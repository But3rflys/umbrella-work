using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaTool
{
    public static class Checker
    {
        public static int Run(string path, string apiDir)
        {
            SourceFile file = SourceFile.Read(path);
            string source = file.Text;
            Parser parser;
            Lexer lexer;
            Block root;
            try
            {
                root = Program.Parse(source, out parser, out lexer);
            }
            catch (LuaSyntaxException ex)
            {
                Console.WriteLine("SYNTAX: FAIL: line " + ex.Line + ": " + ex.Message);
                Console.WriteLine("WARN: fix the syntax error first, the other checks need a file that loads");
                Console.WriteLine("RESULT: 1 warnings");
                return 1;
            }

            Api api = Api.Load(apiDir);
            Analysis a = new Analysis(api);
            a.Run(root);

            List<string> warn = new List<string>();
            List<string> info = new List<string>();
            HashSet<string> seen = new HashSet<string>();

            if (a.LocalizerStat == null)
            {
                warn.Add(a.CallsGlobalQLocalization
                    ? "localizer is not embedded, the script needs a separate !_qLocalizer.lua: run luatool migrate on this file"
                    : "localizer is not embedded: run luatool migrate on this file");
            }
            else if (a.DictCall == null) warn.Add("localizer is embedded but unused: add local localization = qLocalization.new({ en = {...}, ru = {...} })");
            else if (!a.HasWrapLibrary) warn.Add("Menu is not wrapped: add local Menu = " + (a.LocVar ?? "localization") + ".WrapLibrary(Menu) under the dictionary");

            Dictionary<string, HashSet<string>> defined = new Dictionary<string, HashSet<string>>();
            bool nested = false;
            foreach (DictEntry e in a.Entries)
            {
                HashSet<string> langs;
                if (!defined.TryGetValue(e.Path, out langs)) { langs = new HashSet<string>(); defined[e.Path] = langs; }
                langs.Add(e.Lang);
                if (e.Path.IndexOf('.') >= 0) nested = true;
            }
            if (nested) warn.Add("line " + a.DictCall.Line + ": dictionary keys are nested or dotted, widget names with dots are not saved: run luatool migrate to flatten them");
            if (a.Languages.Count > 0)
            {
                if (!a.Languages.Contains("en")) warn.Add("no en table: en is the fallback language");
                if (!a.Languages.Contains("ru")) warn.Add("no ru table: every script ships en and ru");
            }
            int langCount = Math.Max(1, a.Languages.Count);

            HashSet<string> usedKeys = new HashSet<string>();
            foreach (Usage u in a.Usages)
            {
                if (a.InLocalizer(u.Arg)) continue;
                StringExpr lit = u.Arg as StringExpr;
                BinaryExpr cat = u.Arg as BinaryExpr;
                if (lit == null && cat != null && cat.Op == ".." && cat.Left is StringExpr)
                {
                    string prefix = ((StringExpr)cat.Left).Value;
                    if (u.Kind != "tooltip" && u.Kind != "get" && prefix.IndexOf('.') >= 0)
                        Add(warn, seen, "line " + cat.Line + ": menu name built as '" + prefix + "' .. value has a dot, settings will not be saved (use _)");
                    if (defined.Count > 0 && !defined.Keys.Any(k => k.StartsWith(prefix, StringComparison.Ordinal)))
                        Add(warn, seen, "line " + cat.Line + ": key built as '" + prefix + "' .. value, but no dictionary key starts with '" + prefix + "'");
                    continue;
                }
                if (lit == null) continue;
                string v = lit.Value;
                switch (u.Kind)
                {
                    case "tab":
                        if (v.IndexOf('.') >= 0) Add(warn, seen, "line " + lit.Line + ": menu path '" + v + "' has a dot, settings will not be saved");
                        continue;
                    case "create":
                        if (v.IndexOf('.') >= 0) Add(warn, seen, "line " + lit.Line + ": menu name '" + v + "' has a dot, settings will not be saved (use _)");
                        if (defined.ContainsKey(v)) usedKeys.Add(v);
                        continue;
                    case "bindname":
                        Add(warn, seen, "line " + lit.Line + ": bind name '" + v + "' is not translated, pass " + (a.LocVar ?? "localization") + ".Get(\"<key>\")");
                        continue;
                }
                if (u.Kind == "name" && v.IndexOf('.') >= 0)
                    Add(warn, seen, "line " + lit.Line + ": menu name '" + v + "' has a dot, settings will not be saved (use _)");
                if (defined.ContainsKey(v))
                {
                    usedKeys.Add(v);
                    LocalVar into;
                    bool registered = u.Call != null && a.CreatedInto.TryGetValue(u.Call, out into) && a.Registered.Contains(into);
                    if (u.WrappedKnown && !u.Wrapped && u.Kind != "get" && a.DictCall != null && !registered)
                        Add(warn, seen, "line " + lit.Line + ": '" + v + "' is created through the global Menu, it will not be translated: build it from the wrapped Menu");
                    continue;
                }
                if (u.Kind == "item" && !Util.KeyPattern.IsMatch(v) && a.DictCall == null) continue;
                if (Util.KeyPattern.IsMatch(v))
                {
                    string close = defined.Count > 0 ? Api.Suggest(v, defined.Keys) : null;
                    Add(warn, seen, "line " + lit.Line + ": key '" + v + "' has no translation" + (close != null ? " (did you mean '" + close + "'?)" : ""));
                    continue;
                }
                if (u.Kind == "get") continue;
                if (v.IndexOf('.') >= 0 && Regex.IsMatch(v, @"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$")) continue;
                if (v.Length == 0) continue;
                Add(warn, seen, "line " + lit.Line + ": '" + Util.Short(v) + "' is plain text, use a translation key");
            }
            foreach (string key in usedKeys.OrderBy(k => k, StringComparer.Ordinal))
            {
                int n = defined[key].Count;
                if (n < langCount) warn.Add("key '" + key + "' is translated in " + n + " of " + langCount + " languages (missing " + string.Join(", ", a.Languages.Where(l => !defined[key].Contains(l)).ToArray()) + ")");
            }

            foreach (Finding f in a.ApiFindings.OrderBy(x => x.Line))
            {
                if (f.Key != null && a.Guarded.Contains(f.Key)) Add(info, seen, "line " + f.Line + ": " + f.Key + " is not documented, the script checks that it exists before using it");
                else Add(warn, seen, "line " + f.Line + ": " + f.Text);
            }

            if (a.DashLines.Count > 0) warn.Add("long dash on lines " + string.Join(", ", a.DashLines.OrderBy(x => x).Take(10).Select(x => x.ToString()).ToArray()) + ": use a comma or a period");
            if (a.UsesAiBridge) warn.Add("line " + a.AiBridgeLine + ": logs go through ai_bridge (qMCP), they are silent without that MCP: use Log.Write behind a debug switch");

            int comments = 0;
            int skipEnd = a.LocalizerStat != null ? a.LocalizerStat.End : -1;
            foreach (Comment c in lexer.Comments)
            {
                if (c.Start < skipEnd) continue;
                if (source.Substring(c.Start, Math.Min(4, c.End - c.Start)) == "---@") continue;
                comments++;
            }
            if (comments > 0) info.Add(comments + " comments: house style keeps code without explanatory comments");

            string localsText = "top-level locals: " + parser.MainMaxLocals + " (Lua allows 200 per function, keep state in tables and wrap sections in do ... end)";
            if (parser.MainMaxLocals > 150) warn.Add(localsText); else info.Add(localsText);
            foreach (KeyValuePair<int, int> fl in parser.FunctionMaxLocals)
            {
                if (fl.Value > 150) warn.Add("function at line " + fl.Key + " has " + fl.Value + " locals, the limit is 200");
            }
            if (a.UsesPolyLine) info.Add("Render.PolyLine closes the path: last point is joined to the first");
            if (!api.Loaded) info.Add("API reference not found next to the tool, calls were not checked against it");

            Console.WriteLine("SYNTAX: OK (Lua 5.4)");
            Console.WriteLine("KEYS: " + usedKeys.Count + " used, languages: " + string.Join(", ", a.Languages.ToArray()));
            foreach (string w in warn) Console.WriteLine("WARN: " + w);
            foreach (string i in info) Console.WriteLine("INFO: " + i);
            Console.WriteLine("RESULT: " + warn.Count + " warnings");
            return 0;
        }

        static void Add(List<string> list, HashSet<string> seen, string text)
        {
            if (seen.Add(text)) list.Add(text);
        }

        public static int Log(string path)
        {
            string full = Path.GetFullPath(path);
            string name = Path.GetFileName(full);
            string scripts = Path.GetDirectoryName(full);
            string cheat = scripts != null ? Path.GetDirectoryName(scripts) : null;
            string logFile = cheat != null ? Path.Combine(cheat, "debug.log") : null;
            if (logFile == null || !File.Exists(logFile))
            {
                Console.WriteLine("LOG not found: " + (logFile ?? "?") + " (the script has to sit in the Umbrella scripts folder)");
                return 0;
            }
            string text;
            using (FileStream fs = new FileStream(logFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (StreamReader r = new StreamReader(fs, new UTF8Encoding(false)))
            {
                text = r.ReadToEnd();
            }
            string[] lines = text.Replace("\r\n", "\n").Split('\n');
            List<int> marks = new List<int>();
            for (int i = 0; i < lines.Length; i++) if (lines[i].Contains("Reload ScriptSystem")) marks.Add(i);
            int start = 0;
            if (marks.Count >= 2) start = marks[marks.Count - 2] + 1;
            else if (lines.Length > 500) start = lines.Length - 500;
            List<string> blocks = new List<string>();
            int k = start;
            while (k < lines.Length)
            {
                if (lines[k].Contains("[Lua Error]"))
                {
                    StringBuilder block = new StringBuilder(lines[k]);
                    int j = k + 1;
                    while (j < lines.Length && (lines[j].StartsWith("\t") || lines[j].StartsWith(" ") || lines[j].StartsWith("stack traceback") || lines[j].Contains("[Lua Error]")))
                    {
                        if (lines[j].Contains("[Lua Error]") && !lines[j].Contains("dofile")) break;
                        block.Append('\n').Append(lines[j]);
                        j++;
                    }
                    blocks.Add(block.ToString());
                    k = j;
                }
                else k++;
            }
            List<string> own = blocks.Where(b => b.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            int other = blocks.Count - own.Count;
            Console.WriteLine("LOG " + logFile + " (since the previous script reload)");
            if (own.Count == 0) Console.WriteLine("no errors for " + name);
            foreach (var g in own.GroupBy(b => b).Take(15))
            {
                Console.WriteLine((g.Count() > 1 ? "[x" + g.Count() + "] " : "") + g.Key);
            }
            if (other > 0) Console.WriteLine("(" + other + " errors from other scripts skipped)");
            return 0;
        }
    }
}
