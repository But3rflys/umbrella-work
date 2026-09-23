using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace LuaTool
{
    public static class Update
    {
        const string Releases = "https://api.github.com/repos/But3rflys/umbrella-work/releases?per_page=100";
        const string Page = "https://github.com/But3rflys/umbrella-work/releases/tag/umbrella-lua-v";

        public static void Notify(bool force)
        {
            if (Environment.GetEnvironmentVariable("UMBRELLA_LUA_NO_UPDATE") == "1") return;
            try
            {
                string state = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "umbrella-lua", "update.txt");
                string today = DateTime.UtcNow.ToString("yyyy-MM-dd");
                if (!force && File.Exists(state) && File.ReadAllText(state).StartsWith(today, StringComparison.Ordinal)) return;

                string latest = null;
                Thread worker = new Thread(() => { try { latest = Latest(); } catch { } });
                worker.IsBackground = true;
                worker.Start();
                if (!worker.Join(3000)) return;

                Directory.CreateDirectory(Path.GetDirectoryName(state));
                File.WriteAllText(state, today + " " + (latest ?? "?"));
                if (latest != null && Compare(latest, Program.Version) > 0)
                    Console.WriteLine("UPDATE: umbrella-lua " + latest + " is out (installed " + Program.Version + "): " + Page + latest);
            }
            catch
            {
            }
        }

        static string Latest()
        {
            ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072;
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(Releases);
            request.UserAgent = "umbrella-lua/" + Program.Version;
            request.Accept = "application/vnd.github+json";
            request.Timeout = 2500;
            request.ReadWriteTimeout = 2500;
            string body;
            using (WebResponse response = request.GetResponse())
            using (StreamReader reader = new StreamReader(response.GetResponseStream(), Encoding.UTF8))
            {
                body = reader.ReadToEnd();
            }
            string best = null;
            foreach (Match m in Regex.Matches(body, "\"tag_name\"\\s*:\\s*\"umbrella-lua-v(\\d+\\.\\d+\\.\\d+)\""))
            {
                string v = m.Groups[1].Value;
                if (best == null || Compare(v, best) > 0) best = v;
            }
            return best;
        }

        static int Compare(string a, string b)
        {
            string[] x = a.Split('.');
            string[] y = b.Split('.');
            for (int i = 0; i < Math.Max(x.Length, y.Length); i++)
            {
                int p = i < x.Length ? int.Parse(x[i]) : 0;
                int q = i < y.Length ? int.Parse(y[i]) : 0;
                if (p != q) return p.CompareTo(q);
            }
            return 0;
        }
    }
}
