using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaTool
{
    public static class Migrator
    {
        sealed class Edit
        {
            public int Start;
            public int End;
            public string Text;
        }

        public static int Run(string path, string prefixArg, string apiDir)
        {
            SourceFile file = SourceFile.Read(path);
            string original = file.Text;
            string prefix = prefixArg != null ? Util.CleanPrefix(prefixArg) : Util.DefaultPrefix(System.IO.Path.GetFileNameWithoutExtension(path));
            List<string> report = new List<string>();

            Parser parser;
            Lexer lexer;
            Block root;
            try
            {
                Program.Parse(original, out parser, out lexer);
            }
            catch (LuaSyntaxException ex)
            {
                Console.WriteLine("ERROR: the script does not load, fix it first: line " + ex.Line + ": " + ex.Message);
                Console.WriteLine("Nothing was changed.");
                return 1;
            }

            string text = original;
            bool embedded = false;
            if (!Util.HasEmbeddedLocalizer(text))
            {
                text = Util.EmbedLocalizer(text);
                embedded = true;
            }
            try
            {
                root = Program.Parse(text, out parser, out lexer);
            }
            catch (LuaSyntaxException ex)
            {
                Console.WriteLine("ERROR: the script stops loading once the localizer is added: " + ex.Message);
                Console.WriteLine("Nothing was changed.");
                return 1;
            }

            Api api = Api.Load(apiDir);
            Analysis a = new Analysis(api);
            a.Run(root);
            int shift = Util.CountLines(text) - Util.CountLines(original);
            if (a.NewCalls.Count > 1)
            {
                Console.WriteLine("STOPPED: " + path + " has " + a.NewCalls.Count + " separate qLocalization dictionaries (lines "
                    + string.Join(", ", a.NewCalls.Select(c => (c.Line - shift).ToString()).ToArray())
                    + "), it looks like several scripts in one file. migrate works with one script per file: split it or change it by hand");
                Console.WriteLine("Nothing was changed.");
                return 1;
            }
            if (a.NewCalls.Count == 1 && a.DictCall == null)
            {
                Console.WriteLine("STOPPED: the dictionary on line " + (a.NewCalls[0].Line - shift) + " is built by code, not written as a table, so migrate cannot read its keys");
                Console.WriteLine("Nothing was changed.");
                return 1;
            }
            string locVar = a.LocVar ?? "localization";

            List<string> ordered = new List<string>();
            foreach (string l in new[] { "en", "ru" }.Concat(a.Languages)) if (!ordered.Contains(l)) ordered.Add(l);

            string rootSeg = null;
            if (a.Entries.Count > 0 && a.Entries.All(e => e.Path.IndexOf('.') > 0))
            {
                string first = a.Entries[0].Path.Split('.')[0];
                if (a.Entries.All(e => e.Path.Split('.')[0] == first)) rootSeg = first + ".";
            }

            Dictionary<string, string> pathMap = new Dictionary<string, string>();
            List<string> keyOrder = new List<string>();
            Dictionary<string, Dictionary<string, string>> dict = new Dictionary<string, Dictionary<string, string>>();
            bool renamed = false;
            List<string> dynamicPrefixes = a.Concats.Select(c => ((StringExpr)c.Left).Value).Where(v => v.EndsWith(".", StringComparison.Ordinal)).Distinct().ToList();
            foreach (DictEntry e in a.Entries)
            {
                string newKey = Flat(e.Path, prefix, rootSeg, dynamicPrefixes);
                if (newKey != e.Path) renamed = true;
                pathMap[e.Path] = newKey;
                if (!dict.ContainsKey(newKey))
                {
                    dict[newKey] = new Dictionary<string, string>();
                    keyOrder.Add(newKey);
                }
                dict[newKey][e.Lang] = text.Substring(e.Value.Start, e.Value.End - e.Value.Start);
            }
            int fromDictionary = a.Entries.Count;

            List<Edit> edits = new List<Edit>();
            HashSet<Node> covered = new HashSet<Node>();
            List<string> manual = new List<string>();
            List<string> dynamic = new List<string>();
            List<string> notes = new List<string>();

            foreach (StringExpr s in a.Strings)
            {
                if (a.InDictionary(s)) continue;
                string nk;
                if (pathMap.TryGetValue(s.Value, out nk) && nk != s.Value)
                {
                    edits.Add(new Edit { Start = s.Start, End = s.End, Text = Util.Quote(nk) });
                    covered.Add(s);
                }
            }

            foreach (BinaryExpr cat in a.Concats)
            {
                StringExpr left = (StringExpr)cat.Left;
                if (covered.Contains(left) || a.InDictionary(left)) continue;
                string v = left.Value;
                if (v.Length == 0 || !pathMap.Keys.Any(p => p.StartsWith(v, StringComparison.Ordinal) && p.Length > v.Length)) continue;
                if (!v.EndsWith(".") && !v.EndsWith("_")) continue;
                string flatPrefix = v.EndsWith(".") ? FlatPrefix(v, prefix, rootSeg) : null;
                if (flatPrefix == null || flatPrefix == v) continue;
                edits.Add(new Edit { Start = left.Start, End = left.End, Text = Util.Quote(flatPrefix) });
                covered.Add(left);
                dynamic.Add(left.Raw + " .. -> " + Util.Quote(flatPrefix) + " ..");
            }

            HashSet<string> usedKeys = new HashSet<string>(dict.Keys);
            int fromText = 0;
            int insertPos = a.DictStat != null ? a.DictStat.End : Util.LibraryEnd(text);
            bool willWrap = !a.HasWrapLibrary && (a.DictStat != null || a.DictCall == null);
            LocalStat rawAlias = willWrap ? a.MenuAliases.Where(x => x.Start >= insertPos).OrderBy(x => x.End).LastOrDefault() : null;
            if (rawAlias != null) insertPos = rawAlias.End;
            foreach (Usage u in a.Usages)
            {
                if (a.InLocalizer(u.Arg) || a.InDictionary(u.Arg)) continue;
                StringExpr lit = u.Arg as StringExpr;
                if (lit == null || covered.Contains(lit)) continue;
                string v = lit.Value;
                if (u.Kind == "tab")
                {
                    if (Util.IsCyrillic(v)) manual.Add("tab name " + lit.Raw + " is not translatable, rename it to English by hand (this resets its saved settings)");
                    covered.Add(lit);
                    continue;
                }
                if (dict.ContainsKey(v) || pathMap.ContainsKey(v)) { covered.Add(lit); continue; }
                if (v.Length == 0) continue;
                if (u.Kind == "get") continue;
                if (Util.KeyPattern.IsMatch(v))
                {
                    string close = Api.Suggest(v, dict.Keys);
                    if (close != null)
                    {
                        manual.Add("key '" + v + "' (line " + LineOf(text, lit.Start, a) + ") is not in the dictionary, did you mean '" + close + "'?");
                        covered.Add(lit);
                        continue;
                    }
                }
                if (u.Kind == "create")
                {
                    if (Util.IsCyrillic(v)) manual.Add("cannot tell if :Create(" + lit.Raw + ") makes a tab or a group, check it by hand");
                    covered.Add(lit);
                    continue;
                }
                if (u.WrappedKnown && !Effective(u.Receiver, willWrap, insertPos))
                {
                    manual.Add("'" + Util.Short(v) + "' (line " + LineOf(text, lit.Start, a) + ") is created through a Menu that stays unwrapped, so it was left as text: build it from the wrapped Menu, then run migrate again");
                    covered.Add(lit);
                    continue;
                }
                string baseName = u.Base;
                if (u.Kind == "item") baseName = (u.Base ?? "items") + "_" + Util.Slug(v, 3);
                else if (baseName == null) baseName = (u.Receiver != null && u.Receiver.Kind == Kind.Tab3 ? "group_" : "") + Util.Slug(v, 3);
                string key = NewKey(prefix, baseName, lit.Raw, dict, usedKeys, keyOrder);
                string lang = Util.IsCyrillic(v) ? "ru" : "en";
                dict[key][lang] = lit.Raw;
                fromText++;
                string replacement = u.Kind == "bindname" ? locVar + ".Get(" + Util.Quote(key) + ")" : Util.Quote(key);
                edits.Add(new Edit { Start = lit.Start, End = lit.End, Text = replacement });
                covered.Add(lit);
            }

            int wrapCount = 0;
            foreach (CallExpr w in a.WrapCalls)
            {
                if (w.Args.Count != 2 || !(w.Args[1] is BoolExpr) || !((BoolExpr)w.Args[1]).Value) continue;
                TypeInfo innerType;
                if (!a.WrapInner.TryGetValue(w, out innerType) || innerType.Kind == Kind.None || !Effective(innerType, willWrap, insertPos)) continue;
                Expr inner = w.Args[0];
                edits.Add(new Edit { Start = w.Start, End = inner.Start, Text = "" });
                edits.Add(new Edit { Start = inner.End, End = w.End, Text = "" });
                wrapCount++;
            }

            List<StringExpr> outside = new List<StringExpr>();
            foreach (StringExpr s in a.Strings)
            {
                if (covered.Contains(s) || a.InDictionary(s) || a.FindArgs.Contains(s)) continue;
                if (Util.IsCyrillic(s.Value)) outside.Add(s);
            }
            if (outside.Count <= 5)
            {
                foreach (StringExpr s in outside)
                    manual.Add("text outside the menu " + Util.Quote(Util.Short(s.Value)) + " (line " + LineOf(text, s.Start, a) + "): if players see it, move it to the dictionary and use " + locVar + ".Get");
            }
            else
            {
                List<StringExpr> firstOnLine = outside.GroupBy(s => s.Line).Select(g => g.First()).ToList();
                string lines = string.Join(", ", firstOnLine.Take(15).Select(s => LineOf(text, s.Start, a)).ToArray()) + (firstOnLine.Count > 15 ? ", ..." : "");
                string samples = string.Join(", ", outside.Take(3).Select(s => Util.Quote(Util.Short(s.Value))).ToArray());
                manual.Add(outside.Count + " texts outside the menu are in Russian, for example " + samples + " (lines " + lines + "): if players see them, move them to the dictionary and use " + locVar + ".Get");
            }

            string indent = DetectIndent(text, a);
            bool needWrapLib = !a.HasWrapLibrary;
            bool addedWrap = false;
            bool dictNeedsWrite = renamed || fromText > 0;

            Dictionary<string, List<string>> need = new Dictionary<string, List<string>>();
            string dictText = BuildDictionary(locVar, ordered, keyOrder, dict, indent, need);
            string wrapLine = "local Menu = " + locVar + ".WrapLibrary(Menu)";

            if (rawAlias != null && needWrapLib)
            {
                edits.Add(new Edit { Start = rawAlias.End, End = rawAlias.End, Text = "\n\n" + wrapLine });
                addedWrap = true;
                needWrapLib = false;
                notes.Add(rawAlias.Vars[0].Name + " (line " + LineOf(text, rawAlias.Start, a) + ") keeps the raw Menu on purpose, so WrapLibrary goes below it and the manual Wrap calls on it stay");
            }
            foreach (KeyValuePair<CallExpr, TypeInfo> reg in a.Registers)
            {
                TypeInfo rt = reg.Value;
                if (rt == null || rt.Kind == Kind.None || rt.Wrapped || !Effective(rt, willWrap, insertPos)) continue;
                manual.Add(locVar + ".Register on line " + LineOf(text, reg.Key.Start, a) + " gets an object that WrapLibrary now translates too, so its name has two translations: create it from a raw Menu alias or drop the Register");
            }

            if (a.DictStat != null)
            {
                if (dictNeedsWrite) edits.Add(new Edit { Start = a.DictStat.Start, End = a.DictStat.End, Text = dictText + (needWrapLib ? "\n\n" + wrapLine : "") });
                else if (needWrapLib) edits.Add(new Edit { Start = a.DictStat.End, End = a.DictStat.End, Text = "\n\n" + wrapLine });
                addedWrap = addedWrap || needWrapLib;
            }
            else if (a.DictCall != null)
            {
                manual.Add("the dictionary is not stored in a single local, it was left as it is");
            }
            else
            {
                int at = Util.LibraryEnd(text);
                while (at < text.Length && text[at] == '\n') at++;
                edits.Add(new Edit { Start = at, End = at, Text = dictText + (needWrapLib ? "\n\n" + wrapLine : "") + "\n\n" });
                addedWrap = addedWrap || needWrapLib;
            }

            int dictAnchor = a.DictStat != null ? a.DictStat.Start : Util.LibraryEnd(text);
            foreach (Expr raw in a.RawMenuCalls)
            {
                if (raw.Start < dictAnchor && !a.InLocalizer(raw))
                {
                    string line = LineText(text, raw.Start).Trim();
                    manual.Add("Menu is used above the dictionary (line " + LineOf(text, raw.Start, a) + "): " + Util.Short(line) + ". Widgets made there skip the translation wrapper, move that code below the dictionary");
                }
            }
            if (a.AiBridgeUnguardedLine > 0) manual.Add("ai_bridge exists only with qMCP, without it line " + LineOf(text, LineStart(text, a.AiBridgeUnguardedLine), a) + " throws an error: switch to Log.Write behind a debug switch");
            else if (a.UsesAiBridge) manual.Add("logs go through ai_bridge (qMCP), they are silent without that MCP: switch to Log.Write behind a debug switch");

            List<Edit> applied;
            string result = Apply(text, edits, manual, out applied);
            manual = manual.Select(m => ResolveLines(m, applied, result)).ToList();
            notes = notes.Select(m => ResolveLines(m, applied, result)).ToList();
            bool changed = result != original;
            if (changed) file.Write(result);

            Program.Say(embedded ? "EMBEDDED localizer at the top of " + path : null);
            if (!changed)
            {
                Console.WriteLine("NOTHING TO CHANGE: " + path + " already follows the rules");
            }
            else
            {
                Console.WriteLine("MIGRATED " + path + " (key prefix '" + prefix + "_')");
                Console.WriteLine("KEYS: " + keyOrder.Count + " total, " + fromDictionary + " entries from the old dictionary" + (renamed ? " (renamed to flat keys)" : "") + ", " + fromText + " strings taken from the code");
            }
            if (wrapCount > 0) Console.WriteLine("WRAP: removed " + wrapCount + " manual " + locVar + ".Wrap(...), the menu goes through WrapLibrary now");
            if (addedWrap) Console.WriteLine("WRAP: added " + wrapLine);
            foreach (string d in dynamic) Console.WriteLine("DYNAMIC: " + d + " (key built in code, check that every result exists in the dictionary)");
            foreach (string lang in ordered)
            {
                List<string> list;
                if (need.TryGetValue(lang, out list) && list.Count > 0)
                    Console.WriteLine("NEED " + lang + (lang == "en" || lang == "ru" ? "" : " (optional)") + ": " + string.Join(", ", list.ToArray()));
            }
            foreach (string m in manual.Distinct()) Console.WriteLine("MANUAL: " + m);
            foreach (string n in notes) Console.WriteLine("NOTE: " + n);
            if (changed && (renamed || fromText > 0)) Console.WriteLine("NOTE: menu item names changed, so their saved values reset once (dotted names were not saved anyway)");
            Console.WriteLine("BODY starts at line " + Util.BodyLine(result) + ". Add the NEED translations, fix MANUAL items, then run check");
            return 0;
        }

        static bool Effective(TypeInfo t, bool willWrap, int insertPos)
        {
            if (t == null) return true;
            if (t.Wrapped) return true;
            return willWrap && t.GlobalRef && t.RefPos > insertPos;
        }

        static string Flat(string path, string prefix, string rootSeg, List<string> dynamicPrefixes)
        {
            if (path.IndexOf('.') < 0) return path;
            string dyn = dynamicPrefixes.Where(d => path.StartsWith(d, StringComparison.Ordinal) && path.Length > d.Length).OrderByDescending(d => d.Length).FirstOrDefault();
            if (dyn != null) return FlatPrefix(dyn, prefix, rootSeg) + path.Substring(dyn.Length);
            string p = path;
            if (rootSeg != null && p.StartsWith(rootSeg, StringComparison.Ordinal)) p = p.Substring(rootSeg.Length);
            string flat = Util.Snake(p);
            return flat.Length == 0 ? prefix : prefix + "_" + flat;
        }

        static string FlatPrefix(string dotted, string prefix, string rootSeg)
        {
            string body = dotted;
            if (rootSeg != null && body.StartsWith(rootSeg, StringComparison.Ordinal)) body = body.Substring(rootSeg.Length);
            body = Util.Snake(body);
            return body.Length == 0 ? prefix + "_" : prefix + "_" + body + "_";
        }

        static string NewKey(string prefix, string baseName, string raw, Dictionary<string, Dictionary<string, string>> dict, HashSet<string> used, List<string> order)
        {
            string b = Util.KeyPart(baseName);
            string key = prefix + "_" + b;
            key = Regex.Replace(key, "_+", "_");
            int n = 2;
            string candidate = key;
            while (used.Contains(candidate))
            {
                Dictionary<string, string> existing;
                if (dict.TryGetValue(candidate, out existing) && existing.Values.Contains(raw)) return candidate;
                candidate = key + "_" + n;
                n++;
            }
            used.Add(candidate);
            dict[candidate] = new Dictionary<string, string>();
            order.Add(candidate);
            return candidate;
        }

        static string BuildDictionary(string locVar, List<string> langs, List<string> keys, Dictionary<string, Dictionary<string, string>> dict, string indent, Dictionary<string, List<string>> need)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("local ").Append(locVar).Append(" = qLocalization.new({\n");
            foreach (string lang in langs)
            {
                sb.Append(indent).Append(lang).Append(" = {\n");
                foreach (string k in keys)
                {
                    string raw;
                    if (dict[k].TryGetValue(lang, out raw))
                    {
                        sb.Append(indent).Append(indent).Append(k).Append(" = ").Append(raw).Append(",\n");
                    }
                    else
                    {
                        List<string> list;
                        if (!need.TryGetValue(lang, out list)) { list = new List<string>(); need[lang] = list; }
                        list.Add(k);
                    }
                }
                sb.Append(indent).Append("},\n");
            }
            sb.Append("})");
            return sb.ToString();
        }

        static string DetectIndent(string text, Analysis a)
        {
            int start = a.LocalizerStat != null ? a.LocalizerStat.End : 0;
            int tabs = 0;
            int spaces = 0;
            int width = 4;
            foreach (Match m in Regex.Matches(text.Substring(start), @"(?m)^([ \t]+)\S"))
            {
                string ws = m.Groups[1].Value;
                if (ws[0] == '\t') tabs++;
                else
                {
                    spaces++;
                    if (spaces == 1) width = Math.Max(2, Math.Min(8, ws.Length));
                }
            }
            if (tabs == 0 && spaces == 0) return "\t";
            return tabs >= spaces ? "\t" : new string(' ', width);
        }

        static int LineStart(string text, int line)
        {
            int pos = 0;
            for (int l = 1; l < line; l++)
            {
                pos = text.IndexOf('\n', pos);
                if (pos < 0) return text.Length;
                pos++;
            }
            return pos;
        }

        static string LineOf(string text, int offset, Analysis a)
        {
            return "\u0001" + offset + "\u0002";
        }

        static string ResolveLines(string message, List<Edit> applied, string result)
        {
            return Regex.Replace(message, "\u0001(\\d+)\u0002", m =>
            {
                int offset = int.Parse(m.Groups[1].Value);
                int pos = offset;
                foreach (Edit e in applied)
                {
                    int delta = e.Text.Length - (e.End - e.Start);
                    if (e.End <= offset) pos += delta;
                    else if (e.Start < offset) pos += e.Start - offset;
                }
                int line = 1;
                for (int i = 0; i < pos && i < result.Length; i++) if (result[i] == '\n') line++;
                return line.ToString();
            });
        }

        static string LineText(string text, int offset)
        {
            int s = text.LastIndexOf('\n', Math.Max(0, offset - 1)) + 1;
            int e = text.IndexOf('\n', offset);
            if (e < 0) e = text.Length;
            return text.Substring(s, e - s);
        }

        static string Apply(string text, List<Edit> edits, List<string> manual, out List<Edit> applied)
        {
            List<Edit> sorted = edits.OrderByDescending(e => e.Start).ThenByDescending(e => e.End).ToList();
            StringBuilder sb = new StringBuilder(text);
            applied = new List<Edit>();
            int limit = int.MaxValue;
            foreach (Edit e in sorted)
            {
                if (e.End > limit)
                {
                    manual.Add("overlapping change on line " + LineOf(text, e.Start, null) + " was skipped, check that spot by hand");
                    continue;
                }
                sb.Remove(e.Start, e.End - e.Start);
                sb.Insert(e.Start, e.Text);
                applied.Add(e);
                limit = e.Start;
            }
            return sb.ToString();
        }
    }
}
