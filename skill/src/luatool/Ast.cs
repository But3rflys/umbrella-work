using System.Collections.Generic;

namespace LuaTool
{
    public abstract class Node
    {
        public int Start;
        public int End;
        public int Line;
    }

    public sealed class LocalVar
    {
        public string Name;
        public string Attrib;
        public int Line;
        public bool Hidden;
    }

    public abstract class Expr : Node { }

    public sealed class NilExpr : Expr { }
    public sealed class BoolExpr : Expr { public bool Value; }
    public sealed class NumberExpr : Expr { public string Text; }
    public sealed class VarargExpr : Expr { }

    public sealed class StringExpr : Expr
    {
        public string Value;
        public string Raw;
    }

    public sealed class NameExpr : Expr
    {
        public string Name;
        public LocalVar Local;
    }

    public sealed class IndexExpr : Expr
    {
        public Expr Obj;
        public Expr Key;
        public bool Dot;
    }

    public sealed class CallExpr : Expr
    {
        public Expr Func;
        public List<Expr> Args = new List<Expr>();
    }

    public sealed class MethodCallExpr : Expr
    {
        public Expr Obj;
        public string Method;
        public List<Expr> Args = new List<Expr>();
    }

    public sealed class ParenExpr : Expr { public Expr Inner; }

    public sealed class BinaryExpr : Expr
    {
        public string Op;
        public Expr Left;
        public Expr Right;
    }

    public sealed class UnaryExpr : Expr
    {
        public string Op;
        public Expr Operand;
    }

    public sealed class TableField
    {
        public Expr Key;
        public string Name;
        public Expr Value;
        public int Start;
    }

    public sealed class TableExpr : Expr
    {
        public List<TableField> Fields = new List<TableField>();
    }

    public sealed class FunctionExpr : Expr
    {
        public List<LocalVar> Params = new List<LocalVar>();
        public bool IsVararg;
        public Block Body;
    }

    public sealed class Block : Node
    {
        public List<Stat> Stats = new List<Stat>();
    }

    public abstract class Stat : Node { }

    public sealed class LocalStat : Stat
    {
        public List<LocalVar> Vars = new List<LocalVar>();
        public List<Expr> Values = new List<Expr>();
    }

    public sealed class AssignStat : Stat
    {
        public List<Expr> Targets = new List<Expr>();
        public List<Expr> Values = new List<Expr>();
    }

    public sealed class CallStat : Stat { public Expr Call; }
    public sealed class DoStat : Stat { public Block Body; }

    public sealed class WhileStat : Stat
    {
        public Expr Cond;
        public Block Body;
    }

    public sealed class RepeatStat : Stat
    {
        public Block Body;
        public Expr Cond;
    }

    public sealed class IfStat : Stat
    {
        public List<Expr> Conds = new List<Expr>();
        public List<Block> Blocks = new List<Block>();
        public Block Else;
    }

    public sealed class NumForStat : Stat
    {
        public LocalVar Var;
        public Expr From;
        public Expr To;
        public Expr Step;
        public Block Body;
    }

    public sealed class GenForStat : Stat
    {
        public List<LocalVar> Vars = new List<LocalVar>();
        public List<Expr> Iter = new List<Expr>();
        public Block Body;
    }

    public sealed class FunctionStat : Stat
    {
        public Expr Target;
        public bool IsMethod;
        public FunctionExpr Func;
    }

    public sealed class LocalFunctionStat : Stat
    {
        public LocalVar Var;
        public FunctionExpr Func;
    }

    public sealed class ReturnStat : Stat { public List<Expr> Values = new List<Expr>(); }
    public sealed class BreakStat : Stat { }
    public sealed class GotoStat : Stat { public string Label; }
    public sealed class LabelStat : Stat { public string Label; }
    public sealed class EmptyStat : Stat { }
}
