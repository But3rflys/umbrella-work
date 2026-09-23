using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;

namespace LuaTool
{
    public static class Program
    {
        const string Usage =
            "luatool: Umbrella Lua helper\n" +
            "  luatool new <file.lua> [--title \"Menu Name\"] [--prefix xx]   create a script from the template\n" +
            "  luatool migrate <file.lua> [--prefix xx]                     bring an existing script to the skill rules\n" +
            "  luatool check <file.lua>                                     syntax (Lua 5.4), localization, menu and API checks\n" +
            "  luatool check <file.lua> --log                               errors of this script from debug.log\n" +
            "  luatool syntax <file.lua>                                    syntax only\n" +
            "  luatool version                                              skill version";

        public static string Version
        {
            get
            {
                System.Version v = Assembly.GetExecutingAssembly().GetName().Version;
                return v.Major + "." + v.Minor + "." + v.Build;
            }
        }

        public static string ReadSource(string path)
        {
            return SourceFile.Read(path).Text;
        }

        public static Block Parse(string source, out Parser parser, out Lexer lexer)
        {
            lexer = new Lexer(source);
            List<Token> tokens = lexer.Run();
            parser = new Parser(tokens);
            return parser.ParseChunk();
        }

        public static void Say(string line)
        {
            if (line != null) Console.WriteLine(line);
        }

        static string ApiDir(string explicitDir)
        {
            if (explicitDir != null) return explicitDir;
            string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? ".";
            string[] candidates = {
                Path.Combine(exeDir, "..", "references", "api"),
                Path.Combine(exeDir, "references", "api"),
                Path.Combine(exeDir, "..", "umbrella-lua", "references", "api")
            };
            foreach (string c in candidates) if (Directory.Exists(c)) return Path.GetFullPath(c);
            return null;
        }

        static string SyntaxLine(string path)
        {
            try
            {
                Parser parser;
                Lexer lexer;
                Parse(ReadSource(path), out parser, out lexer);
                return "OK";
            }
            catch (LuaSyntaxException ex)
            {
                return "ERR\t" + ex.Line + "\t" + ex.Message;
            }
        }

        public static int Main(string[] args)
        {
            Console.OutputEncoding = new UTF8Encoding(false);
            try
            {
                return Dispatch(args);
            }
            catch (FileNotFoundException ex)
            {
                Console.WriteLine("ERROR: file not found: " + ex.FileName);
                return 2;
            }
            catch (DirectoryNotFoundException ex)
            {
                Console.WriteLine("ERROR: " + ex.Message);
                return 2;
            }
            catch (IOException ex)
            {
                Console.WriteLine("ERROR: " + ex.Message);
                return 2;
            }
            catch (UnauthorizedAccessException ex)
            {
                Console.WriteLine("ERROR: " + ex.Message);
                return 2;
            }
        }

        static int Dispatch(string[] args)
        {
            if (args.Length == 1 && (args[0] == "version" || args[0] == "--version"))
            {
                Console.WriteLine("umbrella-lua " + Version);
                Update.Notify(true);
                return 0;
            }
            if (args.Length < 2)
            {
                Console.WriteLine(Usage);
                return 2;
            }
            string mode = args[0];
            string file = args[1];
            string title = null, prefix = null, api = null;
            bool log = false;
            for (int i = 2; i < args.Length; i++)
            {
                switch (args[i])
                {
                    case "--title": title = i + 1 < args.Length ? args[++i] : null; break;
                    case "--prefix": prefix = i + 1 < args.Length ? args[++i] : null; break;
                    case "--api": api = i + 1 < args.Length ? args[++i] : null; break;
                    case "--log": log = true; break;
                    default:
                        Console.WriteLine("unknown option " + args[i]);
                        Console.WriteLine(Usage);
                        return 2;
                }
            }
            switch (mode)
            {
                case "new": return Done(Create(file, title, prefix));
                case "migrate": return Done(Migrator.Run(file, prefix, ApiDir(api)));
                case "check": return Done(log ? Checker.Log(file) : Checker.Run(file, ApiDir(api)));
                case "syntax":
                    Console.WriteLine(SyntaxLine(file));
                    return 0;
                case "syntax-batch":
                    foreach (string f in File.ReadAllLines(file, new UTF8Encoding(false)))
                    {
                        if (f.Trim().Length == 0) continue;
                        Console.WriteLine(f + "\t" + SyntaxLine(f));
                    }
                    return 0;
            }
            Console.WriteLine("unknown command " + mode);
            Console.WriteLine(Usage);
            return 2;
        }

        static int Done(int code)
        {
            Update.Notify(false);
            return code;
        }

        static int Create(string path, string title, string prefix)
        {
            if (File.Exists(path))
            {
                Console.WriteLine("ERROR: " + path + " already exists, use luatool migrate for an existing script");
                return 1;
            }
            string name = Path.GetFileNameWithoutExtension(path);
            if (title == null) title = Util.DefaultTitle(name);
            prefix = prefix != null ? Util.CleanPrefix(prefix) : Util.DefaultPrefix(name);
            string body = Util.Resource("template.lua").Replace("__P__", prefix).Replace("__TITLE__", title.Replace("\"", "\\\""));
            string text = Util.Resource("qlocalizer.lua").TrimEnd() + "\n\n" + body;
            string dir = Path.GetDirectoryName(Path.GetFullPath(path));
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.WriteAllText(path, text, new UTF8Encoding(false));
            Console.WriteLine("CREATED " + path + " (menu title '" + title + "', key prefix '" + prefix + "_')");
            Console.WriteLine("BODY starts at line " + Util.BodyLine(text) + ", read from there");
            return 0;
        }
    }
}
