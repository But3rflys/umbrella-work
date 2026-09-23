using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaTool
{
    public sealed class Signature
    {
        public int Min;
        public int Max;
        public string Text;
    }

    public sealed class Api
    {
        public readonly Dictionary<string, Dictionary<string, List<Signature>>> Modules = new Dictionary<string, Dictionary<string, List<Signature>>>();
        public readonly Dictionary<string, HashSet<string>> Enums = new Dictionary<string, HashSet<string>>();
        public readonly HashSet<string> Callbacks = new HashSet<string>();
        public readonly HashSet<string> MenuMethods = new HashSet<string>();
        public bool Loaded;

        static readonly Regex ModuleLine = new Regex(@"^([A-Za-z_]\w*)\.([A-Za-z_]\w*)\((.*)\)(?: -> .*)?$");
        static readonly Regex CallbackLine = new Regex(@"^(On\w+)\(");
        static readonly Regex MethodLine = new Regex(@"^(?:[A-Za-z_]\w*)?:([A-Za-z_]\w*)\(");
        static readonly Regex EnumHead = new Regex(@"^## Enum\.(\w+)(?: \((-?\d+)\.\.(-?\d+)\))?\s*$");

        public static Api Load(string dir)
        {
            Api api = new Api();
            if (dir == null || !Directory.Exists(dir)) return api;
            foreach (string file in Directory.GetFiles(dir, "*.md"))
            {
                string name = Path.GetFileNameWithoutExtension(file);
                if (name == "Guide") continue;
                string[] lines = File.ReadAllLines(file, new UTF8Encoding(false));
                if (name == "Enums") { api.LoadEnums(lines); continue; }
                bool inCode = false;
                foreach (string line in lines)
                {
                    if (line.StartsWith("```")) { inCode = !inCode; continue; }
                    if (inCode) continue;
                    if (name == "Callbacks")
                    {
                        Match c = CallbackLine.Match(line);
                        if (c.Success) api.Callbacks.Add(c.Groups[1].Value);
                        continue;
                    }
                    if (name == "Menu")
                    {
                        Match mm = MethodLine.Match(line);
                        if (mm.Success) api.MenuMethods.Add(mm.Groups[1].Value);
                    }
                    Match m = ModuleLine.Match(line);
                    if (!m.Success) continue;
                    string module = m.Groups[1].Value;
                    string fn = m.Groups[2].Value;
                    Dictionary<string, List<Signature>> funcs;
                    if (!api.Modules.TryGetValue(module, out funcs))
                    {
                        funcs = new Dictionary<string, List<Signature>>();
                        api.Modules[module] = funcs;
                    }
                    List<Signature> sigs;
                    if (!funcs.TryGetValue(fn, out sigs))
                    {
                        sigs = new List<Signature>();
                        funcs[fn] = sigs;
                    }
                    sigs.Add(ParseSignature(m.Groups[3].Value, module + "." + fn + "(" + m.Groups[3].Value + ")"));
                }
            }
            api.Loaded = api.Modules.Count > 0;
            return api;
        }

        void LoadEnums(string[] lines)
        {
            for (int i = 0; i < lines.Length; i++)
            {
                Match h = EnumHead.Match(lines[i]);
                if (!h.Success) continue;
                HashSet<string> values = new HashSet<string>();
                Enums[h.Groups[1].Value] = values;
                if (i + 1 >= lines.Length) continue;
                string body = lines[i + 1].Trim();
                string prefix = "";
                int sep = body.IndexOf("* : ", StringComparison.Ordinal);
                if (sep > 0 && body.IndexOf(' ') > sep)
                {
                    prefix = body.Substring(0, sep);
                    body = body.Substring(sep + 4);
                }
                foreach (string item in body.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    int eq = item.LastIndexOf('=');
                    values.Add(prefix + (eq > 0 ? item.Substring(0, eq) : item));
                }
            }
        }

        static Signature ParseSignature(string args, string text)
        {
            Signature s = new Signature { Text = text };
            List<string> parts = SplitTop(args);
            int required = 0;
            int total = 0;
            bool varargs = false;
            foreach (string part in parts)
            {
                string t = part.Trim();
                if (t.Length == 0) continue;
                bool optional = t.StartsWith("[") && t.EndsWith("]");
                string body = optional ? t.Substring(1, t.Length - 2) : t;
                if (body.StartsWith("...")) { varargs = true; continue; }
                total++;
                if (!optional) required = total;
            }
            s.Min = required;
            s.Max = varargs ? int.MaxValue : total;
            return s;
        }

        static List<string> SplitTop(string s)
        {
            List<string> result = new List<string>();
            int depth = 0;
            StringBuilder cur = new StringBuilder();
            foreach (char c in s)
            {
                if (c == '(' || c == '[' || c == '{' || c == '<') depth++;
                if (c == ')' || c == ']' || c == '}' || (c == '>' && !(cur.Length > 0 && cur[cur.Length - 1] == '-'))) depth--;
                if (c == ',' && depth == 0)
                {
                    result.Add(cur.ToString());
                    cur.Length = 0;
                }
                else cur.Append(c);
            }
            if (cur.ToString().Trim().Length > 0) result.Add(cur.ToString());
            return result;
        }

        public static string Suggest(string name, IEnumerable<string> candidates)
        {
            string best = null;
            int bestDistance = int.MaxValue;
            string contained = null;
            string lower = name.ToLowerInvariant();
            foreach (string c in candidates)
            {
                string cl = c.ToLowerInvariant();
                int d = Distance(lower, cl);
                if (d < bestDistance) { bestDistance = d; best = c; }
                if (cl.Length >= 4 && lower.Length >= 4 && (lower.EndsWith(cl) || cl.EndsWith(lower)) && (contained == null || c.Length > contained.Length)) contained = c;
            }
            int limit = Math.Max(2, name.Length / 4);
            if (bestDistance <= limit) return best;
            return contained;
        }

        static int Distance(string a, string b)
        {
            int[] prev = new int[b.Length + 1];
            int[] cur = new int[b.Length + 1];
            for (int j = 0; j <= b.Length; j++) prev[j] = j;
            for (int i = 1; i <= a.Length; i++)
            {
                cur[0] = i;
                for (int j = 1; j <= b.Length; j++)
                {
                    int cost = a[i - 1] == b[j - 1] ? 0 : 1;
                    cur[j] = Math.Min(Math.Min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
                }
                int[] t = prev; prev = cur; cur = t;
            }
            return prev[b.Length];
        }
    }
}
