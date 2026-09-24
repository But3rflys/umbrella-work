using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace LuaTool
{
    public sealed class JsonObject : List<KeyValuePair<string, object>>
    {
        public object Get(string key)
        {
            foreach (KeyValuePair<string, object> kv in this) if (kv.Key == key) return kv.Value;
            return null;
        }
    }

    public static class Json
    {
        public static object Parse(string s)
        {
            int i = 0;
            return Value(s, ref i);
        }

        static void Skip(string s, ref int i)
        {
            while (i < s.Length && char.IsWhiteSpace(s[i])) i++;
        }

        static object Value(string s, ref int i)
        {
            Skip(s, ref i);
            if (i >= s.Length) throw new FormatException("unexpected end of json");
            char c = s[i];
            if (c == '{') return Obj(s, ref i);
            if (c == '[') return Arr(s, ref i);
            if (c == '"') return Str(s, ref i);
            int start = i;
            while (i < s.Length && ",}] \t\r\n".IndexOf(s[i]) < 0) i++;
            string word = s.Substring(start, i - start);
            if (word == "null") return null;
            return word;
        }

        static JsonObject Obj(string s, ref int i)
        {
            JsonObject o = new JsonObject();
            i++;
            Skip(s, ref i);
            if (i < s.Length && s[i] == '}') { i++; return o; }
            while (i < s.Length)
            {
                Skip(s, ref i);
                string key = Str(s, ref i);
                Skip(s, ref i);
                if (i >= s.Length || s[i] != ':') throw new FormatException("expected ':' at " + i);
                i++;
                o.Add(new KeyValuePair<string, object>(key, Value(s, ref i)));
                Skip(s, ref i);
                if (i < s.Length && s[i] == ',') { i++; continue; }
                if (i < s.Length && s[i] == '}') { i++; return o; }
                throw new FormatException("expected ',' or '}' at " + i);
            }
            throw new FormatException("unterminated object");
        }

        static List<object> Arr(string s, ref int i)
        {
            List<object> a = new List<object>();
            i++;
            Skip(s, ref i);
            if (i < s.Length && s[i] == ']') { i++; return a; }
            while (i < s.Length)
            {
                a.Add(Value(s, ref i));
                Skip(s, ref i);
                if (i < s.Length && s[i] == ',') { i++; continue; }
                if (i < s.Length && s[i] == ']') { i++; return a; }
                throw new FormatException("expected ',' or ']' at " + i);
            }
            throw new FormatException("unterminated array");
        }

        static string Str(string s, ref int i)
        {
            if (s[i] != '"') throw new FormatException("expected string at " + i);
            i++;
            StringBuilder sb = new StringBuilder();
            while (i < s.Length && s[i] != '"')
            {
                char c = s[i++];
                if (c != '\\') { sb.Append(c); continue; }
                char e = s[i++];
                switch (e)
                {
                    case 'n': sb.Append('\n'); break;
                    case 't': sb.Append('\t'); break;
                    case 'r': sb.Append('\r'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'u': sb.Append((char)Convert.ToInt32(s.Substring(i, 4), 16)); i += 4; break;
                    default: sb.Append(e); break;
                }
            }
            i++;
            return sb.ToString();
        }
    }

    public static class GameData
    {
        const string Usage =
            "luatool data ability <name>   ability or item: behavior, cast point, cooldown, AbilityValues\n" +
            "luatool data item <name>      item\n" +
            "luatool data unit <name>      unit or hero: abilities and stats\n" +
            "luatool data find <text>      names that contain the text\n" +
            "  --data <dir>                cheat folder or its assets/data (found from the current folder otherwise)";

        static readonly Regex Noise = new Regex(
            "^(Model|ModelScale|VersusScale|LoadoutScale|SpectatorLoadoutScale|SoundSet|IdleExpression|PickSound|BanSound|" +
            "HeroSelectSoundEffect|GibType|workshop_guide_name|LastHitChallengeRival|Adjectives|NameAliases|SimilarHeroes|" +
            "HeroOrderID|HeroUnlockOrder|new_player_enable|CMEnabled|AbilityDraftAbilities|AbilitySound|RenderablePortrait|" +
            "ItemSlots|Bot|GameSoundsFile|VoiceFile|IdleSoundLoop|particle_folder|precache|Portrait.*|.*Sound.*|.*Particle.*|" +
            "MinimapIcon.*|HealthBarOffset.*|ConsideredHero|DisableWearables|Creature|ImmuneToOmnislash|" +
            "RingRadius|HasInventory|SelectionGroup|SelectOnSpawn|IgnoreAddSummonedToSelection|Role|Rolelevels|Complexity|" +
            "party_hat_effects|showcase_attachments|FightRecapLevel|ItemDeclarations|ItemShopTags|Suggest.*)$");

        sealed class Source
        {
            public string File;
            public string Root;
            public string Kind;
            public JsonObject Entries;
        }

        public static int Run(string[] args)
        {
            string dirArg = null;
            List<string> rest = new List<string>();
            for (int i = 1; i < args.Length; i++)
            {
                if (args[i] == "--data" && i + 1 < args.Length) { dirArg = args[++i]; continue; }
                rest.Add(args[i]);
            }
            if (rest.Count < 2)
            {
                Console.WriteLine(Usage);
                return rest.Count == 0 ? 0 : 2;
            }
            string kind = rest[0].ToLowerInvariant();
            string name = string.Join(" ", rest.Skip(1).ToArray()).Trim();
            string dir = FindDir(dirArg);
            if (dir == null)
            {
                Console.WriteLine("DATA not found: run from the Umbrella scripts folder or pass --data <cheat folder>");
                return 1;
            }

            List<Source> sources = new List<Source>();
            if (kind == "ability" || kind == "find") { Load(sources, dir, "npc_abilities.json", "DOTAAbilities", "ability"); }
            if (kind == "ability" || kind == "item" || kind == "find") { Load(sources, dir, "items.json", "DOTAAbilities", "item"); }
            if (kind == "unit" || kind == "hero" || kind == "find")
            {
                Load(sources, dir, "npc_heroes.json", "DOTAHeroes", "hero");
                Load(sources, dir, "npc_units.json", "DOTAUnits", "unit");
            }
            if (sources.Count == 0)
            {
                Console.WriteLine(Usage);
                return 2;
            }

            if (kind == "find")
            {
                string needle = name.ToLowerInvariant();
                List<string> hits = new List<string>();
                foreach (Source src in sources)
                    foreach (KeyValuePair<string, object> e in src.Entries)
                        if (e.Value is JsonObject && e.Key.ToLowerInvariant().Contains(needle)) hits.Add(src.Kind + " " + e.Key);
                Console.WriteLine("FOUND " + hits.Count + " names with '" + name + "'" + (hits.Count > 60 ? ", first 60" : ""));
                foreach (string h in hits.Take(60)) Console.WriteLine(h);
                return 0;
            }

            foreach (Source src in sources)
            {
                JsonObject entry = src.Entries.Get(name) as JsonObject;
                if (entry == null) continue;
                Console.WriteLine("DATA " + src.Kind + " " + name + " (" + src.File + ")");
                List<string> lines = new List<string>();
                Print(entry, "", lines, src.Kind);
                if (src.Kind == "item") NeutralTier(dir, name, lines);
                foreach (string l in lines.Take(90)) Console.WriteLine(l);
                if (lines.Count > 90) Console.WriteLine("... " + (lines.Count - 90) + " more lines");
                string baseName = src.Kind == "hero" ? "npc_dota_hero_base" : src.Kind == "unit" ? "npc_dota_units_base" : "ability_base";
                Console.WriteLine("-- fields that are missing here come from " + baseName);
                return 0;
            }

            List<string> names = sources.SelectMany(s => s.Entries.Where(e => e.Value is JsonObject).Select(e => e.Key)).ToList();
            string lower = name.ToLowerInvariant();
            List<string> close = names.Where(n => n.ToLowerInvariant().Contains(lower)).Take(15).ToList();
            string suggest = Api.Suggest(name, names);
            if (suggest != null && !close.Contains(suggest)) close.Insert(0, suggest);
            Console.WriteLine("NOT FOUND: " + name + (close.Count > 0 ? ". Close names: " + string.Join(", ", close.ToArray()) : ". Try: luatool data find <part of the name>"));
            return 0;
        }

        public sealed class Index
        {
            public readonly HashSet<string> Abilities = new HashSet<string>();
            public readonly HashSet<string> Items = new HashSet<string>();
            public readonly HashSet<string> Units = new HashSet<string>();
            public readonly HashSet<string> Special = new HashSet<string>();
        }

        public static Index LoadIndex(string startDir)
        {
            string dir = Probe(startDir, true);
            if (dir == null) return null;
            Index index = new Index();
            List<Source> sources = new List<Source>();
            Load(sources, dir, "npc_abilities.json", "DOTAAbilities", "ability");
            Load(sources, dir, "items.json", "DOTAAbilities", "item");
            Load(sources, dir, "npc_heroes.json", "DOTAHeroes", "hero");
            Load(sources, dir, "npc_units.json", "DOTAUnits", "unit");
            foreach (Source src in sources)
            {
                foreach (KeyValuePair<string, object> e in src.Entries)
                {
                    JsonObject entry = e.Value as JsonObject;
                    if (entry == null) continue;
                    if (src.Kind == "ability") index.Abilities.Add(e.Key);
                    else if (src.Kind == "item") index.Items.Add(e.Key);
                    else index.Units.Add(e.Key);
                    JsonObject values = entry.Get("AbilityValues") as JsonObject;
                    if (values != null) foreach (KeyValuePair<string, object> v in values) index.Special.Add(v.Key);
                }
            }
            return index.Abilities.Count > 0 ? index : null;
        }

        static string FindDir(string explicitDir)
        {
            return explicitDir != null ? Probe(Path.GetFullPath(explicitDir), false) : Probe(Directory.GetCurrentDirectory(), true);
        }

        static string Probe(string start, bool walkUp)
        {
            string dir = start;
            for (int up = 0; up < 5 && dir != null; up++)
            {
                if (File.Exists(Path.Combine(dir, "npc_abilities.json"))) return dir;
                string nested = Path.Combine(dir, "assets", "data");
                if (File.Exists(Path.Combine(nested, "npc_abilities.json"))) return nested;
                if (!walkUp) break;
                dir = Path.GetDirectoryName(dir);
            }
            return null;
        }

        static void Load(List<Source> sources, string dir, string file, string root, string kind)
        {
            string path = Path.Combine(dir, file);
            if (!File.Exists(path)) return;
            JsonObject top = Json.Parse(File.ReadAllText(path, Encoding.UTF8)) as JsonObject;
            JsonObject entries = top != null ? top.Get(root) as JsonObject : null;
            if (entries != null) sources.Add(new Source { File = file, Root = root, Kind = kind, Entries = entries });
        }

        static void Print(JsonObject obj, string indent, List<string> lines, string kind)
        {
            foreach (KeyValuePair<string, object> kv in obj)
            {
                if (indent.Length == 0 && Noise.IsMatch(kv.Key)) continue;
                string text = kv.Value as string;
                if (text != null)
                {
                    if (text.Length == 0) continue;
                    lines.Add(indent + kv.Key + ": " + text);
                    continue;
                }
                JsonObject child = kv.Value as JsonObject;
                if (child == null) continue;
                if (kv.Key == "Facets")
                {
                    lines.Add(indent + "Facets: " + string.Join(", ", child.Select(c => c.Key).ToArray()));
                    continue;
                }
                if (kv.Key == "AbilityValues")
                {
                    lines.Add(indent + "AbilityValues:");
                    foreach (KeyValuePair<string, object> v in child)
                    {
                        string plain = v.Value as string;
                        JsonObject rich = v.Value as JsonObject;
                        if (plain != null) { lines.Add(indent + "  " + v.Key + ": " + plain); continue; }
                        if (rich == null) continue;
                        string value = rich.Get("value") as string;
                        List<string> extra = rich.Where(r => r.Key != "value" && r.Value is string).Select(r => r.Key + " " + r.Value).ToList();
                        lines.Add(indent + "  " + v.Key + ": " + (value ?? "") + (extra.Count > 0 ? " (" + string.Join(", ", extra.ToArray()) + ")" : ""));
                    }
                    continue;
                }
                if (indent.Length >= 4) { lines.Add(indent + kv.Key + ": {...}"); continue; }
                lines.Add(indent + kv.Key + ":");
                Print(child, indent + "  ", lines, kind);
            }
        }

        static void NeutralTier(string dir, string name, List<string> lines)
        {
            string path = Path.Combine(dir, "neutral_items.json");
            if (!File.Exists(path)) return;
            JsonObject top = Json.Parse(File.ReadAllText(path, Encoding.UTF8)) as JsonObject;
            JsonObject neutral = top != null ? top.Get("neutral_items") as JsonObject : null;
            JsonObject tiers = neutral != null ? neutral.Get("neutral_tiers") as JsonObject : null;
            if (tiers == null) return;
            foreach (KeyValuePair<string, object> tier in tiers)
            {
                JsonObject t = tier.Value as JsonObject;
                JsonObject items = t != null ? t.Get("items") as JsonObject : null;
                if (items != null && items.Get(name) != null)
                {
                    lines.Add("NeutralTier: " + tier.Key + (t.Get("start_time") is string ? " (from " + t.Get("start_time") + ")" : ""));
                    return;
                }
            }
        }
    }
}
