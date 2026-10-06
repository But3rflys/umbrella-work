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
		dh_group_main = "Main",
		dh_enable = "Enable",
		dh_enable_tip = "Shows the draft helper window",
		dh_key = "Open window",
		dh_key_tip = "Opens and closes the window",
		dh_s_debug = "Debug",
		dh_s_log = "Draft log",
		dh_s_log_sub = "Writes the draft state to the log",
		dh_s_panel = "Draft panel",
		dh_s_panel_sub = "Shows the draft state on screen",
		dh_d_mode = "Mode",
		dh_d_none = "No draft right now",
		dh_d_yes = "yes",
		dh_d_no = "no",
		dh_d_me = "you",
		dh_d_hover = "not locked",
		dh_d_us = "Side",
		dh_d_hero = "My hero",
		dh_d_first = "First pick",
		dh_d_captain = "You are captain",
		dh_d_need_captain = "Needs a captain",
		dh_d_our_turn = "Our team's turn",
		dh_d_turn = "Current turn",
		dh_d_order = "Turns",
		dh_d_ban_phase = "Ban phase",
		dh_d_in_control = "Can pick",
		dh_d_selected = "Hero picked",
		dh_d_team_r = "Radiant",
		dh_d_team_d = "Dire",
		dh_d_banned = "Banned",
		dh_d_picked = "Taken",
		dh_d_off = "Unavailable",
		dh_live_captain = "The captain bans and picks",
		dh_live_wait = "Not your turn yet",
		dh_bind_name = "Draft Helper",

		dh_title = "Draft",
		dh_out = "Outside a match",
		dh_training = "Training",
		dh_search = "Search hero",
		dh_chance = "Draft win chance",
		dh_side_r = "Radiant",
		dh_side_d = "Dire",
		dh_we = "Us",
		dh_bans16 = "16 bans",

		dh_our_ban = "Our ban",
		dh_enemy_ban = "Enemy ban",
		dh_our_pick = "Our pick",
		dh_enemy_pick = "Enemy pick",
		dh_step_of = "turn %d of 24",
		dh_round_of = "round %d of 3",
		dh_sub_noctx = "No picks yet, sorted by hero win rate",
		dh_sub_our_ban = "The most dangerous heroes for us",
		dh_sub_enemy_ban = "Our best picks, they may take them",
		dh_sub_our_pick = "Best picks for this draft",
		dh_sub_enemy_pick = "Best enemy picks against us",
		dh_sub_filter = "Best %s against their draft",
		dh_sub_lane = "Stronger in lane against their laners",
		dh_s_goal = "Pick heroes for",
		dh_s_goal_sub = "Game: chance to win. Lane: beats your lane opponents",
		dh_goal_draft = "Game",
		dh_goal_lane = "Lane",
		dh_double_next = "Double pick, turn %d is next",
		dh_double_second = "Second pick in a row",
		dh_enemy_auto_pick = "Enemy is choosing, the pick fills in",
		dh_enemy_auto_ban = "Enemy is choosing, the ban fills in",
		dh_enemy_manual_pick = "Pick for the enemy",
		dh_enemy_manual_ban = "Ban for the enemy",
		dh_ap_last = "Last pick of the round",
		dh_ap_left = "%d picks left in the round",
		dh_ap_hidden = "Enemy picks are hidden until the round ends",
		dh_ap_counter = "Counters to the revealed enemy heroes",
		dh_ap_reveal = "Round over, the enemy reveals picks",

		dh_auto = "Auto",
		dh_pos_1 = "Carry",
		dh_pos_2 = "Mid",
		dh_pos_3 = "Offlane",
		dh_pos_4 = "Soft support",
		dh_pos_5 = "Hard support",
		dh_posa_1 = "carries",
		dh_posa_2 = "mids",
		dh_posa_3 = "offlaners",
		dh_posa_4 = "soft supports",
		dh_posa_5 = "hard supports",
		dh_vs = "vs",
		dh_close = "closes",
		dh_with = "with",
		dh_weak = "weak vs",
		dh_badwith = "bad with",
		dh_by_rate = "by hero win rate",
		dh_matches = "%s matches",
		dh_how_confirm = "Click selects a hero, double click picks at once, right click opens the menu",
		dh_how_click = "Click picks a hero, right click opens the menu",
		dh_how_enemy = "This is a forecast of the enemy turn",
		dh_empty_pos = "No free heroes for this position",
		dh_empty_pool = "No free heroes from the pool for this turn",
		dh_open_pool = "Open the pool",

		dh_search_title = "Search",
		dh_search_sub = "How heroes fit this turn",
		dh_search_enemy = "It is the enemy turn, their pick fills in",
		dh_search_done = "The draft is complete",
		dh_search_none = "No free hero with that name",
		dh_no_data = "no data",

		dh_done = "Draft complete",
		dh_done_cm = "All 24 turns are done",
		dh_done_ap = "All three rounds are done",

		dh_ban_word = "Ban",
		dh_pick_word = "Pick",
		dh_at_step = "turn %d",
		dh_at_round = "round %d",
		dh_select = "Pick",
		dh_ban_btn = "Ban",
		dh_cancel = "Cancel",

		dh_pos_of = "Position of",
		dh_swap = "swap with %s",
		dh_m_select = "Select",
		dh_m_click = "click",
		dh_m_dbl = "double click",
		dh_m_pool_add = "Add to pool",
		dh_m_pool_del = "Remove from pool",
		dh_m_on_pos = "Pick as",
		dh_m_taken = "taken",

		dh_home_sub = "No match right now. Train or tune the hints",
		dh_h_train = "Training draft",
		dh_h_cm_sub = "24 turns, bans and picks in order",
		dh_h_ap_sub = "16 auto bans and three pick rounds",
		dh_start = "Start",
		dh_h_foot_auto = "The script plays for the enemy using its own hints. Change it in settings.",
		dh_h_foot_manual = "You pick for the enemy in Captains Mode. Change it in settings.",
		dh_h_last = "Last draft",
		dh_h_last_foot = "It is shown on the board",
		dh_h_training = "training",
		dh_h_match = "match",
		dh_h_last_chance = "draft win chance %d%%",
		dh_h_hints = "Hints",
		dh_pool = "My hero pool",
		dh_change = "Change",
		dh_settings = "Settings",
		dh_settings_sub = "Data, hints, hero pick, window",
		dh_open = "Open",

		dh_pool_title = "My pool",
		dh_pool_boost_sub = "They go higher in hints for our picks",
		dh_pool_only_sub = "Only these heroes in hints for our picks",
		dh_pool_off_sub = "The pool is ignored right now",
		dh_pool_boost = "Raise higher",
		dh_pool_only = "Pool only",
		dh_pool_off = "Ignore",
		dh_pool_clear = "Clear pool",
		dh_pool_count = "%d of %d in pool",
		dh_pool_short_boost = "raised higher",
		dh_pool_short_only = "only them",
		dh_pool_short_off = "ignored",
		dh_attr_str = "Strength",
		dh_attr_agi = "Agility",
		dh_attr_int = "Intelligence",
		dh_attr_all = "Universal",
		dh_hero_1 = "hero",
		dh_hero_2 = "heroes",
		dh_hero_5 = "heroes",

		dh_set_sub = "Saved right away",
		dh_ready = "Done",
		dh_s_data = "Data",
		dh_s_rank = "Match rank",
		dh_rank_1 = "All",
		dh_rank_2 = "Legend+",
		dh_rank_3 = "Ancient+",
		dh_rank_4 = "Divine+",
		dh_s_hints = "Hints",
		dh_s_count = "Heroes in the list",
		dh_s_reasons = "Reasons under a hero",
		dh_s_reasons_sub = "Who he is good against and with",
		dh_s_chance = "Draft win chance",
		dh_s_pick = "Hero pick",
		dh_s_confirm = "Confirm the pick",
		dh_s_confirm_sub = "Click selects a hero, pick with the button or Enter",
		dh_s_captain = "Auto captain",
		dh_s_captain_sub = "Takes the captain role in Captains Mode right away",
		dh_s_train = "Training",
		dh_s_enemy = "Enemy turns",
		dh_s_enemy_sub = "Captains Mode only",
		dh_s_enemy_auto = "Script plays",
		dh_s_enemy_manual = "Manual",
		dh_s_side = "Our side",
		dh_s_light = "Radiant",
		dh_s_dark = "Dire",
		dh_s_first = "First pick",
		dh_s_first_sub = "Captains Mode only",
		dh_s_first_us = "Ours",
		dh_s_first_them = "Enemy",
		dh_s_train_foot = "Side and first pick apply to the next training.",
		dh_s_window = "Window",
		dh_s_auto = "Open on its own in the draft",
		dh_s_auto_sub = "And close when the draft is over",
		dh_s_scale = "Window size",
		dh_s_blur = "Background blur",
		dh_s_blur_power = "Blur strength",
		dh_s_defaults = "Restore default settings",
		dh_s_about = "About",
		dh_s_hover = "Hover tips",
		dh_s_hover_sub = "What buttons do and how to pick a hero",
		dh_tip_close = "Close the window",
		dh_tip_settings = "Settings",
		dh_tip_back = "Back",
		dh_tip_reset = "Start the training over",
		dh_tip_undo = "Undo the last turn",
		dh_tip_home = "Back to the main screen",
		dh_tip_update = "Download and install the new version",
		dh_tip_slot = "Click to change the hero position",
		dh_version = "Version %s",
		dh_upd_latest = "Latest version",
		dh_upd_checking = "Checking for updates",
		dh_upd_available = "%s is available",
		dh_upd_loading = "Downloading %s",
		dh_upd_done = "Installed, restarting scripts",
		dh_upd_failed = "Update failed",
		dh_upd_check_failed = "Could not check for updates",
		dh_upd_check = "Check",
		dh_upd_install = "Update",
		dh_upd_retry = "Retry",
		dh_upd_ready = "Done",
		dh_upd_pill = "Update to %s",
		dh_upd_pill_loading = "Downloading",
		dh_upd_pill_done = "Restarting",
		dh_upd_bad_file = "the downloaded file is not this script",
		dh_upd_bad_manifest = "broken version.json",
		dh_upd_write = "could not write the file",

		dh_b_row = "Item builds",
		dh_b_row_sub = "For our team, vs this draft",
		dh_b_who = "WHO BEATS WHO",
		dh_b_who_sub = "% to win chance, ours vs theirs",
		dh_b_total = "total",
		dh_b_build = "BUILD",
		dh_b_m_build = "Item build",
		dh_b_dev = "In development",
		dh_data_loading = "Loading draft data from GitHub",
		dh_data_error = "No connection to GitHub",
		dh_data_empty = "empty response",
		dh_data_no_answer = "the server did not answer",
		dh_data_not_sent = "the request was not sent",
		dh_data_none = "No data for this rank yet",
		dh_data_missing = "No data on GitHub yet, it is built once a day",
		dh_match_1 = "match",
		dh_match_2 = "matches",
		dh_match_5 = "matches",
		dh_months = "Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec",
		dh_range_same = "{m1} {d1} to {d2}",
		dh_range = "{m1} {d1} to {m2} {d2}",
		dh_s_source = "Matches",
		dh_source_ap = "Ranked",
		dh_pool_none = "No hero with this name",
		dh_data_ok = "%s %s, %s",
	},
	ru = {
		dh_group_main = "Основное",
		dh_enable = "Включить",
		dh_enable_tip = "Показывает окно помощника драфта",
		dh_key = "Открыть окно",
		dh_key_tip = "Открывает и закрывает окно",
		dh_s_debug = "Отладка",
		dh_s_log = "Лог драфта",
		dh_s_log_sub = "Пишет в лог состояние драфта",
		dh_s_panel = "Панель драфта",
		dh_s_panel_sub = "Показывает состояние драфта на экране",
		dh_d_mode = "Режим",
		dh_d_none = "Драфта сейчас нет",
		dh_d_yes = "да",
		dh_d_no = "нет",
		dh_d_me = "вы",
		dh_d_hover = "не выбран",
		dh_d_us = "Сторона",
		dh_d_hero = "Мой герой",
		dh_d_first = "Первый пик",
		dh_d_captain = "Вы капитан",
		dh_d_need_captain = "Нужен капитан",
		dh_d_our_turn = "Ход нашей команды",
		dh_d_turn = "Текущий ход",
		dh_d_order = "Ходы",
		dh_d_ban_phase = "Фаза банов",
		dh_d_in_control = "Можно пикать",
		dh_d_selected = "Герой выбран",
		dh_d_team_r = "Свет",
		dh_d_team_d = "Тьма",
		dh_d_banned = "Забанены",
		dh_d_picked = "Взяты",
		dh_d_off = "Недоступны",
		dh_live_captain = "Банит и пикает капитан",
		dh_live_wait = "Сейчас не твой ход",
		dh_bind_name = "Draft Helper",

		dh_title = "Драфт",
		dh_out = "Вне матча",
		dh_training = "Тренировка",
		dh_search = "Поиск героя",
		dh_chance = "Шанс по драфту",
		dh_side_r = "Силы Света",
		dh_side_d = "Силы Тьмы",
		dh_we = "Мы",
		dh_bans16 = "16 банов",

		dh_our_ban = "Наш бан",
		dh_enemy_ban = "Бан врага",
		dh_our_pick = "Наш пик",
		dh_enemy_pick = "Пик врага",
		dh_step_of = "ход %d из 24",
		dh_round_of = "раунд %d из 3",
		dh_sub_noctx = "Пиков ещё нет, порядок по винрейту героев",
		dh_sub_our_ban = "Самые опасные для нас герои",
		dh_sub_enemy_ban = "Наши лучшие пики, их могут забрать",
		dh_sub_our_pick = "Лучшие пики под этот драфт",
		dh_sub_enemy_pick = "Лучшие пики врага против нас",
		dh_sub_filter = "Лучшие на %s против их драфта",
		dh_sub_lane = "Сильнее на линии против их героев",
		dh_s_goal = "Подбирать героя",
		dh_s_goal_sub = "На игру: шанс выиграть. На линию: сильнее соперников по линии",
		dh_goal_draft = "На игру",
		dh_goal_lane = "На линию",
		dh_double_next = "Двойной пик, следом ход %d",
		dh_double_second = "Второй пик подряд",
		dh_enemy_auto_pick = "Враг выбирает, пик встанет сам",
		dh_enemy_auto_ban = "Враг выбирает, бан встанет сам",
		dh_enemy_manual_pick = "Выбери пик за врага",
		dh_enemy_manual_ban = "Выбери бан за врага",
		dh_ap_last = "Последний пик раунда",
		dh_ap_left = "Ещё %d пика в раунде",
		dh_ap_hidden = "Пики врага скрыты до конца раунда",
		dh_ap_counter = "Контрпики к открытым героям врага",
		dh_ap_reveal = "Раунд окончен, враг открывает пики",

		dh_auto = "Авто",
		dh_pos_1 = "Керри",
		dh_pos_2 = "Мид",
		dh_pos_3 = "Оффлейн",
		dh_pos_4 = "Четвёрка",
		dh_pos_5 = "Пятёрка",
		dh_posa_1 = "керри",
		dh_posa_2 = "мид",
		dh_posa_3 = "оффлейн",
		dh_posa_4 = "четвёрку",
		dh_posa_5 = "пятёрку",
		dh_vs = "против",
		dh_close = "закрывает",
		dh_with = "с",
		dh_weak = "слаб против",
		dh_badwith = "плохо с",
		dh_by_rate = "по винрейту героя",
		dh_matches = "%s матчей",
		dh_how_confirm = "Клик выделяет героя, двойной клик выбирает сразу, правая кнопка открывает меню",
		dh_how_click = "Клик выбирает героя, правая кнопка открывает меню",
		dh_how_enemy = "Это прогноз хода врага",
		dh_empty_pos = "На эту позицию свободных героев нет",
		dh_empty_pool = "В пуле нет свободных героев на этот ход",
		dh_open_pool = "Открыть пул",

		dh_search_title = "Поиск",
		dh_search_sub = "Оценка героев на этот ход",
		dh_search_enemy = "Сейчас ход врага, его пик встанет сам",
		dh_search_done = "Драфт уже собран",
		dh_search_none = "Свободного героя с таким именем нет",
		dh_no_data = "нет данных",

		dh_done = "Драфт собран",
		dh_done_cm = "Все 24 хода сделаны",
		dh_done_ap = "Все три раунда позади",

		dh_ban_word = "Бан",
		dh_pick_word = "Пик",
		dh_at_step = "ход %d",
		dh_at_round = "раунд %d",
		dh_select = "Выбрать",
		dh_ban_btn = "Забанить",
		dh_cancel = "Отмена",

		dh_pos_of = "Позиция",
		dh_swap = "обмен с %s",
		dh_m_select = "Выделить",
		dh_m_click = "клик",
		dh_m_dbl = "двойной клик",
		dh_m_pool_add = "Добавить в пул",
		dh_m_pool_del = "Убрать из пула",
		dh_m_on_pos = "Выбрать на позицию",
		dh_m_taken = "занят",

		dh_home_sub = "Матча сейчас нет. Можно потренироваться или настроить подсказки",
		dh_h_train = "Тренировочный драфт",
		dh_h_cm_sub = "24 хода, баны и пики по очереди",
		dh_h_ap_sub = "16 автобанов и три раунда пиков",
		dh_start = "Начать",
		dh_h_foot_auto = "За врага ходит скрипт по своим подсказкам. Это меняется в настройках.",
		dh_h_foot_manual = "За врага в Captains Mode пикаешь ты сам. Это меняется в настройках.",
		dh_h_last = "Прошлый драфт",
		dh_h_last_foot = "Он показан на доске слева",
		dh_h_training = "тренировка",
		dh_h_match = "матч",
		dh_h_last_chance = "шанс по драфту %d%%",
		dh_h_hints = "Подсказки",
		dh_pool = "Мой пул героев",
		dh_change = "Изменить",
		dh_settings = "Настройки",
		dh_settings_sub = "Данные, подсказки, выбор героя, окно",
		dh_open = "Открыть",

		dh_pool_title = "Мой пул",
		dh_pool_boost_sub = "В подсказках на наши пики они идут выше",
		dh_pool_only_sub = "В подсказках на наши пики только эти герои",
		dh_pool_off_sub = "Сейчас пул не учитывается",
		dh_pool_boost = "Поднимать выше",
		dh_pool_only = "Только пул",
		dh_pool_off = "Не учитывать",
		dh_pool_clear = "Очистить пул",
		dh_pool_count = "в пуле %d из %d",
		dh_pool_short_boost = "поднимаются выше",
		dh_pool_short_only = "только они",
		dh_pool_short_off = "не учитывается",
		dh_attr_str = "Сила",
		dh_attr_agi = "Ловкость",
		dh_attr_int = "Интеллект",
		dh_attr_all = "Универсал",
		dh_hero_1 = "герой",
		dh_hero_2 = "героя",
		dh_hero_5 = "героев",

		dh_set_sub = "Сохраняются сразу",
		dh_ready = "Готово",
		dh_s_data = "Данные",
		dh_s_rank = "Ранг матчей",
		dh_rank_1 = "Все",
		dh_rank_2 = "Легенда+",
		dh_rank_3 = "Властелин+",
		dh_rank_4 = "Божество+",
		dh_s_hints = "Подсказки",
		dh_s_count = "Героев в списке",
		dh_s_reasons = "Причины под героем",
		dh_s_reasons_sub = "Против кого и с кем он хорош",
		dh_s_chance = "Шанс по драфту",
		dh_s_pick = "Выбор героя",
		dh_s_confirm = "Подтверждать выбор",
		dh_s_confirm_sub = "Клик выделяет героя, выбор кнопкой или Enter",
		dh_s_captain = "Авто капитан",
		dh_s_captain_sub = "Сразу забирает роль капитана в Captains Mode",
		dh_s_train = "Тренировка",
		dh_s_enemy = "Ходы врага",
		dh_s_enemy_sub = "Только в Captains Mode",
		dh_s_enemy_auto = "Делает скрипт",
		dh_s_enemy_manual = "Вручную",
		dh_s_side = "Наша сторона",
		dh_s_light = "Свет",
		dh_s_dark = "Тьма",
		dh_s_first = "Первый пик",
		dh_s_first_sub = "Только для Captains Mode",
		dh_s_first_us = "Наш",
		dh_s_first_them = "У врага",
		dh_s_train_foot = "Сторона и первый пик применяются к новой тренировке.",
		dh_s_window = "Окно",
		dh_s_auto = "Открывать само на драфте",
		dh_s_auto_sub = "И закрывать, когда драфт закончен",
		dh_s_scale = "Размер окна",
		dh_s_blur = "Размытие фона",
		dh_s_blur_power = "Сила размытия",
		dh_s_defaults = "Вернуть настройки по умолчанию",
		dh_s_about = "О скрипте",
		dh_s_hover = "Подсказки при наведении",
		dh_s_hover_sub = "Что делают кнопки и как выбирать героя",
		dh_tip_close = "Закрыть окно",
		dh_tip_settings = "Настройки",
		dh_tip_back = "Назад",
		dh_tip_reset = "Начать тренировку заново",
		dh_tip_undo = "Отменить последний ход",
		dh_tip_home = "На главный экран",
		dh_tip_update = "Скачать и установить новую версию",
		dh_tip_slot = "Клик меняет позицию героя",
		dh_version = "Версия %s",
		dh_upd_latest = "Последняя версия",
		dh_upd_checking = "Проверяю обновления",
		dh_upd_available = "Доступна %s",
		dh_upd_loading = "Скачиваю %s",
		dh_upd_done = "Установлено, перезапускаю скрипты",
		dh_upd_failed = "Не удалось обновить",
		dh_upd_check_failed = "Не удалось проверить обновления",
		dh_upd_check = "Проверить",
		dh_upd_install = "Обновить",
		dh_upd_retry = "Повторить",
		dh_upd_ready = "Готово",
		dh_upd_pill = "Обновить до %s",
		dh_upd_pill_loading = "Загрузка",
		dh_upd_pill_done = "Перезапуск",
		dh_upd_bad_file = "скачанный файл не похож на этот скрипт",
		dh_upd_bad_manifest = "битый version.json",
		dh_upd_write = "не удалось записать файл",

		dh_b_row = "Сборки предметов",
		dh_b_row_sub = "На нашу команду, под этот драфт",
		dh_b_who = "КТО КОГО",
		dh_b_who_sub = "% к шансу победы, наши против их",
		dh_b_total = "итог",
		dh_b_build = "СБОРКА",
		dh_b_m_build = "Сборка предметов",
		dh_b_dev = "В разработке",
		dh_data_loading = "Загружаю данные драфта с GitHub",
		dh_data_error = "Нет связи с GitHub",
		dh_data_empty = "пустой ответ",
		dh_data_no_answer = "сервер не ответил",
		dh_data_not_sent = "запрос не отправлен",
		dh_data_none = "Для этого ранга данных пока нет",
		dh_data_missing = "Данных на GitHub пока нет, они собираются раз в сутки",
		dh_match_1 = "матч",
		dh_match_2 = "матча",
		dh_match_5 = "матчей",
		dh_months = "января,февраля,марта,апреля,мая,июня,июля,августа,сентября,октября,ноября,декабря",
		dh_range_same = "с {d1} по {d2} {m2}",
		dh_range = "с {d1} {m1} по {d2} {m2}",
		dh_s_source = "Матчи",
		dh_source_ap = "Рейтинговые",
		dh_pool_none = "Героя с таким именем нет",
		dh_data_ok = "%s %s %s",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Draft Helper")
	tab:Icon("\u{f0cb}")

	local page = tab:Create("Settings")
	local g_main = page:Create("dh_group_main", Enum.GroupSide.Left)

	ui.enable = g_main:Switch("dh_enable", false, "\u{f011}")
	ui.enable:ToolTip("dh_enable_tip")

	ui.key = g_main:Bind("dh_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("dh_key_tip")
	ui.key:Properties(L("dh_bind_name"))
end

local K = {
	VERSION = "2.0.0-alpha.3",
	CFG = "draft_helper",
	W = 1100,
	H = 716,
	TB = 52,
	PAN = 400,
	CX = 434,
	CW = 632,
	P = 14,
	BOARD_Y = 66,
	NUMY = { 59, 86, 103, 122, 139, 167, 203, 235, 258, 292, 318, 336, 358, 382, 403, 426, 446, 470, 493, 510, 530, 547, 570, 594 },
	TOPY = { 43, 78, 79, 114, 114, 150, 186, 226, 226, 274, 310, 310, 350, 350, 394, 394, 438, 438, 486, 486, 522, 522, 562, 562 },
	AP_Y = { 176, 240, 330, 394, 488 },
	AP_ROUND = { 1, 1, 2, 2, 3 },
	AP_MID = { 237, 391, 517 },
	AP_ROUND_END = { 2, 4, 5 },

	ORDER = { "BF", "BF", "BS", "BS", "BF", "BS", "BS", "PF", "PS", "BF", "BF", "BS", "PS", "PF", "PF", "PS", "PS", "PF", "BF", "BS", "BF", "BS", "PF", "PS" },
	RANKS = { 0, 50, 60, 70 },
	ATTRS = { "str", "agi", "int", "all" },
	POS_ICON = { "safelane", "midlane", "offlane", "softsupport", "hardsupport" },

	PORTRAIT = "panorama/images/heroes/npc_dota_hero_%s_png.vtex_c",
	ICON = "panorama/images/heroes/icons/npc_dota_hero_%s_png.vtex_c",
	POS = "panorama/images/rank_tier_icons/handicap/%sicon_psd.vtex_c",
	G = {
		undo = "\u{f2ea}", trash = "\u{f2ed}", gear = "\u{f013}", search = "\u{f002}", clear = "\u{f057}", wand = "\u{e2ca}",
		hidden = "\u{f070}", check = "\u{f00c}", ban = "\u{f05e}", pointer = "\u{f245}", star = "\u{f005}", chevron = "\u{f054}",
		plus = "\u{f067}", minus = "\u{f068}", chart = "\u{e473}", list = "\u{f0cb}", comment = "\u{f4ad}", percent = "\u{f295}",
		hand = "\u{f25a}", expand = "\u{f424}", house = "\u{f015}", chess = "\u{f43c}", users = "\u{f0c0}", robot = "\u{f544}",
		flag = "\u{f024}", finish = "\u{f11e}", bag = "\u{f290}", crown = "\u{f521}", bug = "\u{f188}", close = "\u{f00d}",
		blur = "\u{f042}", drop = "\u{f043}", eye = "\u{f06e}",
		arrow_down = "\u{f063}", alert = "\u{f06a}", info = "\u{f05a}",
	},

	ENEMY_DELAY = 1.5,
	REVEAL_DELAY = 0.7,
	FADE = 0.2,
	DOUBLE_CLICK = 0.35,
	WHEEL = 112,
	BOOST = 2.5,
	GLASS = 0.3,
	TIP_DELAY = 0.35,
	DEF = {
		rank = 4,
		count = 8,
		reasons = 1,
		chance = 1,
		confirm = 1,
		auto = 1,
		scale = 100,
		pool_mode = "boost",
		tr_enemy = "auto",
		tr_side = "d",
		tr_first = "us",
		goal = "draft",
		source = "ap",
		captain = 0,
		log = 0,
		panel = 0,
		blur = 0,
		blur_power = 50,
		hints = 1,
	},
	LIVE_READ = 0.1,
	LIVE_CAPTAIN = 0.1,
	LIVE_GRID = 0.3,
	LIVE_GRID_HEROES = 2,
}

local MODEL = {
	PRIOR = 250,
	PAIR = 600,
	POS_MIN = 10,
	REASON_MIN = 0.3,
	THREAT = 0.15,
	BASE_W = 0.4,
	COVER = 1,
	LANE_REST = 0.25,
	LANE_VS = { { [3] = true, [4] = true }, { [2] = true }, { [1] = true, [5] = true }, { [1] = true, [5] = true }, { [3] = true, [4] = true } },
	LANE_WITH = { { [5] = true }, {}, { [4] = true }, { [3] = true }, { [1] = true } },
}

local NET = {
	URL = "https://raw.githubusercontent.com/But3rflys/umbrella-work/draft-data/",
	HEADERS = { ["User-Agent"] = "Umbrella/draft-helper" },
	TIMEOUT = 60,
	RETRY = 60,
	CHECK = 3600,
	VERSION_URL = "https://raw.githubusercontent.com/But3rflys/umbrella-work/main/scripts/draft_helper/version.json",
	UPDATE_TIMEOUT = 120,
	RELOAD_DELAY = 1.2,
}

local JS = {
	SINK = [[
(function () {
	let root = $.GetContextPanel();
	while (root.GetParent()) root = root.GetParent();
	let sink = root.FindChild('DraftHelperInput');
	if (%s) {
		if (!sink) {
			sink = $.CreatePanel('TextEntry', root, 'DraftHelperInput');
			sink.style.width = '1px';
			sink.style.height = '1px';
			sink.style.opacity = '0';
			sink.hittest = false;
		}
		sink.text = '';
		sink.SetFocus();
	} else if (sink) {
		sink.text = '';
		sink.DeleteAsync(0);
	}
})();
]],
	CAPTAIN = [[
(function () {
	const button = $.GetContextPanel().FindChildTraverse('CaptainsModeBecomeCaptainButton');
	if (button) $.DispatchEvent('Activated', button, 'mouse');
})();
]],
	ACT = [[
(function () {
	const pre = $.GetContextPanel();
	const hero = '%s';
	const grid = pre.FindChildTraverse('HeroGrid');
	if (!grid) return;
	const card = grid.FindChildrenWithClassTraverse('HeroCard').find(c => {
		const img = c.FindChildTraverse('HeroImage');
		return img && (img.heroname === hero || img.heroname === 'npc_dota_hero_' + hero);
	});
	if (!card) return;
	$.DispatchEvent('Activated', card, 'mouse');
	$.Schedule(0.15, () => {
		const button = pre.FindChildTraverse('%s');
		if (button && pre.BHasClass('InspectedHeroAvailableToPick')) $.DispatchEvent('Activated', button, 'mouse');
	});
})();
]],
}

local C = {
	main = { 15, 15, 16 }, side = { 22, 22, 24 }, bar = { 26, 26, 28 }, card = { 28, 28, 30 }, raised = { 44, 44, 46 },
	text = { 255, 255, 255 }, text2 = { 235, 235, 245, 153 }, text3 = { 235, 235, 245, 77 }, text4 = { 235, 235, 245, 46 },
	sep = { 84, 84, 88, 153 }, sep2 = { 84, 84, 88, 87 }, fill2 = { 120, 120, 128, 82 }, fill3 = { 118, 118, 128, 61 }, fill4 = { 118, 118, 128, 46 },
	slot_cur = { 120, 120, 128, 87 }, slot_line = { 255, 255, 255, 56 }, tick_cur = { 255, 255, 255, 140 },
	green = { 48, 209, 88 }, red = { 255, 69, 58 }, blue = { 10, 132, 255 }, thumb = { 99, 99, 102 }, yellow = { 255, 214, 10 }, black = { 0, 0, 0 },
	hover = { 255, 255, 255, 9 }, select = { 10, 132, 255, 51 }, badge = { 0, 0, 0, 168 }, key = { 0, 0, 0, 72 }, border = { 255, 255, 255, 20 }, outline = { 255, 255, 255, 26 },
	ban_tint = { 115, 115, 115 }, focus = { 10, 132, 255, 230 }, sb = { 235, 235, 245, 77 }, sb_hover = { 235, 235, 245, 140 },
	t_blue = { 10, 132, 255 }, t_indigo = { 94, 92, 230 }, t_orange = { 255, 159, 10 }, t_gray = { 142, 142, 147 }, t_teal = { 48, 176, 199 },
	t_green = { 48, 209, 88 }, t_purple = { 191, 90, 242 }, t_cyan = { 100, 210, 255 },
}

local ROUND = Enum.DrawFlags.RoundCornersAll

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function ease_out(t) return 1 - (1 - t) * (1 - t) end
local function ease_in_out(t)
	if t < 0.5 then return 4 * t * t * t end
	local f = 2 - 2 * t
	return 1 - f * f * f / 2
end
local function signed(v) return (v >= 0 and "+" or "") .. string.format("%.1f", v) end
local function plural(n, base)
	local m10, m100 = n % 10, n % 100
	local form = (m10 == 1 and m100 ~= 11) and "_1" or ((m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14)) and "_2" or "_5")
	return L(base .. form)
end
local function heroes_n(n) return n .. " " .. plural(n, "dh_hero") end

local asset = { fonts = {}, images = {}, digits = {}, sizes = {} }

function asset.font(weight)
	local f = asset.fonts[weight]
	if not f then
		f = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, weight)
		asset.fonts[weight] = f
	end
	return f
end

function asset.size(font, px, str)
	local by_font = asset.sizes[font]
	if not by_font then
		by_font = {}
		asset.sizes[font] = by_font
	end
	local by_px = by_font[px]
	if not by_px then
		by_px = {}
		by_font[px] = by_px
	end
	local v = by_px[str]
	if not v then
		v = Render.TextSize(font, px, str)
		by_px[str] = v
	end
	return v
end

function asset.digit_w(font, px)
	local key = tostring(font) .. ":" .. px
	local w = asset.digits[key]
	if not w then
		w = 0
		for d = 0, 9 do w = math.max(w, asset.size(font, px, tostring(d)).x) end
		asset.digits[key] = w
	end
	return w
end

function asset.icons()
	if not asset.fonts.icon then
		asset.fonts.icon = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
	end
	return asset.fonts.icon
end

function asset.image(path)
	local h = asset.images[path]
	if h == nil then
		local ok, handle = pcall(Render.LoadImage, path)
		h = ok and handle or false
		asset.images[path] = h
	end
	return h or nil
end

function asset.portrait(h) return asset.image(K.PORTRAIT:format(h)) end
function asset.icon(h) return asset.image(K.ICON:format(h)) end
function asset.pos(p) return asset.image(K.POS:format(K.POS_ICON[p])) end

local data = {
	heroes = {}, list = {}, by_attr = {}, by_id = {},
	manifest = nil, sets = {}, busy = {}, wait = {}, failed = false, next_check = 0,
}

do
	local ok, json = pcall(require, "assets.JSON")
	data.json = ok and json or nil
end

function data.path(name)
	local dir = Engine.GetCheatDirectory()
	if not dir:match("[\\/]$") then dir = dir .. "\\" end
	return dir .. "configs\\draft_helper_" .. name
end

function data.read(name)
	local f = io.open(data.path(name), "rb")
	if not f then return nil end
	local text = f:read("a")
	f:close()
	return text
end

function data.write(name, text)
	local f = io.open(data.path(name), "wb")
	if not f then return end
	f:write(text)
	f:close()
end

function data.decode(text)
	if not text or not data.json then return nil end
	local ok, v = pcall(data.json.decode, data.json, text)
	return ok and type(v) == "table" and v or nil
end

function data.fetch(name, done)
	if data.busy[name] or (data.wait[name] or 0) > os.clock() then return end
	data.busy[name] = true
	local sent = HTTP.Request("GET", NET.URL .. name, { headers = NET.HEADERS, timeout = NET.TIMEOUT }, function(r)
		data.busy[name] = nil
		local code = tonumber(r.code) or 0
		local message = r.error_message ~= "" and r.error_message or nil
		if code == 200 and type(r.response) == "string" and #r.response > 0 then
			data.failed, data.error = false, nil
			done(r.response)
		elseif code == 200 then
			data.fail(name, L("dh_data_empty"), code)
			done(nil)
		else
			data.fail(name, code > 0 and ("HTTP " .. code .. (message and (", " .. message) or "")) or message or L("dh_data_no_answer"), code)
			done(nil)
		end
	end, name)
	if not sent then
		data.busy[name] = nil
		data.fail(name, L("dh_data_not_sent"), 0)
		done(nil)
	end
end

function data.fail(name, reason, code)
	data.failed, data.code, data.wait[name] = true, code, os.clock() + NET.RETRY
	data.error = name .. ": " .. reason
	Log.Write("[Draft Helper] " .. data.error)
end

function data.set_heroes(list)
	data.heroes, data.list, data.by_id = {}, {}, {}
	for _, a in ipairs(K.ATTRS) do data.by_attr[a] = {} end
	for _, e in ipairs(list) do
		local shares, main = e.pos, 1
		for p = 2, 5 do if shares[p] > shares[main] then main = p end end
		local hero = {
			h = e.name, id = e.id, name = Engine.GetDisplayNameByUnitName("npc_dota_hero_" .. e.name) or e.name,
			attr = data.by_attr[e.attr] and e.attr or "all", pos = main, shares = shares, rate = 50, games = 0,
		}
		data.heroes[hero.h], data.by_id[hero.id] = hero, hero
		data.list[#data.list + 1] = hero
		table.insert(data.by_attr[hero.attr], hero)
	end
	local by_name = function(a, b) return a.name < b.name end
	table.sort(data.list, by_name)
	for _, list in pairs(data.by_attr) do table.sort(list, by_name) end
	data.shown = nil
end

function data.boot()
	for _, a in ipairs(K.ATTRS) do data.by_attr[a] = {} end
	data.manifest = data.decode(data.read("manifest.json"))
	local heroes = data.decode(data.read("heroes.json"))
	if heroes then data.set_heroes(heroes) end
end

function data.tick()
	if os.clock() < data.next_check then return end
	data.next_check = os.clock() + NET.RETRY
	data.fetch("manifest.json", function(text)
		local m = data.decode(text)
		if not m or type(m.sets) ~= "table" then return end
		data.next_check = os.clock() + NET.CHECK
		if data.manifest and data.manifest.time == m.time and next(data.heroes) then return end
		data.fetch("heroes.json", function(body)
			local heroes = data.decode(body)
			if not heroes then return end
			data.write("heroes.json", body)
			data.write("manifest.json", text)
			data.manifest = m
			data.set_heroes(heroes)
		end)
	end)
end

function data.parse(text, time)
	local st = { time = time, n = tonumber(text:match("^n (%d+)")) or 0, hg = {}, hw = {}, sg = {}, sw = {}, vg = {}, vw = {}, base = {} }
	for id, g, w in text:gmatch("\nh (%d+) (%d+) (%d+)") do
		local h = tonumber(id)
		st.hg[h], st.hw[h] = tonumber(g), tonumber(w)
	end
	for a, b, g, w in text:gmatch("\ns (%d+) (%d+) (%d+) (%d+)") do
		local k = tonumber(a) * 256 + tonumber(b)
		st.sg[k], st.sw[k] = tonumber(g), tonumber(w)
	end
	for a, b, g, w in text:gmatch("\nv (%d+) (%d+) (%d+) (%d+)") do
		local k = tonumber(a) * 256 + tonumber(b)
		st.vg[k], st.vw[k] = tonumber(g), tonumber(w)
	end
	return st
end

function data.stats(key)
	local info = data.manifest and data.manifest.sets[key]
	local cur = data.sets[key]
	if not info or (cur and cur.time == info.time) then return cur end
	if Config.ReadInt(K.CFG, "set_" .. key, 0) == info.time then
		local text = data.read(key .. ".txt")
		if text then
			data.sets[key] = data.parse(text, info.time)
			return data.sets[key]
		end
	end
	data.fetch("stats/" .. key .. ".txt", function(text)
		if not text then return end
		data.write(key .. ".txt", text)
		Config.WriteInt(K.CFG, "set_" .. key, info.time)
		data.sets[key] = data.parse(text, info.time)
	end)
	return cur
end

function data.show(st)
	if data.shown == st then return end
	data.shown = st
	for _, hero in pairs(data.heroes) do
		local g = st and st.hg[hero.id] or 0
		hero.games = g
		hero.rate = g > 0 and st.hw[hero.id] * 100 / g or 50
	end
end

function data.count(n)
	if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
	if n >= 10000 then return string.format("%dk", math.floor(n / 1000 + 0.5)) end
	if n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(n)
end

function data.status(key)
	if not key then
		if #data.list > 0 then return "ok" end
	elseif data.sets[key] then
		return "ok"
	elseif data.manifest and not data.manifest.sets[key] then
		return "none"
	end
	if data.failed and not next(data.busy) then return data.code == 404 and "missing" or "error" end
	return "loading"
end

local upd = { state = "idle", latest = nil, url = nil, error = nil, checked = false, check_failed = false, next_check = 0, reload_at = nil, changed_at = 0 }

do
	local ok, source = pcall(function() return debug.getinfo(1, "S").source end)
	local own = ok and type(source) == "string" and source:match("^@(%a:[\\/].+%.lua)$")
	local dir = Engine.GetCheatDirectory()
	if not dir:match("[\\/]$") then dir = dir .. "\\" end
	upd.path = own or (dir .. "scripts\\draft_helper.lua")
end

function upd.parse(v)
	local a, b, c, pre = tostring(v):match("^(%d+)%.(%d+)%.(%d+)%-?([%w%.]*)$")
	if not a then return nil end
	local ids = {}
	for id in pre:gmatch("[^%.]+") do ids[#ids + 1] = tonumber(id) or id end
	return { tonumber(a), tonumber(b), tonumber(c), pre = ids }
end

function upd.newer(v, than)
	local x, y = upd.parse(v), upd.parse(than)
	if not x or not y then return false end
	for i = 1, 3 do
		if x[i] ~= y[i] then return x[i] > y[i] end
	end
	if #x.pre == 0 or #y.pre == 0 then return #x.pre == 0 and #y.pre > 0 end
	for i = 1, math.max(#x.pre, #y.pre) do
		local p, q = x.pre[i], y.pre[i]
		if p == nil or q == nil then return q == nil end
		if p ~= q then
			if type(p) == type(q) then return p > q end
			return type(p) == "string"
		end
	end
	return false
end

function upd.short(v)
	local core, pre = v:match("^(%d+%.%d+%.%d+)%-(.+)$")
	return core == K.VERSION:match("^%d+%.%d+%.%d+") and pre or v
end

function upd.set(state, error)
	if upd.state ~= state then upd.changed_at = os.clock() end
	upd.state, upd.error = state, error
end

function upd.request(url, done)
	local sent = HTTP.Request("GET", url, { headers = NET.HEADERS, timeout = NET.UPDATE_TIMEOUT }, function(r)
		local code = tonumber(r.code) or 0
		local message = r.error_message ~= "" and r.error_message or nil
		if code == 200 and type(r.response) == "string" and #r.response > 0 then
			done(r.response)
		else
			done(nil, code > 0 and ("HTTP " .. code .. (message and (", " .. message) or "")) or message or L("dh_data_no_answer"))
		end
	end, "draft_helper_update")
	if not sent then done(nil, L("dh_data_not_sent")) end
end

function upd.check(manual)
	if upd.state == "checking" or upd.state == "loading" or upd.state == "done" then return end
	upd.next_check = os.clock() + NET.CHECK
	local before = upd.state
	upd.set("checking")
	upd.request(NET.VERSION_URL, function(text, err)
		local v = data.decode(text)
		if not v or type(v.version) ~= "string" or type(v.url) ~= "string" then
			upd.check_failed = manual or upd.check_failed
			upd.set(before == "checking" and "idle" or before, text and L("dh_upd_bad_manifest") or err)
			return
		end
		upd.checked, upd.check_failed = true, false
		upd.latest, upd.url = v.version, v.url
		upd.set(upd.newer(v.version, K.VERSION) and "available" or "idle")
	end)
end

function upd.install()
	if upd.state ~= "available" and upd.state ~= "error" then return end
	local want = upd.latest
	upd.set("loading")
	upd.request(upd.url, function(text, err)
		if not text then return upd.set("error", err) end
		local found = text:match('VERSION = "([^"]+)"')
		if found ~= want or not text:find("^%-%-%[%[") or not text:find("return script%s*$") then
			return upd.set("error", L("dh_upd_bad_file"))
		end
		local tmp = upd.path .. ".tmp"
		local f = io.open(tmp, "wb")
		if not f then return upd.set("error", L("dh_upd_write")) end
		f:write(text)
		f:close()
		os.remove(upd.path)
		if not os.rename(tmp, upd.path) then
			f = io.open(upd.path, "wb")
			if not f then return upd.set("error", L("dh_upd_write")) end
			f:write(text)
			f:close()
			os.remove(tmp)
		end
		Log.Write("[Draft Helper] updated to " .. want .. ", restarting scripts")
		upd.set("done")
		upd.reload_at = os.clock() + NET.RELOAD_DELAY
	end)
end

function upd.tick()
	local now = os.clock()
	if upd.reload_at and now >= upd.reload_at then
		upd.reload_at = nil
		Engine.ReloadScriptSystem()
	elseif now >= upd.next_check then
		upd.check(false)
	end
end

local calc = {}

local function logit(p) return math.log(p / (1 - p)) end
local function sigmoid(x) return 1 / (1 + math.exp(-x)) end

function calc.base(st, id)
	local v = st.base[id]
	if not v then
		v = logit(((st.hw[id] or 0) + MODEL.PRIOR * 0.5) / ((st.hg[id] or 0) + MODEL.PRIOR))
		st.base[id] = v
	end
	return v
end

function calc.pair(g, w, e)
	return logit((w + MODEL.PAIR * e) / (g + MODEL.PAIR)) - logit(e)
end

function calc.with(st, a, b)
	local k = a < b and a * 256 + b or b * 256 + a
	return calc.pair(st.sg[k] or 0, st.sw[k] or 0, sigmoid(calc.base(st, a) + calc.base(st, b)))
end

function calc.vs(st, a, b)
	local k = a < b and a * 256 + b or b * 256 + a
	local g, w = st.vg[k] or 0, st.vw[k] or 0
	if a > b then w = g - w end
	return calc.pair(g, w, sigmoid(calc.base(st, a) - calc.base(st, b)))
end

function calc.team(st, team)
	local v = 0
	for i, a in ipairs(team) do
		v = v + calc.base(st, a)
		for j = i + 1, #team do v = v + calc.with(st, a, team[j]) end
	end
	return v
end

function calc.draft(st, ours, theirs)
	local v = calc.team(st, ours) - calc.team(st, theirs)
	for _, a in ipairs(ours) do
		for _, b in ipairs(theirs) do v = v + calc.vs(st, a, b) end
	end
	return v
end

function calc.chance(st, ours, theirs) return sigmoid(calc.draft(st, ours, theirs)) end

function calc.why(groups, order)
	local why = {}
	for _, name in ipairs(order) do
		local list = groups[name]
		if #list > 0 then
			table.sort(list, function(p, q) return math.abs(p[2]) > math.abs(q[2]) end)
			why[#why + 1] = { name, list }
		end
	end
	return why
end

function calc.row(st, hero, ours, theirs, base, busy, need)
	local function pp(x) return (sigmoid(base + x) - sigmoid(base)) * 100 end
	local id, cover = hero.id, 0
	local total = calc.base(st, id)
	local groups = { close = {}, vs = {}, with = {}, weak = {}, badwith = {} }
	for _, b in ipairs(theirs) do
		local x = calc.vs(st, id, b)
		total = total + x
		local v = pp(x)
		if v > 0 then cover = cover + v * need[b] end
		if math.abs(v) >= MODEL.REASON_MIN then
			local group = v < 0 and "weak" or (need[b] >= 0.5 and "close" or "vs")
			table.insert(groups[group], { data.by_id[b].h, v })
		end
	end
	for _, a in ipairs(ours) do
		local x = calc.with(st, id, a)
		total = total + x
		local v = pp(x)
		if math.abs(v) >= MODEL.REASON_MIN then table.insert(groups[v > 0 and "with" or "badwith"], { data.by_id[a].h, v }) end
	end
	local why = calc.why(groups, { "close", "vs", "with", "weak", "badwith" })
	local pos = hero.pos
	if busy then
		local best = -1
		for p = 1, 5 do
			if not busy[p] and hero.shares[p] >= MODEL.POS_MIN and hero.shares[p] > best then pos, best = p, hero.shares[p] end
		end
	end
	local d = pp(total)
	return {
		h = hero.h, d = d, k = d - (1 - MODEL.BASE_W) * pp(calc.base(st, id)) + MODEL.COVER * cover,
		pos = pos, share = hero.shares[pos], why = why,
	}
end

function calc.lane(st, row, id, ours, theirs, pos, base)
	local function pp(x) return (sigmoid(base + x) - sigmoid(base)) * 100 end
	local total, found = 0, false
	local groups = { vs = {}, with = {}, weak = {}, badwith = {} }
	local function add(ids, near, fn, good, bad)
		for _, b in ipairs(ids) do
			if pos[b] and near[pos[b]] then
				local x = fn(st, id, b)
				local v = pp(x)
				total, found = total + x, true
				if math.abs(v) >= MODEL.REASON_MIN then table.insert(groups[v > 0 and good or bad], { data.by_id[b].h, v }) end
			end
		end
	end
	add(theirs, MODEL.LANE_VS[row.pos], calc.vs, "vs", "weak")
	add(ours, MODEL.LANE_WITH[row.pos], calc.with, "with", "badwith")
	if not found then return row end
	local d = pp(total)
	return {
		h = row.h, d = d, k = d + MODEL.LANE_REST * row.k, pos = row.pos, share = row.share,
		why = calc.why(groups, { "vs", "with", "weak", "badwith" }),
	}
end

function calc.step(st, ours, theirs, busy, lane)
	local base = (#ours + #theirs > 0) and calc.draft(st, ours, theirs) or 0
	local out = { c = #ours + #theirs > 0, p = busy ~= nil, r = {} }
	local need = {}
	for _, b in ipairs(theirs) do
		local threat = calc.base(st, b)
		for _, a in ipairs(ours) do threat = threat + calc.vs(st, b, a) end
		need[b] = math.max(0, math.min(1, threat / MODEL.THREAT))
	end
	for _, hero in ipairs(data.list) do
		if hero.id then out.r[#out.r + 1] = calc.row(st, hero, ours, theirs, base, busy, need) end
	end
	local general = out.r
	if lane then
		out.r = {}
		for i, r in ipairs(general) do out.r[i] = calc.lane(st, r, data.heroes[r.h].id, ours, theirs, lane, base) end
	end
	table.sort(out.r, function(a, b) return a.k > b.k end)
	out.lane = lane ~= nil
	if busy then
		out.f = {}
		for p = 1, 5 do
			local list = {}
			for _, r in ipairs(general) do
				local hero = data.heroes[r.h]
				if hero.shares[p] >= MODEL.POS_MIN then
					local x = { h = r.h, d = r.d, k = r.k, pos = p, share = hero.shares[p], why = r.why }
					list[#list + 1] = lane and calc.lane(st, x, hero.id, ours, theirs, lane, base) or x
				end
			end
			table.sort(list, function(a, b) return a.k > b.k end)
			out.f[p] = list
		end
	end
	return out
end

data.boot()

local SET = {}

local function set_defaults()
	for k, v in pairs(K.DEF) do SET[k] = v end
end

local function load_settings()
	set_defaults()
	for k, v in Config.ReadString(K.CFG, "settings", ""):gmatch("([%w_]+)=([%w_]+)") do
		if K.DEF[k] ~= nil then
			SET[k] = type(K.DEF[k]) == "number" and (tonumber(v) or K.DEF[k]) or v
		end
	end
	SET.pool = {}
	for h in Config.ReadString(K.CFG, "pool", ""):gsub("^p:", ""):gmatch("[%w_]+") do SET.pool[#SET.pool + 1] = h end
end

local function save_settings()
	local parts = {}
	for k in pairs(K.DEF) do parts[#parts + 1] = k .. "=" .. tostring(SET[k]) end
	Config.WriteString(K.CFG, "settings", table.concat(parts, ";"))
	Config.WriteString(K.CFG, "pool", "p:" .. table.concat(SET.pool, ","))
end

load_settings()

local function in_pool(h)
	for _, x in ipairs(SET.pool) do if x == h then return true end end
	return false
end

local function toggle_pool(h)
	for i, x in ipairs(SET.pool) do
		if x == h then
			table.remove(SET.pool, i)
			save_settings()
			return
		end
	end
	SET.pool[#SET.pool + 1] = h
	save_settings()
end

local S = {
	open = false, alpha = 0, started = false, env = "home", train = false, mode = "cm", view = "home", ret = "home", pool_ret = "set",
	cm = { fp = "d", us = "d", picks = {}, pos = {} },
	ap = { us = "d", ours = {}, theirs = {} },
	filter = 0, sel = nil, ghost = nil, query = "", focus = false, menu = nil, last = nil, press = nil,
	enemy_at = nil, reveal_at = nil, reveal_need = 0,
	scroll = 0, scroll_to = 0, content_h = 0, view_h = 0, content_key = "", step_key = "", fade_t = 1,
	drag = nil, sb_drag = nil, sb_until = 0, tweens = {}, last_click = { id = nil, t = 0 },
	wx = nil, wy = nil, now = 0, dt = 0, chance = { from = nil, to = nil, t = 1 },
	bh = nil, b_ret = "home", tip = nil, calc = nil, calc_key = nil,
}

local draft = {}
local live = {
	d = nil, trace = nil, next_read = 0, next_captain = 0, next_grid = 0, pos = {}, missing = {}, ap_key = "",
	grid = { panel = nil, cards = {}, last = nil, next_heroes = 0 }, found = {}, slots = { board = nil, list = {} }, view = { key = nil },
}

local function kind(i) return K.ORDER[i] and K.ORDER[i]:sub(1, 1) end
local function side_of(fp, i)
	if not K.ORDER[i] or K.ORDER[i]:sub(2, 2) == "F" then return fp end
	return fp == "r" and "d" or "r"
end
local function other(side) return side == "r" and "d" or "r" end

function draft.cm_n() return #S.cm.picks end
function draft.cm_step() return #S.cm.picks + 1 end
function draft.cm_side() return side_of(S.cm.fp, draft.cm_step()) end
function draft.cm_ours() return draft.cm_side() == S.cm.us end
function draft.ap_round()
	local k = #S.ap.ours
	return k < 2 and 1 or (k < 4 and 2 or (k < 5 and 3 or 4))
end
function draft.ap_reveal_for(k) return k >= 5 and 5 or (k >= 4 and 4 or (k >= 2 and 2 or 0)) end
function draft.home_board() return S.env == "home" and not S.train end
function draft.live() return S.env ~= "home" and not S.train end
function draft.manual_enemy() return S.train and SET.tr_enemy == "manual" end

function draft.done()
	if S.mode == "ap" then return draft.ap_round() > 3 end
	return draft.cm_n() >= 24
end

function draft.is_ban() return S.mode == "cm" and not draft.done() and kind(draft.cm_step()) == "B" end

function draft.can_act()
	if draft.live() then return not draft.done() and live.can_act() end
	if S.mode == "ap" then return true end
	return not draft.done() and (draft.cm_ours() or draft.manual_enemy())
end

function draft.teams()
	local ours, theirs, pos = {}, {}, {}
	local function add(list, h, p)
		local hero = data.heroes[h]
		if hero and hero.id then
			list[#list + 1] = hero.id
			pos[hero.id] = p
		end
	end
	if S.mode == "ap" then
		for _, e in ipairs(S.ap.ours) do add(ours, e.h, e.p) end
		for _, e in ipairs(S.ap.theirs) do add(theirs, e.h, e.p) end
	else
		for i, h in ipairs(S.cm.picks) do
			if kind(i) == "P" then add(side_of(S.cm.fp, i) == S.cm.us and ours or theirs, h, S.cm.pos[i]) end
		end
	end
	return ours, theirs, pos
end

function draft.set_key() return SET.source .. "_" .. K.RANKS[SET.rank] end

function draft.stats()
	local st = data.stats(draft.set_key())
	data.show(st)
	return st
end

function draft.step()
	local st = draft.stats()
	if not st or draft.done() then return nil end
	local ours, theirs, pos = draft.teams()
	local ban = draft.is_ban()
	local our_turn = S.mode == "ap" or draft.cm_ours()
	local mine = our_turn ~= ban
	local busy = (mine and not ban) and draft.our_pos() or nil
	local lane = busy and SET.goal == "lane" and pos or nil
	local parts = { draft.set_key(), st.time, mine and "o" or "t", SET.goal, busy and "p" or "-" }
	for _, list in ipairs({ ours, theirs }) do
		for _, id in ipairs(list) do parts[#parts + 1] = id .. ":" .. tostring(pos[id]) end
		parts[#parts + 1] = "/"
	end
	local key = table.concat(parts, "|")
	if S.calc_key ~= key then
		S.calc_key = key
		S.calc = mine and calc.step(st, ours, theirs, busy, lane) or calc.step(st, theirs, ours, nil)
	end
	return S.calc
end

function draft.positional()
	if S.view ~= "draft" or draft.done() then return false end
	if S.mode == "ap" then return true end
	local st = draft.step()
	return kind(draft.cm_step()) == "P" and draft.cm_ours() and st and st.p
end

function draft.used()
	local set = {}
	local grid = draft.live() and live.d and live.d.grid
	if grid then
		for h in pairs(grid.closed) do set[h] = true end
	end
	if S.mode == "ap" then
		for _, e in ipairs(S.ap.ours) do set[e.h] = true end
		for _, e in ipairs(S.ap.theirs) do set[e.h] = true end
	else
		for _, h in ipairs(S.cm.picks) do set[h] = true end
	end
	return set
end

function draft.our_pos()
	local set = {}
	if S.mode == "ap" then
		for _, e in ipairs(S.ap.ours) do if e.p then set[e.p] = true end end
	else
		for i, _ in ipairs(S.cm.picks) do
			if kind(i) == "P" and side_of(S.cm.fp, i) == S.cm.us and S.cm.pos[i] then set[S.cm.pos[i]] = true end
		end
	end
	return set
end

function draft.chance()
	if draft.home_board() then return nil end
	local st = draft.stats()
	local ours, theirs = draft.teams()
	if not st or #ours + #theirs == 0 or (S.mode == "ap" and #theirs == 0) then return nil end
	return calc.chance(st, ours, theirs)
end

function draft.row_for(h)
	local st = draft.step()
	if not st then return nil end
	for _, r in ipairs(st.r) do if r.h == h then return r end end
	if st.f then
		for p = 1, 5 do
			for _, r in ipairs(st.f[p] or {}) do if r.h == h then return r end end
		end
	end
	return nil
end

function draft.pool_on()
	return SET.pool_mode ~= "off" and #SET.pool > 0 and draft.can_act() and not draft.is_ban()
end

function draft.rows()
	local st = draft.step()
	if not st then return {} end
	local key = table.concat({ S.calc_key, S.filter, SET.pool_mode, SET.count, table.concat(SET.pool, ","),
		tostring(draft.can_act()), tostring(live.d and live.d.grid), #S.cm.picks, #S.ap.ours, #S.ap.theirs }, "|")
	if S.rows_key == key then return S.rows end
	S.rows_key = key
	S.rows = draft.build_rows(st)
	return S.rows
end

function draft.build_rows(st)
	local used = draft.used()
	local function ok(r) return not used[r.h] and data.heroes[r.h] ~= nil end
	local list = {}
	if draft.positional() and st.f and S.filter > 0 then
		for _, r in ipairs(st.f[S.filter] or {}) do if ok(r) then list[#list + 1] = r end end
	elseif draft.positional() and st.f then
		local busy, seen, extra = draft.our_pos(), {}, {}
		for _, r in ipairs(st.r) do
			if ok(r) and not (r.pos and busy[r.pos]) then
				list[#list + 1] = r
				seen[r.h] = true
			end
		end
		for p = 1, 5 do
			if not busy[p] then
				for _, r in ipairs(st.f[p] or {}) do
					if ok(r) and not seen[r.h] then
						seen[r.h] = true
						extra[#extra + 1] = r
					end
				end
			end
		end
		table.sort(extra, function(a, b) return a.k > b.k end)
		for _, r in ipairs(extra) do list[#list + 1] = r end
	else
		for _, r in ipairs(st.r) do if ok(r) then list[#list + 1] = r end end
	end
	if draft.pool_on() then
		if SET.pool_mode == "only" then
			local only = {}
			for _, r in ipairs(list) do if in_pool(r.h) then only[#only + 1] = r end end
			list = only
		else
			local ranked = {}
			for i, r in ipairs(list) do ranked[i] = { r = r, i = i, k = r.k + (in_pool(r.h) and K.BOOST or 0) } end
			table.sort(ranked, function(a, b) if a.k ~= b.k then return a.k > b.k end return a.i < b.i end)
			for i, x in ipairs(ranked) do list[i] = x.r end
		end
	end
	local out = {}
	for i = 1, math.min(#list, SET.count) do out[i] = list[i] end
	return out
end

function draft.free_pos(p)
	local busy = draft.our_pos()
	if p and not busy[p] then return p end
	for q = 1, 5 do if not busy[q] then return q end end
	return nil
end

function draft.pos_for(h)
	local hero = data.heroes[h]
	if S.mode == "ap" then
		local r = draft.row_for(h)
		return draft.free_pos(S.filter > 0 and S.filter or (r and r.pos) or (hero and hero.pos))
	end
	local i = draft.cm_step()
	if i > #K.ORDER or kind(i) ~= "P" then return nil end
	local planned = hero and hero.pos
	if side_of(S.cm.fp, i) == S.cm.us then return draft.free_pos(S.filter > 0 and S.filter or planned) end
	return planned
end

function draft.reset_turn()
	S.sel, S.ghost, S.filter, S.enemy_at = nil, nil, 0, nil
	S.menu = nil
end

function draft.snapshot()
	if draft.done() and not draft.home_board() then
		S.last = { mode = S.mode, train = S.train, chance = draft.chance() or 0.5 }
		if S.mode == "ap" then
			S.last.ap = { us = S.ap.us, ours = {}, theirs = {}, bans = draft.live() and live.d and live.d.grid and live.d.grid.banned or {} }
			for i, e in ipairs(S.ap.ours) do S.last.ap.ours[i] = { h = e.h, p = e.p } end
			for i, e in ipairs(S.ap.theirs) do S.last.ap.theirs[i] = { h = e.h, p = e.p } end
		else
			S.last.cm = { fp = S.cm.fp, us = S.cm.us, picks = {}, pos = {} }
			for i, h in ipairs(S.cm.picks) do S.last.cm.picks[i], S.last.cm.pos[i] = h, S.cm.pos[i] end
		end
	end
end

function draft.ap_reveal(upto)
	local st = draft.stats()
	if not st then return end
	local used, taken = draft.used(), {}
	for _, e in ipairs(S.ap.theirs) do if e.p then taken[e.p] = true end end
	for _ = #S.ap.theirs + 1, upto do
		local ours, theirs = draft.teams()
		for _, r in ipairs(calc.step(st, theirs, ours, taken).r) do
			if not used[r.h] and not taken[r.pos] then
				S.ap.theirs[#S.ap.theirs + 1] = { h = r.h, p = r.pos }
				used[r.h], taken[r.pos] = true, true
				break
			end
		end
	end
end

function draft.commit(h, forced, auto)
	if not h or draft.done() or S.reveal_at or draft.used()[h] then return end
	if not auto and not draft.can_act() then return end
	local p = forced or draft.pos_for(h)
	if draft.live() then
		if live.act(h) then live.pos[h] = p end
		draft.reset_turn()
		S.query, S.focus = "", false
		return
	end
	draft.reset_turn()
	S.query, S.focus = "", false
	if S.mode == "ap" then
		S.ap.ours[#S.ap.ours + 1] = { h = h, p = p }
		local need = draft.ap_reveal_for(#S.ap.ours)
		if need > #S.ap.theirs then
			S.reveal_at, S.reveal_need = S.now + K.REVEAL_DELAY, need
		end
	else
		S.cm.pos[draft.cm_step()] = p
		S.cm.picks[#S.cm.picks + 1] = h
	end
	draft.snapshot()
end

function draft.place(h)
	if not h or draft.done() or S.reveal_at or draft.used()[h] or S.view ~= "draft" or not draft.can_act() then return end
	if SET.confirm == 0 or S.sel == h then
		draft.commit(h)
	else
		S.sel = h
	end
end

function draft.undo()
	if not S.train or S.reveal_at then return end
	if S.mode == "ap" then
		if #S.ap.ours == 0 then return end
		S.ap.ours[#S.ap.ours] = nil
		local keep = draft.ap_reveal_for(#S.ap.ours)
		for j = #S.ap.theirs, keep + 1, -1 do S.ap.theirs[j] = nil end
	else
		if draft.cm_n() == 0 then return end
		while draft.cm_n() > 0 and side_of(S.cm.fp, draft.cm_n()) ~= S.cm.us do
			S.cm.pos[draft.cm_n()] = nil
			S.cm.picks[draft.cm_n()] = nil
		end
		if draft.cm_n() > 0 then
			S.cm.pos[draft.cm_n()] = nil
			S.cm.picks[draft.cm_n()] = nil
		end
	end
	draft.reset_turn()
end

function draft.start_training(mode)
	S.train, S.mode, S.view = true, mode, "draft"
	S.query, S.focus = "", false
	S.reveal_at = nil
	draft.reset_turn()
	if mode == "ap" then
		S.ap.us = SET.tr_side
		S.ap.ours, S.ap.theirs = {}, {}
	else
		S.cm = { fp = SET.tr_first == "us" and SET.tr_side or other(SET.tr_side), us = SET.tr_side, picks = {}, pos = {} }
	end
end

function draft.go_home()
	S.train, S.view = false, "home"
	S.reveal_at = nil
	draft.reset_turn()
end

function draft.set_env(env, us, fp)
	S.env, S.train = env, false
	S.query, S.focus, S.reveal_at = "", false, nil
	draft.reset_turn()
	if env == "home" then
		S.view = "home"
		return
	end
	S.mode, S.view = env, "draft"
	S.ap = { us = us, ours = {}, theirs = {} }
	S.cm = { fp = fp, us = us, picks = {}, pos = {} }
end

function draft.enemy_move()
	local st, used = draft.step(), draft.used()
	if not st then return end
	for _, r in ipairs(st.r) do
		if not used[r.h] then
			draft.commit(r.h, nil, true)
			return
		end
	end
end

function draft.tick()
	if S.reveal_at and S.now >= S.reveal_at then
		draft.ap_reveal(S.reveal_need)
		S.reveal_at = nil
		draft.snapshot()
	end
	local enemy_turn = S.train and S.mode == "cm" and not draft.done() and not draft.cm_ours() and not draft.manual_enemy()
	if not enemy_turn then
		S.enemy_at = nil
	elseif not S.enemy_at then
		S.enemy_at = S.now + K.ENEMY_DELAY
	elseif S.now >= S.enemy_at then
		S.enemy_at = nil
		draft.enemy_move()
	end
end

function draft.slot_info(key)
	local t, j = key:sub(1, 1), tonumber(key:sub(2))
	local list = {}
	if t == "c" then
		local team = side_of(S.cm.fp, j)
		for i, h in ipairs(S.cm.picks) do
			if kind(i) == "P" and side_of(S.cm.fp, i) == team then list[#list + 1] = { h = h, i = i } end
		end
		return { h = S.cm.picks[j], p = S.cm.pos[j], list = list,
			get = function(x) return S.cm.pos[x.i] end, set = function(x, v) S.cm.pos[x.i] = v end, self = { i = j } }
	end
	local arr = t == "o" and S.ap.ours or S.ap.theirs
	for i, e in ipairs(arr) do list[i] = { h = e.h, i = i } end
	return { h = arr[j].h, p = arr[j].p, list = list,
		get = function(x) return arr[x.i].p end, set = function(x, v) arr[x.i].p = v end, self = { i = j } }
end

function draft.set_slot_pos(key, p)
	local info = draft.slot_info(key)
	for _, x in ipairs(info.list) do
		if x.h ~= info.h and info.get(x) == p then info.set(x, info.p) end
	end
	info.set(info.self, p)
	draft.snapshot()
end

function live.log(fmt, ...)
	if SET.log == 1 then Log.Write("[Draft Helper] " .. fmt:format(...)) end
end

function live.children(panel, match, out)
	for i = 0, panel:GetChildCount() - 1 do
		local child = panel:GetChild(i)
		if child then
			if match(child) then out[#out + 1] = child else live.children(child, match, out) end
		end
	end
	return out
end

function live.hero(img)
	local unit = img and (img:GetImageSrc() or ""):match("npc_dota_hero_([%w_]+)")
	if not unit then return nil end
	local h = unit:gsub("_png$", "")
	if not data.heroes[h] then
		data.heroes[h] = { h = h, name = Engine.GetDisplayNameByUnitName("npc_dota_hero_" .. h) or h, attr = "all", rate = 50, games = "0", pos = 1 }
	end
	return h
end

function live.slot_hero(slot)
	local img = slot:FindChildTraverse("HeroImage")
	local h = live.hero(img)
	local key = slot:GetID() .. (img and img:GetImageSrc() or "")
	if not h and not live.missing[key] then
		live.missing[key] = true
		live.log("no hero in %s, image src: '%s'", slot:GetID(), img and img:GetImageSrc() or "")
	end
	return h
end

function live.side(pre)
	return pre:HasClass("LocalPlayerIsDire") and "d" or (pre:HasClass("LocalPlayerIsRadiant") and "r" or nil)
end

function live.find(pre, id)
	local cache = live.found
	if not cache.root or not cache.root:IsValid() or cache.root ~= pre then
		live.found = { root = pre }
		cache = live.found
	end
	local panel = cache[id]
	if not panel or not panel:IsValid() then
		panel = pre:FindChildTraverse(id)
		cache[id] = panel
	end
	return panel
end

function live.read_grid(pre, now)
	local cache = live.grid
	if now < live.next_grid then return cache.last end
	live.next_grid = now + K.LIVE_GRID
	local panel = live.find(pre, "HeroGrid")
	cache.last = nil
	if not panel then return nil end
	local stale = not cache.panel or not cache.panel:IsValid() or cache.panel ~= panel or #cache.cards == 0
	for _, card in ipairs(cache.cards) do
		if stale then break end
		stale = not card.panel:IsValid() or not card.img:IsValid()
	end
	if stale then
		cache.panel, cache.cards, cache.next_heroes = panel, {}, 0
		for _, card in ipairs(live.children(panel, function(c) return c:HasClass("HeroCard") end, {})) do
			local img = card:FindChildTraverse("HeroImage")
			if img then cache.cards[#cache.cards + 1] = { panel = card, img = img } end
		end
	end
	if now >= cache.next_heroes then
		cache.next_heroes = now + K.LIVE_GRID_HEROES
		for _, card in ipairs(cache.cards) do card.h = live.hero(card.img) end
	end
	local out = { banned = {}, picked = {}, off = {}, closed = {} }
	for _, card in ipairs(cache.cards) do
		local h = card.h
		if h and not out.closed[h] then
			local list = card.panel:HasClass("Banned") and out.banned or (card.panel:HasClass("AlreadyPicked") and out.picked)
				or (card.panel:HasClass("Unavailable") and out.off)
			if list then
				list[#list + 1] = h
				out.closed[h] = true
			end
		end
	end
	cache.last = out
	return out
end

function live.read_cm(pre)
	local board = live.find(pre, "CaptainsModePicksBans")
	if not board then return nil end
	local d = {
		mode = "cm", pre = pre, us = live.side(pre), fp = board:HasClass("StartingTeamIsRadiant") and "r" or "d",
		captain = pre:HasClass("LocalPlayerIsCaptain"), need_captain = pre:HasClass("LocalTeamNeedsCaptain"),
		our_turn = pre:HasClass("LocalTeamIsActive"), order = {},
	}
	for _, s in ipairs(live.cm_slots(board)) do
		local n = tonumber(s.label:GetText())
		if n and s.panel:HasClass("HeroPickLocked") then
			d.order[n] = live.slot_hero(s.panel)
		elseif n and s.panel:HasClass("ActiveStage") then
			d.turn = n
		end
	end
	live.read_players(pre, d)
	d.us = d.us or live.side(pre)
	return d
end

function live.cm_slots(board)
	local cache = live.slots
	local stale = not cache.board or not cache.board:IsValid() or cache.board ~= board or #cache.list == 0
	for _, s in ipairs(cache.list) do
		if stale then break end
		stale = not s.panel:IsValid() or not s.label:IsValid()
	end
	if stale then
		cache.board, cache.list = board, {}
		for _, team in ipairs({ "Radiant", "Dire" }) do
			for _, slots in ipairs({ { "Ban", 7 }, { "Pick", 5 } }) do
				for i = 1, slots[2] do
					local slot = board:FindChildTraverse(team .. slots[1] .. i)
					local label = slot and live.children(slot, function(c) return c:HasClass("PickOrder") end, {})[1]
					if label then cache.list[#cache.list + 1] = { panel = slot, label = label } end
				end
			end
		end
	end
	return cache.list
end

function live.read_ap(pre)
	local d = {
		mode = "ap", pre = pre, us = live.side(pre),
		ban_phase = pre:HasClass("IsInBanPhase"), in_control = pre:HasClass("LocalPlayerInControl"), selected = pre:HasClass("HasSelectedHero"),
	}
	live.read_players(pre, d)
	return d
end

function live.read_players(pre, d)
	d.teams = { r = {}, d = {} }
	for side, id in pairs({ r = "RadiantTeamPlayers", d = "DireTeamPlayers" }) do
		local root = live.find(pre, id)
		for _, p in ipairs(root and live.children(root, function(c) return c:GetPanelType() == "DOTAHudHeroPickingPlayer" end, {}) or {}) do
			local name = p:FindChildTraverse("PlayerName")
			local player = {
				name = name and name:GetText() or "?", me = p:HasClass("IsLocalPlayerPawn"), tentative = p:HasClass("HeroPickTentative"),
				h = not p:HasClass("HeroPickNone") and live.hero(p:FindChildTraverse("HeroImage")) or nil,
			}
			if player.me then
				d.us = side
				d.me = not player.tentative and player.h or nil
			end
			table.insert(d.teams[side], player)
		end
	end
end

function live.read(pre, now)
	pre = pre or Panorama.GetPanelByName("PreGame", false)
	if not pre or not pre:IsVisible() then return nil end
	local d
	if pre:HasClass("CaptainsModeHeroPicking") or (draft.live() and S.mode == "cm") then
		d = live.read_cm(pre)
	else
		d = live.read_ap(pre)
	end
	if d then d.grid = live.read_grid(pre, now or os.clock()) end
	return d
end

function live.can_act()
	local d = live.d
	if not d then return false end
	if d.mode == "cm" then return d.captain and d.our_turn end
	return d.in_control and not d.selected and not d.ban_phase
end

function live.act(h)
	local d = live.read()
	local why, button
	if not d then
		why = "no draft"
	elseif d.grid and d.grid.closed[h] then
		why = "hero is not available"
	elseif d.mode == "cm" then
		button = d.pre:HasClass("NextCaptainActionIsBan") and "CaptainsModeBanButton" or "CaptainsModeSelectButton"
		why = not d.captain and "not captain" or (not d.our_turn and "not our turn" or nil)
	else
		button = "LockInButton"
		why = d.ban_phase and "ban phase" or (d.selected and "hero already selected" or (not d.in_control and "not our turn" or nil))
	end
	if why then
		live.log("%s skipped: %s", h, why)
		return false
	end
	local ok = Engine.RunScript(JS.ACT:format(h, button), d.pre)
	live.log("%s %s: script %s", button, h, ok and "sent" or "failed")
	return ok
end

function live.team(prev, players)
	local present, out, taken = {}, {}, {}
	for _, p in ipairs(players) do
		if p.h and not p.tentative then present[p.h] = true end
	end
	for _, e in ipairs(prev) do
		if present[e.h] then
			present[e.h] = nil
			out[#out + 1] = e
			if e.p then taken[e.p] = true end
		end
	end
	for _, p in ipairs(players) do
		if p.h and present[p.h] then
			present[p.h] = nil
			local pos = live.pos[p.h] or data.heroes[p.h].pos
			if not pos or taken[pos] then
				for q = 1, 5 do if not taken[q] then pos = q break end end
			end
			taken[pos] = true
			out[#out + 1] = { h = p.h, p = pos }
		end
	end
	return out
end

function live.apply_cm(d)
	S.cm.fp, S.cm.us = d.fp, d.us or S.cm.us
	local same = true
	for i, h in ipairs(S.cm.picks) do
		if d.order[i] ~= h then same = false break end
	end
	if not same then S.cm.picks, S.cm.pos = {}, {} end
	local before = #S.cm.picks
	while d.order[#S.cm.picks + 1] do
		local i = #S.cm.picks + 1
		local h = d.order[i]
		if kind(i) == "P" then S.cm.pos[i] = live.pos[h] or draft.pos_for(h) end
		S.cm.picks[i] = h
	end
	if not same or #S.cm.picks ~= before then
		draft.reset_turn()
		draft.snapshot()
	end
end

function live.apply_ap(d)
	local us = d.us or S.ap.us
	S.ap.us = us
	S.ap.ours = live.team(S.ap.ours, d.teams[us])
	S.ap.theirs = live.team(S.ap.theirs, d.teams[other(us)])
	local key = {}
	for _, e in ipairs(S.ap.ours) do key[#key + 1] = e.h end
	key[#key + 1] = "/"
	for _, e in ipairs(S.ap.theirs) do key[#key + 1] = e.h end
	key = table.concat(key, ",")
	if key ~= live.ap_key then
		live.ap_key = key
		draft.reset_turn()
		draft.snapshot()
	end
end

function live.apply(d)
	if not d then
		if draft.live() then
			draft.set_env("home")
			if SET.auto == 1 then S.open, S.focus = false, false end
		end
		return
	end
	if not draft.live() or S.mode ~= d.mode then
		live.pos, live.ap_key, live.next_grid = {}, "", 0
		draft.set_env(d.mode, d.us or "r", d.fp or "r")
		if SET.auto == 1 then S.open = true end
	end
	if d.mode == "cm" then live.apply_cm(d) else live.apply_ap(d) end
end

function live.rows(d)
	local rows = {}
	if not d then return rows end
	local function add(id, raw, text) rows[#rows + 1] = { id = id, raw = raw, text = text or raw } end
	local function yes(v) return tostring(v), L(v and "dh_d_yes" or "dh_d_no") end
	local function side(v) return tostring(v), v and L(v == "r" and "dh_d_team_r" or "dh_d_team_d") or "-" end
	local function name(h) return h and data.heroes[h] and data.heroes[h].name or "-" end
	local function heroes(list)
		local names = {}
		for i, h in ipairs(list) do names[i] = name(h) end
		return table.concat(list, ","), #names > 0 and table.concat(names, ", ") or "-"
	end
	add("us", side(d.us))
	add("hero", tostring(d.me), d.me and name(d.me) or "-")
	if d.mode == "cm" then
		add("first", side(d.fp))
		add("captain", yes(d.captain))
		add("need_captain", yes(d.need_captain))
		add("our_turn", yes(d.our_turn))
		add("turn", tostring(d.turn or "-"))
		local raw, names = {}, {}
		for i = 1, 24 do
			if d.order[i] then
				raw[#raw + 1] = i .. ":" .. d.order[i]
				names[#names + 1] = i .. " " .. name(d.order[i])
			end
		end
		add("order", table.concat(raw, ","), #names > 0 and table.concat(names, ", ") or "-")
	else
		add("ban_phase", yes(d.ban_phase))
		add("in_control", yes(d.in_control))
		add("selected", yes(d.selected))
		for _, s in ipairs({ "r", "d" }) do
			local raw, names = {}, {}
			for i, p in ipairs(d.teams[s]) do
				raw[i] = (p.me and "*" or "") .. p.name .. ":" .. (p.h or "-") .. (p.tentative and "?" or "")
				local who = p.me and ("%s (%s)"):format(p.name, L("dh_d_me")) or p.name
				names[i] = ("%s %s%s"):format(who, name(p.h), p.tentative and (" (" .. L("dh_d_hover") .. ")") or "")
			end
			add("team_" .. s, table.concat(raw, ","), #names > 0 and table.concat(names, ", ") or "-")
		end
	end
	if d.grid then
		add("banned", heroes(d.grid.banned))
		add("picked", heroes(d.grid.picked))
		add("off", heroes(d.grid.off))
	end
	return rows
end

function live.tick()
	local now = os.clock()
	if now < live.next_read then return end
	live.next_read = now + K.LIVE_READ
	local pre = Panorama.GetPanelByName("PreGame", false)
	if SET.captain == 1 and pre and now >= live.next_captain and pre:HasClass("LocalTeamNeedsCaptain") then
		live.next_captain = now + K.LIVE_CAPTAIN
		local ok = Engine.RunScript(JS.CAPTAIN, pre)
		live.log("become captain: script %s", ok and "sent" or "failed")
	end
	local d = live.read(pre, now)
	live.d = d
	local parts = { d and ("mode=" .. d.mode) or "no draft" }
	for _, row in ipairs(live.rows(d)) do parts[#parts + 1] = row.id .. "=" .. row.raw end
	local trace = table.concat(parts, " ")
	if trace ~= live.trace then
		live.trace = trace
		live.log("%s", trace)
	end
	live.apply(d)
end

local build = { team = {}, me = nil }

function build.source()
	if draft.home_board() then return S.last end
	if not draft.done() then return nil end
	return { mode = S.mode, cm = S.cm, ap = S.ap }
end

function build.slots(enemy)
	local src, out = build.source(), {}
	if not src then return out end
	if src.mode == "ap" then
		for _, e in ipairs(enemy and src.ap.theirs or src.ap.ours) do
			out[#out + 1] = { h = e.h, get = function() return e.p end, set = function(v) e.p = v end }
		end
		return out
	end
	local cm = src.cm
	for i, h in ipairs(cm.picks) do
		if kind(i) == "P" and (side_of(cm.fp, i) == cm.us) ~= (enemy == true) then
			out[#out + 1] = { h = h, get = function() return cm.pos[i] end, set = function(v) cm.pos[i] = v end }
		end
	end
	return out
end

function build.frame()
	local list = build.slots(false)
	table.sort(list, function(a, b) return (a.get() or 9) < (b.get() or 9) end)
	build.team = list
	local me = draft.live() and live.d and live.d.me
	if me and me ~= build.me and build.is_ours(me) then build.me, S.bh = me, me end
	if S.view ~= "build" then return end
	if #list == 0 then
		S.view, S.bh = S.train and "draft" or "home", nil
	elseif not build.is_ours(S.bh) then
		S.bh = list[1].h
	end
end

function build.is_ours(h)
	for _, x in ipairs(build.team) do if x.h == h then return true end end
	return false
end

function build.open(h)
	if not build.is_ours(h) then return end
	if S.view == "draft" and draft.done() then
		S.bh, S.menu = h, nil
		return
	end
	if S.view ~= "build" then S.b_ret = S.view end
	S.view, S.bh, S.menu, S.sel, S.query, S.focus = "build", h, nil, nil, "", false
end

function build.open_team()
	if #build.team == 0 then return end
	build.open(build.is_ours(S.bh) and S.bh or build.team[1].h)
end

local g = { x = 0, y = 0, s = 1, a = 1, fits = {} }

function g.px(x) return math.floor(g.x + x * g.s + 0.5) end
function g.py(y) return math.floor(g.y + y * g.s + 0.5) end
function g.v(x, y) return Vec2(g.px(x), g.py(y)) end
function g.size(x, y, w, h) return Vec2(g.px(x + w) - g.px(x), g.py(y + h) - g.py(y)) end
function g.fs(size) return math.max(1, math.floor(size * g.s + 0.5)) end
function g.col(c, a)
	return Color(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), math.floor((c[4] or 255) * (a or 1) * g.a + 0.5))
end
function g.rect(x, y, w, h, c, r, a, flags)
	Render.FilledRect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), (r or 0) * g.s, flags or ROUND)
end
function g.glass(x, y, w, h, r, solid)
	local blur = SET.blur == 1
	local power = SET.blur_power / 100
	local k = g.a ^ 4
	if blur and k > 0.01 then Render.Blur(g.v(x, y), g.v(x + w, y + h), power * 2 * k, k, r * g.s, ROUND) end
	g.rect(x, y, w, h, C.main, r, blur and 1 - K.GLASS * power or solid)
end
function g.inset() return math.max(1, math.floor(2 * g.s + 0.5)) end
function g.thumb(x, y, w, h, from, to, c, r, a)
	local x1, y1, x2, y2, i = g.px(x), g.py(y), g.px(x + w), g.py(y + h), g.inset()
	local l = x1 + i
	local k = (x2 - i - l) / (w - 4)
	Render.FilledRect(Vec2(l + math.floor(from * k + 0.5), y1 + i), Vec2(l + math.floor(to * k + 0.5), y2 - i), g.col(c, a), r * g.s, ROUND)
end
function g.frame(x, y, w, h, c, r, a, t)
	Render.Rect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), (r or 0) * g.s, ROUND, (t or 1) * g.s)
end
function g.line(x1, y1, x2, y2, c, a, t)
	Render.Line(Vec2(g.x + x1 * g.s, g.y + y1 * g.s), Vec2(g.x + x2 * g.s, g.y + y2 * g.s), g.col(c, a), (t or 1) * g.s)
end
function g.width(font, size, str)
	return asset.size(font, g.fs(size), str).x / g.s
end
function g.text(font, size, str, x, cy, c, a, align)
	local px = g.fs(size)
	local ts = asset.size(font, px, str)
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - ts.x elseif align == "c" then tx = tx - ts.x / 2 end
	Render.Text(font, px, str, Vec2(math.floor(tx + 0.5), math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)), g.col(c, a))
	return ts.x / g.s
end
function g.fit(weight, size, str, max_w)
	local key = weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. str
	local out = g.fits[key]
	if out then return out end
	local font = asset.font(weight)
	out = str
	if g.width(font, size, str) > max_w then
		local chars = {}
		for _, c in utf8.codes(str) do chars[#chars + 1] = utf8.char(c) end
		out = "…"
		for n = #chars - 1, 1, -1 do
			local s = table.concat(chars, "", 1, n):gsub("%s+$", "") .. "…"
			if g.width(font, size, s) <= max_w then out = s break end
		end
	end
	g.fits[key] = out
	return out
end
function g.num(weight, size, str, x, cy, c, a, align)
	local font, px = asset.font(weight), g.fs(size)
	local dw = asset.digit_w(font, px)
	local parts, total = {}, 0
	for ch in str:gmatch(".") do
		local w = ch:match("%d") and dw or asset.size(font, px, ch).x
		parts[#parts + 1] = { ch, w }
		total = total + w
	end
	local ts = asset.size(font, px, str)
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - total elseif align == "c" then tx = tx - total / 2 end
	local ty = math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)
	local col = g.col(c, a)
	for _, part in ipairs(parts) do
		local cw = part[2]
		local off = part[1]:match("%d") and (cw - asset.size(font, px, part[1]).x) / 2 or 0
		Render.Text(font, px, part[1], Vec2(math.floor(tx + off + 0.5), ty), col)
		tx = tx + cw
	end
	return total / g.s
end
function g.num_width(weight, size, str)
	local font, px = asset.font(weight), g.fs(size)
	local dw, total = asset.digit_w(font, px), 0
	for ch in str:gmatch(".") do total = total + (ch:match("%d") and dw or asset.size(font, px, ch).x) end
	return total / g.s
end
function g.glyph(name, size, x, cy, c, a, align)
	return g.text(asset.icons(), size, K.G[name], x, cy, c, a, align or "c")
end
function g.image(handle, x, y, w, h, r, a, gray, tint)
	if not handle then return end
	local size = Render.ImageSize(handle)
	local ia, ba = size.x / math.max(1, size.y), w / h
	local u0, v0, u1, v1 = 0, 0, 1, 1
	if ia > ba then
		local k = ba / ia
		u0, u1 = (1 - k) / 2, (1 + k) / 2
	else
		local k = ia / ba
		v0, v1 = (1 - k) / 2, (1 + k) / 2
	end
	Render.Image(handle, g.v(x, y), g.size(x, y, w, h), g.col(tint or C.text, a), (r or 0) * g.s, ROUND, Vec2(u0, v0), Vec2(u1, v1), gray or 0)
end
function g.icon(handle, x, y, size, c, a)
	if not handle then return end
	Render.Image(handle, g.v(x, y), g.size(x, y, size, size), g.col(c or C.text, a), 0, ROUND, Vec2(0, 0), Vec2(1, 1), 0)
end
function g.clip(x, y, w, h) Render.PushClip(g.v(x, y), g.v(x + w, y + h), true) end
function g.unclip() Render.PopClip() end
function g.vr(x, cy, h, a) g.rect(x, cy - h / 2, 1, h, C.sep, 0, a) end

local function F(w) return asset.font(w) end

local anim = {}

function anim.tween(key, target, time, curve)
	local t = S.tweens[key]
	if not t then
		t = { from = target, to = target, v = target, k = 1 }
		S.tweens[key] = t
	end
	if t.to ~= target then t.from, t.to, t.k = t.v, target, 0 end
	if t.k < 1 then
		t.k = math.min(1, t.k + S.dt / time)
		t.v = t.from + (t.to - t.from) * (curve or ease_out)(t.k)
	else
		t.v = t.to
	end
	return t.v
end

function anim.hover(id, on)
	return anim.tween("hv:" .. id, on and 1 or 0, 0.12)
end

function anim.snap(key, value)
	S.tweens[key] = { from = value, to = value, v = value, k = 1 }
end

local hit = { list = {}, prev = {}, hover = nil, clip = nil }

function hit.begin()
	hit.prev, hit.list, hit.clip = hit.list, {}, nil
	local mx, my = Input.GetCursorPos()
	hit.hover = nil
	for i = #hit.prev, 1, -1 do
		local h = hit.prev[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then
			hit.hover = h[5]
			break
		end
	end
	if S.press and hit.hover ~= S.press.id then hit.hover = nil end
end

function hit.add(x, y, w, h, id, on)
	local x1, y1, x2, y2 = g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s
	if hit.clip then
		x1, y1 = math.max(x1, hit.clip[1]), math.max(y1, hit.clip[2])
		x2, y2 = math.min(x2, hit.clip[3]), math.min(y2, hit.clip[4])
		if x2 <= x1 or y2 <= y1 then return end
	end
	hit.list[#hit.list + 1] = { x1, y1, x2, y2, id, on or {} }
end

function hit.is(id) return hit.hover == id end

function hit.at(mx, my)
	for i = #hit.list, 1, -1 do
		local h = hit.list[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then return h end
	end
	return nil
end

local view = {}

function view.slot(x, y, w, h, hero, o, key)
	local filled = hero ~= nil
	g.rect(x, y, w, h, o.cur and C.slot_cur or C.fill4, 7)
	if o.cur then g.frame(x, y, w, h, C.slot_line, 7) end
	local k = anim.tween("slot" .. key, filled and 1 or 0, 0.3)
	local kg = anim.tween("ghost" .. key, (not filled and o.ghost) and (o.ghost == S.sel and 0.8 or 0.45) or 0, 0.15)
	if filled and k > 0 then
		g.clip(x, y, w, h)
		local ban = o.ban
		g.image(asset.portrait(hero), x, y, w, h, 7, k, ban and 1 or 0, ban and C.ban_tint or C.text)
		if ban then
			local cx, cy, len = x + w / 2, y + h / 2, w * 0.58
			local dx, dy = math.cos(math.rad(24)) * len, math.sin(math.rad(24)) * len
			g.line(cx - dx, cy + dy, cx + dx, cy - dy, C.red, k, 1.5)
		end
		g.unclip()
		if o.pos then
			g.rect(x + 3, y + h - 22, 19, 19, C.badge, 5, k)
			g.icon(asset.pos(o.pos), x + 5, y + h - 20, 15, C.text, k)
		end
		if S.view == "build" and not ban and build.is_ours(hero) then
			local id, on = "bs:" .. key, S.bh == hero
			if on or hit.is(id) then g.frame(x, y, w, h, C.text, 7, on and 1 or 0.5) end
			hit.add(x, y, w, h, id, { click = function() build.open(hero) end })
		elseif o.key then
			local open = S.menu ~= nil and S.menu.key == o.key
			if open or hit.is(o.key) then g.frame(x, y, w, h, C.text, 7, open and 1 or 0.5) end
			local function open_menu() view.open_pos_menu(o.key, x + w, y) end
			hit.add(x, y, w, h, o.key, { click = open_menu, rclick = open_menu })
			view.hint(o.key, L("dh_tip_slot"))
		end
	elseif o.ghost then
		g.clip(x, y, w, h)
		g.image(asset.portrait(o.ghost), x, y, w, h, 7, kg)
		g.unclip()
	elseif o.hidden then
		g.glyph("hidden", 18, x + w / 2, y + h / 2, C.text4)
	end
end

function view.titles(us, active)
	for _, side in ipairs({ "r", "d" }) do
		local cx = side == "r" and 120 or 280
		local on = active == nil or active == side
		g.text(F(700), 14, L(side == "r" and "dh_side_r" or "dh_side_d"), cx, K.TB + 24, on and C.text or C.text3, 1, "c")
		if us == side then g.text(F(600), 11, L("dh_we"), cx, K.TB + 41, side == "r" and C.green or C.red, 1, "c") end
	end
end

function view.board_cm(o)
	local n = #o.picks
	local cur = (n < 24 and not o.idle) and n + 1 or nil
	view.titles(o.us, cur and side_of(o.fp, cur) or nil)
	for i = 1, 24 do
		local pick, side = kind(i) == "P", side_of(o.fp, i)
		local w, h = pick and 71 or 57, pick and 40 or 30
		local x = side == "r" and 156 - w or (pick and 239 or 240)
		local y, ny = K.TOPY[i] + K.BOARD_Y, K.NUMY[i] + K.BOARD_Y
		local x0, x1 = side == "r" and x + w or 214, side == "r" and 186 or x
		g.rect(x0, ny, x1 - x0, 1, i == cur and C.tick_cur or C.sep2)
		g.num(i == cur and 700 or 500, 11, tostring(i), 200, ny, i == cur and C.text or (i <= n and C.text2 or C.text3), 1, "c")
		view.slot(x, y, w, h, o.picks[i], {
			ban = not pick, cur = i == cur, pos = pick and o.pos[i] or nil,
			ghost = i == cur and o.ghost or nil, key = o.live and pick and o.picks[i] and ("c" .. i) or nil,
		}, "c" .. i)
	end
end

function view.board_ap(o)
	local round = o.round
	view.titles(o.us, nil)
	g.text(F(500), 11, L("dh_bans16"), 22, K.TB + 68, C.text3)
	for i = 1, 16 do
		local x, y = 22 + ((i - 1) % 8) * 45, K.TB + 80 + math.floor((i - 1) / 8) * 28
		view.slot(x, y, 40, 23, o.bans[i], { ban = true }, "b" .. i)
	end
	for _, side in ipairs({ "r", "d" }) do
		local mine = side == o.us
		local arr = mine and o.ours or o.theirs
		local x = side == "r" and 68 or 228
		for j = 1, 5 do
			local y, r = K.AP_Y[j] + K.TB, K.AP_ROUND[j]
			local e = arr[j]
			local cur = mine and j == #o.ours + 1 and round <= 3
			g.rect(side == "r" and x + 104 or 212, y + 29, 16, 1, r == round and C.tick_cur or C.sep2)
			view.slot(x, y, 104, 58, e and e.h, {
				cur = cur, pos = e and e.p, ghost = cur and o.ghost or nil,
				hidden = not mine and not e and r == round,
				key = o.live and e and ((mine and "o" or "t") .. j) or nil,
			}, side .. j)
		end
		for r = 1, 2 do
			local a, b = K.AP_Y[r * 2 - 1] + K.TB + 29, K.AP_Y[r * 2] + K.TB + 29
			g.rect(side == "r" and 187 or 212, a, 1, b - a + 1, r == round and C.tick_cur or C.sep2)
		end
	end
	for r = 1, 3 do
		g.num(r == round and 700 or 500, 11, tostring(r), 200, K.AP_MID[r] + K.TB, r == round and C.text or (r < round and C.text2 or C.text3), 1, "c")
	end
end

function view.board()
	g.rect(0, K.TB, K.PAN, K.H - K.TB, C.side, 16, 1, Enum.DrawFlags.RoundCornersBottomLeft)
	g.rect(K.PAN - 1, K.TB, 1, K.H - K.TB, C.black)
	local ghost = S.ghost or S.sel
	if draft.home_board() then
		local last = S.last
		if last and last.mode == "ap" then
			view.board_ap({ us = last.ap.us, ours = last.ap.ours, theirs = last.ap.theirs, bans = last.ap.bans, round = 4 })
		elseif last then
			view.board_cm({ fp = last.cm.fp, us = last.cm.us, picks = last.cm.picks, pos = last.cm.pos })
		else
			view.board_cm({ fp = "d", us = SET.tr_side, picks = {}, pos = {}, idle = true })
		end
	elseif S.mode == "ap" then
		local bans = draft.live() and live.d and live.d.grid and live.d.grid.banned or {}
		view.board_ap({ us = S.ap.us, ours = S.ap.ours, theirs = S.ap.theirs, bans = bans, round = draft.ap_round(), ghost = ghost, live = true })
	else
		view.board_cm({ fp = S.cm.fp, us = S.cm.us, picks = S.cm.picks, pos = S.cm.pos, ghost = draft.can_act() and ghost or nil, live = true })
	end
end

function view.hint(id, text)
	if SET.hints == 1 and hit.is(id) then S.tip = text end
end

function view.button_icon(name, x, id, on_click, active, tip)
	local k = anim.hover(id, hit.is(id) or active)
	if k > 0 then g.rect(x, 12, 32, 28, active and C.fill3 or C.fill4, 6, k) end
	g.glyph(name, 16, x + 16, 26, (hit.is(id) or active) and C.text or C.text2)
	hit.add(x, 12, 32, 28, id, { click = on_click })
	if tip then view.hint(id, tip) end
end

function view.toolbar()
	g.rect(0, 0, K.W, K.TB, C.bar, 16, 1, Enum.DrawFlags.RoundCornersTop)
	g.rect(0, K.TB - 1, K.W, 1, C.black)
	hit.add(0, 0, K.W, K.TB, "drag", { down = function(mx, my) S.drag = { mx = mx, my = my, wx = S.wx, wy = S.wy } end })
	local x = 22
	x = x + g.text(F(700), 16, L("dh_title"), x, 26, C.text) + 14
	g.vr(x, 26, 13)
	x = x + 15
	local mode_name = S.mode == "ap" and "All Pick" or "Captains Mode"
	if draft.home_board() then
		g.text(F(400), 13, L("dh_out"), x, 26, C.text2)
	elseif S.train then
		x = x + g.text(F(400), 13, L("dh_training"), x, 26, C.text2) + 12
		g.vr(x, 26, 13)
		g.text(F(400), 13, mode_name, x + 13, 26, C.text2)
	else
		g.text(F(400), 13, mode_name, x, 26, C.text2)
	end

	local right = K.CX + K.CW - 32
	view.button_icon("close", right, "tb_close", function()
		S.open, S.menu, S.sel, S.focus = false, nil, nil, false
	end, false, L("dh_tip_close"))
	right = right - 8
	if S.view == "draft" or S.view == "pool" then
		right = right - 210
		view.search(right, 12)
		right = right - 8
	end
	local in_set = S.view == "set" or S.view == "pool"
	right = right - 32
	view.button_icon("gear", right, "tb_gear", function()
		S.menu, S.sel = nil, nil
		if in_set then S.view = S.ret else S.ret, S.view = S.view, "set" end
	end, in_set, L(in_set and "dh_tip_back" or "dh_tip_settings"))
	if S.train then
		right = right - 40
		view.button_icon("trash", right, "tb_reset", function() draft.start_training(S.mode) end, false, L("dh_tip_reset"))
		right = right - 40
		view.button_icon("undo", right, "tb_undo", draft.undo, false, L("dh_tip_undo"))
	end
	if S.train or (S.env == "home" and S.view ~= "home") then
		right = right - 40
		view.button_icon("house", right, "tb_home", draft.go_home, false, L("dh_tip_home"))
	end
	right = view.update_pill(right)

	local c = SET.chance == 1 and draft.chance() or nil
	local ch = S.chance
	if c then
		if ch.to ~= c then ch.from, ch.to, ch.t = ch.to or c, c, 0 end
		ch.t = math.min(1, ch.t + S.dt / 0.5)
		local v = (ch.from + (ch.to - ch.from) * ease_out(ch.t)) * 100
		local vx = right - 16
		local nw = g.num(600, 17, string.format("%d%%", math.floor(v + 0.5)), vx, 26, c >= 0.5 and C.green or C.red, 1, "r")
		g.text(F(400), 13, L("dh_chance"), vx - nw - 8, 27, C.text2, 1, "r")
	else
		ch.to = nil
	end
end

function view.update_pill(right)
	local st = upd.state
	local shown = st == "available" or st == "loading" or st == "done" or st == "error"
	local glyph, label, col, text_col
	if st == "available" then
		glyph, label, col, text_col = "arrow_down", string.format(L("dh_upd_pill"), upd.short(upd.latest)), C.blue, C.text
	elseif st == "loading" then
		label, col, text_col = L("dh_upd_pill_loading"), { 10, 132, 255, 90 }, C.text
	elseif st == "done" then
		glyph, label, col, text_col = "check", L("dh_upd_pill_done"), { 48, 209, 88, 72 }, C.green
	elseif st == "error" then
		glyph, label, col, text_col = "alert", L("dh_upd_retry"), { 255, 69, 58, 72 }, C.red
	end
	local content = label and (18 + 7 + g.width(F(500), 13, label)) or 0
	local w = anim.tween("upd_w", shown and content + 24 or 0, 0.28, ease_in_out)
	local k = anim.tween("upd_a", shown and 1 or 0, 0.2)
	if w < 1 then return right end
	local x = right - 8 - w
	local prev = upd.col_prev or col or C.blue
	local mix = math.min(1, (os.clock() - upd.changed_at) / 0.25)
	if mix >= 1 then upd.col_prev = col end
	local bg = col and prev and {
		prev[1] + (col[1] - prev[1]) * mix, prev[2] + (col[2] - prev[2]) * mix, prev[3] + (col[3] - prev[3]) * mix,
		(prev[4] or 255) + ((col[4] or 255) - (prev[4] or 255)) * mix,
	} or prev
	g.clip(x, 12, w, 28)
	g.rect(x, 12, w, 28, bg, 14, k * (hit.is("tb_update") and 0.85 or 1))
	if label then
		local la = k * math.min(1, (os.clock() - upd.changed_at) / 0.18)
		local cx = x + 11
		if glyph then
			g.glyph(glyph, 14, cx + 8, 26, text_col, la, "c")
		else
			Render.Circle(g.v(cx + 8, 26), 5.5 * g.s, g.col(C.text4, la), 1.5 * g.s)
			Render.Circle(g.v(cx + 8, 26), 5.5 * g.s, g.col(C.text, la), 1.5 * g.s, (S.now * 400) % 360, 0.25, true)
		end
		g.text(F(500), 13, label, cx + 25, 26, C.text, la)
	end
	g.unclip()
	if st == "available" or st == "error" then
		hit.add(x, 12, w, 28, "tb_update", { click = upd.install })
		if st == "error" and hit.is("tb_update") and upd.error then S.tip = upd.error end
		if st == "available" then view.hint("tb_update", L("dh_tip_update")) end
	end
	return x
end

function view.search(x, y)
	local focused = S.focus
	g.rect(x, y, 210, 28, focused and C.fill2 or C.fill3, 7)
	if focused then g.frame(x, y, 210, 28, C.focus, 7) end
	g.glyph("search", 14, x + 15, y + 14, C.text2)
	if S.query ~= "" then
		local tw = g.text(F(400), 13, S.query, x + 28, y + 14, C.text)
		if focused and (S.now % 1) < 0.55 then g.rect(x + 29 + tw, y + 7, 1, 14, C.text) end
		g.glyph("clear", 14, x + 196, y + 14, hit.is("search_clear") and C.text2 or C.text3)
		hit.add(x + 184, y, 26, 28, "search_clear", { click = function() S.query = "" end })
	else
		g.text(F(400), 13, L("dh_search"), x + 28, y + 14, C.text3)
		if focused and (S.now % 1) < 0.55 then g.rect(x + 28, y + 7, 1, 14, C.text) end
	end
	hit.add(x, y, 184, 28, "search", { click = function() S.focus = true end })
end

function view.no_head() return S.view == "draft" and draft.done() and S.query == "" end

function view.head()
	local x, right = K.CX, K.CX + K.CW
	local title, of, sub = "", nil, {}
	local function add(text, bold, spin) sub[#sub + 1] = { text = text, bold = bold, spin = spin } end
	local done_btn
	if S.view == "home" then
		title = L("dh_title")
		add(L("dh_home_sub"))
	elseif S.view == "set" then
		title, done_btn = L("dh_settings"), "close"
		add(L("dh_set_sub"))
	elseif S.view == "pool" then
		title, done_btn = L("dh_pool_title"), "poolback"
		add(heroes_n(#SET.pool), true)
		add(L(SET.pool_mode == "only" and "dh_pool_only_sub" or (SET.pool_mode == "off" and "dh_pool_off_sub" or "dh_pool_boost_sub")))
	elseif S.view == "build" then
		title, done_btn = L("dh_h_last"), "buildback"
		if S.last then
			add(S.last.mode == "ap" and "All Pick" or "Captains Mode", true)
			add(string.format(L("dh_h_last_chance"), math.floor(S.last.chance * 100 + 0.5)))
		end
	elseif S.query ~= "" then
		title = L("dh_search_title")
		add(draft.done() and L("dh_search_done") or (draft.can_act() and L("dh_search_sub") or L("dh_search_enemy")))
	elseif draft.done() then
		title = L("dh_done")
		add(L(S.mode == "ap" and "dh_done_ap" or "dh_done_cm"))
	elseif S.mode == "ap" then
		local r = draft.ap_round()
		local left = K.AP_ROUND_END[r] - #S.ap.ours
		title, of = L("dh_our_pick"), string.format(L("dh_round_of"), r)
		if draft.live() and not draft.can_act() then add(L("dh_live_wait"), true) end
		add(left == 1 and L("dh_ap_last") or string.format(L("dh_ap_left"), left), true)
		add(S.reveal_at and L("dh_ap_reveal") or (r == 1 and L("dh_ap_hidden") or L("dh_ap_counter")))
	else
		local i, side = draft.cm_step(), draft.cm_side()
		local us, ban = side == S.cm.us, kind(i) == "B"
		title = L(ban and (us and "dh_our_ban" or "dh_enemy_ban") or (us and "dh_our_pick" or "dh_enemy_pick"))
		of = string.format(L("dh_step_of"), i)
		if not us then
			if draft.manual_enemy() then add(L(ban and "dh_enemy_manual_ban" or "dh_enemy_manual_pick"), true)
			else add(L(ban and "dh_enemy_auto_ban" or "dh_enemy_auto_pick"), true, true) end
		elseif draft.live() and not draft.can_act() then
			add(L("dh_live_captain"), true)
		elseif not ban then
			for _, j in ipairs({ i - 1, i + 1 }) do
				if j >= 1 and j <= 24 and kind(j) == "P" and side_of(S.cm.fp, j) == side then
					add(j > i and string.format(L("dh_double_next"), j) or L("dh_double_second"), true)
					break
				end
			end
		end
		local st = draft.step()
		local text
		if not st then text = L("dh_data_" .. data.status(draft.set_key()))
		elseif not st.c then text = L("dh_sub_noctx")
		elseif draft.positional() and st.lane then text = L("dh_sub_lane")
		elseif draft.positional() and S.filter > 0 then text = string.format(L("dh_sub_filter"), L("dh_posa_" .. S.filter))
		else text = L(ban and (us and "dh_sub_our_ban" or "dh_sub_enemy_ban") or (us and "dh_sub_our_pick" or "dh_sub_enemy_pick")) end
		add(text)
	end
	g.text(F(800), 28, title, x, K.TB + 47, C.text)
	if of then g.text(F(400), 13, of, right, K.TB + 49, C.text3, 1, "r") end
	if done_btn then
		local w = g.width(F(600), 15, L("dh_ready")) + 12
		local id = "head_" .. done_btn
		if hit.is(id) then g.rect(right - w, K.TB + 37, w, 24, { 10, 132, 255, 36 }, 6) end
		g.text(F(600), 15, L("dh_ready"), right - 6, K.TB + 49, C.blue, 1, "r")
		hit.add(right - w, K.TB + 37, w, 24, id, { click = function()
			S.view = done_btn == "poolback" and S.pool_ret or (done_btn == "buildback" and S.b_ret or S.ret)
		end })
	end
	local cx, cy = x, K.TB + 79
	g.clip(x, cy - 12, K.CW, 24)
	for n, part in ipairs(sub) do
		if n > 1 then
			g.vr(cx, cy, 13)
			cx = cx + 11
		end
		if part.spin then
			Render.Circle(g.v(cx + 6, cy), 5.5 * g.s, g.col(C.text4), 1.5 * g.s)
			Render.Circle(g.v(cx + 6, cy), 5.5 * g.s, g.col(C.text), 1.5 * g.s, (S.now * 400) % 360, 0.25, true)
			cx = cx + 18
		end
		cx = cx + g.text(F(part.bold and 500 or 400), 14, part.text, cx, cy, part.bold and C.text or C.text2) + 10
	end
	g.unclip()
end

function view.segment()
	local x, y, w, h = K.CX, K.TB + 112, K.CW, 32
	g.rect(x, y, w, h, C.fill3, 9)
	local bw = (w - 4) / 6
	local tx = anim.tween("seg", x + 2 + S.filter * bw, 0.3, ease_in_out)
	g.thumb(x, y, w, h, tx - x - 2, tx - x - 2 + bw, C.thumb, 7)
	local busy = draft.our_pos()
	for p = 0, 5 do
		local bx = x + 2 + p * bw
		local on, is_busy = S.filter == p, p > 0 and busy[p]
		if p > 0 and not on and S.filter ~= p - 1 then g.rect(bx, y + 8, 1, h - 16, C.sep2) end
		local label = p == 0 and L("dh_auto") or L("dh_pos_" .. p)
		local col = on and C.text or (is_busy and C.text3 or C.text2)
		local tw = g.width(F(500), 13, label) + 24
		local lx = math.floor(bx + (bw - tw) / 2 + 0.5)
		if p == 0 then g.glyph("wand", 14, lx + 9, y + 16, col) else g.icon(asset.pos(p), lx, y + 7, 18, col) end
		g.text(F(500), 13, label, lx + 24, y + 16, col)
		hit.add(bx, y, bw, h, "seg" .. p, { click = function() S.filter = p end })
	end
end

function view.value(r, ctx, right, cy, size)
	local col = C.text
	if ctx then col = r.d >= 0.05 and C.green or (r.d <= -0.05 and C.red or C.text2) end
	local hero = data.heroes[r.h]
	g.num(600, size, ctx and signed(r.d) or string.format("%.1f%%", hero.rate), right, cy - 9, col, 1, "r")
	local mx = right - g.text(F(400), 11, string.format(L("dh_matches"), data.count(hero.games)), right, cy + 9, C.text3, 1, "r")
	if ctx then
		g.vr(mx - 7, cy + 9, 9)
		g.num(400, 11, string.format("%.1f%%", hero.rate), mx - 14, cy + 9, C.text3, 1, "r")
	end
end

function view.reasons(r, ctx, x, cy, max_x)
	g.clip(x, cy - 10, max_x - x, 20)
	local cx, first = x, true
	local function sep()
		if not first then
			g.vr(cx, cy, 13)
			cx = cx + 7
		end
		first = false
	end
	if r.pos then
		sep()
		g.icon(asset.pos(r.pos), cx, cy - 8, 16, C.text2)
		cx = cx + 21 + g.text(F(500), 12, r.share and (r.share .. "%") or L("dh_pos_" .. r.pos), cx + 21, cy, C.text2) + 6
	end
	if ctx and SET.reasons == 1 then
		local function item_w(e) return 23 + g.num_width(500, 12, signed(e[2])) + 6 end
		for _, group in ipairs(r.why or {}) do
			local label = L("dh_" .. group[1])
			local need = (first and 0 or 7) + g.width(F(400), 12, label) + 5 + item_w(group[2][1])
			if cx + need > max_x then break end
			sep()
			cx = cx + g.text(F(400), 12, label, cx, cy, C.text3) + 5
			for n = 1, math.min(2, #group[2]) do
				local h, v = group[2][n][1], group[2][n][2]
				if n > 1 and cx + item_w(group[2][n]) > max_x then break end
				g.icon(asset.icon(h), cx, cy - 9, 18)
				cx = cx + 23
				cx = cx + g.num(500, 12, signed(v), cx, cy, v >= 0 and C.green or C.red) + 6
			end
		end
	end
	if not ctx and not r.pos then
		sep()
		g.text(F(400), 12, L("dh_by_rate"), cx, cy, C.text3)
	end
	g.unclip()
end

function view.hero_name(h, size, weight, x, cy)
	local w = g.text(F(weight), size, data.heroes[h].name, x, cy, C.text)
	if in_pool(h) then g.glyph("star", size - 2, x + w + 6, cy, C.yellow, 1, "l") end
end

function view.how() return L(SET.confirm == 1 and "dh_how_confirm" or "dh_how_click") end

function view.row_actions(h)
	return {
		click = function() draft.place(h) end,
		dbl = function() draft.commit(h) end,
		rclick = function(mx, my) view.open_ctx(h, mx, my) end,
	}
end

function view.best(r, ctx, y, a, can)
	local x, w = K.CX, K.CW
	local id = "h:" .. r.h
	local sel = S.sel == r.h
	g.rect(x, y, w, 100, C.card, 14, a)
	local k = anim.hover(id, can and hit.is(id))
	if k > 0 then g.rect(x, y, w, 100, C.hover, 14, a * k) end
	local ks = anim.tween("sel:" .. r.h, sel and 1 or 0, 0.15)
	if ks > 0 then g.rect(x, y, w, 100, C.select, 14, a * ks) end
	g.image(asset.portrait(r.h), x + K.P, y + K.P, 128, 72, 9, a)
	view.hero_name(r.h, 20, 700, x + 156, y + 38)
	view.reasons(r, ctx, x + 156, y + 63, x + w - 150)
	view.value(r, ctx, x + w - K.P, y + 50, 28)
	if can then
		hit.add(x, y, w, 100, id, view.row_actions(r.h))
		view.hint(id, view.how())
	end
	return 100
end

function view.rows(list, ctx, y, a, can, na)
	local x, w = K.CX, K.CW
	g.rect(x, y, w, #list * 56, C.card, 12, a)
	for n, r in ipairs(list) do
		local ry = y + (n - 1) * 56
		local id = "h:" .. r.h
		local sel = S.sel == r.h
		local k = anim.hover(id, can and hit.is(id))
		local ks = anim.tween("sel:" .. r.h, sel and 1 or 0, 0.15)
		if k > 0 or ks > 0 then
			local flags = (n == 1 and #list == 1) and ROUND or (n == 1 and Enum.DrawFlags.RoundCornersTop or (n == #list and Enum.DrawFlags.RoundCornersBottom or Enum.DrawFlags.RoundCornersNone))
			if k > 0 then g.rect(x, ry, w, 56, C.hover, 12, a * k, flags) end
			if ks > 0 then g.rect(x, ry, w, 56, C.select, 12, a * ks, flags) end
		end
		if n > 1 and not sel and S.sel ~= list[n - 1].h then g.rect(x + 88, ry, w - 88, 1, C.sep2, 0, a) end
		g.image(asset.portrait(r.h), x + K.P, ry + 11, 60, 34, 6, a)
		view.hero_name(r.h, 15, 600, x + 88, ry + 19)
		if na then
			local hero = data.heroes[r.h]
			local cx = x + 88
			if hero.pos then
				g.icon(asset.pos(hero.pos), cx, ry + 31, 16, C.text2, a)
				cx = cx + 21 + g.text(F(500), 12, L("dh_pos_" .. hero.pos), cx + 21, ry + 39, C.text2, a) + 7
				g.vr(cx, ry + 39, 13, a)
				cx = cx + 7
			end
			g.text(F(400), 12, L("dh_attr_" .. hero.attr), cx, ry + 39, C.text3, a)
			g.text(F(400), 12, na, x + w - K.P, ry + 28, C.text3, a, "r")
		else
			view.reasons(r, ctx, x + 88, ry + 39, x + w - 140)
			view.value(r, ctx, x + w - K.P, ry + 28, 15)
		end
		if can then
			hit.add(x, ry, w, 56, id, view.row_actions(r.h))
			view.hint(id, view.how())
		end
	end
	return #list * 56
end

function view.text_block(text, y, a)
	g.text(F(400), 12, text, K.CX + K.CW / 2, y + 7, C.text3, a, "c")
	return 14
end

function view.button(label, glyph, x, y, primary, id, on_click, a)
	local w = g.width(F(500), 14, label) + 32 + (glyph and 20 or 0)
	local col = primary == "blue" and C.blue or (primary == "red" and C.red or C.fill2)
	g.rect(x, y, w, 34, col, 8, hit.is(id) and a * 0.9 or a)
	local tx = x + 16
	if glyph then
		g.glyph(glyph, 14, tx + 6, y + 17, C.text, a)
		tx = tx + 20
	end
	g.text(F(500), 14, label, tx, y + 17, C.text, a)
	hit.add(x, y, w, 34, id, { click = on_click })
	return w
end

function view.draft_content(y, a)
	local can = draft.can_act()
	local st = draft.step()
	local ctx = st and st.c
	local status = data.status(draft.set_key())
	if status ~= "ok" and not draft.done() then return view.data_state(status, y, a) end
	if S.query ~= "" then
		if draft.done() then return view.text_block(L("dh_search_done"), y + 20, a) + 20 end
		local q, used, list, na = S.query:lower(), draft.used(), {}, {}
		for _, hero in ipairs(data.list) do
			if not used[hero.h] and hero.name:lower():find(q, 1, true) then list[#list + 1] = hero end
			if #list >= 12 then break end
		end
		if #list == 0 then return view.text_block(L("dh_search_none"), y + 20, a) + 20 end
		local rows, h = {}, 0
		local function flush()
			if #rows == 0 then return end
			h = h + view.rows(rows, ctx, y + h, a, can)
			rows = {}
		end
		for _, hero in ipairs(list) do
			local r = draft.row_for(hero.h)
			if r then
				rows[#rows + 1] = r
			else
				flush()
				h = h + view.rows({ { h = hero.h } }, ctx, y + h, a, can, L("dh_no_data"))
			end
		end
		flush()
		return h
	end
	if draft.done() then return view.done(y, a) end
	local list = draft.rows()
	if #list == 0 then
		local only = draft.pool_on() and SET.pool_mode == "only"
		view.text_block(L(only and "dh_empty_pool" or "dh_empty_pos"), y + 30, a)
		if only then
			local w = g.width(F(500), 14, L("dh_open_pool")) + 52
			view.button(L("dh_open_pool"), "star", K.CX + (K.CW - w) / 2, y + 56, nil, "open_pool", function()
				S.pool_ret, S.ret, S.view = "draft", "draft", "pool"
			end, a)
		end
		return 100
	end
	local h = view.best(list[1], ctx, y, a, can)
	if #list > 1 then
		local rest = {}
		for i = 2, #list do rest[#rest + 1] = list[i] end
		h = h + 14 + view.rows(rest, ctx, y + h + 14, a, can)
	end
	local how = not can and L("dh_how_enemy") or (SET.confirm == 1 and L("dh_how_confirm") or L("dh_how_click"))
	return h + 14 + view.text_block(how, y + h + 14, a)
end

function view.done(y, a)
	return view.summary(y, a)
end

function view.group_header(text, y, a)
	g.text(F(700), 17, text, K.CX + K.P, y + 10, C.text, a)
	return 30
end

function view.foot(text, y, a)
	g.text(F(400), 12, text, K.CX + K.P, y + 15, C.text3, a)
	return 26
end

function view.data_state(status, y, a)
	local text = L("dh_data_" .. status)
	local w = g.width(F(400), 12, text)
	view.error_tip(K.CX + (K.CW - w) / 2, y + 28, w, 18)
	return view.text_block(text, y + 30, a) + 30
end

function view.error_tip(x, y, w, h)
	if not data.failed or not data.error then return end
	hit.add(x, y, w, h, "data_error", {})
	if hit.is("data_error") then S.tip = data.error end
end

function view.setting_rows(rows, y, a)
	local x, w = K.CX, K.CW
	g.rect(x, y, w, #rows * 50, C.card, 12, a)
	for n, row in ipairs(rows) do
		local ry = y + (n - 1) * 50
		if n > 1 then g.rect(x + 58, ry, w - 58, 1, C.sep2, 0, a) end
		local k = row.act and anim.hover(row.id, hit.is(row.id)) or 0
		if k > 0 then
			local flags = (#rows == 1) and ROUND or (n == 1 and Enum.DrawFlags.RoundCornersTop or (n == #rows and Enum.DrawFlags.RoundCornersBottom or Enum.DrawFlags.RoundCornersNone))
			g.rect(x, ry, w, 50, C.hover, 12, a * k, flags)
		end
		g.rect(x + K.P, ry + 10, 30, 30, row.tile, 8, a)
		g.glyph(row.glyph, 16, x + K.P + 15, ry + 25, C.text, a)
		if row.sub then
			g.text(F(600), 14, row.title, x + 58, ry + 17, C.text, a)
			g.text(F(400), 12, row.sub, x + 58, ry + 34, C.text3, a)
		else
			g.text(F(600), 14, row.title, x + 58, ry + 25, C.text, a)
		end
		if row.control then row.control(x + w - K.P, ry + 25, a) end
		if row.act then hit.add(x, ry, w, 50, row.id, { click = row.act }) end
	end
	return #rows * 50
end

function view.switch(key)
	return function(right, cy, a)
		local on = SET[key] == 1
		local k = anim.tween("sw" .. key, on and 1 or 0, 0.25, ease_in_out)
		local x = right - 42
		local bg = { 120 + (48 - 120) * k, 120 + (209 - 120) * k, 128 + (88 - 128) * k, 82 + (255 - 82) * k }
		g.rect(x, cy - 13, 42, 26, bg, 13, a)
		local x1, y1, x2, y2 = g.px(x), g.py(cy - 13), g.px(x + 42), g.py(cy + 13)
		local half = (y2 - y1) / 2
		Render.FilledCircle(Vec2(x1 + half + (x2 - x1 - 2 * half) * k, y1 + half), half - g.inset(), g.col(C.text, a))
		hit.add(x, cy - 13, 42, 26, "sw" .. key, { click = function()
			SET[key] = on and 0 or 1
			save_settings()
		end })
	end
end

function view.choice(id, options, current, on_pick)
	return function(right, cy, a)
		local widths, total = {}, 4
		for i, o in ipairs(options) do
			widths[i] = g.width(F(500), 12, o[2]) + 22
			total = total + widths[i]
		end
		local x = right - total
		g.rect(x, cy - 14, total, 28, C.fill3, 8, a)
		local sel_x, sel_w, bx = 2, widths[1], 2
		for i, o in ipairs(options) do
			if o[1] == current then sel_x, sel_w = bx, widths[i] end
			bx = bx + widths[i]
		end
		local tx = anim.tween(id .. "_x", sel_x, 0.28, ease_in_out)
		local tw = anim.tween(id .. "_w", sel_w, 0.28, ease_in_out)
		g.thumb(x, cy - 14, total, 28, tx - 2, tx - 2 + tw, C.thumb, 6, a)
		bx = x + 2
		for i, o in ipairs(options) do
			local on, disabled = o[1] == current, o[3]
			g.text(F(500), 12, o[2], bx + widths[i] / 2, cy, on and C.text or (disabled and C.text4 or C.text2), a, "c")
			if not disabled then hit.add(bx, cy - 12, widths[i], 24, id .. i, { click = function() on_pick(o[1]) end }) end
			bx = bx + widths[i]
		end
	end
end

function view.slider(key, min, max)
	return function(right, cy, a)
		local tw = 180
		local x = right - tw - 10
		local v = (SET[key] - min) / (max - min)
		local sx, sw = g.x + x * g.s, tw * g.s
		local id = "sl_" .. key
		local hot = hit.is(id) or (S.slide ~= nil and S.slide.key == key)
		g.num(600, 13, SET[key] .. "%", x - 18, cy, C.text2, a, "r")
		g.rect(x, cy - 2, tw, 4, C.fill2, 2, a)
		g.rect(x, cy - 2, tw * v, 4, C.blue, 2, a)
		Render.FilledCircle(g.v(x + tw * v, cy), (hot and 11 or 10) * g.s, g.col(C.text, a))
		hit.add(x - 12, cy - 14, tw + 24, 28, id, { down = function(mx)
			S.slide = { key = key, min = min, max = max, x = sx, w = sw }
			view.slide_to(mx)
		end })
	end
end

function view.slide_to(mx)
	local s = S.slide
	local v = clamp((mx - s.x) / s.w, 0, 1)
	SET[s.key] = s.min + math.floor((s.max - s.min) * v / 5 + 0.5) * 5
end

function view.stepper(right, cy, a)
	local x = right - 88
	g.rect(x, cy - 14, 88, 28, C.fill3, 8, a)
	local function btn(bx, glyph, delta, enabled, id)
		g.glyph(glyph, 13, bx + 15, cy, enabled and (hit.is(id) and C.text or C.text2) or C.text4, a)
		if enabled then
			hit.add(bx, cy - 14, 30, 28, id, { click = function()
				SET.count = clamp(SET.count + delta, 4, 16)
				save_settings()
			end })
		end
	end
	btn(x, "minus", -1, SET.count > 4, "cnt_minus")
	g.num(600, 13, tostring(SET.count), x + 44, cy, C.text, a, "c")
	btn(x + 58, "plus", 1, SET.count < 16, "cnt_plus")
end

function view.chevron(label, id)
	return function(right, cy, a)
		g.glyph("chevron", 12, right - 5, cy, hit.is(id) and C.text or C.text2, a)
		g.text(F(400), 13, label, right - 17, cy, hit.is(id) and C.text or C.text2, a, "r")
	end
end

function view.pool_short()
	local mode = SET.pool_mode == "only" and "dh_pool_short_only" or (SET.pool_mode == "off" and "dh_pool_short_off" or "dh_pool_short_boost")
	return heroes_n(#SET.pool) .. "  |  " .. L(mode)
end

function view.home(y, a)
	local h = 0
	local function open_pool() S.pool_ret, S.ret, S.view = "home", "home", "pool" end
	h = h + view.group_header(L("dh_h_train"), y + h, a)
	h = h + view.setting_rows({
		{ id = "tr_cm", tile = C.t_blue, glyph = "chess", title = "Captains Mode", sub = L("dh_h_cm_sub"), control = view.chevron(L("dh_start"), "tr_cm"), act = function() draft.start_training("cm") end },
		{ id = "tr_ap", tile = C.t_indigo, glyph = "users", title = "All Pick", sub = L("dh_h_ap_sub"), control = view.chevron(L("dh_start"), "tr_ap"), act = function() draft.start_training("ap") end },
	}, y + h, a)
	h = h + view.foot(L(SET.tr_enemy == "manual" and "dh_h_foot_manual" or "dh_h_foot_auto"), y + h, a) + 22
	if S.last then
		h = h + view.group_header(L("dh_h_last"), y + h, a)
		local sub = L(S.last.train and "dh_h_training" or "dh_h_match") .. "  |  " .. string.format(L("dh_h_last_chance"), math.floor(S.last.chance * 100 + 0.5))
		h = h + view.setting_rows({
			{ tile = S.last.chance >= 0.5 and C.t_green or C.red, glyph = "finish", title = S.last.mode == "ap" and "All Pick" or "Captains Mode", sub = sub },
			{ id = "home_builds", tile = C.t_purple, glyph = "bag", title = L("dh_b_row"), sub = L("dh_b_row_sub"), control = view.chevron(L("dh_open"), "home_builds"), act = build.open_team },
		}, y + h, a)
		h = h + view.foot(L("dh_h_last_foot"), y + h, a) + 22
	end
	h = h + view.group_header(L("dh_h_hints"), y + h, a)
	h = h + view.setting_rows({
		{ id = "home_pool", tile = C.t_orange, glyph = "star", title = L("dh_pool"), sub = view.pool_short(), control = view.chevron(L("dh_change"), "home_pool"), act = open_pool },
		{ id = "home_set", tile = C.t_gray, glyph = "gear", title = L("dh_settings"), sub = L("dh_settings_sub"), control = view.chevron(L("dh_open"), "home_set"), act = function() S.ret, S.view = "home", "set" end },
	}, y + h, a)
	return h
end

function view.data_line()
	local info = data.manifest and data.manifest.sets[draft.set_key()]
	if not info then
		local status = data.status()
		return L("dh_data_" .. ((status == "ok" or data.manifest) and "none" or status))
	end
	local n = tostring(info.n):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	local months = {}
	for m in L("dh_months"):gmatch("[^,]+") do months[#months + 1] = m end
	local a, b = os.date("*t", info.from), os.date("*t", info.to)
	local range = L(a.month == b.month and "dh_range_same" or "dh_range")
		:gsub("{d1}", a.day):gsub("{m1}", months[a.month]):gsub("{d2}", b.day):gsub("{m2}", months[b.month])
	return string.format(L("dh_data_ok"), n, plural(info.n, "dh_match"), range)
end

function view.update_line()
	local st = upd.state
	if st == "checking" then return L("dh_upd_checking") end
	if st == "available" then return string.format(L("dh_upd_available"), upd.latest) end
	if st == "loading" then return string.format(L("dh_upd_loading"), upd.latest) end
	if st == "done" then return L("dh_upd_done") end
	if st == "error" then return L("dh_upd_failed") end
	if upd.check_failed then return L("dh_upd_check_failed") end
	return upd.checked and L("dh_upd_latest") or nil
end

function view.update_tip(y)
	local line = view.update_line()
	if not line or not upd.error or not (upd.state == "error" or upd.check_failed) then return end
	hit.add(K.CX + 58, y + 25, g.width(F(400), 12, line), 18, "upd_error", {})
	if hit.is("upd_error") then S.tip = upd.error end
end

function view.update_button(right, cy, a)
	local st = upd.state
	if st == "checking" or st == "loading" then
		Render.Circle(g.v(right - 8, cy), 5.5 * g.s, g.col(C.text4, a), 1.5 * g.s)
		Render.Circle(g.v(right - 8, cy), 5.5 * g.s, g.col(C.text, a), 1.5 * g.s, (S.now * 400) % 360, 0.25, true)
		return
	end
	if st == "done" then
		g.text(F(500), 14, L("dh_upd_ready"), right, cy, C.green, a, "r")
		return
	end
	local label = L(st == "available" and "dh_upd_install" or (st == "error" and "dh_upd_retry" or "dh_upd_check"))
	local w = g.width(F(500), 14, label) + 24
	local x, on = right - w, hit.is("set_update")
	if st == "available" then
		g.rect(x, cy - 15, w, 30, C.blue, 8, a * (on and 0.85 or 1))
		g.text(F(500), 14, label, x + w / 2, cy, C.text, a, "c")
	else
		if on then g.rect(x, cy - 15, w, 30, { 10, 132, 255, 36 }, 8, a) end
		g.text(F(500), 14, label, x + w / 2, cy, st == "error" and C.red or C.blue, a, "c")
	end
	hit.add(x, cy - 15, w, 30, "set_update", { click = function()
		if st == "idle" then upd.check(true) else upd.install() end
	end })
end

function view.settings(y, a)
	local h = 0
	local ranks = {}
	for i = 1, 4 do ranks[i] = { i, L("dh_rank_" .. i) } end
	local function pick(key) return function(v) SET[key] = v; save_settings() end end
	h = h + view.group_header(L("dh_s_data"), y + h, a)
	local line = view.data_line()
	view.error_tip(K.CX + 58, y + h + 75, g.width(F(400), 12, line), 18)
	h = h + view.setting_rows({
		{ tile = C.t_blue, glyph = "users", title = L("dh_s_source"), control = view.choice("source", { { "ap", L("dh_source_ap") }, { "cm", "Captains Mode" } }, SET.source, pick("source")) },
		{ tile = C.t_indigo, glyph = "chart", title = L("dh_s_rank"), sub = line, control = view.choice("rank", ranks, SET.rank, pick("rank")) },
	}, y + h, a) + 22
	h = h + view.group_header(L("dh_s_hints"), y + h, a)
	h = h + view.setting_rows({
		{ id = "set_pool", tile = C.t_orange, glyph = "star", title = L("dh_pool"), sub = view.pool_short(), control = view.chevron(L("dh_change"), "set_pool"), act = function() S.pool_ret, S.view = "set", "pool" end },
		{ tile = C.t_blue, glyph = "list", title = L("dh_s_count"), control = view.stepper },
		{ tile = C.t_green, glyph = "flag", title = L("dh_s_goal"), sub = L("dh_s_goal_sub"), control = view.choice("goal", { { "draft", L("dh_goal_draft") }, { "lane", L("dh_goal_lane") } }, SET.goal, pick("goal")) },
		{ tile = C.t_teal, glyph = "comment", title = L("dh_s_reasons"), sub = L("dh_s_reasons_sub"), control = view.switch("reasons") },
		{ tile = C.t_green, glyph = "percent", title = L("dh_s_chance"), control = view.switch("chance") },
	}, y + h, a) + 22
	h = h + view.group_header(L("dh_s_pick"), y + h, a)
	h = h + view.setting_rows({
		{ tile = C.t_orange, glyph = "hand", title = L("dh_s_confirm"), sub = L("dh_s_confirm_sub"), control = view.switch("confirm") },
		{ tile = C.t_blue, glyph = "crown", title = L("dh_s_captain"), sub = L("dh_s_captain_sub"), control = view.switch("captain") },
	}, y + h, a) + 22
	h = h + view.group_header(L("dh_s_train"), y + h, a)
	h = h + view.setting_rows({
		{ tile = C.t_indigo, glyph = "robot", title = L("dh_s_enemy"), sub = L("dh_s_enemy_sub"), control = view.choice("tr_enemy", { { "auto", L("dh_s_enemy_auto") }, { "manual", L("dh_s_enemy_manual") } }, SET.tr_enemy, pick("tr_enemy")) },
		{ tile = C.t_green, glyph = "flag", title = L("dh_s_side"), control = view.choice("tr_side", { { "r", L("dh_s_light") }, { "d", L("dh_s_dark") } }, SET.tr_side, pick("tr_side")) },
		{ tile = C.t_orange, glyph = "hand", title = L("dh_s_first"), sub = L("dh_s_first_sub"), control = view.choice("tr_first", { { "us", L("dh_s_first_us") }, { "them", L("dh_s_first_them") } }, SET.tr_first, pick("tr_first")) },
	}, y + h, a)
	h = h + view.foot(L("dh_s_train_foot"), y + h, a) + 22
	h = h + view.group_header(L("dh_s_window"), y + h, a)
	h = h + view.setting_rows({
		{ tile = C.t_purple, glyph = "wand", title = L("dh_s_auto"), sub = L("dh_s_auto_sub"), control = view.switch("auto") },
		{ tile = C.t_blue, glyph = "pointer", title = L("dh_s_hover"), sub = L("dh_s_hover_sub"), control = view.switch("hints") },
		{ tile = C.t_cyan, glyph = "expand", title = L("dh_s_scale"), control = view.choice("scale", { { 90, "90%" }, { 100, "100%" }, { 110, "110%" } }, SET.scale, pick("scale")) },
		{ tile = C.t_indigo, glyph = "blur", title = L("dh_s_blur"), control = view.switch("blur") },
		SET.blur == 1 and { tile = C.t_indigo, glyph = "drop", title = L("dh_s_blur_power"), control = view.slider("blur_power", 10, 100) } or nil,
	}, y + h, a) + 22
	h = h + view.group_header(L("dh_s_debug"), y + h, a)
	h = h + view.setting_rows({
		{ tile = C.t_gray, glyph = "bug", title = L("dh_s_log"), sub = L("dh_s_log_sub"), control = view.switch("log") },
		{ tile = C.t_teal, glyph = "eye", title = L("dh_s_panel"), sub = L("dh_s_panel_sub"), control = view.switch("panel") },
	}, y + h, a) + 22
	h = h + view.group_header(L("dh_s_about"), y + h, a)
	view.update_tip(y + h)
	h = h + view.setting_rows({
		{ tile = C.t_gray, glyph = "info", title = string.format(L("dh_version"), K.VERSION), sub = view.update_line(), control = view.update_button },
	}, y + h, a) + 22
	g.rect(K.CX, y + h, K.CW, 48, C.card, 12, a)
	local kd = anim.hover("defaults", hit.is("defaults"))
	if kd > 0 then g.rect(K.CX, y + h, K.CW, 48, C.hover, 12, a * kd) end
	g.text(F(400), 14, L("dh_s_defaults"), K.CX + K.P, y + h + 24, C.red, a)
	hit.add(K.CX, y + h, K.CW, 48, "defaults", { click = function()
		local pool = SET.pool
		set_defaults()
		SET.pool = pool
		save_settings()
	end })
	return h + 48
end

function view.pool(y, a)
	local x, h = K.CX, 0
	local modes = { { "boost", L("dh_pool_boost") }, { "only", L("dh_pool_only") }, { "off", L("dh_pool_off") } }
	local choice = view.choice("pool_mode", modes, SET.pool_mode, function(v) SET.pool_mode = v; save_settings() end)
	local mw = 4
	for _, m in ipairs(modes) do mw = mw + g.width(F(500), 12, m[2]) + 22 end
	choice(x + mw, y + 14, a)
	if #SET.pool > 0 then
		local id = "pool_clear"
		g.text(F(400), 13, L("dh_pool_clear"), x + K.CW - 6, y + 14, hit.is(id) and C.text or C.blue, a, "r")
		hit.add(x + K.CW - 110, y, 110, 28, id, { click = function() SET.pool = {}; save_settings() end })
	end
	h = 48
	local status = data.status()
	if status ~= "ok" then return h + view.data_state(status, y + h, a) end
	local q = S.query:lower()
	local cols = math.floor((K.CW + 6) / 64)
	local start = h
	for _, attr in ipairs(K.ATTRS) do
		local list = {}
		for _, hero in ipairs(data.by_attr[attr]) do
			if q == "" or hero.name:lower():find(q, 1, true) then list[#list + 1] = hero end
		end
		if #list > 0 then
			local count = 0
			for _, hero in ipairs(list) do if in_pool(hero.h) then count = count + 1 end end
			local tw = g.text(F(700), 17, L("dh_attr_" .. attr), x, y + h + 10, C.text, a)
			g.text(F(400), 13, count > 0 and string.format(L("dh_pool_count"), count, #list) or tostring(#list), x + tw + 8, y + h + 11, C.text3, a)
			h = h + 30
			for n, hero in ipairs(list) do
				local px, py = x + ((n - 1) % cols) * 64, y + h + math.floor((n - 1) / cols) * 39
				local on, id = in_pool(hero.h), "pool:" .. hero.h
				local k = anim.tween(id, on and 1 or 0, 0.18)
				local hover = hit.is(id)
				g.image(asset.portrait(hero.h), px, py, 58, 33, 6, a * (hover and 0.85 or (0.5 + 0.5 * k)), (1 - k) * 0.65)
				if k > 0 then
					Render.FilledCircle(g.v(px + 50, py + 8), 8 * g.s, g.col(C.blue, a * k))
					g.glyph("check", 10, px + 50, py + 8, C.text, a * k)
				end
				hit.add(px, py, 58, 33, id, { click = function() toggle_pool(hero.h) end })
			end
			h = h + math.ceil(#list / cols) * 39 + 22
		end
	end
	if h == start then return h + view.text_block(L("dh_pool_none"), y + h + 20, a) + 20 end
	return h
end

function view.hero_tip(h, id, x, y, size, a, on_click)
	g.icon(asset.icon(h), x, y, size, C.text, a)
	hit.add(x, y, size, size, id, { click = on_click })
	if hit.is(id) then S.tip = data.heroes[h].name end
end

function view.live_panel()
	local screen = Render.ScreenSize()
	g.s = math.max(0.7, screen.y / 1080) * SET.scale / 100
	g.x, g.y, g.a = 20, math.floor(screen.y * 0.13), 1
	local d, kw, lh = live.d, 128, 20
	local v = live.view
	local key = tostring(live.trace) .. g.s
	if v.key ~= key then
		v.key, v.lines = key, {}
		v.w = d and 460 or g.width(F(400), 13, L("dh_d_none")) + 2 * K.P
		local rows = live.rows(d)
		if d then table.insert(rows, 1, { id = "mode", text = d.mode == "ap" and "All Pick" or "Captains Mode" }) end
		for _, row in ipairs(rows) do
			local label, line = L("dh_d_" .. row.id), ""
			for word in row.text:gmatch("%S+%s*") do
				if line ~= "" and g.width(F(400), 12, line .. word) > v.w - kw - 2 * K.P then
					v.lines[#v.lines + 1] = { label, line }
					label, line = "", ""
				end
				line = line .. word
			end
			v.lines[#v.lines + 1] = { label, line }
		end
	end
	local w, lines = v.w, v.lines
	local h = math.max(1, #lines) * lh + 20
	g.glass(0, 0, w, h, 12, 0.8)
	if not d then g.text(F(400), 13, L("dh_d_none"), K.P, h / 2, C.text2) end
	for i, line in ipairs(lines) do
		local cy = 10 + (i - 0.5) * lh
		g.text(F(500), 12, line[1], K.P, cy, C.text2)
		g.text(F(400), 12, line[2], K.P + kw, cy, C.text)
	end
	g.frame(0, 0, w, h, C.border, 12)
end

function view.tip()
	if S.tip ~= S.tip_shown then S.tip_shown, S.tip_since = S.tip, S.now end
	if not S.tip or S.menu then return end
	local k = clamp((S.now - S.tip_since - K.TIP_DELAY) / 0.12, 0, 1)
	if k <= 0 then return end
	local mx, my = Input.GetCursorPos()
	local cx, cy = (mx - g.x) / g.s, (my - g.y) / g.s
	local w = g.width(F(600), 12, S.tip) + 20
	local over = hit.at(mx, my)
	local top = over and (over[2] - g.y) / g.s or cy
	local bottom = over and (over[4] - g.y) / g.s or cy
	local y = math.max(bottom + 6, cy + 24)
	if y + 30 > K.H then y = math.min(top - 32, cy - 34) end
	local x = clamp(cx - w / 2, 4, K.W - w - 4)
	g.rect(x, y, w, 26, C.raised, 7, k)
	g.frame(x, y, w, 26, C.outline, 7, k)
	g.text(F(600), 12, S.tip, x + 10, y + 13, C.text, k)
end

function view.matchup(a, b)
	local st, ha, hb = draft.stats(), data.heroes[a], data.heroes[b]
	if not st or not ha or not hb or not ha.id or not hb.id then return 0 end
	return math.floor(calc.vs(st, ha.id, hb.id) * 250 + 0.5) / 10
end

function view.summary(y, a)
	local x, w = K.CX, K.CW
	local ours, theirs = build.team, build.slots(true)
	if #ours == 0 then return 0 end
	if not build.is_ours(S.bh) then S.bh = ours[1].h end
	table.sort(theirs, function(p, q) return (p.get() or 9) < (q.get() or 9) end)

	g.rect(x, y, w, 252, C.card, 12, a)
	local lw = g.text(F(700), 11, L("dh_b_who"), x + K.P, y + 17, C.text3, a)
	g.vr(x + K.P + lw + 9, y + 17, 11, a)
	g.text(F(400), 12, L("dh_b_who_sub"), x + K.P + lw + 18, y + 17, C.text3, a)
	local gx, gw = x + 8, w - 16
	local cw = (gw - 12 - 44 - 56 - 36) / 5
	local function col(n) return gx + 6 + 44 + 6 + (n - 1) * (cw + 6) end
	local tx = col(6)
	for n, e in ipairs(theirs) do
		view.hero_tip(e.h, "mt:" .. e.h, col(n) + cw / 2 - 13, y + 33, 26, a)
	end
	g.text(F(500), 11, L("dh_b_total"), tx + 28, y + 46, C.text3, a, "c")
	for n, e in ipairs(ours) do
		local ry = y + 62 + (n - 1) * 36
		local id, on = "mr:" .. e.h, e.h == S.bh
		local k = anim.hover(id, hit.is(id) or hit.is("mi:" .. e.h))
		if on then g.rect(gx, ry, gw, 34, C.fill3, 8, a) elseif k > 0 then g.rect(gx, ry, gw, 34, C.hover, 8, a * k) end
		local pick = function() S.bh = e.h end
		hit.add(gx, ry, gw, 34, id, { click = pick })
		view.hero_tip(e.h, "mi:" .. e.h, gx + 6 + 9, ry + 4, 26, a * ((on or k > 0) and 1 or 0.6), pick)
		local total = 0
		for m, t in ipairs(theirs) do
			local v = view.matchup(e.h, t.h)
			total = total + v
			local cx = col(m)
			if math.abs(v) >= 2 then
				local s = math.min(1, (math.abs(v) - 2) / 4)
				local c = v >= 0 and C.green or C.red
				g.rect(cx, ry + 2, cw, 30, { c[1], c[2], c[3], (0.14 + 0.16 * s) * 255 }, 6, a)
				g.num(600, 13, signed(v), cx + cw / 2, ry + 17, c, a, "c")
			else
				g.num(600, 13, signed(v), cx + cw / 2, ry + 17, C.text3, a, "c")
			end
		end
		g.num(700, 13, signed(total), tx + 28, ry + 17, total >= 0 and C.green or C.red, a, "c")
	end

	local by = y + 262
	g.rect(x, by, w, 120, C.card, 12, a)
	local bw = g.text(F(700), 11, L("dh_b_build"), x + K.P, by + 23, C.text3, a)
	g.text(F(700), 11, data.heroes[S.bh].name:upper(), x + K.P + bw + 6, by + 23, C.text2, a)
	g.text(F(500), 13, L("dh_b_dev"), x + w / 2, by + 72, C.text3, a, "c")
	return 382
end

function view.build(y, a)
	if not S.bh then return 0 end
	return view.summary(y, a)
end

function view.content()
	local top = view.no_head() and K.TB + 20 or ((S.view == "draft" and draft.positional() and S.query == "" and not S.reveal_at) and K.TB + 164 or K.TB + 112)
	local bottom = K.H
	local bar_on = S.sel ~= nil and S.view == "draft" and not draft.done()
	local step_key = table.concat({ S.env, tostring(S.train), S.mode, S.view, S.mode == "ap" and (#S.ap.ours .. "/" .. #S.ap.theirs) or tostring(draft.cm_n()), S.view == "build" and S.bh or "" }, ":")
	local key = step_key .. ":" .. S.filter
	if key ~= S.content_key then
		if step_key ~= S.step_key then
			S.scroll_to = 0
			anim.snap("scroll", 0)
		end
		S.content_key, S.step_key, S.fade_t = key, step_key, 0
	end
	S.fade_t = math.min(1, S.fade_t + S.dt / K.FADE)
	local a = 0.35 + 0.65 * ease_out(S.fade_t)
	local vh = bottom - top
	S.view_h = vh
	S.scroll = anim.tween("scroll", S.scroll_to, 0.24)
	hit.add(K.CX - 14, top, K.CW + 28, vh, "content", { wheel = function(dir)
		S.scroll_to = clamp(S.scroll_to + dir * K.WHEEL, 0, math.max(0, S.content_h - S.view_h))
		S.sb_until = S.now + 1.2
	end })
	g.clip(K.CX - 14, top, K.CW + 28, vh)
	hit.clip = { g.x + (K.CX - 14) * g.s, g.y + top * g.s, g.x + (K.CX + K.CW + 14) * g.s, g.y + bottom * g.s }
	local y = top - math.floor(S.scroll * g.s + 0.5) / g.s
	local h
	if S.view == "home" then h = view.home(y, a)
	elseif S.view == "set" then h = view.settings(y, a)
	elseif S.view == "pool" then h = view.pool(y, a)
	elseif S.view == "build" then h = view.build(y, a)
	else h = view.draft_content(y, a) end
	hit.clip = nil
	g.unclip()
	S.content_h = h + 26 + (bar_on and 82 or 0)
	local max_scroll = math.max(0, S.content_h - vh)
	S.scroll_to = clamp(S.scroll_to, 0, max_scroll)
	view.scrollbar(top, vh, max_scroll)
end

function view.scrollbar(top, vh, max_scroll)
	if max_scroll <= 0 then return end
	local x, y, h = K.W - 24, top + 6, vh - 26
	local th = math.max(32, h * h / S.content_h)
	local ty = y + (h - th) * clamp(S.scroll / max_scroll, 0, 1)
	local hover = hit.is("sb") or hit.is("sb_thumb") or S.sb_drag ~= nil
	local k = anim.tween("sb", (hover or S.now < S.sb_until) and 1 or 0, 0.2)
	local wide = anim.tween("sb_w", hover and 1 or 0, 0.15)
	if k > 0 then
		g.rect(x + 2, y, 8, h, { 255, 255, 255, 13 }, 4, k * wide)
		local w = 6 + 2 * wide
		g.rect(x + 10 - w, ty, w, th, hover and C.sb_hover or C.sb, w / 2, k)
	end
	hit.add(x, y, 12, h, "sb", { down = function(mx, my)
		local rel = (my - g.y) / g.s - y - th / 2
		S.scroll_to = clamp(rel / (h - th), 0, 1) * max_scroll
	end })
	hit.add(x, ty, 12, th, "sb_thumb", { down = function(mx, my)
		S.sb_drag = { my = my, scroll = S.scroll, k = max_scroll / math.max(1, h - th) }
	end })
end

function view.bar()
	local on = S.sel ~= nil and S.view == "draft" and not draft.done()
	local k = anim.tween("bar", on and 1 or 0, 0.2)
	if k <= 0.01 then return end
	local h = S.sel or S.bar_hero
	if not h then return end
	S.bar_hero = h
	local x, w, y = K.CX, K.CW, K.H - 92
	hit.add(x, y, w, 72, "bar", {})
	g.rect(x, y, w, 72, C.raised, 14, k)
	g.frame(x, y, w, 72, C.outline, 14, k)
	g.image(asset.portrait(h), x + K.P, y + K.P, 78, 44, 7, k)
	g.text(F(700), 15, data.heroes[h].name, x + 106, y + 27, C.text, k)
	local ban = draft.is_ban()
	local where = S.mode == "ap" and string.format(L("dh_at_round"), math.min(3, draft.ap_round())) or string.format(L("dh_at_step"), math.min(#K.ORDER, draft.cm_step()))
	local sx = x + 106 + g.text(F(400), 12, L(ban and "dh_ban_word" or "dh_pick_word") .. ", " .. where, x + 106, y + 47, C.text2, k)
	local p = draft.pos_for(h)
	if p then
		g.vr(sx + 8, y + 47, 13, k)
		g.icon(asset.pos(p), sx + 16, y + 39, 16, C.text2, k)
		g.text(F(400), 12, L("dh_pos_" .. p), sx + 37, y + 47, C.text2, k)
	end
	local function btn(label, hint, bx, primary, id, fn)
		local kw = g.width(F(600), 11, hint) + 12
		local bw = g.width(F(500), 14, label) + kw + 40
		bx = bx - bw
		g.rect(bx, y + 18, bw, 36, primary or C.fill2, 8, hit.is(id) and k * 0.9 or k)
		local tx = bx + 16 + g.text(F(500), 14, label, bx + 16, y + 36, C.text, k) + 8
		g.rect(tx, y + 27, kw, 18, C.key, 5, k)
		g.text(F(600), 11, hint, tx + kw / 2, y + 36, C.text, k, "c")
		hit.add(bx, y + 18, bw, 36, id, { click = fn })
		return bx
	end
	local bx = btn(L(ban and "dh_ban_btn" or "dh_select"), "Enter", x + w - K.P, ban and C.red or C.blue, "bar_ok", function() draft.commit(S.sel) end)
	btn(L("dh_cancel"), "Esc", bx - 8, nil, "bar_cancel", function() S.sel = nil end)
end

function view.open_pos_menu(key, x, y)
	S.menu = { kind = "pos", key = key, x = x + 8, y = y }
end

function view.open_ctx(h, mx, my)
	if draft.done() or S.reveal_at or draft.used()[h] or not draft.can_act() then return end
	S.menu = { kind = "ctx", h = h, x = (mx - g.x) / g.s + 2, y = (my - g.y) / g.s + 2 }
end

function view.menu()
	local m = S.menu
	if not m then return end
	if S.menu_seen ~= m then
		S.menu_seen = m
		for n = 1, 24 do anim.snap("hv:menu" .. n, 0) end
	end
	local items = {}
	local function item(label, icon, hint, fn, opts)
		items[#items + 1] = { label = label, icon = icon, hint = hint, fn = fn, opts = opts or {} }
	end
	local header
	if m.kind == "pos" then
		local info = draft.slot_info(m.key)
		header = { L("dh_pos_of") .. " ", data.heroes[info.h].name }
		for p = 1, 5 do
			local swap
			for _, x in ipairs(info.list) do
				if x.h ~= info.h and info.get(x) == p then swap = x.h end
			end
			item(L("dh_pos_" .. p), p, swap and string.format(L("dh_swap"), data.heroes[swap].name) or nil, function()
				draft.set_slot_pos(m.key, p)
			end, { check = info.p == p and not swap })
		end
		if build.is_ours(info.h) then
			items[#items + 1] = { sep = true }
			item(L("dh_b_m_build"), "bag", nil, function() build.open(info.h) end)
		end
	else
		local h, ban = m.h, draft.is_ban()
		header = { "", data.heroes[h].name }
		item(L(ban and "dh_ban_btn" or "dh_select"), ban and "ban" or "check", L("dh_m_dbl"), function() draft.commit(h) end, { danger = ban })
		if SET.confirm == 1 then item(L("dh_m_select"), "pointer", L("dh_m_click"), function() S.sel = h end) end
		item(L(in_pool(h) and "dh_m_pool_del" or "dh_m_pool_add"), "star", nil, function() toggle_pool(h) end)
		if not ban and (S.mode == "ap" or draft.cm_ours()) then
			local busy = draft.our_pos()
			items[#items + 1] = { sep = true }
			items[#items + 1] = { section = L("dh_m_on_pos") }
			for p = 1, 5 do
				item(L("dh_pos_" .. p), p, busy[p] and L("dh_m_taken") or nil, function() draft.commit(h, p) end, { disabled = busy[p] })
			end
		end
	end
	local w, h = 236, 36
	for _, it in ipairs(items) do h = h + (it.sep and 11 or (it.section and 22 or 32)) end
	local x = m.x
	if x + w > K.W - 8 then x = x - w - (m.kind == "pos" and 90 or 4) end
	local y = math.min(m.y, K.H - h - 8)
	hit.add(x, y, w, h, "menu", {})
	g.rect(x, y, w, h, C.raised, 12)
	g.frame(x, y, w, h, C.outline, 12)
	local hx = x + 14
	if header[1] ~= "" then hx = hx + g.text(F(400), 13, header[1], hx, y + 18, C.text3) end
	g.text(F(700), 13, header[2], hx, y + 18, C.text)
	local iy = y + 33
	for n, it in ipairs(items) do
		if it.sep then
			g.rect(x + 9, iy + 5, w - 18, 1, C.sep2)
			iy = iy + 11
		elseif it.section then
			g.text(F(600), 11, it.section, x + 14, iy + 11, C.text3)
			iy = iy + 22
		else
			local id = "menu" .. n
			local disabled = it.opts.disabled
			local a = disabled and 0.35 or 1
			local k = disabled and 0 or anim.hover(id, hit.is(id))
			if k > 0 then g.rect(x + 5, iy, w - 10, 32, it.opts.danger and C.red or C.blue, 7, k) end
			if type(it.icon) == "number" then g.icon(asset.pos(it.icon), x + 13, iy + 7, 18, C.text, a)
			else g.glyph(it.icon, 14, x + 22, iy + 16, C.text, a) end
			local lw = g.text(F(400), 13, it.label, x + 39, iy + 16, C.text, a)
			if it.hint then g.text(F(400), 11, g.fit(400, 11, it.hint, w - 14 - 39 - lw - 12), x + w - 14, iy + 16, hit.is(id) and C.text or C.text3, a, "r")
			elseif it.opts.check then g.glyph("check", 13, x + w - 21, iy + 16, C.text, a) end
			if not disabled then
				hit.add(x + 5, iy, w - 10, 32, id, { click = function()
					S.menu = nil
					it.fn()
				end })
			end
			iy = iy + 32
		end
	end
end

function view.window()
	local screen = Render.ScreenSize()
	g.s = math.max(0.7, screen.y / 1080) * SET.scale / 100
	if not S.wx then
		S.wx = Config.ReadInt(K.CFG, "wx", -1)
		S.wy = Config.ReadInt(K.CFG, "wy", -1)
		if S.wx < 0 then S.wx, S.wy = math.floor((screen.x - K.W * g.s) / 2), math.floor((screen.y - K.H * g.s) / 2) end
	end
	S.wx = clamp(S.wx, 0, math.max(0, screen.x - K.W * g.s))
	S.wy = clamp(S.wy, 0, math.max(0, screen.y - K.H * g.s))
	g.x, g.y, g.a = S.wx, S.wy, S.alpha
	hit.begin()
	build.frame()
	S.tip = nil
	if S.view ~= S.query_view then S.query, S.focus, S.query_view = "", false, S.view end
	S.ghost = nil
	if hit.hover and hit.hover:sub(1, 2) == "h:" and S.view == "draft" and draft.can_act() then S.ghost = hit.hover:sub(3) end
	hit.add(0, 0, K.W, K.H, "window", {})
	g.glass(0, 0, K.W, K.H, 16, 1)
	view.board()
	view.toolbar()
	if not view.no_head() then view.head() end
	if S.view == "draft" and draft.positional() and S.query == "" and not S.reveal_at then view.segment() end
	view.content()
	view.bar()
	view.menu()
	view.tip()
	g.frame(0, 0, K.W, K.H, C.border, 16)
end

local input = { swallow = false, held = {}, sink_on = false }

function input.sink(on, force)
	if input.sink_on == on and not force then return end
	input.sink_on = on
	Engine.RunScript(JS.SINK:format(on and "true" or "false"))
end

local CHARS = {}
for i = 0, 25 do
	local letter = string.char(65 + i)
	CHARS[Enum.ButtonCode["KEY_" .. letter]] = letter:lower()
end
for i = 0, 9 do CHARS[Enum.ButtonCode["KEY_" .. i]] = tostring(i) end
CHARS[Enum.ButtonCode.KEY_SPACE] = " "
CHARS[Enum.ButtonCode.KEY_MINUS] = "-"

local function inside(mx, my)
	return mx >= S.wx and my >= S.wy and mx < S.wx + K.W * g.s and my < S.wy + K.H * g.s
end

function input.press(mx, my, button)
	local h = hit.at(mx, my)
	if S.menu and not (h and h[5]:sub(1, 4) == "menu") then
		S.menu = nil
		if button == 1 then S.press = { id = false } end
		return
	end
	local id, on = h and h[5], h and h[6] or {}
	if id ~= "search" and id ~= "search_clear" then S.focus = false end
	if button == 2 then
		if on.rclick then on.rclick(mx, my) end
		return
	end
	S.press = { id = id or false, on = on }
	if on.down then on.down(mx, my) end
end

function input.release(mx, my)
	local press = S.press
	S.press = nil
	if not press or not press.id then return end
	local h = hit.at(mx, my)
	if not h or h[5] ~= press.id then return end
	local on = press.on
	if on.dbl and S.last_click.id == press.id and S.now - S.last_click.t < K.DOUBLE_CLICK then
		S.last_click.id = nil
		on.dbl()
		return
	end
	S.last_click.id, S.last_click.t = press.id, S.now
	if on.click then on.click(mx, my) end
end

function input.end_drag()
	if S.drag then
		Config.WriteInt(K.CFG, "wx", math.floor(S.wx))
		Config.WriteInt(K.CFG, "wy", math.floor(S.wy))
	end
	if S.slide then save_settings() end
	S.drag, S.sb_drag, S.slide = nil, nil, nil
end

function input.key(key)
	if S.focus then
		if key == Enum.ButtonCode.KEY_BACKSPACE then
			S.query = S.query:sub(1, -2)
		elseif key == Enum.ButtonCode.KEY_ESCAPE then
			S.query, S.focus = "", false
		elseif key == Enum.ButtonCode.KEY_ENTER then
			if S.sel then
				draft.commit(S.sel)
			elseif S.view == "draft" and S.query ~= "" then
				local used, q = draft.used(), S.query:lower()
				for _, hero in ipairs(data.list) do
					if not used[hero.h] and hero.name:lower():find(q, 1, true) then
						draft.place(hero.h)
						break
					end
				end
			end
		elseif CHARS[key] and #S.query < 24 then
			S.query = S.query .. CHARS[key]
		else
			return false
		end
		return true
	end
	local ctrl = Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) or Input.IsKeyDown(Enum.ButtonCode.KEY_RCONTROL)
	if key == Enum.ButtonCode.KEY_ESCAPE and S.menu then
		S.menu = nil
	elseif key == Enum.ButtonCode.KEY_ESCAPE and S.sel then
		S.sel = nil
	elseif key == Enum.ButtonCode.KEY_ENTER and S.sel then
		draft.commit(S.sel)
	elseif ctrl and key == Enum.ButtonCode.KEY_Z then
		draft.undo()
	elseif ctrl and key == Enum.ButtonCode.KEY_F and not draft.home_board() and S.view ~= "build" then
		S.focus = true
	else
		return false
	end
	return true
end

local script = {}

function script.OnUpdateEx()
	if not ui.enable:Get() then return end
	data.tick()
	upd.tick()
	live.tick()
	if ui.key:IsPressed() and not Input.IsInputCaptured() and not S.focus then S.open = not S.open end
end

function script.OnFrame()
	if not ui.enable:Get() then return end
	local now = os.clock()
	local frame = GlobalVars.GetAbsFrameTime()
	S.dt = clamp(frame > 0 and frame or (now - (S.now > 0 and S.now or now)), 0, 0.1)
	S.now = now
	S.alpha = anim.tween("window", S.open and 1 or 0, 0.18)
	if SET.panel == 1 then view.live_panel() end
	input.sink(S.focus and S.open)
	if S.alpha <= 0 then return end
	if not S.started then
		S.started = true
		draft.set_env("home")
	end
	if S.press and not Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
		input.end_drag()
		S.press = nil
	end
	for key in pairs(input.held) do
		if not Input.IsKeyDown(key, true) then input.held[key] = nil end
	end
	local mx, my = Input.GetCursorPos()
	if S.drag then
		S.wx, S.wy = S.drag.wx + mx - S.drag.mx, S.drag.wy + my - S.drag.my
	end
	if S.slide then view.slide_to(mx) end
	if S.sb_drag then
		S.scroll_to = clamp(S.sb_drag.scroll + (my - S.sb_drag.my) * S.sb_drag.k, 0, math.max(0, S.content_h - S.view_h))
		anim.snap("scroll", S.scroll_to)
		S.sb_until = S.now + 1.2
	end
	draft.tick()
	view.window()
end

function script.OnKeyEvent(e)
	if not ui.enable:Get() or S.alpha <= 0 or not S.started then return true end
	local mx, my = Input.GetCursorPos()
	local over = inside(mx, my) or S.menu ~= nil
	if e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP or e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN then
		if not inside(mx, my) then return true end
		local content = nil
		for i = #hit.list, 1, -1 do
			if hit.list[i][5] == "content" then content = hit.list[i] break end
		end
		if content and mx >= content[1] and mx < content[3] and my >= content[2] and my < content[4] then
			content[6].wheel(e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN and 1 or -1)
		end
		return false
	end
	if e.key == Enum.ButtonCode.KEY_MOUSE1 or e.key == Enum.ButtonCode.KEY_MOUSE2 then
		local left = e.key == Enum.ButtonCode.KEY_MOUSE1
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			if input.held[e.key] then return not input.swallow end
			input.held[e.key] = true
			if not over then
				S.focus = false
				if left then S.press = { id = false } end
				return true
			end
			input.swallow = true
			input.press(mx, my, left and 1 or 2)
			return false
		elseif e.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
			input.held[e.key] = nil
			if left then
				input.end_drag()
				input.release(mx, my)
			end
			if input.swallow then
				input.swallow = false
				return false
			end
		end
		return true
	end
	if S.focus then
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			input.sink(true, true)
			input.key(e.key)
		end
		return false
	end
	if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and not Input.IsInputCaptured() and over then
		if input.key(e.key) then return false end
	end
	return true
end

ui.enable:SetCallback(function()
	local on = ui.enable:Get()
	ui.key:Disabled(not on)
	if not on then
		S.open, S.focus = false, false
		input.sink(false)
	end
end, true)

return script
