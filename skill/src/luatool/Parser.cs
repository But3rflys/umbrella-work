using System;
using System.Collections.Generic;

namespace LuaTool
{
    public sealed class Parser
    {
        const int MaxVars = 200;
        const int MaxUpvalues = 255;

        sealed class LabelInfo
        {
            public string Name;
            public int Line;
            public int NActVar;
        }

        sealed class GotoInfo
        {
            public string Name;
            public int Line;
            public int NActVar;
        }

        sealed class BlockScope
        {
            public BlockScope Parent;
            public int ActStart;
            public bool IsLoop;
            public List<LabelInfo> Labels = new List<LabelInfo>();
            public List<GotoInfo> Gotos = new List<GotoInfo>();
        }

        sealed class FuncState
        {
            public FuncState Parent;
            public List<LocalVar> Active = new List<LocalVar>();
            public int Pending;
            public BlockScope Block;
            public bool IsVararg;
            public bool IsMain;
            public int Line;
            public int MaxDeclared;
            public HashSet<LocalVar> Upvalues = new HashSet<LocalVar>();
            public bool UsesEnv;
            public int UpvalueCount { get { return Upvalues.Count + (UsesEnv ? 1 : 0); } }
        }

        readonly List<Token> toks;
        int p;
        FuncState fs;
        readonly LocalVar envVar = new LocalVar { Name = "_ENV", Hidden = true };

        public int MainMaxLocals;
        public readonly List<KeyValuePair<int, int>> FunctionMaxLocals = new List<KeyValuePair<int, int>>();

        public Parser(List<Token> tokens)
        {
            toks = tokens;
        }

        Token Cur { get { return toks[p]; } }

        Token Next()
        {
            Token t = toks[p];
            if (p < toks.Count - 1)
            {
                p++;
                if (toks[p].Error != null) throw toks[p].Error;
            }
            return t;
        }

        Token LookAhead
        {
            get
            {
                Token t = p + 1 < toks.Count ? toks[p + 1] : toks[toks.Count - 1];
                if (t.Error != null) throw t.Error;
                return t;
            }
        }

        int CurLine
        {
            get
            {
                Token t = Cur;
                if (t.Type == TokenType.String && t.Text != null)
                {
                    int n = 0;
                    for (int i = 0; i < t.Text.Length; i++)
                    {
                        if (t.Text[i] == '\n') n++;
                        else if (t.Text[i] == '\r' && (i + 1 >= t.Text.Length || t.Text[i + 1] != '\n')) n++;
                    }
                    return t.Line + n;
                }
                return t.Line;
            }
        }

        LuaSyntaxException SyntaxError(string message)
        {
            Token t = Cur;
            string near = t.Type == TokenType.Eof ? "<eof>" : "'" + t.Text + "'";
            return new LuaSyntaxException(message + " near " + near, CurLine, t.Column);
        }

        LuaSyntaxException SemError(string message)
        {
            return new LuaSyntaxException(message, CurLine, Cur.Column);
        }

        static string Quote(string what)
        {
            return what == "<eof>" || what == "<name>" ? what : "'" + what + "'";
        }

        bool Test(string value)
        {
            if (Cur.Is(value)) { Next(); return true; }
            return false;
        }

        void Check(string value)
        {
            if (!Cur.Is(value)) throw SyntaxError(Quote(value) + " expected");
        }

        void CheckNext(string value)
        {
            Check(value);
            Next();
        }

        void CheckMatch(string what, string who, int line)
        {
            if (Test(what)) return;
            if (line == CurLine) throw SyntaxError(Quote(what) + " expected");
            throw SyntaxError(Quote(what) + " expected (to close " + Quote(who) + " at line " + line + ")");
        }

        string CheckName()
        {
            if (Cur.Type != TokenType.Name) throw SyntaxError("<name> expected");
            return Next().Value;
        }

        bool BlockFollow(bool withUntil)
        {
            Token t = Cur;
            if (t.Type == TokenType.Eof) return true;
            if (t.Type != TokenType.Keyword) return false;
            switch (t.Value)
            {
                case "else":
                case "elseif":
                case "end":
                    return true;
                case "until":
                    return withUntil;
            }
            return false;
        }

        T Mark<T>(T node, Token first) where T : Node
        {
            node.Start = first.Start;
            node.Line = first.Line;
            node.End = toks[Math.Max(0, p - 1)].End;
            return node;
        }

        void OpenFunction(bool isMain, int line)
        {
            FuncState f = new FuncState { Parent = fs, IsMain = isMain, Line = line };
            fs = f;
            EnterBlock(false);
        }

        void CloseFunction()
        {
            LeaveBlock();
            if (fs.IsMain) MainMaxLocals = fs.MaxDeclared;
            else FunctionMaxLocals.Add(new KeyValuePair<int, int>(fs.Line, fs.MaxDeclared));
            fs = fs.Parent;
        }

        void EnterBlock(bool isLoop)
        {
            fs.Block = new BlockScope { Parent = fs.Block, ActStart = fs.Active.Count, IsLoop = isLoop };
        }

        void LeaveBlock()
        {
            BlockScope bl = fs.Block;
            fs.Active.RemoveRange(bl.ActStart, fs.Active.Count - bl.ActStart);
            if (bl.IsLoop)
            {
                LabelInfo breakLabel = new LabelInfo { Name = "break", Line = 0, NActVar = fs.Active.Count };
                SolveGotos(bl, breakLabel);
            }
            fs.Block = bl.Parent;
            if (bl.Parent != null)
            {
                foreach (GotoInfo g in bl.Gotos)
                {
                    g.NActVar = bl.ActStart;
                    bl.Parent.Gotos.Add(g);
                }
            }
            else if (bl.Gotos.Count > 0)
            {
                GotoInfo g = bl.Gotos[0];
                if (g.Name == "break") throw SemError("break outside a loop at line " + g.Line);
                throw SemError("no visible label '" + g.Name + "' for <goto> at line " + g.Line);
            }
        }

        void SolveGotos(BlockScope bl, LabelInfo label)
        {
            for (int i = 0; i < bl.Gotos.Count; )
            {
                GotoInfo g = bl.Gotos[i];
                if (g.Name == label.Name)
                {
                    if (g.NActVar < label.NActVar)
                    {
                        string varName = g.NActVar < fs.Active.Count ? fs.Active[g.NActVar].Name : "?";
                        throw SemError("<goto " + g.Name + "> at line " + g.Line + " jumps into the scope of local '" + varName + "'");
                    }
                    bl.Gotos.RemoveAt(i);
                }
                else i++;
            }
        }

        LabelInfo FindLabel(string name)
        {
            for (BlockScope b = fs.Block; b != null; b = b.Parent)
            {
                foreach (LabelInfo l in b.Labels)
                {
                    if (l.Name == name) return l;
                }
            }
            return null;
        }

        LocalVar DeclareLocal(string name, int line, bool hidden)
        {
            int declared = fs.Active.Count + fs.Pending + 1;
            if (declared > MaxVars)
            {
                string where = fs.IsMain ? "main function" : "function at line " + fs.Line;
                throw SyntaxError("too many local variables (limit is " + MaxVars + ") in " + where);
            }
            fs.Pending++;
            if (declared > fs.MaxDeclared) fs.MaxDeclared = declared;
            return new LocalVar { Name = name, Line = line, Hidden = hidden };
        }

        void Activate(LocalVar v)
        {
            fs.Pending--;
            fs.Active.Add(v);
        }

        LocalVar Resolve(string name, FuncState f, out bool isUpvalue)
        {
            isUpvalue = false;
            for (int i = f.Active.Count - 1; i >= 0; i--)
            {
                if (f.Active[i].Name == name && !f.Active[i].Hidden) return f.Active[i];
            }
            if (f.Parent == null) return null;
            bool dummy;
            LocalVar outer = Resolve(name, f.Parent, out dummy);
            if (outer != null)
            {
                isUpvalue = true;
                AddUpvalue(f, outer);
            }
            return outer;
        }

        void AddUpvalue(FuncState f, LocalVar v)
        {
            if (f.Upvalues.Contains(v)) return;
            f.Upvalues.Add(v);
            if (f.UpvalueCount > MaxUpvalues)
            {
                throw SyntaxError("too many upvalues (limit is " + MaxUpvalues + ") in function at line " + f.Line);
            }
        }

        void UseEnv(FuncState f)
        {
            for (FuncState x = f; x != null && !x.IsMain; x = x.Parent)
            {
                if (x.UsesEnv) return;
                x.UsesEnv = true;
                if (x.UpvalueCount > MaxUpvalues) throw SyntaxError("too many upvalues (limit is " + MaxUpvalues + ") in function at line " + x.Line);
            }
        }

        public Block ParseChunk()
        {
            if (toks[0].Error != null) throw toks[0].Error;
            OpenFunction(true, 0);
            fs.IsVararg = true;
            Token first = Cur;
            Block block = new Block();
            StatList(block);
            if (Cur.Type != TokenType.Eof) throw SyntaxError("<eof> expected");
            Mark(block, first);
            CloseFunction();
            return block;
        }

        void StatList(Block block)
        {
            while (!BlockFollow(true))
            {
                if (Cur.Is("return"))
                {
                    block.Stats.Add(Statement());
                    return;
                }
                block.Stats.Add(Statement());
            }
        }

        Block ParseBlock()
        {
            Token first = Cur;
            EnterBlock(false);
            Block block = new Block();
            StatList(block);
            LeaveBlock();
            return Mark(block, first);
        }

        Stat Statement()
        {
            Token first = Cur;
            int line = Cur.Line;
            if (Cur.Type == TokenType.Eof) throw SyntaxError("unexpected symbol");
            switch (Cur.Value)
            {
                case ";":
                    if (Cur.Type != TokenType.Symbol) break;
                    Next();
                    return Mark(new EmptyStat(), first);
                case "if":
                    if (Cur.Type != TokenType.Keyword) break;
                    return IfStatement(first, line);
                case "while":
                    if (Cur.Type != TokenType.Keyword) break;
                    {
                        Next();
                        WhileStat w = new WhileStat();
                        w.Cond = Expression();
                        EnterBlock(true);
                        CheckNext("do");
                        w.Body = ParseBlock();
                        CheckMatch("end", "while", line);
                        LeaveBlock();
                        return Mark(w, first);
                    }
                case "do":
                    if (Cur.Type != TokenType.Keyword) break;
                    {
                        Next();
                        DoStat d = new DoStat();
                        d.Body = ParseBlock();
                        CheckMatch("end", "do", line);
                        return Mark(d, first);
                    }
                case "for":
                    if (Cur.Type != TokenType.Keyword) break;
                    return ForStatement(first, line);
                case "repeat":
                    if (Cur.Type != TokenType.Keyword) break;
                    {
                        Next();
                        RepeatStat r = new RepeatStat();
                        EnterBlock(true);
                        EnterBlock(false);
                        Token bodyFirst = Cur;
                        Block body = new Block();
                        StatList(body);
                        r.Body = Mark(body, bodyFirst);
                        CheckMatch("until", "repeat", line);
                        r.Cond = Expression();
                        LeaveBlock();
                        LeaveBlock();
                        return Mark(r, first);
                    }
                case "function":
                    if (Cur.Type != TokenType.Keyword) break;
                    return FunctionStatement(first, line);
                case "local":
                    if (Cur.Type != TokenType.Keyword) break;
                    Next();
                    if (Test("function")) return LocalFunction(first);
                    return LocalStatement(first);
                case "::":
                    if (Cur.Type != TokenType.Symbol) break;
                    Next();
                    return LabelStatement(first, CheckName(), line);
                case "return":
                    if (Cur.Type != TokenType.Keyword) break;
                    {
                        Next();
                        ReturnStat ret = new ReturnStat();
                        if (!BlockFollow(true) && !Cur.Is(";")) ret.Values = ExprList();
                        Test(";");
                        return Mark(ret, first);
                    }
                case "break":
                    if (Cur.Type != TokenType.Keyword) break;
                    Next();
                    fs.Block.Gotos.Add(new GotoInfo { Name = "break", Line = line, NActVar = fs.Active.Count });
                    return Mark(new BreakStat(), first);
                case "goto":
                    if (Cur.Type != TokenType.Keyword) break;
                    {
                        Next();
                        string name = CheckName();
                        LabelInfo label = FindLabel(name);
                        if (label == null) fs.Block.Gotos.Add(new GotoInfo { Name = name, Line = line, NActVar = fs.Active.Count });
                        return Mark(new GotoStat { Label = name }, first);
                    }
            }
            return ExprStatement(first);
        }

        Stat IfStatement(Token first, int line)
        {
            IfStat s = new IfStat();
            Next();
            s.Conds.Add(Expression());
            CheckNext("then");
            s.Blocks.Add(ParseBlock());
            while (Cur.Is("elseif"))
            {
                Next();
                s.Conds.Add(Expression());
                CheckNext("then");
                s.Blocks.Add(ParseBlock());
            }
            if (Test("else")) s.Else = ParseBlock();
            CheckMatch("end", "if", line);
            return Mark(s, first);
        }

        Stat ForStatement(Token first, int line)
        {
            Next();
            EnterBlock(true);
            Token nameTok = Cur;
            string name = CheckName();
            Stat result;
            if (Cur.Is("="))
            {
                NumForStat f = new NumForStat();
                LocalVar[] hidden = { DeclareLocal("(for state)", line, true), DeclareLocal("(for state)", line, true), DeclareLocal("(for state)", line, true) };
                LocalVar v = DeclareLocal(name, nameTok.Line, false);
                Next();
                f.From = Expression();
                CheckNext(",");
                f.To = Expression();
                if (Test(",")) f.Step = Expression();
                foreach (LocalVar h in hidden) Activate(h);
                CheckNext("do");
                EnterBlock(false);
                Activate(v);
                f.Var = v;
                f.Body = ParseBlock();
                LeaveBlock();
                result = f;
            }
            else if (Cur.Is(",") || Cur.Is("in"))
            {
                GenForStat g = new GenForStat();
                LocalVar[] hidden = { DeclareLocal("(for state)", line, true), DeclareLocal("(for state)", line, true), DeclareLocal("(for state)", line, true), DeclareLocal("(for state)", line, true) };
                g.Vars.Add(DeclareLocal(name, nameTok.Line, false));
                while (Test(","))
                {
                    Token t = Cur;
                    g.Vars.Add(DeclareLocal(CheckName(), t.Line, false));
                }
                CheckNext("in");
                g.Iter = ExprList();
                foreach (LocalVar h in hidden) Activate(h);
                CheckNext("do");
                EnterBlock(false);
                foreach (LocalVar v in g.Vars) Activate(v);
                g.Body = ParseBlock();
                LeaveBlock();
                result = g;
            }
            else
            {
                throw SyntaxError("'=' or 'in' expected");
            }
            CheckMatch("end", "for", line);
            LeaveBlock();
            return Mark(result, first);
        }

        Stat FunctionStatement(Token first, int line)
        {
            Next();
            FunctionStat s = new FunctionStat();
            Token nameTok = Cur;
            Expr target = SingleVar(CheckName(), nameTok);
            while (Cur.Is("."))
            {
                Next();
                Token keyTok = Cur;
                string key = CheckName();
                target = Mark(new IndexExpr { Obj = target, Key = Mark(new StringExpr { Value = key, Raw = key }, keyTok), Dot = true }, nameTok);
            }
            if (Cur.Is(":"))
            {
                Next();
                Token keyTok = Cur;
                string key = CheckName();
                target = Mark(new IndexExpr { Obj = target, Key = Mark(new StringExpr { Value = key, Raw = key }, keyTok), Dot = true }, nameTok);
                s.IsMethod = true;
            }
            s.Target = target;
            s.Func = FunctionBody(s.IsMethod, line, first);
            return Mark(s, first);
        }

        Stat LocalFunction(Token first)
        {
            Token nameTok = Cur;
            LocalFunctionStat s = new LocalFunctionStat();
            s.Var = DeclareLocal(CheckName(), nameTok.Line, false);
            Activate(s.Var);
            s.Func = FunctionBody(false, first.Line, first);
            return Mark(s, first);
        }

        Stat LocalStatement(Token first)
        {
            LocalStat s = new LocalStat();
            bool hasClose = false;
            do
            {
                Token nameTok = Cur;
                LocalVar v = DeclareLocal(CheckName(), nameTok.Line, false);
                if (Test("<"))
                {
                    string attr = CheckName();
                    CheckNext(">");
                    if (attr == "const") v.Attrib = "const";
                    else if (attr == "close")
                    {
                        if (hasClose) throw SemError("multiple to-be-closed variables in local list");
                        hasClose = true;
                        v.Attrib = "close";
                    }
                    else throw SemError("unknown attribute '" + attr + "'");
                }
                s.Vars.Add(v);
            } while (Test(","));
            if (Test("=")) s.Values = ExprList();
            foreach (LocalVar v in s.Vars) Activate(v);
            return Mark(s, first);
        }

        Stat LabelStatement(Token first, string name, int line)
        {
            CheckNext("::");
            List<Stat> skipped = new List<Stat>();
            while (Cur.Is(";") || Cur.Is("::")) skipped.Add(Statement());
            LabelInfo existing = FindLabel(name);
            if (existing != null) throw SemError("label '" + name + "' already defined on line " + existing.Line);
            LabelInfo label = new LabelInfo { Name = name, Line = line, NActVar = BlockFollow(false) ? fs.Block.ActStart : fs.Active.Count };
            fs.Block.Labels.Add(label);
            SolveGotos(fs.Block, label);
            LabelStat stat = Mark(new LabelStat { Label = name }, first);
            return stat;
        }

        Stat ExprStatement(Token first)
        {
            Expr e = SuffixedExpr();
            if (Cur.Is("=") || Cur.Is(","))
            {
                AssignStat a = new AssignStat();
                a.Targets.Add(CheckAssignable(e));
                while (Test(","))
                {
                    a.Targets.Add(CheckAssignable(SuffixedExpr()));
                }
                CheckNext("=");
                a.Values = ExprList();
                return Mark(a, first);
            }
            if (!(e is CallExpr) && !(e is MethodCallExpr)) throw SyntaxError("syntax error");
            return Mark(new CallStat { Call = e }, first);
        }

        Expr CheckAssignable(Expr e)
        {
            if (e is NameExpr)
            {
                LocalVar v = ((NameExpr)e).Local;
                if (v != null && (v.Attrib == "const" || v.Attrib == "close"))
                {
                    throw SemError("attempt to assign to const variable '" + v.Name + "'");
                }
                return e;
            }
            if (e is IndexExpr) return e;
            throw SyntaxError("syntax error");
        }

        FunctionExpr FunctionBody(bool isMethod, int line, Token first)
        {
            FunctionExpr f = new FunctionExpr();
            OpenFunction(false, line);
            CheckNext("(");
            if (isMethod)
            {
                LocalVar self = DeclareLocal("self", line, false);
                Activate(self);
                f.Params.Add(self);
            }
            if (!Cur.Is(")"))
            {
                do
                {
                    if (Cur.Type == TokenType.Name)
                    {
                        Token t = Cur;
                        LocalVar v = DeclareLocal(CheckName(), t.Line, false);
                        Activate(v);
                        f.Params.Add(v);
                    }
                    else if (Cur.Is("..."))
                    {
                        Next();
                        f.IsVararg = true;
                    }
                    else throw SyntaxError("<name> or '...' expected");
                } while (!f.IsVararg && Test(","));
            }
            fs.IsVararg = f.IsVararg;
            CheckNext(")");
            Token bodyFirst = Cur;
            Block body = new Block();
            StatList(body);
            f.Body = Mark(body, bodyFirst);
            CheckMatch("end", "function", line);
            CloseFunction();
            return Mark(f, first);
        }

        List<Expr> ExprList()
        {
            List<Expr> list = new List<Expr>();
            list.Add(Expression());
            while (Test(",")) list.Add(Expression());
            return list;
        }

        Expr SingleVar(string name, Token tok)
        {
            bool upvalue;
            LocalVar v = Resolve(name, fs, out upvalue);
            if (v == null)
            {
                bool envUp;
                LocalVar env = Resolve("_ENV", fs, out envUp);
                if (env == null) UseEnv(fs);
            }
            return Mark(new NameExpr { Name = name, Local = v }, tok);
        }

        Expr PrimaryExpr()
        {
            Token first = Cur;
            if (Cur.Type == TokenType.Name) return SingleVar(Next().Value, first);
            if (Cur.Is("("))
            {
                int line = Cur.Line;
                Next();
                Expr inner = Expression();
                CheckMatch(")", "(", line);
                return Mark(new ParenExpr { Inner = inner }, first);
            }
            throw SyntaxError("unexpected symbol");
        }

        Expr SuffixedExpr()
        {
            Token first = Cur;
            Expr e = PrimaryExpr();
            while (true)
            {
                if (Cur.Is("."))
                {
                    Next();
                    Token keyTok = Cur;
                    string key = CheckName();
                    e = Mark(new IndexExpr { Obj = e, Key = Mark(new StringExpr { Value = key, Raw = key }, keyTok), Dot = true }, first);
                }
                else if (Cur.Is("["))
                {
                    Next();
                    Expr key = Expression();
                    CheckNext("]");
                    e = Mark(new IndexExpr { Obj = e, Key = key }, first);
                }
                else if (Cur.Is(":"))
                {
                    Next();
                    string method = CheckName();
                    MethodCallExpr m = new MethodCallExpr { Obj = e, Method = method };
                    m.Args = CallArgs();
                    e = Mark(m, first);
                }
                else if (Cur.Is("(") || Cur.Is("{") || Cur.Type == TokenType.String)
                {
                    CallExpr c = new CallExpr { Func = e };
                    c.Args = CallArgs();
                    e = Mark(c, first);
                }
                else return e;
            }
        }

        List<Expr> CallArgs()
        {
            List<Expr> args = new List<Expr>();
            Token first = Cur;
            if (Cur.Type == TokenType.String)
            {
                Next();
                args.Add(Mark(new StringExpr { Value = first.Value, Raw = first.Text }, first));
                return args;
            }
            if (Cur.Is("{"))
            {
                args.Add(TableConstructor());
                return args;
            }
            if (Cur.Is("("))
            {
                int line = Cur.Line;
                Next();
                if (!Cur.Is(")")) args = ExprList();
                CheckMatch(")", "(", line);
                return args;
            }
            throw SyntaxError("function arguments expected");
        }

        Expr TableConstructor()
        {
            Token first = Cur;
            int line = Cur.Line;
            CheckNext("{");
            TableExpr t = new TableExpr();
            do
            {
                if (Cur.Is("}")) break;
                TableField field = new TableField { Start = Cur.Start };
                if (Cur.Type == TokenType.Name && LookAhead.Is("="))
                {
                    field.Name = Next().Value;
                    Next();
                    field.Value = Expression();
                }
                else if (Cur.Is("["))
                {
                    Next();
                    field.Key = Expression();
                    CheckNext("]");
                    CheckNext("=");
                    field.Value = Expression();
                }
                else
                {
                    field.Value = Expression();
                }
                t.Fields.Add(field);
            } while (Test(",") || Test(";"));
            CheckMatch("}", "{", line);
            return Mark(t, first);
        }

        Expr SimpleExpr()
        {
            Token first = Cur;
            switch (Cur.Type)
            {
                case TokenType.Number:
                    Next();
                    return Mark(new NumberExpr { Text = first.Text }, first);
                case TokenType.String:
                    Next();
                    return Mark(new StringExpr { Value = first.Value, Raw = first.Text }, first);
                case TokenType.Keyword:
                    switch (Cur.Value)
                    {
                        case "nil": Next(); return Mark(new NilExpr(), first);
                        case "true": Next(); return Mark(new BoolExpr { Value = true }, first);
                        case "false": Next(); return Mark(new BoolExpr { Value = false }, first);
                        case "function":
                            Next();
                            return FunctionBody(false, first.Line, first);
                    }
                    break;
                case TokenType.Symbol:
                    if (Cur.Value == "...")
                    {
                        if (!fs.IsVararg) throw SyntaxError("cannot use '...' outside a vararg function");
                        Next();
                        return Mark(new VarargExpr(), first);
                    }
                    if (Cur.Value == "{") return TableConstructor();
                    break;
            }
            return SuffixedExpr();
        }

        static int UnaryPriority = 12;

        static bool BinaryPriority(Token t, out int left, out int right)
        {
            left = right = 0;
            if (t.Type != TokenType.Symbol && t.Type != TokenType.Keyword) return false;
            switch (t.Value)
            {
                case "+": case "-": left = right = 10; return t.Type == TokenType.Symbol;
                case "*": case "%": case "/": case "//": left = right = 11; return t.Type == TokenType.Symbol;
                case "^": left = 14; right = 13; return t.Type == TokenType.Symbol;
                case "..": left = 9; right = 8; return t.Type == TokenType.Symbol;
                case "<<": case ">>": left = right = 7; return t.Type == TokenType.Symbol;
                case "&": left = right = 6; return t.Type == TokenType.Symbol;
                case "~": left = right = 5; return t.Type == TokenType.Symbol;
                case "|": left = right = 4; return t.Type == TokenType.Symbol;
                case "==": case "~=": case "<": case "<=": case ">": case ">=": left = right = 3; return t.Type == TokenType.Symbol;
                case "and": left = right = 2; return t.Type == TokenType.Keyword;
                case "or": left = right = 1; return t.Type == TokenType.Keyword;
            }
            return false;
        }

        static bool IsUnary(Token t)
        {
            if (t.Type == TokenType.Keyword) return t.Value == "not";
            if (t.Type == TokenType.Symbol) return t.Value == "-" || t.Value == "#" || t.Value == "~";
            return false;
        }

        Expr Expression()
        {
            return SubExpr(0);
        }

        Expr SubExpr(int limit)
        {
            Token first = Cur;
            Expr e;
            if (IsUnary(Cur))
            {
                string op = Next().Value;
                Expr operand = SubExpr(UnaryPriority);
                e = Mark(new UnaryExpr { Op = op, Operand = operand }, first);
            }
            else e = SimpleExpr();
            int left, right;
            while (BinaryPriority(Cur, out left, out right) && left > limit)
            {
                string op = Next().Value;
                Expr rhs = SubExpr(right);
                e = Mark(new BinaryExpr { Op = op, Left = e, Right = rhs }, first);
            }
            return e;
        }
    }
}
