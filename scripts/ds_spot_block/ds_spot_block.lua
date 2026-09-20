local script = {}

local qLocalization = (function()
    local lib = {}
    local a = function(...) return ... end

    local state = {
        lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
        instances = {},
    }

    local setters = { ToolTip = "tooltip" }

    local helpers
    do
        helpers = {
            resolve = a(function(root, path)
                for key in path:gmatch("[^.]+") do
                    if type(root) ~= "table" then return end
                    root = root[key]
                end
                return root
            end),

            is_object = a(function(value)
                return type(value) == "table" or type(value) == "userdata"
            end),

            has_method = a(function(object, name)
                return helpers.is_object(object) and type(object[name]) == "function"
            end),

            is_menu_object = a(function(value)
                return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
            end),

            is_list = a(function(value)
                if type(value) ~= "table" or #value == 0 then return false end
                for i = 1, #value do
                    if type(value[i]) ~= "string" then return false end
                end
                return true
            end),

            is_indexed_list = a(function(object)
                return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
            end),
        }
    end

    function lib.new(translations)
        local languages = {}
        for i, name in ipairs(state.lang and state.lang:List() or {}) do
            local code = name:match("%a+")
            if code and translations[code] then
                languages[i - 1] = code
            end
        end

        local localization = {
            translations = translations,
            languages = languages,
            objects = {},
        }

        local methods
        do
            methods = {
                get_language = a(function(language_index)
                    if language_index == nil and state.lang then
                        language_index = state.lang:Get()
                    end
                    return localization.languages[language_index] or "en"
                end),

                localize = a(function(path, language_index)
                    if type(path) ~= "string" then return path end
                    local language = methods.get_language(language_index)
                    return helpers.resolve(localization.translations[language], path)
                        or helpers.resolve(localization.translations.en, path)
                        or path
                end),

                has = a(function(path)
                    if type(path) ~= "string" then return false end
                    return helpers.resolve(localization.translations.en, path) ~= nil
                        or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
                end),

                localize_items = a(function(items, language_index)
                    local result, localized = {}, false
                    for i = 1, #items do
                        local value = items[i]
                        if methods.has(value) then
                            result[i] = methods.localize(value, language_index)
                            localized = true
                        else
                            result[i] = value
                        end
                    end
                    return result, localized
                end),

                apply = a(function(object, kind, path, language_index)
                    if kind == "label" then
                        object:ForceLocalization(methods.localize(path, language_index))
                    elseif kind == "tooltip" then
                        object:ToolTip(methods.localize(path, language_index))
                    elseif kind == "items" then
                        local value = object:Get()
                        object:Update((methods.localize_items(path, language_index)))
                        object:Set(value)
                    end
                end),

                track = a(function(object, kind, path, apply_now)
                    local record = localization.objects[object]
                    if record == nil then
                        record = {}
                        localization.objects[object] = record
                    end
                    record[kind] = path
                    if apply_now then
                        methods.apply(object, kind, path)
                    end
                end),

                register = a(function(object, path)
                    if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
                        return
                    end
                    methods.track(object, "label", path, true)
                end),

                update = a(function(language_index)
                    for object, record in pairs(localization.objects) do
                        for kind, path in pairs(record) do
                            methods.apply(object, kind, path, language_index)
                        end
                    end
                end),

                wrap = a(function(target, bind_self)
                    if not helpers.is_object(target) then return target end

                    local proxy
                    proxy = setmetatable({}, {
                        __index = function(_, key)
                            local member = target[key]
                            if type(member) ~= "function" then return member end

                            return function(...)
                                local args = table.pack(...)

                                if bind_self and args[1] == proxy then
                                    table.remove(args, 1)
                                    args.n = args.n - 1
                                end

                                if key == "Switch" and args.n < 2 then
                                    args[2] = false
                                    args.n = 2
                                end

                                local name_path, item_paths

                                if setters[key] then
                                    if methods.has(args[1]) then
                                        methods.track(target, setters[key], args[1], false)
                                        args[1] = methods.localize(args[1])
                                    end
                                else
                                    local name_index = bind_self and 1 or args.n
                                    if methods.has(args[name_index]) then
                                        name_path = args[name_index]
                                    end

                                    local items_index
                                    if key == "Combo" then
                                        items_index = 2
                                    elseif key == "Update" and helpers.is_indexed_list(target) then
                                        items_index = 1
                                    end

                                    if items_index ~= nil and helpers.is_list(args[items_index]) then
                                        local items, localized = methods.localize_items(args[items_index])
                                        if localized then
                                            item_paths = args[items_index]
                                            args[items_index] = items
                                        end
                                    end
                                end

                                local results
                                if bind_self then
                                    results = table.pack(member(target, table.unpack(args, 1, args.n)))
                                else
                                    results = table.pack(member(table.unpack(args, 1, args.n)))
                                end

                                for i = 1, results.n do
                                    local result = results[i]
                                    if helpers.is_menu_object(result) then
                                        if name_path then
                                            methods.register(result, name_path)
                                        end
                                        if item_paths then
                                            methods.track(result, "items", item_paths, false)
                                            item_paths = nil
                                        end
                                        results[i] = methods.wrap(result, true)
                                    end
                                end

                                if item_paths then
                                    methods.track(target, "items", item_paths, false)
                                end

                                return table.unpack(results, 1, results.n)
                            end
                        end,

                        __newindex = function(_, key, value)
                            target[key] = value
                        end,
                    })

                    return proxy
                end),
            }
        end

        state.instances[methods] = true

        return {
            GetLanguage = methods.get_language,
            Get = methods.localize,
            Localize = methods.localize,
            Update = methods.update,
            Register = methods.register,
            Wrap = methods.wrap,
            WrapLibrary = function(library)
                return methods.wrap(library, false)
            end,
        }
    end

    if state.lang then
        state.lang:SetCallback(function(this)
            local language_index = this:Get()
            for methods in pairs(state.instances) do
                methods.update(language_index)
            end
        end, true)
    end

    return lib
end)()

local CONFIG = "ds_spot_block"
local HERO = "npc_dota_hero_dark_seer"
local VACUUM = "dark_seer_vacuum"

local SPOTS = {
    { id = "dire_medium_top",
      cast = Vector(-4677.4, 8545.9, 54.9), anchor = Vector(-4240.0, 8256.0, 64.0),
      min = Vector(-4594.8, 7904.0, -112.1), max = Vector(-3885.2, 8608.0, 366.6) },
    { id = "dire_medium_mid",
      cast = Vector(2417.3, 8351.0, 512.0), anchor = Vector(2079.9, 7896.0, 256.0),
      min = Vector(1629.2, 7524.4, 8.0), max = Vector(2530.6, 8267.6, 492.1) },
    { id = "radiant_large_left",
      cast = Vector(-8488.9, 25.9, 256.0), anchor = Vector(-8261.0, -431.2, 320.0),
      min = Vector(-8645.0, -815.2, -192.0), max = Vector(-7877.0, -47.2, 600.0) },
    { id = "radiant_small_bot",
      cast = Vector(2335.7, -8519.6, 128.0), anchor = Vector(2671.2, -8370.4, 24.0),
      min = Vector(2343.8, -8714.1, -328.0), max = Vector(2998.6, -8026.8, 360.0) },
    { id = "dire_small_top",
      cast = Vector(-3293.6, 7439.5, 128.0), anchor = Vector(-2963.9, 7412.0, 60.4),
      min = Vector(-3318.7, 7060.0, -112.1), max = Vector(-2609.0, 7764.0, 366.6) },
    { id = "large_river_bot",
      cast = Vector(4308.2, -3402.1, 128.0), anchor = Vector(4750.5, -3904.0, 136.0),
      min = Vector(4379.1, -4312.6, -360.0), max = Vector(5121.9, -3495.4, 472.0) },
    { id = "radiant_medium_left",
      cast = Vector(-4349.2, 1355.5, 256.0), anchor = Vector(-4032.0, 895.4, 279.0),
      min = Vector(-4368.0, 535.4, -512.0), max = Vector(-3696.0, 1255.4, 600.0) },
}

for _, spot in ipairs(SPOTS) do
    spot.enabled = Config.ReadInt(CONFIG, spot.id, 1) == 1
    spot.center = Vector((spot.min.x + spot.max.x) / 2, (spot.min.y + spot.max.y) / 2, spot.anchor.z)
    spot.anim = spot.enabled and 1 or 0
    spot.hover = 0
end

local function icon_of(widget, glyph)
    pcall(widget.Icon, widget, glyph)
    return widget
end

local function tip(widget, text)
    pcall(widget.ToolTip, widget, text)
    return widget
end

local localization = qLocalization.new({
    en = {
        ds_group_cast = "Cast",
        ds_group_look = "Visuals",
        ds_enable = "Enable",
        ds_extra = "Extra",
        ds_log = "Write to log",
        ds_condition = "Condition",
        ds_conditions_all = "All creeps",
        ds_conditions_strongest = "Strongest",
        ds_conditions_any = "Any creep",
        ds_conditions_none = "No condition",
        ds_key = "Key",
        ds_key_tip = "Works only when creeps are visible",
        ds_approach = "Auto approach",
        ds_approach_dist = "Approach distance",
        ds_aggro_toggle = "Aggro creeps",
        ds_icons = "Camp icons",
        ds_size = "Icon size",
        ds_lift = "Height above camp",
        ds_glow = "Bar glow",
        ds_radius = "Vacuum radius",
        ds_point = "Cast point",
        ds_creeps = "Creep rings",
        ds_stand = "Hero position",
        ds_radius_dist = "Visible from",
    },
    ru = {
        ds_group_cast = "Каст",
        ds_group_look = "Вид",
        ds_enable = "Включить",
        ds_extra = "Дополнительно",
        ds_log = "Писать в лог",
        ds_condition = "Условие",
        ds_conditions_all = "Все крипы",
        ds_conditions_strongest = "Сильнейший",
        ds_conditions_any = "Любой крип",
        ds_conditions_none = "Без условия",
        ds_key = "Клавиша",
        ds_key_tip = "Работает, только если видны крипы",
        ds_approach = "Авто-подход",
        ds_approach_dist = "Дистанция подхода",
        ds_aggro_toggle = "Агр крипов",
        ds_icons = "Значки над кемпами",
        ds_size = "Размер значка",
        ds_lift = "Высота над кемпом",
        ds_glow = "Свечение полоски",
        ds_radius = "Радиус Vacuum",
        ds_point = "Точка каста",
        ds_creeps = "Кольца на крипах",
        ds_stand = "Позиция героя",
        ds_radius_dist = "Видно с расстояния",
    },
})

local UI = localization.WrapLibrary(Menu)

local hero_tab = UI.Find("Heroes", "Hero List", "Dark Seer")
local page = hero_tab and hero_tab:Create("Spot Block") or UI.Create("Heroes", "Hero List", "Dark Seer", "Spot Block")

local g_cast = page:Create("ds_group_cast", Enum.GroupSide.Left)
local g_look = page:Create("ds_group_look", Enum.GroupSide.Right)

local enable = g_cast:Switch("ds_enable", true, "\u{f011}")
local enable_gear = (function()
    local ok, gear = pcall(enable.Gear, enable, "ds_extra")
    return ok and gear or g_cast
end)()
local write_log = enable_gear:Switch("ds_log", true, "\u{f15c}")
local condition = icon_of(g_cast:Combo("ds_condition",
    { "ds_conditions_all", "ds_conditions_strongest", "ds_conditions_any", "ds_conditions_none" }, 0), "\u{f05b}")
local bind = tip(g_cast:Bind("ds_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}"), "ds_key_tip")
local approach = g_cast:Switch("ds_approach", true, "\u{f554}")
local approach_dist = icon_of(g_cast:Slider("ds_approach_dist", 400, 3000, 1500), "\u{f337}")
local aggro = g_cast:Switch("ds_aggro_toggle", true, "\u{f255}")

local show_icons = g_look:Switch("ds_icons", true, "\u{f03e}")
local tile_size = icon_of(g_look:Slider("ds_size", 14, 40, 22, "%d px"), "\u{f065}")
local tile_lift = icon_of(g_look:Slider("ds_lift", 0, 150, 40, "%d px"), "\u{f062}")
local show_glow = g_look:Switch("ds_glow", true, "\u{f0eb}")
local show_radius = g_look:Switch("ds_radius", true, "\u{f192}")
local show_point = g_look:Switch("ds_point", true, "\u{f140}")
local show_creeps = g_look:Switch("ds_creeps", true, "\u{f1ce}")
local show_stand = g_look:Switch("ds_stand", true, "\u{f3c5}")
local radius_dist = icon_of(g_look:Slider("ds_radius_dist", 600, 5000, 1600), "\u{f06e}")

local function sync_menu()
    local on = enable:Get()
    local walk = approach:Get()
    local icons = show_icons:Get()

    approach_dist:Visible(walk)
    aggro:Visible(walk)
    tile_size:Visible(icons)
    tile_lift:Visible(icons)
    show_glow:Visible(icons)
    radius_dist:Visible(show_radius:Get() or show_point:Get() or show_creeps:Get())

    for _, widget in ipairs({ condition, bind, approach, approach_dist, aggro }) do
        pcall(widget.Disabled, widget, not on)
    end
    pcall(g_look.Disabled, g_look, not on)
end

local menu_state
local WATCHED = { enable, approach, show_icons, show_radius, show_point, show_creeps }

local function watch_menu()
    local parts = {}
    for i, widget in ipairs(WATCHED) do parts[i] = widget:Get() and "1" or "0" end
    local key = table.concat(parts)
    if key == menu_state then return end
    menu_state = key
    sync_menu()
end

watch_menu()

local ON = Color(64, 214, 108, 255)
local OFF = Color(226, 52, 52, 255)
local CARD = Color(12, 12, 14, 240)
local DIM = Color(10, 10, 12, 90)
local HOVER = Color(255, 255, 255, 30)
local FLASH = Color(255, 255, 255, 110)
local SEAM = Color(0, 0, 0, 140)
local GLOW = 0.2
local CLEAR = Color(0, 0, 0, 0)
local VIGNETTE = Color(0, 0, 0, 90)
local ALL = Enum.DrawFlags.RoundCornersAll
local TOP = Enum.DrawFlags.RoundCornersTop
local TOP_LEFT = Enum.DrawFlags.RoundCornersTopLeft
local BOTTOM = Enum.DrawFlags.RoundCornersBottom
local UV_MIN = Vec2(0.06, 0.06)
local UV_MAX = Vec2(0.94, 0.94)
local RING = Color(235, 235, 235, 255)
local DOT_SHADOW = Color(0, 0, 0, 170)

local icon, icon_loaded

local function load_icon()
    if icon_loaded then return icon end
    icon_loaded = true
    local ok, handle = pcall(Render.LoadImage, "panorama/images/spellicons/" .. VACUUM .. "_png.vtex_c")
    if ok and handle and handle ~= 0 then icon = handle end
    return icon
end

local function with_alpha(color, a)
    return Color(color.r, color.g, color.b, math.floor(color.a * math.max(0, math.min(1, a))))
end

local function world_ring(center, radius, color, thickness, segments)
    local prev_s, prev_v
    for i = 0, segments do
        local angle = i / segments * math.pi * 2
        local s, v = Render.WorldToScreen(Vector(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius, center.z))
        if i > 0 and v and prev_v then Render.Line(prev_s, s, color, thickness) end
        prev_s, prev_v = s, v
    end
end

local function ground_ring(center, radius, segments)
    local points = {}
    for i = 1, segments do
        local angle = (i - 1) / segments * math.pi * 2
        local px, py = center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius
        local ok, z = pcall(World.GetGroundZ, px, py)
        points[i] = Vector(px, py, (ok and type(z) == "number") and z or center.z)
    end
    return points
end

local function draw_loop(points, color, thickness)
    local prev_s, prev_v = Render.WorldToScreen(points[#points])
    for i = 1, #points do
        local s, v = Render.WorldToScreen(points[i])
        if v and prev_v then Render.Line(prev_s, s, color, thickness) end
        prev_s, prev_v = s, v
    end
end

local function mix(a, b, t)
    return Color(
        math.floor(a.r + (b.r - a.r) * t + 0.5),
        math.floor(a.g + (b.g - a.g) * t + 0.5),
        math.floor(a.b + (b.b - a.b) * t + 0.5),
        math.floor(a.a + (b.a - a.a) * t + 0.5))
end

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

local function ease(current, target, dt, speed)
    local value = current + (target - current) * math.min(1, dt * speed)
    if math.abs(target - value) < 0.005 then return target end
    return value
end

local function in_box(pos, spot, margin)
    return pos.x >= spot.min.x - margin and pos.x <= spot.max.x + margin
        and pos.y >= spot.min.y - margin and pos.y <= spot.max.y + margin
end

local function camp_creeps(spot, radius)
    local list = {}
    local reach = spot.center:Distance2D(spot.max) + 150
    for _, npc in ipairs(NPCs.InRadius(spot.center, reach, Enum.TeamNum.TEAM_NEUTRAL, Enum.TeamType.TEAM_FRIEND, true, true)) do
        if NPC.IsNeutral(npc) and Entity.IsAlive(npc) then
            local pos = Entity.GetAbsOrigin(npc)
            if in_box(pos, spot, 150) then
                list[#list + 1] = {
                    npc = npc,
                    pos = pos,
                    hp = Entity.GetMaxHealth(npc),
                    inside = pos:Distance2D(spot.cast) <= radius,
                }
            end
        end
    end
    table.sort(list, function(a, b) return a.hp > b.hp end)
    return list
end

local function special(ability, key, fallback)
    local ok, value = pcall(Ability.GetLevelSpecialValueFor, ability, key)
    if ok and type(value) == "number" and value > 0 then return value end
    return fallback
end

local function vacuum_state(hero)
    local ability = NPC.GetAbility(hero, VACUUM)
    if not ability or Ability.GetLevel(ability) == 0 then
        return { learned = false, radius = 400, range = 450, fill = 0 }
    end
    local cooldown = Ability.GetCooldown(ability)
    local length = Ability.GetCooldownLength(ability)
    return {
        learned = true,
        ability = ability,
        radius = special(ability, "radius", 400),
        range = Ability.GetCastRange(ability),
        castable = Ability.IsCastable(ability, NPC.GetMana(hero)),
        fill = (cooldown > 0 and length > 0) and (1 - cooldown / length) or 1,
    }
end

local function catch_ok(creeps)
    local rule = condition:Get()
    if rule == 3 then return true end
    if #creeps == 0 then return false end
    if rule == 1 then return creeps[1].inside end
    if rule == 2 then
        for _, creep in ipairs(creeps) do
            if creep.inside then return true end
        end
        return false
    end
    for _, creep in ipairs(creeps) do
        if not creep.inside then return false end
    end
    return true
end

local function call(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function log(fmt, ...)
    if write_log:Get() then Log.Write("[DS Spot Block] " .. string.format(fmt, ...)) end
end

local function caught_count(creeps)
    local caught = 0
    for _, creep in ipairs(creeps) do
        if creep.inside then caught = caught + 1 end
    end
    return caught
end

local function cast(spot, vac, creeps, dist, now)
    spot.flash = now
    Ability.CastPosition(vac.ability, spot.cast)
    log("cast %s dist=%.0f creeps=%d/%d", spot.id, dist, caught_count(creeps), #creeps)
end

local function can_act(hero)
    return Entity.IsAlive(hero) and not NPC.IsStunned(hero) and not NPC.IsSilenced(hero)
        and not NPC.IsChannellingAbility(hero)
end

local function nearest_spot(hero_pos, limit)
    local best, best_dist
    for _, spot in ipairs(SPOTS) do
        local dist = hero_pos:Distance2D(spot.cast)
        if spot.enabled and dist <= limit and (not best_dist or dist < best_dist) then
            best, best_dist = spot, dist
        end
    end
    return best, best_dist
end

local session

local function tracked_creeps(spot, radius, tracked)
    local list = camp_creeps(spot, radius)
    local seen = {}
    for _, creep in ipairs(list) do
        local index = Entity.GetIndex(creep.npc)
        seen[index] = true
        tracked[index] = creep.npc
    end
    for index, npc in pairs(tracked) do
        if not seen[index] then
            if call(Entity.IsAlive, npc) and not call(Entity.IsDormant, npc) then
                local pos = Entity.GetAbsOrigin(npc)
                if pos:Distance2D(spot.center) <= 2000 then
                    list[#list + 1] = {
                        npc = npc,
                        pos = pos,
                        hp = Entity.GetMaxHealth(npc),
                        inside = pos:Distance2D(spot.cast) <= radius,
                    }
                end
            else
                tracked[index] = nil
            end
        end
    end
    table.sort(list, function(a, b) return a.hp > b.hp end)
    return list
end

local function flat_dir(from, to)
    local dx, dy = to.x - from.x, to.y - from.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return 0, 0 end
    return dx / len, dy / len
end

local function ground_point(x, y, fallback_z)
    local z = call(World.GetGroundZ, x, y)
    return Vector(x, y, type(z) == "number" and z or fallback_z)
end

local function near_tree(pos)
    local trees = call(Trees.InRadius, pos, 90, true)
    if type(trees) == "table" and #trees > 0 then return true end
    trees = call(TempTrees.InRadius, pos, 90)
    return type(trees) == "table" and #trees > 0
end

local function walkable(pos)
    return call(GridNav.IsTraversable, pos) == true and not near_tree(pos)
end

local STAND_RINGS = { 0, 50, 100, 150, 200, 260 }

local function auto_stands(spot)
    local ox, oy = flat_dir(spot.center, spot.cast)
    local pool = {}
    for _, r in ipairs(STAND_RINGS) do
        local steps = r == 0 and 1 or 16
        for i = 0, steps - 1 do
            local angle = i / steps * math.pi * 2
            local p = ground_point(spot.cast.x + math.cos(angle) * r, spot.cast.y + math.sin(angle) * r, spot.cast.z)
            if walkable(p) then
                local outward = (p.x - spot.cast.x) * ox + (p.y - spot.cast.y) * oy
                pool[#pool + 1] = { pos = p, score = r - outward * 0.8 + (in_box(p, spot, 0) and 400 or 0) }
            end
        end
    end
    table.sort(pool, function(a, b) return a.score < b.score end)
    local stands = {}
    for i = 1, math.min(6, #pool) do stands[i] = pool[i].pos end
    return stands
end

local function next_auto_stand(session_state)
    local list = session_state.auto
    session_state.auto_index = (session_state.auto_index or 0) + 1
    return list[session_state.auto_index]
end

local ARRIVE = 60
local STUCK_TIME = 0.9
local WAIT_LIMIT = 4

local function move(hero, hero_pos, pos, now, stuck_time)
    if hero_pos:Distance2D(pos) <= ARRIVE then
        session.progress_pos = nil
        return "arrived"
    end
    local retarget = not session.move_to or session.move_to:Distance2D(pos) > 1
    if retarget or not session.progress_pos or hero_pos:Distance2D(session.progress_pos) > 25 then
        session.progress_pos = hero_pos
        session.progress_at = now
    elseif now - session.progress_at > stuck_time then
        return "stuck"
    end
    if retarget or now - session.last_move > 0.5 then
        session.move_to = pos
        session.last_move = now
        NPC.MoveTo(hero, pos)
    end
    return "moving"
end

local function go_stand(hero, hero_pos, now)
    if not session.stand then return "arrived" end
    local state = move(hero, hero_pos, session.stand, now, STUCK_TIME)
    if state ~= "stuck" then return state end

    session.move_to, session.progress_pos = nil, nil
    session.stand = next_auto_stand(session)
    return session.stand and "moving" or "arrived"
end

local function aggro_step(hero, creeps, now)
    local target = session.target
    if not target or not call(Entity.IsAlive, target) or call(Entity.IsDormant, target) then
        target = creeps[1].npc
        session.target = target
        session.target_hp = Entity.GetHealth(target)
        session.aggro_start = now
        session.swing = nil
        log("aggro %s", session.spot.id)
    end

    if Entity.GetHealth(target) < session.target_hp
        or (session.swing and now - session.swing > 1.2)
        or now - session.aggro_start > 5 then
        session.aggroed = now
        return false
    end

    if not session.swing and NPC.IsAttacking(hero) then session.swing = now end
    if now - (session.last_attack or 0) > 0.3 then
        session.last_attack = now
        session.move_to = nil
        Player.AttackTarget(Players.GetLocal(), hero, target)
    end
    return true
end

local function bind_logic(hero, hero_pos, vac, now)
    if not bind:IsDown() then
        session = nil
        return
    end
    if session and session.done then return end
    if not vac.learned or not vac.castable or not can_act(hero) then return end

    if not session then
        local limit = approach:Get() and math.max(approach_dist:Get(), vac.range) or vac.range
        local spot = nearest_spot(hero_pos, limit)
        if not spot then return end
        session = { spot = spot, tracked = {}, last_move = 0 }
        if approach:Get() then
            session.auto = auto_stands(spot)
            session.stand = next_auto_stand(session)
        end
    end

    local spot = session.spot
    local dist = hero_pos:Distance2D(spot.cast)
    local creeps = tracked_creeps(spot, vac.radius, session.tracked)
    local ready = catch_ok(creeps)

    if ready and (dist <= vac.range or approach:Get()) then
        session.done = true
        cast(spot, vac, creeps, dist, now)
        return
    end
    if not approach:Get() then return end

    if not ready and #creeps > 0 and not session.aggroed and aggro:Get() then
        if aggro_step(hero, creeps, now) then
            session.wait_start = nil
            session.progress_pos = nil
            return
        end
    end

    local state = go_stand(hero, hero_pos, now)
    if state == "moving" then
        session.wait_start = nil
        return
    end

    session.wait_start = session.wait_start or now
    if now - session.wait_start < WAIT_LIMIT then return end

    session.done = true
    if caught_count(creeps) > 0 then
        log("partial %s", spot.id)
        cast(spot, vac, creeps, dist, now)
    else
        log("give up %s", spot.id)
    end
end

local hits = {}

local function draw_ground(spot, hero_pos, vac)
    local ring_on, point_on, creeps_on = show_radius:Get(), show_point:Get(), show_creeps:Get()
    if spot.anim <= 0.01 or not (ring_on or point_on or creeps_on) then return end
    local dist = hero_pos:Distance2D(spot.cast)
    local fade = clamp01((radius_dist:Get() - dist) / 300) * spot.anim
    if fade <= 0 then return end

    local creeps = camp_creeps(spot, vac.radius)
    local base = catch_ok(creeps) and ON or RING

    if ring_on then
        if spot.ring_radius ~= vac.radius then
            spot.ring = ground_ring(spot.cast, vac.radius, 72)
            spot.ring_radius = vac.radius
        end
        local reach = vac.learned and dist <= vac.range
        draw_loop(spot.ring, with_alpha(base, (reach and 0.85 or 0.4) * fade), reach and 2 or 1.5)
    end

    if creeps_on then
        for _, creep in ipairs(creeps) do
            world_ring(creep.pos, 22, with_alpha(creep.inside and ON or OFF, 0.8 * fade), 1.5, 24)
        end
    end

    if point_on then
        local s, v = Render.WorldToScreen(spot.cast)
        if v then
            Render.FilledCircle(s, 4, with_alpha(DOT_SHADOW, fade))
            Render.FilledCircle(s, 2.5, with_alpha(base, fade))
        end
    end
end

local function draw_glow(x0, y0, x1, y1, color, strength, r, size)
    local layers = math.max(3, math.floor(size * 0.2 + 0.5))
    local total = 0
    for i = 1, layers do
        local k = 1 - (i - 1) / layers
        total = total + k * k
    end
    for i = layers, 1, -1 do
        local k = 1 - (i - 1) / layers
        local a = GLOW * k * k / total * strength
        Render.FilledRect(Vec2(x0 - i, y0 - i), Vec2(x1 + i, y1 + i), with_alpha(color, a), r + i, ALL)
    end
end

local function draw_icon(spot, vac, now, dt, cx, cy)
    local anchor, visible = Render.WorldToScreen(spot.anchor)
    if not visible then
        spot.hover = 0
        return
    end

    local t = spot.anim
    local s = tile_size:Get()
    local bar_h = math.max(3, math.floor(s * 0.14 + 0.5))
    local r = math.max(2, math.floor(s * 0.16 + 0.5))
    local x = math.floor(anchor.x - s / 2)
    local top = math.floor(anchor.y - tile_lift:Get() - (s + bar_h) / 2)
    local y = top + bar_h
    local x1, y1 = x + s, y + s
    hits[#hits + 1] = { spot = spot, x = x, y = top, w = s, h = s + bar_h }

    local hovered = cx >= x and cx <= x1 and cy >= top and cy <= y1
    spot.hover = ease(spot.hover, hovered and 1 or 0, dt, 16)

    local bar = mix(OFF, ON, t)
    local cooling = spot.enabled and vac.learned and vac.fill < 1
    local w = cooling and math.max(r, math.floor(s * vac.fill + 0.5)) or s
    if show_glow:Get() then draw_glow(x, top, x + w, y, bar, cooling and 0.45 or 1, r, s) end

    Render.FilledRect(Vec2(x, top), Vec2(x1, y1), CARD, r, ALL)

    if load_icon() then
        local tint = math.floor(150 + 105 * t)
        Render.Image(icon, Vec2(x, y), Vec2(s, s), Color(tint, tint, tint, 255),
            r, BOTTOM, UV_MIN, UV_MAX, 1 - t)
    end
    if t < 1 then
        Render.FilledRect(Vec2(x, y), Vec2(x1, y1), with_alpha(DIM, 1 - t), r, BOTTOM)
    end
    Render.Gradient(Vec2(x, y + math.floor(s * 0.55)), Vec2(x1, y1), CLEAR, CLEAR, VIGNETTE, VIGNETTE, r, BOTTOM)

    local flags = w >= s and TOP or TOP_LEFT
    Render.FilledRect(Vec2(x, top), Vec2(x + w, y), cooling and with_alpha(bar, 0.55) or bar, r, flags)
    Render.FilledRect(Vec2(x, y), Vec2(x1, y + 1), SEAM)

    if spot.hover > 0 then
        Render.FilledRect(Vec2(x, top), Vec2(x1, y1), with_alpha(HOVER, spot.hover), r, ALL)
    end

    if spot.flash then
        local k = 1 - (now - spot.flash) / 0.5
        if k > 0 then
            Render.FilledRect(Vec2(x, y), Vec2(x1, y1), with_alpha(FLASH, k), r, BOTTOM)
        else
            spot.flash = nil
        end
    end
end

local function local_ds()
    local hero = Heroes.GetLocal()
    if not hero or NPC.GetUnitName(hero) ~= HERO then return nil end
    return hero
end

function script.OnUpdate()
    if not enable:Get() then return end
    local hero = local_ds()
    if not hero then return end
    bind_logic(hero, Entity.GetAbsOrigin(hero), vacuum_state(hero), GlobalVars.GetCurTime())
end

function script.OnFrame()
    if Menu.Opened() then watch_menu() end
end

function script.OnDraw()
    hits = {}
    if not enable:Get() then return end
    local hero = local_ds()
    if not hero then return end

    local ok, frame = pcall(GlobalVars.GetAbsFrameTime)
    local dt = (ok and type(frame) == "number") and math.min(0.1, math.max(0, frame)) or 0.016
    local hero_pos = Entity.GetAbsOrigin(hero)
    local vac = vacuum_state(hero)
    local now = GlobalVars.GetCurTime()
    local cx, cy = Input.GetCursorPos()

    for _, spot in ipairs(SPOTS) do
        spot.anim = ease(spot.anim, spot.enabled and 1 or 0, dt, 12)
    end
    for _, spot in ipairs(SPOTS) do draw_ground(spot, hero_pos, vac) end
    if show_stand:Get() and session and session.stand and not session.done then
        world_ring(session.stand, 18, with_alpha(RING, 0.7), 1.5, 20)
    end
    if show_icons:Get() then
        for _, spot in ipairs(SPOTS) do draw_icon(spot, vac, now, dt, cx, cy) end
    end
end

local function spot_under_cursor()
    local cx, cy = Input.GetCursorPos()
    for i = #hits, 1, -1 do
        local h = hits[i]
        if cx >= h.x and cx <= h.x + h.w and cy >= h.y and cy <= h.y + h.h then
            return h.spot
        end
    end
end

local function menu_under_cursor()
    if not Menu.Opened() then return false end
    local cx, cy = Input.GetCursorPos()
    local pos, size = Menu.Pos(), Menu.Size()
    return cx >= pos.x and cx <= pos.x + size.x and cy >= pos.y and cy <= pos.y + size.y
end

local last_toggle = 0

function script.OnKeyEvent(data)
    if data.key ~= Enum.ButtonCode.KEY_MOUSE1 or data.event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then return true end
    if not enable:Get() or #hits == 0 or menu_under_cursor() then return true end

    local spot = spot_under_cursor()
    if not spot then return true end

    local now = (os and os.clock) and os.clock() or GlobalVars.GetCurTime()
    if now - last_toggle > 0.2 then
        last_toggle = now
        spot.enabled = not spot.enabled
        Config.WriteInt(CONFIG, spot.id, spot.enabled and 1 or 0)
    end
    return false
end

function script.OnGameEnd()
    hits = {}
    session = nil
end

return script
