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
            else if (a.DictCall == null && a.NewCalls.Count == 0) warn.Add("localizer is embedded but unused: add local localization = qLocalization.new({ en = {...}, ru = {...} })");
            else if (!a.HasWrapLibrary && a.NewCalls.Count <= 1) warn.Add("Menu is not wrapped: add local Menu = " + (a.LocVar ?? "localization") + ".WrapLibrary(Menu) under the dictionary");
            bool dictKnown = a.NewCalls.Count <= 1 && (a.NewCalls.Count == 0 || a.DictCall != null);
            if (a.NewCalls.Count > 1)
                warn.Add(a.NewCalls.Count + " separate qLocalization dictionaries (lines " + string.Join(", ", a.NewCalls.Select(c => c.Line.ToString()).ToArray())
                    + "): looks like several scripts in one file, so translation keys were not checked");
            else if (a.NewCalls.Count == 1 && a.DictCall == null)
                warn.Add("line " + a.NewCalls[0].Line + ": the dictionary is built by code, not written as a table, so translation keys were not checked");

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
            Dictionary<string, List<KeyValuePair<int, string>>> groups = new Dictionary<string, List<KeyValuePair<int, string>>>();
            foreach (Usage u in a.Usages)
            {
                if (a.InLocalizer(u.Arg)) continue;
                StringExpr lit = u.Arg as StringExpr;
                BinaryExpr cat = u.Arg as BinaryExpr;
                if (lit == null && cat != null && cat.Op == ".." && cat.Left is StringExpr)
                {
                    string prefix = ((StringExpr)cat.Left).Value;
                    if (u.Kind != "tooltip" && u.Kind != "get" && prefix.IndexOf('.') >= 0)
                        Put(groups, seen, "dot", cat.Line, "line " + cat.Line + ": menu name built as '" + prefix + "' .. value has a dot, settings will not be saved (use _)");
                    if (dictKnown && defined.Count > 0 && !defined.Keys.Any(k => k.StartsWith(prefix, StringComparison.Ordinal)))
                        Add(warn, seen, "line " + cat.Line + ": key built as '" + prefix + "' .. value, but no dictionary key starts with '" + prefix + "'");
                    continue;
                }
                if (lit == null) continue;
                string v = lit.Value;
                switch (u.Kind)
                {
                    case "tab":
                        if (v.IndexOf('.') >= 0) Put(groups, seen, "dot", lit.Line, "line " + lit.Line + ": menu path '" + v + "' has a dot, settings will not be saved");
                        continue;
                    case "create":
                        if (v.IndexOf('.') >= 0) Put(groups, seen, "dot", lit.Line, "line " + lit.Line + ": menu name '" + v + "' has a dot, settings will not be saved (use _)");
                        if (defined.ContainsKey(v)) usedKeys.Add(v);
                        continue;
                    case "bindname":
                        Add(warn, seen, "line " + lit.Line + ": bind name '" + v + "' is not translated, pass " + (a.LocVar ?? "localization") + ".Get(\"<key>\")");
                        continue;
                }
                if (u.Kind == "name" && v.IndexOf('.') >= 0)
                    Put(groups, seen, "dot", lit.Line, "line " + lit.Line + ": menu name '" + v + "' has a dot, settings will not be saved (use _)");
                if (defined.ContainsKey(v))
                {
                    usedKeys.Add(v);
                    LocalVar into;
                    bool registered = u.Call != null && a.CreatedInto.TryGetValue(u.Call, out into) && a.Registered.Contains(into);
                    if (u.WrappedKnown && !u.Wrapped && u.Kind != "get" && a.DictCall != null && !registered)
                        Add(warn, seen, "line " + lit.Line + ": '" + v + "' is created through the global Menu, it will not be translated: build it from the wrapped Menu");
                    continue;
                }
                if (!dictKnown) continue;
                if (u.Kind == "item" && !Util.KeyPattern.IsMatch(v) && a.DictCall == null) continue;
                if (Util.KeyPattern.IsMatch(v))
                {
                    string close = defined.Count > 0 ? Api.Suggest(v, defined.Keys) : null;
                    Put(groups, seen, "key", lit.Line, "line " + lit.Line + ": key '" + v + "' has no translation" + (close != null ? " (did you mean '" + close + "'?)" : ""));
                    continue;
                }
                if (u.Kind == "get") continue;
                if (v.IndexOf('.') >= 0 && Regex.IsMatch(v, @"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$")) continue;
                if (v.Length == 0) continue;
                Put(groups, seen, "plain", lit.Line, "line " + lit.Line + ": '" + Util.Short(v) + "' is plain text, use a translation key");
            }
            Flush(warn, groups, "dot", "menu names have a dot, settings will not be saved: run luatool migrate to flatten them");
            Flush(warn, groups, "key", "keys have no translation");
            Flush(warn, groups, "plain", "menu texts are plain text instead of translation keys");
            List<string> partial = usedKeys.Where(k => defined[k].Count < langCount).OrderBy(k => k, StringComparer.Ordinal).ToList();
            if (partial.Count <= 5)
            {
                foreach (string key in partial)
                    warn.Add("key '" + key + "' is translated in " + defined[key].Count + " of " + langCount + " languages (missing " + string.Join(", ", a.Languages.Where(l => !defined[key].Contains(l)).ToArray()) + ")");
            }
            else
            {
                foreach (string lang in a.Languages)
                {
                    List<string> keys = partial.Where(k => !defined[k].Contains(lang)).ToList();
                    if (keys.Count > 0) warn.Add(keys.Count + " keys are not translated to " + lang + ": " + string.Join(", ", keys.ToArray()));
                }
            }

            foreach (Finding f in a.ApiFindings.OrderBy(x => x.Line))
            {
                if (f.Key != null && a.Guarded.Contains(f.Key)) Add(info, seen, "line " + f.Line + ": " + f.Key + " is not documented, the script checks that it exists before using it");
                else Add(warn, seen, "line " + f.Line + ": " + f.Text);
            }

            if (a.DashLines.Count > 0) warn.Add("long dash on lines " + string.Join(", ", a.DashLines.OrderBy(x => x).Take(10).Select(x => x.ToString()).ToArray()) + ": use a comma or a period");
            if (a.AiBridgeUnguardedLine > 0) warn.Add("line " + a.AiBridgeUnguardedLine + ": ai_bridge exists only with qMCP, without it this line throws an error: use Log.Write behind a debug switch");
            else if (a.UsesAiBridge) warn.Add("line " + a.AiBridgeLine + ": logs go through ai_bridge (qMCP), they are silent without that MCP: use Log.Write behind a debug switch");
            if (api.Loaded)
            {
                foreach (KeyValuePair<string, int> call in a.GlobalCalls.OrderBy(x => x.Value))
                {
                    if (a.GlobalDefs.Contains(call.Key) || a.Guarded.Contains(call.Key) || LuaGlobals.Contains(call.Key) || api.Globals.Contains(call.Key) || api.Modules.ContainsKey(call.Key)) continue;
                    Add(warn, seen, "line " + call.Value + ": " + call.Key + "() is called, but nothing in this file defines it: the call throws an error");
                }
            }

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

        static readonly HashSet<string> LuaGlobals = new HashSet<string>
        {
            "assert", "collectgarbage", "dofile", "error", "getmetatable", "ipairs", "load", "loadfile", "next", "pairs",
            "pcall", "print", "rawequal", "rawget", "rawlen", "rawset", "require", "select", "setmetatable", "tonumber",
            "tostring", "type", "xpcall", "unpack", "qLocalization", "ai_bridge"
        };

        static void Add(List<string> list, HashSet<string> seen, string text)
        {
            if (seen.Add(text)) list.Add(text);
        }

        static void Put(Dictionary<string, List<KeyValuePair<int, string>>> groups, HashSet<string> seen, string group, int line, string text)
        {
            if (!seen.Add(text)) return;
            List<KeyValuePair<int, string>> list;
            if (!groups.TryGetValue(group, out list)) { list = new List<KeyValuePair<int, string>>(); groups[group] = list; }
            list.Add(new KeyValuePair<int, string>(line, text));
        }

        static void Flush(List<string> warn, Dictionary<string, List<KeyValuePair<int, string>>> groups, string group, string summary)
        {
            List<KeyValuePair<int, string>> list;
            if (!groups.TryGetValue(group, out list)) return;
            if (list.Count <= 5)
            {
                foreach (KeyValuePair<int, string> item in list) warn.Add(item.Value);
                return;
            }
            int[] lines = list.Select(x => x.Key).Distinct().OrderBy(x => x).ToArray();
            string shown = string.Join(", ", lines.Take(12).Select(x => x.ToString()).ToArray()) + (lines.Length > 12 ? ", ..." : "");
            warn.Add(list.Count + " " + summary + " (lines " + shown + ")");
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
