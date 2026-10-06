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
		dh_news = "What's new",
		dh_news_sub = "Changes in this update",
		dh_news_row_sub = "Changes in the latest update",
		dh_cl_b5fps_t = "Higher FPS",
		dh_cl_b5fps_d = "The window costs far less FPS, most of all in Captains Mode. With the window closed the script barely touches the game. Fixed an error in ranked All Pick.",
		dh_cl_b4fix_t = "Position stays",
		dh_cl_b4fix_d = "The chosen position no longer jumps back to Auto after someone else picks. It resets only once your team takes it.",
		dh_cl_b2fix_t = "Fixes",
		dh_cl_b2fix_d = "Minor changes and bug fixes.",
		dh_cl_resize_t = "Resize by the corner",
		dh_cl_resize_d = "Drag the corner at the bottom right of the window or the build panel to scale it. Fixed size options are gone.",
		dh_cl_keep_t = "The draft stays after the match starts",
		dh_cl_keep_d = "The draft is tied to the lobby while you pick, so it is no longer lost when scripts reload at the start of the match.",
		dh_cl_items_t = "Cleaner answers",
		dh_cl_items_d = "Sentries are now suggested to supports only.",
		dh_cl_builds_t = "Item builds",
		dh_cl_builds_d = "A build for your hero and role from 7000+ MMR games: starting items, then early, mid and late game.",
		dh_cl_counter_t = "Answers to their draft",
		dh_cl_counter_d = "The build adapts to enemy heroes and their items in the match: Skadi against healing, Nullifier against saves, Dust against invisibility.",
		dh_cl_panel_t = "Build panel",
		dh_cl_panel_d = "Opens with the shop. Left click pins an item to quick buy, Shift + left click replaces quick buy, right click buys. Switch the role in the header, drag the panel by it.",
		dh_cl_set_t = "Settings",
		dh_cl_set_d = "A new Build panel group, dependent options unfold smoothly, up to 25 heroes in the list.",
		dh_cl_cache_t = "One cache file",
		dh_cl_cache_d = "All downloaded data now lives in draft_helper_v2.dat instead of a dozen files in configs. Old files move there by themselves.",
		dh_cl_fix_t = "Fixes",
		dh_cl_fix_d = "Enemy positions in training no longer repeat.",
		dh_bp = "Build panel",
		dh_bp_tip = "Small item list for your hero next to the shop",
		dh_bp_early = "Early",
		dh_bp_mid = "Mid",
		dh_bp_late = "Late",
		dh_bp_show = "Show",
		dh_bp_show_shop = "With shop",
		dh_bp_show_always = "Always",
		dh_bp_all = "All settings",
		dh_bp_pinned = "In quick buy",
		dh_s_debug = "Debug",
		dh_s_log = "Logging",
		dh_s_log_sub = "Writes events to debug.log",
		dh_s_panel = "Draft panel",
		dh_s_panel_sub = "Shows the draft state on screen",
		dh_d_mode = "Mode",
		dh_d_none = "No draft right now",
		dh_d_yes = "yes",
		dh_d_no = "no",
		dh_d_me = "you",
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
		dh_h_clear = "Clear the board",
		dh_h_clear_sub = "Remove this training from the board",
		dh_clear = "Clear",
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
		dh_upd_bad_version = "downloaded version %s instead of %s",
		dh_upd_bad_manifest = "broken version.json",
		dh_upd_write = "could not write the file",

		dh_b_row = "Item builds",
		dh_b_row_sub = "For our team, vs this draft",
		dh_b_who = "WHO BEATS WHO",
		dh_b_who_sub = "% to win chance, ours vs theirs",
		dh_b_total = "total",
		dh_b_build = "BUILD",
		dh_b_m_build = "Item build",
		dh_b_start = "Start",
		dh_b_stage1 = "Early game",
		dh_b_stage2 = "Mid game",
		dh_b_stage3 = "Late game",
		dh_b_no_role = "No build for this role",
		dh_b_or = "or %s",
		dh_b_counter = "FOR THEIR DRAFT",
		dh_b_counter_none = "No special answers needed",
		dh_b_data_none = "Item builds are not on GitHub yet",
		dh_b_no_hero = "No item data for this hero yet",
		dh_t_heal = "Healing and regen",
		dh_t_save = "Dispellable saves",
		dh_t_evasion = "Evasion",
		dh_t_invis = "Invisibility",
		dh_t_units = "Illusions and units",
		dh_t_passive = "Strong passives",
		dh_t_target = "Targeted disables",
		dh_t_silence = "Silences and roots",
		dh_t_escape = "Elusive heroes",
		dh_t_magic = "Lots of magic damage",
		dh_t_phys = "Lots of physical damage",
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
		dh_news = "Что нового",
		dh_news_sub = "Что изменилось в обновлении",
		dh_news_row_sub = "Изменения последнего обновления",
		dh_cl_b5fps_t = "Выше FPS",
		dh_cl_b5fps_d = "Окно отнимает гораздо меньше FPS, особенно в Captains Mode. С закрытым окном скрипт почти не нагружает игру. Исправлена ошибка в рейтинговом All Pick.",
		dh_cl_b4fix_t = "Позиция не сбрасывается",
		dh_cl_b4fix_d = "Выбранная позиция больше не прыгает на «Авто» после чужого пика. Она сбрасывается, только когда её заняла твоя команда.",
		dh_cl_b2fix_t = "Исправления",
		dh_cl_b2fix_d = "Мелкие изменения и исправления ошибок.",
		dh_cl_resize_t = "Размер за уголок",
		dh_cl_resize_d = "Потяни уголок справа внизу окна или панели сборки, чтобы изменить размер. Фиксированные варианты размера убраны.",
		dh_cl_keep_t = "Драфт не теряется после начала матча",
		dh_cl_keep_d = "Драфт привязывается к лобби ещё во время пиков, поэтому больше не пропадает, когда скрипты перезагружаются на старте матча.",
		dh_cl_items_t = "Точнее ответы на драфт",
		dh_cl_items_d = "Сентри теперь советуются только саппортам.",
		dh_cl_builds_t = "Сборки предметов",
		dh_cl_builds_d = "Сборка под твоего героя и роль по играм 7000+ MMR: стартовый закуп, ранняя игра, середина и поздняя.",
		dh_cl_counter_t = "Ответы на их драфт",
		dh_cl_counter_d = "Сборка подстраивается под вражеских героев и их предметы в матче: скади против лечения, нуллифаер против сейвов, дасты против невидимости.",
		dh_cl_panel_t = "Панель сборки",
		dh_cl_panel_d = "Открывается вместе с магазином. ЛКМ закрепляет предмет в квикбае, Shift + ЛКМ заменяет квикбай, ПКМ покупает. Роль переключается в шапке, за неё же панель перетаскивается.",
		dh_cl_set_t = "Настройки",
		dh_cl_set_d = "Новая группа «Панель сборки», зависимые настройки раскрываются плавно, до 25 героев в списке.",
		dh_cl_cache_t = "Один файл кэша",
		dh_cl_cache_d = "Все скачанные данные теперь лежат в draft_helper_v2.dat вместо десятка файлов в configs. Старые файлы переносятся сами.",
		dh_cl_fix_t = "Исправления",
		dh_cl_fix_d = "Позиции врагов в тренировке больше не повторяются.",
		dh_bp = "Панель сборки",
		dh_bp_tip = "Маленький список предметов твоего героя у магазина",
		dh_bp_early = "Ранняя",
		dh_bp_mid = "Середина",
		dh_bp_late = "Поздняя",
		dh_bp_show = "Показывать",
		dh_bp_show_shop = "С магазином",
		dh_bp_show_always = "Всегда",
		dh_bp_all = "Все настройки",
		dh_bp_pinned = "В квикбае",
		dh_s_debug = "Отладка",
		dh_s_log = "Журнал",
		dh_s_log_sub = "Записывает события в debug.log",
		dh_s_panel = "Панель драфта",
		dh_s_panel_sub = "Показывает состояние драфта на экране",
		dh_d_mode = "Режим",
		dh_d_none = "Драфта сейчас нет",
		dh_d_yes = "да",
		dh_d_no = "нет",
		dh_d_me = "вы",
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
		dh_h_clear = "Очистить доску",
		dh_h_clear_sub = "Убрать эту тренировку с доски",
		dh_clear = "Очистить",
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
		dh_upd_bad_version = "скачалась версия %s вместо %s",
		dh_upd_bad_manifest = "битый version.json",
		dh_upd_write = "не удалось записать файл",

		dh_b_row = "Сборки предметов",
		dh_b_row_sub = "На нашу команду, под этот драфт",
		dh_b_who = "КТО КОГО",
		dh_b_who_sub = "% к шансу победы, наши против их",
		dh_b_total = "итог",
		dh_b_build = "СБОРКА",
		dh_b_m_build = "Сборка предметов",
		dh_b_start = "Старт",
		dh_b_stage1 = "Ранняя игра",
		dh_b_stage2 = "Середина",
		dh_b_stage3 = "Поздняя игра",
		dh_b_no_role = "Для этой роли сборки нет",
		dh_b_or = "или %s",
		dh_b_counter = "ПОД ИХ ДРАФТ",
		dh_b_counter_none = "Особых ответов не нужно",
		dh_b_data_none = "Сборок на GitHub пока нет",
		dh_b_no_hero = "По этому герою данных о предметах пока нет",
		dh_t_heal = "Лечение и реген",
		dh_t_save = "Сейвы, которые снимаются",
		dh_t_evasion = "Уклонение",
		dh_t_invis = "Невидимость",
		dh_t_units = "Иллюзии и юниты",
		dh_t_passive = "Сильные пассивки",
		dh_t_target = "Точечный контроль",
		dh_t_silence = "Сайленсы и руты",
		dh_t_escape = "Неуловимые герои",
		dh_t_magic = "Много магического урона",
		dh_t_phys = "Много физического урона",
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
	VERSION = "2.0.0-beta.5",
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
		arrow_down = "\u{f063}", alert = "\u{f06a}", info = "\u{f05a}", pin = "\u{f08d}",
		shield = "\u{f3ed}", wrench = "\u{f0ad}", store = "\u{f54e}", gift = "\u{f06b}",
	},

	NEWS = {
		{
			v = "2.0.0-beta.5",
			items = {
				{ key = "dh_cl_b5fps", glyph = "chart", tile = "t_green" },
			},
		},
		{
			v = "2.0.0-beta.4",
			items = {
				{ key = "dh_cl_b4fix", glyph = "wrench", tile = "t_green" },
			},
		},
		{
			v = "2.0.0-beta.2",
			items = {
				{ key = "dh_cl_b2fix", glyph = "wrench", tile = "t_green" },
			},
		},
		{
			v = "2.0.0-beta.1",
			items = {
				{ key = "dh_cl_resize", glyph = "expand", tile = "t_cyan" },
				{ key = "dh_cl_keep", glyph = "flag", tile = "t_green" },
				{ key = "dh_cl_items", glyph = "shield", tile = "red", icons = { "dust", "ward_sentry" } },
			},
		},
		{
			v = "2.0.0-alpha.10",
			items = {
				{ key = "dh_cl_builds", glyph = "bag", tile = "t_purple", icons = { "magic_wand", "power_treads", "bfury", "manta", "butterfly", "skadi" } },
				{ key = "dh_cl_counter", glyph = "shield", tile = "red", icons = { "skadi", "nullifier", "dust", "black_king_bar" } },
				{ key = "dh_cl_panel", glyph = "store", tile = "t_blue", roles = true },
				{ key = "dh_cl_set", glyph = "gear", tile = "t_gray" },
				{ key = "dh_cl_cache", glyph = "drop", tile = "t_teal" },
				{ key = "dh_cl_fix", glyph = "wrench", tile = "t_green" },
			},
		},
	},
	ENEMY_DELAY = 1.5,
	REVEAL_DELAY = 0.7,
	FADE = 0.2,
	DOUBLE_CLICK = 0.35,
	WHEEL = 112,
	BOOST = 2.5,
	GLASS = 0.3,
	SINK_ALIVE = 0.4,
	SINK_TIMEOUT = 1500,
	TIP_DELAY = 0.35,
	SCALE_MIN = 70,
	SCALE_MAX = 160,
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
		source = "cm",
		captain = 0,
		log = 0,
		panel = 0,
		blur = 0,
		blur_power = 50,
		hints = 1,
		bp = 1,
		bp_scale = 100,
		bp_show = "shop",
	},
	LIVE_READ = 0.1,
	LIVE_IDLE = 0.5,
	LIVE_CAPTAIN = 0.1,
	LIVE_GRID = 0.3,
	LIVE_GRID_HEROES = 2,
	LANE_BITS = { [1] = 1, [2] = 3, [4] = 2, [8] = 4, [16] = 5 },
	RANKED = { [7] = true, COMPETITIVE_MATCH = true },
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

local ITEM = {
	POS_MIN = 100,
	FILL = 0.25,
	AGHS = 0.3,
	FOLD_GAP = 10,
	EARLY = 12,
	MID = 25,
	LATE = 30,
	POOL = 0.05,
	COUNTERS = 4,
	CAP = 1.5,
	INV_READ = 1,
	ICON = "panorama/images/items/%s_png.vtex_c",
	SCEPTER = "ultimate_scepter",
	SHARD = "aghanims_shard",
	THRESHOLD = { magic = 2, phys = 2 },
	ORDER = { "heal", "save", "evasion", "invis", "units", "passive", "target", "silence", "escape", "magic", "phys" },
	ANSWERS = {
		heal = { "skadi", "spirit_vessel" },
		save = { "nullifier" },
		evasion = { "monkey_king_bar", "bloodthorn" },
		invis = { "dust", "ward_sentry", "gem" },
		units = { "mjollnir", "bfury", "maelstrom", "radiance", "shivas_guard" },
		passive = { "silver_edge" },
		target = { "sphere", "lotus_orb" },
		silence = { "manta", "lotus_orb", "cyclone", "black_king_bar" },
		escape = { "orchid", "bloodthorn", "rod_of_atos", "gungir", "sheepstick", "abyssal_blade" },
		magic = { "black_king_bar", "pipe", "glimmer_cape" },
		phys = { "ghost", "force_staff", "solar_crest", "shivas_guard", "assault", "crimson_guard", "heavens_halberd", "blade_mail", "butterfly" },
	},
	CONSUMABLES = { dust = { 1, 2, 3, 4, 5 }, ward_sentry = { 4, 5 } },
	ENEMY = {
		heart = "heal", satanic = "heal", bloodstone = "heal=0.5", vladmir = "heal=0.5", holy_locket = "heal=0.5",
		mekansm = "heal=0.5", guardian_greaves = "heal=0.5", mask_of_madness = "heal=0.5",
		ghost = "save", glimmer_cape = "save invis=0.5", aeon_disk = "save", wind_waker = "save", cyclone = "save=0.5",
		ethereal_blade = "save=0.5", solar_crest = "save=0.5",
		butterfly = "evasion", talisman_of_evasion = "evasion=0.5",
		invis_sword = "invis", silver_edge = "invis", shadow_amulet = "invis=0.5",
		manta = "units=0.5",
		orchid = "silence=0.5", bloodthorn = "silence", rod_of_atos = "silence=0.5", gungir = "silence=0.5", heavens_halberd = "silence=0.5",
		sheepstick = "target", abyssal_blade = "target=0.5",
	},
	HEROES = {
		antimage = "escape:antimage_blink phys=0.5",
		axe = "passive=0.5:axe_counter_helix",
		bane = "target:bane_fiends_grip magic=0.5",
		bloodseeker = "heal=0.5:bloodseeker_sanguivore target=0.5:bloodseeker_rupture phys=0.5",
		crystal_maiden = "magic silence=0.5:crystal_maiden_frostbite",
		drow_ranger = "phys silence=0.5:drow_ranger_wave_of_silence",
		earthshaker = "magic",
		juggernaut = "phys heal=0.5:juggernaut_healing_ward",
		mirana = "magic=0.5 escape=0.5:mirana_leap invis=0.5:mirana_invis",
		nevermore = "phys magic=0.5",
		morphling = "escape:morphling_waveform phys=0.5 magic=0.5",
		phantom_lancer = "units:phantom_lancer_juxtapose phys",
		puck = "escape:puck_phase_shift magic silence=0.5:puck_waning_rift",
		pudge = "target:pudge_dismember heal=0.5:pudge_dismember magic=0.5",
		razor = "phys",
		sand_king = "magic invis=0.5:sandking_sand_storm",
		storm_spirit = "escape:storm_spirit_ball_lightning magic",
		sven = "phys",
		tiny = "phys=0.5 magic=0.5",
		vengefulspirit = "phys=0.5",
		windrunner = "evasion:windrunner_windrun save=0.5:windrunner_windrun escape=0.5:windrunner_windrun phys=0.5",
		zuus = "magic",
		kunkka = "phys=0.5 magic=0.5",
		lina = "magic target=0.5:lina_laguna_blade",
		lich = "magic",
		lion = "magic target:lion_voodoo",
		shadow_shaman = "target:shadow_shaman_shackles magic=0.5",
		slardar = "phys passive:slardar_bash",
		tidehunter = "passive=0.5:tidehunter_kraken_shell magic=0.5",
		witch_doctor = "magic heal=0.5:witch_doctor_voodoo_restoration",
		riki = "invis:riki_backstab passive=0.5:riki_backstab phys silence=0.5:riki_smoke_screen",
		enigma = "units=0.5:enigma_demonic_conversion magic",
		tinker = "magic",
		sniper = "phys",
		necrolyte = "heal:necrolyte_death_pulse save:necrolyte_ghost_shroud magic",
		warlock = "units=0.5:warlock_rain_of_chaos heal=0.5:warlock_shadow_word magic",
		beastmaster = "target:beastmaster_primal_roar units=0.5:beastmaster_summon_raptor phys=0.5",
		queenofpain = "escape:queenofpain_blink magic",
		venomancer = "magic units=0.5:venomancer_plague_ward",
		faceless_void = "phys passive=0.5:faceless_void_time_lock escape=0.5:faceless_void_time_walk",
		skeleton_king = "phys heal:skeleton_king_vampiric_spirit",
		death_prophet = "magic silence:death_prophet_silence heal=0.5:death_prophet_spirit_siphon",
		phantom_assassin = "phys evasion:phantom_assassin_immaterial passive:phantom_assassin_coup_de_grace",
		pugna = "magic heal=0.5:pugna_life_drain save=0.5:pugna_decrepify",
		templar_assassin = "phys invis=0.5:templar_assassin_meld",
		viper = "magic=0.5 phys=0.5 target=0.5:viper_viper_strike",
		luna = "phys magic=0.5",
		dragon_knight = "phys=0.5 heal=0.5:dragon_knight_dragon_blood passive=0.5:dragon_knight_dragon_blood",
		dazzle = "heal:dazzle_shadow_wave",
		rattletrap = "magic=0.5 target=0.5:rattletrap_hookshot",
		leshrac = "magic",
		furion = "units:furion_force_of_nature magic=0.5",
		life_stealer = "phys heal:life_stealer_feast",
		dark_seer = "units=0.5:dark_seer_wall_of_replica magic=0.5",
		clinkz = "phys invis:clinkz_wind_walk",
		omniknight = "heal:omniknight_purification magic=0.5",
		enchantress = "heal:enchantress_natures_attendants phys=0.5 units=0.5:enchantress_enchant",
		huskar = "heal:huskar_berserkers_blood passive:huskar_berserkers_blood magic=0.5",
		night_stalker = "phys silence:night_stalker_crippling_fear",
		broodmother = "units:broodmother_spawn_spiderlings heal=0.5:broodmother_insatiable_hunger phys=0.5",
		bounty_hunter = "invis:bounty_hunter_wind_walk phys=0.5",
		weaver = "invis:weaver_shukuchi escape:weaver_time_lapse phys",
		jakiro = "magic",
		batrider = "target:batrider_flaming_lasso magic=0.5",
		chen = "units:chen_holy_persuasion heal=0.5:chen_hand_of_god",
		spectre = "phys passive:spectre_dispersion units=0.5:spectre_haunt",
		doom_bringer = "target:doom_bringer_doom magic=0.5",
		ancient_apparition = "magic",
		ursa = "phys passive:ursa_fury_swipes",
		spirit_breaker = "passive=0.5:spirit_breaker_greater_bash phys=0.5 target=0.5:spirit_breaker_nether_strike",
		gyrocopter = "phys magic=0.5",
		alchemist = "heal:alchemist_chemical_rage phys",
		invoker = "magic invis=0.5:invoker_ghost_walk",
		silencer = "magic silence:silencer_global_silence",
		obsidian_destroyer = "magic",
		lycan = "units:lycan_summon_wolves phys",
		brewmaster = "phys=0.5 magic=0.5 evasion=0.5:brewmaster_drunken_brawler",
		shadow_demon = "magic=0.5 target=0.5:shadow_demon_disruption",
		lone_druid = "units:lone_druid_spirit_bear phys",
		chaos_knight = "units:chaos_knight_phantasm phys",
		meepo = "units:meepo_divided_we_stand phys=0.5 magic=0.5",
		treant = "heal:treant_living_armor invis=0.5:treant_natures_guise silence=0.5:treant_overgrowth",
		ogre_magi = "magic",
		undying = "heal=0.5:undying_soul_rip units=0.5:undying_tombstone magic=0.5",
		rubick = "magic=0.5 target=0.5:rubick_telekinesis",
		disruptor = "magic",
		nyx_assassin = "magic invis:nyx_assassin_vendetta",
		naga_siren = "units:naga_siren_mirror_image phys silence=0.5:naga_siren_ensnare",
		keeper_of_the_light = "magic",
		wisp = "heal:wisp_tether",
		visage = "units:visage_summon_familiars magic=0.5",
		slark = "phys escape:slark_shadow_dance heal:slark_shadow_dance passive=0.5:slark_essence_shift",
		medusa = "phys magic=0.5",
		troll_warlord = "phys passive=0.5:troll_warlord_fervor",
		centaur = "magic=0.5",
		magnataur = "phys=0.5 magic=0.5",
		shredder = "magic heal=0.5:shredder_reactive_armor passive=0.5:shredder_reactive_armor",
		bristleback = "passive:bristleback_bristleback phys=0.5",
		tusk = "phys=0.5",
		skywrath_mage = "magic silence:skywrath_mage_ancient_seal",
		abaddon = "heal:abaddon_borrowed_time save=0.5:abaddon_aphotic_shield",
		elder_titan = "magic=0.5",
		legion_commander = "target:legion_commander_duel phys=0.5 heal=0.5:legion_commander_press_the_attack",
		ember_spirit = "escape:ember_spirit_fire_remnant phys=0.5 magic=0.5 silence=0.5:ember_spirit_searing_chains",
		earth_spirit = "escape=0.5:earth_spirit_rolling_boulder magic",
		terrorblade = "units:terrorblade_conjure_image phys",
		phoenix = "magic heal=0.5:phoenix_supernova escape=0.5:phoenix_icarus_dive",
		oracle = "heal:oracle_purifying_flames magic=0.5",
		techies = "magic",
		winter_wyvern = "heal=0.5:winter_wyvern_cold_embrace magic",
		arc_warden = "phys units=0.5:arc_warden_tempest_double",
		abyssal_underlord = "magic=0.5",
		monkey_king = "phys escape=0.5:monkey_king_tree_dance",
		pangolier = "escape:pangolier_gyroshell magic=0.5 phys=0.5",
		dark_willow = "magic escape=0.5:dark_willow_shadow_realm silence=0.5:dark_willow_bramble_maze",
		grimstroke = "magic silence=0.5:grimstroke_ink_creature target=0.5:grimstroke_soul_chain",
		mars = "phys=0.5 magic=0.5",
		void_spirit = "escape:void_spirit_astral_step magic",
		snapfire = "magic",
		hoodwink = "phys=0.5 magic=0.5 escape=0.5:hoodwink_scurry",
		dawnbreaker = "heal=0.5:dawnbreaker_solar_guardian phys=0.5",
		marci = "phys heal=0.5:marci_bodyguard",
		primal_beast = "target:primal_beast_pulverize magic=0.5",
		muerta = "magic",
		ringmaster = "magic=0.5",
		kez = "phys escape:kez_grappling_claw",
		largo = "magic=0.5",
	},
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
	let sink = root.FindChild('TextInputProxy');
	const drop = () => {
		sink.text = '';
		sink.DeleteAsync(0);
	};
	if (%s) {
		if (!sink) {
			sink = $.CreatePanel('TextEntry', root, 'TextInputProxy');
			sink.style.width = '1px';
			sink.style.height = '1px';
			sink.style.opacity = '0';
			sink.hittest = false;
			const watch = () => {
				if (!sink.IsValid()) return;
				if (Date.now() - Number(sink.GetAttributeString('alive', '0')) > %d) return drop();
				$.Schedule(0.25, watch);
			};
			$.Schedule(0.25, watch);
		}
		sink.SetAttributeString('alive', String(Date.now()));
		sink.text = '';
		sink.SetFocus();
	} else if (sink) {
		drop();
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
	t_green = { 48, 209, 88 }, t_purple = { 191, 90, 242 }, t_cyan = { 100, 210, 255 }, pill = { 58, 58, 60 },
}

local ROUND = Enum.DrawFlags.RoundCornersAll

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function ease_out(t) return 1 - (1 - t) * (1 - t) end
local function ease_in_out(t)
	if t < 0.5 then return 4 * t * t * t end
	local f = 2 - 2 * t
	return 1 - f * f * f / 2
end
local SIGNED, SIGNED_N = {}, 0
local function signed(v)
	local s = SIGNED[v]
	if not s then
		s = (v >= 0 and "+" or "") .. string.format("%.1f", v)
		if SIGNED_N >= 4000 then SIGNED, SIGNED_N = {}, 0 end
		SIGNED[v], SIGNED_N = s, SIGNED_N + 1
	end
	return s
end
local NUM_STR = {}
for i = 0, 99 do NUM_STR[i] = tostring(i) end
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

asset.budget, asset.dims = 2, {}

function asset.image(path)
	local h = asset.images[path]
	if h == nil then
		if asset.budget <= 0 then return nil end
		asset.budget = asset.budget - 1
		local ok, handle = pcall(Render.LoadImage, path)
		h = ok and handle or false
		asset.images[path] = h
	end
	return h or nil
end

local function path_cache(fmt)
	return setmetatable({}, { __index = function(t, k)
		local v = fmt(k)
		t[k] = v
		return v
	end })
end

local PORTRAIT_PATH = path_cache(function(h) return K.PORTRAIT:format(h) end)
local ICON_PATH = path_cache(function(h) return K.ICON:format(h) end)
local POS_PATH = path_cache(function(p) return K.POS:format(K.POS_ICON[p]) end)

function asset.portrait(h) return asset.image(PORTRAIT_PATH[h]) end
function asset.icon(h) return asset.image(ICON_PATH[h]) end
function asset.pos(p) return asset.image(POS_PATH[p]) end

local data = {
	heroes = {}, list = {}, by_attr = {}, by_id = {},
	manifest = nil, sets = {}, busy = {}, wait = {}, failed = false, next_check = 0,
}

do
	local ok, json = pcall(require, "assets.JSON")
	data.json = ok and json or nil
end

data.FILE = "draft_helper_v2.dat"
data.MAGIC = "DHC2"
data.LEGACY = { "manifest.json", "heroes.json", "items.txt", "ap_0.txt", "ap_50.txt", "ap_60.txt", "ap_70.txt", "cm_0.txt", "cm_50.txt", "cm_60.txt", "cm_70.txt" }

function data.path(name)
	local dir = Engine.GetCheatDirectory()
	if not dir:match("[\\/]$") then dir = dir .. "\\" end
	return dir .. "configs\\" .. name
end

function data.file(name)
	local f = io.open(data.path(name), "rb")
	if not f then return nil end
	local text = f:read("a")
	f:close()
	return text
end

function data.load_cache()
	local cache = {}
	data.cache = cache
	local blob = data.file(data.FILE)
	if blob and blob:sub(1, #data.MAGIC + 1) == data.MAGIC .. "\n" then
		local i = #data.MAGIC + 2
		while i <= #blob do
			local name, len, start = blob:match("^([^\n]+)\n(%d+)\n()", i)
			if not name then break end
			len = tonumber(len)
			cache[name] = blob:sub(start, start + len - 1)
			i = start + len + 1
		end
		return
	end
	local moved = false
	for _, name in ipairs(data.LEGACY) do
		local text = data.file("draft_helper_" .. name)
		if text then
			cache[name], moved = text, true
			os.remove(data.path("draft_helper_" .. name))
		end
	end
	local session = data.file("draft_helper_session.json")
	if session then
		if Config.ReadString(K.CFG, "session", "") == "" then Config.WriteString(K.CFG, "session", session) end
		os.remove(data.path("draft_helper_session.json"))
	end
	os.remove(data.path("draft_helper.dat"))
	if moved then data.save_cache() end
end

function data.save_cache()
	local names = {}
	for name in pairs(data.cache) do names[#names + 1] = name end
	table.sort(names)
	local parts = { data.MAGIC, "\n" }
	for _, name in ipairs(names) do
		local text = data.cache[name]
		parts[#parts + 1] = name .. "\n" .. #text .. "\n"
		parts[#parts + 1] = text
		parts[#parts + 1] = "\n"
	end
	local path = data.path(data.FILE)
	local f = io.open(path .. ".tmp", "wb")
	if not f then return end
	f:write(table.concat(parts))
	f:close()
	os.remove(path)
	if not os.rename(path .. ".tmp", path) then
		f = io.open(path, "wb")
		if f then
			f:write(table.concat(parts))
			f:close()
		end
		os.remove(path .. ".tmp")
	end
end

function data.read(name)
	if not data.cache then data.load_cache() end
	return data.cache[name]
end

function data.write(name, text)
	if not data.cache then data.load_cache() end
	data.cache[name] = text
	data.save_cache()
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
		if data.manifest and data.manifest.time == m.time and next(data.heroes) then
			data.prefetch()
			return
		end
		data.fetch("heroes.json", function(body)
			local heroes = data.decode(body)
			if not heroes then return end
			data.cache["heroes.json"] = body
			data.write("manifest.json", text)
			data.manifest = m
			data.set_heroes(heroes)
			data.prefetch()
		end)
	end)
end

function data.prefetch()
	if data.active then data.stats(data.active()) end
	data.items()
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

function data.parse_items(text, time)
	local it = { time = time, patch = text:match("\nv (%S+)"), meta = {}, by_name = {}, up = {}, hero = {} }
	for id, name, cost in text:gmatch("\ni (%d+) ([%w_]+) (%d+)") do
		local i = tonumber(id)
		it.meta[i] = { name = name, cost = tonumber(cost) }
		it.by_name[name] = i
	end
	for id, list in text:gmatch("\nu (%d+) ([%d ]+)") do
		local up = {}
		for p in list:gmatch("%d+") do up[#up + 1] = tonumber(p) end
		it.up[tonumber(id)] = up
	end
	for h, p, n, wr, share in text:gmatch("\nh (%d+) (%d) (%d+) (%d+) (%d+)") do
		local hid = tonumber(h)
		it.hero[hid] = it.hero[hid] or {}
		it.hero[hid][tonumber(p)] = { n = tonumber(n), wr = tonumber(wr) / 1000, share = tonumber(share), start = {}, core = {}, mid = {}, final = {}, path = {} }
	end
	local function entry(h, p)
		local hero = it.hero[tonumber(h)]
		return hero and hero[tonumber(p)]
	end
	for h, p, n, list in text:gmatch("\ns (%d+) (%d) (%d+) ([%d,]+)") do
		local e = entry(h, p)
		if e then
			local ids = {}
			for x in list:gmatch("%d+") do ids[#ids + 1] = tonumber(x) end
			e.start[#e.start + 1] = { n = tonumber(n), ids = ids }
		end
	end
	for tag, h, p, id, pr, m, wr in text:gmatch("\n([cm]) (%d+) (%d) (%d+) (%d+) (%d+) (%d+)") do
		local e = entry(h, p)
		if e then
			local list = tag == "c" and e.core or e.mid
			list[#list + 1] = { id = tonumber(id), pr = tonumber(pr) / 1000, min = tonumber(m) / 10, wr = tonumber(wr) / 1000 }
		end
	end
	for h, p, id, m in text:gmatch("\nb (%d+) (%d) (%d+) (%d+)") do
		local e = entry(h, p)
		if e then e.path[#e.path + 1] = { id = tonumber(id), min = tonumber(m) / 10 } end
	end
	for h, p, id, pr in text:gmatch("\nf (%d+) (%d) (%d+) (%d+)") do
		local e = entry(h, p)
		if e then e.final[tonumber(id)] = tonumber(pr) / 1000 end
	end
	return it
end

function data.stats(key, parse)
	parse = parse or data.parse
	local info = data.manifest and data.manifest.sets[key]
	local cur = data.sets[key]
	if not info then
		if cur == nil then
			local text = data.read(key .. ".txt")
			cur = text and parse(text, 0) or false
			data.sets[key] = cur
		end
		return cur or nil
	end
	if cur and cur.time == info.time then return cur end
	if Config.ReadInt(K.CFG, "set_" .. key, 0) == info.time then
		local text = data.read(key .. ".txt")
		if text then
			data.sets[key] = parse(text, info.time)
			return data.sets[key]
		end
	end
	data.fetch("stats/" .. key .. ".txt", function(text)
		if not text then return end
		data.write(key .. ".txt", text)
		Config.WriteInt(K.CFG, "set_" .. key, info.time)
		data.sets[key] = parse(text, info.time)
	end)
	return cur or nil
end

function data.items() return data.stats("items", data.parse_items) end

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

local upd = { state = "idle", latest = nil, urls = nil, error = nil, checked = false, check_failed = false, next_check = 0, reload_at = nil, changed_at = 0 }

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
		upd.latest, upd.urls = v.version, {}
		if type(v.release) == "string" then upd.urls[1] = v.release end
		upd.urls[#upd.urls + 1] = v.url
		upd.set(upd.newer(v.version, K.VERSION) and "available" or "idle")
	end)
end

function upd.install()
	if upd.state ~= "available" and upd.state ~= "error" then return end
	local want = upd.latest
	upd.set("loading")
	upd.fetch(1, want)
end

function upd.fetch(i, want)
	upd.request(upd.urls[i], function(text, err)
		if text and (not text:find("^%-%-%[%[") or not text:find("return script%s*$")) then
			text, err = nil, L("dh_upd_bad_file")
		end
		local found = text and text:match('VERSION = "([^"]+)"')
		if text and found ~= want then
			text, err = nil, string.format(L("dh_upd_bad_version"), tostring(found), want)
		end
		if not text then
			if upd.urls[i + 1] then return upd.fetch(i + 1, want) end
			return upd.set("error", err)
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
		Engine.RunScript(JS.SINK:format("false", K.SINK_TIMEOUT))
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
data.active = function() return SET.source .. "_" .. K.RANKS[SET.rank] end

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
	if S.in_frame and S.frame_step == S.frame then return S.calc end
	local st = draft.stats()
	if not st or draft.done() then return nil end
	local ours, theirs, pos = draft.teams()
	local ban = draft.is_ban()
	local our_turn = S.mode == "ap" or draft.cm_ours()
	local mine = our_turn ~= ban
	local busy = (mine and not ban) and draft.our_pos() or nil
	local role = busy and draft.my_role()
	if role then
		busy = {}
		for p = 1, 5 do busy[p] = p ~= role end
	end
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
	if S.in_frame then S.frame_step = S.frame end
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

function draft.my_role()
	return S.mode == "ap" and draft.live() and live.d and live.d.my_role or nil
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
		local role = draft.my_role()
		if role and S.filter == 0 then return role end
		local r = draft.row_for(h)
		return draft.free_pos(S.filter > 0 and S.filter or (r and r.pos) or (hero and hero.pos))
	end
	local i = draft.cm_step()
	if i > #K.ORDER or kind(i) ~= "P" then return nil end
	local planned = hero and hero.pos
	if side_of(S.cm.fp, i) == S.cm.us then return draft.free_pos(S.filter > 0 and S.filter or planned) end
	local busy = {}
	for j, _ in ipairs(S.cm.picks) do
		if kind(j) == "P" and side_of(S.cm.fp, j) ~= S.cm.us and S.cm.pos[j] then busy[S.cm.pos[j]] = true end
	end
	local best = nil
	for p = 1, 5 do
		if not busy[p] and (not best or (hero and hero.shares[p] > hero.shares[best])) then best = p end
	end
	return best or planned
end

function draft.reset_turn(keep_filter)
	S.sel, S.ghost, S.enemy_at = nil, nil, nil
	S.menu = nil
	if not keep_filter or draft.our_pos()[S.filter] then S.filter = 0 end
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
		S.last.me = draft.live() and live.d and live.d.me or nil
		S.last.match = draft.live() and live.lobby() or nil
		S.saved = S.last
		draft.save_last()
	end
end

function draft.save_last()
	local last = S.saved
	if not data.json then return end
	if not last then
		Config.WriteString(K.CFG, "session", "{}")
		return
	end
	local out = { mode = last.mode, train = last.train, chance = last.chance, me = last.me, match = last.match, ap = last.ap }
	if last.cm then
		local pos = {}
		for i, p in pairs(last.cm.pos) do pos[tostring(i)] = p end
		out.cm = { fp = last.cm.fp, us = last.cm.us, picks = last.cm.picks, pos = pos }
	end
	local ok, text = pcall(data.json.encode, data.json, out)
	if ok and text then Config.WriteString(K.CFG, "session", text) end
end

function draft.clear_last()
	if not S.last or not S.last.train then return end
	S.last, S.saved, S.bh = nil, nil, nil
	draft.reset_turn()
	draft.save_last()
end

function draft.show_last()
	local saved = S.saved
	S.last = saved and (saved.train or (saved.match ~= nil and saved.match == live.match)) and saved or nil
end

function draft.load_last()
	local v = data.decode(Config.ReadString(K.CFG, "session", ""))
	if not v or (v.mode ~= "cm" and v.mode ~= "ap") or not v[v.mode] then return end
	if v.cm then
		local pos = {}
		for i, p in pairs(v.cm.pos or {}) do pos[tonumber(i)] = p end
		v.cm.pos, v.cm.picks = pos, v.cm.picks or {}
	end
	if v.ap then
		v.ap.ours, v.ap.theirs, v.ap.bans = v.ap.ours or {}, v.ap.theirs or {}, v.ap.bans or {}
	end
	v.chance = tonumber(v.chance) or 0.5
	S.saved = v
	draft.show_last()
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
		draft.reset_turn(true)
		S.query, S.focus = "", false
		return
	end
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
	draft.reset_turn(true)
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
		get = function(x) return arr[x.i].p end, set = function(x, v) arr[x.i].p, arr[x.i].manual = v, true end, self = { i = j } }
end

function draft.set_slot_pos(key, p)
	local info = draft.slot_info(key)
	for _, x in ipairs(info.list) do
		if x.h ~= info.h and info.get(x) == p then info.set(x, info.p) end
	end
	info.set(info.self, p)
	draft.snapshot()
end

draft.load_last()

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
	return unit and live.unit(unit:gsub("_png$", ""):gsub("_persona%d+$", ""):gsub("_alt%d+$", "")) or nil
end

function live.unit(unit)
	local h = unit:gsub("^npc_dota_hero_", "")
	if not data.heroes[h] then
		data.heroes[h] = { h = h, name = Engine.GetDisplayNameByUnitName("npc_dota_hero_" .. h) or h, attr = "all", rate = 50, games = "0", pos = 1 }
	end
	return h
end

function live.slot_hero(slot, img)
	img = img or slot:FindChildTraverse("HeroImage")
	local h = live.hero(img)
	if not h then
		local key = slot:GetID() .. (img and img:GetImageSrc() or "")
		if not live.missing[key] then
			live.missing[key] = true
			live.log("no hero in %s, image src: '%s'", slot:GetID(), img and img:GetImageSrc() or "")
		end
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
		s.n = s.n or tonumber(s.label:GetText())
		local n = s.n
		if n and s.panel:HasClass("HeroPickLocked") then
			if not s.h then
				if not s.img or not s.img:IsValid() then s.img = s.panel:FindChildTraverse("HeroImage") end
				s.h = live.slot_hero(s.panel, s.img)
			end
			d.order[n] = s.h
		else
			s.h = nil
			if n and s.panel:HasClass("ActiveStage") then d.turn = n end
		end
	end
	live.read_players(d)
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
	live.read_players(d)
	live.after_players(d)
	return d
end

function live.ranked()
	local lobby = GameRules.GetLobbyID()
	if live.ranked_lobby ~= lobby then
		local v = data.decode(GameRules.GetLobbyObjectJson())
		live.ranked_lobby, live.is_ranked = lobby, v ~= nil and K.RANKED[v.lobby_type] == true
		live.log("lobby %s: type %s, ranked %s", tostring(lobby), tostring(v and v.lobby_type), tostring(live.is_ranked))
	end
	return live.is_ranked
end

function live.trace_roles(d)
	local found, total, parts, missing = 0, 0, {}, {}
	for _, side in ipairs({ "r", "d" }) do
		local list = {}
		for _, p in ipairs(d.teams[side]) do
			total = total + 1
			if p.role then found = found + 1 else missing[#missing + 1] = p.name end
			list[#list + 1] = ("%s=%s"):format(p.h or p.name, tostring(p.role))
		end
		parts[#parts + 1] = side .. "[" .. table.concat(list, " ") .. "]"
	end
	local line = ("roles: me %s, found %d/%d | %s"):format(tostring(d.my_role), found, total, table.concat(parts, " "))
	if line == live.roles_line then return end
	live.roles_line = line
	live.log("%s", line)
	if not d.my_role then live.log("roles: own role not found, GetTeamData has no lane_selection_flags") end
	if #missing > 0 then live.log("roles: no role for %s, position falls back to hero stats", table.concat(missing, ", ")) end
end

function live.read_players(d)
	d.teams = { r = {}, d = {} }
	d.ranked = d.mode == "ap" and live.ranked()
	local me = Players.GetLocal()
	if not me then return end
	local my_id, list = Player.GetPlayerID(me), Players.GetAll()
	table.sort(list, function(a, b) return Player.GetPlayerID(a) < Player.GetPlayerID(b) end)
	for _, p in ipairs(list) do
		local team = Entity.GetTeamNum(p)
		local side = team == Enum.TeamNum.TEAM_RADIANT and "r" or (team == Enum.TeamNum.TEAM_DIRE and "d" or nil)
		if side then
			local ok, td = pcall(Player.GetTeamData, p)
			td = ok and type(td) == "table" and td or {}
			local unit = Engine.GetHeroNameByID(math.tointeger(tonumber(td.selected_hero_id) or 0) or 0)
			local player = {
				name = Player.GetName(p) or "?", me = Player.GetPlayerID(p) == my_id,
				h = unit and unit ~= "" and live.unit(unit) or nil,
				role = d.ranked and K.LANE_BITS[math.tointeger(tonumber(td.lane_selection_flags) or 0) or 0] or nil,
			}
			if player.me then d.us, d.me, d.my_role = side, player.h, player.role end
			table.insert(d.teams[side], player)
		end
	end
end

function live.after_players(d)
	if d.ranked and SET.log == 1 then live.trace_roles(d) end
end

function live.pregame()
	local p = live.pre_panel
	if p and p:IsValid() then return p end
	local now = os.clock()
	if now < (live.next_pre or 0) then return nil end
	live.next_pre = now + 1
	live.pre_panel = Panorama.GetPanelByName("PreGame", false)
	return live.pre_panel
end

function live.read(pre, now)
	pre = pre or live.pregame()
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
	local present, out, taken, roles = {}, {}, {}, {}
	for _, p in ipairs(players) do
		if p.h then
			present[p.h] = true
			roles[p.h] = p.role
		end
	end
	for _, e in ipairs(prev) do
		if present[e.h] then
			present[e.h] = nil
			if roles[e.h] and not e.manual then e.p = roles[e.h] end
			out[#out + 1] = e
			if e.p then taken[e.p] = true end
		end
	end
	for _, p in ipairs(players) do
		if p.h and present[p.h] then
			present[p.h] = nil
			local pos = p.role or live.pos[p.h] or data.heroes[p.h].pos
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
		draft.reset_turn(true)
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
		draft.reset_turn(true)
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
	if d.me and S.saved and draft.done() and S.saved.me ~= d.me then
		S.saved.me = d.me
		draft.save_last()
	end
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
				raw[i] = (p.me and "*" or "") .. p.name .. ":" .. (p.h or "-") .. (p.role and ("@" .. p.role) or "")
				local who = p.me and ("%s (%s)"):format(p.name, L("dh_d_me")) or p.name
				names[i] = ("%s %s"):format(who, name(p.h))
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

function live.lobby()
	local id = GameRules.GetLobbyID()
	if not id or id == 0 then return nil end
	return tostring(id)
end

function live.tick()
	local now = os.clock()
	if now >= (live.next_match or 0) then
		live.next_match = now + 0.5
		local match = Engine.IsInGame() and live.lobby() or nil
		if match ~= live.match then
			live.match = match
			draft.show_last()
			live.log("match %s, saved draft %s", tostring(match), S.last and "shown" or "hidden")
		end
	end
	if now < live.next_read then return end
	live.next_read = now + K.LIVE_READ
	local pre = live.pregame()
	if SET.captain == 1 and pre and now >= live.next_captain and pre:HasClass("LocalTeamNeedsCaptain") then
		live.next_captain = now + K.LIVE_CAPTAIN
		local ok = Engine.RunScript(JS.CAPTAIN, pre)
		live.log("become captain: script %s", ok and "sent" or "failed")
	end
	local d = live.read(pre, now)
	live.d = d
	if not d then live.next_read = now + K.LIVE_IDLE end
	if SET.log == 1 or SET.panel == 1 then live.trace_state(d) end
	live.apply(d)
end

function live.trace_state(d)
	local parts = { d and ("mode=" .. d.mode) or "no draft" }
	for _, row in ipairs(live.rows(d)) do parts[#parts + 1] = row.id .. "=" .. row.raw end
	local trace = table.concat(parts, " ")
	if trace ~= live.trace then
		live.trace = trace
		live.log("%s", trace)
	end
end

local inv = { items = {}, sig = "", match = nil, next_read = 0 }

function inv.tick()
	local now = os.clock()
	if now < inv.next_read then return end
	inv.next_read = now + ITEM.INV_READ
	if live.match ~= inv.match then inv.match, inv.items, inv.sig = live.match, {}, "" end
	if not inv.match then return end
	local me = Heroes.GetLocal()
	if not me then return end
	local changed = false
	for _, hero in ipairs(Heroes.GetAll()) do
		if not Entity.IsSameTeam(hero, me) and not NPC.IsIllusion(hero) and not Entity.IsDormant(hero) then
			local name = NPC.GetUnitName(hero):gsub("^npc_dota_hero_", "")
			local list = {}
			for i = 0, 8 do
				local item = NPC.GetItemByIndex(hero, i)
				if item then list[#list + 1] = (Ability.GetName(item):gsub("^item_", "")) end
			end
			table.sort(list)
			local key = table.concat(list, ",")
			if not inv.items[name] or inv.items[name].key ~= key then
				local set = {}
				for _, n in ipairs(list) do set[n] = true end
				inv.items[name] = { key = key, set = set }
				changed = true
			end
		end
	end
	if not changed then return end
	local parts = {}
	for name, e in pairs(inv.items) do parts[#parts + 1] = name .. "=" .. e.key end
	table.sort(parts)
	inv.sig = table.concat(parts, ";")
end

local build = { team = {}, me = nil, names = {}, abilities = {}, rules = nil, cache = {}, cached = 0 }

function build.item_name(name)
	local s = build.names[name]
	if not s then
		local ok, v = pcall(GameLocalizer.FindItem, "item_" .. name)
		s = ok and type(v) == "string" and v ~= "" and v or name
		build.names[name] = s
	end
	return s
end

function build.ability_name(ab)
	local s = build.abilities[ab]
	if not s then
		local ok, v = pcall(GameLocalizer.FindAbility, ab)
		s = ok and type(v) == "string" and v or ""
		build.abilities[ab] = s
	end
	return s
end

function build.get_rules()
	if build.rules then return build.rules end
	local function parse(s)
		local out = {}
		for tok in s:gmatch("%S+") do
			local tag, w, ab = tok:match("^(%a+)=?([%d%.]*):?([%w_]*)$")
			if tag then out[#out + 1] = { tag = tag, w = tonumber(w) or 1, ab = ab ~= "" and ab or nil } end
		end
		return out
	end
	local rules = { heroes = {}, enemy = {} }
	for h, s in pairs(ITEM.HEROES) do rules.heroes[h] = parse(s) end
	for name, s in pairs(ITEM.ENEMY) do rules.enemy[name] = parse(s) end
	build.rules = rules
	return rules
end

function build.threats(enemies)
	local rules, threat = build.get_rules(), {}
	for _, e in ipairs(enemies) do
		local per = {}
		local function add(tag, w, what)
			local p = per[tag]
			if not p then
				p = { w = 0, what = {} }
				per[tag] = p
			end
			p.w = p.w + w
			if what and what ~= "" then p.what[#p.what + 1] = what end
		end
		for _, r in ipairs(rules.heroes[e] or {}) do add(r.tag, r.w, r.ab and build.ability_name(r.ab)) end
		local own = inv.items[e]
		if own then
			for name in pairs(own.set) do
				for _, r in ipairs(rules.enemy[name] or {}) do add(r.tag, r.w, build.item_name(name)) end
			end
		end
		for tag, p in pairs(per) do
			local t = threat[tag]
			if not t then
				t = { w = 0, src = {} }
				threat[tag] = t
			end
			t.w = t.w + math.min(ITEM.CAP, p.w)
			t.src[#t.src + 1] = { h = e, w = p.w, what = p.what }
		end
	end
	return threat
end

function build.plan(h, pos, enemies)
	local it, hero = data.items(), data.heroes[h]
	if not it or not hero or not hero.id then return nil end
	local key = table.concat({ h, tostring(pos), table.concat(enemies, ","), inv.sig, tostring(it.time) }, "|")
	if build.cache[key] then return build.cache[key] end
	if build.cached >= 16 then build.cache, build.cached = {}, 0 end
	local plan = { key = key, has = false, start = {}, stages = { {}, {}, {} }, counters = {} }
	build.cache[key], build.cached = plan, build.cached + 1
	local e = it.hero[hero.id] and it.hero[hero.id][pos]
	if not e or e.n < ITEM.POS_MIN then
		plan.no_role = true
		return plan
	end
	plan.has = true

	local in_start = {}
	local kit = e.start[1]
	if kit then
		local order, count = {}, {}
		for _, id in ipairs(kit.ids) do
			local m = it.meta[id]
			if m then
				if not count[id] then order[#order + 1] = id end
				count[id] = (count[id] or 0) + 1
				in_start[id] = true
			end
		end
		for _, id in ipairs(order) do plan.start[#plan.start + 1] = { name = it.meta[id].name, q = count[id] } end
	end

	local pr, mins = {}, {}
	for _, list in ipairs({ e.core, e.mid }) do
		for _, x in ipairs(list) do
			pr[x.id] = math.max(pr[x.id] or 0, x.pr)
			mins[x.id] = mins[x.id] or x.min
		end
	end
	local function base(id)
		local m = it.meta[id]
		return m and (m.name:gsub("^dagon_%d$", "dagon"))
	end
	local src = e.path
	if #src == 0 then
		src = {}
		for _, x in ipairs(e.core) do src[#src + 1] = x end
		for _, x in ipairs(e.mid) do
			if x.pr >= ITEM.FILL then src[#src + 1] = x end
		end
		table.sort(src, function(p, q) return p.min < q.min end)
	end
	local path, at = {}, {}
	for _, x in ipairs(src) do
		local name = base(x.id)
		if name and not in_start[x.id] then
			local i = at[name]
			if not i then
				path[#path + 1] = { id = x.id, name = name, min = x.min, q = 1 }
				at[name] = #path
			elseif name == it.meta[x.id].name and i == #path then
				path[i].q = path[i].q + 1
			end
		end
	end
	local function upgraded(i)
		for _, p in ipairs(it.up[path[i].id] or {}) do
			local j = at[base(p) or ""]
			if j and j > i and path[j].name ~= path[i].name and path[j].min - path[i].min <= ITEM.FOLD_GAP then return true end
		end
		return false
	end
	local keep = {}
	for i, x in ipairs(path) do
		if not upgraded(i) then keep[#keep + 1] = x end
	end
	path, at = keep, {}
	for i, x in ipairs(path) do at[x.name] = i end

	local function add(name, min)
		if at[name] then return end
		path[#path + 1] = { name = name, min = min, q = 1 }
		at[name] = #path
	end
	for _, name in ipairs({ ITEM.SCEPTER, ITEM.SHARD }) do
		local id = it.by_name[name]
		if id and (pr[id] or 0) >= ITEM.AGHS then add(name, mins[id] or ITEM.LATE) end
	end

	local pool = {}
	for id, p in pairs(e.final) do pool[id] = p end
	for id, p in pairs(pr) do pool[id] = math.max(pool[id] or 0, p) end
	local function fits(name)
		local id = it.by_name[name]
		local p = id and pool[id] or 0
		if p >= ITEM.POOL then return 1 + p end
		for _, role in ipairs(ITEM.CONSUMABLES[name] or {}) do
			if role == pos then return 0.5 end
		end
		return 0
	end
	local threat, by_item, order = build.threats(enemies), {}, {}
	for _, tag in ipairs(ITEM.ORDER) do
		local t = threat[tag]
		local score = t and t.w / (ITEM.THRESHOLD[tag] or 1) or 0
		if score >= 1 then
			local list = {}
			for i, name in ipairs(ITEM.ANSWERS[tag]) do
				local f = fits(name)
				if f > 0 then list[#list + 1] = { name = name, f = f, i = i } end
			end
			table.sort(list, function(p, q)
				if p.f ~= q.f then return p.f > q.f end
				return p.i < q.i
			end)
			if list[1] then
				local name = list[1].name
				local c = by_item[name]
				if not c then
					c = { name = name, score = 0, tags = {}, src = {}, by_hero = {} }
					by_item[name] = c
					order[#order + 1] = c
				end
				c.score = c.score + score
				c.tags[#c.tags + 1] = tag
				c.alt = c.alt or (list[2] and list[2].name)
				for _, s in ipairs(t.src) do
					local src_h = c.by_hero[s.h]
					if not src_h then
						src_h = { h = s.h, w = 0, what = {} }
						c.by_hero[s.h] = src_h
						c.src[#c.src + 1] = src_h
					end
					src_h.w = src_h.w + s.w
					for _, w in ipairs(s.what) do
						local dup = false
						for _, x in ipairs(src_h.what) do dup = dup or x == w end
						if not dup then src_h.what[#src_h.what + 1] = w end
					end
				end
			end
		end
	end
	table.sort(order, function(p, q) return p.score > q.score end)
	for i = 1, math.min(ITEM.COUNTERS, #order) do
		local c = order[i]
		table.sort(c.src, function(p, q) return p.w > q.w end)
		plan.counters[i] = c
		local id = it.by_name[c.name]
		add(c.name, (id and mins[id]) or (ITEM.CONSUMABLES[c.name] and ITEM.EARLY - 1) or ITEM.LATE)
	end

	for i, x in ipairs(path) do x.i = i end
	table.sort(path, function(p, q)
		if p.min ~= q.min then return p.min < q.min end
		return p.i < q.i
	end)
	for _, x in ipairs(path) do
		local s = x.min < ITEM.EARLY and 1 or (x.min < ITEM.MID and 2 or 3)
		local row = plan.stages[s]
		row[#row + 1] = x
	end
	local mid, late = plan.stages[2], plan.stages[3]
	if (#mid == 0 and #late >= 3) or (#late == 0 and #mid >= 4) then
		local all = {}
		for _, x in ipairs(mid) do all[#all + 1] = x end
		for _, x in ipairs(late) do all[#all + 1] = x end
		local cut = math.floor(#all / 2)
		plan.stages[2], plan.stages[3] = { table.unpack(all, 1, cut) }, { table.unpack(all, cut + 1) }
	end
	return plan
end

function build.current()
	local h = S.bh
	if not h or not data.heroes[h] then return nil end
	local pos = nil
	for _, e in ipairs(build.team) do
		if e.h == h then pos = e.get() end
	end
	pos = pos or data.heroes[h].pos
	local enemies = {}
	for _, e in ipairs(build.slots(true)) do enemies[#enemies + 1] = e.h end
	table.sort(enemies)
	return build.plan(h, pos, enemies), pos
end

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
	local me = draft.live() and live.d and live.d.me or (draft.home_board() and S.last and S.last.me)
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
local NUM_LAYOUT, NUM_LAYOUT_N = {}, 0

function g.num_layout(font, px, str)
	if NUM_LAYOUT_N >= 2000 then NUM_LAYOUT, NUM_LAYOUT_N = {}, 0 end
	local by_font = NUM_LAYOUT[font]
	if not by_font then
		by_font = {}
		NUM_LAYOUT[font] = by_font
	end
	local key = px .. ":" .. str
	local out = by_font[key]
	if out then return out end
	local dw = asset.digit_w(font, px)
	local chars, total = {}, 0
	for ch in str:gmatch(".") do
		local digit = ch:match("%d") ~= nil
		local w = digit and dw or asset.size(font, px, ch).x
		chars[#chars + 1] = { ch, total + (digit and (w - asset.size(font, px, ch).x) / 2 or 0) }
		total = total + w
	end
	out = { chars = chars, total = total, h = asset.size(font, px, str).y }
	by_font[key], NUM_LAYOUT_N = out, NUM_LAYOUT_N + 1
	return out
end
function g.num(weight, size, str, x, cy, c, a, align)
	local font, px = asset.font(weight), g.fs(size)
	local lay = g.num_layout(font, px, str)
	local total = lay.total
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - total elseif align == "c" then tx = tx - total / 2 end
	local ty = math.floor(g.y + cy * g.s - lay.h / 2 + 0.5)
	local col = g.col(c, a)
	for _, ch in ipairs(lay.chars) do
		Render.Text(font, px, ch[1], Vec2(math.floor(tx + ch[2] + 0.5), ty), col)
	end
	return total / g.s
end
function g.num_width(weight, size, str)
	local font, px = asset.font(weight), g.fs(size)
	return g.num_layout(font, px, str).total / g.s
end
function g.glyph(name, size, x, cy, c, a, align)
	return g.text(asset.icons(), size, K.G[name], x, cy, c, a, align or "c")
end
function g.image(handle, x, y, w, h, r, a, gray, tint)
	if not handle then return end
	local size = asset.dims[handle]
	if not size then
		size = Render.ImageSize(handle)
		asset.dims[handle] = size
	end
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

local HOVER_KEY = setmetatable({}, { __index = function(t, id)
	local v = "hv:" .. id
	t[id] = v
	return v
end })

function anim.hover(id, on)
	return anim.tween(HOVER_KEY[id], on and 1 or 0, 0.12)
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
		g.num(i == cur and 700 or 500, 11, NUM_STR[i], 200, ny, i == cur and C.text or (i <= n and C.text2 or C.text3), 1, "c")
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
		g.num(r == round and 700 or 500, 11, NUM_STR[r], 200, K.AP_MID[r] + K.TB, r == round and C.text or (r < round and C.text2 or C.text3), 1, "c")
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
	elseif S.view == "news" then
		title, done_btn = L("dh_news"), "newsback"
		add(K.NEWS[1].v, true)
		add(L("dh_news_sub"))
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
			S.view = done_btn == "poolback" and S.pool_ret or (done_btn == "buildback" and S.b_ret or (done_btn == "newsback" and S.news_ret or S.ret))
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
	local labels, tws, cells, total = {}, {}, {}, 0
	for p = 0, 5 do
		labels[p] = p == 0 and L("dh_auto") or L("dh_pos_" .. p)
		tws[p] = g.width(F(500), 13, labels[p]) + 24
		total = total + tws[p]
	end
	local extra = math.max(0, (w - 4 - total) / 6)
	local cx = x + 2
	for p = 0, 5 do
		cells[p] = { x = cx, w = tws[p] + extra }
		cx = cx + cells[p].w
	end
	local cur = cells[S.filter] or cells[0]
	local tx = anim.tween("seg", cur.x, 0.3, ease_in_out)
	local tw_cur = anim.tween("seg_w", cur.w, 0.3, ease_in_out)
	g.thumb(x, y, w, h, tx - x - 2, tx - x - 2 + tw_cur, C.thumb, 7)
	local busy = draft.our_pos()
	for p = 0, 5 do
		local bx, bw = cells[p].x, cells[p].w
		local on, is_busy = S.filter == p, p > 0 and busy[p]
		if p > 0 and not on and S.filter ~= p - 1 then g.rect(bx, y + 8, 1, h - 16, C.sep2) end
		local label = labels[p]
		local col = on and C.text or (is_busy and C.text3 or C.text2)
		local tw = tws[p]
		local lx = math.floor(bx + (bw - tw) / 2 + 0.5)
		if p == 0 then g.glyph("wand", 14, lx + 9, y + 16, col) else g.icon(asset.pos(p), lx, y + 7, 18, col) end
		g.text(F(500), 13, label, lx + 24, y + 16, col)
		hit.add(bx, y, bw, h, "seg" .. p, { click = function() S.filter = p end })
	end
end

function view.row_text(r)
	local hero = data.heroes[r.h]
	local t = r._text
	if not t or t.rate ~= hero.rate or t.games ~= hero.games or t.lang ~= L("dh_matches") then
		t = {
			rate = hero.rate, games = hero.games, lang = L("dh_matches"),
			d = r.d and signed(r.d), rate_s = string.format("%.1f%%", hero.rate),
			games_s = string.format(L("dh_matches"), data.count(hero.games)),
		}
		r._text = t
	end
	return t
end

function view.value(r, ctx, right, cy, size)
	local col = C.text
	if ctx then col = r.d >= 0.05 and C.green or (r.d <= -0.05 and C.red or C.text2) end
	local t = view.row_text(r)
	g.num(600, size, ctx and t.d or t.rate_s, right, cy - 9, col, 1, "r")
	local mx = right - g.text(F(400), 11, t.games_s, right, cy + 9, C.text3, 1, "r")
	if ctx then
		g.vr(mx - 7, cy + 9, 9)
		g.num(400, 11, t.rate_s, mx - 14, cy + 9, C.text3, 1, "r")
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
		g.icon(asset.pos(r.pos), cx, cy - 9, 18, C.text2)
		r._share = r._share or (r.share and (r.share .. "%"))
		cx = cx + 23 + g.text(F(500), 12, r._share or L("dh_pos_" .. r.pos), cx + 23, cy, C.text2) + 6
	end
	if ctx and SET.reasons == 1 then
		local function txt(e)
			e[3] = e[3] or signed(e[2])
			return e[3]
		end
		local function item_w(e) return 27 + g.width(F(500), 12, txt(e)) + 6 end
		for _, group in ipairs(r.why or {}) do
			group.key = group.key or ("dh_" .. group[1])
			local label = L(group.key)
			local need = (first and 0 or 7) + g.width(F(400), 12, label) + 5 + item_w(group[2][1])
			if cx + need > max_x then break end
			sep()
			cx = cx + g.text(F(400), 12, label, cx, cy, C.text3) + 5
			for n = 1, math.min(2, #group[2]) do
				local h, v = group[2][n][1], group[2][n][2]
				if n > 1 and cx + item_w(group[2][n]) > max_x then break end
				g.icon(asset.icon(h), cx, cy - 11, 22)
				cx = cx + 27
				cx = cx + g.text(F(500), 12, txt(group[2][n]), cx, cy, v >= 0 and C.green or C.red) + 6
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

local ROW_ACTS = {}

function view.row_actions(h)
	local acts = ROW_ACTS[h]
	if not acts then
		acts = {
			click = function() draft.place(h) end,
			dbl = function() draft.commit(h) end,
			rclick = function(mx, my) view.open_ctx(h, mx, my) end,
		}
		ROW_ACTS[h] = acts
	end
	return acts
end

function view.best(r, ctx, y, a, can)
	local x, w = K.CX, K.CW
	r._id = r._id or ("h:" .. r.h)
	r._sel = r._sel or ("sel:" .. r.h)
	local id = r._id
	local sel = S.sel == r.h
	g.rect(x, y, w, 100, C.card, 14, a)
	local k = anim.hover(id, can and hit.is(id))
	if k > 0 then g.rect(x, y, w, 100, C.hover, 14, a * k) end
	local ks = anim.tween(r._sel, sel and 1 or 0, 0.15)
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
		if S.vis_top and (ry + 56 < S.vis_top or ry > S.vis_bottom) then goto continue end
		r._id = r._id or ("h:" .. r.h)
		r._sel = r._sel or ("sel:" .. r.h)
		local id = r._id
		local sel = S.sel == r.h
		local k = anim.hover(id, can and hit.is(id))
		local ks = anim.tween(r._sel, sel and 1 or 0, 0.15)
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
		::continue::
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
		if S.rest_of ~= list then
			S.rest_of, S.rest = list, {}
			for i = 2, #list do S.rest[#S.rest + 1] = list[i] end
		end
		h = h + 14 + view.rows(S.rest, ctx, y + h + 14, a, can)
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

function view.fold(key, on)
	return anim.tween("fold_" .. key, on and 1 or 0, 0.26, ease_in_out)
end

function view.setting_rows(rows, y, a)
	local x, w = K.CX, K.CW
	local hs, total, last = {}, 0, 0
	for n, row in ipairs(rows) do
		hs[n] = math.floor(50 * (row.fold or 1) + 0.5)
		total = total + hs[n]
		if hs[n] > 0 then last = n end
	end
	if total <= 0 then return 0 end
	g.rect(x, y, w, total, C.card, 12, a)
	local ry = y
	for n, row in ipairs(rows) do
		local f = row.fold or 1
		if hs[n] > 0 then
			local ra = a * f * f
			if f < 1 then g.clip(x, ry, w, hs[n]) end
			if n > 1 then g.rect(x + 58, ry, w - 58, 1, C.sep2, 0, ra) end
			local k = row.act and anim.hover(row.id, hit.is(row.id)) or 0
			if k > 0 then
				local flags = (last == 1) and ROUND or (n == 1 and Enum.DrawFlags.RoundCornersTop or (n == last and Enum.DrawFlags.RoundCornersBottom or Enum.DrawFlags.RoundCornersNone))
				g.rect(x, ry, w, 50, C.hover, 12, ra * k, flags)
			end
			g.rect(x + K.P, ry + 10, 30, 30, row.tile, 8, ra)
			g.glyph(row.glyph, 16, x + K.P + 15, ry + 25, C.text, ra)
			if row.sub then
				g.text(F(600), 14, row.title, x + 58, ry + 17, C.text, ra)
				g.text(F(400), 12, row.sub, x + 58, ry + 34, C.text3, ra)
			else
				g.text(F(600), 14, row.title, x + 58, ry + 25, C.text, ra)
			end
			if row.control and f > 0.98 then row.control(x + w - K.P, ry + 25, ra) elseif row.control then
				local hold = hit.list
				hit.list = {}
				row.control(x + w - K.P, ry + 25, ra)
				hit.list = hold
			end
			if row.act and f > 0.98 then hit.add(x, ry, w, 50, row.id, { click = row.act }) end
			if f < 1 then g.unclip() end
		end
		ry = ry + hs[n]
	end
	return total
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
				SET.count = clamp(SET.count + delta, 4, 25)
				save_settings()
			end })
		end
	end
	btn(x, "minus", -1, SET.count > 4, "cnt_minus")
	g.num(600, 13, tostring(SET.count), x + 44, cy, C.text, a, "c")
	btn(x + 58, "plus", 1, SET.count < 25, "cnt_plus")
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
		local rows = {
			{ tile = S.last.chance >= 0.5 and C.t_green or C.red, glyph = "finish", title = S.last.mode == "ap" and "All Pick" or "Captains Mode", sub = sub },
			{ id = "home_builds", tile = C.t_purple, glyph = "bag", title = L("dh_b_row"), sub = L("dh_b_row_sub"), control = view.chevron(L("dh_open"), "home_builds"), act = build.open_team },
		}
		if S.last.train then
			rows[#rows + 1] = { id = "home_clear", tile = C.red, glyph = "trash", title = L("dh_h_clear"), sub = L("dh_h_clear_sub"), control = view.chevron(L("dh_clear"), "home_clear"), act = function()
				draft.clear_last()
				build.team, build.me = {}, nil
			end }
		end
		h = h + view.setting_rows(rows, y + h, a)
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
		{ tile = C.t_blue, glyph = "users", title = L("dh_s_source"), control = view.choice("source", { { "cm", "Captains Mode" }, { "ap", L("dh_source_ap") } }, SET.source, pick("source")) },
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
	h = h + view.group_header(L("dh_bp"), y + h, a)
	h = h + view.setting_rows({
		{ tile = C.t_purple, glyph = "bag", title = L("dh_bp"), sub = L("dh_bp_tip"), control = view.switch("bp") },
		{ fold = view.fold("bp", SET.bp == 1), tile = C.t_blue, glyph = "eye", title = L("dh_bp_show"), control = view.choice("bp_show", { { "shop", L("dh_bp_show_shop") }, { "always", L("dh_bp_show_always") } }, SET.bp_show, pick("bp_show")) },
	}, y + h, a) + 22
	h = h + view.group_header(L("dh_s_window"), y + h, a)
	h = h + view.setting_rows({
		{ tile = C.t_purple, glyph = "wand", title = L("dh_s_auto"), sub = L("dh_s_auto_sub"), control = view.switch("auto") },
		{ tile = C.t_blue, glyph = "pointer", title = L("dh_s_hover"), sub = L("dh_s_hover_sub"), control = view.switch("hints") },
		{ tile = C.t_indigo, glyph = "blur", title = L("dh_s_blur"), control = view.switch("blur") },
		{ fold = view.fold("blur", SET.blur == 1), tile = C.t_indigo, glyph = "drop", title = L("dh_s_blur_power"), control = view.slider("blur_power", 10, 100) },
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
		{ id = "set_news", tile = C.t_indigo, glyph = "gift", title = L("dh_news"), sub = L("dh_news_row_sub"), control = view.chevron(L("dh_open"), "set_news"), act = function() view.open_news() end },
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

	return 262 + view.items(x, y + 262, w, a)
end

function view.item_icon(name, x, y, a, id, q)
	g.rect(x, y, 44, 32, C.fill4, 5, a)
	g.image(asset.image(ITEM.ICON:format(name)), x, y, 44, 32, 5, a)
	if q and q > 1 then
		g.rect(x + 26, y + 18, 18, 14, C.badge, 4, a)
		g.text(F(700), 10, "×" .. q, x + 35, y + 25, C.text, a, "c")
	end
	hit.add(x, y, 44, 32, id, {})
	if hit.is(id) then S.tip = build.item_name(name) end
end

function view.items(x, y, w, a)
	local plan, pos = build.current()
	local hero = data.heroes[S.bh]
	local nc = plan and #plan.counters or 0
	local h = 120
	if plan and plan.has then
		h = 44 + 44
		for _, row in ipairs(plan.stages) do
			if #row > 0 then h = h + 44 end
		end
		h = h + 44 + (nc > 0 and nc * 50 or 30) + 6
	end
	g.rect(x, y, w, h, C.card, 12, a)
	local bw = g.text(F(700), 11, L("dh_b_build"), x + K.P, y + 23, C.text3, a)
	local nw = g.text(F(700), 11, hero.name:upper(), x + K.P + bw + 6, y + 23, C.text2, a)
	if pos then g.icon(asset.pos(pos), x + K.P + bw + nw + 12, y + 16, 14, C.text2, a) end
	if not plan or not plan.has then
		local status = data.status("items")
		local text = plan and L(plan.no_role and "dh_b_no_role" or "dh_b_no_hero") or (status == "none" and L("dh_b_data_none") or L("dh_data_" .. status))
		g.text(F(500), 13, text, x + w / 2, y + 72, C.text3, a, "c")
		return h
	end

	local lx, ix, right = x + K.P, x + K.P + 104, x + w - K.P
	local function label(text, ry) g.text(F(500), 12, text, lx, ry + 22, C.text2, a) end
	local ry = y + 44
	label(L("dh_b_start"), ry)
	for i, e in ipairs(plan.start) do
		local cx = ix + (i - 1) * 50
		if cx + 44 > right then break end
		view.item_icon(e.name, cx, ry + 6, a, "bs:" .. i, e.q)
	end
	ry = ry + 44

	for s, row in ipairs(plan.stages) do
		if #row > 0 then
			label(L("dh_b_stage" .. s), ry)
			for i, e in ipairs(row) do
				local cx = ix + (i - 1) * 50
				if cx + 44 > right then break end
				view.item_icon(e.name, cx, ry + 6, a, "b" .. s .. ":" .. i, e.q)
			end
			ry = ry + 44
		end
	end

	g.rect(lx, ry + 4, w - 2 * K.P, 1, C.sep2, 0, a)
	g.text(F(700), 11, L("dh_b_counter"), lx, ry + 26, C.text3, a)
	ry = ry + 44
	if nc == 0 then g.text(F(400), 12, L("dh_b_counter_none"), lx, ry + 10, C.text3, a) end
	for i, c in ipairs(plan.counters) do
		local cy = ry + (i - 1) * 50
		view.item_icon(c.name, lx, cy + 9, a, "bc:" .. i)
		local tx = lx + 58
		g.text(F(600), 13, build.item_name(c.name), tx, cy + 17, C.text, a)
		local tags = {}
		for _, t in ipairs(c.tags) do tags[#tags + 1] = L("dh_t_" .. t) end
		local hx = right - #c.src * 26 + 4
		local line = g.fit(400, 12, table.concat(tags, ", "), hx - 12 - tx)
		local lw = g.text(F(400), 12, line, tx, cy + 35, C.text2, a)
		if c.alt then
			local alt = string.format(L("dh_b_or"), build.item_name(c.alt))
			if tx + lw + 4 + g.width(F(400), 12, alt) <= hx - 12 then g.text(F(400), 12, alt, tx + lw + 4, cy + 35, C.text3, a) end
		end
		for j, src in ipairs(c.src) do
			local id = "bch:" .. i .. ":" .. j
			local px = hx + (j - 1) * 26
			g.icon(asset.icon(src.h), px, cy + 14, 22, C.text, a)
			hit.add(px, cy + 14, 22, 22, id, {})
			if hit.is(id) then
				local name = data.heroes[src.h] and data.heroes[src.h].name or src.h
				S.tip = #src.what > 0 and (name .. ": " .. table.concat(src.what, ", ")) or name
			end
		end
	end
	return h
end

function view.open_news()
	if S.view ~= "news" then S.news_ret = S.view end
	S.view, S.menu, S.query, S.focus = "news", nil, "", false
	Config.WriteString(K.CFG, "news", K.NEWS[1].v)
end

view.wraps = {}

function view.wrap(text, weight, size, max_w)
	local key = weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. text
	local out = view.wraps[key]
	if out then return out end
	out = {}
	local line = ""
	for word in text:gmatch("[^ \t\n]+") do
		local try = line == "" and word or (line .. " " .. word)
		if line ~= "" and g.width(F(weight), size, try) > max_w then
			out[#out + 1] = line
			line = word
		else
			line = try
		end
	end
	if line ~= "" then out[#out + 1] = line end
	view.wraps[key] = out
	return out
end

function view.news(y, a)
	local x, w, h = K.CX, K.CW, 0
	for _, rel in ipairs(K.NEWS) do
		h = h + view.group_header(string.format(L("dh_version"), rel.v), y + h, a)
		for _, e in ipairs(rel.items) do
			local lines = view.wrap(L(e.key .. "_d"), 400, 13, w - 58 - K.P)
			local strip = (e.icons or e.roles) and 44 or 0
			local ch = 44 + #lines * 18 + strip + 12
			local cy = y + h
			g.rect(x, cy, w, ch, C.card, 12, a)
			g.rect(x + K.P, cy + 14, 30, 30, C[e.tile], 8, a)
			g.glyph(e.glyph, 16, x + K.P + 15, cy + 29, C.text, a)
			g.text(F(600), 15, L(e.key .. "_t"), x + 58, cy + 25, C.text, a)
			for i, line in ipairs(lines) do g.text(F(400), 13, line, x + 58, cy + 44 + (i - 1) * 18, C.text2, a) end
			local iy = cy + 36 + #lines * 18 + 12
			if e.icons then
				for i, name in ipairs(e.icons) do
					local ix = x + 58 + (i - 1) * 50
					g.rect(ix, iy, 44, 32, C.fill4, 6, a)
					g.image(asset.image(ITEM.ICON:format(name)), ix, iy, 44, 32, 6, a)
				end
			elseif e.roles then
				g.rect(x + 58, iy, 5 * 34 + 4, 32, C.fill3, 8, a)
				g.rect(x + 58 + 2, iy + 2, 34, 28, C.pill, 6, a)
				for r = 1, 5 do g.icon(asset.pos(r), x + 58 + 2 + (r - 1) * 34 + 7, iy + 6, 20, C.text, a * (r == 1 and 1 or 0.55)) end
			end
			h = h + ch + 10
		end
		h = h + 12
	end
	return h
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
	S.vis_top, S.vis_bottom = top, bottom
	local h
	if S.view == "home" then h = view.home(y, a)
	elseif S.view == "set" then h = view.settings(y, a)
	elseif S.view == "pool" then h = view.pool(y, a)
	elseif S.view == "build" then h = view.build(y, a)
	elseif S.view == "news" then h = view.news(y, a)
	else h = view.draft_content(y, a) end
	S.vis_top, S.vis_bottom = nil, nil
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

function view.grip(w, h, id, on_down)
	local hot = hit.is(id) or (S.resize ~= nil and S.resize.id == id)
	local c = hot and C.text2 or C.text3
	g.line(w - 6, h - 14, w - 14, h - 6, c, 1, 1.5)
	g.line(w - 6, h - 9, w - 9, h - 6, c, 1, 1.5)
	hit.add(w - 18, h - 18, 18, 18, id, { down = on_down })
end

function view.resize_to(mx)
	local r = S.resize
	local k = (r.w + mx - r.mx) / r.w
	SET[r.key] = clamp(math.floor(r.scale * k + 0.5), K.SCALE_MIN, K.SCALE_MAX)
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
	view.grip(K.W, K.H, "grip", function(mx)
		S.resize = { id = "grip", key = "scale", mx = mx, w = K.W * g.s, scale = SET.scale }
	end)
	view.menu()
	view.tip()
	g.frame(0, 0, K.W, K.H, C.border, 16)
end

local bp = {
	HEAD = 36, IW = 40, IH = 29, COLS = 6, x = nil, y = nil, rect = nil, hits = {}, hover = nil, press = nil, drag = nil,
	hero = nil, match = nil, pos = nil, prefs = false, switched = 0, shown = false,
	quick = {}, enemies = {}, next_scan = 0, cat = nil, tip_id = nil, tip_since = 0,
}

function bp.me()
	local hero = Heroes.GetLocal()
	if not hero then return nil end
	return (NPC.GetUnitName(hero):gsub("^npc_dota_hero_", "")), hero
end

function bp.visible()
	if not ui.enable:Get() or SET.bp ~= 1 or not Engine.IsInGame() or not Heroes.GetLocal() then return false end
	return SET.bp_show == "always" or Engine.IsShopOpen()
end

function bp.default_pos(me)
	for _, e in ipairs(build.slots(false)) do
		if e.h == me and e.get() then return e.get() end
	end
	local p = Players.GetLocal()
	if p then
		local ok, td = pcall(Player.GetTeamData, p)
		local role = ok and type(td) == "table" and K.LANE_BITS[math.tointeger(tonumber(td.lane_selection_flags) or 0) or 0]
		if role then return role end
	end
	return data.heroes[me] and data.heroes[me].pos or 1
end

function bp.catalog()
	if bp.cat then return bp.cat end
	local cat = { id = {}, name = {}, cost = {}, recipe = {} }
	bp.cat = cat
	local dir = Engine.GetCheatDirectory()
	if not dir:match("[\\/]$") then dir = dir .. "\\" end
	local f = io.open(dir .. "assets\\data\\items.json", "rb")
	if not f then return cat end
	local v = data.decode(f:read("a"))
	f:close()
	local root = v and v.DOTAAbilities
	if type(root) ~= "table" then return cat end
	for full, e in pairs(root) do
		local id = type(e) == "table" and tonumber(e.ID)
		if id and full:sub(1, 5) == "item_" then
			local name = full:sub(6)
			cat.id[name], cat.name[id], cat.cost[name] = id, name, tonumber(e.ItemCost) or 0
			local req = e.ItemRecipe == "1" and type(e.ItemResult) == "string" and type(e.ItemRequirements) == "table" and e.ItemRequirements["01"]
			if type(req) == "string" then
				local parts = {}
				for part in req:gmatch("[^;]+") do parts[#parts + 1] = (part:gsub("%*$", ""):gsub("^item_", "")) end
				cat.recipe[e.ItemResult:sub(6)] = { parts = parts, recipe = name }
			end
		end
	end
	return cat
end

function bp.leaves(name, have, out, depth)
	if depth > 0 and (have[name] or 0) > 0 then
		have[name] = have[name] - 1
		return
	end
	local cat = bp.catalog()
	local r = depth < 6 and cat.recipe[name]
	if not r then
		out[#out + 1] = name
		return
	end
	for _, part in ipairs(r.parts) do bp.leaves(part, have, out, depth + 1) end
	if (cat.cost[r.recipe] or 0) > 0 then bp.leaves(r.recipe, have, out, depth + 1) end
end

function bp.read_quick(it)
	local out, p = {}, Players.GetLocal()
	if not p then return out end
	local ok, info = pcall(Player.GetQuickBuyInfo, p)
	if not ok or type(info) ~= "table" then return out end
	for _, raw in ipairs(info.m_quickBuyItems or {}) do
		local id = math.tointeger(tonumber(raw) or 0) or 0
		local name = id > 0 and (it and it.meta[id] and it.meta[id].name or bp.catalog().name[id])
		if name then out[#out + 1] = name end
	end
	return out
end

function bp.read_enemies(hero)
	local out, seen = {}, {}
	for _, h in ipairs(Heroes.GetAll()) do
		if not Entity.IsSameTeam(h, hero) and not NPC.IsIllusion(h) then
			local name = NPC.GetUnitName(h):gsub("^npc_dota_hero_", "")
			if data.heroes[name] and not seen[name] then
				seen[name] = true
				out[#out + 1] = name
			end
		end
	end
	table.sort(out)
	return out
end

function bp.set_quick(list)
	if #list == 0 then
		pcall(Engine.SetQuickBuy, "", true)
	else
		for i, name in ipairs(list) do Engine.SetQuickBuy(name, i == 1) end
	end
	bp.next_scan = 0
end

function bp.has_quick(name)
	for _, n in ipairs(bp.quick) do
		if n == name then return true end
	end
	return false
end

function bp.pin(name)
	if Input.IsKeyDown(Enum.ButtonCode.KEY_LSHIFT) or Input.IsKeyDown(Enum.ButtonCode.KEY_RSHIFT) then
		Engine.SetQuickBuy(name, true)
	elseif bp.has_quick(name) then
		local keep = {}
		for _, n in ipairs(bp.quick) do
			if n ~= name then keep[#keep + 1] = n end
		end
		bp.set_quick(keep)
	else
		Engine.SetQuickBuy(name, false)
	end
	bp.next_scan = 0
end

function bp.buy(name)
	local player, hero = Players.GetLocal(), Heroes.GetLocal()
	if not player or not hero then return end
	local cat = bp.catalog()
	local have = {}
	for i = 0, 14 do
		local item = NPC.GetItemByIndex(hero, i)
		if item then
			local n = Ability.GetName(item):gsub("^item_", "")
			have[n] = (have[n] or 0) + 1
		end
	end
	local parts = {}
	bp.leaves(name, have, parts, 0)
	local gold = Player.GetTotalGold(player)
	for _, part in ipairs(parts) do
		local id, cost = cat.id[part], cat.cost[part] or 0
		if cost > gold then break end
		if id then
			pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, id, Vector(0, 0, 0), id,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, true, "draft_helper_buy", false)
			gold = gold - cost
		end
	end
	bp.next_scan = 0
end

function bp.tick()
	local now = os.clock()
	if not bp.shown or now < bp.next_scan then return end
	bp.next_scan = now + 0.25
	local me, hero = bp.me()
	if not me then return end
	if bp.match ~= live.match or bp.hero ~= me then
		bp.match, bp.hero, bp.pos = live.match, me, bp.default_pos(me)
	end
	local it = data.items()
	bp.quick, bp.enemies = bp.read_quick(it), bp.read_enemies(hero)
end

function bp.hit(x, y, w, h, id, on)
	on = on or {}
	on.id = id
	on[1], on[2], on[3], on[4] = g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s
	bp.hits[#bp.hits + 1] = on
end

function bp.at(mx, my)
	for i = #bp.hits, 1, -1 do
		local h = bp.hits[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then return h end
	end
	return nil
end

function bp.inside(mx, my)
	local r = bp.rect
	return r and mx >= r[1] and mx < r[3] and my >= r[2] and my < r[4]
end

function bp.labels()
	local labels = { L("dh_b_start"), L("dh_bp_early"), L("dh_bp_mid"), L("dh_bp_late") }
	local w = 0
	for _, t in ipairs(labels) do w = math.max(w, g.width(F(400), 12, t)) end
	return labels, math.ceil(w) + 12
end

function bp.rows(plan, labels)
	if not plan or not plan.has then return nil, 40 end
	local rows, h = {}, 2
	for i, list in ipairs({ plan.start, plan.stages[1], plan.stages[2], plan.stages[3] }) do
		if #list > 0 then
			local lines = math.ceil(#list / bp.COLS)
			local rh = lines * bp.IH + (lines - 1) * 5
			rows[#rows + 1] = { label = labels[i], list = list, y = h, h = rh }
			h = h + rh + 6
		end
	end
	return rows, h - 6 + 10
end

function bp.item(e, x, y, a, idx)
	local id = "bi:" .. idx
	local pin = bp.has_quick(e.name)
	local over = bp.hover == id
	local w, h = bp.IW, bp.IH
	g.rect(x, y, w, h, C.fill4, 5, a)
	g.image(asset.image(ITEM.ICON:format(e.name)), x, y, w, h, 5, a)
	if over then
		g.rect(x, y, w, h, C.hover, 5, a)
		g.frame(x, y, w, h, C.slot_line, 5, a)
	end
	if (e.q or 1) > 1 then
		g.rect(x + w - 16, y + h - 13, 16, 13, C.badge, 3, a)
		g.text(F(700), 10, "×" .. e.q, x + w - 8, y + h - 6.5, C.text, a, "c")
	end
	if pin then
		g.rect(x + w - 11, y - 5, 16, 16, C.main, 8, a)
		g.rect(x + w - 10, y - 4, 14, 14, C.blue, 7, a)
		g.glyph("pin", 8, x + w - 3, y + 3, C.text, a)
	end
	bp.hit(x, y, w, h, id, { item = e.name })
end

function bp.seg(key, options, cur, right, cy, a, on_pick)
	local widths, total = {}, 4
	for i, o in ipairs(options) do
		widths[i] = math.max(26, g.width(F(500), 11, o.label) + 16)
		total = total + widths[i]
	end
	local x0 = right - total
	g.rect(x0, cy - 11, total, 22, C.fill3, 7, a)
	local x, at, w_at = x0 + 2, 0, 26
	for i, o in ipairs(options) do
		if o.v == cur then at, w_at = x - x0 - 2, widths[i] end
		x = x + widths[i]
	end
	local px = anim.tween("bp_seg_" .. key, at, 0.22, ease_in_out)
	local pw = anim.tween("bp_segw_" .. key, w_at, 0.22, ease_in_out)
	g.rect(x0 + 2 + px, cy - 9, pw, 18, C.pill, 5, a)
	x = x0 + 2
	for i, o in ipairs(options) do
		g.text(F(500), 11, o.label, x + widths[i] / 2, cy, o.v == cur and C.text or C.text2, a, "c")
		bp.hit(x, cy - 9, widths[i], 18, "bs:" .. key .. i, { left = function() on_pick(o.v) end })
		x = x + widths[i]
	end
end

function bp.draw_tip(plan)
	if not bp.tip_id or S.now - bp.tip_since < K.TIP_DELAY then return end
	local h = nil
	for _, x in ipairs(bp.hits) do
		if x.id == bp.tip_id then h = x end
	end
	if not h or not h.item then return end
	local lines = { { F(600), 12, build.item_name(h.item), C.text } }
	for _, c in ipairs(plan and plan.counters or {}) do
		if c.name == h.item then
			local tags = {}
			for _, t in ipairs(c.tags) do tags[#tags + 1] = L("dh_t_" .. t) end
			lines[#lines + 1] = { F(400), 11, table.concat(tags, ", "), C.text2 }
			for _, s in ipairs(c.src) do
				local name = data.heroes[s.h] and data.heroes[s.h].name or s.h
				lines[#lines + 1] = { F(400), 11, #s.what > 0 and (name .. ": " .. table.concat(s.what, ", ")) or name, C.text2 }
			end
		end
	end
	if bp.has_quick(h.item) then
		lines[#lines + 1] = { F(400), 11, L("dh_bp_pinned"), C.text3 }
	end
	local w = 0
	for _, l in ipairs(lines) do w = math.max(w, g.width(l[1], l[2], l[3])) end
	w = w + 18
	local th = 10 + #lines * 16
	local k = clamp((S.now - bp.tip_since - K.TIP_DELAY) / 0.12, 0, 1) * g.a
	local screen = Render.ScreenSize()
	local cx = (h[1] + h[3]) / 2
	local sx = clamp(cx - w * g.s / 2, 4, screen.x - w * g.s - 4)
	local sy = h[2] - th * g.s - 6
	if sy < 4 then sy = h[4] + 6 end
	local ox, oy, oa = g.x, g.y, g.a
	g.x, g.y, g.a = math.floor(sx + 0.5), math.floor(sy + 0.5), 1
	g.rect(0, 0, w, th, C.raised, 7, k)
	g.frame(0, 0, w, th, C.outline, 7, k)
	for i, l in ipairs(lines) do g.text(l[1], l[2], l[3], 9, 5 + (i - 0.5) * 16, l[4], k) end
	g.x, g.y, g.a = ox, oy, oa
end

function bp.frame()
	local vis = bp.visible()
	local a = anim.tween("bp", vis and 1 or 0, 0.18)
	bp.shown = a > 0.01
	local prev = bp.hits
	bp.hits, bp.rect = {}, nil
	if not bp.shown then
		bp.hover, bp.tip_id, bp.press, bp.drag, bp.resize = nil, nil, nil, nil, nil
		return
	end
	local me = bp.me()
	if not me or not data.heroes[me] then return end
	local screen = Render.ScreenSize()
	if screen.x <= 0 or screen.y <= 0 then return end
	g.s = math.max(0.7, screen.y / 1080) * SET.bp_scale / 100
	g.a = a
	local mx, my = Input.GetCursorPos()
	bp.hover = nil
	for i = #prev, 1, -1 do
		local h = prev[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then
			bp.hover = h.id
			break
		end
	end
	if bp.press and bp.hover ~= bp.press.id then bp.hover = nil end
	if bp.hover ~= bp.tip_id then bp.tip_id, bp.tip_since = bp.hover, S.now end

	local pos = bp.pos or bp.default_pos(me)
	bp.pos = pos
	local plan = build.plan(me, pos, bp.enemies)
	local labels, lab_w = bp.labels()
	local rows, body_h = bp.rows(plan, labels)
	local W = math.max(8 + 26 + 5 * 26 + 4 + 10, 8 + lab_w + bp.COLS * (bp.IW + 5) - 5 + 8)
	local prefs_h = 2 + 26 + 6 + 20 + 10
	if bp.prefs then body_h = prefs_h end
	local H = bp.HEAD + body_h

	if bp.resize then
		if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
			local k = (bp.resize.w + mx - bp.resize.mx) / bp.resize.w
			SET.bp_scale = clamp(math.floor(bp.resize.scale * k + 0.5), K.SCALE_MIN, K.SCALE_MAX)
		else
			bp.resize = nil
			save_settings()
		end
	end
	if bp.drag then
		if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
			bp.drag.moved = bp.drag.moved or math.abs(mx - bp.drag.mx) + math.abs(my - bp.drag.my) > 3
			bp.x = clamp(bp.drag.x + mx - bp.drag.mx, 0, screen.x - W * g.s)
			bp.y = clamp(bp.drag.y + my - bp.drag.my, 0, screen.y - H * g.s)
		else
			bp.save()
		end
	elseif not bp.x then
		local saved = Config.ReadString(K.CFG, "bp_pos", "")
		local sx, sy = saved:match("^(%d+),(%d+)$")
		if sx then
			bp.x, bp.y = tonumber(sx), tonumber(sy)
		else
			bp.x, bp.y = math.floor(screen.x * 0.6 - W * g.s), math.floor(screen.y * 0.12)
		end
	end
	bp.x = clamp(bp.x, 0, math.max(0, screen.x - W * g.s))
	bp.y = clamp(bp.y, 0, math.max(0, screen.y - H * g.s))
	g.x, g.y = math.floor(bp.x + 0.5), math.floor(bp.y + 0.5)
	H = math.floor(anim.tween("bp_h", H, 0.22, ease_in_out) + 0.5)
	local ca = ease_out(clamp((S.now - bp.switched) / 0.2, 0, 1))
	bp.rect = { g.x, g.y, g.x + W * g.s, g.y + H * g.s }

	g.rect(0, 0, W, H, C.main, 12, 0.94)
	bp.hit(0, 0, W, bp.HEAD, "bp_head", { drag = true })
	g.icon(asset.icon(me), 9, 8, 20, C.text, 1)
	local rx = 36
	g.rect(rx, 5, 5 * 26 + 4, 26, C.fill3, 8, 1)
	local px = anim.tween("bp_role", (pos - 1) * 26, 0.22, ease_in_out)
	g.rect(rx + 2 + px, 7, 26, 22, C.pill, 6, 1)
	local it = data.items()
	local by_pos = it and it.hero[data.heroes[me].id] or nil
	for p = 1, 5 do
		local id = "bp_role" .. p
		local has = by_pos and by_pos[p] and by_pos[p].n >= ITEM.POS_MIN
		local alpha = (p == pos or bp.hover == id) and (has and 1 or 0.6) or (has and 0.55 or 0.22)
		g.icon(asset.pos(p), rx + 2 + (p - 1) * 26 + 5, 10, 16, C.text, alpha)
		bp.hit(rx + 2 + (p - 1) * 26, 7, 26, 22, id, { left = function() bp.pos = p end })
	end
	local gx = W - 32
	local gear_on = bp.prefs or bp.hover == "bp_gear"
	if gear_on then g.rect(gx, 6, 24, 24, C.fill3, 6, 1) end
	g.glyph("gear", 12, gx + 12, 18, gear_on and C.text or C.text2, 1)
	bp.hit(gx, 6, 24, 24, "bp_gear", { left = function() bp.prefs, bp.switched = not bp.prefs, S.now end })
	g.clip(0, bp.HEAD, W, H - bp.HEAD)

	local top = bp.HEAD
	if bp.prefs then
		local y = top + 2
		g.text(F(400), 12, L("dh_bp_show"), 10, y + 13, C.text2, ca)
		bp.seg("show", { { v = "shop", label = L("dh_bp_show_shop") }, { v = "always", label = L("dh_bp_show_always") } }, SET.bp_show, W - 10, y + 13, ca, function(v)
			SET.bp_show = v
			save_settings()
		end)
		y = y + 32
		local lw = g.width(F(500), 12, L("dh_bp_all"))
		g.text(F(500), 12, L("dh_bp_all"), 10, y + 10, C.blue, ca * (bp.hover == "bp_all" and 0.7 or 1))
		bp.hit(10, y, lw, 20, "bp_all", { left = bp.open_settings })
	elseif not plan or not plan.has then
		local status = data.status("items")
		local text = plan and L(plan.no_role and "dh_b_no_role" or "dh_b_no_hero") or (status == "none" and L("dh_b_data_none") or L("dh_data_" .. status))
		g.text(F(400), 12, text, W / 2, top + 18, C.text3, ca, "c")
	else
		local n = 0
		for _, r in ipairs(rows) do
			g.text(F(400), 12, r.label, 9, top + r.y + bp.IH / 2, C.text3, ca)
			for i, e in ipairs(r.list) do
				n = n + 1
				local col, line = (i - 1) % bp.COLS, math.floor((i - 1) / bp.COLS)
				bp.item(e, 8 + lab_w + col * (bp.IW + 5), top + r.y + line * (bp.IH + 5), ca, n)
			end
		end
	end
	g.unclip()
	local grip = bp.hover == "bp_grip" or bp.resize ~= nil
	g.line(W - 6, H - 14, W - 14, H - 6, grip and C.text2 or C.text3, 1, 1.5)
	g.line(W - 6, H - 9, W - 9, H - 6, grip and C.text2 or C.text3, 1, 1.5)
	bp.hit(W - 18, H - 18, 18, 18, "bp_grip", { grip = true })
	g.frame(0, 0, W, H, C.border, 12)
	bp.draw_tip(plan)
end

function bp.open_settings()
	if not S.started then
		S.started = true
		draft.set_env("home")
	end
	if S.view ~= "set" and S.view ~= "pool" then S.ret = S.view end
	S.open, S.view, S.menu, S.query, S.focus = true, "set", nil, "", false
	bp.prefs, bp.switched = false, S.now
end

function bp.save()
	local d = bp.drag
	bp.drag = nil
	if d and d.moved then
		local pos = string.format("%d,%d", math.floor(bp.x + 0.5), math.floor(bp.y + 0.5))
		Config.WriteString(K.CFG, "bp_pos", pos)
	end
end

function bp.key(e)
	if not bp.shown then return nil end
	local left, right = e.key == Enum.ButtonCode.KEY_MOUSE1, e.key == Enum.ButtonCode.KEY_MOUSE2
	if not left and not right then return nil end
	local mx, my = Input.GetCursorPos()
	if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
		if bp.press then return false end
		if not bp.inside(mx, my) then return nil end
		local h = bp.at(mx, my)
		bp.press = { id = h and h.id, right = right }
		if left and h and h.drag then bp.drag = { mx = mx, my = my, x = bp.x, y = bp.y } end
		if left and h and h.grip then bp.resize = { mx = mx, w = bp.rect[3] - bp.rect[1], scale = SET.bp_scale } end
		return false
	elseif e.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
		local p = bp.press
		if not p then return nil end
		bp.press = nil
		if bp.drag then bp.save() end
		if bp.resize then
			bp.resize = nil
			save_settings()
		end
		local h = bp.at(mx, my)
		if h and h.id == p.id then
			if h.item then
				if p.right then bp.buy(h.item) else bp.pin(h.item) end
			elseif not p.right and h.left then
				h.left()
			end
		end
		return false
	end
	return nil
end

local input = { swallow = false, held = {}, sink_on = false, sink_at = 0 }

function input.sink(on, force)
	local now = os.clock()
	if input.sink_on == on and not force and not (on and now >= input.sink_at) then return end
	input.sink_on, input.sink_at = on, now + K.SINK_ALIVE
	Engine.RunScript(JS.SINK:format(on and "true" or "false", K.SINK_TIMEOUT))
end

Engine.RunScript(JS.SINK:format("false", K.SINK_TIMEOUT))

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
	if S.slide or S.resize then save_settings() end
	S.drag, S.sb_drag, S.slide, S.resize = nil, nil, nil, nil
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
	inv.tick()
	bp.tick()
	if ui.key:IsPressed() and not Input.IsInputCaptured() and not S.focus then S.open = not S.open end
end

function script.OnFrame()
	if not ui.enable:Get() then return end
	local now = os.clock()
	local frame = GlobalVars.GetAbsFrameTime()
	S.dt = clamp(frame > 0 and frame or (now - (S.now > 0 and S.now or now)), 0, 0.1)
	S.now = now
	asset.budget = 2
	S.alpha = anim.tween("window", S.open and 1 or 0, 0.18)
	if SET.panel == 1 then view.live_panel() end
	bp.frame()
	input.sink(S.focus and S.open)
	if S.alpha <= 0 then return end
	if not S.started then
		S.started = true
		draft.set_env("home")
		if K.VERSION == K.NEWS[1].v and Config.ReadString(K.CFG, "news", "") ~= K.NEWS[1].v then view.open_news() end
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
	if S.resize and S.resize.key == "scale" then view.resize_to(mx) end
	if S.sb_drag then
		S.scroll_to = clamp(S.sb_drag.scroll + (my - S.sb_drag.my) * S.sb_drag.k, 0, math.max(0, S.content_h - S.view_h))
		anim.snap("scroll", S.scroll_to)
		S.sb_until = S.now + 1.2
	end
	draft.tick()
	S.frame, S.in_frame = (S.frame or 0) + 1, true
	view.window()
	S.in_frame = false
end

function script.OnKeyEvent(e)
	if ui.enable:Get() then
		local taken = bp.key(e)
		if taken ~= nil then return taken end
	end
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
