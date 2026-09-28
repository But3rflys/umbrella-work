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
		as_mode = "When to stack",
		as_debug = "Debug log",
		as_key = "Key",
		as_bind_name = "Auto Stack",
		as_camps = "Camp rings",
		as_gear_camps = "Camp rings",
		as_camps_scale = "Size",
		as_camps_idle = "Idle rings",
		as_camps_blur = "Blur behind",
		as_camps_type = "Camp type",
		is_group = "Auto Stack",
		is_enable = "Enable",
		is_enable_tip = "Invoker stacks camps with Tornado\nat the right second of every minute",
		is_gear_main = "Auto Stack",
		is_mode = "When to stack",
		is_debug = "Debug log",
		is_key = "Key",
		is_bind_name = "Invoker Stack",
		is_camps = "Camp rings",
		is_gear_camps = "Camp rings",
		is_camps_scale = "Size",
		is_camps_idle = "Idle rings",
		is_camps_blur = "Blur behind",
		is_camps_type = "Camp type",
		is_auto_invoke = "Invoke Tornado",
		stack_mode_tip = "Automatic stacks the best enabled camp.\nKey modes stack the chosen camp this minute",
		stack_modes_auto = "Automatic",
		stack_modes_toggle = "Automatic, key on and off",
		stack_modes_nearest = "Key: nearest camp",
		stack_modes_cursor = "Key: camp under the cursor",
		stack_key_tip = "Turns stacking on or picks the camp,\na second press cancels",
		stack_camps_tip = "A ring over every camp, click it\nto turn that camp on or off",
		stack_camps_idle_tip = "How visible the rings of camps\nthat aren't being stacked are",
		stack_camps_type_tip = "Shows on the pill which camp it is:\nsmall, medium, large or ancient",
		stack_st_fail = "No stack",
		stack_st_done = "Stacked",
		stack_st_blind = "Cast",
		stack_st_cd = "CD %.1f",
		stack_st_mana = "No mana",
		stack_st_late = "won't make it",
		stack_st_cast = "Casting",
		stack_st_miss = "Missed",
		stack_st_far = "Too far",
		stack_st_high = "Too high",
		stack_st_hidden = "No Tornado",
		stack_st_invoking = "Casting",
		stack_why_late = "late %.1f s",
		stack_why_early = "early %.1f s",
		stack_why_hero = "hero in the camp",
		stack_why_blocked = "someone else in the camp",
		stack_why_partial = "not every creep hit",
		stack_why_air = "in the air, no stack",
		stack_why_low = "creeps not above the camp box",
		stack_why_unknown = "not seen, can't check",
		stack_why_fog = "in the fog, can't check",
		stack_why_blind = "blind",
		stack_hits = "hit %d of %d",
		stack_camp_0 = "small",
		stack_camp_1 = "medium",
		stack_camp_2 = "large",
		stack_camp_3 = "ancient",
	},
	ru = {
		as_group = "Авто-стак",
		as_enable = "Включить",
		as_enable_tip = "Кунка стакает кемпы торрентом\nв нужную секунду каждой минуты",
		as_gear_main = "Авто-стак",
		as_mode = "Когда стакать",
		as_debug = "Отладка в лог",
		as_key = "Клавиша",
		as_bind_name = "Auto Stack",
		as_camps = "Кольца над кемпами",
		as_gear_camps = "Кольца над кемпами",
		as_camps_scale = "Размер",
		as_camps_idle = "Кольца в покое",
		as_camps_blur = "Размытие фона",
		as_camps_type = "Тип кемпа",
		is_group = "Авто-стак",
		is_enable = "Включить",
		is_enable_tip = "Инвокер стакает кемпы торнадо\nв нужную секунду каждой минуты",
		is_gear_main = "Авто-стак",
		is_mode = "Когда стакать",
		is_debug = "Отладка в лог",
		is_key = "Клавиша",
		is_bind_name = "Invoker Stack",
		is_camps = "Кольца над кемпами",
		is_gear_camps = "Кольца над кемпами",
		is_camps_scale = "Размер",
		is_camps_idle = "Кольца в покое",
		is_camps_blur = "Размытие фона",
		is_camps_type = "Тип кемпа",
		is_auto_invoke = "Создавать торнадо",
		stack_mode_tip = "Сам стакает лучший включённый кемп.\nПо клавише стакает выбранный кемп в эту минуту",
		stack_modes_auto = "Сам",
		stack_modes_toggle = "Сам, клавиша вкл/выкл",
		stack_modes_nearest = "Клавиша: ближайший кемп",
		stack_modes_cursor = "Клавиша: кемп под курсором",
		stack_key_tip = "Включает авто-стак или выбирает кемп,\nповторное нажатие отменяет",
		stack_camps_tip = "Кольцо над каждым кемпом, клик по нему\nвключает и выключает кемп",
		stack_camps_idle_tip = "Насколько заметны кольца кемпов,\nкоторые сейчас не стакаются",
		stack_camps_type_tip = "Пишет на плашке, какой это кемп:\nмалый, средний, большой или древний",
		stack_st_fail = "Не стакнулось",
		stack_st_done = "Стакнуто",
		stack_st_blind = "Кинул",
		stack_st_cd = "КД %.1f",
		stack_st_mana = "Нет маны",
		stack_st_late = "не успеет",
		stack_st_cast = "Кидаю",
		stack_st_miss = "Не кинул",
		stack_st_far = "Далеко",
		stack_st_high = "Высоко",
		stack_st_hidden = "Нет торнадо",
		stack_st_invoking = "Кастую",
		stack_why_late = "поздно на %.1f с",
		stack_why_early = "рано на %.1f с",
		stack_why_hero = "герой в кемпе",
		stack_why_blocked = "в кемпе чужой юнит",
		stack_why_partial = "задеты не все",
		stack_why_air = "в воздухе, но не стакнулось",
		stack_why_low = "крипы не вылетели из кемпа",
		stack_why_unknown = "не видно, не проверить",
		stack_why_fog = "в тумане, не проверить",
		stack_why_blind = "вслепую",
		stack_hits = "задето %d из %d",
		stack_camp_0 = "малый",
		stack_camp_1 = "средний",
		stack_camp_2 = "большой",
		stack_camp_3 = "древний",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local CAMPS = {
	["m258_m13"] = { x = -8306.3, y = -546.4, cast = 57.27 },
	["264_38"] = { x = 8426.1, y = 1280.1, cast = 57.23 },
	["128_2"] = { x = 4318.6, y = 61.5, cast = 57.23 },
	["m123_155"] = { x = -3887.0, y = 4814.2, cast = 57.23 },
	["6_m161"] = { x = 224.0, y = -5180.1, cast = 57.27 },
	["126_m158"] = { x = 3975.2, y = -5046.2, cast = 57.27 },
	["m61_m148"] = { x = -1984.8, y = -4836.6, cast = 57.27 },
	["248_m2"] = { x = 7918.2, y = -122.3, cast = 57.23 },
	["106_m38"] = { x = 3450.2, y = -1367.3, cast = 57.23 },
	["m80_121"] = { x = -2583.5, y = 3854.3, cast = 57.23 },
	["m24_154"] = { x = -833.7, y = 4903.6, cast = 57.27 },
	["m47_m108"] = { x = -1443.2, y = -3343.0, cast = 57.27 },
	["m126_28"] = { x = -4019.3, y = 988.4, cast = 57.30 },
	["57_m126"] = { x = 1897.6, y = -3966.3, cast = 57.30 },
	["36_128"] = { x = 1240.9, y = 4179.1, cast = 57.27 },
	["34_79"] = { x = 1023.5, y = 2640.4, cast = 57.27 },
	["m150_m3"] = { x = -4991.2, y = -106.0, cast = 57.27 },
	["m24_m240"] = { x = -767.5, y = -7675.4, cast = 57.23 },
	["m77_m262"] = { x = -2428.6, y = -8414.3, cast = 57.23 },
	["m249_m56"] = { x = -8001.9, y = -1827.0, cast = 57.23 },
	["10_241"] = { x = 377.3, y = 7705.3, cast = 57.27 },
	["m152_125"] = { x = -4822.3, y = 3932.7, cast = 57.23 },
	["148_m122"] = { x = 4655.6, y = -3730.2, cast = 57.27 },
}

local COLORS = {
	ok = { 111, 214, 111 },
	bad = { 232, 98, 90 },
	idle = { 240, 240, 242 },
	text = { 240, 240, 242 },
	muted = { 150, 154, 160 },
}

local K = {
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
	GROUND_TICKS = 3,
	LATEST = 59.9,
	OPEN_FROM = 45.0,
	WATCH_AFTER = 4.0,
	SPAWN_CHECK = 1.0,
	SPAWN_SEEN = 0.05,
	CAMP_GRID = 32,
	TICK_HALF = 1 / 60,
	CAMP_LIST_TTL = 5.0,
	CURVE_TIME = 3.6,
	MAX_SAMPLES = 130,
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
	MEASURE_SIZE = 96,
	WIDTH_SPEED = 26,
	WIDTH_TIME = 0.15,
	HOVER_PAD = 6,
	FADE_SPEED = 20,
	COLOR_SPEED = 18,
	PROG_SPEED = 30,
}

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

local function camp_key(box)
	local function part(v)
		local n = math.floor(v / K.CAMP_GRID + 0.5)
		return n < 0 and ("m" .. -n) or tostring(n)
	end
	return part((box.min.x + box.max.x) / 2) .. "_" .. part((box.min.y + box.max.y) / 2)
end

local function camp_name(camp_type)
	return camp_type and L("stack_camp_" .. camp_type) or "?"
end

local function clock()
	local t = GameRules.GetDOTATime()
	local minute = math.floor(t / 60)
	return t, minute, t - minute * 60
end

local function latency()
	local flow = Enum.Flow
	local out = NetChannel.GetAvgLatency(flow.FLOW_OUTGOING) or 0
	local inn = NetChannel.GetAvgLatency(flow.FLOW_INCOMING) or 0
	return math.max(0, out), math.max(0, inn)
end

local function modifier_names(npc)
	local names = {}
	local mods = NPC.GetModifiers(npc) or {}
	for i = 1, #mods do names[#names + 1] = Modifier.GetName(mods[i]) end
	return table.concat(names, ",")
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

local function box_creeps(hero, box)
	local list = {}
	local units = NPCs.InRadius(box_center(box), K.GROUP_RADIUS, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY) or {}
	for i = 1, #units do
		local u = units[i]
		if NPC.IsNeutral(u) and Entity.IsAlive(u) and not NPC.IsWaitingToSpawn(u) then
			local pos = Entity.GetAbsOrigin(u)
			if in_box(box, pos) then list[#list + 1] = { npc = u, pos = pos } end
		end
	end
	return list, units
end

local function count_in_box(hero, box)
	local n = 0
	local units = visible_neutrals(hero, box_center(box), K.GROUP_RADIUS)
	for i = 1, #units do
		if in_box(box, units[i].pos, K.COUNT_PAD) then n = n + 1 end
	end
	return n
end

local function camp_creeps(units, box)
	local seen = {}
	for i = 1, #units do
		if in_box(box, units[i].pos, K.BOX_PAD) then seen[#seen + 1] = units[i] end
	end
	return seen
end

local function toward(origin, point, dist)
	local dx, dy = point.x - origin.x, point.y - origin.y
	local d = math.max(math.sqrt(dx * dx + dy * dy), 1)
	return Vector(origin.x + dx / d * dist, origin.y + dy / d * dist, origin.z), dx / d, dy / d, d
end

local kunkka = {
	prefix = "as",
	tag = "[Auto Stack]",
	unit = "npc_dota_hero_kunkka",
	menu = "Kunkka",
	side = Enum.GroupSide.Right,
	ability = "kunkka_torrent",
	config = "auto_stack",
	icon = "panorama/images/spellicons/kunkka_torrent_png.vtex_c",
	earliest = 45.0,
	second = 57.25,
}

do
	local function circle_hits(center, radius, creeps)
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

	local function best_circle(origin, range, radius, creeps)
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
			local d = origin:Distance2D(p)
			if d <= range then
				local hits, slack = circle_hits(p, radius, creeps)
				if #hits > 0 then
					local better = not best or #hits > #best.hits
						or (#hits == #best.hits and (slack > best.slack + 1 or (slack >= best.slack - 1 and d < best.dist)))
					if better then best = { pos = p, hits = hits, slack = slack, dist = d } end
				end
			end
		end
		return best
	end

	function kunkka.find_target(ctx, hero, ability, only)
		local origin = Entity.GetAbsOrigin(hero)
		local range = Ability.GetCastRange(ability) + (NPC.GetCastRangeBonus(hero) or 0)
		local radius = Ability.GetLevelSpecialValueFor(ability, "radius")
		local search = range + radius + K.CAMP_REACH
		local units = visible_neutrals(hero, origin, search)
		local best = nil
		for _, camp in ipairs(ctx.camps_near(origin, search, only)) do
			local seen = camp_creeps(units, camp.box)
			local c = nil
			if #seen > 0 then
				c = best_circle(origin, range, radius, seen)
				if c then c.fog, c.full = false, #c.hits == #seen end
			else
				local spot = ctx.camp_spot(camp.key, camp.box)
				local d = origin:Distance2D(spot)
				if d <= range then c = { pos = spot, hits = {}, slack = 0, dist = d, fog = true, full = true } end
			end
			if c then
				c.inside, c.box, c.camp_type, c.key = seen, camp.box, camp.camp_type, camp.key
				if ctx.better_target(c, best) then best = c end
			end
		end
		return best
	end

	function kunkka.plan(ctx, hero, ability, target)
		local out, inn = latency()
		local base = CAMPS[target.key].cast or kunkka.second
		return {
			order_at = clamp(base - out, kunkka.earliest, K.LATEST), turn = 0, check = 0, ok = true,
			base = base, delay = Ability.GetLevelSpecialValueFor(ability, "delay") or 0, ping_out = out, ping_in = inn,
		}
	end

	function kunkka.describe(target, plan)
		return string.format("slack %.0f, order @ %.2f (camp second :%05.2f minus ping %d ms, incoming %d ms)",
			target.slack, plan.order_at, plan.base, math.floor(plan.ping_out * 1000 + 0.5), math.floor(plan.ping_in * 1000 + 0.5))
	end

	function kunkka.after_finish(ctx, w, zero)
		local sum, count, air_len = 0, 0, 0
		for i = 1, #w.hits do
			local c = w.hits[i]
			if c.air_start and c.air_end and not c.partial then
				sum = sum + ((c.air_start + c.air_end) / 2 - w.order.t - w.plan.delay)
				air_len = air_len + (c.air_end - c.air_start)
				count = count + 1
			end
		end
		if count > 0 then
			ctx.log(string.format("measured: order to mid-air %.3f s, flight %.2f s", sum / count, air_len / count))
		else
			ctx.log("measured: no creep flight seen")
		end
	end
end

local TORNADO = {
	SPEED = 1000,
	RADIUS = 200,
	DISTANCE = 1500,
	LIFT_TIME = 1.2,
	LIFT_TABLE = { 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4, 2.6, 2.8, 3.0, 3.2 },
	TRAVEL_TABLE = { 1500, 1800, 2100, 2400, 2700, 3000, 3300, 3600, 3900, 4200, 4500 },
	BOB = { base = 394, amp = 73, period = 1.05, peak = 0.775, rise = 1670, fall = 0.3, lag = -0.05 },
	TOP_MARGIN = 5,
	CHECK = -0.033,
	SCAN_STEP = 1 / 60,
	QUAS = "invoker_quas",
	WEX = "invoker_wex",
	INVOKE = "invoker_invoke",
	INVOKE_LEAD = 2.5,
	INVOKE_STEP = 0.05,
	INVOKE_TIMEOUT = 1.0,
}

local invoker = {
	prefix = "is",
	tag = "[Invoker Stack]",
	unit = "npc_dota_hero_invoker",
	menu = "Invoker",
	side = Enum.GroupSide.Left,
	ability = "invoker_tornado",
	config = "invoker_stack",
	icon = "panorama/images/spellicons/invoker_tornado_png.vtex_c",
	earliest = 50.0,
}

do
	local BOB = TORNADO.BOB

	local function orb_level(hero, name)
		local orb = NPC.GetAbility(hero, name)
		return orb and Ability.GetLevel(orb) or 0
	end

	local function tornado(ability, hero)
		local speed = Ability.GetLevelSpecialValueFor(ability, "travel_speed")
		local radius = Ability.GetLevelSpecialValueFor(ability, "area_of_effect")
		local dist = TORNADO.TRAVEL_TABLE[orb_level(hero, TORNADO.WEX)] or Ability.GetLevelSpecialValueFor(ability, "travel_distance")
		return (speed and speed > 0) and speed or TORNADO.SPEED,
			2 * ((radius and radius > 0) and radius or TORNADO.RADIUS),
			(dist and dist > 0) and dist or TORNADO.DISTANCE
	end

	local function lift_time(ability, hero)
		local q = orb_level(hero, TORNADO.QUAS)
		if TORNADO.LIFT_TABLE[q] then return TORNADO.LIFT_TABLE[q], q, "table" end
		local d = Ability.GetLevelSpecialValueFor(ability, "lift_duration")
		return (d and d > 0) and d or TORNADO.LIFT_TIME, q, "fallback"
	end

	local function lift_height(air, tau)
		if tau <= 0 or tau >= air then return 0 end
		local hover = BOB.base + BOB.amp * math.cos(2 * math.pi * (tau - BOB.peak) / BOB.period)
		local h = math.min(tau * BOB.rise, hover)
		if tau > air - BOB.fall then h = math.min(h, hover * (air - tau) / BOB.fall) end
		return h
	end

	local function line_hits(origin, ux, uy, length, width, creeps)
		local hits, slack, far = {}, math.huge, 0
		for i = 1, #creeps do
			local c = creeps[i]
			local rx, ry = c.pos.x - origin.x, c.pos.y - origin.y
			local along = rx * ux + ry * uy
			local room = width / 2 + c.hull - math.abs(rx * uy - ry * ux)
			if along > 0 and along <= length and room >= 0 then
				hits[#hits + 1] = { npc = c.npc, pos = c.pos, along = along, hull = c.hull }
				if room < slack then slack = room end
				if along > far then far = along end
			end
		end
		return hits, slack, far
	end

	local function best_line(origin, range, length, width, creeps)
		local aims = {}
		local sx, sy = 0, 0
		for i = 1, #creeps do
			local a = creeps[i].pos
			sx, sy = sx + a.x, sy + a.y
			aims[#aims + 1] = a
			for j = i + 1, #creeps do
				local b = creeps[j].pos
				aims[#aims + 1] = Vector((a.x + b.x) / 2, (a.y + b.y) / 2, a.z)
			end
		end
		aims[#aims + 1] = Vector(sx / #creeps, sy / #creeps, creeps[1].pos.z)

		local best = nil
		for i = 1, #aims do
			local d = origin:Distance2D(aims[i])
			if d > 1 then
				local pos, ux, uy = toward(origin, aims[i], math.max(100, math.min(range - 10, d)))
				local hits, slack, far = line_hits(origin, ux, uy, length, width, creeps)
				if #hits > 0 then
					local better = not best or #hits > #best.hits
						or (#hits == #best.hits and (slack > best.slack + 1 or (slack >= best.slack - 1 and far < best.far)))
					if better then best = { pos = pos, ux = ux, uy = uy, hits = hits, slack = slack, far = far, dist = d } end
				end
			end
		end
		return best
	end

	local function best_window(air, creeps, t_from, t_to)
		local best_lo, best_hi, run_lo = nil, nil, nil
		local t = t_from
		while t <= t_to + TORNADO.SCAN_STEP do
			local good = true
			for i = 1, #creeps do
				if lift_height(air, t - creeps[i].lift) <= creeps[i].need then
					good = false
					break
				end
			end
			if good then
				run_lo = run_lo or t
			elseif run_lo then
				if not best_lo or (t - TORNADO.SCAN_STEP - run_lo) > (best_hi - best_lo) + 0.05 then
					best_lo, best_hi = run_lo, t - TORNADO.SCAN_STEP
				end
				run_lo = nil
			end
			t = t + TORNADO.SCAN_STEP
		end
		if run_lo and (not best_lo or (t_to - run_lo) > (best_hi - best_lo) + 0.05) then
			best_lo, best_hi = run_lo, t_to
		end
		return best_lo, best_hi
	end

	function invoker.find_target(ctx, hero, ability, only)
		local origin = Entity.GetAbsOrigin(hero)
		local range = Ability.GetCastRange(ability) + (NPC.GetCastRangeBonus(hero) or 0)
		local _, width, length = tornado(ability, hero)
		local search = length + K.CAMP_REACH
		local units = visible_neutrals(hero, origin, search)
		local best = nil
		for _, camp in ipairs(ctx.camps_near(origin, search, only)) do
			local box = camp.box
			local seen = camp_creeps(units, box)
			local c = nil
			if #seen > 0 then
				c = best_line(origin, range, length, width, seen)
				if c then c.fog, c.full = false, #c.hits == #seen end
			else
				local spot = ctx.camp_spot(camp.key, box)
				local d = origin:Distance2D(spot)
				if d <= length then
					local pos, ux, uy = toward(origin, spot, math.max(100, math.min(range - 10, d)))
					c = { pos = pos, ux = ux, uy = uy, hits = {}, slack = 0, far = d, dist = d, fog = true, full = true, spot_along = d, spot_ground = spot.z }
				end
			end
			if c then
				c.inside, c.box, c.camp_type, c.key = seen, box, camp.camp_type, camp.key
				c.length, c.width = length, width
				local need = #c.hits == 0 and box.max.z - (c.spot_ground or box.min.z) or 0
				for j = 1, #c.hits do need = math.max(need, box.max.z - c.hits[j].pos.z) end
				c.reachable = need + TORNADO.TOP_MARGIN < BOB.base + BOB.amp
				if ctx.better_target(c, best) then best = c end
			end
		end
		return best
	end

	function invoker.plan(ctx, hero, ability, target)
		local out, inn = latency()
		local speed = tornado(ability, hero)
		local air, quas, air_src = lift_time(ability, hero)
		local list = target.hits
		if #list == 0 then list = { { along = target.spot_along, pos = Vector(0, 0, target.spot_ground or target.box.min.z) } } end
		local creeps, near, far, need = {}, math.huge, 0, 0
		for i = 1, #list do
			local c = list[i]
			local h = target.box.max.z - c.pos.z + TORNADO.TOP_MARGIN
			need = math.max(need, h)
			near, far = math.min(near, c.along), math.max(far, c.along)
			creeps[#creeps + 1] = { lift = BOB.lag + c.along / speed, need = h }
		end
		local lo, hi = best_window(air, creeps, BOB.lag + near / speed, BOB.lag + far / speed + air)
		local ok = lo ~= nil
		local mid = ok and (lo + hi) / 2 or (BOB.lag + far / speed + BOB.peak)
		local turn = NPC.GetTimeToFacePosition(hero, target.pos) or 0
		local cast = Ability.GetCastPoint(ability)
		return {
			order_at = clamp(60 + TORNADO.CHECK - mid - cast - turn - out, invoker.earliest, K.LATEST),
			turn = turn, cast = cast, mid = mid, ok = ok, window = ok and (hi - lo) or 0, check = TORNADO.CHECK,
			speed = speed, near = near / speed, far = far / speed, air = air, quas = quas, air_src = air_src, need = need,
			ping_out = out, ping_in = inn,
		}
	end

	function invoker.describe(target, plan)
		return string.format("slack %.0f, dist %d, order @ %.2f = 60 %+.3f (check) - mid %.3f - cast %.2f - turn %.2f - ping %d ms (incoming %d ms); tornado %.3f..%.3f s, box needs %.0f, bob up to %.0f, in air %.2f s (quas %d, %s), above top together %.3f s%s",
			target.slack, math.floor(target.dist), plan.order_at, plan.check, plan.mid, plan.cast, plan.turn,
			math.floor(plan.ping_out * 1000 + 0.5), math.floor(plan.ping_in * 1000 + 0.5), plan.near, plan.far, plan.need,
			BOB.base + BOB.amp, plan.air, plan.quas, plan.air_src, plan.window, plan.ok and "" or " (cannot)")
	end

	function invoker.predict(order, plan, along)
		return order.t + plan.turn + plan.cast + (order.out or 0) + BOB.lag + along / plan.speed
	end

	function invoker.on_lift(c)
		local mods = NPC.GetModifiers(c.npc) or {}
		for i = 1, #mods do
			local name = Modifier.GetName(mods[i]) or ""
			if name:find("tornado", 1, true) then c.mod_name, c.mod_dur = name, Modifier.GetDuration(mods[i]) end
		end
	end

	function invoker.after_finish(ctx, w, zero, lo, hi)
		if #w.hits > 0 and lo <= hi then
			local ideal = (lo + hi) / 2
			ctx.log(string.format("all above box top together from %+.3f to %+.3f (%.3f s); aimed check %+.3f %s, order could move %+.3f s",
				lo, hi, hi - lo, w.plan.check, (lo <= w.plan.check and hi >= w.plan.check) and "was inside" or "missed it", w.plan.check - ideal))
		elseif #w.hits > 0 then
			ctx.log("never all above box top at the same time")
		end
		local mod_dur, mod_name = nil, nil
		for i = 1, #w.hits do
			if (w.hits[i].mod_dur or 0) > 0 then mod_dur, mod_name = w.hits[i].mod_dur, w.hits[i].mod_name end
		end
		if mod_dur then
			ctx.log(string.format("lift duration: modifier %s says %.3f s, plan used %.3f s (%s) for quas %d%s", mod_name, mod_dur,
				w.plan.air, w.plan.air_src, w.plan.quas, math.abs(mod_dur - w.plan.air) > 0.01 and ", MISMATCH" or ""))
		end
	end

	function invoker.dump(ctx)
		for _, c in ipairs(ctx.camp_list()) do
			local ground = World.GetGroundZ(c.center.x, c.center.y)
			local need = c.box.max.z - ground
			ctx.log(string.format("camp %s %s: ground %.0f, box z %.0f..%.0f, tornado must lift %.0f (bob up to %.0f) -> %s",
				c.key, camp_name(c.camp_type), ground, c.box.min.z, c.box.max.z, need, BOB.base + BOB.amp,
				need + TORNADO.TOP_MARGIN < BOB.base + BOB.amp and "possible" or "too high"))
		end
	end

	function invoker.build_menu(ctx, group)
		ctx.ui.auto_invoke = group:Switch("is_auto_invoke", false, "\u{f0d0}")
	end

	function invoker.refresh_menu(ctx, on)
		ctx.ui.auto_invoke:Disabled(not on)
	end

	local function own_orders_pending(indices)
		local queue = Humanizer.GetOrderQueue()
		if type(queue) ~= "table" then return false end
		for i = 1, #queue do
			if indices[queue[i].abilityIndex] then return true end
		end
		return false
	end

	local function invoke_blocker(hero, tornado_ability, left)
		local quas, wex, invoke = NPC.GetAbility(hero, TORNADO.QUAS), NPC.GetAbility(hero, TORNADO.WEX), NPC.GetAbility(hero, TORNADO.INVOKE)
		if orb_level(hero, TORNADO.QUAS) < 1 or orb_level(hero, TORNADO.WEX) < 1 then
			return "orbs", "quas or wex not learned"
		end
		if not invoke or (Ability.GetCooldown(invoke) or 0) > 0 then
			return "invoke_cd", string.format("invoke on cooldown %.1f", invoke and Ability.GetCooldown(invoke) or -1)
		end
		if (Ability.GetCooldown(tornado_ability) or 0) > left then
			return "tornado_cd", string.format("tornado cooldown %.1f > left %.1f", Ability.GetCooldown(tornado_ability), left)
		end
		if NPC.IsStunned(hero) or NPC.IsSilenced(hero) then
			return "disabled", "stunned or silenced"
		end
		return nil, nil, { quas, wex, wex, invoke }
	end

	local function auto_invoke(ctx, hero, ability, left, minute)
		local state = ctx.state
		local now = GameRules.GetGameTime()
		local inv = state.invoke
		if inv and inv.minute ~= minute then state.invoke, inv = nil, nil end
		if inv and inv.done then return false end
		if not inv then
			if left > TORNADO.INVOKE_LEAD or left < 0 then return false end
			local cat, why, seq = invoke_blocker(hero, ability, left)
			if cat then
				ctx.log_once("invoke_" .. cat, "auto invoke skipped: " .. why)
				return false
			end
			local indices = {}
			for i = 1, #seq do indices[Entity.GetIndex(seq[i])] = true end
			inv = { minute = minute, step = 1, last = -100.0, started = now, seq = seq, indices = indices }
			state.invoke = inv
			ctx.log(string.format("auto invoke: start, %.2f s before the throw", left))
		end
		if not Ability.IsHidden(ability) then
			inv.done = true
			ctx.log(string.format("auto invoke: tornado ready after %.2f s", now - inv.started))
			return false
		end
		if now - inv.started > TORNADO.INVOKE_TIMEOUT + #inv.seq * TORNADO.INVOKE_STEP * 4 then
			inv.done = true
			ctx.log("auto invoke: gave up, tornado still not on the bar")
			return false
		end
		if inv.step <= #inv.seq and now - inv.last >= TORNADO.INVOKE_STEP and not own_orders_pending(inv.indices) then
			local ab = inv.seq[inv.step]
			Ability.CastNoTarget(ab)
			ctx.log(string.format("auto invoke: step %d %s", inv.step, Ability.GetName(ab) or "?"))
			inv.step, inv.last = inv.step + 1, now
		end
		return true
	end

	function invoker.before_cast(ctx, hero, ability, target, plan, view)
		local hidden = Ability.IsHidden(ability)
		if hidden and ctx.ui.auto_invoke:Get() then
			if auto_invoke(ctx, hero, ability, view.left, view.minute) then
				ctx.set_status("invoking", {
					camp = target.key, open = view.open, rgb = COLORS.ok, prog = view.prog, main = L("stack_st_invoking"), segs = { view.camp },
				})
				return true
			end
			if view.left > TORNADO.INVOKE_LEAD then hidden = false end
		end
		if hidden then
			ctx.set_status("hidden", {
				camp = target.key, open = view.open, rgb = COLORS.bad, prog = 0, main = L("stack_st_hidden"), main_rgb = COLORS.bad, segs = { view.camp },
			})
			return true
		end
		if not plan.ok then
			ctx.set_status("high", {
				camp = target.key, open = view.open, rgb = COLORS.bad, prog = 0, main = L("stack_st_high"), main_rgb = COLORS.bad, segs = { view.camp },
				detail = string.format("%s: tornado lifts %.0f, box needs %.0f", target.key, BOB.base + BOB.amp, plan.need),
			})
			return true
		end
		return false
	end

	function invoker.reset(ctx)
		ctx.state.invoke = nil
	end
end

local function create_stacker(def)
	local P = def.prefix
	local ui = {}
	local state = {
		next_scan = 0.0,
		done_minute = -1,
		attempts = 0,
		last_try = -100.0,
		camps = {},
		anim = {},
		digit_w = {},
		advances = {},
		icons = {},
		swallow = false,
	}
	local ctx = { state = state, ui = ui, def = def }

	local config = ((type(Config) == "table" or type(Config) == "userdata") and type(Config.ReadInt) == "function"
		and type(Config.WriteInt) == "function") and Config or nil
	local memory = {}
	if not config then
		Log.Write(def.tag .. " Config is replaced by another script, camp toggles will not be saved")
	end

	local function store_read(key, default)
		if config then return config.ReadInt(def.config, key, default) end
		local v = memory[key]
		if v == nil then return default end
		return v
	end

	local function store_write(key, value)
		if config then
			config.WriteInt(def.config, key, value)
		else
			memory[key] = value
		end
	end

	function ctx.log(text)
		if ui.debug and ui.debug:Get() then Log.Write(def.tag .. " " .. text) end
	end

	function ctx.log_once(key, text)
		if state.logged == key then return end
		state.logged = key
		ctx.log(text)
	end

	function ctx.set_status(key, info)
		state.status = info
		info.key = key
		ctx.log_once(key, string.format("%s  %s", key, info.detail or ""))
	end

	do
		local page = UI.Find("Heroes", "Hero List", def.menu):Find("Main Settings")
		local group = page:Create(P .. "_group", def.side)
		ui.hero_enable = Menu.Find("Heroes", "Hero List", def.menu, "Main Settings", "Hero Settings", "Enable")

		ui.enable = group:Switch(P .. "_enable", false, "\u{f00c}")
		ui.enable:ToolTip(P .. "_enable_tip")
		local g_main = ui.enable:Gear(P .. "_gear_main")
		ui.mode = g_main:Combo(P .. "_mode", { "stack_modes_auto", "stack_modes_toggle", "stack_modes_nearest", "stack_modes_cursor" }, 3)
		ui.mode:Icon("\u{f1de}")
		ui.mode:ToolTip("stack_mode_tip")
		ui.debug = g_main:Switch(P .. "_debug", false, "\u{f188}")

		ui.key = group:Bind(P .. "_key", Enum.ButtonCode.KEY_NONE, "\u{e1c1}")
		ui.key:ToolTip("stack_key_tip")

		if def.build_menu then def.build_menu(ctx, group) end

		ui.camps = group:Switch(P .. "_camps", true, "\u{f3c5}")
		ui.camps:ToolTip("stack_camps_tip")
		local g_camps = ui.camps:Gear(P .. "_gear_camps")
		ui.camps_scale = g_camps:Slider(P .. "_camps_scale", 80, 160, 100, "%d%%")
		ui.camps_scale:Icon("\u{f065}")
		ui.camps_idle = g_camps:Slider(P .. "_camps_idle", 20, 100, 70, "%d%%")
		ui.camps_idle:Icon("\u{f043}")
		ui.camps_idle:ToolTip("stack_camps_idle_tip")
		ui.camps_blur = g_camps:Switch(P .. "_camps_blur", false, "\u{f042}")
		ui.camps_type = g_camps:Switch(P .. "_camps_type", true, "\u{f036}")
		ui.camps_type:ToolTip("stack_camps_type_tip")
	end

	local function active()
		return ui.enable:Get() and (not ui.hero_enable or ui.hero_enable:Get())
	end

	local function refresh_menu()
		local on = ui.enable:Get()
		local mode = ui.mode:Get()
		local camps = on and ui.camps:Get()
		ui.mode:Disabled(not on)
		ui.debug:Disabled(not on)
		ui.key:Visible(mode ~= 0)
		ui.key:Disabled(not on)
		ui.key:Properties(L(P .. "_bind_name"), nil, mode == 1)
		ui.camps:Disabled(not on)
		ui.camps_scale:Disabled(not camps)
		ui.camps_idle:Disabled(not camps)
		ui.camps_blur:Disabled(not camps)
		ui.camps_type:Disabled(not camps)
		if def.refresh_menu then def.refresh_menu(ctx, on) end
	end

	ui.enable:SetCallback(refresh_menu, true)
	ui.mode:SetCallback(function()
		state.armed = nil
		refresh_menu()
	end)
	ui.camps:SetCallback(refresh_menu)

	local function camp_data(key)
		local e = state.camps[key]
		if not e then
			local spot = CAMPS[key]
			e = { off = store_read("off_" .. key, 0) == 1 }
			if spot then e.spot = Vector(spot.x, spot.y, World.GetGroundZ(spot.x, spot.y)) end
			state.camps[key] = e
		end
		return e
	end

	function ctx.camp_spot(key, box)
		return camp_data(key).spot or box_ground(box)
	end

	local function toggle_camp(key)
		local e = camp_data(key)
		e.off = not e.off
		store_write("off_" .. key, e.off and 1 or 0)
		if state.armed and state.armed.key == key and e.off then state.armed = nil end
		state.next_scan = 0.0
		ctx.log(string.format("camp %s clicked: off %s", key, tostring(e.off)))
	end

	function ctx.camp_list()
		local now = GameRules.GetGameTime()
		if state.camp_list and #state.camp_list > 0 and now < state.camp_list_until then return state.camp_list end
		local list = {}
		local camps = Camps.GetAll() or {}
		for i = 1, #camps do
			local box = Camp.GetCampBox(camps[i])
			local key = box and camp_key(box)
			if key and CAMPS[key] then
				list[#list + 1] = { box = box, key = key, center = box_ground(box), camp_type = Camp.GetType(camps[i]) }
			end
		end
		state.camp_list, state.camp_list_until = list, now + K.CAMP_LIST_TTL
		return list
	end

	function ctx.camps_near(origin, radius, only)
		local list = {}
		for _, c in ipairs(ctx.camp_list()) do
			if origin:Distance2D(c.center) <= radius and not camp_data(c.key).off and (not only or only == c.key) then
				list[#list + 1] = c
			end
		end
		return list
	end

	function ctx.better_target(a, b)
		if not b then return true end
		if (a.reachable ~= false) ~= (b.reachable ~= false) then return a.reachable ~= false end
		if a.fog ~= b.fog then return not a.fog end
		if a.full ~= b.full then return a.full end
		if #a.hits ~= #b.hits then return #a.hits > #b.hits end
		if a.fog and a.camp_type ~= b.camp_type then return (a.camp_type or 0) > (b.camp_type or 0) end
		return a.dist < b.dist
	end

	local function find_camp(key)
		for _, c in ipairs(ctx.camp_list()) do
			if c.key == key then return c end
		end
		return nil
	end

	local function new_hit(w, npc, ground, z, along)
		local c = { npc = npc, ground = ground, peak = z, along = along, low = 0, curve = {}, segs = {} }
		if along and def.predict then c.pred_up = def.predict(w.order, w.plan, along) end
		return c
	end

	local function start_watch(hero, minute, target)
		local box = target.box
		local order = state.order or { t = GameRules.GetDOTATime(), turn = 0 }
		local creeps, around = box_creeps(hero, box)
		local known = {}
		for i = 1, #around do known[Entity.GetIndex(around[i])] = true end
		local w = {
			minute = minute, box = box, key = target.key, fog = target.fog, order = order, plan = state.plan,
			before = count_in_box(hero, box), known = known, creeps = creeps, hits = {}, blockers = {},
			tracked = {}, fresh_seen = {}, before_seen = 0, after_seen = 0, vision_before = false, vision_after = false,
		}
		local hit_set = {}
		for i = 1, #target.hits do
			local c = target.hits[i]
			hit_set[c.npc] = true
			if NPCs.Contains(c.npc) then
				local z = Entity.GetAbsOrigin(c.npc).z
				w.hits[#w.hits + 1] = new_hit(w, c.npc, z, z, c.along)
			end
		end
		for i = 1, #creeps do creeps[i].hit = hit_set[creeps[i].npc] or false end
		state.watch = w
		ctx.log(string.format("watch: camp %s%s, order at %.2f, %d hit of %d in box, %d counted before, box top %.0f",
			target.key, target.fog and " (fog)" or "", order.t - minute * 60, #w.hits, #creeps, w.before, box.max.z))
	end

	local function snapshot(hero, w, rel)
		w.snap = true
		w.hero_in = in_box(w.box, Entity.GetAbsOrigin(hero))
		local top = w.box.max.z
		local check_t = (w.minute + 1) * 60 + w.plan.check
		w.above, w.below, w.grounded = 0, 0, 0
		for i = 1, #w.creeps do
			local c = w.creeps[i]
			if NPCs.Contains(c.npc) and Entity.IsAlive(c.npc) then
				local pos = Entity.GetAbsOrigin(c.npc)
				local inside = in_box(w.box, pos)
				local up = pos.z - c.pos.z
				local where
				if pos.z > top then
					w.above, where = w.above + 1, "above top"
				elseif up > K.AIR_HEIGHT then
					if inside then w.below = w.below + 1 end
					where = "in air below top"
				else
					if inside then
						w.grounded = w.grounded + 1
						if not c.hit then w.unhit_in_box = true end
					end
					where = "on the ground"
				end
				ctx.log(string.format("at check %s: hit %s, in box %s, %s, height %.0f, z %.0f, box top %.0f (%+.0f), mods [%s]",
					NPC.GetUnitName(c.npc), tostring(c.hit), tostring(inside), where, up, pos.z, top, pos.z - top, modifier_names(c.npc)))
			end
		end
		for i = 1, #w.hits do
			local c = w.hits[i]
			if NPCs.Contains(c.npc) and Entity.IsAlive(c.npc) then
				local pos = Entity.GetAbsOrigin(c.npc)
				if in_box(w.box, pos) and pos.z <= c.ground + K.AIR_HEIGHT then
					if c.air_end then
						w.landed = math.max(w.landed or 0, check_t - c.air_end)
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
		ctx.log(string.format("at check (%+.3f): %d above box top, %d in air below it, %d on the ground, hero in box %s, others in box %d",
			rel, w.above, w.below, w.grounded, tostring(w.hero_in), #w.blockers))
	end

	local function finish_watch(hero, now, rel)
		local w = state.watch
		state.watch = nil
		local zero = (w.minute + 1) * 60
		local check_t = zero + w.plan.check

		local lo, hi, first_up = -math.huge, math.huge, nil
		for i = 1, #w.hits do
			local c = w.hits[i]
			local seg_text, seg, seg_d = {}, nil, nil
			for k = 1, #c.segs do
				local sg = c.segs[k]
				seg_text[#seg_text + 1] = string.format("%+.3f..%+.3f", sg[1] - zero, sg[2] - zero)
				local d = check_t < sg[1] and (sg[1] - check_t) or (check_t > sg[2] and (check_t - sg[2]) or 0)
				if not seg or d < seg_d then seg, seg_d = sg, d end
			end
			if c.air_start then first_up = math.max(first_up or -math.huge, c.air_start - check_t) end
			ctx.log(string.format("flight %s:%s predicted up %s, up %s, peak %.0f at %s, down %s, above box top %s%s%s",
				NPC.GetUnitName(c.npc) or "?", c.along and string.format(" along %d,", math.floor(c.along)) or "",
				c.pred_up and string.format("%+.3f", c.pred_up - zero) or "-",
				c.air_start and string.format("%+.3f", c.air_start - zero) or "-",
				c.peak - c.ground, c.peak_at and string.format("%+.3f", c.peak_at - zero) or "-",
				c.air_end and string.format("%+.3f", c.air_end - zero) or "-",
				#seg_text > 0 and table.concat(seg_text, ", ") or "never",
				c.partial and ", was already up" or "",
				c.mod_dur and string.format(", %s %.3f s", c.mod_name, c.mod_dur) or ""))
			if #c.curve > 0 then ctx.log("  curve " .. table.concat(c.curve, " ")) end
			if seg then
				lo, hi = math.max(lo, seg[1] - zero), math.min(hi, seg[2] - zero)
			else
				lo, hi = math.huge, -math.huge
			end
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
			verdict, why = "fog", L("stack_why_fog")
		elseif after > before or (fresh > 0 and after >= before) then
			verdict = "ok"
		elseif not vision then
			verdict, why = w.fog and "fog" or "unknown", L(w.fog and "stack_why_fog" or "stack_why_unknown")
		elseif w.hero_in then
			verdict, why = "hero", L("stack_why_hero")
		elseif #w.blockers > 0 then
			verdict, why = "blocked", L("stack_why_blocked")
		elseif w.unhit_in_box then
			verdict, why = "partial", L("stack_why_partial")
		elseif w.landed then
			verdict, why = "early", string.format(L("stack_why_early"), w.landed)
		elseif w.not_up then
			verdict, why = "late", string.format(L("stack_why_late"), math.max(0, first_up or 0))
		elseif (w.below or 0) > 0 then
			verdict, why = "low", L("stack_why_low")
		else
			verdict, why = "air_no_stack", L("stack_why_air")
		end
		ctx.log(string.format("verdict %s: camp %s%s, creeps %d -> %d, fresh %d, at check %d above box top, %d in air below it, %d on the ground, blockers [%s], checked at +%.2f",
			verdict, w.key, w.fog and " (fog)" or "", before, after, fresh, w.above or 0, w.below or 0, w.grounded or 0,
			table.concat(w.blockers, ","), rel))
		if def.after_finish then def.after_finish(ctx, w, zero, lo, hi) end

		if state.armed and state.armed.minute <= w.minute then state.armed = nil end
		local result = { time = now, camp = w.key, open = true, prog = 1 }
		if verdict == "ok" then
			result.rgb, result.main, result.main_rgb = COLORS.ok, L("stack_st_done"), COLORS.ok
			result.segs = { string.format(":%05.2f", w.order.t - w.minute * 60) }
		elseif verdict == "fog" or verdict == "unknown" then
			result.rgb, result.main, result.segs = COLORS.idle, L("stack_st_blind"), { why }
		else
			result.rgb, result.main, result.main_rgb, result.segs = COLORS.bad, L("stack_st_fail"), COLORS.bad, { why }
		end
		state.result = result
	end

	local function watch_tick(hero, now)
		local w = state.watch
		local t = GameRules.GetDOTATime()
		local zero = (w.minute + 1) * 60
		local rel = t - zero
		local top = w.box.max.z

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
						local along = w.order.ux and math.max(0, (u.pos.x - w.order.x) * w.order.ux + (u.pos.y - w.order.y) * w.order.uy) or nil
						local c = new_hit(w, u.npc, ground, u.pos.z, along)
						c.partial = u.pos.z > ground + K.AIR_HEIGHT
						w.hits[#w.hits + 1] = c
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
				local up = z - c.ground
				if up > K.AIR_HEIGHT then
					c.low = 0
					if not c.air_start then
						c.air_start = t
						if def.on_lift then def.on_lift(c) end
					end
					if z > c.peak then c.peak, c.peak_at = z, t end
				elseif c.air_start and not c.air_end then
					c.low = c.low + 1
					if c.low == 1 then c.low_at = t end
					if c.low >= K.GROUND_TICKS then c.air_end = c.low_at end
				end
				if z > top then
					if c.over then
						c.segs[#c.segs][2] = t
					else
						c.segs[#c.segs + 1] = { t, t }
						c.over = true
					end
				else
					c.over = false
				end
				if ui.debug:Get() and c.air_start and t - c.air_start <= K.CURVE_TIME and #c.curve < K.MAX_SAMPLES then
					c.curve[#c.curve + 1] = string.format("%+.3f:%.0f", rel, up)
				end
				if c.air_start and not c.air_end then flying = true end
			end
		end

		if rel >= w.plan.check and not w.snap then snapshot(hero, w, rel) end
		if w.snap and ((rel >= K.SPAWN_CHECK and not flying) or rel >= K.WATCH_AFTER) then
			finish_watch(hero, now, rel)
		end
	end

	local function pick_camp(hero, mode)
		local from
		if mode == 3 then
			if state.hover and not camp_data(state.hover).off then return state.hover end
			from = Input.GetWorldCursorPos()
		else
			from = Entity.GetAbsOrigin(hero)
		end
		local best, best_d = nil, mode == 3 and K.CURSOR_RADIUS * K.CURSOR_RADIUS or math.huge
		for _, c in ipairs(ctx.camp_list()) do
			if not camp_data(c.key).off then
				local d = (c.center.x - from.x) ^ 2 + (c.center.y - from.y) ^ 2
				if d < best_d then best, best_d = c.key, d end
			end
		end
		return best
	end

	local function press_key(hero, mode)
		local _, minute = clock()
		if mode == 2 and state.armed then
			ctx.log("disarmed " .. state.armed.key)
			state.armed = nil
			return
		end
		local key = pick_camp(hero, mode)
		if not key then
			ctx.log("key: no enabled camp to pick")
			return
		end
		if state.armed and state.armed.key == key then
			ctx.log("disarmed " .. key)
			state.armed = nil
			return
		end
		state.armed = { key = key, minute = state.done_minute == minute and minute + 1 or minute }
		state.next_scan = 0.0
		ctx.log(string.format("armed camp %s for minute %d", key, state.armed.minute))
	end

	local function fail(now, key, camp, minute)
		state.result = { time = now, camp = key, open = true, rgb = COLORS.bad, prog = 1, main = L("stack_st_miss"), main_rgb = COLORS.bad, segs = { camp } }
		state.done_minute = minute
	end

	local function update()
		local hero = Heroes.GetLocal()
		if not hero or not Entity.IsAlive(hero) or NPC.GetUnitName(hero) ~= def.unit then
			state.status, state.target, state.plan = nil, nil, nil
			return
		end
		if def.dump and not state.dumped and ui.debug:Get() then
			state.dumped = true
			def.dump(ctx)
		end
		local now = GameRules.GetGameTime()
		local mode = ui.mode:Get()
		local keyed = mode >= 2
		if keyed and ui.key:IsPressed() and not Input.IsInputCaptured() then press_key(hero, mode) end
		if state.watch then
			watch_tick(hero, now)
			if state.watch then return end
		end

		local ability = NPC.GetAbility(hero, def.ability)
		local t, minute, sec = clock()

		if state.result and (now - state.result.time < K.RESULT_LINGER or state.done_minute == minute) then
			state.status = state.result
			return
		end
		state.result = nil

		if state.armed and state.armed.minute < minute then
			ctx.log("armed camp expired: " .. state.armed.key)
			state.armed = nil
		end
		local only = keyed and state.armed and state.armed.key or nil
		local offset = keyed and state.armed and (state.armed.minute - minute) * 60 or 0

		if (mode == 1 and not ui.key:IsToggled()) or (keyed and not only) then
			state.target, state.plan = nil, nil
			ctx.set_status("off", {})
			return
		end
		if minute < 1 then
			ctx.set_status("early", {})
			return
		end
		if not ability or Ability.GetLevel(ability) < 1 then
			ctx.set_status("level", {})
			return
		end
		if state.done_minute == minute and offset == 0 then return end

		if now >= state.next_scan then
			state.next_scan = now + K.SCAN_INTERVAL
			local target = def.find_target(ctx, hero, ability, only)
			state.target = target
			state.plan = nil
			if target then
				local plan = def.plan(ctx, hero, ability, target)
				plan.in_box, plan.hit_in_box = #target.inside, #target.hits
				plan.hero_in_box = in_box(target.box, Entity.GetAbsOrigin(hero))
				state.plan = plan
			end
		end
		local target, plan = state.target, state.plan
		if not target then
			if only then
				local c = find_camp(only)
				ctx.set_status("far", {
					camp = only, open = true, rgb = COLORS.idle, prog = 0, main = L("stack_st_far"),
					segs = { c and camp_name(c.camp_type) or "?" }, detail = "armed camp " .. only .. " is out of reach",
				})
			else
				ctx.set_status("no_camp", { detail = "no enabled camp in reach" })
			end
			return
		end

		local order_at = plan.order_at
		local left = order_at + offset - sec
		local camp = camp_name(target.camp_type)
		local open = keyed or sec >= K.OPEN_FROM
		local prog = clamp(1 - left / math.max(0.1, order_at - K.OPEN_FROM), 0, 1)
		local warn, rgb = nil, COLORS.ok
		if plan.hero_in_box then
			warn, rgb = L("stack_why_hero"), COLORS.bad
		elseif target.fog then
			warn = L("stack_why_blind")
		elseif plan.hit_in_box < plan.in_box then
			warn, rgb = string.format(L("stack_hits"), plan.hit_in_box, plan.in_box), COLORS.bad
		end

		local view = { left = left, minute = minute, open = open, prog = prog, camp = camp }
		if def.before_cast and def.before_cast(ctx, hero, ability, target, plan, view) then return end

		local cd = Ability.GetCooldown(ability) or 0
		local mana_ok = NPC.GetMana(hero) >= (Ability.GetManaCost(ability) or 0)
		if left > K.TICK_HALF then
			if cd > left then
				ctx.set_status("cd", {
					camp = target.key, open = open, rgb = COLORS.bad, prog = prog,
					main = string.format(L("stack_st_cd"), cd), main_rgb = COLORS.bad, segs = { camp, L("stack_st_late") },
					detail = string.format("cd %.1f > left %.1f", cd, left),
				})
			elseif not mana_ok then
				ctx.set_status("mana", {
					camp = target.key, open = open, rgb = COLORS.bad, prog = prog,
					main = L("stack_st_mana"), main_rgb = COLORS.bad, segs = { camp, L("stack_st_late") },
				})
			else
				local whole = math.ceil(left)
				ctx.set_status("wait", {
					camp = target.key, open = open, rgb = rgb, prog = prog,
					main = string.format("%d:%02d", whole // 60, whole % 60), main_rgb = rgb, segs = { camp, warn },
					detail = string.format("%s %s%s: %d/%d in box hit%s, %s", camp, target.key, target.fog and " fog" or "",
						plan.hit_in_box, plan.in_box, offset > 0 and ", next minute" or "", def.describe(target, plan)),
				})
			end
			state.attempts = 0
			return
		end

		if left < -K.LATE_WINDOW then
			if keyed and state.attempts == 0 then
				state.armed.minute = minute + 1
				ctx.log(string.format("armed camp %s moved to minute %d, pressed after the cast second", target.key, minute + 1))
				return
			end
			ctx.log(string.format("missed window: sec %.2f, order_at %.2f", sec, order_at))
			fail(now, target.key, camp, minute)
			return
		end

		if Ability.IsInAbilityPhase(ability) or (cd > 0 and state.attempts > 0) then
			state.done_minute = minute
			ctx.log(string.format("cast ok at %.2f, %d hits%s, planned %.2f", sec, #target.hits, target.fog and " (fog)" or "", order_at))
			ctx.set_status("cast", { camp = target.key, open = true, rgb = COLORS.ok, prog = 1, main = L("stack_st_cast"), segs = { camp } })
			start_watch(hero, minute, target)
			return
		end

		if not Ability.IsCastable(ability, NPC.GetMana(hero)) or NPC.IsStunned(hero) or NPC.IsSilenced(hero) or NPC.IsChannellingAbility(hero) then
			ctx.log(string.format("not castable at %.2f: cd %.1f, mana %s, stunned %s, silenced %s, channel %s",
				sec, cd, tostring(mana_ok), tostring(NPC.IsStunned(hero)), tostring(NPC.IsSilenced(hero)), tostring(NPC.IsChannellingAbility(hero))))
			fail(now, target.key, camp, minute)
			return
		end

		if state.attempts >= K.MAX_ATTEMPTS then
			ctx.log(string.format("gave up after %d orders at %.2f", state.attempts, sec))
			fail(now, target.key, camp, minute)
			return
		end
		if now - state.last_try >= K.RETRY_DELAY then
			state.attempts = state.attempts + 1
			state.last_try = now
			if state.attempts == 1 then
				local o = Entity.GetAbsOrigin(hero)
				state.order = {
					t = t, turn = plan.turn, planned = order_at, out = plan.ping_out, inn = plan.ping_in,
					x = o.x, y = o.y, ux = target.ux, uy = target.uy,
				}
			end
			Ability.CastPosition(ability, target.pos)
			ctx.set_status("cast", { camp = target.key, open = true, rgb = COLORS.ok, prog = 1, main = L("stack_st_cast"), segs = { camp } })
			ctx.log(string.format("order #%d at %.2f (dota %.2f), camp %s%s, pos %s, %d hits, slack %.0f, dist %d, turn %.2f",
				state.attempts, sec, t, target.key, target.fog and " fog" or "", tostring(target.pos), #target.hits, target.slack,
				math.floor(target.dist), plan.turn))
		end
	end

	local script = {}

	function script.OnUpdate()
		if not active() or GameRules.IsPaused() then return end
		update()
	end

	function script.OnKeyEvent(data)
		if data.key ~= Enum.ButtonCode.KEY_MOUSE1 then return true end
		if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			if state.swallow then return false end
			if state.hover and active() and ui.camps:Get() and not Input.IsInputCaptured() then
				toggle_camp(state.hover)
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
		state.done_minute, state.attempts, state.dumped = -1, 0, nil
		state.status, state.result, state.target, state.plan, state.watch, state.order = nil, nil, nil, nil, nil, nil
		state.armed, state.camp_list, state.hover, state.swallow, state.anim = nil, nil, nil, false, {}
		if def.reset then def.reset(ctx) end
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

		local function build_items(c, e, st, hovered)
			local items = {}
			local name = camp_name(c.camp_type)
			local show_type = ui.camps_type:Get()
			if hovered then
				if show_type then
					items[1] = { kind = "bold", text = name, rgb = COLORS.text }
					items[2] = { kind = "div" }
				end
				items[#items + 1] = { kind = "toggle", on = not e.off }
			elseif st then
				items[1] = { kind = "bold", text = st.main, rgb = st.main_rgb or COLORS.text }
				for i = 1, 4 do
					local seg = st.segs and st.segs[i]
					if seg and (show_type or seg ~= name) then
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

		local function advance(font, size, ch)
			local key = font .. ":" .. ch
			local a = state.advances[key]
			if not a then
				a = Render.TextSize(font, K.MEASURE_SIZE, ch).x / K.MEASURE_SIZE
				state.advances[key] = a
			end
			return a * size
		end

		local function text_runs(font, size, text)
			local runs, dw = {}, digit_width(font, size)
			local w, h = 0, Render.TextSize(font, size, text).y
			for _, code in utf8.codes(text) do
				local ch = utf8.char(code)
				if ch:match("^%d$") then
					local cw = Render.TextSize(font, size, ch).x
					runs[#runs + 1] = { text = ch, x = w + (dw - cw) / 2 }
					w = w + dw
				else
					if ch ~= " " then runs[#runs + 1] = { text = ch, x = w } end
					w = w + advance(font, size, ch)
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
				local bg = it.on and Color(111, 214, 111, a(153)) or Color(255, 255, 255, a(41))
				Render.FilledRect(Vec2(x, cy - th / 2), Vec2(x + tw, cy + th / 2), bg, th / 2, ROUND_ALL)
				local kx = it.on and (x + tw - th / 2) or (x + th / 2)
				Render.FilledCircle(Vec2(kx, cy), th / 2 - 2 * scale, it.on and Color(255, 255, 255, a(255)) or Color(174, 178, 184, a(255)))
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
				an.w = an.w_from + (an.w_to - an.w_from) * (1 - k * k * k)
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
			tween_width(an, 2 * math.floor((h + (cw > 0 and (K.ROW_LEAD * scale + cw + K.ROW_TAIL * scale) or 0)) / 2 + 0.5))
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

			if ui.camps_blur:Get() and alpha > 0.02 then Render.Blur(pa, pb, alpha, 1.0, r, ROUND_ALL) end
			Render.FilledRect(pa, pb, Color(14, 16, 18, a(184)), r, ROUND_ALL)

			local rr, thick = K.RING_R * scale, K.RING_W * scale
			local rgb, prog
			if st then
				local goal = clamp(st.prog or 1, 0, 1)
				if not an.prog or goal < an.prog - 0.2 then an.prog = goal end
				an.prog = approach(an.prog, goal, an.dt, K.PROG_SPEED)
				rgb, prog = an.rgb, an.prog
			else
				an.prog = nil
				rgb, prog = not e.off and COLORS.ok or nil, 1
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
				local color = Color(math.floor(rgb[1] + 0.5), math.floor(rgb[2] + 0.5), math.floor(rgb[3] + 0.5), a(255))
				if prog >= 1 then
					full_ring(p, rr, color, thick)
				else
					Render.Circle(p, rr, color, thick, 270, prog, false, 64)
				end
			end

			local icon = load_icon(def.icon)
			local s = K.RING_ICON * scale
			if icon then
				Render.Image(icon.handle, Vec2(p.x - s / 2, p.y - s / 2), Vec2(s, s), Color(255, 255, 255, a(e.off and 170 or 255)), s / 2, ROUND_ALL,
					icon.uv0, icon.uv1, e.off and 1.0 or 0.0)
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
		end

		local function draw_camps()
			state.hover = nil
			if not ui.camps:Get() then return end
			local hero = Heroes.GetLocal()
			if not hero or NPC.GetUnitName(hero) ~= def.unit then return end
			local dt = math.max(0.0, math.min(0.1, GlobalVars.GetAbsFrameTime() or 0.016))
			local scale = ui.camps_scale:Get() / 100
			local idle = ui.camps_idle:Get() / 100
			local screen = Render.ScreenSize()
			local r = K.RING_H * scale / 2
			local top = {}
			for _, c in ipairs(ctx.camp_list()) do
				local e = camp_data(c.key)
				local p, visible = Render.WorldToScreen(ctx.camp_spot(c.key, c.box))
				if visible then
					local an = state.anim[c.key]
					if not an then
						an = { a = 0.0 }
						state.anim[c.key] = an
					end
					an.dt = dt
					local st = camp_status(c.key)
					local w = an.w or (r * 2)
					local pad = an.hover and K.HOVER_PAD or 0
					local zone = an.hover and math.max(w, an.hover_w or 0) + pad * 2 or w
					local hovered = Input.IsCursorInRect(pill_left(p, zone, screen), p.y - r - pad, zone, r * 2 + pad * 2)
					if hovered and not an.hover then an.hover_w = w end
					an.hover = hovered
					if hovered then state.hover = c.key end
					an.a = approach(an.a, (st or hovered) and 1.0 or (e.off and idle * 0.65 or idle), dt, K.FADE_SPEED)
					if st then
						an.rgb = an.rgb or { st.rgb[1], st.rgb[2], st.rgb[3] }
						for k = 1, 3 do an.rgb[k] = approach(an.rgb[k], st.rgb[k], dt, K.COLOR_SPEED) end
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

		function script.OnDraw()
			if not active() then
				state.hover = nil
				return
			end
			local ok, err = pcall(draw_camps)
			if not ok and err ~= state.draw_error then
				state.draw_error = err
				Log.Write(def.tag .. " draw: " .. tostring(err))
			end
		end
	end

	return script
end

local stackers = { create_stacker(kunkka), create_stacker(invoker) }

local script = {}

function script.OnUpdate()
	for i = 1, #stackers do stackers[i].OnUpdate() end
end

function script.OnDraw()
	for i = 1, #stackers do stackers[i].OnDraw() end
end

function script.OnKeyEvent(data)
	for i = 1, #stackers do
		if stackers[i].OnKeyEvent(data) == false then return false end
	end
	return true
end

function script.OnGameEnd()
	for i = 1, #stackers do stackers[i].OnGameEnd() end
end

return script
