--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

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
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
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
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

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
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

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
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()
local localization = qLocalization.new({
	en = {
		as_group = "Auto Stack",
		as_enable = "Enable",
		as_enable_tip = "Kunkka stacks camps with Torrent\nat the right second of every minute",
		as_gear_main = "Auto Stack",
		as_debug = "Debug log",
		as_debug_tip = "Writes every state change and the reason\nfor each skipped stack to the log",
		as_mode = "When to stack",
		as_mode_tip = "Automatic stacks the best enabled camp.\nKey modes stack the chosen camp this minute",
		as_modes_auto = "Automatic",
		as_modes_toggle = "Automatic, key on and off",
		as_modes_nearest = "Key: nearest camp",
		as_modes_cursor = "Key: camp under the cursor",
		as_key = "Key",
		as_key_tip = "Turns stacking on or picks the camp,\na second press cancels",
		as_bind_name = "Auto Stack",
		as_camps = "Camp rings",
		as_camps_tip = "A ring over every camp, click it\nto turn that camp on or off",
		as_gear_camps = "Camp rings",
		as_camps_scale = "Size",
		as_camps_idle = "Idle rings",
		as_camps_idle_tip = "How visible the rings of camps\nthat aren't being stacked are",
		as_camps_blur = "Blur behind",
		as_st_fail = "No stack",
		as_st_done = "Stacked",
		as_st_blind = "Cast",
		as_st_cd = "CD %.1f",
		as_st_mana = "No mana",
		as_st_late = "won't make it",
		as_st_cast = "Casting",
		as_st_miss = "Missed",
		as_st_far = "Too far",
		as_why_late = "late %.1f s",
		as_why_early = "early %.1f s",
		as_why_hero = "hero in the camp",
		as_why_blocked = "someone else in the camp",
		as_why_partial = "not every creep hit",
		as_why_air = "in the air, no stack",
		as_why_unknown = "not seen, can't check",
		as_why_fog = "in the fog, can't check",
		as_why_blind = "blind",
		as_hits = "hit %d of %d",
		as_why_low = "creeps not above the camp box",
		as_camp_0 = "small",
		as_camp_1 = "medium",
		as_camp_2 = "large",
		as_camp_3 = "ancient",
	},
	ru = {
		as_group = "Авто-стак",
		as_enable = "Включить",
		as_enable_tip = "Кунка стакает кемпы торрентом\nв нужную секунду каждой минуты",
		as_gear_main = "Авто-стак",
		as_debug = "Отладка в лог",
		as_debug_tip = "Пишет в лог смену состояний и причину,\nпо которой стак пропущен",
		as_mode = "Когда стакать",
		as_mode_tip = "Сам стакает лучший включённый кемп.\nПо клавише стакает выбранный кемп в эту минуту",
		as_modes_auto = "Сам",
		as_modes_toggle = "Сам, клавиша вкл/выкл",
		as_modes_nearest = "Клавиша: ближайший кемп",
		as_modes_cursor = "Клавиша: кемп под курсором",
		as_key = "Клавиша",
		as_key_tip = "Включает авто-стак или выбирает кемп,\nповторное нажатие отменяет",
		as_bind_name = "Auto Stack",
		as_camps = "Кольца над кемпами",
		as_camps_tip = "Кольцо над каждым кемпом, клик по нему\nвключает и выключает кемп",
		as_gear_camps = "Кольца над кемпами",
		as_camps_scale = "Размер",
		as_camps_idle = "Кольца в покое",
		as_camps_idle_tip = "Насколько заметны кольца кемпов,\nкоторые сейчас не стакаются",
		as_camps_blur = "Размытие фона",
		as_st_fail = "Не стакнулось",
		as_st_done = "Стакнуто",
		as_st_blind = "Кинул",
		as_st_cd = "КД %.1f",
		as_st_mana = "Нет маны",
		as_st_late = "не успеет",
		as_st_cast = "Кидаю",
		as_st_miss = "Не кинул",
		as_st_far = "Далеко",
		as_why_late = "поздно на %.1f с",
		as_why_early = "рано на %.1f с",
		as_why_hero = "герой в кемпе",
		as_why_blocked = "в кемпе чужой юнит",
		as_why_partial = "задеты не все",
		as_why_air = "в воздухе, но не стакнулось",
		as_why_unknown = "не видно, не проверить",
		as_why_fog = "в тумане, не проверить",
		as_why_blind = "вслепую",
		as_hits = "задето %d из %d",
		as_why_low = "крипы не вылетели из кемпа",
		as_camp_0 = "малый",
		as_camp_1 = "средний",
		as_camp_2 = "большой",
		as_camp_3 = "древний",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local MAP = {
	["m258_m13"] = { x = -8306.3, y = -546.4, cast = 57.27, type = 2 },
	["264_38"] = { x = 8426.1, y = 1280.1, cast = 57.23, type = 0 },
	["128_2"] = { x = 4318.6, y = 61.5, cast = 57.23, type = 3 },
	["m123_155"] = { x = -3887.0, y = 4814.2, cast = 57.23, type = 0 },
	["6_m161"] = { x = 224.0, y = -5180.1, cast = 57.27, type = 3 },
	["126_m158"] = { x = 3975.2, y = -5046.2, cast = 57.27, type = 0 },
	["m61_m148"] = { x = -1984.8, y = -4836.6, cast = 57.27, type = 1 },
	["248_m2"] = { x = 7918.2, y = -122.3, cast = 57.23, type = 2 },
	["106_m38"] = { x = 3450.2, y = -1367.3, cast = 57.23, type = 1 },
	["m80_121"] = { x = -2583.5, y = 3854.3, cast = 57.23, type = 1 },
	["m24_154"] = { x = -833.7, y = 4903.6, cast = 57.27, type = 3 },
	["m47_m108"] = { x = -1443.2, y = -3343.0, cast = 57.27, type = 2 },
	["m126_28"] = { x = -4019.3, y = 988.4, cast = 57.30, type = 1 },
	["57_m126"] = { x = 1897.6, y = -3966.3, cast = 57.30, type = 1 },
	["36_128"] = { x = 1240.9, y = 4179.1, cast = 57.27, type = 1 },
	["34_79"] = { x = 1023.5, y = 2640.4, cast = 57.27, type = 2 },
	["m150_m3"] = { x = -4991.2, y = -106.0, cast = 57.27, type = 3 },
	["m24_m240"] = { x = -767.5, y = -7675.4, cast = 57.23, type = 2 },
	["m77_m262"] = { x = -2428.6, y = -8414.3, cast = 57.23, type = 1 },
	["m249_m56"] = { x = -8001.9, y = -1827.0, cast = 57.23, type = 0 },
	["10_241"] = { x = 377.3, y = 7705.3, cast = 57.27, type = 2 },
	["m152_125"] = { x = -4822.3, y = 3932.7, cast = 57.23, type = 2 },
	["148_m122"] = { x = 4655.6, y = -3730.2, cast = 57.27, type = 2 },
}

local K = {
	HERO = "npc_dota_hero_kunkka",
	ABILITY = "kunkka_torrent",
	SCAN_INTERVAL = 0.1,
	LATE_WINDOW = 0.5,
	RETRY_DELAY = 0.25,
	MAX_ATTEMPTS = 2,
	CAMP_REACH = 600,
	CURSOR_RADIUS = 900,
	BOX_PAD = 40,
	COUNT_PAD = 150,
	RESULT_LINGER = 4.0,
	GROUP_RADIUS = 700,
	AIR_HEIGHT = 20,
	EARLIEST = 45.0,
	LATEST = 59.9,
	OPEN_FROM = 45.0,
	WATCH_AFTER = 4.0,
	SPAWN_CHECK = 1.0,
	SPAWN_SEEN = 0.05,
	CONFIG = "auto_stack",
	CAMP_GRID = 32,
	SECOND = 57.25,
	TICK_HALF = 1 / 60,
	CAMP_LIST_TTL = 5.0,
	RING_H = 32,
	RING_ICON = 24,
	RING_R = 14,
	RING_W = 2,
	RING_POINTS = 64,
	ROW_LEAD = 6,
	ROW_TAIL = 12,
	ROW_GAP = 8,
	DIVIDER = 14,
	TOGGLE_W = 24,
	TOGGLE_H = 14,
	FONT = 12,
	FONT_SMALL = 11,
	WIDTH_SPEED = 26,
	WIDTH_TIME = 0.15,
	FADE_SPEED = 20,
	COLOR_SPEED = 18,
	PROG_SPEED = 30,
	ICON = "panorama/images/spellicons/kunkka_torrent_png.vtex_c",
}

local COLORS = {
	ok = { 111, 214, 111 },
	bad = { 232, 98, 90 },
	idle = { 240, 240, 242 },
	text = { 240, 240, 242 },
	muted = { 150, 154, 160 },
}

local ui = {}

local state = {
	next_scan = 0.0,
	target = nil,
	status = nil,
	logged = nil,
	done_minute = -1,
	attempts = 0,
	last_try = -100.0,
	result = nil,
	plan = nil,
	watch = nil,
	order = nil,
	armed = nil,
	camps = {},
	camp_list = nil,
	camp_list_until = 0.0,
	hover = nil,
	swallow = false,
	anim = {},
	draw_error = nil,
	fonts = nil,
	digit_w = {},
	icons = {},
}

local function log(text)
	if ui.debug and ui.debug:Get() then
		Log.Write("[Auto Stack] " .. text)
	end
end

do
	local hero_tab = UI.Find("Heroes", "Hero List", "Kunkka")
	local page = hero_tab and hero_tab:Find("Main Settings")
	if not page then
		local tab = UI.Create("Scripts", "Scripts", "Auto Stack")
		tab:Icon("\u{f5fd}")
		page = tab:Create("Settings")
	end
	local group = page:Create("as_group", Enum.GroupSide.Right)
	ui.hero_enable = Menu.Find("Heroes", "Hero List", "Kunkka", "Main Settings", "Hero Settings", "Enable")

	ui.enable = group:Switch("as_enable", false, "\u{f00c}")
	ui.enable:ToolTip("as_enable_tip")
	local g_main = ui.enable:Gear("as_gear_main")
	ui.mode = g_main:Combo("as_mode", { "as_modes_auto", "as_modes_toggle", "as_modes_nearest", "as_modes_cursor" }, 0)
	ui.mode:Icon("\u{f1de}")
	ui.mode:ToolTip("as_mode_tip")
	ui.debug = g_main:Switch("as_debug", false, "\u{f188}")
	ui.debug:ToolTip("as_debug_tip")

	ui.key = group:Bind("as_key", Enum.ButtonCode.KEY_NONE, "\u{e1c1}")
	ui.key:ToolTip("as_key_tip")

	ui.camps = group:Switch("as_camps", true, "\u{f3c5}")
	ui.camps:ToolTip("as_camps_tip")
	local g_camps = ui.camps:Gear("as_gear_camps")
	ui.camps_scale = g_camps:Slider("as_camps_scale", 80, 160, 100, "%d%%")
	ui.camps_scale:Icon("\u{f065}")
	ui.camps_idle = g_camps:Slider("as_camps_idle", 20, 100, 70, "%d%%")
	ui.camps_idle:Icon("\u{f043}")
	ui.camps_idle:ToolTip("as_camps_idle_tip")
	ui.camps_blur = g_camps:Switch("as_camps_blur", true, "\u{f042}")
end

local function active()
	return ui.enable:Get() and (not ui.hero_enable or ui.hero_enable:Get())
end

local function refresh_disabled()
	local on = ui.enable:Get()
	local mode = ui.mode:Get()
	local camps = on and ui.camps:Get()
	ui.mode:Disabled(not on)
	ui.key:Visible(mode ~= 0)
	ui.key:Disabled(not on)
	ui.camps:Disabled(not on)
	ui.camps_scale:Disabled(not camps)
	ui.camps_idle:Disabled(not camps)
	ui.camps_blur:Disabled(not camps)
	ui.debug:Disabled(not on)
	ui.key:Properties(L("as_bind_name"), nil, mode == 1)
end

ui.enable:SetCallback(refresh_disabled, true)
ui.mode:SetCallback(function()
	state.armed = nil
	refresh_disabled()
end)
ui.camps:SetCallback(refresh_disabled)

local function log_once(key, text)
	if state.logged == key then return end
	state.logged = key
	log(text)
end

local function clock()
	local t = GameRules.GetDOTATime()
	local minute = math.floor(t / 60)
	return t, minute, t - minute * 60
end

local function clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end

local function in_box(box, pos, pad)
	pad = pad or 0
	return pos.x >= box.min.x - pad and pos.x <= box.max.x + pad and pos.y >= box.min.y - pad and pos.y <= box.max.y + pad
end

local function box_center(box)
	return Vector((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, (box.min.z + box.max.z) / 2)
end

local function box_ground(box)
	local cx, cy = (box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2
	return Vector(cx, cy, World.GetGroundZ(cx, cy))
end

local function camp_name(camp_type)
	return camp_type and L("as_camp_" .. camp_type) or "?"
end

local function camp_key(box)
	local function part(v)
		local n = math.floor(v / K.CAMP_GRID + 0.5)
		return n < 0 and ("m" .. -n) or tostring(n)
	end
	return part((box.min.x + box.max.x) / 2) .. "_" .. part((box.min.y + box.max.y) / 2)
end

local function camp_data(key)
	local e = state.camps[key]
	if not e then
		local base = MAP[key]
		e = { off = Config.ReadInt(K.CONFIG, "off_" .. key, 0) == 1 }
		if base then e.sx, e.sy, e.sz = base.x, base.y, World.GetGroundZ(base.x, base.y) end
		state.camps[key] = e
	end
	return e
end

local function camp_enabled(e)
	return not e.off
end

local function camp_spot(e, box)
	if e.sx then return Vector(e.sx, e.sy, e.sz) end
	return box_ground(box)
end

local function toggle_camp(key)
	local e = camp_data(key)
	e.off = not e.off
	Config.WriteInt(K.CONFIG, "off_" .. key, e.off and 1 or 0)
	if state.armed and state.armed.key == key and e.off then state.armed = nil end
	state.next_scan = 0.0
	log(string.format("camp %s clicked: off %s", key, tostring(e.off)))
end

local function camp_list()
	local now = GameRules.GetGameTime()
	if state.camp_list and #state.camp_list > 0 and now < state.camp_list_until then return state.camp_list end
	local list = {}
	local camps = Camps.GetAll() or {}
	for i = 1, #camps do
		local box = Camp.GetCampBox(camps[i])
		local key = box and camp_key(box)
		if key and MAP[key] then
			list[#list + 1] = { camp = camps[i], box = box, key = key, center = box_ground(box), camp_type = Camp.GetType(camps[i]) }
		end
	end
	state.camp_list, state.camp_list_until = list, now + K.CAMP_LIST_TTL
	return list
end

local function find_camp(key)
	local list = camp_list()
	for i = 1, #list do
		if list[i].key == key then return list[i] end
	end
	return nil
end

local function visible_neutrals(hero, center, radius)
	local list = {}
	local units = NPCs.InRadius(center, radius, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY) or {}
	for i = 1, #units do
		local u = units[i]
		if NPC.IsNeutral(u) and Entity.IsAlive(u) and not NPC.IsWaitingToSpawn(u) and NPC.IsVisible(u) then
			list[#list + 1] = { npc = u, pos = Entity.GetAbsOrigin(u), hull = NPC.GetHullRadius(u) or 24 }
		end
	end
	return list
end

local function count_in_box(hero, box)
	local n = 0
	local units = visible_neutrals(hero, box_center(box), K.GROUP_RADIUS)
	for i = 1, #units do
		if in_box(box, units[i].pos, K.COUNT_PAD) then n = n + 1 end
	end
	return n
end

local function aoe_eval(center, radius, creeps)
	local hits, slack = {}, math.huge
	for i = 1, #creeps do
		local c = creeps[i]
		local room = radius + c.hull - math.sqrt((c.pos.x - center.x) ^ 2 + (c.pos.y - center.y) ^ 2)
		if room >= 0 then
			hits[#hits + 1] = c
			if room < slack then slack = room end
		end
	end
	return hits, slack
end

local function best_center(origin, range, radius, creeps)
	local points = {}
	local sx, sy = 0, 0
	for i = 1, #creeps do
		local a = creeps[i].pos
		sx, sy = sx + a.x, sy + a.y
		points[#points + 1] = a
		for j = i + 1, #creeps do
			local b = creeps[j].pos
			points[#points + 1] = Vector((a.x + b.x) / 2, (a.y + b.y) / 2, a.z)
		end
	end
	points[#points + 1] = Vector(sx / #creeps, sy / #creeps, creeps[1].pos.z)

	local best = nil
	for i = 1, #points do
		local p = points[i]
		local d = math.sqrt((p.x - origin.x) ^ 2 + (p.y - origin.y) ^ 2)
		local hits, slack = {}, 0
		if d <= range then hits, slack = aoe_eval(p, radius, creeps) end
		if #hits > 0 then
			local better = not best or #hits > #best.hits
				or (#hits == #best.hits and (slack > best.slack + 1 or (slack >= best.slack - 1 and d < best.dist)))
			if better then best = { pos = p, hits = hits, slack = slack, dist = d } end
		end
	end
	return best
end

local function better_target(a, b)
	if not b then return true end
	if a.fog ~= b.fog then return not a.fog end
	if a.full ~= b.full then return a.full end
	if #a.hits ~= #b.hits then return #a.hits > #b.hits end
	if a.mark ~= b.mark then return a.mark > b.mark end
	if a.fog and a.camp_type ~= b.camp_type then return (a.camp_type or 0) > (b.camp_type or 0) end
	return a.dist < b.dist
end

local function find_target(hero, ability, only)
	local origin = Entity.GetAbsOrigin(hero)
	local range = Ability.GetCastRange(ability) + (NPC.GetCastRangeBonus(hero) or 0)
	local radius = Ability.GetLevelSpecialValueFor(ability, "radius")
	local search = range + radius + K.CAMP_REACH
	local units = visible_neutrals(hero, origin, search)
	local camps = Camps.InRadius(origin, search) or {}
	local best = nil
	for i = 1, #camps do
		local box = Camp.GetCampBox(camps[i])
		if box then
			local key = camp_key(box)
			local e = camp_data(key)
			if MAP[key] and camp_enabled(e) and (not only or only == key) then
				local seen = {}
				for j = 1, #units do
					if in_box(box, units[j].pos, K.BOX_PAD) then seen[#seen + 1] = units[j] end
				end
				local ground = box_ground(box)
				local c = nil
				if #seen > 0 then
					c = best_center(origin, range, radius, seen)
					if c then c.fog, c.full = false, #c.hits == #seen end
				else
					local spot = camp_spot(e, box)
					local d = origin:Distance2D(spot)
					if d <= range then
						c = { pos = spot, hits = {}, slack = 0, dist = d, fog = true, full = true }
					end
				end
				if c then
					c.inside, c.box, c.camp, c.camp_type, c.key, c.mark = seen, box, camps[i], Camp.GetType(camps[i]), key, 1
					c.range, c.radius, c.ground = range, radius, ground
					if better_target(c, best) then best = c end
				end
			end
		end
	end
	return best
end

local function set_status(key, info)
	state.status = info
	info.key = key
	log_once(key, string.format("%s  %s", key, info.detail or ""))
end

local function box_creeps(hero, box, pad)
	local list = {}
	local units = NPCs.InRadius(box_center(box), K.GROUP_RADIUS, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY) or {}
	for i = 1, #units do
		local u = units[i]
		if NPC.IsNeutral(u) and Entity.IsAlive(u) and not NPC.IsWaitingToSpawn(u) then
			local pos = Entity.GetAbsOrigin(u)
			if in_box(box, pos, pad) then
				list[#list + 1] = { npc = u, pos = pos }
			end
		end
	end
	return list, units
end

local function latency()
	local flow = Enum.Flow
	local out = NetChannel.GetAvgLatency(flow.FLOW_OUTGOING) or 0
	local inn = NetChannel.GetAvgLatency(flow.FLOW_INCOMING) or 0
	return math.max(0, out), math.max(0, inn)
end

local function torrent_delay(ability)
	return Ability.GetLevelSpecialValueFor(ability, "delay") or 0
end

local function plan_time(hero, ability, target)
	local origin = Entity.GetAbsOrigin(hero)
	local out, inn = latency()
	local base = MAP[target.key] and MAP[target.key].cast or K.SECOND
	local order_at = clamp(base - out, K.EARLIEST, K.LATEST)
	return {
		order_at = order_at, turn = 0, travel = torrent_delay(ability), how = "map", base = base, ping_out = out, ping_in = inn,
		in_box = #target.inside, hit_in_box = #target.hits, hero_in_box = in_box(target.box, origin),
	}
end

local function start_watch(hero, ability, minute, target, sec)
	local box = target.box
	local order = state.order or { t = GameRules.GetDOTATime(), turn = 0 }
	local creeps, around = box_creeps(hero, box, 0)
	local known = {}
	for i = 1, #around do known[Entity.GetIndex(around[i])] = true end
	local hit_set = {}
	for i = 1, #target.hits do hit_set[target.hits[i].npc] = true end
	local hits = {}
	for i = 1, #target.hits do
		local c = target.hits[i]
		if NPCs.Contains(c.npc) then
			local pos = Entity.GetAbsOrigin(c.npc)
			hits[#hits + 1] = { npc = c.npc, ground = pos.z, peak = pos.z }
		end
	end
	for i = 1, #creeps do creeps[i].hit = hit_set[creeps[i].npc] or false end
	state.watch = {
		minute = minute, box = box, key = target.key, fog = target.fog, pos = target.pos, camp_type = target.camp_type,
		room = camp_data(target.key).room,
		before = count_in_box(hero, box), known = known, creeps = creeps, hits = hits,
		order = order, delay = torrent_delay(ability), cast_sec = sec, blockers = {},
		tracked = {}, fresh_seen = {}, before_seen = 0, after_seen = 0, vision_before = false, vision_after = false,
	}
	log(string.format("watch: camp %s%s, order at %.2f, turn %.2f, delay %.2f, %d hit, %d in box, %d counted before",
		target.key, target.fog and " (fog)" or "", order.t - minute * 60, order.turn, state.watch.delay, #hits, #creeps, state.watch.before))
end

local function modifier_names(npc)
	local names = {}
	local mods = NPC.GetModifiers(npc) or {}
	for i = 1, #mods do names[#names + 1] = Modifier.GetName(mods[i]) end
	return table.concat(names, ",")
end

local function finish_watch(hero, now, rel)
	local w = state.watch
	state.watch = nil
	local zero = (w.minute + 1) * 60

	local sum, count, air_len, first_start, last_end, peak, mid_sum = 0, 0, 0, nil, nil, 0, 0
	for i = 1, #w.hits do
		local c = w.hits[i]
		if c.air_start and c.air_end and not c.partial then
			local mid = (c.air_start + c.air_end) / 2
			sum = sum + (mid - w.order.t - w.order.turn - w.delay)
			mid_sum = mid_sum + (mid - zero)
			air_len = air_len + (c.air_end - c.air_start)
			count = count + 1
			peak = math.max(peak, c.peak - c.ground)
		end
		if c.air_start then first_start = math.min(first_start or math.huge, c.air_start - zero) end
		if c.air_end then last_end = math.max(last_end or -math.huge, c.air_end - zero) end
		log(string.format("flight %s: up %s, down %s, height %.0f",
			NPC.GetUnitName(c.npc) or "?",
			c.air_start and string.format("%+.2f", c.air_start - zero) or "-",
			c.air_end and string.format("%+.2f", c.air_end - zero) or "-",
			c.peak - c.ground))
	end

	if count > 0 then
		local out, inn = w.order.out or 0, w.order.inn or 0
		w.mid = mid_sum / count
		log(string.format("measured: order to mid-air %.3f s, flight %.2f s, lift %.0f, mid-air at %+.3f, ping %d+%d ms",
			sum / count, air_len / count, peak, w.mid, math.floor(out * 1000 + 0.5), math.floor(inn * 1000 + 0.5)))
	else
		log("measured: no creep flight seen")
	end

	local center = box_center(w.box)
	local after, fresh, seen = 0, 0, false
	local units = NPCs.InRadius(center, K.GROUP_RADIUS, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY) or {}
	for i = 1, #units do
		local u = units[i]
		if NPC.IsNeutral(u) and NPC.IsVisible(u) and Entity.IsAlive(u) then
			seen = true
			if in_box(w.box, Entity.GetAbsOrigin(u), K.COUNT_PAD) then
				after = after + 1
				if not w.known[Entity.GetIndex(u)] then w.fresh_seen[Entity.GetIndex(u)] = true end
			end
		end
	end
	for _ in pairs(w.fresh_seen) do fresh = fresh + 1 end
	if not seen and Entity.GetAbsOrigin(hero):Distance2D(center) < 800 then seen = true end
	local before = math.max(w.before, w.before_seen)
	after = math.max(after, w.after_seen)
	local vision = seen or w.vision_after

	local verdict, why = nil, nil
	if w.fog and not w.vision_before then
		verdict, why = "fog", L("as_why_fog")
	elseif after > before or (fresh > 0 and after >= before) then
		verdict = "ok"
	elseif not vision then
		verdict, why = w.fog and "fog" or "unknown", L(w.fog and "as_why_fog" or "as_why_unknown")
	elseif w.hero_in then
		verdict, why = "hero", L("as_why_hero")
	elseif #w.blockers > 0 then
		verdict, why = "blocked", L("as_why_blocked")
	elseif w.unhit_in_box then
		verdict, why = "partial", L("as_why_partial")
	elseif w.landed or (last_end and last_end < 0) then
		verdict, why = "early", string.format(L("as_why_early"), w.landed or -last_end)
	elseif w.not_up or not first_start or first_start > 0 then
		verdict, why = "late", string.format(L("as_why_late"), math.max(0, first_start or 0))
	elseif (w.below or 0) > 0 then
		verdict, why = "low", L("as_why_low")
	else
		verdict, why = "air_no_stack", L("as_why_air")
	end
	log(string.format("verdict %s: camp %s%s, creeps %d -> %d, fresh %d, seen %s, up %s, down %s, blockers [%s], checked at +%.2f",
		verdict, w.key, w.fog and (w.vision_before and " (fog, seen by Torrent)" or " (fog, not seen)") or "", before, after, fresh, tostring(vision),
		first_start and string.format("%+.2f", first_start) or "-", last_end and string.format("%+.2f", last_end) or "-",
		table.concat(w.blockers, ","), rel))

	if state.armed and state.armed.minute <= w.minute then state.armed = nil end
	if verdict == "ok" then
		state.result = {
			time = now, camp = w.key, open = true, rgb = COLORS.ok, prog = 1,
			main = L("as_st_done"), main_rgb = COLORS.ok, segs = { string.format(":%05.2f", w.order.t - w.minute * 60) },
		}
	elseif verdict == "fog" or verdict == "unknown" then
		state.result = {
			time = now, camp = w.key, open = true, rgb = COLORS.idle, prog = 1,
			main = L("as_st_blind"), segs = { why },
		}
	else
		local segs = { why }
		state.result = {
			time = now, camp = w.key, open = true, rgb = COLORS.bad, prog = 1,
			main = L("as_st_fail"), main_rgb = COLORS.bad, segs = segs,
		}
	end
end

local function snapshot(hero, w, rel)
	w.snap = true
	w.hero_in = in_box(w.box, Entity.GetAbsOrigin(hero))
	local zero = (w.minute + 1) * 60
	local grounded = 0
	for i = 1, #w.creeps do
		local c = w.creeps[i]
		if NPCs.Contains(c.npc) and Entity.IsAlive(c.npc) then
			local pos = Entity.GetAbsOrigin(c.npc)
			local inside = in_box(w.box, pos)
			local up = pos.z - c.pos.z
			if inside and up <= K.AIR_HEIGHT then
				grounded = grounded + 1
				if not c.hit then w.unhit_in_box = true end
			end
			log(string.format("at :00 %s: hit %s, in box %s, height %.0f, z %.0f (box top %.0f, %s), mods [%s]",
				NPC.GetUnitName(c.npc), tostring(c.hit), tostring(inside), up, pos.z, w.box.max.z,
				pos.z > w.box.max.z and "above" or "below", modifier_names(c.npc)))
		end
	end
	for i = 1, #w.hits do
		local c = w.hits[i]
		if NPCs.Contains(c.npc) and Entity.IsAlive(c.npc) then
			local pos = Entity.GetAbsOrigin(c.npc)
			if in_box(w.box, pos) and pos.z > c.ground + K.AIR_HEIGHT and pos.z <= w.box.max.z then
				w.below = (w.below or 0) + 1
			end
			if in_box(w.box, pos) and pos.z <= c.ground + K.AIR_HEIGHT then
				if c.air_end then
					w.landed = math.max(w.landed or 0, zero - c.air_end)
				else
					w.not_up = true
				end
			end
		end
	end
	local hero_index = Entity.GetIndex(hero)
	local units = NPCs.InRadius(box_center(w.box), K.GROUP_RADIUS, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_BOTH) or {}
	for i = 1, #units do
		local u = units[i]
		local name = NPC.GetUnitName(u) or "?"
		if Entity.GetIndex(u) ~= hero_index and not NPC.IsNeutral(u) and not name:find("thinker", 1, true)
			and Entity.IsAlive(u) and in_box(w.box, Entity.GetAbsOrigin(u)) then
			w.blockers[#w.blockers + 1] = name
		end
	end
	log(string.format("at :00 (+%.2f): %d of %d on the ground in box, hero in box %s, others in box %d",
		rel, grounded, #w.creeps, tostring(w.hero_in), #w.blockers))
end

local function watch_tick(hero, now)
	local w = state.watch
	local t = GameRules.GetDOTATime()
	local rel = t - (w.minute + 1) * 60

	local n = 0
	local units = visible_neutrals(hero, box_center(w.box), K.GROUP_RADIUS)
	for i = 1, #units do
		local u = units[i]
		if in_box(w.box, u.pos, K.COUNT_PAD) then
			n = n + 1
			local idx = Entity.GetIndex(u.npc)
			if rel < 0 then
				w.known[idx] = true
				if w.fog and not w.tracked[idx] then
					w.tracked[idx] = true
					local ground = World.GetGroundZ(u.pos.x, u.pos.y)
					w.hits[#w.hits + 1] = { npc = u.npc, ground = ground, peak = u.pos.z, partial = u.pos.z > ground + K.AIR_HEIGHT }
					w.creeps[#w.creeps + 1] = { npc = u.npc, pos = Vector(u.pos.x, u.pos.y, ground), hit = true }
				end
			elseif rel >= K.SPAWN_SEEN and not w.known[idx] then
				w.fresh_seen[idx] = true
			end
		end
	end
	if n > 0 or FogOfWar.IsPointVisible(box_ground(w.box)) then
		if rel < 0 then
			w.vision_before = true
			w.before_seen = math.max(w.before_seen, n)
		elseif rel >= K.SPAWN_SEEN then
			w.vision_after = true
			w.after_seen = math.max(w.after_seen, n)
		end
	end

	local flying = false
	for i = 1, #w.hits do
		local c = w.hits[i]
		if NPCs.Contains(c.npc) and Entity.IsAlive(c.npc) then
			local z = Entity.GetAbsOrigin(c.npc).z
			if z > c.ground + K.AIR_HEIGHT then
				if not c.air_start then c.air_start = t end
				if z > c.peak then c.peak = z end
			elseif c.air_start and not c.air_end then
				c.air_end = t
			end
			if not c.air_end then flying = true end
		end
	end

	if rel >= 0 and not w.snap then snapshot(hero, w, rel) end

	if w.snap and ((rel >= K.SPAWN_CHECK and not flying) or rel >= K.WATCH_AFTER) then
		finish_watch(hero, now, rel)
	end
end

local function pick_camp(hero, mode)
	local list = camp_list()
	local from
	if mode == 3 then
		if state.hover then
			local e = camp_data(state.hover)
			if camp_enabled(e) then return state.hover end
		end
		from = Input.GetWorldCursorPos()
	else
		from = Entity.GetAbsOrigin(hero)
	end
	local best, best_d = nil, mode == 3 and K.CURSOR_RADIUS * K.CURSOR_RADIUS or math.huge
	for i = 1, #list do
		local c = list[i]
		if camp_enabled(camp_data(c.key)) then
			local d = (c.center.x - from.x) ^ 2 + (c.center.y - from.y) ^ 2
			if d < best_d then best, best_d = c.key, d end
		end
	end
	return best
end

local function press_key(hero, mode)
	local _, minute = clock()
	if mode == 2 and state.armed then
		log("disarmed " .. state.armed.key)
		state.armed = nil
		return
	end
	local key = pick_camp(hero, mode)
	if not key then
		log("key: no enabled camp to pick")
		return
	end
	if state.armed and state.armed.key == key then
		log("disarmed " .. key)
		state.armed = nil
		return
	end
	state.armed = { key = key, minute = state.done_minute == minute and minute + 1 or minute }
	state.next_scan = 0.0
	log(string.format("armed camp %s for minute %d", key, state.armed.minute))
end

local function update()
	local hero = Heroes.GetLocal()
	if not hero or not Entity.IsAlive(hero) or NPC.GetUnitName(hero) ~= K.HERO then
		state.status, state.target, state.plan = nil, nil, nil
		return
	end
	local now = GameRules.GetGameTime()
	local mode = ui.mode:Get()
	local keyed = mode >= 2
	if keyed and ui.key:IsPressed() and not Input.IsInputCaptured() then
		press_key(hero, mode)
	end
	if state.watch then
		watch_tick(hero, now)
		if state.watch then return end
	end

	local ability = NPC.GetAbility(hero, K.ABILITY)
	local t, minute, sec = clock()

	if state.result and (now - state.result.time < K.RESULT_LINGER or state.done_minute == minute) then
		state.status = state.result
		return
	end
	state.result = nil

	if state.armed and state.armed.minute < minute then
		log("armed camp expired: " .. state.armed.key)
		state.armed = nil
	end
	local only = keyed and state.armed and state.armed.key or nil
	local offset = keyed and state.armed and (state.armed.minute - minute) * 60 or 0

	if (mode == 1 and not ui.key:IsToggled()) or (keyed and not only) then
		state.target, state.plan = nil, nil
		set_status("off", {})
		return
	end
	if minute < 1 then
		set_status("early", {})
		return
	end
	if not ability or Ability.GetLevel(ability) < 1 then
		set_status("level", {})
		return
	end
	if state.done_minute == minute and offset == 0 then
		return
	end

	if now >= state.next_scan then
		state.next_scan = now + K.SCAN_INTERVAL
		local target = find_target(hero, ability, only)
		state.target = target
		state.plan = target and plan_time(hero, ability, target) or nil
	end
	local target = state.target
	if not target then
		if only then
			local c = find_camp(only)
			set_status("far", {
				camp = only, open = true, rgb = COLORS.idle, prog = 0, main = L("as_st_far"),
				segs = { c and camp_name(c.camp_type) or "?" }, detail = "armed camp " .. only .. " is out of reach",
			})
		else
			set_status("no_camp", { detail = "no enabled camp in reach" })
		end
		return
	end

	local plan = state.plan
	local turn, order_at = plan.turn, plan.order_at
	local left = order_at + offset - sec
	local camp = camp_name(target.camp_type)
	local open = keyed or sec >= K.OPEN_FROM
	local prog = clamp(1 - left / math.max(0.1, order_at - K.OPEN_FROM), 0, 1)
	local n = #target.hits
	local warn, rgb = nil, COLORS.ok
	if plan.hero_in_box then
		warn, rgb = L("as_why_hero"), COLORS.bad
	elseif target.fog then
		warn = L("as_why_blind")
	elseif plan.hit_in_box < plan.in_box then
		warn, rgb = string.format(L("as_hits"), plan.hit_in_box, plan.in_box), COLORS.bad
	end

	local cd = Ability.GetCooldown(ability) or 0
	local mana_ok = NPC.GetMana(hero) >= (Ability.GetManaCost(ability) or 0)
	if left > K.TICK_HALF then
		if cd > left then
			set_status("cd", {
				camp = target.key, open = open, rgb = COLORS.bad, prog = prog,
				main = string.format(L("as_st_cd"), cd), main_rgb = COLORS.bad, segs = { camp, L("as_st_late") },
				detail = string.format("cd %.1f > left %.1f", cd, left),
			})
		elseif not mana_ok then
			set_status("mana", {
				camp = target.key, open = open, rgb = COLORS.bad, prog = prog,
				main = L("as_st_mana"), main_rgb = COLORS.bad, segs = { camp, L("as_st_late") },
			})
		else
			local whole = math.ceil(left)
			set_status("wait", {
				camp = target.key, open = open, rgb = rgb, prog = prog,
				main = string.format("%d:%02d", whole // 60, whole % 60), main_rgb = rgb, segs = { camp, warn },
				detail = string.format("%s %s%s mark %d, %d hits (%d/%d in box), slack %.0f, order @ %.2f%s (map :%05.2f minus ping %d ms, incoming %d ms)",
					camp, target.key, target.fog and " fog" or "", target.mark, n, plan.hit_in_box, plan.in_box, target.slack, plan.order_at,
					offset > 0 and " next minute" or "", plan.base, math.floor(plan.ping_out * 1000 + 0.5), math.floor(plan.ping_in * 1000 + 0.5)),
			})
		end
		state.attempts = 0
		return
	end

	if left < -K.LATE_WINDOW then
		if keyed and state.attempts == 0 then
			state.armed.minute = minute + 1
			log(string.format("armed camp %s moved to minute %d, pressed after the cast second", target.key, minute + 1))
			return
		end
		log(string.format("missed window: sec %.2f, order_at %.2f", sec, order_at))
		state.result = { time = now, camp = target.key, open = true, rgb = COLORS.bad, prog = 1, main = L("as_st_miss"), main_rgb = COLORS.bad, segs = { camp } }
		state.done_minute = minute
		return
	end

	if Ability.IsInAbilityPhase(ability) or (cd > 0 and state.attempts > 0) then
		state.done_minute = minute
		log(string.format("cast ok at %.2f, %d hits%s, planned %.2f", sec, n, target.fog and " (fog)" or "", plan.order_at))
		set_status("cast", { camp = target.key, open = true, rgb = COLORS.ok, prog = 1, main = L("as_st_cast"), segs = { camp } })
		start_watch(hero, ability, minute, target, sec)
		return
	end

	if not Ability.IsCastable(ability, NPC.GetMana(hero)) or NPC.IsStunned(hero) or NPC.IsSilenced(hero) or NPC.IsChannellingAbility(hero) then
		log(string.format("not castable at %.2f: cd %.1f, mana %s, stunned %s, silenced %s, channel %s",
			sec, cd, tostring(mana_ok), tostring(NPC.IsStunned(hero)), tostring(NPC.IsSilenced(hero)), tostring(NPC.IsChannellingAbility(hero))))
		state.result = { time = now, camp = target.key, open = true, rgb = COLORS.bad, prog = 1, main = L("as_st_miss"), main_rgb = COLORS.bad, segs = { camp } }
		state.done_minute = minute
		return
	end

	if state.attempts >= K.MAX_ATTEMPTS then
		log(string.format("gave up after %d orders at %.2f", state.attempts, sec))
		state.result = { time = now, camp = target.key, open = true, rgb = COLORS.bad, prog = 1, main = L("as_st_miss"), main_rgb = COLORS.bad, segs = { camp } }
		state.done_minute = minute
		return
	end
	if now - state.last_try >= K.RETRY_DELAY then
		state.attempts = state.attempts + 1
		state.last_try = now
		if state.attempts == 1 then
			state.order = { t = t, turn = turn, planned = order_at, out = plan.ping_out, inn = plan.ping_in }
		end
		Ability.CastPosition(ability, target.pos)
		set_status("cast", { camp = target.key, open = true, rgb = COLORS.ok, prog = 1, main = L("as_st_cast"), segs = { camp } })
		log(string.format("order #%d at %.2f (dota %.2f), camp %s%s, pos %s, %d hits, slack %.0f, dist %d, turn %.2f, %s",
			state.attempts, sec, t, target.key, target.fog and " fog" or "", tostring(target.pos), n, target.slack, math.floor(target.dist), turn, plan.how))
	end
end

local script = {}

function script.OnUpdate()
	if not active() then return end
	if GameRules.IsPaused() then return end
	update()
end

function script.OnKeyEvent(data)
	if data.key ~= Enum.ButtonCode.KEY_MOUSE1 then return true end
	if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
		if state.swallow then return false end
		local key = state.hover
		if key and active() and ui.camps:Get() and not Input.IsInputCaptured() then
			toggle_camp(key)
			state.swallow = true
			return false
		end
	elseif data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP and state.swallow then
		state.swallow = false
		return false
	end
	return true
end

function script.OnGameEnd()
	state.done_minute = -1
	state.status, state.result, state.target, state.plan, state.watch, state.order = nil, nil, nil, nil, nil, nil
	state.armed, state.camp_list, state.hover, state.swallow, state.anim = nil, nil, nil, false, {}
end

do
	local ROUND_ALL = Enum.DrawFlags.RoundCornersAll

	local function load_icon(path)
		local entry = state.icons[path]
		if entry == nil then
			local handle = Render.LoadImage(path)
			entry = handle and { handle = handle } or false
			state.icons[path] = entry
		end
		if not entry then return nil end
		if not entry.uv0 then
			local size = Render.ImageSize(entry.handle)
			if not size or size.x <= 0 or size.y <= 0 then return nil end
			local u0, v0, u1, v1 = 0.0, 0.0, 1.0, 1.0
			if size.x > size.y then
				local d = (1.0 - size.y / size.x) / 2
				u0, u1 = d, 1.0 - d
			elseif size.y > size.x then
				local d = (1.0 - size.x / size.y) / 2
				v0, v1 = d, 1.0 - d
			end
			entry.uv0, entry.uv1 = Vec2(u0, v0), Vec2(u1, v1)
		end
		return entry
	end

	local function approach(current, target, dt, speed)
		return current + (target - current) * (1 - math.exp(-dt * speed))
	end

	local function fonts()
		if not state.fonts then
			local flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
			state.fonts = {
				bold = Render.LoadFont("Inter", flags, Enum.FontWeight.BOLD) or Render.LoadFont("Segoe UI", flags, Enum.FontWeight.BOLD),
				regular = Render.LoadFont("Inter", flags, Enum.FontWeight.NORMAL) or Render.LoadFont("Segoe UI", flags, Enum.FontWeight.NORMAL),
			}
		end
		return state.fonts
	end

	local function full_ring(p, radius, color, thickness)
		local pts = {}
		for i = 0, K.RING_POINTS - 1 do
			local ang = i / K.RING_POINTS * 2 * math.pi
			pts[#pts + 1] = Vec2(p.x + math.cos(ang) * radius, p.y + math.sin(ang) * radius)
		end
		Render.PolyLine(pts, color, thickness)
	end

	local function camp_status(key)
		local st = state.status
		if st and st.camp == key and st.open then return st end
		return nil
	end

	local function ring_color(e)
		if e.off then return nil, 0 end
		return COLORS.ok, 1
	end

	local function build_items(c, e, st, hovered)
		local items = {}
		if hovered then
			items[1] = { kind = "bold", text = camp_name(c.camp_type), rgb = COLORS.text }
			items[2] = { kind = "div" }
			items[3] = { kind = "toggle", on = camp_enabled(e) }
		elseif st then
			items[1] = { kind = "bold", text = st.main, rgb = st.main_rgb or COLORS.text }
			for i = 1, 4 do
				local seg = st.segs and st.segs[i]
				if seg then
					items[#items + 1] = { kind = "div" }
					items[#items + 1] = { kind = "text", text = seg }
				end
			end
		end
		return items
	end

	local function digit_width(font, size)
		local key = font .. ":" .. size
		local w = state.digit_w[key]
		if not w then
			w = 0
			for d = 0, 9 do w = math.max(w, Render.TextSize(font, size, tostring(d)).x) end
			state.digit_w[key] = w
		end
		return w
	end

	local function text_runs(font, size, text)
		local runs, dw = {}, digit_width(font, size)
		local w, h = 0, Render.TextSize(font, size, text).y
		for chunk, digits in text:gmatch("([^%d]*)(%d*)") do
			if chunk ~= "" then
				local cw = Render.TextSize(font, size, chunk).x
				runs[#runs + 1] = { text = chunk, x = w, w = cw }
				w = w + cw
			end
			for i = 1, #digits do
				local ch = digits:sub(i, i)
				local cw = Render.TextSize(font, size, ch).x
				runs[#runs + 1] = { text = ch, x = w + (dw - cw) / 2, w = dw }
				w = w + dw
			end
		end
		return runs, w, h
	end

	local function measure(items, scale)
		local f = fonts()
		local size = math.floor(K.FONT * scale + 0.5)
		local small = math.floor(K.FONT_SMALL * scale + 0.5)
		local gap = K.ROW_GAP * scale
		local w = 0
		for i = 1, #items do
			local it = items[i]
			if it.kind == "toggle" then
				it.w = K.TOGGLE_W * scale
			elseif it.kind == "div" then
				it.w = 1
			else
				it.font = it.kind == "bold" and f.bold or f.regular
				it.size = it.kind == "bold" and size or small
				it.runs, it.w, it.h = text_runs(it.font, it.size, it.text)
			end
			w = w + it.w + (i > 1 and gap or 0)
		end
		return w
	end

	local function draw_item(it, x, cy, alpha, scale)
		local function a(v) return math.floor(v * alpha + 0.5) end
		if it.kind == "div" then
			local h = K.DIVIDER * scale
			Render.FilledRect(Vec2(x, cy - h / 2), Vec2(x + 1, cy + h / 2), Color(255, 255, 255, a(46)))
		elseif it.kind == "toggle" then
			local tw, th = K.TOGGLE_W * scale, K.TOGGLE_H * scale
			local bg = it.retry and Color(232, 98, 90, a(115)) or (it.on and Color(111, 214, 111, a(153)) or Color(255, 255, 255, a(41)))
			Render.FilledRect(Vec2(x, cy - th / 2), Vec2(x + tw, cy + th / 2), bg, th / 2, ROUND_ALL)
			local kr = th / 2 - 2 * scale
			local kx = it.on and (x + tw - th / 2) or (x + th / 2)
			Render.FilledCircle(Vec2(kx, cy), kr, it.on and Color(255, 255, 255, a(255)) or Color(174, 178, 184, a(255)))
		else
			local rgb = it.rgb or COLORS.muted
			local color = Color(rgb[1], rgb[2], rgb[3], a(255))
			local y = math.floor(cy - it.h / 2 + 0.5)
			for i = 1, #it.runs do
				local r = it.runs[i]
				Render.Text(it.font, it.size, r.text, Vec2(math.floor(x + r.x + 0.5), y), color)
			end
		end
	end

	local function pill_left(p, w, screen)
		return clamp(p.x - w / 2, 4, screen.x - w - 4)
	end

	local function tween_width(an, target)
		if an.w == nil then
			an.w, an.w_to, an.w_t = target, target, 1
		elseif an.w_to ~= target then
			an.w_from, an.w_to, an.w_t = an.w, target, 0
		end
		if an.w_t < 1 then
			an.w_t = math.min(1, an.w_t + an.dt / K.WIDTH_TIME)
			local k = 1 - an.w_t
			local e = 1 - k * k * k
			an.w = an.w_from + (an.w_to - an.w_from) * e
		else
			an.w = an.w_to
		end
	end

	local function draw_camp(c, e, p, st, hovered, an, scale, screen)
		local alpha = an.a
		local function a(v) return math.floor(v * alpha + 0.5) end
		local h = 2 * math.floor(K.RING_H * scale / 2 + 0.5)
		local r = h / 2
		local items = build_items(c, e, st, hovered)
		local cw = #items > 0 and measure(items, scale) or 0
		local target_w = 2 * math.floor((h + (cw > 0 and (K.ROW_LEAD * scale + cw + K.ROW_TAIL * scale) or 0)) / 2 + 0.5)
		tween_width(an, target_w)
		an.open = approach(an.open or 0, #items > 0 and 1 or 0, an.dt, K.WIDTH_SPEED)
		if an.open < 0.01 then an.open = 0 end
		if #items > 0 then
			an.items = items
		elseif an.open > 0 and an.items then
			items = an.items
		else
			an.items = nil
		end
		local w = an.w
		local py = math.floor(p.y + 0.5)
		local ax = pill_left(Vec2(math.floor(p.x + 0.5), py), w, screen)
		local pa, pb = Vec2(ax, py - r), Vec2(ax + w, py + r)
		p = Vec2(ax + r, py)

		local blur = alpha
		if ui.camps_blur:Get() and blur > 0.02 then
			Render.Blur(pa, pb, blur, 1.0, r, ROUND_ALL)
		end
		Render.FilledRect(pa, pb, Color(14, 16, 18, a(184)), r, ROUND_ALL)

		local rr, thick = K.RING_R * scale, K.RING_W * scale
		local rgb, ring_a, prog
		if st then
			local goal = clamp(st.prog or 1, 0, 1)
			if not an.prog or goal < an.prog - 0.2 then an.prog = goal end
			an.prog = approach(an.prog, goal, an.dt, K.PROG_SPEED)
			rgb, ring_a, prog = an.rgb, 1, an.prog
		else
			an.prog = nil
			rgb, ring_a = ring_color(e)
			prog = 1
		end
		if prog > 0.995 then prog = 1 end
		if prog < 0.01 then prog = 0 end
		if st and prog < 1 then
			local track = Color(255, 255, 255, a(31))
			if prog == 0 then
				full_ring(p, rr, track, thick)
			else
				Render.Circle(p, rr, track, thick, 270 + 360 * prog, 1 - prog, false, 64)
			end
		end
		if rgb and prog > 0 then
			local color = Color(math.floor(rgb[1] + 0.5), math.floor(rgb[2] + 0.5), math.floor(rgb[3] + 0.5), a(255 * ring_a))
			if prog >= 1 then
				full_ring(p, rr, color, thick)
			else
				Render.Circle(p, rr, color, thick, 270, prog, false, 64)
			end
		end

		local icon = load_icon(K.ICON)
		local s = K.RING_ICON * scale
		if icon then
			Render.Image(icon.handle, Vec2(p.x - s / 2, p.y - s / 2), Vec2(s, s), Color(255, 255, 255, a(camp_enabled(e) and 255 or 170)), s / 2, ROUND_ALL,
				icon.uv0, icon.uv1, camp_enabled(e) and 0.0 or 1.0)
		end

		if #items > 0 then
			Render.PushClip(pa, pb)
			local gap = K.ROW_GAP * scale
			local x = p.x + r + K.ROW_LEAD * scale
			for i = 1, #items do
				draw_item(items[i], x, p.y, alpha * an.open, scale)
				x = x + items[i].w + gap
			end
			Render.PopClip()
		end
		return pa, pb
	end

	local function draw_camps()
		state.hover = nil
		if not ui.camps:Get() then return end
		local hero = Heroes.GetLocal()
		if not hero or NPC.GetUnitName(hero) ~= K.HERO then return end
		local dt = math.max(0.0, math.min(0.1, GlobalVars.GetAbsFrameTime() or 0.016))
		local scale = ui.camps_scale:Get() / 100
		local idle = ui.camps_idle:Get() / 100
		local screen = Render.ScreenSize()
		local r = K.RING_H * scale / 2
		local list = camp_list()
		local top = {}
		for i = 1, #list do
			local c = list[i]
			local e = camp_data(c.key)
			local spot = camp_spot(e, c.box)
			local p, visible = Render.WorldToScreen(spot)
			if visible then
				local an = state.anim[c.key]
				if not an then
					an = { a = 0.0 }
					state.anim[c.key] = an
				end
				an.dt = dt
				local st = camp_status(c.key)
				local w = an.w or (r * 2)
				local hovered = Input.IsCursorInRect(pill_left(p, w, screen), p.y - r, w, r * 2)
				if hovered then state.hover = c.key end
				local goal = (st or hovered) and 1.0 or (camp_enabled(e) and idle or idle * 0.65)
				an.a = approach(an.a, goal, dt, K.FADE_SPEED)
				if st then
					if an.rgb then
						for k = 1, 3 do an.rgb[k] = approach(an.rgb[k], st.rgb[k], dt, K.COLOR_SPEED) end
					else
						an.rgb = { st.rgb[1], st.rgb[2], st.rgb[3] }
					end
				else
					an.rgb = nil
				end
				if st or hovered then
					top[#top + 1] = { c = c, e = e, p = p, st = st, hovered = hovered, an = an }
				else
					draw_camp(c, e, p, nil, false, an, scale, screen)
				end
			end
		end
		for i = 1, #top do
			local it = top[i]
			draw_camp(it.c, it.e, it.p, it.st, it.hovered, it.an, scale, screen)
		end
	end

	local function guarded(fn, name)
		local ok, err = pcall(fn)
		if not ok and err ~= state.draw_error then
			state.draw_error = err
			Log.Write("[Auto Stack] " .. name .. ": " .. tostring(err))
		end
	end

	function script.OnDraw()
		if not active() then
			state.hover = nil
			return
		end
		guarded(draw_camps, "draw")
	end
end

return script
