using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaTool
{
    public enum TokenType { Name, Keyword, Number, String, Symbol, Eof }

    public sealed class Token
    {
        public TokenType Type;
        public string Text;
        public string Value;
        public int Start;
        public int End;
        public int Line;
        public int Column;
        public LuaSyntaxException Error;

        public bool Is(string value)
        {
            return (Type == TokenType.Symbol || Type == TokenType.Keyword) && Value == value;
        }

        public string Near()
        {
            if (Type == TokenType.Eof) return "<eof>";
            return Text;
        }
    }

    public sealed class Comment
    {
        public int Start;
        public int End;
        public int Line;
    }

    public sealed class LuaSyntaxException : Exception
    {
        public readonly int Line;
        public readonly int Column;

        public LuaSyntaxException(string message, int line, int column) : base(message)
        {
            Line = line;
            Column = column;
        }
    }

    public sealed class Lexer
    {
        static readonly HashSet<string> Keywords = new HashSet<string>(new[] {
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
            "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while" });

        static readonly string[] Symbols = {
            "...", "..", "==", "~=", "<=", ">=", "<<", ">>", "//", "::",
            "+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", "." };

        static readonly Regex DecimalNumber = new Regex(@"^(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$");
        static readonly Regex HexNumber = new Regex(@"^0[xX]([0-9a-fA-F]+\.?[0-9a-fA-F]*|\.[0-9a-fA-F]+)([pP][+-]?\d+)?$");

        readonly string src;
        int pos;
        int line = 1;
        int lineStart;

        public readonly List<Token> Tokens = new List<Token>();
        public readonly List<Comment> Comments = new List<Comment>();

        public Lexer(string source)
        {
            src = source;
        }

        char Cur { get { return pos < src.Length ? src[pos] : '\0'; } }

        char At(int k) { return pos + k < src.Length ? src[pos + k] : '\0'; }

        bool AtEnd { get { return pos >= src.Length; } }

        static bool IsAlpha(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; }

        static bool IsDigit(char c) { return c >= '0' && c <= '9'; }

        static bool IsHex(char c) { return IsDigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'); }

        static bool IsNewline(char c) { return c == '\n' || c == '\r'; }

        int Column(int offset) { return offset - lineStart + 1; }

        LuaSyntaxException Error(string message, string near)
        {
            string text = near == null ? message : message + " near '" + near + "'";
            return new LuaSyntaxException(text, line, Column(pos));
        }

        void NewLine()
        {
            char c = Cur;
            pos++;
            if (IsNewline(Cur) && Cur != c) pos++;
            line++;
            lineStart = pos;
        }

        public List<Token> Run()
        {
            try
            {
                Scan();
            }
            catch (LuaSyntaxException ex)
            {
                Tokens.Add(new Token { Type = TokenType.Eof, Text = "", Value = "<error>", Start = pos, End = pos, Line = ex.Line, Column = ex.Column, Error = ex });
            }
            return Tokens;
        }

        void Scan()
        {
            if (Cur == '#')
            {
                while (!AtEnd && !IsNewline(Cur)) pos++;
            }
            while (true)
            {
                SkipSpace();
                if (AtEnd)
                {
                    Tokens.Add(new Token { Type = TokenType.Eof, Text = "", Value = "<eof>", Start = pos, End = pos, Line = line, Column = Column(pos) });
                    return;
                }
                int start = pos;
                int tokLine = line;
                int tokCol = Column(pos);
                char c = Cur;
                Token tok;
                if (IsAlpha(c))
                {
                    while (IsAlpha(Cur) || IsDigit(Cur)) pos++;
                    string word = src.Substring(start, pos - start);
                    tok = new Token { Type = Keywords.Contains(word) ? TokenType.Keyword : TokenType.Name, Value = word };
                }
                else if (IsDigit(c) || (c == '.' && IsDigit(At(1))))
                {
                    tok = ReadNumber();
                }
                else if (c == '"' || c == '\'')
                {
                    tok = ReadShortString();
                }
                else if (c == '[' && (At(1) == '[' || At(1) == '='))
                {
                    int level = LongBracketLevel();
                    if (level >= 0)
                    {
                        string value = ReadLongBracket(level, "string");
                        tok = new Token { Type = TokenType.String, Value = value };
                    }
                    else if (level == -2)
                    {
                        throw Error("invalid long string delimiter", "[=");
                    }
                    else
                    {
                        pos++;
                        tok = new Token { Type = TokenType.Symbol, Value = "[" };
                    }
                }
                else
                {
                    string sym = null;
                    foreach (string s in Symbols)
                    {
                        if (string.CompareOrdinal(src, pos, s, 0, s.Length) == 0) { sym = s; break; }
                    }
                    if (sym == null)
                    {
                        throw Error("unexpected symbol", c < 32 || c > 126 ? "<\\" + ((int)c).ToString() + ">" : c.ToString());
                    }
                    pos += sym.Length;
                    tok = new Token { Type = TokenType.Symbol, Value = sym };
                }
                tok.Start = start;
                tok.End = pos;
                tok.Line = tokLine;
                tok.Column = tokCol;
                tok.Text = src.Substring(start, pos - start);
                Tokens.Add(tok);
            }
        }

        void SkipSpace()
        {
            while (!AtEnd)
            {
                char c = Cur;
                if (IsNewline(c)) { NewLine(); continue; }
                if (c == ' ' || c == '\t' || c == '\f' || c == '\v') { pos++; continue; }
                if (c == '-' && At(1) == '-')
                {
                    int start = pos;
                    int startLine = line;
                    pos += 2;
                    if (Cur == '[')
                    {
                        int level = LongBracketLevel();
                        if (level >= 0)
                        {
                            ReadLongBracket(level, "comment");
                            Comments.Add(new Comment { Start = start, End = pos, Line = startLine });
                            continue;
                        }
                    }
                    while (!AtEnd && !IsNewline(Cur)) pos++;
                    Comments.Add(new Comment { Start = start, End = pos, Line = startLine });
                    continue;
                }
                break;
            }
        }

        int LongBracketLevel()
        {
            int p = pos + 1;
            int count = 0;
            while (p < src.Length && src[p] == '=') { count++; p++; }
            if (p < src.Length && src[p] == '[') return count;
            return count == 0 ? -1 : -2;
        }

        string ReadLongBracket(int level, string what)
        {
            pos += level + 2;
            if (IsNewline(Cur)) NewLine();
            StringBuilder sb = new StringBuilder();
            while (true)
            {
                if (AtEnd) throw Error("unfinished long " + what, "<eof>");
                char c = Cur;
                if (c == ']')
                {
                    int p = pos + 1;
                    int count = 0;
                    while (p < src.Length && src[p] == '=') { count++; p++; }
                    if (count == level && p < src.Length && src[p] == ']')
                    {
                        pos = p + 1;
                        return sb.ToString();
                    }
                    sb.Append(c);
                    pos++;
                    continue;
                }
                if (IsNewline(c))
                {
                    sb.Append('\n');
                    NewLine();
                    continue;
                }
                sb.Append(c);
                pos++;
            }
        }

        Token ReadNumber()
        {
            int start = pos;
            string expo = "Ee";
            if (Cur == '.') pos++;
            char first = Cur;
            pos++;
            if (first == '0' && (Cur == 'x' || Cur == 'X') && src[start] != '.')
            {
                pos++;
                expo = "Pp";
            }
            while (true)
            {
                char c = Cur;
                if (expo.IndexOf(c) >= 0 && c != '\0')
                {
                    pos++;
                    if (Cur == '+' || Cur == '-') pos++;
                }
                else if (IsHex(c) || c == '.')
                {
                    pos++;
                }
                else break;
            }
            if (IsAlpha(Cur)) pos++;
            string text = src.Substring(start, pos - start);
            if (!DecimalNumber.IsMatch(text) && !HexNumber.IsMatch(text))
            {
                throw Error("malformed number", text);
            }
            return new Token { Type = TokenType.Number, Value = text };
        }

        Token ReadShortString()
        {
            int start = pos;
            char quote = Cur;
            pos++;
            StringBuilder sb = new StringBuilder();
            while (true)
            {
                if (AtEnd) throw Error("unfinished string", "<eof>");
                char c = Cur;
                if (c == quote) { pos++; break; }
                if (IsNewline(c)) throw Error("unfinished string", src.Substring(start, pos - start));
                if (c != '\\')
                {
                    sb.Append(c);
                    pos++;
                    continue;
                }
                pos++;
                char e = Cur;
                switch (e)
                {
                    case 'a': sb.Append('\a'); pos++; break;
                    case 'b': sb.Append('\b'); pos++; break;
                    case 'f': sb.Append('\f'); pos++; break;
                    case 'n': sb.Append('\n'); pos++; break;
                    case 'r': sb.Append('\r'); pos++; break;
                    case 't': sb.Append('\t'); pos++; break;
                    case 'v': sb.Append('\v'); pos++; break;
                    case '\\': sb.Append('\\'); pos++; break;
                    case '"': sb.Append('"'); pos++; break;
                    case '\'': sb.Append('\''); pos++; break;
                    case '\n':
                    case '\r':
                        sb.Append('\n');
                        NewLine();
                        break;
                    case 'x':
                        {
                            pos++;
                            int value = 0;
                            for (int i = 0; i < 2; i++)
                            {
                                if (!IsHex(Cur)) throw Error("hexadecimal digit expected", src.Substring(start, pos - start + (AtEnd ? 0 : 1)));
                                value = value * 16 + Convert.ToInt32(Cur.ToString(), 16);
                                pos++;
                            }
                            sb.Append((char)value);
                            break;
                        }
                    case 'z':
                        pos++;
                        while (!AtEnd)
                        {
                            if (IsNewline(Cur)) { NewLine(); continue; }
                            if (Cur == ' ' || Cur == '\t' || Cur == '\f' || Cur == '\v') { pos++; continue; }
                            break;
                        }
                        break;
                    case 'u':
                        {
                            pos++;
                            if (Cur != '{') throw Error("missing '{' in \\u{xxxx}", src.Substring(start, pos - start + (AtEnd ? 0 : 1)));
                            pos++;
                            if (!IsHex(Cur)) throw Error("hexadecimal digit expected", src.Substring(start, pos - start + (AtEnd ? 0 : 1)));
                            long value = 0;
                            while (IsHex(Cur))
                            {
                                value = value * 16 + Convert.ToInt32(Cur.ToString(), 16);
                                if (value > 0x7FFFFFFFL) throw Error("UTF-8 value too large", src.Substring(start, pos - start + 1));
                                pos++;
                            }
                            if (Cur != '}') throw Error("missing '}' in \\u{xxxx}", src.Substring(start, pos - start + (AtEnd ? 0 : 1)));
                            pos++;
                            if (value <= 0x10FFFF && (value < 0xD800 || value > 0xDFFF)) sb.Append(char.ConvertFromUtf32((int)value));
                            else sb.Append('?');
                            break;
                        }
                    default:
                        {
                            if (!IsDigit(e))
                            {
                                if (AtEnd) throw Error("unfinished string", "<eof>");
                                throw Error("invalid escape sequence", src.Substring(start, pos - start + 1));
                            }
                            int value = 0;
                            for (int i = 0; i < 3 && IsDigit(Cur); i++)
                            {
                                value = value * 10 + (Cur - '0');
                                pos++;
                            }
                            if (value > 255) throw Error("decimal escape too large", src.Substring(start, pos - start));
                            sb.Append((char)value);
                            break;
                        }
                }
            }
            return new Token { Type = TokenType.String, Value = sb.ToString() };
        }
    }
}
