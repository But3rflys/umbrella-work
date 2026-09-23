using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaTool
{
    public sealed class SourceFile
    {
        public string Path;
        public string Text;
        public bool Crlf;
        public bool Bom;

        public static SourceFile Read(string path)
        {
            byte[] bytes = File.ReadAllBytes(path);
            SourceFile f = new SourceFile { Path = path };
            f.Bom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
            string text = new UTF8Encoding(false).GetString(bytes, f.Bom ? 3 : 0, bytes.Length - (f.Bom ? 3 : 0));
            f.Crlf = text.Contains("\r\n");
            f.Text = text.Replace("\r\n", "\n");
            return f;
        }

        public void Write(string text)
        {
            string output = Crlf ? text.Replace("\n", "\r\n") : text;
            File.WriteAllText(Path, output, new UTF8Encoding(Bom));
        }
    }

    public static class Util
    {
        static readonly Regex CyrillicRx = new Regex("[Ѐ-ӿ]");
        static readonly Regex LocalizerRx = new Regex(@"(?m)^local\s+qLocalization\s*=\s*\(\s*function");
        static readonly Regex HeadRx = new Regex(@"\A(?:---@[^\n]*\n)+");
        static readonly Regex LibEndRx = new Regex(@"(?m)^end\)\(\)\n");
        public static readonly Regex KeyPattern = new Regex(@"^[a-z][a-z0-9]*(_[a-z0-9]+)+$");
        static Dictionary<char, string> translit;

        public static string Resource(string name)
        {
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
            {
                if (s == null) throw new InvalidOperationException("missing resource " + name);
                using (StreamReader r = new StreamReader(s, new UTF8Encoding(false)))
                {
                    return r.ReadToEnd().Replace("\r\n", "\n");
                }
            }
        }

        public static bool HasEmbeddedLocalizer(string text)
        {
            return LocalizerRx.IsMatch(text);
        }

        public static string EmbedLocalizer(string text)
        {
            string head = "";
            Match m = HeadRx.Match(text);
            if (m.Success)
            {
                head = m.Value;
                text = text.Substring(m.Length);
            }
            return head + Resource("qlocalizer.lua").TrimEnd() + "\n\n" + text.TrimStart('\n');
        }

        public static int BodyLine(string text)
        {
            Match m = LibEndRx.Match(text);
            int offset = m.Success ? m.Index + m.Length : 0;
            int line = 1;
            for (int i = 0; i < offset; i++) if (text[i] == '\n') line++;
            return line;
        }

        public static int LibraryEnd(string text)
        {
            Match m = LibEndRx.Match(text);
            return m.Success ? m.Index + m.Length : 0;
        }

        public static string[] Words(string name)
        {
            return Regex.Split(name, @"[_\-\s]+").WhereNotEmpty();
        }

        public static string[] WhereNotEmpty(this string[] items)
        {
            List<string> r = new List<string>();
            foreach (string s in items) if (s.Length > 0) r.Add(s);
            return r.ToArray();
        }

        public static int CountLines(string text)
        {
            int n = 1;
            foreach (char c in text) if (c == '\n') n++;
            return n;
        }

        public static string StripVersion(string fileName)
        {
            string s = Regex.Replace(fileName, @"(?:[_\-\s]+v?|[_\-\s]*v)\d+(?:[._]\d+)*$", "", RegexOptions.IgnoreCase);
            return s.Length > 0 ? s : fileName;
        }

        public static string DefaultTitle(string fileName)
        {
            fileName = StripVersion(fileName);
            StringBuilder sb = new StringBuilder();
            foreach (string w in Words(fileName))
            {
                if (sb.Length > 0) sb.Append(' ');
                sb.Append(char.ToUpperInvariant(w[0])).Append(w.Substring(1));
            }
            return sb.ToString();
        }

        public static string DefaultPrefix(string fileName)
        {
            fileName = StripVersion(fileName);
            StringBuilder sb = new StringBuilder();
            foreach (string w in Words(fileName))
            {
                char c = char.ToLowerInvariant(w[0]);
                if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) sb.Append(c);
            }
            string p = sb.ToString();
            if (p.Length < 2)
            {
                string clean = Regex.Replace(fileName.ToLowerInvariant(), "[^a-z0-9]", "");
                p = clean.Substring(0, Math.Min(3, clean.Length));
            }
            if (p.Length == 0 || !(p[0] >= 'a' && p[0] <= 'z')) p = "s" + p;
            return p;
        }

        public static string CleanPrefix(string prefix)
        {
            string p = Regex.Replace((prefix ?? "").ToLowerInvariant(), "[^a-z0-9]", "");
            if (p.Length == 0 || !(p[0] >= 'a' && p[0] <= 'z')) p = "s" + p;
            return p;
        }

        public static bool IsCyrillic(string v)
        {
            return v != null && CyrillicRx.IsMatch(v);
        }

        static Dictionary<char, string> Translit
        {
            get
            {
                if (translit != null) return translit;
                string[] lat = { "a", "b", "v", "g", "d", "e", "zh", "z", "i", "y", "k", "l", "m", "n", "o", "p", "r", "s", "t", "u", "f", "h", "ts", "ch", "sh", "sch", "", "y", "", "e", "yu", "ya" };
                translit = new Dictionary<char, string>();
                for (int i = 0; i < lat.Length; i++) translit[(char)(0x430 + i)] = lat[i];
                translit['ё'] = "e";
                return translit;
            }
        }

        public static string Slug(string value, int maxWords)
        {
            StringBuilder sb = new StringBuilder();
            foreach (char ch in value.ToLowerInvariant())
            {
                string t;
                if (Translit.TryGetValue(ch, out t)) sb.Append(t);
                else sb.Append(ch);
            }
            string[] words = Regex.Replace(sb.ToString(), "[^a-z0-9]+", " ").Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (words.Length == 0) return "item";
            return string.Join("_", words, 0, Math.Min(maxWords, words.Length));
        }

        public static string KeyPart(string value)
        {
            string s = Snake(value);
            return s.Length == 0 ? "item" : s;
        }

        public static string Snake(string value)
        {
            string split = Regex.Replace(value ?? "", "([a-z0-9])([A-Z])", "$1_$2");
            return Regex.Replace(split.ToLowerInvariant(), "[^a-z0-9]+", "_").Trim('_');
        }

        public static string Short(string v)
        {
            v = v.Replace("\n", "\\n");
            return v.Length > 60 ? v.Substring(0, 57) + "..." : v;
        }

        public static string Quote(string value)
        {
            return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }
    }
}
