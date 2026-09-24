using System;
using System.Collections.Generic;
using System.Linq;

namespace LuaTool
{
    public enum Kind
    {
        None, MenuLib, MenuFn, Tab2, Tab3, Group, Gear, Widget, Attach, Found, UnknownMenu,
        QLoc, QLocNew, Loc, LocGet, LocWrap, LocWrapLib, LocRegister, EnumRoot, EnumAlias, ApiFn
    }

    public sealed class TypeInfo
    {
        public Kind Kind;
        public bool Wrapped;
        public bool WrapUnknown;
        public bool GlobalRef;
        public int RefPos;
        public string Name;
        public string Module;

        public bool WrappedAfterInsert(int insertPos)
        {
            return Wrapped || (GlobalRef && RefPos > insertPos);
        }

        public static readonly TypeInfo None = new TypeInfo { Kind = Kind.None };

        public bool IsMenuObject
        {
            get
            {
                switch (Kind)
                {
                    case Kind.Tab2: case Kind.Tab3: case Kind.Group: case Kind.Gear: case Kind.Widget:
                    case Kind.Attach: case Kind.Found: case Kind.UnknownMenu:
                        return true;
                }
                return false;
            }
        }

        public TypeInfo With(Kind kind)
        {
            return new TypeInfo { Kind = kind, Wrapped = Wrapped, WrapUnknown = WrapUnknown, GlobalRef = GlobalRef, RefPos = RefPos, Name = Name, Module = Module };
        }
    }

    public sealed class Usage
    {
        public string Kind;
        public Expr Arg;
        public string Base;
        public bool Wrapped;
        public bool WrappedKnown;
        public int ArgIndex;
        public TypeInfo Receiver;
        public Expr Call;
    }

    public sealed class DictEntry
    {
        public string Lang;
        public string Path;
        public Expr Value;
    }

    public sealed class Finding
    {
        public int Line;
        public string Text;
        public string Key;
    }

    public sealed class Analysis
    {
        static readonly HashSet<string> Constructors = new HashSet<string> {
            "Switch", "Bind", "Slider", "Combo", "MultiCombo", "MultiSelect", "Input", "Label", "ColorPicker", "Button" };

        readonly Api api;
        readonly Dictionary<Expr, TypeInfo> cache = new Dictionary<Expr, TypeInfo>();
        readonly Dictionary<LocalVar, TypeInfo> locals = new Dictionary<LocalVar, TypeInfo>();
        readonly Dictionary<string, TypeInfo> fields = new Dictionary<string, TypeInfo>();
        readonly Dictionary<LocalVar, int> ids = new Dictionary<LocalVar, int>();
        Expr pendingExpr;
        string pendingBase;

        public Block Root;
        public LocalStat LocalizerStat;
        public bool CallsGlobalQLocalization;
        public LocalStat DictStat;
        public CallExpr DictCall;
        public string LocVar;
        public readonly List<string> Languages = new List<string>();
        public readonly List<DictEntry> Entries = new List<DictEntry>();
        public bool HasWrapLibrary;
        public readonly List<CallExpr> WrapCalls = new List<CallExpr>();
        public readonly Dictionary<CallExpr, TypeInfo> WrapInner = new Dictionary<CallExpr, TypeInfo>();
        public readonly Dictionary<Expr, LocalVar> CreatedInto = new Dictionary<Expr, LocalVar>();
        public readonly HashSet<LocalVar> Registered = new HashSet<LocalVar>();
        public readonly List<KeyValuePair<CallExpr, TypeInfo>> Registers = new List<KeyValuePair<CallExpr, TypeInfo>>();
        public readonly List<LocalStat> MenuAliases = new List<LocalStat>();
        Expr usageCall;
        public readonly List<Usage> Usages = new List<Usage>();
        public readonly List<Finding> ApiFindings = new List<Finding>();
        public readonly List<int> DashLines = new List<int>();
        public readonly List<StringExpr> Strings = new List<StringExpr>();
        public readonly HashSet<StringExpr> FindArgs = new HashSet<StringExpr>();
        public readonly List<Expr> RawMenuCalls = new List<Expr>();
        public readonly List<BinaryExpr> Concats = new List<BinaryExpr>();
        public readonly HashSet<string> Guarded = new HashSet<string>();
        public readonly List<CallExpr> NewCalls = new List<CallExpr>();
        public readonly Dictionary<string, int> GlobalCalls = new Dictionary<string, int>();
        public readonly Dictionary<string, int> GlobalReads = new Dictionary<string, int>();
        public readonly Dictionary<string, List<int>> LocalDecls = new Dictionary<string, List<int>>();
        public readonly Dictionary<string, int> GlobalReadPos = new Dictionary<string, int>();
        public readonly List<KeyValuePair<string, StringExpr>> GameNames = new List<KeyValuePair<string, StringExpr>>();
        public readonly List<KeyValuePair<string, LocalStat>> SelfInits = new List<KeyValuePair<string, LocalStat>>();
        public readonly List<KeyValuePair<int, string>> MenuPlaces = new List<KeyValuePair<int, string>>();
        public readonly HashSet<string> GlobalDefs = new HashSet<string>();
        public int AiBridgeUnguardedLine;
        int aiGuard;
        public bool UsesAiBridge;
        public int AiBridgeLine;
        public bool UsesPolyLine;

        public Analysis(Api api)
        {
            this.api = api;
        }

        public bool InLocalizer(Node n)
        {
            return LocalizerStat != null && n.Start >= LocalizerStat.Start && n.End <= LocalizerStat.End;
        }

        public bool InDictionary(Node n)
        {
            return DictCall != null && n.Start >= DictCall.Start && n.End <= DictCall.End;
        }

        public void Run(Block root)
        {
            Root = root;
            foreach (Stat s in root.Stats)
            {
                LocalStat ls = s as LocalStat;
                if (ls != null && ls.Vars.Count == 1 && ls.Vars[0].Name == "qLocalization" && ls.Values.Count == 1)
                {
                    CallExpr c = ls.Values[0] as CallExpr;
                    if (c != null && c.Func is ParenExpr && ((ParenExpr)c.Func).Inner is FunctionExpr)
                    {
                        LocalizerStat = ls;
                        locals[ls.Vars[0]] = new TypeInfo { Kind = Kind.QLoc };
                    }
                }
                NameExpr alias = ls != null && ls.Vars.Count == 1 && ls.Values.Count == 1 ? ls.Values[0] as NameExpr : null;
                if (alias != null && alias.Name == "Menu" && alias.Local == null && ls.Vars[0].Name != "Menu") MenuAliases.Add(ls);
            }
            VisitBlock(root);
            CheckCallbacks(root);
        }

        int Id(LocalVar v)
        {
            int id;
            if (!ids.TryGetValue(v, out id))
            {
                id = ids.Count + 1;
                ids[v] = id;
            }
            return id;
        }

        string PathKey(Expr e)
        {
            NameExpr n = e as NameExpr;
            if (n != null) return n.Local != null ? "L" + Id(n.Local) : "G" + n.Name;
            IndexExpr ix = e as IndexExpr;
            if (ix != null)
            {
                StringExpr k = ix.Key as StringExpr;
                if (k == null) return null;
                string b = PathKey(ix.Obj);
                return b == null ? null : b + "." + k.Value;
            }
            ParenExpr p = e as ParenExpr;
            if (p != null) return PathKey(p.Inner);
            return null;
        }

        public static string LastName(Expr e)
        {
            NameExpr n = e as NameExpr;
            if (n != null) return n.Name;
            IndexExpr ix = e as IndexExpr;
            if (ix != null)
            {
                StringExpr k = ix.Key as StringExpr;
                if (k != null) return k.Value;
                return LastName(ix.Obj);
            }
            MethodCallExpr m = e as MethodCallExpr;
            if (m != null) return LastName(m.Obj);
            CallExpr c = e as CallExpr;
            if (c != null) return LastName(c.Func);
            ParenExpr p = e as ParenExpr;
            if (p != null) return LastName(p.Inner);
            return null;
        }

        void Assign(Expr target, TypeInfo t)
        {
            NameExpr n = target as NameExpr;
            if (n != null && n.Local != null)
            {
                if (LocalizerStat != null && n.Local == LocalizerStat.Vars[0]) return;
                locals[n.Local] = t;
                return;
            }
            string key = PathKey(target);
            if (key != null) fields[key] = t;
        }

        void VisitBlock(Block b)
        {
            if (b == null) return;
            int saved = aiGuard;
            foreach (Stat s in b.Stats)
            {
                VisitStat(s);
                IfStat exit = s as IfStat;
                if (exit != null && exit.Conds.Count == 1 && exit.Else == null && Mentions(exit.Conds[0], "ai_bridge")
                    && exit.Blocks[0].Stats.Count > 0 && exit.Blocks[0].Stats[exit.Blocks[0].Stats.Count - 1] is ReturnStat)
                    aiGuard++;
            }
            aiGuard = saved;
        }

        void Declare(string name, int line)
        {
            List<int> lines;
            if (!LocalDecls.TryGetValue(name, out lines)) { lines = new List<int>(); LocalDecls[name] = lines; }
            lines.Add(line);
        }

        static bool Mentions(Expr e, string name)
        {
            NameExpr n = e as NameExpr;
            if (n != null) return n.Local == null && n.Name == name;
            BinaryExpr b = e as BinaryExpr;
            if (b != null) return Mentions(b.Left, name) || Mentions(b.Right, name);
            UnaryExpr u = e as UnaryExpr;
            if (u != null) return Mentions(u.Operand, name);
            ParenExpr p = e as ParenExpr;
            if (p != null) return Mentions(p.Inner, name);
            IndexExpr ix = e as IndexExpr;
            if (ix != null) return Mentions(ix.Obj, name);
            CallExpr c = e as CallExpr;
            if (c != null)
            {
                foreach (Expr a in c.Args) if (Mentions(a, name)) return true;
                return Mentions(c.Func, name);
            }
            return false;
        }

        void VisitStat(Stat s)
        {
            if (s == LocalizerStat) return;
            LocalStat ls = s as LocalStat;
            if (ls != null)
            {
                foreach (LocalVar v in ls.Vars)
                {
                    Declare(v.Name, ls.Line);
                    if (ls.Values.Count > 0) SelfInits.Add(new KeyValuePair<string, LocalStat>(v.Name, ls));
                }
                for (int i = 0; i < ls.Values.Count; i++)
                {
                    TypeInfo t = EvalWithTarget(ls.Values[i], i < ls.Vars.Count ? ls.Vars[i].Name : null);
                    if (i < ls.Vars.Count)
                    {
                        locals[ls.Vars[i]] = t;
                        if (ls.Values[i] is CallExpr || ls.Values[i] is MethodCallExpr) CreatedInto[ls.Values[i]] = ls.Vars[i];
                    }
                    CallExpr c = ls.Values[i] as CallExpr;
                    if (t.Kind == Kind.Loc && c != null && c == DictCall && DictStat == null && ls.Vars.Count == 1)
                    {
                        DictStat = ls;
                        LocVar = ls.Vars[i].Name;
                    }
                }
                for (int i = ls.Values.Count; i < ls.Vars.Count; i++) locals[ls.Vars[i]] = TypeInfo.None;
                return;
            }
            AssignStat a = s as AssignStat;
            if (a != null)
            {
                foreach (Expr target in a.Targets)
                {
                    NameExpr global = target as NameExpr;
                    if (global != null && global.Local == null) GlobalDefs.Add(global.Name);
                    IndexExpr ix = target as IndexExpr;
                    if (ix != null)
                    {
                        Eval(ix.Obj);
                        if (!(ix.Key is StringExpr)) Eval(ix.Key);
                    }
                }
                for (int i = 0; i < a.Values.Count; i++)
                {
                    TypeInfo t = EvalWithTarget(a.Values[i], i < a.Targets.Count ? LastName(a.Targets[i]) : null);
                    if (i < a.Targets.Count) Assign(a.Targets[i], t);
                }
                return;
            }
            CallStat cs = s as CallStat;
            if (cs != null) { Eval(cs.Call); return; }
            DoStat d = s as DoStat;
            if (d != null) { VisitBlock(d.Body); return; }
            WhileStat w = s as WhileStat;
            if (w != null) { GuardCondition(w.Cond); Eval(w.Cond); VisitBlock(w.Body); return; }
            RepeatStat r = s as RepeatStat;
            if (r != null) { VisitBlock(r.Body); GuardCondition(r.Cond); Eval(r.Cond); return; }
            IfStat i2 = s as IfStat;
            if (i2 != null)
            {
                bool aiTest = i2.Conds.Any(c => Mentions(c, "ai_bridge"));
                for (int k = 0; k < i2.Conds.Count; k++)
                {
                    GuardCondition(i2.Conds[k]);
                    Eval(i2.Conds[k]);
                    if (aiTest) aiGuard++;
                    VisitBlock(i2.Blocks[k]);
                    if (aiTest) aiGuard--;
                }
                if (aiTest) aiGuard++;
                VisitBlock(i2.Else);
                if (aiTest) aiGuard--;
                return;
            }
            NumForStat nf = s as NumForStat;
            if (nf != null)
            {
                Eval(nf.From); Eval(nf.To);
                if (nf.Step != null) Eval(nf.Step);
                VisitBlock(nf.Body);
                return;
            }
            GenForStat gf = s as GenForStat;
            if (gf != null)
            {
                foreach (Expr e in gf.Iter) Eval(e);
                VisitBlock(gf.Body);
                return;
            }
            FunctionStat fs = s as FunctionStat;
            if (fs != null)
            {
                NameExpr global = fs.Target as NameExpr;
                if (global != null && global.Local == null) GlobalDefs.Add(global.Name);
                IndexExpr ix = fs.Target as IndexExpr;
                if (ix != null) Eval(ix.Obj);
                if (IsGetWrapper(fs.Func)) Assign(fs.Target, new TypeInfo { Kind = Kind.LocGet });
                VisitBlock(fs.Func.Body);
                return;
            }
            LocalFunctionStat lf = s as LocalFunctionStat;
            if (lf != null)
            {
                Declare(lf.Var.Name, lf.Line);
                if (IsGetWrapper(lf.Func)) locals[lf.Var] = new TypeInfo { Kind = Kind.LocGet };
                VisitBlock(lf.Func.Body);
                return;
            }
            ReturnStat ret = s as ReturnStat;
            if (ret != null) { foreach (Expr e in ret.Values) Eval(e); return; }
        }

        TypeInfo EvalWithTarget(Expr e, string baseName)
        {
            Expr savedExpr = pendingExpr;
            string savedBase = pendingBase;
            pendingExpr = e;
            pendingBase = baseName;
            TypeInfo t = Eval(e);
            pendingExpr = savedExpr;
            pendingBase = savedBase;
            return t;
        }

        void AddApi(Node n, string text, string key)
        {
            if (InLocalizer(n)) return;
            ApiFindings.Add(new Finding { Line = n.Line, Text = text, Key = key });
        }

        void Guard(Expr e)
        {
            NameExpr name = e as NameExpr;
            if (name != null && name.Local == null) { Guarded.Add(name.Name); return; }
            IndexExpr ix = e as IndexExpr;
            if (ix == null) return;
            NameExpr root = ix.Obj as NameExpr;
            StringExpr key = ix.Key as StringExpr;
            if (root != null && root.Local == null && key != null) Guarded.Add(root.Name + "." + key.Value);
        }

        void GuardCondition(Expr cond)
        {
            if (cond == null) return;
            Guard(cond);
            BinaryExpr b = cond as BinaryExpr;
            if (b != null && (b.Op == "and" || b.Op == "or"))
            {
                GuardCondition(b.Left);
                GuardCondition(b.Right);
            }
            if (b != null && (b.Op == "==" || b.Op == "~=") && (b.Left is NilExpr || b.Right is NilExpr))
            {
                Guard(b.Left);
                Guard(b.Right);
            }
            if (b != null && (b.Op == "==" || b.Op == "~="))
            {
                CallExpr tc = (b.Left as CallExpr) ?? (b.Right as CallExpr);
                NameExpr tf = tc != null ? tc.Func as NameExpr : null;
                if (tf != null && tf.Local == null && tf.Name == "type" && tc.Args.Count == 1) Guard(tc.Args[0]);
            }
            UnaryExpr u = cond as UnaryExpr;
            if (u != null && u.Op == "not") GuardCondition(u.Operand);
            ParenExpr p = cond as ParenExpr;
            if (p != null) GuardCondition(p.Inner);
        }

        public TypeInfo Eval(Expr e)
        {
            if (e == null) return TypeInfo.None;
            TypeInfo cached;
            if (cache.TryGetValue(e, out cached)) return cached;
            TypeInfo t = EvalCore(e);
            cache[e] = t;
            return t;
        }

        TypeInfo EvalCore(Expr e)
        {
            StringExpr str = e as StringExpr;
            if (str != null)
            {
                if (!InLocalizer(str))
                {
                    Strings.Add(str);
                    if (str.Value.IndexOf('—') >= 0 && !DashLines.Contains(str.Line)) DashLines.Add(str.Line);
                }
                return TypeInfo.None;
            }
            NameExpr n = e as NameExpr;
            if (n != null)
            {
                if (n.Local != null)
                {
                    TypeInfo lt;
                    return locals.TryGetValue(n.Local, out lt) ? lt : TypeInfo.None;
                }
                if (!InLocalizer(n) && !GlobalReads.ContainsKey(n.Name)) { GlobalReads[n.Name] = n.Line; GlobalReadPos[n.Name] = n.Start; }
                switch (n.Name)
                {
                    case "Menu": return new TypeInfo { Kind = Kind.MenuLib, Wrapped = false, GlobalRef = true, RefPos = n.Start };
                    case "Enum": return new TypeInfo { Kind = Kind.EnumRoot };
                    case "qLocalization": CallsGlobalQLocalization = true; return new TypeInfo { Kind = Kind.QLoc };
                    case "ai_bridge":
                        if (!InLocalizer(n) && !UsesAiBridge) { UsesAiBridge = true; AiBridgeLine = n.Line; }
                        return TypeInfo.None;
                }
                TypeInfo gt;
                return fields.TryGetValue("G" + n.Name, out gt) ? gt : TypeInfo.None;
            }
            IndexExpr ix = e as IndexExpr;
            if (ix != null) return EvalIndex(ix);
            CallExpr call = e as CallExpr;
            if (call != null) return EvalCall(call);
            MethodCallExpr mc = e as MethodCallExpr;
            if (mc != null) return EvalMethod(mc);
            ParenExpr p = e as ParenExpr;
            if (p != null) return Eval(p.Inner);
            BinaryExpr b = e as BinaryExpr;
            if (b != null)
            {
                if (b.Op == "and" || b.Op == "or" || b.Op == "==" || b.Op == "~=") GuardCondition(b);
                if (b.Op == ".." && b.Left is StringExpr && !InLocalizer(b)) Concats.Add(b);
                TypeInfo lt = Eval(b.Left);
                bool aiTest = (b.Op == "and" || b.Op == "or") && Mentions(b.Left, "ai_bridge");
                if (aiTest) aiGuard++;
                TypeInfo rt = Eval(b.Right);
                if (aiTest) aiGuard--;
                if (b.Op == "and") return rt;
                if (b.Op == "or") return rt.Kind != Kind.None ? rt : lt;
                return TypeInfo.None;
            }
            UnaryExpr u = e as UnaryExpr;
            if (u != null)
            {
                if (u.Op == "not") GuardCondition(u.Operand);
                Eval(u.Operand);
                return TypeInfo.None;
            }
            TableExpr t = e as TableExpr;
            if (t != null)
            {
                foreach (TableField f in t.Fields)
                {
                    if (f.Key != null) Eval(f.Key);
                    Eval(f.Value);
                }
                return TypeInfo.None;
            }
            FunctionExpr fn = e as FunctionExpr;
            if (fn != null)
            {
                bool wrapper = IsGetWrapper(fn);
                Expr savedExpr = pendingExpr;
                string savedBase = pendingBase;
                pendingExpr = null;
                pendingBase = null;
                VisitBlock(fn.Body);
                pendingExpr = savedExpr;
                pendingBase = savedBase;
                return wrapper ? new TypeInfo { Kind = Kind.LocGet } : TypeInfo.None;
            }
            return TypeInfo.None;
        }

        bool IsGetWrapper(FunctionExpr f)
        {
            if (f.Params.Count == 0 || f.Body == null || f.Body.Stats.Count != 1) return false;
            ReturnStat r = f.Body.Stats[0] as ReturnStat;
            if (r == null || r.Values.Count != 1) return false;
            CallExpr c = r.Values[0] as CallExpr;
            if (c == null || c.Args.Count == 0) return false;
            NameExpr arg = c.Args[0] as NameExpr;
            if (arg == null || arg.Local == null || !f.Params.Contains(arg.Local)) return false;
            IndexExpr fx = c.Func as IndexExpr;
            if (fx == null) return false;
            TypeInfo owner = Eval(fx.Obj);
            StringExpr k = fx.Key as StringExpr;
            return owner.Kind == Kind.Loc && k != null && (k.Value == "Get" || k.Value == "Localize");
        }

        TypeInfo EvalIndex(IndexExpr ix)
        {
            NameExpr bridge = ix.Obj as NameExpr;
            if (bridge != null && bridge.Local == null && bridge.Name == "ai_bridge" && aiGuard == 0 && AiBridgeUnguardedLine == 0 && !InLocalizer(ix))
                AiBridgeUnguardedLine = ix.Line;
            TypeInfo obj = Eval(ix.Obj);
            StringExpr key = ix.Key as StringExpr;
            if (key == null)
            {
                Eval(ix.Key);
                return TypeInfo.None;
            }
            string k = key.Value;
            switch (obj.Kind)
            {
                case Kind.EnumRoot:
                    if (api.Loaded && !api.Enums.ContainsKey(k))
                    {
                        string s = Api.Suggest(k, api.Enums.Keys);
                        AddApi(ix, "Enum." + k + " is not in the Umbrella API" + (s != null ? " (did you mean Enum." + s + "?)" : ""), "Enum." + k);
                    }
                    return new TypeInfo { Kind = Kind.EnumAlias, Name = k };
                case Kind.EnumAlias:
                    {
                        HashSet<string> values;
                        if (api.Loaded && api.Enums.TryGetValue(obj.Name, out values) && !values.Contains(k))
                        {
                            string s = Api.Suggest(k, values);
                            AddApi(ix, "Enum." + obj.Name + "." + k + " does not exist" + (s != null ? " (did you mean " + s + "?)" : ""), null);
                        }
                        return TypeInfo.None;
                    }
                case Kind.QLoc:
                    return k == "new" ? new TypeInfo { Kind = Kind.QLocNew } : TypeInfo.None;
                case Kind.Loc:
                    if (k == "Get" || k == "Localize") return new TypeInfo { Kind = Kind.LocGet };
                    if (k == "WrapLibrary") return new TypeInfo { Kind = Kind.LocWrapLib };
                    if (k == "Wrap") return new TypeInfo { Kind = Kind.LocWrap };
                    if (k == "Register") return new TypeInfo { Kind = Kind.LocRegister };
                    return TypeInfo.None;
                case Kind.MenuLib:
                    {
                        CheckModuleFunction(ix, "Menu", k);
                        TypeInfo fn = obj.With(Kind.MenuFn);
                        fn.Name = k;
                        return fn;
                    }
            }
            NameExpr root = ix.Obj as NameExpr;
            if (root != null && root.Local == null && api.Modules.ContainsKey(root.Name) && root.Name != "table" && root.Name != "Menu")
            {
                if (root.Name == "Render" && k == "PolyLine" && !InLocalizer(ix)) UsesPolyLine = true;
                if (CheckModuleFunction(ix, root.Name, k)) return new TypeInfo { Kind = Kind.ApiFn, Module = root.Name, Name = k };
                return TypeInfo.None;
            }
            string path = PathKey(ix);
            TypeInfo ft;
            if (path != null && fields.TryGetValue(path, out ft)) return ft;
            return TypeInfo.None;
        }

        bool CheckModuleFunction(Node n, string module, string fn)
        {
            if (!api.Loaded) return false;
            Dictionary<string, List<Signature>> funcs;
            if (!api.Modules.TryGetValue(module, out funcs)) return false;
            if (funcs.ContainsKey(fn)) return true;
            string s = Api.Suggest(fn, funcs.Keys);
            AddApi(n, module + "." + fn + " is not in the Umbrella API" + (s != null ? " (did you mean " + module + "." + s + "?)" : ""), module + "." + fn);
            return false;
        }

        static bool OpenEnded(List<Expr> args)
        {
            if (args.Count == 0) return false;
            Expr last = args[args.Count - 1];
            return last is CallExpr || last is MethodCallExpr || last is VarargExpr;
        }

        void AddUsage(string kind, Expr arg, string baseName, TypeInfo receiver, int index)
        {
            if (arg == null) return;
            Usages.Add(new Usage
            {
                Kind = kind,
                Arg = arg,
                Base = baseName,
                Receiver = receiver,
                Wrapped = receiver != null && receiver.Wrapped,
                WrappedKnown = receiver != null && receiver.Kind != Kind.None && !receiver.WrapUnknown,
                ArgIndex = index,
                Call = usageCall
            });
        }

        TypeInfo EvalCall(CallExpr call)
        {
            NameExpr callee = call.Func as NameExpr;
            if (callee != null && callee.Local == null && !InLocalizer(callee) && !GlobalCalls.ContainsKey(callee.Name))
                GlobalCalls[callee.Name] = callee.Line;
            TypeInfo f = Eval(call.Func);
            foreach (Expr a in call.Args) Eval(a);
            string target = call == pendingExpr ? pendingBase : null;
            usageCall = call;
            switch (f.Kind)
            {
                case Kind.QLocNew:
                    if (!InLocalizer(call) && !NewCalls.Contains(call)) NewCalls.Add(call);
                    if (DictCall == null && call.Args.Count > 0 && call.Args[0] is TableExpr && !InLocalizer(call))
                    {
                        DictCall = call;
                        ExtractDictionary((TableExpr)call.Args[0]);
                    }
                    return new TypeInfo { Kind = Kind.Loc };
                case Kind.LocWrapLib:
                    {
                        NameExpr arg = call.Args.Count > 0 ? call.Args[0] as NameExpr : null;
                        if (arg != null && arg.Name == "Menu" && arg.Local == null)
                        {
                            HasWrapLibrary = true;
                            return new TypeInfo { Kind = Kind.MenuLib, Wrapped = true };
                        }
                        return TypeInfo.None;
                    }
                case Kind.LocWrap:
                    {
                        WrapCalls.Add(call);
                        TypeInfo inner = call.Args.Count > 0 ? Eval(call.Args[0]) : TypeInfo.None;
                        WrapInner[call] = inner;
                        if (inner.Kind == Kind.None) return TypeInfo.None;
                        TypeInfo w = inner.With(inner.Kind);
                        w.Wrapped = true;
                        return w;
                    }
                case Kind.LocGet:
                    if (call.Args.Count > 0) AddUsage("get", call.Args[0], null, null, 0);
                    return TypeInfo.None;
                case Kind.LocRegister:
                    {
                        NameExpr arg = call.Args.Count > 0 ? call.Args[0] as NameExpr : null;
                        if (arg != null && arg.Local != null) Registered.Add(arg.Local);
                        if (call.Args.Count > 0) Registers.Add(new KeyValuePair<CallExpr, TypeInfo>(call, Eval(call.Args[0])));
                        return TypeInfo.None;
                    }
                case Kind.MenuFn:
                    if (f.Name == "Create")
                    {
                        if (!f.Wrapped && !InLocalizer(call)) RawMenuCalls.Add(call);
                        int count = call.Args.Count;
                        if (!InLocalizer(call) && count > 0 && call.Args.Take(Math.Min(count, 4)).All(x => x is StringExpr))
                            MenuPlaces.Add(new KeyValuePair<int, string>(call.Line, string.Join(" > ", call.Args.Take(Math.Min(count, 4)).Select(x => ((StringExpr)x).Value).ToArray())));
                        for (int i = 0; i < count; i++)
                        {
                            if (i == 4) AddUsage("name", call.Args[i], target != null ? GroupBase(target) : null, f.With(Kind.Tab3), i);
                            else AddUsage("tab", call.Args[i], null, f.With(Kind.MenuLib), i);
                        }
                        if (OpenEnded(call.Args)) return f.With(Kind.UnknownMenu);
                        if (count == 3) return f.With(Kind.Tab2);
                        if (count == 4) return f.With(Kind.Tab3);
                        if (count == 5) return f.With(Kind.Group);
                        return f.With(Kind.UnknownMenu);
                    }
                    if (f.Name == "Find")
                    {
                        if (!f.Wrapped && !InLocalizer(call)) RawMenuCalls.Add(call);
                        foreach (Expr a in call.Args)
                        {
                            StringExpr s = a as StringExpr;
                            if (s != null) FindArgs.Add(s);
                        }
                        return f.With(Kind.Found);
                    }
                    return TypeInfo.None;
                case Kind.ApiFn:
                    CheckArgCount(call, f.Module, f.Name, call.Args);
                    if (call.Args.Count >= 2 && call.Args[1] is StringExpr && !InLocalizer(call))
                    {
                        string gameKind = null;
                        if (f.Module == "NPC" && (f.Name == "GetItem" || f.Name == "HasItem")) gameKind = "item";
                        else if (f.Module == "NPC" && (f.Name == "GetAbility" || f.Name == "HasAbility")) gameKind = "ability";
                        else if (f.Module == "Ability" && f.Name == "GetLevelSpecialValueFor") gameKind = "special";
                        if (gameKind != null) GameNames.Add(new KeyValuePair<string, StringExpr>(gameKind, (StringExpr)call.Args[1]));
                    }
                    return TypeInfo.None;
            }
            return TypeInfo.None;
        }

        void CheckArgCount(Node n, string module, string fn, List<Expr> args)
        {
            List<Signature> sigs;
            Dictionary<string, List<Signature>> funcs;
            if (!api.Modules.TryGetValue(module, out funcs) || !funcs.TryGetValue(fn, out sigs)) return;
            int count = args.Count;
            bool open = OpenEnded(args);
            foreach (Signature s in sigs)
            {
                if (open ? count - 1 <= s.Max : (count >= s.Min && count <= s.Max)) return;
            }
            Signature first = sigs[0];
            string range = first.Min == first.Max ? first.Min.ToString() : first.Max == int.MaxValue ? first.Min + " or more" : first.Min + " to " + first.Max;
            AddApi(n, module + "." + fn + " takes " + range + " arguments, got " + count + ": " + first.Text, null);
        }

        static string GroupBase(string target)
        {
            return target.ToLowerInvariant().Contains("group") ? target : "group_" + target;
        }

        TypeInfo EvalMethod(MethodCallExpr mc)
        {
            TypeInfo obj = Eval(mc.Obj);
            foreach (Expr a in mc.Args) Eval(a);
            string target = mc == pendingExpr ? pendingBase : null;
            string recv = LastName(mc.Obj);
            string m = mc.Method;
            usageCall = mc;
            string objPath = PathKey(mc.Obj);
            TypeInfo methodType;
            if (objPath != null && fields.TryGetValue(objPath + "." + m, out methodType) && methodType.Kind == Kind.LocGet)
            {
                if (mc.Args.Count > 0) AddUsage("get", mc.Args[0], null, null, 0);
                return TypeInfo.None;
            }
            bool menuish = obj.IsMenuObject || (obj.Kind == Kind.None && (Constructors.Contains(m) || m == "Gear" || m == "ToolTip"));
            if (!menuish) return TypeInfo.None;
            Expr arg0 = mc.Args.Count > 0 ? mc.Args[0] : null;
            if (m == "Create")
            {
                if (obj.Kind == Kind.Tab2)
                {
                    AddUsage("tab", arg0, null, obj, 0);
                    return obj.With(Kind.Tab3);
                }
                if (obj.Kind == Kind.Tab3)
                {
                    AddUsage("name", arg0, target != null ? GroupBase(target) : null, obj, 0);
                    return obj.With(Kind.Group);
                }
                AddUsage("create", arg0, target, obj, 0);
                return obj.With(Kind.UnknownMenu);
            }
            if (Constructors.Contains(m))
            {
                AddUsage("name", arg0, target, obj, 0);
                if (m == "Combo" && mc.Args.Count > 1)
                {
                    TableExpr items = mc.Args[1] as TableExpr;
                    if (items != null)
                    {
                        string baseName = (target ?? (recv ?? "combo")) + "s";
                        foreach (TableField f in items.Fields)
                        {
                            if (f.Key == null && f.Name == null) AddUsage("item", f.Value, baseName, obj, 1);
                        }
                    }
                }
                if (m == "ColorPicker" && obj.Kind == Kind.Widget) return obj.With(Kind.Attach);
                return obj.Kind == Kind.None ? new TypeInfo { Kind = Kind.Widget, WrapUnknown = true } : obj.With(Kind.Widget);
            }
            if (m == "Gear")
            {
                AddUsage("name", arg0, "gear_" + (recv ?? "item"), obj, 0);
                return obj.Kind == Kind.None ? new TypeInfo { Kind = Kind.Gear, WrapUnknown = true } : obj.With(Kind.Gear);
            }
            if (m == "ToolTip")
            {
                AddUsage("tooltip", arg0, (recv ?? "item") + "_tip", obj, 0);
                return TypeInfo.None;
            }
            if (m == "Properties")
            {
                AddUsage("bindname", arg0, (recv ?? "key") + "_bind_name", obj, 0);
                return TypeInfo.None;
            }
            if (obj.IsMenuObject && api.Loaded && api.MenuMethods.Count > 0 && !api.MenuMethods.Contains(m) && !InLocalizer(mc))
            {
                string s = Api.Suggest(m, api.MenuMethods);
                AddApi(mc, ":" + m + " is not a menu method" + (s != null ? " (did you mean :" + s + "?)" : ""), null);
            }
            return TypeInfo.None;
        }

        void ExtractDictionary(TableExpr table)
        {
            foreach (TableField f in table.Fields)
            {
                string lang = f.Name ?? (f.Key is StringExpr ? ((StringExpr)f.Key).Value : null);
                if (lang == null) continue;
                if (!Languages.Contains(lang)) Languages.Add(lang);
                Flatten(lang, "", f.Value);
            }
        }

        void Flatten(string lang, string prefix, Expr value)
        {
            TableExpr sub = value as TableExpr;
            if (sub == null)
            {
                if (prefix.Length > 0) Entries.Add(new DictEntry { Lang = lang, Path = prefix, Value = value });
                return;
            }
            foreach (TableField f in sub.Fields)
            {
                string key = f.Name ?? (f.Key is StringExpr ? ((StringExpr)f.Key).Value : null);
                if (key == null) continue;
                Flatten(lang, prefix.Length == 0 ? key : prefix + "." + key, f.Value);
            }
        }

        void CheckCallbacks(Block root)
        {
            if (!api.Loaded || api.Callbacks.Count == 0 || root.Stats.Count == 0) return;
            ReturnStat ret = root.Stats[root.Stats.Count - 1] as ReturnStat;
            if (ret == null || ret.Values.Count == 0) return;
            List<KeyValuePair<string, Node>> names = new List<KeyValuePair<string, Node>>();
            NameExpr rn = ret.Values[0] as NameExpr;
            TableExpr rt = ret.Values[0] as TableExpr;
            if (rt != null)
            {
                foreach (TableField f in rt.Fields) if (f.Name != null) names.Add(new KeyValuePair<string, Node>(f.Name, f.Value));
            }
            else if (rn != null && rn.Local != null)
            {
                CollectCallbackNames(root, rn.Local, names);
            }
            foreach (KeyValuePair<string, Node> kv in names)
            {
                if (!kv.Key.StartsWith("On") || kv.Key.Length < 3 || !char.IsUpper(kv.Key[2])) continue;
                if (api.Callbacks.Contains(kv.Key)) continue;
                string s = Api.Suggest(kv.Key, api.Callbacks);
                AddApi(kv.Value, kv.Key + " is not a known callback, Umbrella will never call it" + (s != null ? " (did you mean " + s + "?)" : ""), null);
            }
        }

        void CollectCallbackNames(Block b, LocalVar table, List<KeyValuePair<string, Node>> names)
        {
            if (b == null) return;
            foreach (Stat s in b.Stats)
            {
                FunctionStat fs = s as FunctionStat;
                if (fs != null)
                {
                    IndexExpr ix = fs.Target as IndexExpr;
                    if (ix != null && ix.Obj is NameExpr && ((NameExpr)ix.Obj).Local == table && ix.Key is StringExpr)
                        names.Add(new KeyValuePair<string, Node>(((StringExpr)ix.Key).Value, fs));
                    continue;
                }
                AssignStat a = s as AssignStat;
                if (a != null)
                {
                    foreach (Expr t in a.Targets)
                    {
                        IndexExpr ix = t as IndexExpr;
                        if (ix != null && ix.Obj is NameExpr && ((NameExpr)ix.Obj).Local == table && ix.Key is StringExpr)
                            names.Add(new KeyValuePair<string, Node>(((StringExpr)ix.Key).Value, a));
                    }
                    continue;
                }
                DoStat d = s as DoStat;
                if (d != null) CollectCallbackNames(d.Body, table, names);
            }
        }
    }
}
