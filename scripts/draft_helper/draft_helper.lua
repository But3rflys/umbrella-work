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

local Config = Config
local JSON = require("assets.JSON")

local localization = qLocalization.new({
	en = {
		cd_group_main = "Main",
		cd_enable = "Enable",
		cd_enable_tip = "Turns the draft helper on",
		cd_key = "Open window",
		cd_key_tip = "Opens and closes the draft window",
		cd_bind_name = "Draft Helper",

		cd_mode_order = "In turns",
		cd_mode_free = "Free",
		cd_bans = "Bans",
		cd_tip_mode_t = "Draft mode",
		cd_tip_mode = "In turns: bans and picks go strictly by order\nFree: usual hero pick, put anyone anywhere",
		cd_tip_tent_t = "Ally is choosing",
		cd_tip_tent = "The game has not revealed the hero yet,\nit can still change",
		cd_tip_slot_t = "Slot",
		cd_tip_free = "Click an empty slot to fill it,\nright click clears it",
		cd_title = "Draft",
		cd_first = "First pick",
		cd_us = "We",
		cd_enemy = "Enemy",
		cd_chance = "draft win chance",
		cd_replace = "Replace",
		cd_done = "Draft complete",
		cd_done_tip = "right click on a slot clears it",
		cd_search = "Type a hero, Enter puts it in the turn",
		cd_attr_str = "STRENGTH",
		cd_attr_agi = "AGILITY",
		cd_attr_int = "INTELLECT",
		cd_attr_all = "UNIVERSAL",
		cd_t_pick = "Who to pick",
		cd_s_pick = "counters to the enemy draft, then synergy",
		cd_t_ban = "Who to ban",
		cd_s_ban = "best picks for the enemy against us",
		cd_t_epick = "Enemy pick",
		cd_s_epick = "best picks for the enemy against us",
		cd_t_eban = "Enemy ban",
		cd_s_eban = "our best picks they may take away",
		cd_on = "%s for %s",
		cd_posT1 = "Carry",
		cd_posT2 = "Mid",
		cd_posT3 = "Offlane",
		cd_posT4 = "Soft support",
		cd_posT5 = "Hard support",
		cd_tip_badge_t = "Hero position",
		cd_tip_badge = "Click to set the position by hand,\nright click returns auto",
		cd_tip_pm_auto = "Position from hero stats and lineup",
		cd_tip_pm = "Lock the hero on this position",
		cd_tip_auto_t = "Auto",
		cd_tip_auto = "The script picks the position\nthat fits our lineup",
		cd_tip_pick = "Heroes for this position.\nUnder the top ones, who fits with them",
		cd_tip_ban = "Strong heroes against us\nthat play this position",
		cd_tip_taken = "Now %s plays here,\npicking it moves him to a free position",
		cd_tip_close_t = "Close",
		cd_tip_close = "Hides the window,\nit opens again with the key from the menu",
		cd_tip_undo_t = "Undo turn",
		cd_tip_undo = "Removes the last entered hero",
		cd_tip_reset_t = "Reset draft",
		cd_tip_reset = "Clears all picks and bans",
		cd_tip_first_t = "First pick",
		cd_tip_first = "Who bans and picks first.\nIt sets the order of turns",
		cd_auto_pos = "auto",
		cd_pos1 = "carry",
		cd_pos2 = "mid",
		cd_pos3 = "offlane",
		cd_pos4 = "soft support",
		cd_pos5 = "hard support",
		cd_acc1 = "carry",
		cd_acc2 = "mid",
		cd_acc3 = "offlane",
		cd_acc4 = "soft support",
		cd_acc5 = "hard support",
		cd_vs = "vs",
		cd_with = "with",
		cd_weak = "weak vs",
		cd_bad_with = "bad with",
		cd_with_him = "with him",
		cd_pro = "pro drafts %d%%",
		cd_rate = "win rate %.1f%%",
		cd_tip_num_t = "%s from the draft",
		cd_tip_num = "How counters and synergy change the win chance.\nHero win rate %s over %s matches",
		cd_matches = "%s matches",
		cd_empty = "No fitting heroes",
		cd_ld_heroes = "Loading heroes",
		cd_ld_pro = "Loading pro matches",
		cd_ld_wait = "Preparing data",
		cd_ld_error = "No connection to GitHub",
		cd_ld_slow = "The server is slow to answer",
		cd_tip_err_t = "Why",
		cd_ld_retry = "retry in %d s",
		cd_src_short0 = "Ranked",
		cd_rk0 = "All",
		cd_rk1 = "Ancient+",
		cd_rk2 = "Divine+",
		cd_rk3 = "Divine 5+",
		cd_set_source = "Matches",
		cd_set_rank = "Rank",
		cd_set_scale = "Size",
		cd_set_tips = "Hints",
		cd_set_blur = "Background blur",
		cd_set_auto = "Open on hero pick",
		cd_tip_settings_t = "Settings",
		cd_tip_settings = "Data, window look and behavior",
		cd_s_none = "no picks yet, sorted by hero win rate",
		cd_tip_wr_t = "Win rate %s",
		cd_tip_wr = "%s matches at the chosen rank.\nCounters show up after the first picks",
		cd_set_title = "Settings",
		cd_sec_data = "DATA",
		cd_set_volume = "Volume",
		cd_set_volume_tip = "more matches, steadier numbers",
		cd_ld_gh = "Loading stats",
		cd_cnt_t = "Who counters %s",
		cd_sm_counter = "Who counters",
		cd_sm_clear = "Remove",
		cd_cnt_wins = "wins %s of games",
		cd_p_later = "NEXT",
		cd_p_sell = "Inventory full, sell",
		cd_news_t = "What's new",
		cd_news_date = "October 1",
		cd_news_new = "NEW",
		cd_news_fix = "FIXED",
		cd_news_ok = "Got it",
		cd_set_news = "What's new in %s",
		cd_news_open = "Open",
		cd_nw1_t = "Pick from the list",
		cd_nw1 = "Right click a suggested hero to pick it.\nThe script asks for confirmation first.",
		cd_nw2_t = "Buying from the build panel",
		cd_nw2 = "Right click an item to buy it. Low on gold, it buys a part.\nShift + left click leaves only this item in quick buy.",
		cd_nw3_t = "Enemy positions",
		cd_nw3 = "You can set enemy positions by hand. Your lane opponent\nweighs more in advice, enemy support items weigh less.",
		cd_nw4_t = "Single Draft and bans",
		cd_nw4 = "Suggests only the heroes you were given. Skips banned heroes.",
		cd_nw5_t = "Upgrades",
		cd_nw5 = "Next shows what your items upgrade into.",
		cd_nw6_t = "Item advice",
		cd_nw6 = "No longer suggests selling Pike for Aghanim's or buying Butterfly\nagainst MKB. Tells you when to disassemble Radiance.",
		cd_gh_manifest = "checking for updates",
		cd_gh_heroes = "hero list",
		cd_gh_pro = "pro matches",
		cd_gh_rules = "counter rules",
		cd_p_hide_t = "Hide",
		cd_p_hide = "Until the end of the match. Turn it off for good:\nsettings, Build panel, Show: Never",
		cd_gh_ranked = "ranked, %s matches",
		cd_gh_cm = "Captains Mode, %s matches",
		cd_ld_step = "%s, step %d of %d",
		cd_gh_wait = ", waiting %d s",
		cd_gh_sched = "New data daily around %d:%02d Moscow time (%02d:%02d UTC)",
		cd_gh_same = "no new data yet",
		cd_gh_new = "data updated",
		cd_tip_gh_refresh = "GitHub data updates once a day,\nthe button only checks whether a new set is out",
		cd_set_bg = "Background",
		cd_set_debug = "Debug log",
		cd_set_refresh = "Update",
		cd_src_long1 = "Captains Mode",
		cd_upd_now = "updated just now",
		cd_upd_min = "updated %d min ago",
		cd_upd_hour = "updated %d h ago",
		cd_upd_day = "updated %d d ago",
		cd_upd_never = "not loaded yet",
		cd_cm_done = "Loaded %s over %d days",
		cd_cm_wait = "Loading, this takes a few minutes",
		cd_cm_why = "Few CM games, about %d a day, hero pairs lean on ranked",
		cd_cm_why0 = "Few CM games, hero pairs lean on ranked matches",
		cd_upd_failed = "Update failed",
		cd_pill_get = "Update to %s",
		cd_pill_down = "Downloading %s",
		cd_pill_done = "Updated, restarting",
		cd_upd_loading = "loading",
		cd_sum_t = "Draft summary",
		cd_sum_chance = "win chance",
		cd_sum_vs = "MATCHUPS",
		cd_sum_vs_sub = "% to the win chance, ours against theirs",
		cd_sum_total = "total",
		cd_sum_hint = "click one of our heroes to see the build",
		cd_tip_cell_t = "%s against %s",
		cd_tip_cell = "%s%% to the win chance\nfrom matches at the chosen rank",
		cd_tip_sum_t = "%s against their draft",
		cd_tip_sum = "Sum over all five enemies.\nClick shows the build for this hero",
		cd_build_t = "%s BUILD",
		cd_build_sub = "against their pick",
		cd_build_start = "START",
		cd_build_gold = "%d of %d gold",
		cd_build_order = "IN BUY ORDER",
		cd_build_spare = "keep on hand against",
		cd_build_loading = "Loading items",
		cd_build_none = "Not enough item data for this hero",
		cd_tip_item_vs = "Against %s",
		cd_th_magic = "magic",
		cd_th_disable = "disables",
		cd_th_targeted = "single-target",
		cd_th_silence = "silences",
		cd_th_roots = "roots and disarms",
		cd_th_invis = "invisibility",
		cd_th_evasion = "evasion",
		cd_th_heal = "healing",
		cd_th_illusions = "illusions",
		cd_th_passives = "strong passives",
		cd_th_phys = "right-click",
		cd_th_burst = "right-click burst damage",
		cd_th_pierce = "through BKB",
		cd_th_escape = "escapes and dodges",
		cd_th_saves = "enemy saves",
		cd_tip_after = "Later disassemble into %s",
		cd_tip_upgrade = "Later upgrade into %s",
		cd_tip_up_from = "Upgrade of %s",
		cd_tip_bless = "Consumes Aghanim's Scepter\nand frees an inventory slot",
		cd_tip_dis_from = "Disassemble %s and build this",
		cd_p_up = "from %s",
		cd_set_preview = "What it looks like",
		cd_preview_show = "Show",
		cd_preview_hide = "Hide",
		cd_tip_preview = "Shows the panel with a sample build,\nyou can drag it with the mouse",
		cd_p_dis = "disassemble %s",
		cd_tip_swap = "Instead of %s",
		cd_tip_swap_why = "%s has %s",
		cd_p_all = "Build complete",
		cd_tip_skipped = "Skipped for now, it stays at the end",
		cd_tip_noslot = "Consumed right away, takes no slot",
		cd_p_stash = "Inventory full, to backpack",
		cd_p_sell_left = "After disassembling sell",
		cd_tip_dis_left = "%s stays, build %s from it",
		cd_tip_dis_sell = "%s stays, sell it",
		cd_pk_t = "Pick this hero?",
		cd_pk_ok = "Pick",
		cd_pk_no = "Cancel",
		cd_pk_dont = "Don't ask again",
		cd_pk_dont2 = "turn it back on in settings",
		cd_pk_stage = "Picking works only during hero selection",
		cd_pk_have = "You already have a hero",
		cd_pk_taken = "This hero can't be picked",
		cd_pk_fail = "Couldn't pick, not your turn?",
		cd_set_pick_ask = "Confirm hero pick",
		cd_set_lanes = "Enemy positions and lanes",
		cd_tip_lanes = "Position badges on enemy heroes, counters on your lane\nweigh more, items of enemy supports weigh less",
		cd_set_window = "Draft window",
		cd_sec_panel = "BUILD PANEL IN MATCH",
		cd_sec_window = "GENERAL",
		cd_set_pmode = "Show",
		cd_pm0 = "Always",
		cd_pm1 = "In shop",
		cd_pm2 = "Never",
		cd_set_pmode_t = "Build panel",
		cd_pm_note = "Item window during a match.\nIts cross hides it until the match ends",
		cd_set_pview = "Look",
		cd_pview0 = "Strip",
		cd_pview1 = "List",
		cd_set_padapt = "Adapt to enemy items",
		cd_p_title = "Build",
		cd_p_instead = "instead of %s",
		cd_p_preview = "preview",
		cd_p_start = "Start",
		cd_p_cost = "%d gold",
		cd_build_nopos = "No build for %s",
		cd_build_nopos2 = "the hero is rarely played there, pick another position",
		cd_tip_bpos = "Build from %d matches\nin this position",
		cd_tip_bpos_none = "The hero is rarely played here,\nthere is no build",
	},
	ru = {
		cd_group_main = "Основное",
		cd_enable = "Включить",
		cd_enable_tip = "Включает помощника драфта",
		cd_key = "Открыть окно",
		cd_key_tip = "Открывает и закрывает окно драфта",
		cd_bind_name = "Draft Helper",

		cd_mode_order = "По очереди",
		cd_mode_free = "Свободный",
		cd_bans = "Баны",
		cd_tip_mode_t = "Режим драфта",
		cd_tip_mode = "По очереди: баны и пики строго по порядку\nСвободный: обычный выбор, ставишь кого угодно куда угодно",
		cd_tip_tent_t = "Союзник выбирает",
		cd_tip_tent = "Игра ещё не открыла героя,\nон может поменяться",
		cd_tip_slot_t = "Слот",
		cd_tip_free = "Клик по пустому слоту выбирает его,\nправый клик очищает",
		cd_title = "Драфт",
		cd_first = "Первый пик",
		cd_us = "Мы",
		cd_enemy = "Враг",
		cd_chance = "шанс по драфту",
		cd_replace = "Замена",
		cd_done = "Драфт собран",
		cd_done_tip = "правый клик по слоту очищает его",
		cd_search = "Впиши героя, Enter ставит в текущий ход",
		cd_attr_str = "СИЛА",
		cd_attr_agi = "ЛОВКОСТЬ",
		cd_attr_int = "ИНТЕЛЛЕКТ",
		cd_attr_all = "УНИВЕРСАЛ",
		cd_t_pick = "Кого пикнуть",
		cd_s_pick = "контрпики к драфту врага, потом синергия",
		cd_t_ban = "Кого забанить",
		cd_s_ban = "лучшие пики для врага против нас",
		cd_t_epick = "Пик врага",
		cd_s_epick = "лучшие пики для врага против нас",
		cd_t_eban = "Бан врага",
		cd_s_eban = "наши лучшие пики, их могут забрать",
		cd_on = "%s на %s",
		cd_posT1 = "Керри",
		cd_posT2 = "Мид",
		cd_posT3 = "Оффлейн",
		cd_posT4 = "Четвёрка",
		cd_posT5 = "Пятёрка",
		cd_tip_badge_t = "Позиция героя",
		cd_tip_badge = "Клик меняет позицию вручную,\nправый клик возвращает авто",
		cd_tip_pm_auto = "Позиция по статистике героя и составу",
		cd_tip_pm = "Закрепить героя на этой позиции",
		cd_tip_auto_t = "Авто",
		cd_tip_auto = "Скрипт сам выберет позицию,\nкоторая подходит нашему составу",
		cd_tip_pick = "Герои на эту позицию.\nПод лучшими видно, кого взять к ним",
		cd_tip_ban = "Сильные против нас герои,\nкоторые играют на этой позиции",
		cd_tip_taken = "Сейчас здесь %s, при выборе\nон сдвинется на свободную позицию",
		cd_tip_close_t = "Закрыть",
		cd_tip_close = "Прячет окно, открыть снова\nможно клавишей из меню",
		cd_tip_undo_t = "Отменить ход",
		cd_tip_undo = "Убирает последнего вписанного героя",
		cd_tip_reset_t = "Сбросить драфт",
		cd_tip_reset = "Очищает все пики и баны",
		cd_tip_first_t = "Первый пик",
		cd_tip_first = "Кто первым банит и пикает.\nОт этого зависит порядок ходов",
		cd_auto_pos = "авто",
		cd_pos1 = "керри",
		cd_pos2 = "мид",
		cd_pos3 = "оффлейн",
		cd_pos4 = "четвёрка",
		cd_pos5 = "пятёрка",
		cd_acc1 = "керри",
		cd_acc2 = "мид",
		cd_acc3 = "оффлейн",
		cd_acc4 = "четвёрку",
		cd_acc5 = "пятёрку",
		cd_vs = "против",
		cd_with = "с",
		cd_weak = "слаб против",
		cd_bad_with = "плохо с",
		cd_with_him = "с ним",
		cd_pro = "в про-драфтах %d%%",
		cd_rate = "винрейт %.1f%%",
		cd_tip_num_t = "%s от драфта",
		cd_tip_num = "Так контрпики и синергия меняют шанс победы.\nВинрейт героя %s за %s матчей",
		cd_matches = "%s матчей",
		cd_empty = "Нет подходящих героев",
		cd_ld_heroes = "Загружаю героев",
		cd_ld_pro = "Загружаю про-матчи",
		cd_ld_wait = "Готовлю данные",
		cd_ld_error = "Нет связи с GitHub",
		cd_ld_slow = "Сервер долго отвечает",
		cd_tip_err_t = "Причина",
		cd_ld_retry = "повтор через %d с",
		cd_src_short0 = "Рейтинг",
		cd_rk0 = "Все",
		cd_rk1 = "Властелин+",
		cd_rk2 = "Божество+",
		cd_rk3 = "Божество 5+",
		cd_set_source = "Матчи",
		cd_set_rank = "Ранг",
		cd_set_scale = "Размер",
		cd_set_tips = "Подсказки",
		cd_set_blur = "Размытие фона",
		cd_set_auto = "Открывать на выборе героев",
		cd_tip_settings_t = "Настройки",
		cd_tip_settings = "Данные, внешний вид окна и поведение",
		cd_s_none = "пиков ещё нет, порядок по винрейту героев",
		cd_tip_wr_t = "Винрейт %s",
		cd_tip_wr = "%s матчей на выбранном ранге.\nКонтрпики появятся после первых пиков",
		cd_set_title = "Настройки",
		cd_sec_data = "ДАННЫЕ",
		cd_set_volume = "Объём",
		cd_set_volume_tip = "больше матчей, точнее цифры",
		cd_ld_gh = "Загружаю статистику",
		cd_cnt_t = "Кто контрит %s",
		cd_sm_counter = "Кто контрит",
		cd_sm_clear = "Убрать",
		cd_cnt_wins = "побеждает в %s игр",
		cd_p_later = "ДАЛЬШЕ",
		cd_p_sell = "Инвентарь полный, продай",
		cd_news_t = "Что нового",
		cd_news_date = "1 октября",
		cd_news_new = "НОВОЕ",
		cd_news_fix = "ИСПРАВЛЕНО",
		cd_news_ok = "Понятно",
		cd_set_news = "Что нового в %s",
		cd_news_open = "Открыть",
		cd_nw1_t = "Пик из списка",
		cd_nw1 = "ПКМ по герою в рекомендациях выбирает его.\nПеред этим скрипт спрашивает подтверждение.",
		cd_nw2_t = "Покупка с панели сборки",
		cd_nw2 = "ПКМ по предмету покупает его. Если золота мало, покупает часть.\nShift + ЛКМ ставит в быструю покупку только этот предмет.",
		cd_nw3_t = "Позиции врагов",
		cd_nw3 = "Позицию врага можно выбрать вручную. Контрпик соперника по линии\nвлияет на совет сильнее, предметы вражеских саппортов слабее.",
		cd_nw4_t = "Single Draft и баны",
		cd_nw4 = "Советует только выданных героев. Забаненных не предлагает.",
		cd_nw5_t = "Апгрейды",
		cd_nw5 = "В «Дальше» видно, во что улучшить твои предметы.",
		cd_nw6_t = "Советы по предметам",
		cd_nw6 = "Больше не предлагает продать пику ради аганима и брать бабочку\nпротив мкб. Подсказывает, когда разобрать радик.",
		cd_gh_manifest = "проверяю обновления",
		cd_gh_heroes = "список героев",
		cd_gh_pro = "про-матчи",
		cd_gh_rules = "правила контр",
		cd_p_hide_t = "Скрыть",
		cd_p_hide = "До конца матча. Выключить совсем:\nнастройки, Панель сборки, Показывать: Нет",
		cd_gh_ranked = "рейтинг, %s матчей",
		cd_gh_cm = "Captains Mode, %s матчей",
		cd_ld_step = "%s, шаг %d из %d",
		cd_gh_wait = ", жду %d с",
		cd_gh_sched = "Новые данные каждый день около %d:%02d по МСК",
		cd_gh_same = "новых данных пока нет",
		cd_gh_new = "данные обновлены",
		cd_tip_gh_refresh = "Данные на GitHub обновляются раз в сутки,\nкнопка только проверит, не вышли ли новые",
		cd_set_bg = "Фон",
		cd_set_debug = "Отладка в лог",
		cd_set_refresh = "Обновить",
		cd_src_long1 = "Captains Mode",
		cd_upd_now = "обновлено только что",
		cd_upd_min = "обновлено %d мин назад",
		cd_upd_hour = "обновлено %d ч назад",
		cd_upd_day = "обновлено %d дн назад",
		cd_upd_never = "ещё не загружено",
		cd_cm_done = "Загружено %s за %d дней",
		cd_cm_wait = "Загружаю, это займёт несколько минут",
		cd_cm_why = "В CM мало игр, около %d в день, пары героев дополняются рейтинговыми",
		cd_cm_why0 = "В CM мало игр, пары героев дополняются рейтинговыми",
		cd_upd_failed = "Не удалось обновить",
		cd_pill_get = "Обновить до %s",
		cd_pill_down = "Скачиваю %s",
		cd_pill_done = "Обновлено, перезапуск",
		cd_upd_loading = "загружается",
		cd_sum_t = "Итог драфта",
		cd_sum_chance = "шанс победы",
		cd_sum_vs = "КТО КОГО",
		cd_sum_vs_sub = "% к шансу победы, наши против их",
		cd_sum_total = "итог",
		cd_sum_hint = "клик по нашему герою открывает его сборку",
		cd_tip_cell_t = "%s против %s",
		cd_tip_cell = "%s%% к шансу победы\nпо матчам выбранного ранга",
		cd_tip_sum_t = "%s против их драфта",
		cd_tip_sum = "Сумма по всем пяти врагам.\nКлик покажет сборку этого героя",
		cd_build_t = "СБОРКА %s",
		cd_build_sub = "против их пика",
		cd_build_start = "СТАРТ",
		cd_build_gold = "%d из %d золота",
		cd_build_order = "ПО ПОРЯДКУ ПОКУПКИ",
		cd_build_spare = "в запасе против",
		cd_build_loading = "Загружаю предметы",
		cd_build_none = "Мало данных по предметам героя",
		cd_tip_item_vs = "Против %s",
		cd_th_magic = "магия",
		cd_th_disable = "контроль",
		cd_th_targeted = "в одну цель",
		cd_th_silence = "сайленсы",
		cd_th_roots = "руты и дизарм",
		cd_th_invis = "инвиз",
		cd_th_evasion = "уклонение",
		cd_th_heal = "лечение",
		cd_th_illusions = "иллюзии",
		cd_th_passives = "сильные пассивки",
		cd_th_phys = "урон с руки",
		cd_th_burst = "берст урон с руки",
		cd_th_pierce = "сквозь BKB",
		cd_th_escape = "побег и доджи",
		cd_th_saves = "сейвы у врага",
		cd_tip_after = "Потом разобрать в %s",
		cd_tip_upgrade = "Потом собрать в %s",
		cd_tip_up_from = "Апгрейд %s",
		cd_tip_bless = "Съедает Aghanim's Scepter\nи освобождает слот в инвентаре",
		cd_tip_dis_from = "Разобрать %s и собрать",
		cd_p_up = "из %s",
		cd_set_preview = "Как выглядит",
		cd_preview_show = "Показать",
		cd_preview_hide = "Скрыть",
		cd_tip_preview = "Показывает панель с примером сборки,\nеё можно передвинуть мышью",
		cd_p_dis = "разобрать %s",
		cd_tip_swap = "Вместо %s",
		cd_tip_swap_why = "У %s: %s",
		cd_p_all = "Сборка собрана",
		cd_tip_skipped = "Пропущен, стоит в конце очереди",
		cd_tip_noslot = "Съедается сразу, слот не занимает",
		cd_p_stash = "Инвентарь полный, в рюкзак",
		cd_p_sell_left = "После разборки продай",
		cd_tip_dis_left = "Останется %s, собери из него %s",
		cd_tip_dis_sell = "Останется %s, его продай",
		cd_pk_t = "Выбрать этого героя?",
		cd_pk_ok = "Выбрать",
		cd_pk_no = "Отмена",
		cd_pk_dont = "Больше не спрашивать",
		cd_pk_dont2 = "включить обратно можно в настройках",
		cd_pk_stage = "Выбрать можно только на стадии пиков",
		cd_pk_have = "Герой уже выбран",
		cd_pk_taken = "Этого героя сейчас нельзя взять",
		cd_pk_fail = "Не получилось выбрать, не твой ход?",
		cd_set_pick_ask = "Подтверждать выбор героя",
		cd_set_lanes = "Позиции врагов и линии",
		cd_tip_lanes = "Значки позиций у врагов, контрпики по своей линии\nвесят больше, предметы вражеских саппортов меньше",
		cd_set_window = "Окно драфта",
		cd_sec_panel = "ПАНЕЛЬ СБОРКИ В МАТЧЕ",
		cd_sec_window = "ОБЩЕЕ",
		cd_set_pmode = "Показывать",
		cd_pm0 = "Всегда",
		cd_pm1 = "В магазине",
		cd_pm2 = "Нет",
		cd_set_pmode_t = "Панель сборки",
		cd_pm_note = "Окошко с предметами в матче.\nКрестик на нём прячет его до конца игры",
		cd_set_pview = "Вид",
		cd_pview0 = "Полоса",
		cd_pview1 = "Список",
		cd_set_padapt = "Подстраивать под предметы врагов",
		cd_p_title = "Сборка",
		cd_p_instead = "вместо %s",
		cd_p_preview = "предпросмотр",
		cd_p_start = "Старт",
		cd_p_cost = "%d золота",
		cd_build_nopos = "Сборки на %s нет",
		cd_build_nopos2 = "на этой позиции героя почти не берут, выбери другую",
		cd_tip_bpos = "Сборка по %d матчам\nна этой позиции",
		cd_tip_bpos_none = "Здесь героя почти не берут,\nсборки нет",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Draft Helper")
	tab:Icon("\u{f0c0}")

	local page = tab:Create("Settings")
	local g_main = page:Create("cd_group_main", Enum.GroupSide.Left)

	ui.enable = g_main:Switch("cd_enable", true, "\u{f011}")
	ui.enable:ToolTip("cd_enable_tip")

	ui.key = g_main:Bind("cd_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("cd_key_tip")
	ui.key:Properties(L("cd_bind_name"), nil, true)
end

ui.enable:SetCallback(function()
	ui.key:Disabled(not ui.enable:Get())
end, true)

local cfg = {}
do
	local defaults = {
		source = 0, rank = 2, volume = 1, zoom = 100, bg = 88, blur = 1, tips = 1, auto = 1, debug = 0,
		panel = 1, pview = 0, pzoom = 100, pshop = 0, padapt = 1, pick_ask = 1, lanes = 1,
	}
	for key, value in pairs(defaults) do
		cfg[key] = Config.ReadInt("draft_helper", "set_" .. key, value)
	end
	if cfg.pview > 1 then
		cfg.pview = 0
	end
end

local function set_cfg(key, value)
	cfg[key] = value
	Config.WriteInt("draft_helper", "set_" .. key, value)
end

local function log(fmt, ...)
	if cfg.debug == 1 then
		Log.Write("[Draft Helper] " .. fmt:format(...))
	end
end

local K = {
	VERSION = "1.4.0",
	UPDATE_URL = "https://raw.githubusercontent.com/But3rflys/umbrella-work/main/scripts/draft_helper/version.json",
	UPDATE_EVERY = 6 * 3600,
	UPDATE_MIN_SIZE = 50000,
	UPDATE_RELOAD_DELAY = 1.2,
	SCRIPT_NAME = "draft_helper.lua",

	DATA_URLS = {
		"https://raw.githubusercontent.com/But3rflys/umbrella-work/draft-data/",
		"https://cdn.jsdelivr.net/gh/But3rflys/umbrella-work@draft-data/",
	},
	DATA_CHECK = 3 * 3600,
	DATA_AT = 3 * 3600 + 10 * 60,
	MSK_SHIFT = 3 * 3600,
	HEADERS = { ["User-Agent"] = "Umbrella/draft_helper", ["Accept"] = "application/json" },
	TIMEOUT = 40,
	RETRY = 60,
	RETRY_SHORT = 5,
	STUCK = 25,
	GAP = 1.1,
	CONFIG = "draft_helper",
	CACHE_FILE = "configs\\draft_helper.dat",
	CACHE_MAGIC = "DHC3",
	CACHE_KEYS = 6,

	CM_MAX = 40000,
	CM_DAYS = 60,
	RANKS = { 0, 60, 70, 75 },
	VOLUMES = { 50000, 100000, 200000 },

	PRIOR_BASE = 200,
	PRIOR_PAIR = 1000,
	PRIOR_POS = 12,
	PRIOR_CM = 300,
	PRIOR_CM_PAIR = 60,
	POS_FLOOR = 0.01,
	ADV_W = 1.2,
	RARE_W = 0.03,
	COUNTER_EXTRA = 0.5,
	COUNTERED_EXTRA = 0.5,
	SYN_W = 0.5,
	FIT_MIN = 0.1,
	FIT_W = 0.025,
	BASE_W = 0.25,
	CONTEST_W = 0.05,
	MIN_GAMES = 150,
	LIST_MAX = 40,
	REASONS = 2,
	REASON_MIN = 0.3,
	ORDER_W = 0.05,
	PICK_ORDER = {
		{ 0.13, 0.20, 0.14, 0.26, 0.27 },
		{ 0.07, 0.10, 0.14, 0.33, 0.35 },
		{ 0.13, 0.12, 0.27, 0.24, 0.23 },
		{ 0.27, 0.28, 0.22, 0.12, 0.11 },
		{ 0.40, 0.29, 0.21, 0.05, 0.05 },
	},
	POS_MIN = 0.2,
	COMP_ROWS = 6,
	SUM_MIN = 0.3,

	ORDER = "BF BF BS BS BF BS BS PF PS BF BF BS PS PF PF PS PS PF BF BS BF BS PF PS",
	FREE_PICKS = 10,
	SYNC_EVERY = 0.5,
	SYNC_MODES = {
		[Enum.GameMode.DOTA_GAMEMODE_AP] = true,
		[Enum.GameMode.DOTA_GAMEMODE_TURBO] = true,
		[Enum.GameMode.DOTA_GAMEMODE_ALL_DRAFT] = true,
		[Enum.GameMode.DOTA_GAMEMODE_SD] = true,
	},
	MODE_SD = Enum.GameMode.DOTA_GAMEMODE_SD,
	GRID = "HeroGrid",
	TEAM_PANELS = { "RadiantTeamPlayers", "DireTeamPlayers" },
	GRID_CARD = "HeroCard",
	GRID_OFF = "Unavailable",
	GRID_CARD_UP = 3,
	GRID_DEPTH = 20,
	GRID_MIN = 60,
	SD_OFFER_MAX = 4,
	PANEL_DEPTH = 14,
	TEAM_DIRE = Enum.TeamNum.TEAM_DIRE,
	MATCH_STATES = {
		[Enum.GameState.DOTA_GAMERULES_STATE_HERO_SELECTION] = true,
		[Enum.GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME] = true,
		[Enum.GameState.DOTA_GAMERULES_STATE_TEAM_SHOWCASE] = true,
		[Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME] = true,
		[Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS] = true,
	},
	LANE_BITS = { [1] = 1, [2] = 3, [4] = 2, [8] = 4, [16] = 5 },
	TENTATIVE = 0.45,
	HERO_SELECTION = Enum.GameState.DOTA_GAMERULES_STATE_HERO_SELECTION,
	MODE_CM = Enum.GameMode.DOTA_GAMEMODE_CM,
	STRATEGY = Enum.GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME,

	W = 960,
	PAD = 16,
	HEAD_H = 44,
	MAIN_H = 500,
	TL_W = 186,
	TL_HEAD = 30,
	TL_GAP = 18,
	TL_STEP = 14.5,
	TL_SAME = 3,
	PICK_W = 50,
	PICK_H = 28,
	BAN_W = 36,
	BAN_H = 20,
	GRID_W = 330,
	SEARCH_H = 32,
	CELL_H = 21,
	CELL_GAP = 3,
	COL_GAP = 6,
	BTN = 27,
	SET_ROW = 28,
	ROW = 40,
	ROW_COMP = 56,
	RADIUS = 12,
	SCROLL = 44,
	FADE = 0.15,
	CLICK_GUARD = 0.3,
	FONTS = { "Inter", "Segoe UI" },
	BASE_ZOOM = 1.1,
	SLIDER_GAP = 18,
	CM_NOTE_H = 44,
	POS_ICON = { "safelane", "midlane", "offlane", "softsupport", "hardsupport" },
	POS_COLOR = { Color(240, 177, 74), Color(98, 168, 255), Color(239, 111, 94), Color(95, 208, 138), Color(181, 140, 255) },
	TIP_DELAY = 0.3,
	TIP_FADE = 0.1,
	TIP_HOLD = 0.08,
	TIP_GRACE = 0.3,
	PAGE_TIME = 0.28,
	NEWS_IN = 0.26,
	NEWS_OUT = 0.16,
	NEWS_SLIDE = 14,
	PAGE_SLIDE = 10,
	POP = 0.22,
	MOVE = 0.18,
	STAGGER = 0.022,
	ROW_IN = 0.2,
	SLIDE = 12,
	TYPE_GAP = 0.15,
	ROUND = Enum.DrawFlags.RoundCornersAll,

	MOUSE1 = Enum.ButtonCode.KEY_MOUSE1,
	MOUSE2 = Enum.ButtonCode.KEY_MOUSE2,
	LSHIFT = Enum.ButtonCode.KEY_LSHIFT,
	RSHIFT = Enum.ButtonCode.KEY_RSHIFT,
	WHEEL_UP = Enum.ButtonCode.KEY_MWHEELUP,
	WHEEL_DOWN = Enum.ButtonCode.KEY_MWHEELDOWN,
	BACKSPACE = Enum.ButtonCode.KEY_BACKSPACE,
	ENTER = Enum.ButtonCode.KEY_ENTER,
	PAD_ENTER = Enum.ButtonCode.KEY_PAD_ENTER,
	ESCAPE = Enum.ButtonCode.KEY_ESCAPE,
	KEY_DOWN = Enum.EKeyEvent.EKeyEvent_KEY_DOWN,
	KEY_UP = Enum.EKeyEvent.EKeyEvent_KEY_UP,
	SCROLL_UP = Enum.EKeyEvent.EKeyEvent_SCROLL_UP,
	SCROLL_DOWN = Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN,

	WIN_MIN = 20,
	BUYS_MIN = 30,
	BUYS_KEEP = 30,
	ITEM_RETRY = 15,
	ITEM_FAIL_SKIP = 60,
	START_GOLD = 600,
	START_MIN = 0.35,
	STACK = {
		branches = 3, tango = 2, ward_sentry = 2, ward_observer = 2, flask = 2, clarity = 2, enchanted_mango = 2,
		blood_grenade = 2, faerie_fire = 2,
	},
	SLOTS = 6,
	SLOT_MIN_COST = 1000,
	SLOT_EXTRA = { blink = true, ghost = true },
	SLOT_SKIP = { ultimate_scepter_2 = true, ward_dispenser = true, rapier = true },
	EARLY_EXTRA = { bottle = true },
	EARLY_SHARE = 0.5,
	EARLY_T = 900,
	EARLY_MIN_COST = 300,
	EARLY_MAX = 3,
	BOOTS = {
		power_treads = true, phase_boots = true, arcane_boots = true, tranquil_boots = true, travel_boots = true,
		travel_boots_2 = true, guardian_greaves = true, boots_of_bearing = true,
	},
	ITEM_SHARE = 0.15,
	ITEM_SHARE_FULL = 0.25,
	ITEM_COUNTER_W = 0.4,
	ITEM_UPGRADE = 0.5,
	CORE_LOCK = 3,
	SIBLING_COST = 800,
	UPGRADE_MIN = 0.15,
	PRE_SHARE = 0.3,
	PRE_COST = 1500,
	PRE_GAP = 180,
	DISASSEMBLE = {
		mask_of_madness = true, echo_sabre = true, pers = true, vanguard = true, vladmir = true, sange_and_yasha = true,
		kaya_and_sange = true, yasha_and_kaya = true, radiance = true, angels_demise = true,
	},
	KEEP_MAX = 0.75,
	AFTER_SHARE = 0.2,
	AFTER_GAP = 480,
	SPARE_MIN = 0.4,
	VS_MIN = 0.2,
	VS_MAX = 3,
	ROLE_MAGIC = 0.4,
	ROLE_DISABLE = 0.5,
	ROLE_PHYS_AGI = 0.6,
	ROLE_PHYS_STR = 0.35,
	COUNTERS = {},
	FIT = {},
	MUST = {},
	MUST_MAX = 2,
	MUST_COVER = 0.5,
	PHYS_MIN = 0.8,
	PHYS_ITEMS = {},
	REACT = {},
	REACT_MAX = 2,
	REACT_RATE = 0.03,
	RATE_MIN_GAMES = 60,
	PANEL_EVERY = 0.5,
	QFLASH = 0.4,
	STRIP_COLS = 8,
	SUM_STEP_W = 56,
	PANEL_STATES = {
		[Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME] = true,
		[Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS] = true,
	},
	INV_LAST = 14,
	ENEMY_INV_LAST = 8,
	SWAP_MARGIN = 0.12,
	SWAPS_MAX = 2,
	SIGNAL_MIN = 700,
	SKIP_GAP = 420,
	MORE_COST = 2000,
	MORE_SHARE = 0.08,
	MORE_GAP = 300,
	MORE_POP = 0.2,
	MORE_MAX = 3,
	MORE_UP = 0.1,
	KEEP_MIN = 10,
	ITEM_THREAT_MIN = 2,
	MORE_SKIP = { rapier = true, ward_dispenser = true },
	BLESSING = "ultimate_scepter_2",
	BOOTS_UP = { "travel_boots", "guardian_greaves", "boots_of_bearing" },
	SELL_MAX = 2000,
	SELL_RATIO = 0.5,
	LANE_W = 0.5,
	LANE_OPP = {
		{ [3] = true, [4] = true }, { [2] = true }, { [1] = true, [5] = true },
		{ [1] = true, [5] = true }, { [3] = true, [4] = true },
	},
	SUPPORT_ITEM_W = 0.67,
	SELL_HARD = 4,
	SELL_BOOTS = { power_treads = true, phase_boots = true, arcane_boots = true, tranquil_boots = true },
	SELL_BOOTS_FOR = 3500,
	SELL_COUNTER = 0.3,
	BACKPACK = 3,
	SHARD = "aghanims_shard",
	SHARD_MOD = "modifier_item_aghanims_shard",
	CONSUME_SHARE = 0.25,
	NO_SLOT = { aghanims_shard = true, ultimate_scepter_2 = true },
	ANTI_HARD = 0.5,
	ANTI_KEEP = 0.5,
	INSTEAD = {},
	INSTEAD_SHARE = 0.05,
	INSTEAD_COST = 0.6,
	DIS_SHARE = 0.1,
	DIS_KEEP = 0.4,
	PICK_CHECK = 1.5,
	BUY_GAP = 0.15,
	TOAST = 2.5,
	SELL_SKIP = {
		aegis = true, cheese = true, gem = true, ward_dispenser = true, dust = true, smoke_of_deceit = true,
		refresher_shard = true, tpscroll = true, boots = true,
	},
	CNT_MAX = 30,
	NEWS = {
		{ "n", "\u{f245}", "cd_nw1_t", "cd_nw1" },
		{ "n", "\u{f07a}", "cd_nw2_t", "cd_nw2" },
		{ "n", "\u{f0e8}", "cd_nw3_t", "cd_nw3" },
		{ "n", "\u{f005}", "cd_nw4_t", "cd_nw4" },
		{ "n", "\u{f062}", "cd_nw5_t", "cd_nw5" },
		{ "f", "\u{f0e7}", "cd_nw6_t", "cd_nw6" },
	},
	COVER = 0.8,
	ENEMY_ITEMS = {},
	ANTI = {},
}

K.FREE = {}
for i = 1, 10 do
	K.FREE[i] = { kind = "P", team = i <= 5 and 0 or 1, group = i <= 5 and "us" or "enemy" }
end
for i = 11, 20 do
	K.FREE[i] = { kind = "B", team = 0, group = "ban" }
end

K.STEPS = {}
for token in K.ORDER:gmatch("%S+") do
	K.STEPS[#K.STEPS + 1] = { kind = token:sub(1, 1), side = token:sub(2, 2) == "F" and 0 or 1 }
end

K.CHARS = {}
for i = 0, 25 do
	local letter = string.char(65 + i)
	local code = Enum.ButtonCode["KEY_" .. letter]
	if code then
		K.CHARS[code] = letter:lower()
	end
end
for i = 0, 9 do
	local code = Enum.ButtonCode["KEY_" .. i]
	if code then
		K.CHARS[code] = tostring(i)
	end
end
K.CHARS[Enum.ButtonCode.KEY_SPACE] = " "

K.TYPE_KEYS = { K.BACKSPACE, K.ENTER, K.PAD_ENTER, K.ESCAPE }
for code in pairs(K.CHARS) do
	K.TYPE_KEYS[#K.TYPE_KEYS + 1] = code
end

local P = {
	BG = Color(14, 16, 18, 255),
	TEXT = Color(240, 240, 242, 255),
	MUTED = Color(150, 154, 160, 255),
	DIM = Color(92, 96, 102, 255),
	GOOD = Color(111, 214, 111, 255),
	BAD = Color(232, 98, 90, 255),
	LINE = Color(255, 255, 255, 18),
	CELL = Color(255, 255, 255, 10),
	FIELD = Color(255, 255, 255, 15),
	CHIP_ON = Color(255, 255, 255, 36),
	HOVER = Color(255, 255, 255, 13),
	SEP = Color(255, 255, 255, 46),
	SHADE = Color(0, 0, 0, 150),
	WARN = Color(236, 178, 82, 255),
	TIP = Color(15, 17, 20, 255),
	TIP_EDGE = Color(255, 255, 255, 46),
	CARD = Color(24, 27, 30, 255),
	WHITE = Color(255, 255, 255, 255),
	BAN = Color(170, 170, 170, 255),
	USED = Color(90, 90, 90, 255),
}

local D = {
	loaded = false,
	heroes = nil,
	by_id = {},
	by_unit = {},
	by_attr = { str = {}, agi = {}, int = {}, all = {} },
	heroes_at = 0,
	pos_count = nil,
	pos_at = 0,
	contest = nil,
	pos_prob = {},
	sets = nil,
	busy = false,
	next_request = 0,
	error = nil,
	status = nil,
}

local draft = {
	first = 0,
	mode = 0,
	store = { [0] = {}, [1] = {} },
	history = { [0] = {}, [1] = {} },
	target = nil,
	manual = { [0] = {}, [1] = {} },
	known_pos = {},
	tentative = {},
	me = nil,
	my_role = nil,
	filter_user = false,
	sync_at = 0,
	sync_sig = nil,
	steps = {},
	edit = nil,
	match = nil,
	query = "",
	filter = 0,
	dirty = true,
	result = nil,
	slot_pos = {},
	chance = nil,
	vs_cache = {},
	summary = nil,
	summary_sig = nil,
	build_h = nil,
	extra_bans = {},
	extra_key = nil,
}

draft.steps = draft.store[0]

local W = {
	open = false,
	auto = false,
	vis = 0,
	x = nil,
	y = nil,
	w = 0,
	h = 0,
	drag = false,
	dx = 0,
	dy = 0,
	hits = {},
	swallow = {},
	click_at = -1,
	scroll_at = -1,
	grid_scroll = 0,
	list_scroll = 0,
	grid_rect = nil,
	list_rect = nil,
	images = {},
	fonts = nil,
	focus = false,
	anim = {},
	placed = {},
	typed = {},
	held = {},
	settings = false,
	set_gear = nil,
	gear_pop = nil,
	gear_block = nil,
	gear_anchor = {},
	preview = false,
	pos_menu = nil,
	pm_last = nil,
	badge_rect = {},
	tip_cand = nil,
	tip_id = nil,
	tip_t = 0,
	tip_last = nil,
	list_t0 = 0,
	step_t = 0,
	step_c = false,
	snap = false,
}

local function cheat_path(sub)
	local dir = Engine.GetCheatDirectory()
	if not dir:match("[\\/]$") then
		dir = dir .. "\\"
	end
	return dir .. sub
end

local store, store_save, store_load

do
	local function read_path(path)
		local f = io.open(path, "rb")
		if not f then
			return nil
		end
		local text = f:read("a")
		f:close()
		return text
	end

	local function write_path(path, text)
		local tmp = path .. ".tmp"
		local f = io.open(tmp, "wb")
		if not f then
			return false
		end
		f:write(text)
		f:close()
		os.remove(path)
		if not os.rename(tmp, path) then
			f = io.open(path, "wb")
			if f then
				f:write(text)
				f:close()
			end
			os.remove(tmp)
		end
		return true
	end

	local function decode(text)
		if type(text) ~= "string" or text == "" then
			return nil
		end
		local ok, data = pcall(JSON.decode, JSON, text)
		return (ok and type(data) == "table") and data or nil
	end

	store = { data = { sets = {}, files = {}, buys = {} }, blobs = {} }

	local function evict()
		local keys = {}
		for key in pairs(store.blobs) do
			if key:sub(1, 2) == "s:" then
				keys[#keys + 1] = key
			end
		end
		if #keys <= K.CACHE_KEYS then
			return
		end
		table.sort(keys, function(x, y)
			local mx, my = store.data.sets[x] or {}, store.data.sets[y] or {}
			return (tonumber(mx.used) or 0) > (tonumber(my.used) or 0)
		end)
		for i = K.CACHE_KEYS + 1, #keys do
			store.blobs[keys[i]] = nil
			store.data.sets[keys[i]] = nil
		end
	end

	function store_save()
		evict()
		local keys = {}
		for key, blob in pairs(store.blobs) do
			if #blob > 0 then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys)
		store.data.blob_keys = keys
		local ok, text = pcall(JSON.encode, JSON, store.data)
		if not ok then
			return
		end
		local parts = { string.pack("<c4I4", K.CACHE_MAGIC, #text), text }
		for _, key in ipairs(keys) do
			local blob = store.blobs[key]
			parts[#parts + 1] = string.pack("<I4", #blob)
			parts[#parts + 1] = blob
		end
		write_path(cheat_path(K.CACHE_FILE), table.concat(parts))
	end

	local function store_read(blob)
		local n = string.unpack("<I4", blob, 5)
		local data = decode(blob:sub(9, 8 + n))
		if not data then
			error("broken cache")
		end
		for _, key in ipairs({ "sets", "files", "buys" }) do
			data[key] = type(data[key]) == "table" and data[key] or {}
		end
		local pos = 9 + n
		local blobs = {}
		for _, key in ipairs(type(data.blob_keys) == "table" and data.blob_keys or {}) do
			local len = string.unpack("<I4", blob, pos)
			local part = blob:sub(pos + 4, pos + 3 + len)
			if #part ~= len then
				error("broken cache")
			end
			blobs[key] = part
			pos = pos + 4 + len
		end
		return data, blobs
	end

	function store_load()
		local blob = read_path(cheat_path(K.CACHE_FILE))
		if blob and #blob >= 8 and blob:sub(1, 4) == K.CACHE_MAGIC then
			local ok, data, blobs = pcall(store_read, blob)
			if ok then
				store.data, store.blobs = data, blobs
				return
			end
			log("cache file broken, starting fresh")
		end
	end
end

local function logit(p)
	return math.log(p / (1 - p))
end

local function sigm(x)
	return 1 / (1 + math.exp(-x))
end

local function clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end

local function norm(s)
	return (s:lower():gsub("[^%w]", ""))
end

local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function set_heroes(list)
	local heroes = {}
	D.by_id = {}
	D.by_unit = {}
	D.by_attr = { str = {}, agi = {}, int = {}, all = {} }
	for _, h in ipairs(list) do
		local id = math.tointeger(tonumber(h.id))
		if id and id > 0 and id < 256 and type(h.name) == "string" and type(h.localized_name) == "string" then
			local label = h.localized_name
			local initials = {}
			for word in label:gsub("'", ""):gmatch("%w+") do
				initials[#initials + 1] = word:sub(1, 1):lower()
			end
			local hero = {
				id = id,
				unit = h.name,
				name = label,
				attr = D.by_attr[h.primary_attr] and h.primary_attr or "all",
				roles = type(h.roles) == "table" and h.roles or {},
				melee = h.attack_type == "Melee",
				key = norm(label),
				short = norm(h.name:gsub("^npc_dota_hero_", "")),
				initials = table.concat(initials),
			}
			hero.words = {}
			for word in label:lower():gsub("'", ""):gmatch("%w+") do
				hero.words[#hero.words + 1] = word
			end
			heroes[#heroes + 1] = hero
			D.by_id[id] = hero
			D.by_unit[hero.unit] = hero
			table.insert(D.by_attr[hero.attr], hero)
		end
	end
	for _, group in pairs(D.by_attr) do
		table.sort(group, function(a, b)
			return a.name < b.name
		end)
	end
	D.heroes = heroes
	D.pos_prob = {}
	draft.dirty = true
end

local function set_pos(rows)
	local count = {}
	for _, row in ipairs(rows) do
		local h, pos, n = tonumber(row.h), tonumber(row.pos), tonumber(row.n)
		if h and pos and n and pos >= 1 and pos <= 5 then
			count[h] = count[h] or { 0, 0, 0, 0, 0 }
			count[h][pos] = count[h][pos] + n
		end
	end
	D.pos_count = count
	D.pos_prob = {}
	draft.dirty = true
end

local function set_contest(rows)
	local contest = {}
	for _, row in ipairs(rows) do
		local h, c, n = tonumber(row.h), tonumber(row.c), tonumber(row.n)
		if h and c and n and n > 0 then
			contest[h] = c / n
		end
	end
	D.contest = contest
	draft.dirty = true
end

local function new_set(source)
	return { source = source, stats = nil, updated = 0, oldest = nil, gh_key = nil }
end

D.sets = { [0] = new_set(0), [1] = new_set(1) }

local function source()
	return cfg.source == 1 and 1 or 0
end

local function want(S)
	local target = K.VOLUMES[cfg.volume + 1] or 100000
	if S.source == 1 then
		target = math.min(target, K.CM_MAX)
	end
	return K.RANKS[cfg.rank + 1] or 70, target
end

local function request(url, param, on_done)
	D.busy = true
	D.req_n = (D.req_n or 0) + 1
	local id = D.req_n
	D.req_at, D.req_param = os.clock(), param
	local sent = HTTP.Request("GET", url, { headers = K.HEADERS, timeout = K.TIMEOUT }, function(res)
		if id ~= D.req_n then
			return
		end
		D.busy = false
		D.next_request = os.clock() + K.GAP
		local ok, err = pcall(on_done, res)
		if not ok then
			D.error = tostring(err):gsub("^.-:%d+: ", "")
			local short = D.fast or D.error:lower():find("timeout", 1, true)
			D.fast = nil
			D.next_request = os.clock() + (short and K.RETRY_SHORT or K.RETRY)
			if D.error ~= D.logged_error then
				D.logged_error = D.error
				Log.Write("[Draft Helper] " .. param .. " failed: " .. D.error)
			end
		end
	end, param)
	if not sent then
		D.busy = false
		D.error = "request was not sent"
		D.next_request = os.clock() + K.RETRY
	end
end

local function data_tick()
	if not D.loaded then
		D.loaded = true
		store_load()
		D.gh.restore()
	end
	if D.busy and os.clock() - D.req_at > K.TIMEOUT + K.STUCK then
		D.req_n, D.busy = D.req_n + 1, false
		D.error, D.next_request = "no answer, timeout", os.clock() + K.RETRY_SHORT
		Log.Write(("[Draft Helper] %s: no answer in %d s, retrying"):format(tostring(D.req_param), K.TIMEOUT + K.STUCK))
	end
	D.gh.sync()
	if D.busy or os.clock() < D.next_request then
		return
	end
	D.gh.tick()
end

local function refresh_data()
	D.gh.check_at, D.gh.manual = 0, true
	D.next_request, D.error = 0, nil
	log("manual refresh")
end

D.gh = { manifest = nil, check_at = 0, base = 1, done = 0 }

do
	local GH = D.gh

	function GH.url(name)
		return K.DATA_URLS[GH.base] .. name
	end

	function GH.flip()
		GH.base = GH.base % #K.DATA_URLS + 1
	end

	function GH.key(S)
		local rank, target = want(S)
		return ("%d:%d:%d"):format(S.source, rank, target)
	end

	local function sets()
		return source() == 1 and { D.sets[0], D.sets[1] } or { D.sets[0] }
	end

	local function get(name, param, on_body)
		request(GH.url(name), param, function(res)
			if tostring(res.code) ~= "200" or type(res.response) ~= "string" or res.response == "" then
				GH.flip()
				D.fast = true
				error(("%s: http %s %s"):format(param, tostring(res.code), tostring(res.error_message or "")))
			end
			local ok, err = pcall(on_body, res.response)
			if not ok then
				GH.flip()
				D.fast = true
				error(err, 0)
			end
			GH.done = GH.done + 1
			D.error = nil
		end)
	end

	local function file(name)
		local blob = store.blobs["d:" .. name]
		if not blob then
			return nil
		end
		local ok, data = pcall(JSON.decode, JSON, blob)
		return ok and type(data) == "table" and data or nil
	end

	local function keep(name, text, t)
		store.blobs["d:" .. name] = text
		store.data.files[name] = t
		GH.dirty = true
	end

	local function parse_stats(text)
		local st = { bg = {}, bw = {}, vg = {}, vw = {}, sg = {}, sw = {}, n = tonumber(text:match("^n (%d+)")) }
		if not st.n then
			error("stats: bad file")
		end
		local games = { b = st.bg, v = st.vg, s = st.sg }
		local wins = { b = st.bw, v = st.vw, s = st.sw }
		for kind, key, g, w in text:gmatch("(%a) (%d+) (%d+) (%d+)") do
			local gt = games[kind]
			if gt then
				key, w = tonumber(key), tonumber(w)
				gt[key] = tonumber(g)
				if w > 0 then
					wins[kind][key] = w
				end
			end
		end
		local counts = {}
		for _, g in pairs(st.bg) do
			if g >= K.MIN_GAMES then
				counts[#counts + 1] = g
			end
		end
		table.sort(counts)
		st.median = counts[math.max(1, math.floor(#counts / 2))] or 1
		return st
	end

	local function apply(S, key, st, meta)
		S.stats, S.gh_key = st, key
		S.updated = tonumber(meta.time) or 0
		S.oldest = tonumber(meta.oldest)
		draft.dirty = true
	end

	local function table_of(v)
		return type(v) == "table" and v or {}
	end

	function GH.rules(r)
		if type(r) ~= "table" or r.v ~= 1 then
			return false
		end
		K.COUNTERS, K.FIT, K.ANTI = table_of(r.counters), table_of(r.fit), table_of(r.anti)
		K.ENEMY_ITEMS, K.REACT, K.PHYS_ITEMS = table_of(r.enemy_items), table_of(r.react), table_of(r.phys_items)
		K.INSTEAD = table_of(r.instead)
		local must = {}
		for _, mu in ipairs(table_of(r.must)) do
			local pos = {}
			for _, p in ipairs(table_of(mu.pos)) do
				pos[math.tointeger(p) or p] = true
			end
			must[#must + 1] = { mu.threat, tonumber(mu.min) or 1, pos, mu.phys == true }
		end
		K.MUST = must
		D.tags = table_of(r.heroes)
		D.rules_ok, D.rules_rev = true, (D.rules_rev or 0) + 1
		draft.dirty = true
		return true
	end

	function GH.restore()
		local files = store.data.files
		local heroes = file("heroes")
		if heroes and #heroes >= 100 then
			set_heroes(heroes)
			D.heroes_at = tonumber(files.heroes) or 0
		end
		local pro = file("pro")
		if pro and type(pro.pos) == "table" and type(pro.contest) == "table" then
			set_pos(pro.pos)
			set_contest(pro.contest)
			D.pos_at = tonumber(files.pro) or 0
		end
		if GH.rules(file("rules")) then
			D.rules_at = tonumber(files.rules) or 0
		end
	end

	function GH.sync()
		for _, S in ipairs(sets()) do
			local key = GH.key(S)
			if S.gh_key ~= key then
				S.stats, S.gh_key, S.updated, S.oldest = nil, key, 0, nil
				local blob, meta = store.blobs["s:" .. key], store.data.sets["s:" .. key]
				if blob and type(meta) == "table" then
					local ok, st = pcall(parse_stats, blob)
					if ok then
						meta.used = os.time()
						apply(S, key, st, meta)
						log("github stats %s from cache: %d matches", key, st.n)
					end
				end
				draft.dirty = true
			end
		end
	end

	function GH.pending()
		local list = {}
		local m = GH.manifest
		if not m or os.clock() >= GH.check_at then
			list[1] = { kind = "manifest" }
			return list
		end
		local t = tonumber(m.heroes) or 0
		if not D.heroes or (D.heroes_at or 0) < t then
			list[#list + 1] = { kind = "heroes", t = t }
		end
		t = tonumber(m.pro) or 0
		if not D.pos_count or not D.contest or (D.pos_at or 0) < t then
			list[#list + 1] = { kind = "pro", t = t }
		end
		t = tonumber(m.rules) or 0
		if t > 0 and (not D.rules_ok or (D.rules_at or 0) < t) then
			list[#list + 1] = { kind = "rules", t = t }
		end
		for _, S in ipairs(sets()) do
			local key = S.gh_key
			local meta = key and m.sets[key]
			if type(meta) == "table" and (not S.stats or S.updated < (tonumber(meta.time) or 0)) then
				list[#list + 1] = { kind = "stats", S = S, key = key, meta = meta }
			end
		end
		return list
	end

	function GH.progress()
		local list = GH.pending()
		return GH.done, GH.done + #list, list[1]
	end

	function GH.tick()
		local job = GH.pending()[1]
		if not job then
			if GH.dirty then
				GH.dirty = false
				store_save()
			end
			if GH.manual then
				GH.manual = false
				GH.note, GH.note_at = GH.done > 1 and "cd_gh_new" or "cd_gh_same", os.clock()
			end
			GH.done = 0
			D.status = nil
			return
		end
		D.status = "cd_st_gh"
		if job.kind == "manifest" then
			get("manifest.json", "cd_manifest", function(text)
				local data = JSON:decode(text)
				if type(data) ~= "table" or type(data.sets) ~= "table" then
					error("manifest: bad file")
				end
				GH.manifest = data
				GH.check_at = os.clock() + K.DATA_CHECK
				log("github data from %s", os.date("%Y-%m-%d %H:%M", tonumber(data.time) or 0))
			end)
		elseif job.kind == "heroes" then
			get("heroes.json", "cd_heroes", function(text)
				local list = JSON:decode(text)
				if type(list) ~= "table" or #list < 100 then
					error("heroes: bad list")
				end
				set_heroes(list)
				D.heroes_at = job.t
				keep("heroes", text, job.t)
				log("heroes loaded: %d", #D.heroes)
			end)
		elseif job.kind == "pro" then
			get("pro.json", "cd_pro", function(text)
				local pro = JSON:decode(text)
				if type(pro) ~= "table" or type(pro.pos) ~= "table" or type(pro.contest) ~= "table" then
					error("pro: bad file")
				end
				set_pos(pro.pos)
				set_contest(pro.contest)
				D.pos_at = job.t
				keep("pro", text, job.t)
				log("pro data loaded")
			end)
		elseif job.kind == "rules" then
			get("rules.json", "cd_rules", function(text)
				if not GH.rules(JSON:decode(text)) then
					error("rules: bad file")
				end
				D.rules_at = job.t
				keep("rules", text, job.t)
				log("counter rules loaded")
			end)
		else
			local key, meta, S = job.key, job.meta, job.S
			get(("stats/%s.txt"):format((key:gsub(":", "_"))), "cd_stats", function(text)
				local st = parse_stats(text)
				store.blobs["s:" .. key] = text
				store.data.sets["s:" .. key] = { time = tonumber(meta.time) or 0, oldest = meta.oldest, used = os.time() }
				GH.dirty = true
				if S.gh_key == key then
					apply(S, key, st, meta)
				end
				log("stats %s: %d matches", key, st.n)
			end)
		end
	end
end

local U = {
	status = "idle",
	remote = nil,
	url = nil,
	checked = 0,
	error = nil,
	reload_at = nil,
	busy = false,
}

do
	local function parts(v)
		local out = {}
		for n in tostring(v or ""):gmatch("%d+") do
			out[#out + 1] = tonumber(n)
		end
		return out
	end

	local function newer(a, b)
		local x, y = parts(a), parts(b)
		for i = 1, math.max(#x, #y) do
			local p, q = x[i] or 0, y[i] or 0
			if p ~= q then
				return p > q
			end
		end
		return false
	end

	local function script_path()
		local ok, info = pcall(function()
			return debug and debug.getinfo and debug.getinfo(1, "S")
		end)
		local src = ok and type(info) == "table" and info.source or nil
		if type(src) == "string" and src:sub(1, 1) == "@" and src:lower():find("%.lua$") then
			return src:sub(2)
		end
		return cheat_path("scripts\\" .. K.SCRIPT_NAME)
	end

	local function fail(msg)
		U.status, U.error, U.busy = "error", msg, false
		Log.Write("[Draft Helper] update: " .. msg)
	end

	function U.check()
		if U.busy then
			return
		end
		U.busy, U.status, U.error = true, "checking", nil
		local sent = HTTP.Request("GET", K.UPDATE_URL, { headers = K.HEADERS, timeout = 20 }, function(res)
			U.busy = false
			U.checked = os.time()
			if tostring(res.code) ~= "200" then
				fail("check: http " .. tostring(res.code) .. " " .. tostring(res.error_message or ""))
				return
			end
			local ok, data = pcall(JSON.decode, JSON, res.response)
			if not ok or type(data) ~= "table" or type(data.version) ~= "string" or type(data.url) ~= "string" then
				fail("check: bad version.json")
				return
			end
			U.remote, U.url = data.version, data.url
			U.status = newer(data.version, K.VERSION) and "available" or "latest"
			log("update check: local %s, remote %s -> %s", K.VERSION, data.version, U.status)
		end, "cd_update")
		if not sent then
			fail("check: request was not sent")
		end
	end

	function U.install()
		if U.busy or U.status ~= "available" or not U.url then
			return
		end
		U.busy, U.status, U.error = true, "downloading", nil
		local want = U.remote
		local sent = HTTP.Request("GET", U.url, { headers = K.HEADERS, timeout = 60 }, function(res)
			if tostring(res.code) ~= "200" or type(res.response) ~= "string" then
				fail("download: http " .. tostring(res.code) .. " " .. tostring(res.error_message or ""))
				return
			end
			local text = res.response
			if #text < K.UPDATE_MIN_SIZE then
				fail("download: file too small")
				return
			end
			local version = text:match('VERSION = "([^"]+)"')
			if version ~= want then
				fail("download: version inside is " .. tostring(version) .. ", expected " .. tostring(want))
				return
			end
			if type(load) == "function" then
				local chunk, err = load(text, "=draft_helper", "t")
				if not chunk then
					fail("download: file does not compile: " .. tostring(err))
					return
				end
			end
			local path = script_path()
			local tmp = path .. ".new"
			local f = io.open(tmp, "wb")
			if not f then
				fail("write: no access to " .. path)
				return
			end
			f:write(text)
			f:close()
			os.remove(path)
			if not os.rename(tmp, path) then
				local g = io.open(path, "wb")
				if not g then
					fail("write: could not replace " .. path)
					return
				end
				g:write(text)
				g:close()
				os.remove(tmp)
			end
			U.busy, U.status = false, "done"
			U.reload_at = os.clock() + K.UPDATE_RELOAD_DELAY
			Log.Write("[Draft Helper] updated to " .. want .. ", reloading scripts")
		end, "cd_update_file")
		if not sent then
			fail("download: request was not sent")
		end
	end

	function U.tick()
		if U.reload_at and os.clock() >= U.reload_at then
			U.reload_at = nil
			Engine.ReloadScriptSystem()
			return
		end
		if not U.busy and os.time() - U.checked > K.UPDATE_EVERY then
			U.check()
		end
	end
end

do
	local a, b, c = K.VERSION:match("(%d+)%.(%d+)%.(%d+)")
	K.VNUM = (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100 + (tonumber(c) or 0)
	local seen = Config.ReadInt("draft_helper", "seen", 0)
	if seen < K.VNUM then
		local f = io.open(cheat_path(K.CACHE_FILE), "rb")
		if f then
			f:close()
			W.news = true
		else
			Config.WriteInt("draft_helper", "seen", K.VNUM)
		end
	end
end

local M = {}

do
	local function ranked()
		return D.sets[0].stats
	end

	local function cm()
		return source() == 1 and D.sets[1].stats or nil
	end

	local function shrink(w, g, prior, weight)
		return (w + weight * prior) / (g + weight)
	end

	local function base_ranked(h)
		local st = ranked()
		return shrink(st.bw[h] or 0, st.bg[h] or 0, 0.5, K.PRIOR_BASE)
	end

	function M.base(h)
		local p = base_ranked(h)
		local c = cm()
		if c then
			p = shrink(c.bw[h] or 0, c.bg[h] or 0, p, K.PRIOR_CM)
		end
		return p
	end

	function M.rarity(h)
		local st = ranked()
		local g = st and st.bg[h] or 0
		local med = st and st.median or 1
		if g <= 0 or g >= med then
			return 0
		end
		return K.RARE_W * math.log(g / med)
	end

	function M.games(h)
		local st = ranked()
		return st and st.bg[h] or 0
	end

	function M.shown_games(h)
		local c = cm()
		if c then
			return c.bg[h] or 0
		end
		return M.games(h)
	end

	local function pair(st, a, b, versus)
		local key = a < b and a * 256 + b or b * 256 + a
		if versus then
			local g = st.vg[key] or 0
			local w = st.vw[key] or 0
			if a > b then
				w = g - w
			end
			return w, g
		end
		return st.sw[key] or 0, st.sg[key] or 0
	end

	local function expect(a, b, versus)
		if versus then
			return sigm(logit(a) - logit(b))
		end
		return sigm(logit(a) + logit(b))
	end

	local function effect(a, b, versus)
		local e_r = expect(base_ranked(a), base_ranked(b), versus)
		local w, g = pair(ranked(), a, b, versus)
		local fx = logit(shrink(w, g, e_r, K.PRIOR_PAIR)) - logit(e_r)
		local c = cm()
		if not c then
			return fx
		end
		local e_c = expect(M.base(a), M.base(b), versus)
		local prior = sigm(logit(e_c) + fx)
		local wc, gc = pair(c, a, b, versus)
		return logit(shrink(wc, gc, prior, K.PRIOR_CM_PAIR)) - logit(e_c)
	end

	function M.adv(a, b)
		return effect(a, b, true)
	end

	function M.syn(a, b)
		return effect(a, b, false)
	end

	function M.counters(h, used)
		local st = ranked()
		local rows = {}
		if not st then
			return rows
		end
		for _, hero in ipairs(D.heroes or {}) do
			local a = hero.id
			if a ~= h and not used[a] and M.games(a) >= K.MIN_GAMES then
				local e = expect(M.base(a), M.base(h), true)
				local p = sigm(logit(e) + effect(a, h, true))
				local _, g = pair(st, a, h, true)
				rows[#rows + 1] = { h = a, p = p, d = p - e, g = g }
			end
		end
		table.sort(rows, function(x, y)
			if x.d ~= y.d then
				return x.d > y.d
			end
			return x.h < y.h
		end)
		return rows
	end
end

function M.pos(h)
	local prob = D.pos_prob[h]
	if prob then
		return prob
	end
	local hero = D.by_id[h]
	local prior = { 0.2, 0.2, 0.2, 0.2, 0.2 }
	if hero then
		local carry, support = false, false
		for _, role in ipairs(hero.roles) do
			carry = carry or role == "Carry"
			support = support or role == "Support"
		end
		if carry and not support then
			prior = { 0.4, 0.3, 0.2, 0.05, 0.05 }
		elseif support and not carry then
			prior = { 0.02, 0.04, 0.08, 0.43, 0.43 }
		end
	end
	local count = D.pos_count and D.pos_count[h] or { 0, 0, 0, 0, 0 }
	local total = 0
	for i = 1, 5 do
		total = total + count[i]
	end
	prob = {}
	for i = 1, 5 do
		prob[i] = math.log(math.max(K.POS_FLOOR, (count[i] + K.PRIOR_POS * prior[i]) / (total + K.PRIOR_POS)))
	end
	D.pos_prob[h] = prob
	return prob
end

function M.assign(team, blocked)
	local n = #team
	if n == 0 then
		return 0, {}
	end
	local best, best_map = -math.huge, {}
	local map, used, probs = {}, {}, {}
	for i = 1, n do
		probs[i] = M.pos(team[i])
	end
	local function run(i, acc)
		if i > n then
			if acc > best then
				best = acc
				best_map = { table.unpack(map, 1, n) }
			end
			return
		end
		local pp = probs[i]
		for p = 1, 5 do
			if not used[p] and not (blocked and blocked[p]) then
				used[p] = true
				map[i] = p
				run(i + 1, acc + pp[p])
				used[p] = false
			end
		end
	end
	run(1, 0)
	return best, best_map
end

local I = {
	loaded = false,
	items = nil,
	by_name = {},
	items_at = 0,
	buys = {},
	buys_at = {},
	skip = {},
	busy = false,
	next_at = 0,
	error = nil,
	logged = nil,
	dirty = false,
	threat_of = {},
	builds = {},
	bpos = {},
}

do
	local function set_items(list)
		local items, by_name = {}, {}
		for _, it in ipairs(list) do
			local id = math.tointeger(tonumber(it.id))
			if id and type(it.n) == "string" then
				local parts = {}
				for part in tostring(it.p or ""):gmatch("[%w_]+") do
					parts[#parts + 1] = part
				end
				local item = {
					id = id,
					name = it.n,
					label = type(it.d) == "string" and it.d ~= "" and it.d or it.n,
					cost = tonumber(it.c) or 0,
					created = tonumber(it.m) == 1,
					parts = parts,
					recipe = math.tointeger(tonumber(it.r)),
				}
				items[id] = item
				by_name[item.name] = item
			end
		end
		I.items, I.by_name, I.builds = items, by_name, {}
	end

	local function set_buys(h, list)
		local by = {}
		for _, r in ipairs(list) do
			local p, name, n, g = math.tointeger(tonumber(r.p)), r.i, tonumber(r.n), tonumber(r.g)
			if p and p >= 1 and p <= 5 and type(name) == "string" and n and n > 0 and g and g > 0 then
				local d = by[p]
				if not d then
					d = { g = g, gw = 0, rows = {}, fin = {} }
					by[p] = d
				end
				d.g = math.max(d.g, g)
				d.gw = math.max(d.gw, tonumber(r.gw) or 0)
				local id = math.tointeger(tonumber(name:match("^#(%d+)$")))
				if id then
					d.fin[id] = n
				else
					d.rows[name] = { n = n, w = tonumber(r.w) or 0, t = tonumber(r.t) or 0, s = tonumber(r.s) or 0, m = tonumber(r.m) or 0 }
				end
			end
		end
		I.buys[h] = { pos = by }
		I.builds = {}
	end

	setmetatable(I.buys, {
		__index = function(_, h)
			local key = tostring(h)
			local text, meta = store.blobs["b:" .. key], store.data.buys[key]
			if not text or type(meta) ~= "table" then
				return nil
			end
			local ok, list = pcall(JSON.decode, JSON, text)
			if not ok or type(list) ~= "table" then
				store.blobs["b:" .. key] = nil
				return nil
			end
			set_buys(h, list)
			I.buys_at[h] = tonumber(meta.time) or 0
			return I.buys[h]
		end,
	})

	local function load()
		I.loaded = true
		local blob = store.blobs["d:items"]
		if blob then
			local ok, list = pcall(JSON.decode, JSON, blob)
			if ok and type(list) == "table" and #list >= 100 then
				set_items(list)
				I.items_at = tonumber(store.data.files.items) or 0
			end
		end
	end

	local function fetch(url, param, on_done)
		I.busy = true
		I.req_n = (I.req_n or 0) + 1
		local id = I.req_n
		I.req_at, I.req_param = os.clock(), param
		local sent = HTTP.Request("GET", url, { headers = K.HEADERS, timeout = K.TIMEOUT }, function(res)
			if id ~= I.req_n then
				return
			end
			I.busy = false
			I.next_at = os.clock() + K.GAP
			local ok, err = pcall(on_done, res)
			if ok then
				I.error = nil
				return
			end
			I.error = tostring(err):gsub("^.-:%d+: ", "")
			I.next_at = os.clock() + K.ITEM_RETRY
			if I.error ~= I.logged then
				I.logged = I.error
				Log.Write("[Draft Helper] " .. param .. " failed: " .. I.error)
			end
		end, param)
		if not sent then
			I.busy = false
			I.error = "request was not sent"
			I.next_at = os.clock() + K.ITEM_RETRY
		end
	end

	local function keep_buys(h, text)
		local buys = store.data.buys
		local key = tostring(h)
		buys[key] = { time = I.buys_at[h] }
		store.blobs["b:" .. key] = text
		local keys = {}
		for k in pairs(buys) do
			keys[#keys + 1] = k
		end
		if #keys > K.BUYS_KEEP then
			table.sort(keys, function(x, y)
				return (tonumber(buys[x].time) or 0) > (tonumber(buys[y].time) or 0)
			end)
			for n = K.BUYS_KEEP + 1, #keys do
				buys[keys[n]] = nil
				store.blobs["b:" .. keys[n]] = nil
			end
		end
		I.dirty = true
	end

	local function gh_fetch(name, param, on_body)
		fetch(D.gh.url(name), param, function(res)
			if tostring(res.code) ~= "200" or type(res.response) ~= "string" or res.response == "" then
				if tostring(res.code) ~= "404" then
					D.gh.flip()
				end
				error(("%s: http %s %s"):format(param, tostring(res.code), tostring(res.error_message or "")))
			end
			on_body(res.response)
		end)
	end

	local function request_items()
		local t = tonumber(D.gh.manifest.items) or os.time()
		gh_fetch("items.json", "cd_items", function(text)
			local list = JSON:decode(text)
			if type(list) ~= "table" or #list < 100 then
				error("items: bad list")
			end
			set_items(list)
			I.items_at = t
			store.blobs["d:items"] = text
			store.data.files.items = t
			I.dirty = true
			log("items loaded: %d", #list)
		end)
	end

	local function request_buys(h)
		local t = tonumber(D.gh.manifest.builds) or os.time()
		I.skip[h] = os.clock() + K.ITEM_FAIL_SKIP
		gh_fetch(("builds/%d.json"):format(h), "cd_buys", function(text)
			local list = JSON:decode(text)
			if type(list) ~= "table" then
				error(("purchases %d: bad file"):format(h))
			end
			I.skip[h] = nil
			I.buys_at[h] = t
			set_buys(h, list)
			keep_buys(h, text)
			log("purchases loaded for %d: %d rows", h, #list)
		end)
	end

	function I.positions(h)
		local out = {}
		local all = I.buys[h]
		for p, d in pairs(all and all.pos or {}) do
			if d.g >= K.BUYS_MIN then
				out[p] = d.g
			end
		end
		return out
	end

	function I.hero(sm)
		for _, row in ipairs(sm.rows) do
			if row.h == draft.build_h then
				return row
			end
		end
		local mine = draft.mode == 1 and draft.me and draft.steps[draft.me]
		for _, row in ipairs(sm.rows) do
			if row.h == mine then
				return row
			end
		end
		return sm.rows[1]
	end

	function I.tick()
		if not D.loaded then
			return
		end
		if not I.loaded then
			load()
		end
		local sm = draft.summary
		if I.busy and os.clock() - I.req_at > K.TIMEOUT + K.STUCK then
			I.req_n, I.busy = I.req_n + 1, false
			I.error, I.next_at = "no answer, timeout", os.clock() + K.ITEM_RETRY
			Log.Write(("[Draft Helper] %s: no answer in %d s, retrying"):format(tostring(I.req_param), K.TIMEOUT + K.STUCK))
		end
		if I.busy or os.clock() < I.next_at then
			return
		end
		if sm or I.want then
			local m = D.gh.manifest
			if not m then
				return
			end
			if not I.items or I.items_at < (tonumber(m.items) or 0) then
				request_items()
				return
			end
			local want = { I.want }
			if sm then
				local first = I.hero(sm)
				want[#want + 1] = first and first.h
				for _, row in ipairs(sm.rows) do
					want[#want + 1] = row.h
				end
			end
			for _, h in ipairs(want) do
				local stale = not I.buys[h] or (I.buys_at[h] or 0) < (tonumber(m.builds) or 0)
				if stale and os.clock() >= (I.skip[h] or 0) then
					request_buys(h)
					return
				end
			end
		end
		if I.dirty then
			I.dirty = false
			store_save()
		end
	end

	function I.threats(h)
		if I.rules_rev ~= D.rules_rev then
			I.threat_of, I.builds, I.rules_rev = {}, {}, D.rules_rev
		end
		local cached = I.threat_of[h]
		if cached then
			return cached
		end
		local hero = D.by_id[h]
		local t = {}
		if hero then
			local short = hero.unit:gsub("^npc_dota_hero_", "")
			for k, v in pairs((D.tags or {})[short] or {}) do
				t[k] = v
			end
			local roles = {}
			for _, role in ipairs(hero.roles) do
				roles[role] = true
			end
			if roles.Nuker then
				t.magic = (t.magic or 0) + K.ROLE_MAGIC
			end
			if roles.Disabler then
				t.disable = (t.disable or 0) + K.ROLE_DISABLE
			end
			if roles.Carry and not roles.Support and (hero.attr == "agi" or hero.attr == "str") then
				t.phys = (t.phys or 0) + (hero.attr == "agi" and K.ROLE_PHYS_AGI or K.ROLE_PHYS_STR)
			end
			for k, v in pairs(t) do
				t[k] = math.min(1, v)
			end
		end
		I.threat_of[h] = t
		return t
	end

	local function related(a, b)
		for _, part in ipairs(a.parts) do
			if part == b.name then
				return true
			end
		end
		for _, part in ipairs(b.parts) do
			if part == a.name then
				return true
			end
		end
		return false
	end

	local function siblings(a, b)
		for _, x in ipairs(a.parts) do
			local part = I.by_name[x]
			if part and part.created and part.cost >= K.SIBLING_COST then
				for _, y in ipairs(b.parts) do
					if x == y then
						return true
					end
				end
			end
		end
		return false
	end

	local function vs_heroes(vs, them, per)
		local list = {}
		for _, e in ipairs(them) do
			local x = 0
			for threat, w in pairs(vs) do
				x = x + w * (per[e][threat] or 0)
			end
			if x >= K.VS_MIN then
				list[#list + 1] = { h = e, x = x }
			end
		end
		table.sort(list, function(a, b)
			return a.x > b.x
		end)
		local out = {}
		for n = 1, math.min(K.VS_MAX, #list) do
			out[n] = list[n].h
		end
		return out
	end

	local function fits_hero(name, h, pos)
		local fit, hero = K.FIT[name], D.by_id[h]
		if not fit or not hero or (fit.melee and not hero.melee) then
			return false
		end
		local rule = (not pos or pos <= 3) and fit.core or fit.support
		return rule == true or (type(rule) == "table" and rule[hero.attr] == true)
	end

	local function est_time(item, cands)
		local sum, n, last = 0, 0, 0
		for _, cd in pairs(cands) do
			last = math.max(last, cd.t)
			if math.abs(cd.item.cost - item.cost) <= 1000 then
				sum, n = sum + cd.t, n + 1
			end
		end
		return n > 0 and sum / n or last + 120
	end

	local function counter_cd(name, cands)
		local item = I.by_name[name]
		return cands[name] or { item = item, count = 0, share = 0, t = est_time(item, cands) }
	end

	local function place(slots, cd, locked)
		local item = cd.item
		local idx, low
		for i, sl in ipairs(slots) do
			if not locked(sl) and not sl.must and not sl.pre and not K.BOOTS[sl.item.name] then
				local ok = true
				for j, o in ipairs(slots) do
					if j ~= i and (o.item == item or related(o.item, item) or (not K.BOOTS[o.item.name] and siblings(o.item, item))) then
						ok = false
					end
				end
				local v = sl.score or sl.share or 0
				if ok and (not idx or v < low) then
					idx, low = i, v
				end
			end
		end
		if not idx then
			return nil
		end
		local new = copy(cd)
		new.replaced, new.drop, new.core = slots[idx].item, nil, nil
		slots[idx] = new
		return new
	end

	function I.must(slots, cands, per, them, h, pos, locked)
		local added = {}
		for _, rule in ipairs(K.MUST) do
			local threat = rule[1]
			local strongest = 0
			for _, e in ipairs(them) do
				strongest = math.max(strongest, (per[e] or {})[threat] or 0)
			end
			local role_ok = not rule[4] or I.physical(h, pos)
			if strongest >= rule[2] and rule[3][pos or 0] and role_ok and #added < K.MUST_MAX then
				local covered = 0
				for _, s in ipairs(slots) do
					covered = math.max(covered, (K.COUNTERS[s.item.name] or {})[threat] or 0)
				end
				local best, best_v
				if covered < K.MUST_COVER then
					for name, vs in pairs(K.COUNTERS) do
						local w = vs[threat]
						if w and w >= K.MUST_COVER and I.by_name[name] and fits_hero(name, h, pos) then
							local v = w + (cands[name] and cands[name].share or 0)
							if not best or v > best_v or (v == best_v and name < best) then
								best, best_v = name, v
							end
						end
					end
				end
				local new = best and place(slots, counter_cd(best, cands), locked)
				if new then
					new.why = { { threat = threat, x = K.COUNTERS[best][threat] } }
					new.vs = vs_heroes({ [threat] = 1 }, them, per)
					new.must = threat
					added[#added + 1] = new
				end
			end
		end
		return added
	end

	function I.physical(h, pos)
		local all = I.buys[h]
		local data = all and pos and all.pos[pos]
		if not data or data.g <= 0 then
			return false
		end
		local sum = 0
		for name in pairs(K.PHYS_ITEMS) do
			local r = data.rows[name]
			if r then
				sum = sum + r.n / data.g
			end
		end
		return sum >= K.PHYS_MIN
	end

	function I.rate(h, pos, name)
		local all = I.buys[h]
		if not all then
			return 0
		end
		local d = pos and all.pos[pos]
		if d and d.g >= K.RATE_MIN_GAMES then
			local r = d.rows[name]
			return r and r.n / d.g or 0
		end
		local n, g = 0, 0
		for _, dd in pairs(all.pos) do
			g = g + dd.g
			local r = dd.rows[name]
			if r then
				n = n + r.n
			end
		end
		return g > 0 and n / g or 0
	end

	function I.react(slots, cands, them, seen, h, pos, locked, ew)
		local added = {}
		local phys = I.physical(h, pos)
		for _, rule in ipairs(K.REACT) do
			local source, hits = nil, 0
			for _, e in ipairs(them) do
				for _, name in ipairs(rule.items) do
					if seen[e] and seen[e][name] then
						hits = hits + (ew and ew[e] or 1)
						source = source or { e = e, item = name }
					end
				end
			end
			if hits < K.ITEM_THREAT_MIN then
				source = nil
			end
			local covered = false
			for _, sl in ipairs(slots) do
				if ((K.COUNTERS[sl.item.name] or {})[rule.threat] or 0) >= K.MUST_COVER then
					covered = true
				end
			end
			local pick
			if source and not covered and (not rule.phys or phys) and #added < K.REACT_MAX then
				for _, name in ipairs(rule.counters) do
					if not pick and I.by_name[name] and fits_hero(name, h, pos)
						and (not rule.rate or I.rate(h, pos, name) >= K.REACT_RATE) then
						pick = name
					end
				end
			end
			local new = pick and place(slots, counter_cd(pick, cands), locked)
			if new then
				new.why = { { threat = rule.threat, x = K.COUNTERS[pick] and K.COUNTERS[pick][rule.threat] or 1 } }
				new.vs = { source.e }
				new.must, new.reason = rule.threat, source
				added[#added + 1] = new
			end
		end
		return added
	end

	local function item_body(cd)
		local lines = {}
		if cd.pre then
			lines[1] = L("cd_tip_up_from"):format(cd.pre.item.label)
		end
		if cd.why then
			local names = {}
			for _, e in ipairs(cd.vs) do
				names[#names + 1] = D.by_id[e] and D.by_id[e].name or "?"
			end
			if #names > 0 then
				lines[#lines + 1] = L("cd_tip_item_vs"):format(table.concat(names, ", "))
			end
			local threats = {}
			for n = 1, math.min(2, #cd.why) do
				threats[n] = L("cd_th_" .. cd.why[n].threat)
			end
			lines[#lines + 1] = table.concat(threats, ", ")
		end
		if cd.after then
			lines[#lines + 1] = L(cd.after_kind == "up" and "cd_tip_upgrade" or "cd_tip_after"):format(cd.after.item.label)
		end
		return table.concat(lines, "\n")
	end

	I.body, I.related, I.siblings = item_body, related, siblings

	function I.share(data, r)
		if data.gw >= K.WIN_MIN then
			return r.w / data.gw
		end
		return r.n / data.g
	end

	function I.collect(data)
		local cands, boots = {}, nil
		for name, r in pairs(data.rows) do
			local item = I.by_name[name]
			if item then
				local cd = { item = item, count = r.n, t = r.t, share = I.share(data, r) }
				if K.BOOTS[name] then
					if not boots or cd.share > boots.share then
						boots = cd
					end
				elseif not K.SLOT_SKIP[name] and (K.SLOT_EXTRA[name] or (item.created and item.cost >= K.SLOT_MIN_COST)) then
					cands[name] = cd
				end
			end
		end
		for _, cd in pairs(cands) do
			for _, part in ipairs(cd.item.parts) do
				local p = cands[part]
				if p and p ~= cd and cd.count >= K.ITEM_UPGRADE * p.count then
					p.drop = true
				end
			end
		end
		return cands, boots
	end

	function I.pre(cd, data)
		local best
		for _, part in ipairs(cd.item.parts) do
			local r = data.rows[part]
			local p = I.by_name[part]
			if r and p and r.n / data.g >= K.PRE_SHARE and r.t < cd.t - K.PRE_GAP
				and ((p.created and p.cost >= K.PRE_COST) or (part == "boots" and K.BOOTS[cd.item.name]))
				and (not best or p.cost > best.item.cost) then
				best = { item = p, t = r.t }
			end
		end
		return best
	end

	function I.upgrade(cd, cands, taken)
		local best
		for _, y in pairs(cands) do
			local contains, used = false, false
			for _, part in ipairs(y.item.parts) do
				if part == cd.item.name then
					contains = true
				end
			end
			for _, p in ipairs(taken) do
				if p.item == y.item then
					used = true
				end
			end
			if contains and not used and y.t > cd.t and y.count >= K.UPGRADE_MIN * cd.count
				and (not best or y.count > best.count) then
				best = y
			end
		end
		return best
	end

	function I.after(cd, cands, taken, data)
		local item = cd.item
		if not K.DISASSEMBLE[item.name] or (data.fin[item.id] or 0) >= K.KEEP_MAX * cd.count then
			return nil
		end
		local best
		for _, y in pairs(cands) do
			if y.share >= K.AFTER_SHARE and y.t >= cd.t + K.AFTER_GAP and not related(item, y.item) then
				local shared, used = false, false
				for _, a in ipairs(item.parts) do
					for _, b in ipairs(y.item.parts) do
						if a == b then
							shared = true
						end
					end
				end
				for _, p in ipairs(taken) do
					if p.item == y.item then
						used = true
					end
				end
				if shared and not used and (not best or y.share > best.share) then
					best = y
				end
			end
		end
		return best
	end

	local function start_items(data)
		local sorted = {}
		for name, r in pairs(data.rows) do
			local item = I.by_name[name]
			if item and r.m > 0 and r.m >= K.START_MIN * data.g then
				sorted[#sorted + 1] = { item = item, r = r }
			end
		end
		table.sort(sorted, function(a, b)
			if a.r.m ~= b.r.m then
				return a.r.m > b.r.m
			end
			return a.item.name < b.item.name
		end)
		local out, gold = {}, 0
		for _, st in ipairs(sorted) do
			local q = clamp(math.floor(st.r.s / st.r.m + 0.5), 1, K.STACK[st.item.name] or 1)
			while q > 0 and gold + q * st.item.cost > K.START_GOLD do
				q = q - 1
			end
			if q > 0 then
				out[#out + 1] = { item = st.item, q = q }
				gold = gold + q * st.item.cost
			end
		end
		return out, gold
	end

	function I.early(data, picked, start)
		local skip = {}
		for _, st in ipairs(start) do
			skip[st.item.name] = true
		end
		for _, cd in ipairs(picked) do
			skip[cd.item.name] = true
		end
		local list = {}
		for name, r in pairs(data.rows) do
			local item = I.by_name[name]
			if item and not skip[name] and not K.BOOTS[name] and r.t > 0 and r.t <= K.EARLY_T
				and r.n / data.g >= K.EARLY_SHARE
				and (K.EARLY_EXTRA[name] or (item.created and item.cost >= K.EARLY_MIN_COST and item.cost < K.SLOT_MIN_COST)) then
				list[#list + 1] = { item = item, t = r.t, share = r.n / data.g }
			end
		end
		table.sort(list, function(a, b)
			if a.share ~= b.share then
				return a.share > b.share
			end
			return a.item.name < b.item.name
		end)
		for n = #list, K.EARLY_MAX + 1, -1 do
			list[n] = nil
		end
		for _, e in ipairs(list) do
			for _, cd in ipairs(picked) do
				for _, part in ipairs(cd.item.parts) do
					if not e.up and cd.t > e.t and part == e.item.name then
						e.up = cd.item
					end
				end
			end
			e.body = e.up and L("cd_tip_upgrade"):format(e.up.label) or ""
		end
		return list
	end

	function I.build(h, pos, them)
		local all = I.buys[h]
		if not all or not I.items then
			return nil
		end
		local data = pos and all.pos[pos]
		if not data or data.g < K.BUYS_MIN then
			return { none = true, pos = pos, slots = {}, start = {}, gold = 0 }
		end
		local key = ("%d:%d:%s:%d:%d:%d"):format(h, pos or 0, table.concat(them, ","), I.items_at, I.buys_at[h] or 0, D.rules_rev or 0)
		local cached = I.builds[key]
		if cached then
			return cached
		end
		local T, per = {}, {}
		for _, e in ipairs(them) do
			per[e] = I.threats(e)
			for threat, v in pairs(per[e]) do
				T[threat] = (T[threat] or 0) + v
			end
		end
		local cands, boots = I.collect(data)
		local list = {}
		for name, cd in pairs(cands) do
			if not cd.drop then
				cd.score = cd.share
				local vs = K.COUNTERS[name]
				if vs and cd.share >= K.ITEM_SHARE then
					local v, why = 0, {}
					for threat, w in pairs(vs) do
						local x = w * math.min(1, T[threat] or 0)
						if x > 0 then
							v = v + x
							why[#why + 1] = { threat = threat, x = x }
						end
					end
					if v > 0 then
						table.sort(why, function(a, b)
							return a.x > b.x
						end)
						cd.why = why
						cd.score = cd.share + K.ITEM_COUNTER_W * math.min(1, v) * math.min(1, cd.share / K.ITEM_SHARE_FULL)
						cd.vs = vs_heroes(vs, them, per)
					end
				end
				list[#list + 1] = cd
			end
		end
		local picked = { boots }
		local function fits(cd)
			for _, p in ipairs(picked) do
				if related(p.item, cd.item) or (p ~= boots and siblings(p.item, cd.item)) then
					return false
				end
			end
			return true
		end
		local function by(field)
			table.sort(list, function(a, b)
				if a[field] ~= b[field] then
					return a[field] > b[field]
				end
				return a.item.name < b.item.name
			end)
		end
		by("share")
		local core = 0
		for _, cd in ipairs(list) do
			if core >= K.CORE_LOCK or #picked >= K.SLOTS then
				break
			end
			if fits(cd) then
				cd.core = true
				core = core + 1
				picked[#picked + 1] = cd
			end
		end
		by("score")
		for _, cd in ipairs(list) do
			if #picked >= K.SLOTS then
				break
			end
			if not cd.core and fits(cd) then
				picked[#picked + 1] = cd
			end
		end
		I.must(picked, cands, per, them, h, pos, function(s)
			return s.core
		end)
		table.sort(picked, function(a, b)
			if math.abs(a.t - b.t) > 0.05 then
				return a.t < b.t
			end
			return a.item.cost < b.item.cost
		end)
		for _, cd in ipairs(picked) do
			cd.pre = I.pre(cd, data)
			local up = I.upgrade(cd, cands, picked)
			if up then
				cd.after, cd.after_kind = up, "up"
			else
				cd.after, cd.after_kind = I.after(cd, cands, picked, data), "dis"
			end
			cd.body = item_body(cd)
		end
		local start, gold = start_items(data)
		local early = I.early(data, picked, start)
		local steps = {}
		for _, e in ipairs(early) do
			steps[#steps + 1] = { item = e.item, t = e.t, body = e.body, early = true }
		end
		local shard
		local sr = data.rows[K.SHARD]
		if sr and I.by_name[K.SHARD] and sr.n / data.g >= K.CONSUME_SHARE then
			shard = { item = I.by_name[K.SHARD], t = sr.t }
			steps[#steps + 1] = { item = shard.item, t = shard.t, body = L("cd_tip_noslot") }
		end
		for _, cd in ipairs(picked) do
			if cd.pre then
				steps[#steps + 1] = { item = cd.pre.item, t = cd.pre.t, body = L("cd_tip_upgrade"):format(cd.item.label) }
			end
			steps[#steps + 1] = cd
			if cd.after then
				steps[#steps + 1] = {
					item = cd.after.item,
					t = cd.after.t,
					base = cd.item,
					kind = cd.after_kind,
					body = L(cd.after_kind == "up" and "cd_tip_up_from" or "cd_tip_dis_from"):format(cd.item.label),
				}
			end
		end
		table.sort(steps, function(a, b)
			if a.t ~= b.t then
				return a.t < b.t
			end
			return (a.base and 1 or 0) < (b.base and 1 or 0)
		end)
		local spare
		if (T.invis or 0) >= K.SPARE_MIN then
			local item = I.by_name[(pos and pos >= 4) and "ward_sentry" or "dust"]
			if item then
				spare = { item = item, q = 2, vs = vs_heroes({ invis = 1 }, them, per) }
			end
		end
		local build = { slots = picked, steps = steps, start = start, gold = gold, spare = spare, early = early, shard = shard }
		I.builds[key] = build
		return build
	end
end

local function STEPS()
	return draft.mode == 1 and K.FREE or K.STEPS
end

local function step_team(i)
	local step = STEPS()[i]
	return step.team or (step.side ~ draft.first)
end

local function cur_step()
	if draft.edit then
		return draft.edit
	end
	local list = STEPS()
	if draft.mode == 1 then
		local t = draft.target
		if not t and draft.me and not draft.steps[draft.me] then
			return draft.me
		end
		if t and list[t] then
			if not draft.steps[t] then
				return t
			end
			for i, step in ipairs(list) do
				if step.group == list[t].group and not draft.steps[i] then
					return i
				end
			end
		end
	end
	local last = draft.mode == 1 and K.FREE_PICKS or #list
	for i = 1, last do
		if not draft.steps[i] then
			return i
		end
	end
	return nil
end

local function picks(team)
	local out = {}
	for i, step in ipairs(STEPS()) do
		local h = draft.steps[i]
		if h and step.kind == "P" and step_team(i) == team then
			out[#out + 1] = h
		end
	end
	return out
end

local function used_set()
	local set = {}
	for i = 1, #STEPS() do
		local h = draft.steps[i]
		if h then
			set[h] = true
		end
	end
	if draft.mode == 1 then
		for h in pairs(draft.extra_bans) do
			set[h] = true
		end
		for h in pairs(draft.unavail or {}) do
			set[h] = true
		end
	end
	return set
end

function M.summary()
	local rows, them = {}, picks(1)
	for i, step in ipairs(STEPS()) do
		local h = draft.steps[i]
		if h and step.kind == "P" and step_team(i) == 0 then
			rows[#rows + 1] = { h = h, pos = draft.slot_pos[i], slot = i }
		end
	end
	table.sort(rows, function(a, b)
		return (a.pos or 9) * 100 + a.slot < (b.pos or 9) * 100 + b.slot
	end)
	local sig = {}
	for _, row in ipairs(rows) do
		row.v, row.sum = {}, 0
		for j, e in ipairs(them) do
			local v = (sigm(K.ADV_W * M.adv(row.h, e)) - 0.5) * 100
			row.v[j] = v
			row.sum = row.sum + v
		end
		sig[#sig + 1] = row.h
	end
	for _, e in ipairs(them) do
		sig[#sig + 1] = e
	end
	return { rows = rows, them = them, sig = table.concat(sig, ",") }
end

local function hero_score(h, allies, enemies, reasons, pos)
	local delta = 0
	local lane = pos and cfg.lanes == 1 and K.LANE_OPP[pos]
	for _, e in ipairs(enemies) do
		local v = M.adv(h, e) * K.ADV_W
		local ep = lane and (draft.enemy_pos or {})[e]
		if ep and lane[ep] then
			v = v * (1 + K.LANE_W)
		end
		delta = delta + v
		if reasons then
			reasons[#reasons + 1] = { h = e, v = v, t = "vs" }
		end
	end
	for _, b in ipairs(allies) do
		local v = M.syn(h, b) * K.SYN_W
		delta = delta + v
		if reasons then
			reasons[#reasons + 1] = { h = b, v = v, t = "with" }
		end
	end
	return delta
end

local function companions(hero, pos, lineup, enemies, used)
	local slots, members = {}, {}
	for p, h in pairs(lineup) do
		slots[p] = h
		members[#members + 1] = h
	end
	slots[pos] = hero
	members[#members + 1] = hero
	local taken = { [hero] = true }
	for _, h in ipairs(members) do
		taken[h] = true
	end
	local out = {}
	while true do
		local best_p, best_h, best_s
		for p = 1, 5 do
			if not slots[p] then
				for _, cand in ipairs(D.heroes) do
					local h = cand.id
					if not used[h] and not taken[h] and M.games(h) >= K.MIN_GAMES then
						local lp = M.pos(h)[p]
						if math.exp(lp) >= K.POS_MIN then
							local s = draft.vs_cache[h]
							if not s then
								s = hero_score(h, {}, enemies) + K.BASE_W * logit(M.base(h)) + M.rarity(h)
								draft.vs_cache[h] = s
							end
							for _, b in ipairs(members) do
								s = s + M.syn(h, b) * K.SYN_W
							end
							s = s + K.FIT_W * lp
							if not best_s or s > best_s then
								best_p, best_h, best_s = p, h, s
							end
						end
					end
				end
			end
		end
		if not best_p then
			break
		end
		slots[best_p] = best_h
		taken[best_h] = true
		members[#members + 1] = best_h
		out[#out + 1] = { pos = best_p, h = best_h }
	end
	table.sort(out, function(a, b)
		return a.pos < b.pos
	end)
	return out
end

local function fixed_pos(i)
	local manual = draft.manual[draft.mode][i]
	if manual then
		return manual, true
	end
	if draft.mode == 1 then
		return draft.known_pos[i], false
	end
	return nil, false
end

local function known_role(h)
	for i, step in ipairs(STEPS()) do
		if draft.steps[i] == h and step.kind == "P" and step_team(i) == 0 then
			return fixed_pos(i)
		end
	end
	return nil, false
end

local function set_manual(i, p)
	local manual = draft.manual[draft.mode]
	if p then
		for j, q in pairs(manual) do
			if q == p and STEPS()[j] and step_team(j) == step_team(i) then
				manual[j] = nil
			end
		end
	end
	manual[i] = p
	draft.dirty = true
end

local function recompute()
	draft.dirty = false
	local cs = cur_step()
	if draft.mode == 1 and cs and cs == draft.me and draft.my_role and draft.filter == 0 and not draft.filter_user then
		draft.filter = draft.my_role
	end
	draft.result, draft.chance, draft.slot_pos, draft.vs_cache, draft.summary = nil, nil, {}, {}, nil
	local ours, ours_idx = {}, {}
	for i, step in ipairs(STEPS()) do
		if draft.steps[i] and step.kind == "P" and step_team(i) == 0 then
			ours[#ours + 1] = draft.steps[i]
			ours_idx[#ours_idx + 1] = i
		end
	end
	local known_block, unknown, unknown_idx = {}, {}, {}
	local claim = 0
	if cs and draft.filter > 0 and STEPS()[cs].kind == "P" and step_team(cs) == 0 then
		claim = draft.filter
	end
	for j, i in ipairs(ours_idx) do
		local kp, manual = fixed_pos(i)
		if kp and (kp == claim and not manual) then
			kp = nil
		end
		if kp and not known_block[kp] then
			draft.slot_pos[i] = kp
			known_block[kp] = true
		else
			unknown[#unknown + 1] = ours[j]
			unknown_idx[#unknown_idx + 1] = i
		end
	end
	local claim_block = known_block
	if claim > 0 and not known_block[claim] then
		claim_block = { [claim] = true }
		for p in pairs(known_block) do
			claim_block[p] = true
		end
	end
	local _, our_map = M.assign(unknown, claim_block)
	for j, i in ipairs(unknown_idx) do
		draft.slot_pos[i] = our_map[j]
	end
	draft.enemy_pos = {}
	if cfg.lanes == 1 then
		local eblock, eunknown, eunknown_idx = {}, {}, {}
		for i, step in ipairs(STEPS()) do
			local h = draft.steps[i]
			if h and step.kind == "P" and step_team(i) == 1 then
				local kp = draft.manual[draft.mode][i]
				if kp and not eblock[kp] then
					draft.slot_pos[i], draft.enemy_pos[h] = kp, kp
					eblock[kp] = true
				else
					eunknown[#eunknown + 1] = h
					eunknown_idx[#eunknown_idx + 1] = i
				end
			end
		end
		local _, emap = M.assign(eunknown, eblock)
		for j, i in ipairs(eunknown_idx) do
			draft.slot_pos[i], draft.enemy_pos[eunknown[j]] = emap[j], emap[j]
		end
	end
	if not D.sets[0].stats or not D.heroes then
		return
	end
	local us, them = picks(0), picks(1)
	if #us > 0 and #them > 0 then
		local d = 0
		for _, a in ipairs(us) do
			d = d + logit(M.base(a))
			for _, e in ipairs(them) do
				d = d + K.ADV_W * M.adv(a, e)
			end
		end
		for _, e in ipairs(them) do
			d = d - logit(M.base(e))
		end
		for _, side in ipairs({ { us, 1 }, { them, -1 } }) do
			local team = side[1]
			for j = 1, #team - 1 do
				for l = j + 1, #team do
					d = d + side[2] * K.SYN_W * M.syn(team[j], team[l])
				end
			end
		end
		draft.chance = sigm(d)
	end
	local c = cur_step()
	if not c then
		if #us == 5 and #them == 5 then
			local sm = M.summary()
			if sm.sig ~= draft.summary_sig then
				draft.summary_sig = sm.sig
				W.list_t0, W.list_scroll = os.clock(), 0
			end
			draft.summary = sm
		end
		return
	end
	local acting, kind = step_team(c), STEPS()[c].kind
	local persp = kind == "P" and acting or 1 - acting
	local allies, enemies = picks(persp), picks(1 - persp)
	local old = draft.edit and draft.steps[c]
	if old then
		for _, list in ipairs({ allies, enemies }) do
			for j = #list, 1, -1 do
				if list[j] == old then
					table.remove(list, j)
				end
			end
		end
	end
	local our_pick = acting == 0 and kind == "P"
	local our_ban = acting == 0 and kind == "B"
	local base_fit = 0
	local lineup, taken, block, rest = {}, {}, {}, allies
	if draft.filter ~= 0 and acting ~= 0 then
		draft.filter = 0
	end
	local sel = draft.filter
	if our_pick then
		rest = {}
		for _, h in ipairs(allies) do
			local kp, manual = known_role(h)
			if kp and not block[kp] and (kp ~= sel or manual) then
				block[kp] = true
				lineup[kp] = h
			else
				rest[#rest + 1] = h
			end
		end
		local assign_block = {}
		for p in pairs(block) do
			assign_block[p] = true
		end
		if sel > 0 then
			assign_block[sel] = true
		end
		local base_map
		base_fit, base_map = M.assign(rest, assign_block)
		for j, p in ipairs(base_map) do
			lineup[p] = rest[j]
		end
		for p in pairs(lineup) do
			taken[p] = true
		end
		if sel > 0 then
			block = assign_block
		end
	end
	local used = used_set()
	if old then
		used[old] = nil
	end
	local offer
	if our_pick and (c == draft.me or not draft.me) then
		offer = draft.offer
	end
	local early = #allies + #enemies < 4
	local pick_no = math.min(5, #allies + 1)
	local function order_bonus(pos)
		if not our_pick or sel > 0 or not pos then
			return 0
		end
		return K.ORDER_W * math.log(K.PICK_ORDER[pick_no][pos] / 0.2)
	end
	local rows = {}
	local team = { table.unpack(rest) }
	local slot = #team + 1
	for _, hero in ipairs(D.heroes) do
		local h = hero.id
		local offered = offer and offer[h] and M.games(h) > 0
		if not used[h] and (offered or not offer and M.games(h) >= K.MIN_GAMES) and not (our_pick and #allies >= 5) then
			local lp = M.pos(h)
			local pos, fit, ok = nil, 0, true
			if our_pick then
				if sel > 0 then
					pos, fit = sel, lp[sel]
					ok = math.exp(fit) >= K.POS_MIN
				else
					team[slot] = h
					local f, map = M.assign(team, block)
					fit = f - base_fit
					pos = map[slot]
					ok = math.exp(fit) >= K.FIT_MIN
				end
			elseif our_ban and sel > 0 then
				pos, fit = sel, lp[sel]
				ok = math.exp(fit) >= K.POS_MIN
			end
			if offered then
				ok = true
			end
			if ok then
				local reasons = {}
				local delta = hero_score(h, allies, enemies, reasons, our_pick and pos or nil)
				local counter = 0
				for _, r in ipairs(reasons) do
					if r.t == "vs" then
						counter = counter + K.COUNTER_EXTRA * r.v + K.COUNTERED_EXTRA * math.min(0, r.v)
					end
				end
				local contest = (source() == 1 and D.contest) and D.contest[h] or 0
				rows[#rows + 1] = {
					h = h,
					delta = delta,
					pos = pos,
					share = pos and math.exp(lp[pos]) or nil,
					rank = delta + counter + K.BASE_W * logit(M.base(h)) + K.FIT_W * fit + (early and K.CONTEST_W * contest or 0)
						+ order_bonus(pos) + M.rarity(h),
					reasons = reasons,
					contest = contest,
				}
			end
		end
	end
	team[slot] = nil
	table.sort(rows, function(a, b)
		return a.rank > b.rank
	end)
	for i = #rows, K.LIST_MAX + 1, -1 do
		rows[i] = nil
	end
	for i, row in ipairs(rows) do
		table.sort(row.reasons, function(a, b)
			return a.v > b.v
		end)
		if our_pick and row.pos and i <= K.COMP_ROWS then
			local comp = companions(row.h, row.pos, lineup, enemies, used)
			if #comp > 0 then
				row.comp = comp
			end
		end
	end
	draft.result = { acting = acting, kind = kind, taken = taken, rows = rows, positional = acting == 0,
		context = #allies + #enemies > 0 }
	W.list_t0 = os.clock()
end

local function reset_draft()
	draft.steps, draft.edit, draft.query, draft.filter, draft.dirty = {}, nil, "", 0, true
	draft.known_pos, draft.me, draft.my_role, draft.filter_user, draft.sync_sig = {}, nil, nil, false, nil
	draft.tentative, draft.build_h, draft.summary_sig = {}, nil, nil
	draft.extra_bans, draft.extra_key = {}, nil
	draft.offer, draft.offer_key = nil, nil
	draft.unavail, draft.unavail_key = nil, nil
	W.counter = nil
	draft.store[draft.mode], draft.history[draft.mode], draft.target = draft.steps, {}, nil
	draft.manual[draft.mode] = {}
	W.list_scroll = 0
end

local function set_mode(mode)
	if draft.mode == mode then
		return
	end
	draft.mode = mode
	draft.steps = draft.store[mode]
	draft.edit, draft.target, draft.filter, draft.dirty = nil, nil, 0, true
	W.list_scroll = 0
	W.placed = {}
end

local function put(h)
	local c = cur_step()
	if not c or not D.by_id[h] then
		return
	end
	local used = used_set()
	if used[h] and draft.steps[c] ~= h then
		return
	end
	if draft.steps[c] ~= h then
		draft.manual[draft.mode][c] = nil
	end
	if draft.mode == 1 then
		draft.tentative[c] = nil
		if c > K.FREE_PICKS then
			draft.target = nil
		end
	end
	draft.steps[c] = h
	local hist = draft.history[draft.mode]
	for j = #hist, 1, -1 do
		if hist[j] == c then
			table.remove(hist, j)
		end
	end
	hist[#hist + 1] = c
	draft.edit, draft.query, draft.dirty = nil, "", true
	W.list_scroll = 0
	log("step %d: %s %s", c, STEPS()[c].kind, D.by_id[h].name)
end

local function undo()
	if draft.edit then
		draft.edit, draft.dirty = nil, true
		return
	end
	local hist = draft.history[draft.mode]
	while #hist > 0 do
		local i = table.remove(hist)
		if draft.steps[i] then
			draft.steps[i] = nil
			draft.dirty = true
			if draft.mode == 1 then
				draft.target = i
			end
			return
		end
	end
	for i = #STEPS(), 1, -1 do
		if draft.steps[i] then
			draft.steps[i] = nil
			draft.dirty = true
			return
		end
	end
end

local function in_match()
	local ok, gs = pcall(GameRules.GetGameState)
	if not ok or not gs or not K.MATCH_STATES[gs] then
		return false, "state " .. tostring(gs)
	end
	local ok2, me = pcall(Players.GetLocal)
	if not ok2 or not me then
		return false, "no local player"
	end
	return true, gs
end

local function sync_skip(reason)
	if draft.sync_sig ~= reason then
		draft.sync_sig = reason
		log("sync skipped: %s", reason)
	end
end

local function panel_unit(panel)
	local okt, kind = pcall(panel.GetPanelType, panel)
	if not okt or type(kind) ~= "string" or not kind:find("Image", 1, true) then
		return nil
	end
	local found
	local ok, src = pcall(panel.GetImageSrc, panel)
	if ok and type(src) == "string" then
		found = src:match("(npc_dota_hero_[%w_]+)")
	end
	if not found then
		return nil
	end
	if not draft.panel_kind then
		draft.panel_kind = kind
		log("hero portraits are %s panels", kind)
	end
	found = found:gsub("_png$", ""):gsub("_persona%d+$", ""):gsub("_alt%d+$", "")
	return D.by_unit[found] and found or nil
end

local function walk_portraits(panel, max_depth, on_unit, depth)
	depth = depth or 0
	if depth > max_depth then
		return
	end
	local okv, visible = pcall(panel.IsVisible, panel)
	if okv and visible == false then
		return
	end
	local unit = panel_unit(panel)
	if unit then
		on_unit(unit, panel)
		return
	end
	local okc, count = pcall(panel.GetChildCount, panel)
	if not okc or not count then
		return
	end
	for i = 0, count - 1 do
		local okg, child = pcall(panel.GetChild, panel, i)
		if okg and child then
			walk_portraits(child, max_depth, on_unit, depth + 1)
		end
	end
end

local function enemy_panel_heroes(my_team)
	local id = K.TEAM_PANELS[my_team == K.TEAM_DIRE and 1 or 2]
	local ok, root = pcall(Panorama.GetPanelByName, id, false)
	local out, seen = {}, {}
	if ok and root then
		walk_portraits(root, K.PANEL_DEPTH, function(unit)
			if not seen[unit] then
				seen[unit] = true
				out[#out + 1] = unit
			end
		end)
	end
	if draft.panel_log ~= (ok and root and "found" or "missing") .. #out then
		draft.panel_log = (ok and root and "found" or "missing") .. #out
		log("panel %s: %s, heroes: %s", id, (ok and root) and "found" or "missing", table.concat(out, " "))
	end
	return out
end

local function card_open(portrait)
	local p = portrait
	for _ = 1, K.GRID_CARD_UP do
		local ok, parent = pcall(p.GetParent, p)
		if not ok or not parent then
			return false
		end
		p = parent
		local okc, is_card = pcall(p.HasClass, p, K.GRID_CARD)
		if okc and is_card then
			local oko, off = pcall(p.HasClass, p, K.GRID_OFF)
			return oko and not off
		end
	end
	return false
end

local function pick_grid()
	for _, id in ipairs(K.TEAM_PANELS) do
		local ok, anchor = pcall(Panorama.GetPanelByName, id, false)
		if ok and anchor then
			local okr, root = pcall(anchor.GetRootParent, anchor)
			local okf, grid = false, nil
			if okr and root then
				okf, grid = pcall(root.FindChildTraverse, root, K.GRID)
			end
			if draft.grid_log ~= id .. tostring(okf and grid ~= nil) then
				draft.grid_log = id .. tostring(okf and grid ~= nil)
				log("hero grid via %s: %s", id, (okf and grid) and "found" or "missing")
			end
			return okf and grid or nil
		end
	end
	local ok, grid = pcall(Panorama.GetPanelByName, K.GRID, false)
	return ok and grid or nil
end

local function read_grid()
	local grid = pick_grid()
	if not grid then
		return nil
	end
	local out, seen = {}, {}
	walk_portraits(grid, K.GRID_DEPTH, function(unit, panel)
		local info = D.by_unit[unit]
		if info and not seen[info.id] then
			seen[info.id] = true
			out[#out + 1] = { h = info.id, open = card_open(panel) }
		end
	end)
	if #out < K.GRID_MIN then
		return nil
	end
	return out
end

local function hero_names(set)
	local names = {}
	for h in pairs(set) do
		names[#names + 1] = D.by_id[h].name
	end
	table.sort(names)
	return #names > 0 and table.concat(names, ", ") or "none"
end

local function sd_offer(grid, used)
	local set, n, off = {}, 0, 0
	for _, card in ipairs(grid) do
		if not card.open then
			off = off + 1
		elseif not used[card.h] then
			set[card.h] = true
			n = n + 1
		end
	end
	if off == 0 then
		return nil, nil
	end
	local detail = ("%d heroes, open: %s"):format(#grid, hero_names(set))
	if n == 0 or n > K.SD_OFFER_MAX then
		return nil, detail
	end
	return set, detail
end

local function grid_unavailable(grid)
	local picked = {}
	for _, h in pairs(draft.steps) do
		picked[h] = true
	end
	local set = {}
	for _, card in ipairs(grid) do
		if not card.open and not picked[card.h] then
			set[card.h] = true
		end
	end
	return set
end

local function sync_free()
	if draft.mode ~= 1 or not D.heroes then
		return
	end
	local now = os.clock()
	if now < draft.sync_at then
		return
	end
	draft.sync_at = now + K.SYNC_EVERY
	local ok_match, why = in_match()
	if not ok_match then
		sync_skip(why)
		return
	end
	local okm, gm = pcall(GameRules.GetGameMode)
	if not okm or not K.SYNC_MODES[gm] then
		sync_skip("game mode " .. tostring(gm))
		return
	end
	local me = Players.GetLocal()
	local my_team = Entity.GetTeamNum(me)
	local mates = {}
	for _, p in ipairs(Players.GetAll()) do
		if Entity.GetTeamNum(p) == my_team then
			mates[#mates + 1] = p
		end
	end
	table.sort(mates, function(a, b)
		return Player.GetPlayerID(a) < Player.GetPlayerID(b)
	end)
	local changed = false
	local function set(i, h)
		if draft.steps[i] == h then
			return
		end
		for j = 1, #K.FREE do
			if j ~= i and draft.steps[j] == h then
				draft.steps[j] = nil
				draft.manual[1][j] = nil
			end
		end
		draft.steps[i] = h
		draft.manual[1][i] = nil
		changed = true
	end
	local sig = {}
	for k, p in ipairs(mates) do
		if k > 5 then
			break
		end
		local ok, td = pcall(Player.GetTeamData, p)
		if ok and type(td) == "table" then
			local hid = math.tointeger(tonumber(td.selected_hero_id) or 0) or 0
			local flags = math.tointeger(tonumber(td.lane_selection_flags) or 0) or 0
			local hover = 0
			if hid <= 0 and p ~= me then
				local okp, tp = pcall(Player.GetTeamPlayer, p)
				if okp and type(tp) == "table" then
					hover = math.tointeger(tonumber(tp.possible_hero_selection) or 0) or 0
				end
			end
			if hid > 0 and D.by_id[hid] then
				set(k, hid)
				if draft.tentative[k] then
					draft.tentative[k] = nil
					changed = true
				end
			elseif hover > 0 and D.by_id[hover] then
				set(k, hover)
				if not draft.tentative[k] then
					draft.tentative[k] = true
					changed = true
				end
			end
			local role = K.LANE_BITS[flags]
			if draft.known_pos[k] ~= role then
				draft.known_pos[k] = role
				changed = true
			end
			if p == me and (draft.me ~= k or draft.my_role ~= role) then
				draft.me, draft.my_role = k, role
				changed = true
			end
			sig[#sig + 1] = ("%d:%d:%d:%d"):format(Player.GetPlayerID(p), hid, hover, flags)
		end
	end
	local n = 5
	local seen = {}
	local enemies, source = enemy_panel_heroes(my_team), "panel"
	if #enemies == 0 then
		source = "entities"
		for _, hero in ipairs(Heroes.GetAll()) do
			if Entity.GetTeamNum(hero) ~= my_team and not NPC.IsIllusion(hero) then
				enemies[#enemies + 1] = NPC.GetUnitName(hero)
			end
		end
	end
	for _, unit in ipairs(enemies) do
		local info = D.by_unit[unit]
		if info and not seen[info.id] and n < 10 then
			seen[info.id] = true
			n = n + 1
			set(n, info.id)
			sig[#sig + 1] = "e" .. info.id
		end
	end
	sig[#sig + 1] = source
	local bans = GameRules.GetBannedHeroes()
	if type(bans) == "table" then
		local list, dup = {}, {}
		for i = 0, 63 do
			local id = math.tointeger(tonumber(bans[i]) or 0) or 0
			if id > 0 and D.by_id[id] and not dup[id] then
				dup[id] = true
				list[#list + 1] = id
			end
		end
		local extra, keys = {}, {}
		for j, id in ipairs(list) do
			if j <= 10 then
				set(10 + j, id)
			else
				extra[id] = true
				keys[#keys + 1] = id
			end
			sig[#sig + 1] = "b" .. id
		end
		local key = table.concat(keys, ",")
		if draft.extra_key ~= key then
			draft.extra_bans, draft.extra_key = extra, key
			changed = true
		end
	end
	local grid = read_grid()
	if grid and gm ~= K.MODE_SD then
		local off = grid_unavailable(grid)
		local key = hero_names(off)
		if key ~= draft.unavail_key then
			draft.unavail, draft.unavail_key = off, key
			changed = true
			log("unavailable: %s", key)
		end
	end
	local offer, detail
	if grid and gm == K.MODE_SD and not draft.steps[draft.me or 0] then
		offer, detail = sd_offer(grid, used_set())
	end
	if not detail and gm == K.MODE_SD and not draft.steps[draft.me or 0] then
		offer, detail = draft.offer, draft.offer_key
	end
	if detail ~= draft.offer_key then
		draft.offer, draft.offer_key = offer, detail
		changed = true
		if detail then
			log("single draft: %s%s", detail, offer and "" or " (not applied)")
		end
	end
	if changed then
		draft.dirty = true
	end
	local line = table.concat(sig, " ")
	if line ~= draft.sync_sig then
		draft.sync_sig = line
		log("sync: team %s, me %s role %s | %s", tostring(my_team), tostring(draft.me), tostring(draft.my_role), line)
	end
end

local G = {
	live = false,
	match = nil,
	hero = nil,
	pos = nil,
	pos_for = nil,
	them = {},
	seen = {},
	owned = {},
	ever = {},
	main = {},
	bpos = nil,
	time = 0,
	plan = nil,
	sig = nil,
	next_at = 0,
	T1 = {},
	anti = {},
	pack = 0,
	pack_free = 0,
	ew = {},
}

local function progress(item, used, depth, min_cost, skip)
	local have = 0
	for _, part in ipairs(item.parts) do
		local p = I.by_name[part]
		if p and part ~= skip then
			if (G.owned[part] or 0) > (used[part] or 0) and p.cost >= (min_cost or 0) then
				used[part] = (used[part] or 0) + 1
				have = have + p.cost
			elseif depth < 3 and p.created then
				have = have + progress(p, used, depth + 1, min_cost, skip)
			end
		end
	end
	return have
end

do
	local function item_name(item)
		local ok, name = pcall(Ability.GetName, item)
		if ok and type(name) == "string" and name ~= "" then
			return (name:gsub("^item_", ""))
		end
		return nil
	end

	local function my_pos(h)
		for i, step in ipairs(STEPS()) do
			if draft.steps[i] == h and step.kind == "P" and step_team(i) == 0 and draft.slot_pos[i] then
				return draft.slot_pos[i]
			end
		end
		local ok, td = pcall(Player.GetTeamData, Players.GetLocal())
		local role = ok and type(td) == "table" and K.LANE_BITS[math.tointeger(tonumber(td.lane_selection_flags) or 0) or 0]
		if role then
			return role
		end
		local best, best_p = -math.huge, 1
		for p, lp in ipairs(M.pos(h)) do
			if lp > best then
				best, best_p = lp, p
			end
		end
		return best_p
	end

	local function counter_v(name, T, cover)
		local v = 0
		for threat, w in pairs(K.COUNTERS[name] or {}) do
			v = v + w * math.min(1, (T[threat] or 0) * (cover[threat] or 1))
		end
		return math.min(1, v)
	end

	local function value(cd, T, cover, anti)
		local v = cd.share >= K.ITEM_SHARE and counter_v(cd.item.name, T, cover) or 0
		return cd.share + K.ITEM_COUNTER_W * v * math.min(1, cd.share / K.ITEM_SHARE_FULL) - (anti[cd.item.name] or 0)
	end

	local function coverage(slots, skip)
		local left = {}
		for _, s in ipairs(slots) do
			if s ~= skip then
				for threat, w in pairs(K.COUNTERS[s.item.name] or {}) do
					left[threat] = (left[threat] or 1) * (1 - K.COVER * w)
				end
			end
		end
		return left
	end

	local function owns(item)
		if (G.owned[item.name] or 0) > 0 or G.ever[item.name] then
			return true
		end
		for name in pairs(G.ever) do
			local o = I.by_name[name]
			if o then
				for _, part in ipairs(o.parts) do
					if part == item.name then
						return true
					end
				end
			end
		end
		return false
	end

	local function eligible(name, item)
		return item and not K.SLOT_SKIP[name]
			and (K.BOOTS[name] or K.SLOT_EXTRA[name] or (item.created and item.cost >= K.SLOT_MIN_COST))
	end

	local function clash(slots, skip, cd)
		for _, s in ipairs(slots) do
			if s ~= skip and (s.item == cd.item or I.related(s.item, cd.item)
				or (not K.BOOTS[s.item.name] and I.siblings(s.item, cd.item))) then
				return true
			end
		end
		return false
	end

	local function enemy_weights(them)
		local ew, pos = {}, {}
		if cfg.lanes ~= 1 then
			return ew
		end
		local known, rest = draft.enemy_pos or {}, {}
		for _, e in ipairs(them) do
			pos[e] = known[e]
			if not pos[e] then
				rest[#rest + 1] = e
			end
		end
		local block = {}
		for _, p in pairs(pos) do
			block[p] = true
		end
		local _, map = M.assign(rest, block)
		for j, e in ipairs(rest) do
			pos[e] = map[j]
		end
		for _, e in ipairs(them) do
			ew[e] = (pos[e] or 1) >= 4 and K.SUPPORT_ITEM_W or 1
		end
		return ew
	end

	local function item_threat_counts()
		local counts = {}
		for _, e in ipairs(G.them) do
			for name in pairs(G.seen[e] or {}) do
				for threat in pairs(K.ENEMY_ITEMS[name] or {}) do
					counts[threat] = (counts[threat] or 0) + (G.ew[e] or 1)
				end
			end
		end
		return counts
	end

	local function add_threats(e, T, from, counts)
		local t = copy(I.threats(e))
		if counts then
			for name in pairs(G.seen[e] or {}) do
				for threat, w in pairs(K.ENEMY_ITEMS[name] or {}) do
					if (counts[threat] or 0) >= K.ITEM_THREAT_MIN then
						w = w * (G.ew[e] or 1)
						t[threat] = (t[threat] or 0) + w
						from[#from + 1] = { e = e, item = name, threat = threat, w = w }
					end
				end
			end
		end
		for k, v in pairs(t) do
			t[k] = math.min(1, v)
			T[k] = (T[k] or 0) + t[k]
		end
		return t
	end

	local function reason_for(cd, from)
		local vs, best = K.COUNTERS[cd.item.name] or {}, nil
		for _, f in ipairs(from) do
			local w = vs[f.threat]
			if w and (not best or w * f.w > best.x) then
				best = { e = f.e, item = f.item, x = w * f.w }
			end
		end
		return best
	end

	local function place_owned(slots, data, T1, anti)
		local function lowest(filter)
			local worst, worst_v
			for i, s in ipairs(slots) do
				if filter(s) then
					local v = value(s, T1, coverage(slots, s), anti)
					if not worst or v < worst_v then
						worst, worst_v = i, v
					end
				end
			end
			return worst
		end
		local names = {}
		for name in pairs(G.owned) do
			names[#names + 1] = name
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local item = I.by_name[name]
			if eligible(name, item) then
				local placed = false
				for _, s in ipairs(slots) do
					if s.item == item or (s.after and s.after.item == item) then
						placed = true
					end
					for _, part in ipairs(s.item.parts) do
						if part == name then
							placed = true
						end
					end
				end
				if not placed then
					local idx
					for i, s in ipairs(slots) do
						if not idx and not owns(s.item) and ((K.BOOTS[name] and K.BOOTS[s.item.name])
							or (s.after and s.after.item == item) or I.related(s.item, item) or I.siblings(s.item, item)) then
							idx = i
						end
					end
					idx = idx or lowest(function(s)
						return not owns(s.item) and not s.core
					end) or lowest(function(s)
						return not owns(s.item)
					end)
					if idx then
						local r = data.rows[name]
						slots[idx] = {
							item = item,
							count = r and r.n or 0,
							share = r and I.share(data, r) or 0,
							t = r and r.t or G.time,
							bought = true,
						}
					end
				end
			end
		end
	end

	local function swap_slots(slots, cands, T0, T1, from, anti, anti_from)
		local swaps = 0
		while swaps < K.SWAPS_MAX do
			local best
			for i, s in ipairs(slots) do
				if not s.core and not s.bought and not s.swapped and not K.BOOTS[s.item.name] and not owns(s.item)
					and progress(s.item, {}, 0, K.SIGNAL_MIN) == 0 then
					local cover = coverage(slots, s)
					local cur = value(s, T1, cover, anti)
					local hurt = (anti[s.item.name] or 0) > 0
					for _, cd in pairs(cands) do
						if not cd.drop and not clash(slots, s, cd) then
							local v1 = value(cd, T1, cover, anti)
							local fresh = hurt or v1 > value(cd, T0, cover, anti) + 0.02
							local gain = v1 - cur
							if fresh and gain >= K.SWAP_MARGIN and (not best or gain > best.gain) then
								best = { i = i, cd = cd, gain = gain, hurt = hurt }
							end
						end
					end
				end
			end
			if not best then
				return
			end
			local old = slots[best.i]
			local new = copy(best.cd)
			new.swapped, new.from = true, old.item
			new.reason = best.hurt and anti_from[old.item.name] or reason_for(new, from)
			slots[best.i] = new
			swaps = swaps + 1
		end
	end

	local function contains(item, name, depth)
		for _, part in ipairs(item.parts) do
			if part == name then
				return true
			end
			local p = I.by_name[part]
			if p and depth < 3 and contains(p, name, depth + 1) then
				return true
			end
		end
		return false
	end

	local function keep_rate(data, item)
		local r = data.rows[item.name]
		if not r or r.n < K.KEEP_MIN then
			return nil
		end
		return (data.fin[item.id] or 0) / r.n
	end

	local function scepter_in_full_bag()
		if #G.main < 6 then
			return false
		end
		for _, name in ipairs(G.main) do
			if name == "ultimate_scepter" then
				return true
			end
		end
		return false
	end

	local function needed(slots, it)
		for _, sl in ipairs(slots) do
			local items = { sl.item }
			if sl.after then
				items[#items + 1] = sl.after.item
			end
			for _, p in ipairs(items) do
				if not owns(p) and contains(p, it.name, 0) then
					return true
				end
			end
		end
		return false
	end

	local function take(bag, name)
		for j = #bag, 1, -1 do
			if bag[j] == name then
				table.remove(bag, j)
				return
			end
		end
	end

	local function sell_for(slots, bag, item, data)
		local in_bag = {}
		for _, name in ipairs(bag) do
			in_bag[name] = true
		end
		local worst, worst_k
		local function pick(boots)
			for _, name in ipairs(G.main) do
				local it = I.by_name[name]
				if it and in_bag[name] and not K.SELL_SKIP[name] and not K.STACK[name] and it.cost > 0
					and (boots and K.SELL_BOOTS[name] or not K.BOOTS[name])
					and it.cost <= K.SELL_MAX and it.cost <= item.cost * K.SELL_RATIO and not needed(slots, it)
					and counter_v(name, G.T1, {}) < K.SELL_COUNTER then
					local k = keep_rate(data, it) or 0
					if not worst or k < worst_k or (k == worst_k and it.cost < worst.cost) then
						worst, worst_k = it, k
					end
				end
			end
		end
		pick(false)
		if not worst and #bag >= K.SLOTS and item.cost >= K.SELL_BOOTS_FOR then
			pick(true)
		end
		if not worst then
			return nil
		end
		local d = { name = worst.name, label = worst.label }
		if G.pack > 0 then
			G.pack, d.stash = G.pack - 1, true
		end
		return d
	end

	local function replacement(slots, sl, cands, anti)
		local old = sl.item
		local function ok(cd)
			return cd and not cd.drop and cd.item ~= old and not owns(cd.item) and not clash(slots, sl, cd)
				and (anti[cd.item.name] or 0) < K.ANTI_HARD
		end
		for _, name in ipairs(K.INSTEAD[old.name] or {}) do
			local cd = cands[name]
			if ok(cd) and cd.share >= K.INSTEAD_SHARE then
				return copy(cd)
			end
		end
		local best
		for name, cd in pairs(cands) do
			if ok(cd) and cd.item.cost >= old.cost * K.INSTEAD_COST and (not K.PHYS_ITEMS[old.name] or K.PHYS_ITEMS[name])
				and (not best or cd.share > best.share) then
				best = cd
			end
		end
		return best and copy(best)
	end

	local function drop_anti(slots, cands, anti, anti_from)
		for i, sl in ipairs(slots) do
			local w = anti[sl.item.name] or 0
			if w >= K.ANTI_HARD and not sl.bought and not owns(sl.item)
				and progress(sl.item, {}, 0, K.SIGNAL_MIN) < sl.item.cost * K.ANTI_KEEP then
				local new = replacement(slots, sl, cands, anti)
				if new then
					new.swapped, new.from, new.reason = true, sl.item, anti_from[sl.item.name]
					new.after, new.after_kind = sl.after, sl.after_kind
					slots[i] = new
					sl = new
				end
			end
			if sl.after and (anti[sl.after.item.name] or 0) >= K.ANTI_HARD and not owns(sl.after.item) then
				sl.after = nil
			end
		end
	end

	local function dis_planned(slots, item)
		for _, sl in ipairs(slots) do
			if sl.item == item then
				return sl
			end
		end
		return nil
	end

	local function disassemble(slots, cands, anti)
		local kept = G.dis
		if kept then
			local from, cd = I.by_name[kept.from], cands[kept.to]
			local in_main = false
			for _, name in ipairs(G.main) do
				if name == kept.from then
					in_main = true
				end
			end
			if not in_main and from and cd and ((G.owned[kept.part] or 0) > 0 or owns(cd.item)) then
				local rest = kept.rest and { item = I.by_name[kept.rest], into = kept.into and cands[kept.into] }
				return { from = from, cd = cd, planned = dis_planned(slots, cd.item), rest = rest and rest.item and rest }
			end
		end
		G.dis = nil
		local have, seen = {}, {}
		for _, sl in ipairs(slots) do
			if sl.after and sl.after_kind == "dis" then
				return nil
			end
			if not seen[sl.item.name] then
				seen[sl.item.name] = true
				have[#have + 1] = sl.item.name
			end
		end
		for _, name in ipairs(G.main) do
			if not seen[name] then
				seen[name] = true
				have[#have + 1] = name
			end
		end
		local function free(cd)
			return cd and not cd.drop and not owns(cd.item) and (anti[cd.item.name] or 0) < K.ANTI_HARD
				and cd.share >= K.DIS_SHARE
		end
		for _, x in ipairs(have) do
			local it = I.by_name[x]
			if it and K.DISASSEMBLE[x] and counter_v(x, G.T1, {}) < K.DIS_KEEP then
				local best, part
				for _, cd in pairs(cands) do
					if free(cd) and cd.item ~= it and not I.related(cd.item, it) then
						for _, p in ipairs(cd.item.parts) do
							for _, q in ipairs(it.parts) do
								if p == q and I.by_name[q] and (not best or cd.share > best.share) then
									best, part = cd, q
								end
							end
						end
					end
				end
				if best then
					local rest
					for _, q in ipairs(it.parts) do
						local qi = I.by_name[q]
						if q ~= part and qi and not q:find("^recipe_") and qi.cost >= K.SLOT_MIN_COST then
							rest = { item = qi }
							for _, cd in pairs(cands) do
								if free(cd) and cd ~= best and cd.item ~= it and not I.related(cd.item, it)
									and cd.share >= K.MORE_SHARE and not I.related(cd.item, best.item) then
									for _, p in ipairs(cd.item.parts) do
										if p == q and (not rest.into or cd.share > rest.into.share) then
											rest.into = cd
										end
									end
								end
							end
						end
					end
					G.dis = {
						from = it.name, to = best.item.name, part = part,
						rest = rest and rest.item.name, into = rest and rest.into and rest.into.item.name,
					}
					return { from = it, cd = best, planned = dis_planned(slots, best.item), rest = rest }
				end
			end
		end
		return nil
	end

	local function more_items(data, slots, room, bag, dis)
		local cands = I.collect(data)
		local last_t, taken = 0, {}
		if dis then
			taken[#taken + 1] = dis.cd.item
			if dis.rest and dis.rest.into then
				taken[#taken + 1] = dis.rest.into.item
			end
		end
		for _, sl in ipairs(slots) do
			last_t = math.max(last_t, sl.t or 0, sl.after and sl.after.t or 0)
			taken[#taken + 1] = sl.item
			if sl.after then
				taken[#taken + 1] = sl.after.item
			end
		end
		for name in pairs(G.ever) do
			local it = I.by_name[name]
			if it and eligible(name, it) then
				taken[#taken + 1] = it
			end
		end
		local function fam(item)
			local f, n = item.name:match("^(.-)_(%d)$")
			if f and I.by_name[f] then
				return f, tonumber(n)
			end
			return item.name, 1
		end
		local function free(item)
			local fi, li = fam(item)
			for _, t in ipairs(taken) do
				local ft, lt = fam(t)
				if t == item or (ft == fi and li <= lt) or I.related(t, item)
					or (not K.BOOTS[t.name] and not K.BOOTS[item.name] and I.siblings(t, item)) then
					return false
				end
			end
			return not owns(item)
		end
		local list = {}
		for _, cd in pairs(cands) do
			if not cd.drop and cd.item.cost >= K.MORE_COST and cd.share >= K.MORE_SHARE
				and (cd.t >= last_t - K.MORE_GAP or cd.share >= K.MORE_POP) and free(cd.item) and (G.anti[cd.item.name] or 0) < K.ANTI_HARD then
				list[#list + 1] = { item = cd.item, t = cd.t, share = cd.share }
			end
		end
		local boots
		for name in pairs(G.owned) do
			if K.BOOTS[name] then
				boots = I.by_name[name]
			end
		end
		if boots then
			for _, name in ipairs(K.BOOTS_UP) do
				local r, it = data.rows[name], I.by_name[name]
				local fits = it and (name == "travel_boots" or I.related(boots, it))
				if r and fits and name ~= boots.name and not owns(it) and I.share(data, r) >= K.MORE_SHARE then
					list[#list + 1] = { item = it, t = r.t, share = I.share(data, r), instead = boots, swap = true }
				end
			end
		end
		local in_plan, offered = {}, {}
		for _, t in ipairs(taken) do
			in_plan[t] = true
		end
		for _, name in ipairs(bag) do
			local base = I.by_name[name]
			local br = data.rows[name]
			if base and eligible(name, base) and br and br.n > 0 and not K.BOOTS[name] then
				for _, up in pairs(I.items) do
					local r = data.rows[up.name]
					if r and r.n >= K.MORE_UP * br.n and not offered[up] and not in_plan[up] and not K.MORE_SKIP[up.name]
						and not owns(up) and (G.anti[up.name] or 0) < K.ANTI_HARD then
						for _, part in ipairs(up.parts) do
							if part == base.name then
								offered[up] = true
								list[#list + 1] = { item = up, t = r.t, share = I.share(data, r), instead = base }
							end
						end
					end
				end
			end
		end
		local bless = I.by_name[K.BLESSING]
		if bless and not owns(bless) then
			local entry
			for _, mo in ipairs(list) do
				if mo.item == bless then
					entry = mo
				end
			end
			if not entry and scepter_in_full_bag() then
				local r = data.rows[K.BLESSING]
				entry = { item = bless, t = r and r.t or G.time, instead = I.by_name.ultimate_scepter }
				list[#list + 1] = entry
			end
			if entry then
				entry.share, entry.frees = 1, true
			end
		end
		table.sort(list, function(a, b)
			if (a.instead ~= nil) ~= (b.instead ~= nil) then
				return a.instead ~= nil
			end
			if a.share ~= b.share then
				return a.share > b.share
			end
			return a.item.name < b.item.name
		end)
		local room_left = room
		local in_bag = {}
		for _, name in ipairs(bag) do
			in_bag[name] = true
		end
		local chosen = {}
		for _, mo in ipairs(list) do
			local ok = #chosen < K.MORE_MAX
			for _, c in ipairs(chosen) do
				if fam(c.item) == fam(mo.item) or I.related(c.item, mo.item) or I.siblings(c.item, mo.item)
					or (K.BOOTS[c.item.name] and K.BOOTS[mo.item.name]) then
					ok = false
				end
			end
			if ok and (not mo.instead or not (mo.swap or in_bag[mo.instead.name])) then
				if room_left > 0 then
					room_left = room_left - 1
				else
					mo.sell = sell_for(slots, bag, mo.item, data)
					if mo.sell then
						take(bag, mo.sell.name)
					else
						ok = false
					end
				end
			end
			if ok then
				chosen[#chosen + 1] = mo
				if mo.frees then
					room_left = room_left + 1
				end
			end
		end
		list = chosen
		table.sort(list, function(a, b)
			if (a.frees or false) ~= (b.frees or false) then
				return a.frees == true
			end
			return a.t < b.t
		end)
		local out = {}
		for i, mo in ipairs(list) do
			local d = { name = mo.item.name, label = mo.item.label, cost = mo.item.cost, t = mo.t, more = true }
			if mo.swap then
				d.base, d.kind, d.from = { name = mo.instead.name, label = mo.instead.label }, "up", mo.instead.label
				d.body = L("cd_tip_swap"):format(mo.instead.label)
			elseif mo.instead then
				d.base, d.kind = { name = mo.instead.name, label = mo.instead.label }, "up"
				d.body = mo.frees and L("cd_tip_bless") or L("cd_tip_up_from"):format(mo.instead.label)
			else
				d.body = ""
			end
			d.sell = mo.sell
			out[i] = d
		end
		return out
	end

	function G.compute()
		local base = I.build(G.hero, G.bpos, G.them)
		if not base then
			return nil
		end
		if base.none then
			return { none = true, hero = G.hero, pos = G.bpos, slots = {} }
		end
		local data = I.buys[G.hero].pos[G.bpos]
		if #base.slots == 0 then
			return nil
		end
		local adapt = cfg.padapt == 1
		local T0, T1, from, per1 = {}, {}, {}, {}
		local counts = adapt and item_threat_counts() or nil
		for _, e in ipairs(G.them) do
			add_threats(e, T0, {}, nil)
			per1[e] = add_threats(e, T1, from, counts)
		end
		local anti, anti_from = {}, {}
		if adapt then
			for _, e in ipairs(G.them) do
				for name in pairs(G.seen[e] or {}) do
					for target, w in pairs(K.ANTI[name] or {}) do
						if w > (anti[target] or 0) then
							anti[target], anti_from[target] = w, { e = e, item = name }
						end
					end
				end
			end
		end
		G.T1, G.anti = T1, anti
		local slots = {}
		for i, cd in ipairs(base.slots) do
			slots[i] = copy(cd)
		end
		place_owned(slots, data, T1, anti)
		local cands = I.collect(data)
		if adapt then
			swap_slots(slots, cands, T0, T1, from, anti, anti_from)
			local function locked(sl)
				return sl.core or sl.bought or owns(sl.item) or progress(sl.item, {}, 0, K.SIGNAL_MIN) > 0
			end
			for _, new in ipairs(I.must(slots, cands, per1, G.them, G.hero, G.bpos, locked)) do
				new.swapped, new.from = true, new.replaced
				new.reason = reason_for(new, from)
			end
			for _, new in ipairs(I.react(slots, cands, G.them, G.seen, G.hero, G.bpos, locked, G.ew)) do
				new.swapped, new.from = true, new.replaced
			end
			drop_anti(slots, cands, anti, anti_from)
			for _, sl in ipairs(slots) do
				if sl.swapped then
					local hero = sl.reason and D.by_id[sl.reason.e]
					log("panel swap: %s -> %s (%s %s)", sl.from and sl.from.name or "?", sl.item.name,
						hero and hero.name or "-", sl.reason and sl.reason.item or "-")
				end
			end
		end
		table.sort(slots, function(a, b)
			if a.t ~= b.t then
				return a.t < b.t
			end
			return a.item.cost < b.item.cost
		end)
		local dis = disassemble(slots, cands, anti)
		local steps = {}
		for _, sl in ipairs(slots) do
			if sl.pre then
				steps[#steps + 1] = { s = sl, item = sl.pre.item, t = sl.pre.t, pre = true }
			end
			if dis and dis.planned == sl and not owns(sl.item) then
				steps[#steps + 1] = { s = sl, item = sl.item, t = sl.t, base = dis.from, kind = "dis", dis = dis }
			else
				steps[#steps + 1] = { s = sl, item = sl.item, t = sl.t, via = sl.pre and sl.pre.item }
			end
			if sl.after then
				steps[#steps + 1] = { s = sl, item = sl.after.item, t = sl.after.t, base = sl.item, kind = sl.after_kind }
			end
		end
		for _, e in ipairs(base.early or {}) do
			steps[#steps + 1] = { item = e.item, t = e.t, early = e }
		end
		if base.shard then
			steps[#steps + 1] = { item = base.shard.item, t = base.shard.t, consume = true }
		end
		if dis and not dis.planned then
			steps[#steps + 1] = { item = dis.cd.item, t = math.max(G.time, dis.cd.t), base = dis.from, kind = "dis", dis = dis }
		end
		if dis and dis.rest and dis.rest.into and not dis_planned(slots, dis.rest.into.item) then
			local into = dis.rest.into
			steps[#steps + 1] = { item = into.item, t = math.max(G.time, dis.cd.t, into.t) + 1, base = dis.rest.item, kind = "up" }
		end
		table.sort(steps, function(a, b)
			if a.t ~= b.t then
				return a.t < b.t
			end
			return (a.base and 1 or 0) < (b.base and 1 or 0)
		end)
		local function step_done(st)
			if st.base or st.pre or st.early or st.consume then
				return owns(st.item)
			end
			return st.s.bought or owns(st.item)
		end
		local last_t
		for _, st in ipairs(steps) do
			if step_done(st) then
				last_t = math.max(last_t or st.t, st.t)
			end
		end
		local order, skipped, gone = {}, {}, {}
		for _, st in ipairs(steps) do
			local done = step_done(st)
			local dep = st.base or st.via
			st.signal = done and 0 or progress(st.item, {}, 0, K.SIGNAL_MIN, (dep or {}).name)
			local behind = last_t and st.t + K.SKIP_GAP < last_t
			if not done and not st.consume and st.signal == 0 and (behind or (dep and gone[dep.name])) then
				if not st.early then
					st.skipped = true
					skipped[#skipped + 1] = st
					gone[st.item.name] = true
				end
			else
				order[#order + 1] = st
			end
		end
		for _, st in ipairs(skipped) do
			order[#order + 1] = st
		end
		steps = order
		local bag = {}
		for _, name in ipairs(G.main) do
			bag[#bag + 1] = name
		end
		local room = K.SLOTS - #G.main
		local bless = I.by_name[K.BLESSING]
		G.pack = G.pack_free or 0
		local hard = 0
		for _, name in ipairs(G.main) do
			local it = I.by_name[name]
			if it and (K.BOOTS[name] or it.cost >= K.SLOT_MIN_COST) then
				hard = hard + 1
			end
		end
		for _, st in ipairs(steps) do
			if not step_done(st) and not K.NO_SLOT[st.item.name] then
				local parts = 0
				if st.dis then
					parts = 1
					local had = false
					for j = #bag, 1, -1 do
						if not had and bag[j] == st.dis.from.name then
							table.remove(bag, j)
							had = true
						end
					end
					local rest = st.dis.rest
					if rest and rest.into then
						if had then
							bag[#bag + 1] = rest.item.name
						end
					elseif rest and (had or (G.owned[rest.item.name] or 0) > 0) then
						st.left = { name = rest.item.name, label = rest.item.label, left = true }
					end
				end
				for j = #bag, 1, -1 do
					if contains(st.item, bag[j], 0) then
						table.remove(bag, j)
						parts = parts + 1
					end
				end
				if parts == 0 then
					if room > 0 then
						room = room - 1
					else
						st.sell = sell_for(slots, bag, st.item, data)
						if st.sell then
							take(bag, st.sell.name)
						elseif hard < K.SELL_HARD then
							for j = #bag, 1, -1 do
								local it = I.by_name[bag[j]]
								if it and not K.BOOTS[bag[j]] and it.cost < K.SLOT_MIN_COST then
									table.remove(bag, j)
									break
								end
							end
						elseif st.item.name == "ultimate_scepter" and bless and not owns(bless) then
							st.item, st.bless = bless, true
						else
							st.no_room = true
							log("no room for %s: main [%s], bag [%s]", st.item.name, table.concat(G.main, ","), table.concat(bag, ","))
						end
					end
				end
				if not st.no_room and not st.bless then
					bag[#bag + 1] = st.item.name
				end
			end
		end
		local target, target_k
		for _, st in ipairs(steps) do
			if not step_done(st) and not st.no_room and st.signal > 0 then
				local k = st.signal / math.max(1, st.item.cost)
				if not target or k > target_k then
					target, target_k = st, k
				end
			end
		end
		if not target then
			for _, st in ipairs(steps) do
				if not target and not step_done(st) and not st.no_room then
					target = st
				end
			end
		end
		local plan = { hero = G.hero, slots = {}, pos = G.bpos }
		local start = { items = {}, gold = base.gold, done = true }
		for _, st in ipairs(base.start) do
			local name = st.item.name
			local have = G.owned[name] or 0
			if name == "ward_observer" or name == "ward_sentry" then
				have = have + (G.owned.ward_dispenser or 0)
			end
			if have < st.q and G.ever[name] and G.time > 0 then
				have = st.q
			end
			local d = { name = name, label = st.item.label, cost = st.item.cost, q = st.q, have = math.min(have, st.q) }
			d.state = d.have >= st.q and "done" or "next"
			d.title = st.q > 1 and ("%s x%d"):format(st.item.label, st.q) or st.item.label
			start.done = start.done and d.state == "done"
			start.items[#start.items + 1] = d
		end
		plan.start = #start.items > 0 and start or nil
		for i, st in ipairs(steps) do
			local s = st.s
			local d = { name = st.item.name, label = st.item.label, cost = st.item.cost, t = st.t }
			if step_done(st) then
				d.state = "done"
			elseif st == target then
				d.state = "next"
				plan.next = d
			else
				d.state = "later"
			end
			local lines = {}
			if st.early then
				lines[1] = st.early.up and L("cd_tip_upgrade"):format(st.early.up.label) or nil
			elseif st.pre then
				lines[1] = L("cd_tip_upgrade"):format(s.item.label)
			elseif st.consume then
				lines[1] = L("cd_tip_noslot")
			elseif st.base then
				d.base, d.kind = { name = st.base.name, label = st.base.label }, st.kind
				lines[1] = L(st.kind == "up" and "cd_tip_up_from" or "cd_tip_dis_from"):format(st.base.label)
				local rest = st.dis and st.dis.rest
				if rest and rest.into then
					lines[2] = L("cd_tip_dis_left"):format(rest.item.label, rest.into.item.label)
				elseif rest then
					lines[2] = L("cd_tip_dis_sell"):format(rest.item.label)
				end
			else
				if s.swapped then
					d.from = s.from.label
					lines[1] = L("cd_tip_swap"):format(s.from.label)
					local r = s.reason
					if r then
						local hero = D.by_id[r.e]
						local it = I.by_name[r.item]
						lines[2] = L("cd_tip_swap_why"):format(hero and hero.name or "?", it and it.label or r.item)
						d.reason = r.e
					end
				elseif s.must and s.vs then
					d.reason = s.vs[1]
				end
				if st.via then
					d.base, d.kind = { name = st.via.name, label = st.via.label }, "up"
				end
				local body = I.body(s)
				if body ~= "" then
					lines[#lines + 1] = body
				end
			end
			if st.skipped then
				lines[#lines + 1] = L("cd_tip_skipped")
			end
			d.body = table.concat(lines, "\n")
			plan.slots[i] = d
		end
		plan.complete = plan.next == nil
		plan.more = more_items(data, slots, room, bag, dis)
		for _, m in ipairs(plan.more) do
			if m.base and not m.from then
				for _, d in ipairs(plan.slots) do
					if d.name == m.base.name then
						local line = L("cd_tip_upgrade"):format(m.label)
						d.body = d.body ~= "" and d.body .. "\n" .. line or line
					end
				end
			end
		end
		for i, d in ipairs(plan.more) do
			d.state = "later"
			if plan.complete and i == 1 then
				d.state, plan.next = "next", d
			end
		end
		if target then
			plan.sell = target.sell or target.left
		elseif plan.next then
			plan.sell = plan.next.sell
		end
		if hard < K.SELL_HARD then
			if plan.sell and not plan.sell.left then
				plan.sell = nil
			end
			for _, d in ipairs(plan.more) do
				d.sell = nil
			end
		end
		return plan
	end

	local function stop()
		G.live, I.want = false, nil
	end

	function G.tick()
		if cfg.panel ~= 1 then
			stop()
			return
		end
		local now = os.clock()
		if now < G.next_at then
			return
		end
		G.next_at = now + K.PANEL_EVERY
		local okg, gs = pcall(GameRules.GetGameState)
		local hero = okg and K.PANEL_STATES[gs] and Heroes.GetLocal()
		local info = hero and D.by_unit[NPC.GetUnitName(hero)]
		if not info then
			stop()
			return
		end
		local match = tostring(GameRules.GetMatchID())
		if G.match ~= match then
			G.match, G.seen, G.plan, G.sig, G.pos_for, G.ever, G.dis = match, {}, nil, nil, nil, {}, nil
		end
		local team = Entity.GetTeamNum(hero)
		local them, taken = {}, {}
		for _, e in ipairs(Heroes.GetAll()) do
			if Entity.GetTeamNum(e) ~= team and not NPC.IsIllusion(e) then
				local ei = D.by_unit[NPC.GetUnitName(e)]
				if ei and not taken[ei.id] and #them < 5 then
					taken[ei.id] = true
					them[#them + 1] = ei.id
					if not Entity.IsDormant(e) then
						local old = G.seen[ei.id] or {}
						local items = {}
						for slot = 0, K.ENEMY_INV_LAST do
							local item = NPC.GetItemByIndex(e, slot)
							local name = item and item_name(item)
							if name then
								items[name] = true
								if not old[name] and (K.ENEMY_ITEMS[name] or K.ANTI[name]) then
									log("panel: %s has %s", ei.name, name)
								end
							end
						end
						for name in pairs(old) do
							if not items[name] and (K.ENEMY_ITEMS[name] or K.ANTI[name]) then
								log("panel: %s no longer has %s", ei.name, name)
							end
						end
						G.seen[ei.id] = items
					end
				end
			end
		end
		table.sort(them)
		local owned = {}
		for slot = 0, K.INV_LAST do
			local item = NPC.GetItemByIndex(hero, slot)
			local name = item and item_name(item)
			if name then
				owned[name] = (owned[name] or 0) + 1
			end
		end
		if next(owned) == nil then
			G.ever = {}
		end
		local oks, scepter = pcall(NPC.HasScepter, hero)
		if oks and scepter and not owned.ultimate_scepter then
			owned[K.BLESSING] = 1
		end
		local okm, shard = pcall(NPC.HasModifier, hero, K.SHARD_MOD)
		if okm and shard then
			owned[K.SHARD] = 1
		end
		if G.pos_for ~= info.id then
			G.pos, G.pos_for = my_pos(info.id), info.id
		end
		for name in pairs(owned) do
			G.ever[name] = true
		end
		local main = {}
		for slot = 0, 5 do
			local item = NPC.GetItemByIndex(hero, slot)
			local name = item and item_name(item)
			if name then
				main[#main + 1] = name
			end
		end
		G.main = main
		local pack = K.BACKPACK
		for slot = 6, 5 + K.BACKPACK do
			if NPC.GetItemByIndex(hero, slot) then
				pack = pack - 1
			end
		end
		G.pack_free = pack
		G.hero, G.them, G.owned, G.live, I.want = info.id, them, owned, true, info.id
		G.bpos = I.bpos[info.id] or G.pos
		G.time = GameRules.GetDOTATime(true, true)
		local sig = { info.id, G.bpos, table.concat(them, ","), I.items_at, I.buys_at[info.id] or 0, cfg.padapt, D.rules_rev or 0 }
		local names = {}
		for name, n in pairs(owned) do
			names[#names + 1] = name .. n
		end
		for name in pairs(G.ever) do
			names[#names + 1] = "~" .. name
		end
		table.sort(names)
		sig[#sig + 1] = table.concat(names, ",")
		sig[#sig + 1] = "m" .. table.concat(main, ",")
		sig[#sig + 1] = "p" .. pack .. ":" .. math.floor(G.time / 60)
		G.ew = enemy_weights(them)
		local ews = {}
		for _, e in ipairs(them) do
			ews[#ews + 1] = e .. "=" .. (G.ew[e] or 1)
		end
		sig[#sig + 1] = "w" .. table.concat(ews, ",")
		for _, e in ipairs(them) do
			local list = {}
			for name in pairs(G.seen[e] or {}) do
				if K.ENEMY_ITEMS[name] or K.ANTI[name] then
					list[#list + 1] = name
				end
			end
			table.sort(list)
			sig[#sig + 1] = e .. ":" .. table.concat(list, ",")
		end
		sig = table.concat(sig, "|")
		if sig ~= G.sig then
			G.plan = G.compute()
			G.sig = G.plan and sig or nil
			if G.plan then
				log("panel plan for %d: %d slots, main [%s], next %s, sell %s", info.id, #G.plan.slots, table.concat(main, ","),
					G.plan.next and G.plan.next.name or "-", G.plan.sell and G.plan.sell.name or "-")
			end
		end
	end
end

local function match_score(hero, q)
	if q == "" then
		return 1
	end
	if hero.initials == q then
		return 5
	end
	if hero.key:sub(1, #q) == q then
		return 4
	end
	if #q >= 2 and hero.initials:sub(1, #q) == q then
		return 3
	end
	for _, word in ipairs(hero.words) do
		if word:sub(1, #q) == q then
			return 2
		end
	end
	if hero.key:find(q, 1, true) or hero.short:find(q, 1, true) then
		return 1
	end
	return 0
end

local function best_match()
	local q = norm(draft.query)
	if q == "" or not D.heroes then
		return nil
	end
	local used = used_set()
	local best, best_score
	for _, hero in ipairs(D.heroes) do
		if not used[hero.id] then
			local s = match_score(hero, q)
			if s > 0 and (not best or s > best_score or (s == best_score and hero.name < best.name)) then
				best, best_score = hero, s
			end
		end
	end
	return best
end

local function over_menu(x, y)
	if not Menu.Opened() then
		return false
	end
	local pos, size = Menu.Pos(), Menu.Size()
	return x >= pos.x and x <= pos.x + size.x and y >= pos.y and y <= pos.y + size.y
end

local function in_rect(r, cx, cy)
	return r and cx >= r[1] and cx <= r[3] and cy >= r[2] and cy <= r[4]
end

local function cursor_in_window()
	local cx, cy = Input.GetCursorPos()
	if W.panel_rect and in_rect(W.panel_rect, cx, cy) and not over_menu(cx, cy) then
		return true
	end
	if not W.open or W.vis <= 0 or W.w == 0 or not W.x then
		return false
	end
	if over_menu(cx, cy) then
		return false
	end
	if W.pm_rect and in_rect(W.pm_rect, cx, cy) then
		return true
	end
	return cx >= W.x and cx <= W.x + W.w and cy >= W.y and cy <= W.y + W.h
end

local function hit_at(cx, cy)
	for i = #W.hits, 1, -1 do
		local hit = W.hits[i]
		if cx >= hit[1] and cx <= hit[3] and cy >= hit[2] and cy <= hit[4] then
			return hit
		end
	end
	return nil
end

local function take_owned(item, used)
	if (G.owned[item.name] or 0) - (used[item.name] or 0) > 0 then
		used[item.name] = (used[item.name] or 0) + 1
		return true
	end
	return false
end

local function owned_value(item, used, depth, whole)
	if not whole and take_owned(item, used) then
		return item.cost
	end
	return depth < 3 and progress(item, used, depth + 1) or 0
end

local function full_buy(item, used, out, top)
	if not top and take_owned(item, used) then
		return
	end
	local parts = {}
	for _, part in ipairs(item.parts) do
		local p = I.by_name[part]
		if p then
			parts[#parts + 1] = p
		end
	end
	if #parts == 0 then
		out[#out + 1] = { id = item.id, name = item.name }
		return
	end
	for _, p in ipairs(parts) do
		full_buy(p, used, out, false)
	end
	if item.recipe then
		out[#out + 1] = { id = item.recipe, name = "recipe_" .. item.name }
	end
end

local function buy_list(item, gold, used, out, depth)
	local probe = copy(used)
	local whole = depth == 0
	local need = item.cost - owned_value(item, probe, depth, whole)
	if need <= 0 and not whole then
		owned_value(item, used, depth)
		return 0
	end
	if need <= gold then
		full_buy(item, used, out, whole)
		return math.max(0, need)
	end
	if depth >= 3 then
		return 0
	end
	local parts = {}
	for _, part in ipairs(item.parts) do
		local p = I.by_name[part]
		if p then
			parts[#parts + 1] = p
		end
	end
	table.sort(parts, function(a, b)
		return a.cost > b.cost
	end)
	local spent = 0
	for _, p in ipairs(parts) do
		spent = spent + buy_list(p, gold - spent, used, out, depth + 1)
	end
	return spent
end

local function purchase(item)
	local hero = Heroes.GetLocal()
	if not hero then
		return false
	end
	local ok, err = pcall(Player.PrepareUnitOrders, Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, nil,
		Vector(0, 0, 0), item.id, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, hero, false, false, false, true)
	log("purchase %s (%d): %s", item.name, item.id, ok and "sent" or tostring(err))
	return ok
end

local function buy(name)
	local item = I.by_name and I.by_name[name]
	if not item then
		return false
	end
	local okg, gold = pcall(Player.GetTotalGold, Players.GetLocal())
	gold = okg and tonumber(gold) or 0
	local list = {}
	buy_list(item, gold, {}, list, 0)
	if #list == 0 then
		log("buy %s: nothing to buy, gold %d, cost %d", name, gold, item.cost)
		return false
	end
	local names = {}
	for _, it in ipairs(list) do
		names[#names + 1] = it.name
	end
	log("buy %s: %s (gold %d, recipe %s)", name, table.concat(names, ", "), gold, tostring(item.recipe))
	W.buyq, W.buy_at = list, 0
	return true
end

local function buy_tick()
	local q = W.buyq
	if not q or os.clock() < W.buy_at then
		return
	end
	local it = table.remove(q, 1)
	if it then
		purchase(it)
		W.buy_at = os.clock() + K.BUY_GAP
	end
	if #q == 0 then
		W.buyq = nil
	end
end

local function pin(name, only)
	if not only then
		local item = I.by_name[name]
		local ok, info = pcall(Player.GetQuickBuyInfo, Players.GetLocal())
		for _, id in ipairs(ok and type(info) == "table" and type(info.m_quickBuyItems) == "table" and info.m_quickBuyItems or {}) do
			if item and id == item.id then
				return true
			end
		end
	end
	return pcall(Engine.SetQuickBuy, name, only == true)
end

local function toast(key)
	W.toast = { key = key, t = os.clock() }
end

local function my_hero_id()
	local ok, td = pcall(Player.GetTeamData, Players.GetLocal())
	return ok and type(td) == "table" and (math.tointeger(tonumber(td.selected_hero_id) or 0) or 0) or 0
end

local function pick_block(h)
	local ok, gs = pcall(GameRules.GetGameState)
	if not ok or gs ~= K.HERO_SELECTION then
		return "cd_pk_stage"
	end
	if my_hero_id() > 0 then
		return "cd_pk_have"
	end
	for i, x in pairs(draft.steps) do
		if x == h and not draft.tentative[i] then
			return "cd_pk_taken"
		end
	end
	if (draft.extra_bans or {})[h] or (draft.unavail or {})[h] or (draft.offer and not draft.offer[h]) then
		return "cd_pk_taken"
	end
	return nil
end

local function pick(h)
	local hero = D.by_id[h]
	local why = hero and pick_block(h)
	if not hero or why then
		toast(why or "cd_pk_taken")
		return
	end
	Engine.ExecuteCommand("dota_select_hero " .. hero.unit)
	W.pick_check = { h = h, at = os.clock() + K.PICK_CHECK }
	log("pick %s", hero.unit)
end

local function order_tick()
	buy_tick()
	local c = W.pick_check
	if not c or os.clock() < c.at then
		return
	end
	W.pick_check = nil
	local hid = my_hero_id()
	if hid ~= c.h then
		toast("cd_pk_fail")
		log("pick failed: selected %d", hid)
	end
end

local function click(right)
	local cx, cy = Input.GetCursorPos()
	local hit = hit_at(cx, cy)
	local kind, arg = hit and hit[5], hit and hit[6]
	if W.pos_menu and kind ~= "posset" and kind ~= "posbadge" and kind ~= "pmbg" then
		W.pos_menu = nil
	end
	if W.slot_menu and kind ~= "smenu" and kind ~= "smbg" and not (kind == "slot" and right) then
		W.slot_menu = nil
	end
	if W.set_gear and kind ~= "set_gear" and not in_rect(W.gear_pop, cx, cy) then
		W.set_gear = nil
	end
	if W.pick and kind ~= "pick_ok" and kind ~= "pick_dont" and kind ~= "pickcard" then
		W.pick = nil
		return
	end
	if not hit then
		return
	end
	if kind == "pmbg" or kind == "stgbg" or kind == "newsbg" or kind == "smbg" or kind == "pickcard" then
		return
	elseif kind == "pick_ok" then
		if not right then
			local p = W.pick
			W.pick = nil
			if p.dont then
				set_cfg("pick_ask", 0)
			end
			pick(p.h)
		end
	elseif kind == "pick_dont" then
		if not right then
			W.pick.dont = not W.pick.dont
		end
	elseif kind == "settings" then
		W.settings = not W.settings
		W.pos_menu, W.set_gear = nil, nil
	elseif kind == "set_back" then
		W.settings, W.set_gear = false, nil
	elseif kind == "set_preview" then
		W.preview = not W.preview
	elseif kind == "set_gear" then
		W.set_gear = W.set_gear ~= arg and arg or nil
	elseif kind == "set_src" then
		set_cfg("source", arg)
		draft.dirty = true
	elseif kind == "set_rank" then
		set_cfg("rank", arg)
		draft.dirty = true
	elseif kind == "set_vol" then
		set_cfg("volume", arg)
	elseif kind == "set_scale_up" or kind == "set_scale_down" then
		set_cfg("zoom", clamp(cfg.zoom + (kind == "set_scale_up" and 10 or -10), 70, 130))
	elseif kind == "set_bg" then
		W.slider = true
	elseif kind == "set_toggle" then
		set_cfg(arg, cfg[arg] == 1 and 0 or 1)
		if arg == "lanes" then
			draft.dirty, G.sig = true, nil
		end
	elseif kind == "set_refresh" then
		refresh_data()
	elseif kind == "upd_install" then
		if U.status == "error" and U.url then
			U.status = "available"
		end
		U.install()
	elseif kind == "posbadge" then
		if right then
			set_manual(arg, nil)
			W.pos_menu = nil
		else
			W.pos_menu = not (W.pos_menu and W.pos_menu.slot == arg) and { slot = arg } or nil
			W.settings = false
		end
	elseif kind == "posset" then
		if W.pos_menu then
			set_manual(W.pos_menu.slot, arg > 0 and arg or nil)
		end
		W.pos_menu = nil
	elseif kind == "set_pmode" then
		set_cfg("panel", arg == 2 and 0 or 1)
		if arg == 2 and W.set_gear == "panel" then
			W.set_gear = nil
		end
		if arg < 2 then
			set_cfg("pshop", arg)
			W.phidden = nil
		end
	elseif kind == "set_pview" then
		set_cfg("pview", arg)
	elseif kind == "set_pzoom_up" or kind == "set_pzoom_down" then
		set_cfg("pzoom", clamp(cfg.pzoom + (kind == "set_pzoom_up" and 10 or -10), 60, 160))
	elseif kind == "bpos" then
		I.bpos[arg.h] = arg.p
	elseif kind == "qbuy" then
		local shift = Input.IsKeyDown(K.LSHIFT) or Input.IsKeyDown(K.RSHIFT)
		local ok
		if right then
			ok = buy(arg.name)
		else
			ok = pin(arg.name, shift)
		end
		if ok then
			W.qflash = { id = arg.id, t = os.clock() }
		end
	elseif kind == "phide" then
		if W.preview then
			W.preview = false
		else
			W.phidden = G.match
		end
	elseif kind == "pdrag" then
		if not right then
			W.pdrag, W.pdx, W.pdy = true, cx - W.px, cy - W.py
		end
	elseif kind == "sbar" then
		if not right then
			local grab = cy - arg.ty
			if grab < 0 or grab > arg.th then
				grab = arg.th / 2
			end
			W.sdrag = { id = arg.id, grab = grab }
		end
	elseif kind == "search" then
		W.focus = true
	elseif kind == "head" then
		if not right then
			W.drag, W.dx, W.dy = true, cx - W.x, cy - W.y
		end
	elseif kind == "set_news" then
		W.news = true
	elseif kind == "news_ok" then
		W.news = nil
		Config.WriteInt("draft_helper", "seen", K.VNUM)
	elseif kind == "counter_back" then
		W.counter, W.list_scroll = nil, 0
	elseif kind == "smenu" then
		local i = W.slot_menu and W.slot_menu.slot
		W.slot_menu = nil
		if i and draft.steps[i] then
			if arg == "counter" then
				W.counter, W.list_scroll = draft.steps[i], 0
			else
				draft.steps[i] = nil
				draft.manual[draft.mode][i] = nil
				draft.edit = nil
				if draft.mode == 1 then
					draft.target = i
				end
				draft.dirty = true
			end
		end
	elseif kind == "slot" and right and draft.steps[arg] and STEPS()[arg].kind == "P" then
		local same = W.slot_menu and W.slot_menu.slot == arg
		W.slot_menu = not same and { slot = arg, x = cx - W.ox, y = cy - W.oy } or nil
		draft.edit = nil
	elseif kind == "slot" then
		if right then
			draft.steps[arg] = nil
			draft.manual[draft.mode][arg] = nil
			draft.edit = nil
			if draft.mode == 1 then
				draft.target = arg
			end
		elseif draft.steps[arg] then
			draft.tentative[arg] = nil
			draft.edit = draft.edit ~= arg and arg or nil
		else
			draft.edit = nil
			if draft.mode == 1 then
				draft.target = arg
			end
		end
		draft.dirty = true
	elseif kind == "mode" then
		set_mode(arg)
	elseif kind == "sumrow" then
		draft.build_h = arg
	elseif kind == "hero" or kind == "row" then
		if not right then
			put(arg)
		elseif kind == "row" then
			local why = cfg.pick_ask == 1 and pick_block(arg)
			if why then
				toast(why)
			elseif cfg.pick_ask == 1 then
				W.pick = { h = arg, dont = false }
			else
				pick(arg)
			end
		end
	elseif kind == "pos" then
		draft.filter = arg
		draft.filter_user = true
		draft.dirty = true
		W.list_scroll = 0
	elseif kind == "first" then
		draft.first = arg
		draft.dirty = true
	elseif kind == "undo" then
		undo()
	elseif kind == "reset" then
		reset_draft()
	elseif kind == "close" then
		W.open, W.auto, W.pos_menu, W.settings = false, false, nil, false
	end
end

local function type_key(key)
	local now = os.clock()
	if now - (W.typed[key] or -1) < K.TYPE_GAP then
		return
	end
	W.typed[key] = now
	local ch = K.CHARS[key]
	if ch then
		if #draft.query < 24 then
			draft.query = draft.query .. ch
			W.grid_scroll = 0
		end
	elseif key == K.BACKSPACE then
		if #draft.query > 0 then
			draft.query = draft.query:sub(1, -2)
		else
			undo()
		end
	elseif key == K.ENTER or key == K.PAD_ENTER then
		local hero = best_match()
		if hero then
			put(hero.id)
		end
	elseif key == K.ESCAPE then
		if W.pick then
			W.pick = nil
		elseif W.settings then
			W.settings = false
		elseif #draft.query > 0 then
			draft.query = ""
		else
			W.open = false
		end
	end
end

local function open_window()
	W.open, W.focus = true, true
end

local draw_window, draw_panel, draw_tips
local load_stage, spinner, STAGE_TEXT

do
	local s, m, dt = nil, {}, 0
	local A = W.anim

	local function ease(k)
		local q = 1 - clamp(k, 0, 1)
		return 1 - q * q * q
	end

	local function approach(key, target, speed)
		local v = A[key]
		if v == nil then
			v = target
		else
			v = v + (target - v) * (1 - math.exp(-dt * speed))
			if math.abs(target - v) < 0.002 then
				v = target
			end
		end
		A[key] = v
		return v
	end

	local function tween(key, target, dur)
		local t = A[key]
		if type(t) ~= "table" or W.snap then
			t = { v = target, from = target, to = target, k = 1 }
			A[key] = t
		elseif t.to ~= target then
			t.from, t.to, t.k = t.v, target, 0
		end
		if t.k < 1 then
			t.k = math.min(1, t.k + dt / dur)
			t.v = t.from + (t.to - t.from) * ease(t.k)
		else
			t.v = t.to
		end
		return t.v
	end

	local function mix(c1, c2, k)
		return Color(
			math.floor(c1.r + (c2.r - c1.r) * k + 0.5),
			math.floor(c1.g + (c2.g - c1.g) * k + 0.5),
			math.floor(c1.b + (c2.b - c1.b) * k + 0.5),
			math.floor(c1.a + (c2.a - c1.a) * k + 0.5))
	end

	local function load_font(weight)
		local flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
		for _, name in ipairs(K.FONTS) do
			local ok, handle = pcall(Render.LoadFont, name, flags, weight)
			if ok and handle and handle ~= 0 then
				return handle
			end
		end
		return Render.LoadFont(K.FONTS[#K.FONTS], flags, weight)
	end

	local function ensure_fonts()
		if not W.fonts then
			W.fonts = {
				bold = load_font(Enum.FontWeight.BOLD),
				semi = load_font(Enum.FontWeight.SEMIBOLD),
				medium = load_font(Enum.FontWeight.MEDIUM),
				regular = load_font(Enum.FontWeight.NORMAL),
				icon = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400),
			}
		end
	end

	local function image(path)
		local handle = W.images[path]
		if handle == nil then
			local ok, result = pcall(Render.LoadImage, path)
			handle = (ok and result and result ~= 0) and result or false
			W.images[path] = handle
		end
		return handle or nil
	end

	local function portrait(h)
		local hero = D.by_id[h]
		return hero and image("panorama/images/heroes/" .. hero.unit .. "_png.vtex_c")
	end

	local function mini(h)
		local hero = D.by_id[h]
		return hero and image("panorama/images/heroes/icons/" .. hero.unit .. "_png.vtex_c")
	end

	local function item_img(name)
		return image("panorama/images/items/" .. name .. "_png.vtex_c")
	end

	local function px(v)
		return math.floor(v * s + 0.5)
	end

	local function fade(c, a)
		if a >= 1 then
			return c
		end
		return Color(c.r, c.g, c.b, math.floor(c.a * clamp(a, 0, 1) + 0.5))
	end

	local function tw(font, size, text)
		return Render.TextSize(font, size, text).x
	end

	local function th(font, size)
		local key = font .. "@" .. size
		local h = m[key]
		if not h then
			local v = Render.TextSize(font, size, "Ay").y
			h = (v and v > 0) and v or size
			m[key] = h
		end
		return h
	end

	local function text(font, size, str, x, cy, color, free)
		local y = math.floor(cy - th(font, size) / 2 + 0.5)
		local tx
		if free then
			tx = x
		else
			tx = math.floor(x + 0.5)
		end
		Render.Text(font, size, str, Vec2(tx, y), color)
		return tw(font, size, str)
	end

	local function rect(x0, y0, x1, y1, color, r)
		Render.FilledRect(Vec2(x0, y0), Vec2(x1, y1), color, r or 0, K.ROUND)
	end

	local function outline(x0, y0, x1, y1, a, r)
		rect(x0, y0, x1, y1, fade(P.TIP, a), r)
		Render.Rect(Vec2(x0, y0), Vec2(x1, y1), fade(P.TIP_EDGE, a), r, K.ROUND, math.max(1, px(1)))
	end

	local function backdrop(x, y, w, h, a, r)
		if cfg.blur == 1 then
			local strength = clamp((a - 0.5) / 0.5, 0, 1)
			if strength > 0.01 then
				Render.Blur(Vec2(x, y), Vec2(x + w, y + h), strength, 1.0, r, K.ROUND)
			end
		end
		rect(x, y, x + w, y + h, fade(Color(P.BG.r, P.BG.g, P.BG.b, math.floor(255 * cfg.bg / 100 + 0.5)), a), r)
	end

	local function set_scale(zoom)
		local menu_scale = Menu.Scale()
		s = zoom / 100 * K.BASE_ZOOM * ((menu_scale >= 50 and menu_scale <= 300) and menu_scale / 100 or 1)
	end

	local function hit(x0, y0, x1, y1, kind, arg)
		if W.nohit then
			return
		end
		local clip = W.hit_clip
		if clip then
			y0, y1 = math.max(y0, clip[1]), math.min(y1, clip[2])
			if y1 <= y0 then
				return
			end
		end
		W.hits[#W.hits + 1] = { x0, y0, x1, y1, kind, arg }
	end

	local function hovered(x0, y0, x1, y1)
		local cx, cy = Input.GetCursorPos()
		if (W.gear_block and in_rect(W.gear_block, cx, cy)) or (W.news_block and in_rect(W.news_block, cx, cy)) then
			return false
		end
		return cx >= x0 and cx <= x1 and cy >= y0 and cy <= y1 and not over_menu(cx, cy) and not W.drag
	end

	local function glyph(str, x, cy, size, color)
		local w = tw(W.fonts.icon, size, str)
		text(W.fonts.icon, size, str, x - w / 2, cy, color)
	end

	local function vline(x, cy, half, a)
		rect(x, cy - half, x + math.max(1, px(1)), cy + half, fade(P.SEP, a))
	end

	local function fmt_games(n)
		if n >= 10000 then
			return ("%dk"):format(math.floor(n / 1000 + 0.5))
		elseif n >= 1000 then
			return ("%.1fk"):format(n / 1000)
		end
		return tostring(n)
	end

	local function pct(v)
		return (sigm(v) - 0.5) * 100
	end

	local function fmt_updated(ts)
		if not ts or ts <= 0 then
			return L("cd_upd_never")
		end
		local age = os.time() - ts
		if age < 120 then
			return L("cd_upd_now")
		elseif age < 3600 then
			return L("cd_upd_min"):format(math.floor(age / 60))
		elseif age < 86400 then
			return L("cd_upd_hour"):format(math.floor(age / 3600))
		end
		return L("cd_upd_day"):format(math.floor(age / 86400))
	end

	STAGE_TEXT = {
		heroes = "cd_ld_heroes",
		pro = "cd_ld_pro",
		wait = "cd_ld_wait",
		error = "cd_ld_error",
		slow = "cd_ld_slow",
		gh = "cd_ld_gh",
	}

	function load_stage()
		if D.error and os.clock() < D.next_request then
			return D.error:lower():find("timeout", 1, true) and "slow" or "error"
		end
		if D.status == "cd_st_gh" then
			return "gh"
		end
		if not D.heroes or not D.sets[0].stats then
			return "wait"
		end
		return nil
	end

	function spinner(cx, cy, r, a, color, thick)
		local t = os.clock()
		local p = Vec2(cx, cy)
		Render.Circle(p, r, fade(P.CELL, a * 2), thick, 0, 1, false, 48)
		if color == P.BAD then
			Render.Circle(p, r, fade(color, a), thick, 270, 1, false, 48)
			return
		end
		Render.Circle(p, r, fade(color, a), thick, (t * 320) % 360, 0.22 + 0.1 * math.sin(t * 2.4), true, 48)
	end

	local function pos_icon(p)
		return image("panorama/images/rank_tier_icons/handicap/" .. K.POS_ICON[p] .. "icon_psd.vtex_c")
	end

	local function draw_pos(p, x, cy, size, a)
		local img = pos_icon(p)
		if img then
			Render.Image(img, Vec2(x, math.floor(cy - size / 2 + 0.5)), Vec2(size, size), fade(K.POS_COLOR[p], a))
		end
		return size
	end

	local function tip(id, x0, y0, x1, y1, title, body, pos)
		if W.nohit or W.slot_menu or (W.pos_menu and id:sub(1, 2) ~= "pm") then
			return
		end
		if hovered(x0, y0, x1, y1) then
			W.tip_cand = { id = id, x0 = x0, y0 = y0, x1 = x1, y1 = y1, title = title, body = body, pos = pos, s = s }
		end
	end

	local function draw_tip(a)
		local c = cfg.tips == 1 and W.tip_cand or nil
		W.tip_cand = nil
		local now = os.clock()
		if c and not cursor_in_window() then
			c = nil
		end
		if c then
			if W.tip_id ~= c.id then
				local warm = W.tip_on or (W.tip_off and now - W.tip_off < K.TIP_GRACE and (W.tip_off_a or 0) > 0.5)
				W.tip_id, W.tip_t, W.tip_warm = c.id, warm and now - 1 or now, warm
			end
			W.tip_last = c
		else
			W.tip_id = nil
		end
		local show = c ~= nil and now - W.tip_t > K.TIP_DELAY
		local ta
		if show then
			if not W.tip_on then
				W.tip_on = true
				W.tip_from = W.tip_warm and now - K.TIP_FADE or now
			end
			ta = clamp((now - W.tip_from) / K.TIP_FADE, 0, 1)
		else
			if W.tip_on then
				W.tip_on, W.tip_off, W.tip_off_a = false, now, W.tip_cur or 1
			end
			local since = W.tip_off and now - W.tip_off - K.TIP_HOLD
			if not since then
				ta = 0
			elseif since < 0 then
				ta = W.tip_off_a
			else
				ta = W.tip_off_a * clamp(1 - since / K.TIP_FADE, 0, 1)
			end
		end
		W.tip_cur = ta
		ta = ta * a
		local t = W.tip_last
		if ta <= 0.01 or not t then
			return
		end
		s = t.s or s
		local lines = {}
		for line in (t.body or ""):gmatch("[^\n]+") do
			lines[#lines + 1] = line
		end
		local icon = t.pos and px(14) + px(6) or 0
		local w = icon + tw(W.fonts.bold, px(12), t.title)
		for _, line in ipairs(lines) do
			w = math.max(w, tw(W.fonts.regular, px(11), line))
		end
		local pad_x, pad_y, line_h = px(10), px(8), px(15)
		w = math.floor(w + pad_x * 2 + 0.5)
		local h = pad_y * 2 + px(16) + #lines * line_h + (#lines > 0 and px(2) or 0)
		local screen = Render.ScreenSize()
		local x = math.floor(clamp((t.x0 + t.x1) / 2 - w / 2, 4, screen.x - w - 4))
		local y = math.floor(t.y1 + px(6))
		if y + h > screen.y - 4 then
			y = math.floor(t.y0 - px(6) - h)
		end
		outline(x, y, x + w, y + h, ta, px(8))
		local cy = y + pad_y + px(8)
		local tx = x + pad_x
		if t.pos then
			draw_pos(t.pos, tx, cy, px(14), ta)
			tx = tx + icon
		end
		text(W.fonts.bold, px(12), t.title, tx, cy, fade(P.TEXT, ta))
		cy = cy + px(10) + px(2) + line_h / 2
		for _, line in ipairs(lines) do
			text(W.fonts.regular, px(11), line, x + pad_x, cy, fade(P.MUTED, ta))
			cy = cy + line_h
		end
	end

	local function draw_loader(x0, y0, x1, y1, a, stage)
		local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - px(10)
		local err = stage == "error"
		if err then
			glyph("\u{f071}", cx, cy - px(34), px(22), fade(P.WARN, a))
		else
			spinner(cx, cy - px(34), px(14), a, P.TEXT, math.max(1.5, px(2.5)))
		end
		local title = L(STAGE_TEXT[stage] or "cd_ld_wait")
		text(W.fonts.bold, px(13), title, cx - tw(W.fonts.bold, px(13), title) / 2, cy, fade(P.TEXT, a))
		local sub
		if err or stage == "slow" then
			sub = L("cd_ld_retry"):format(math.max(1, math.ceil(D.next_request - os.clock())))
		elseif stage == "gh" then
			local done, total, job = D.gh.progress()
			if job then
				local what = job.kind == "stats"
					and L(job.S.source == 1 and "cd_gh_cm" or "cd_gh_ranked"):format(fmt_games(tonumber(job.meta.n) or 0))
					or L("cd_gh_" .. job.kind)
				sub = L("cd_ld_step"):format(what, math.min(done + 1, total), total)
				local wait = D.busy and os.clock() - (D.req_at or 0) or 0
				if wait >= 3 then
					sub = sub .. L("cd_gh_wait"):format(math.floor(wait))
				end
			end
		end
		if sub then
			text(W.fonts.regular, px(11), sub, cx - tw(W.fonts.regular, px(11), sub) / 2, cy + px(20), fade(P.MUTED, a))
		end
		if err then
			return
		end
		local bw, bh = px(180), math.max(2, px(3))
		local by = cy + px(38)
		local gp = 0
		if stage == "gh" then
			local done, total = D.gh.progress()
			gp = done / math.max(1, total)
		end
		local prog = tween("loader_p", gp, 0.4)
		rect(cx - bw / 2, by, cx + bw / 2, by + bh, fade(P.CELL, a * 1.6), bh / 2)
		if prog > 0 then
			rect(cx - bw / 2, by, cx - bw / 2 + bw * prog, by + bh, fade(P.GOOD, a * 0.85), bh / 2)
		end
	end

	local function draw_slot(i, x, y, w, h, a)
		local badge
		local step = STEPS()[i]
		local hero = draft.steps[i]
		local r = px(4)
		local placed = W.placed[i]
		if hero and (not placed or placed.h ~= hero) then
			placed = { h = hero, t = os.clock() }
			W.placed[i] = placed
		elseif not hero then
			W.placed[i] = nil
			placed = nil
		end
		local e = placed and ease((os.clock() - placed.t) / K.POP) or 0
		if e < 1 then
			rect(x, y, x + w, y + h, fade(P.CELL, a * (1 - e)), r)
		end
		if hero then
			local sc = 0.84 + 0.16 * e
			local dw, dh = w * sc, h * sc
			local x0, y0 = x + (w - dw) / 2, y + (h - dh) / 2
			local ha = a * e * approach("tent" .. i, (draft.mode == 1 and draft.tentative[i]) and K.TENTATIVE or 1, 12)
			local img = portrait(hero)
			if step.kind == "P" then
				if img then
					Render.Image(img, Vec2(x0, y0), Vec2(dw, dh), fade(P.WHITE, ha), r, K.ROUND)
				else
					rect(x0, y0, x0 + dw, y0 + dh, fade(P.FIELD, ha), r)
				end
				local pos = draft.slot_pos[i]
				if pos then
					local pa = a * approach("sp" .. i .. ":" .. pos, 1, 14) * e
					local size = px(12)
					local manual = draft.manual[draft.mode][i] ~= nil
					local bh = approach("bh" .. i, hovered(x, y + h - size - px(5), x + size + px(8), y + h) and 1 or 0, 20)
					local bg = mix(P.SHADE, P.TIP, math.max(bh, manual and 0.6 or 0))
					rect(x + px(1), y + h - size - px(3), x + size + px(5), y + h - px(1), fade(bg, pa * 0.9), px(3))
					draw_pos(pos, x + px(3), y + h - px(2) - size / 2, size, pa)
					badge = { x, y + h - size - px(5), x + size + px(8), y + h }
				end
			else
				if img then
					Render.Image(img, Vec2(x0, y0), Vec2(dw, dh), fade(P.BAN, ha), r, K.ROUND, Vec2(0, 0), Vec2(1, 1), 1.0)
				else
					rect(x0, y0, x0 + dw, y0 + dh, fade(P.FIELD, ha), r)
				end
				local k = ease((os.clock() - placed.t - K.POP * 0.5) / K.POP)
				if k > 0 then
					local ax, ay = x + w - px(8), y + px(3)
					local bx, by = x + px(8), y + h - px(3)
					Render.Line(Vec2(ax, ay), Vec2(ax + (bx - ax) * k, ay + (by - ay) * k), fade(P.BAD, a * 0.85),
						math.max(1, px(1.5)))
				end
			end
		end
		local hv = approach("sh" .. i, hovered(x, y, x + w, y + h) and 1 or 0, 20)
		if hv > 0 then
			rect(x, y, x + w, y + h, fade(P.HOVER, a * hv), r)
		end
		if i == cur_step() then
			W.cur_target = { x - 1 - W.ox, y - 1 - W.oy, w + 2, h + 2 }
		end
		hit(x, y, x + w, y + h, "slot", i)
		if badge then
			W.badge_rect[i] = { badge[1] - W.ox, badge[2] - W.oy, badge[3] - W.ox, badge[4] - W.oy }
			hit(badge[1], badge[2], badge[3], badge[4], "posbadge", i)
			tip("badge" .. i, badge[1], badge[2], badge[3], badge[4], L("cd_tip_badge_t"), L("cd_tip_badge"))
		else
			W.badge_rect[i] = nil
		end
	end

	local function draw_pos_menu(a)
		local menu = W.pos_menu
		if menu and not W.badge_rect[menu.slot] then
			W.pos_menu, menu = nil, nil
		end
		local ma = approach("pm_a", menu and 1 or 0, 22) * a
		if menu then
			W.pm_last = menu
		end
		menu = menu or W.pm_last
		local anchor = menu and W.badge_rect[menu.slot]
		if ma <= 0.01 or not anchor then
			return
		end
		local size, gap, pad = px(26), px(3), px(4)
		local w = pad * 2 + 6 * size + 5 * gap
		local h = size + pad * 2
		local screen = Render.ScreenSize()
		local x = math.floor(clamp(anchor[1] + W.ox, 4, screen.x - w - 4))
		local y = math.floor(anchor[4] + W.oy + px(4))
		if y + h > screen.y - 4 then
			y = math.floor(anchor[2] + W.oy - px(4) - h)
		end
		outline(x, y, x + w, y + h, ma, px(8))
		if W.pos_menu then
			hit(x, y, x + w, y + h, "pmbg")
			W.pm_rect = { x, y, x + w, y + h }
		end
		local current = draft.manual[draft.mode][menu.slot] or 0
		local cy = y + pad + size / 2
		for k = 0, 5 do
			local bx = x + pad + k * (size + gap)
			local hv = approach("pm_h" .. k, (W.pos_menu and hovered(bx, y + pad, bx + size, y + pad + size)) and 1 or 0, 20)
			local bg = current == k and P.CHIP_ON or mix(P.CELL, P.HOVER, hv)
			rect(bx, y + pad, bx + size, y + pad + size, fade(bg, ma), px(6))
			if k == 0 then
				glyph("\u{f0d0}", bx + size / 2, cy, px(12), fade(current == 0 and P.TEXT or P.MUTED, ma))
			else
				draw_pos(k, bx + (size - px(16)) / 2, cy, px(16), ma)
			end
			if W.pos_menu then
				hit(bx, y + pad, bx + size, y + pad + size, "posset", k)
				tip("pm" .. k, bx, y + pad, bx + size, y + pad + size,
					k == 0 and L("cd_tip_auto_t") or L("cd_posT" .. k), k == 0 and L("cd_tip_pm_auto") or L("cd_tip_pm"), k > 0 and k or nil)
			end
		end
	end

	local function draw_cursor(a)
		local t = W.cur_target
		local ca = approach("cur_a", t and 1 or 0, 16)
		if not t then
			t = W.cur_last
			if not t or ca <= 0 then
				return
			end
		end
		W.cur_last = t
		local x = tween("cur_x", t[1], K.MOVE) + W.ox
		local y = tween("cur_y", t[2], K.MOVE) + W.oy
		local w = tween("cur_w", t[3], K.MOVE)
		local h = tween("cur_h", t[4], K.MOVE)
		local col = mix(P.TEXT, P.MUTED, approach("cur_edit", draft.edit and 1 or 0, 16))
		Render.Rect(Vec2(x, y), Vec2(x + w, y + h), fade(col, a * ca), px(5), K.ROUND, math.max(1, px(1.5)))
	end

	local function segment(id, x, cy, labels, value, kind, a)
		local seg_h, pad = px(24), px(9)
		local widths, total = {}, px(4)
		for i, label in ipairs(labels) do
			widths[i] = tw(W.fonts.medium, px(11), label) + pad * 2
			total = total + widths[i]
		end
		rect(x, cy - seg_h / 2, x + total, cy + seg_h / 2, fade(P.CELL, a), px(7))
		local bx = x + px(2)
		local on_x = bx
		for i = 1, value do
			on_x = on_x + widths[i]
		end
		local kx = tween(id .. "_x", on_x - x, K.MOVE) + x
		local kw = tween(id .. "_w", widths[value + 1], K.MOVE)
		rect(kx, cy - seg_h / 2 + px(2), kx + kw, cy + seg_h / 2 - px(2), fade(P.CHIP_ON, a), px(5))
		for i, label in ipairs(labels) do
			local on = approach(id .. "_t" .. i, value == i - 1 and 1 or 0, 18)
			text(W.fonts.medium, px(11), label, bx + pad, cy, fade(mix(P.MUTED, P.TEXT, on), a))
			hit(bx, cy - seg_h / 2, bx + widths[i], cy + seg_h / 2, kind, i - 1)
			bx = bx + widths[i]
		end
		return total, seg_h
	end

	local function segment_width(labels)
		local total = px(4)
		for _, label in ipairs(labels) do
			total = total + tw(W.fonts.medium, px(11), label) + px(9) * 2
		end
		return total
	end

	local SB = { field = { grid = "grid_scroll", list = "list_scroll", set = "set_scroll" } }

	function SB.scroll(id, key, max)
		local field = SB.field[id]
		local geo = W.sb_geo and W.sb_geo[id]
		local drag = W.sdrag and W.sdrag.id == id
		if drag and geo then
			if Input.IsKeyDown(K.MOUSE1, true) then
				local _, cy = Input.GetCursorPos()
				W[field] = clamp((cy - W.sdrag.grab - geo.y0) / math.max(1, geo.track - geo.th), 0, 1) * max
			else
				W.sdrag, drag = nil, false
			end
		end
		W[field] = clamp(W[field] or 0, 0, max)
		if drag then
			A[key] = { v = W[field], from = W[field], to = W[field], k = 1 }
		end
		return math.floor(tween(key, W[field], K.MOVE) + 0.5)
	end

	function SB.bar(id, x1, y0, y1, shown, max, a)
		W.sb_geo = W.sb_geo or {}
		if not max or max <= 0 then
			W.sb_geo[id] = nil
			return
		end
		local track = y1 - y0
		local th = math.max(px(24), math.floor(track * track / (track + max)))
		local ty = y0 + (track - th) * clamp(shown / max, 0, 1)
		local drag = W.sdrag and W.sdrag.id == id
		local hv = approach("sb_h" .. id, (drag or hovered(x1 - px(12), y0, x1, y1)) and 1 or 0, 18)
		local bw = px(4) + px(3) * hv
		local x0 = x1 - px(3) - bw
		rect(x0, y0, x0 + bw, y1, fade(Color(255, 255, 255, math.floor(10 + 10 * hv)), a), bw / 2)
		rect(x0, ty, x0 + bw, ty + th, fade(Color(255, 255, 255, math.floor(60 + 60 * hv)), a), bw / 2)
		W.sb_geo[id] = { y0 = y0, track = track, th = th }
		hit(x1 - px(12), y0, x1, y1, "sbar", { id = id, ty = ty, th = th })
	end

	local function draw_update_pill(right, cy, a)
		local st = U.status
		local show = st == "available" or st == "downloading" or st == "done" or (st == "error" and U.remote ~= nil)
		local pa = approach("pill_a", show and 1 or 0, 14)
		if pa <= 0.01 then
			return right
		end
		if show then
			W.pill_st = st
		end
		st = W.pill_st or st
		local label, icon, fg, bg
		if st == "downloading" then
			label, fg, bg = L("cd_pill_down"):format(U.remote or ""), Color(191, 227, 191, 255), Color(111, 214, 111, 26)
		elseif st == "done" then
			label, icon, fg, bg = L("cd_pill_done"), "\u{f00c}", Color(143, 227, 143, 255), nil
		elseif st == "error" then
			label, icon, fg, bg = L("cd_upd_failed"), "\u{f071}", P.WARN, Color(236, 178, 82, 30)
		else
			label, icon, fg, bg = L("cd_pill_get"):format(U.remote or ""), "\u{f063}", Color(168, 234, 168, 255), Color(111, 214, 111, 41)
		end
		local ph = px(24)
		local pad = px(10)
		local iw = icon and px(16) or 0
		local target = pad * 2 + iw + tw(W.fonts.semi, px(11), label)
		local pw = math.floor(tween("pill_w", target, K.MOVE) + 0.5)
		local x0 = right - pw
		local clickable = st == "available" or st == "error"
		local hv = approach("pill_h", (clickable and hovered(x0, cy - ph / 2, right, cy + ph / 2)) and 1 or 0, 20)
		local ea = a * pa
		if bg then
			local hb = Color(bg.r, bg.g, bg.b, math.min(255, bg.a + math.floor(28 * hv)))
			rect(x0, cy - ph / 2, right, cy + ph / 2, fade(hb, ea), px(7))
		end
		Render.PushClip(Vec2(x0, cy - ph / 2), Vec2(right, cy + ph / 2), true)
		local tx = x0 + pad
		if icon then
			glyph(icon, tx + px(5), cy, px(10), fade(fg, ea))
			tx = tx + iw
		end
		text(W.fonts.semi, px(11), label, tx, cy, fade(fg, ea))
		Render.PopClip()
		if st == "downloading" then
			local bx0, bx1 = x0 + px(7), right - px(7)
			local by = cy + ph / 2 - px(4)
			local seg = (bx1 - bx0) * 0.4
			local phase = (os.clock() % 1.1) / 1.1
			local sx = bx0 + (bx1 - bx0 + seg) * phase - seg
			Render.PushClip(Vec2(bx0, by - px(1)), Vec2(bx1, by + px(3)), true)
			rect(sx, by, sx + seg, by + px(2), fade(P.GOOD, ea), px(1))
			Render.PopClip()
		end
		if clickable and show then
			hit(x0, cy - ph / 2, right, cy + ph / 2, "upd_install")
			if st == "error" and U.error then
				tip("pill", x0, cy - ph / 2, right, cy + ph / 2, L("cd_tip_err_t"), U.error:sub(1, 80))
			end
		end
		return x0 - px(8) * pa
	end

	local function draw_header(x, y, w, a)
		local cy = y + px(K.HEAD_H) / 2
		local left = x + px(K.PAD)
		hit(x, y, x + w, y + px(K.HEAD_H), "head")
		left = left + text(W.fonts.bold, px(13), L("cd_title"), left, cy, fade(P.TEXT, a)) + px(10)
		local mw, mh = segment("mode", left, cy, { L("cd_mode_order"), L("cd_mode_free") }, draft.mode, "mode", a)
		tip("mode", left, cy - mh / 2, left + mw, cy + mh / 2, L("cd_tip_mode_t"), L("cd_tip_mode"))
		left = left + mw + px(10)
		local left_end = left
		local stage = load_stage()
		local busy = stage and D.sets[0].stats and draft.result
		local ba = approach("head_load", busy and 1 or 0, 10)
		if ba > 0 then
			vline(left, cy, px(7), a * ba)
			left = left + px(10)
			if stage == "error" then
				glyph("\u{f071}", left + px(6), cy, px(10), fade(P.WARN, a * ba))
			else
				spinner(left + px(6), cy, px(5), a * ba, P.MUTED, math.max(1, px(1.5)))
			end
			local str = L(STAGE_TEXT[stage] or "cd_ld_wait")
			local sx = left + px(18) + text(W.fonts.regular, px(11), str, left + px(18), cy, fade(P.MUTED, a * ba))
			if (stage == "error" or stage == "slow") and D.error then
				tip("err", left, cy - px(10), sx, cy + px(10), L("cd_tip_err_t"), D.error:sub(1, 80))
			end
			left_end = math.max(left_end, sx)
		end

		local right = x + w - px(K.PAD)
		local ib = px(26)
		for _, item in ipairs({ { "\u{f00d}", "close" }, { "\u{f013}", "settings" }, { "\u{f1f8}", "reset" }, { "\u{f2ea}", "undo" } }) do
			local x0 = right - ib
			local active = item[2] == "settings" and W.settings
			local hv = approach("btn_" .. item[2], (active or hovered(x0, cy - ib / 2, right, cy + ib / 2)) and 1 or 0, 20)
			if hv > 0 then
				rect(x0, cy - ib / 2, right, cy + ib / 2, fade(P.HOVER, a * hv), px(7))
			end
			glyph(item[1], x0 + ib / 2, cy, px(12), fade(mix(P.MUTED, P.TEXT, hv), a))
			hit(x0, cy - ib / 2, right, cy + ib / 2, item[2])
			tip(item[2], x0, cy - ib / 2, right, cy + ib / 2, L("cd_tip_" .. item[2] .. "_t"), L("cd_tip_" .. item[2]))
			right = x0 - px(4)
		end
		right = right - px(6)
		right = draw_update_pill(right, cy, a)
		local lx = right
		if draft.mode == 0 then
			local labels = { L("cd_us"), L("cd_enemy") }
			local sx = right - segment_width(labels)
			local _, sh = segment("first", sx, cy, labels, draft.first, "first", a)
			local label = L("cd_first")
			lx = sx - px(8) - tw(W.fonts.regular, px(11), label)
			text(W.fonts.regular, px(11), label, lx, cy, fade(P.MUTED, a))
			tip("first", lx, cy - sh / 2, right, cy + sh / 2, L("cd_tip_first_t"), L("cd_tip_first"))
			lx = lx - px(10)
			vline(lx, cy, px(7), a)
		end

		local ca = approach("chance_a", draft.chance and 1 or 0, 10)
		if ca > 0 then
			local value = tween("chance", draft.chance or A.chance_last or 0.5, 0.45)
			if draft.chance then
				A.chance_last = draft.chance
			end
			local num = ("%d%%"):format(math.floor(value * 100 + 0.5))
			local nw = tw(W.fonts.bold, px(12), num)
			local col = mix(P.BAD, P.GOOD, approach("chance_c", value >= 0.5 and 1 or 0, 8))
			lx = lx - px(10) - nw
			text(W.fonts.bold, px(12), num, lx, cy, fade(col, a * ca))
			local cl = L("cd_chance")
			local clw = tw(W.fonts.regular, px(11), cl)
			if lx - px(6) - clw > left_end + px(12) then
				text(W.fonts.regular, px(11), cl, lx - px(6) - clw, cy, fade(P.MUTED, a * ca))
			else
				tip("chance", lx - px(2), cy - px(10), lx + nw + px(2), cy + px(10), L("cd_chance"), "")
			end
		end
	end

	local function draw_free(x, y, w, a)
		local ty = y + px(K.TL_HEAD) / 2
		local left, right = x + px(K.PAD), x + w - px(K.PAD)
		text(W.fonts.bold, px(12), L("cd_us"), left, ty, fade(P.GOOD, a))
		local en = L("cd_enemy")
		text(W.fonts.bold, px(12), en, right - tw(W.fonts.bold, px(12), en), ty, fade(P.BAD, a))
		W.cur_target = nil
		local pw = math.floor((right - left - px(12)) / 2)
		local ph = math.floor(pw * 0.5625)
		local top = y + px(K.TL_HEAD) + px(2)
		for i = 1, 10 do
			local col, row = i <= 5 and 0 or 1, (i - 1) % 5
			local sx = col == 0 and left or right - pw
			local sy = top + row * (ph + px(6))
			if draft.tentative[i] then
				tip("slot" .. i, sx, sy, sx + pw, sy + ph, L("cd_tip_tent_t"), L("cd_tip_tent"))
			else
				tip("slot" .. i, sx, sy, sx + pw, sy + ph, L("cd_tip_slot_t"), L("cd_tip_free"))
			end
			draw_slot(i, sx, sy, pw, ph, a)
		end
		local by = top + 5 * (ph + px(6)) + px(10)
		text(W.fonts.bold, px(12), L("cd_bans"), left, by + px(6), fade(P.MUTED, a))
		by = by + px(18)
		local gap = px(4)
		local bw = math.floor((right - left - gap * 4) / 5)
		local bh = math.floor(bw * 0.62)
		for i = 11, 20 do
			local n = i - 11
			local sx = left + (n % 5) * (bw + gap)
			local sy = by + (n // 5) * (bh + gap)
			draw_slot(i, sx, sy, bw, bh, a)
		end
		draw_cursor(a)
	end

	local function mini_switch(key, x, cy, a)
		local tw_, th_ = px(24), px(14)
		local k = approach("sw_" .. key, cfg[key] == 1 and 1 or 0, 18)
		local bg = mix(Color(255, 255, 255, 41), Color(111, 214, 111, 153), k)
		rect(x - tw_, cy - th_ / 2, x, cy + th_ / 2, fade(bg, a), th_ / 2)
		local kx = x - tw_ + th_ / 2 + (tw_ - th_) * k
		Render.FilledCircle(Vec2(kx, cy), th_ / 2 - px(2), fade(mix(Color(174, 178, 184, 255), P.WHITE, k), a))
	end

	local function draw_settings_page(x, y, w, h, a)
		local left, right = x + px(14), x + w - px(14)
		local ty = y + px(20)
		local bx = left
		local ib = px(24)
		local hv = approach("st_back", hovered(bx, ty - ib / 2, bx + ib, ty + ib / 2) and 1 or 0, 20)
		if hv > 0 then
			rect(bx, ty - ib / 2, bx + ib, ty + ib / 2, fade(P.HOVER, a * hv), px(7))
		end
		glyph("\u{f060}", bx + ib / 2, ty, px(12), fade(mix(P.MUTED, P.TEXT, hv), a))
		hit(bx, ty - ib / 2, bx + ib, ty + ib / 2, "set_back")
		text(W.fonts.bold, px(13), L("cd_set_title"), bx + ib + px(8), ty, fade(P.TEXT, a))

		local row_h = px(K.SET_ROW)
		local top = y + px(36)
		local scroll = SB.scroll("set", "set_scroll", W.set_max or 0)
		W.set_rect = { x, top, x + w, y + h }
		W.hit_clip = { top, y + h }
		Render.PushClip(Vec2(x, top), Vec2(x + w, y + h), true)
		local cx0, cy0 = Input.GetCursorPos()
		local covered = W.gear_pop and in_rect(W.gear_pop, cx0, cy0)
		W.gear_block = W.gear_pop
		local C = { l = left, r = right, x0 = x + px(4), x1 = x + w - px(4), y = top + px(2) - scroll, a = a }

		local function section(c, key)
			c.y = c.y + px(6)
			text(W.fonts.semi, px(10), L(key), c.l, c.y + px(6), fade(P.DIM, c.a))
			c.y = c.y + px(14)
		end
		local function row(c, icon, label, id)
			local cy = c.y + row_h / 2
			local inside = cx0 >= c.x0 and cx0 <= c.x1 and cy0 >= c.y and cy0 < c.y + row_h
			local rh = approach("st_row" .. id, (inside and not W.drag and (c.popup or not covered)) and 1 or 0, 20)
			if rh > 0 then
				rect(c.x0, c.y, c.x1, c.y + row_h, fade(Color(255, 255, 255, c.popup and 12 or 8), c.a * rh), px(7))
			end
			local tx = c.l
			if icon then
				glyph(icon, c.l + px(7), cy, px(11), fade(P.MUTED, c.a))
				tx = c.l + px(22)
			end
			local lw = label and text(W.fonts.regular, px(12), label, tx, cy, fade(P.TEXT, c.a)) or 0
			c.y = c.y + row_h
			return cy, tx, tx + lw
		end
		local function seg(c, id, labels, value, kind, cy)
			segment(id, c.r - segment_width(labels), cy, labels, value, kind, c.a)
		end
		local function toggle(c, icon, key, label, id)
			local cy = row(c, icon, label, id)
			mini_switch(key, c.r, cy, c.a)
			hit(c.x0, cy - row_h / 2, c.x1, cy + row_h / 2, "set_toggle", key)
			return cy
		end
		local function stepper(c, cy, value, up, down, id)
			local sb = px(20)
			local vw = px(42)
			for n, item in ipairs({ { "+", up, c.r - sb }, { "-", down, c.r - sb * 2 - vw } }) do
				local sx = item[3]
				local h2 = approach(id .. n, hovered(sx, cy - sb / 2, sx + sb, cy + sb / 2) and 1 or 0, 20)
				rect(sx, cy - sb / 2, sx + sb, cy + sb / 2, fade(mix(P.CELL, P.HOVER, h2), c.a), px(6))
				local gw = tw(W.fonts.medium, px(12), item[1])
				text(W.fonts.medium, px(12), item[1], sx + (sb - gw) / 2, cy, fade(P.TEXT, c.a))
				hit(sx, cy - sb / 2, sx + sb, cy + sb / 2, item[2])
			end
			local label = ("%d%%"):format(value)
			local tvw = tw(W.fonts.medium, px(11), label)
			text(W.fonts.medium, px(11), label, c.r - sb - vw / 2 - tvw / 2, cy, fade(P.TEXT, c.a))
		end
		local function button(c, cy, id, label, kind, whole_row, icon, on)
			local bw = tw(W.fonts.medium, px(11), label) + px(24) + (icon and px(8) or 0)
			local bh = px(22)
			local x0 = c.r - bw
			local hx0, hy0, hx1, hy1 = x0, cy - bh / 2, c.r, cy + bh / 2
			if whole_row then
				hx0, hy0, hx1, hy1 = c.x0, cy - row_h / 2, c.x1, cy + row_h / 2
			end
			local hv = approach(id, ((c.popup or not covered) and hovered(hx0, hy0, hx1, hy1)) and 1 or 0, 20)
			rect(x0, cy - bh / 2, c.r, cy + bh / 2, fade(on and P.CHIP_ON or mix(P.CELL, P.HOVER, hv), c.a), px(6))
			local tx = x0 + px(12)
			if icon then
				glyph(icon, x0 + px(13), cy, px(10), fade(P.MUTED, c.a))
				tx = x0 + px(23)
			end
			text(W.fonts.medium, px(11), label, tx, cy, fade(P.TEXT, c.a))
			hit(hx0, hy0, hx1, hy1, kind)
			return x0, bh
		end
		local function gear(c, key, cy)
			local size = px(20)
			local on = W.set_gear == key
			local gh = approach("st_g" .. key, (on or (not covered and hovered(c.r - size, cy - size / 2, c.r, cy + size / 2))) and 1 or 0, 20)
			if gh > 0 then
				rect(c.r - size, cy - size / 2, c.r, cy + size / 2, fade(on and P.CHIP_ON or P.HOVER, c.a * gh), px(6))
			end
			glyph("\u{f013}", c.r - size / 2, cy, px(10), fade(mix(P.MUTED, P.TEXT, gh), c.a))
			hit(c.r - size, cy - size / 2, c.r, cy + size / 2, "set_gear", key)
			W.gear_anchor[key] = { cy - size / 2, cy + size / 2 }
			return size
		end

		section(C, "cd_sec_data")
		local cy = row(C, "\u{f1c0}", L("cd_set_source"), "src")
		seg(C, "st_src", { L("cd_src_short0"), L("cd_src_long1") }, source(), "set_src", cy)
		local note_h = math.floor(tween("st_cm_note", source() == 1 and px(K.CM_NOTE_H) or 0, K.PAGE_TIME) + 0.5)
		if note_h > 0.5 then
			local na = a * clamp(note_h / px(K.CM_NOTE_H), 0, 1)
			Render.PushClip(Vec2(x, C.y), Vec2(x + w, C.y + note_h), true)
			local CM = D.sets[1]
			local n = CM.stats and CM.stats.n or 0
			local days = CM.oldest and math.max(1, math.floor((os.time() - CM.oldest) / 86400 + 0.5)) or nil
			local rate = (days and n > 0) and n / days or nil
			local l1 = C.y + px(12)
			local l2 = C.y + px(29)
			glyph("\u{f05a}", left + px(7), l1, px(10), fade(P.MUTED, na))
			local tx = left + px(22)
			if n == 0 or not days then
				text(W.fonts.regular, px(11), L("cd_cm_wait"), tx, l1, fade(P.MUTED, na))
			else
				text(W.fonts.regular, px(11), L("cd_cm_done"):format(fmt_games(n), math.min(days, K.CM_DAYS)), tx, l1, fade(P.MUTED, na))
			end
			local why = rate and L("cd_cm_why"):format(math.floor(rate + 0.5)) or L("cd_cm_why0")
			text(W.fonts.regular, px(10), why, tx, l2, fade(P.DIM, na))
			Render.PopClip()
			C.y = C.y + note_h
		end
		cy = row(C, "\u{f091}", L("cd_set_rank"), "rank")
		seg(C, "st_rank", { L("cd_rk0"), L("cd_rk1"), L("cd_rk2"), L("cd_rk3") }, cfg.rank, "set_rank", cy)
		local vy = C.y
		local vcy, _, label_end = row(C, "\u{f5fd}", L("cd_set_volume"), "vol")
		seg(C, "st_vol", { "50k", "100k", "200k" }, cfg.volume, "set_vol", vcy)
		tip("st_vol_tip", left, vy, label_end, vy + row_h, L("cd_set_volume"), L("cd_set_volume_tip"))

		local iy = C.y
		local ih = row_h + px(12)
		C.y = iy + ih
		cy = iy + ih / 2
		local l1, l2 = iy + px(13), iy + px(29)
		local tx = left + px(22)
		glyph("\u{f1da}", left + px(7), l1, px(11), fade(P.MUTED, a))
		local S = D.sets[source()]
		local parts = {}
		if S.stats then
			parts[#parts + 1] = L("cd_matches"):format(fmt_games(S.stats.n))
		end
		local note = D.gh.note and os.clock() - D.gh.note_at < 5 and L(D.gh.note)
		parts[#parts + 1] = note or (D.status == "cd_st_gh" and L("cd_upd_loading") or fmt_updated(S.updated))
		local lx = tx
		for n, part in ipairs(parts) do
			if n > 1 then
				vline(lx, l1, px(6), a)
				lx = lx + px(8)
			end
			lx = lx + text(W.fonts.regular, px(11), part, lx, l1, fade(P.MUTED, a)) + px(8)
		end
		local msk = (K.DATA_AT + K.MSK_SHIFT) % 86400
		local utc = K.DATA_AT % 86400
		text(W.fonts.regular, px(10), L("cd_gh_sched"):format(msk // 3600, msk % 3600 // 60, utc // 3600, utc % 3600 // 60), tx, l2, fade(P.DIM, a))
		local rbx, rbh = button(C, cy, "st_refresh", L("cd_set_refresh"), "set_refresh", false, "\u{f021}")
		tip("st_refresh_tip", rbx, cy - rbh / 2, right, cy + rbh / 2, L("cd_set_refresh"), L("cd_tip_gh_refresh"))

		section(C, "cd_sec_panel")
		local pm_y = C.y
		local pcy, _, pm_end = row(C, "\u{f06e}", L("cd_set_pmode"), "pmode")
		local pm_labels = { L("cd_pm0"), L("cd_pm1"), L("cd_pm2") }
		local pm_r = C.r
		if cfg.panel == 1 then
			pm_r = C.r - gear(C, "panel", pcy) - px(8)
		end
		segment("st_pmode", pm_r - segment_width(pm_labels), pcy, pm_labels, cfg.panel ~= 1 and 2 or cfg.pshop, "set_pmode", a)
		tip("st_pmode_tip", left, pm_y, pm_end, pm_y + row_h, L("cd_set_pmode_t"), L("cd_pm_note"))

		section(C, "cd_sec_window")
		cy = row(C, "\u{f2d0}", L("cd_set_window"), "win")
		gear(C, "window", cy)
		hit(C.x0, cy - row_h / 2, C.r - px(24), cy + row_h / 2, "set_gear", "window")
		toggle(C, "\u{f52b}", "auto", L("cd_set_auto"), "auto")
		toggle(C, "\u{f058}", "pick_ask", L("cd_set_pick_ask"), "pick_ask")
		local lane_y = C.y
		toggle(C, "\u{f0e8}", "lanes", L("cd_set_lanes"), "lanes")
		tip("st_lanes", left, lane_y, right, lane_y + row_h, L("cd_set_lanes"), L("cd_tip_lanes"))
		toggle(C, "\u{f188}", "debug", L("cd_set_debug"), "debug")
		cy = row(C, "\u{f005}", L("cd_set_news"):format(K.VERSION), "news")
		button(C, cy, "st_news", L("cd_news_open"), "set_news", true)

		Render.PopClip()
		W.hit_clip = nil
		W.set_max = math.max(0, C.y + scroll - top + px(8) - (y + h - top))
		SB.bar("set", x + w - px(1), top, y + h, scroll, W.set_max, a)

		local g = W.set_gear
		local ga = approach("st_gear_a", g and 1 or 0, 22) * a
		if g then
			W.gear_last = g
		end
		g = g or W.gear_last
		W.gear_pop = nil
		local anchor = g and W.gear_anchor[g]
		if ga <= 0.01 or not anchor then
			return
		end
		local sw = px(24)
		local fit = g == "window" and {
			{ "cd_set_scale", px(82) }, { "cd_set_bg", px(100) + px(K.SLIDER_GAP) + tw(W.fonts.medium, px(11), "100%") },
			{ "cd_set_blur", sw }, { "cd_set_tips", sw },
		} or {
			{ "cd_set_pview", segment_width({ L("cd_pview0"), L("cd_pview1") }) }, { "cd_set_scale", px(82) },
			{ "cd_set_padapt", sw }, { "cd_set_preview", tw(W.fonts.medium, px(11), L("cd_preview_hide")) + px(24) },
		}
		local pw = px(280)
		for _, f in ipairs(fit) do
			pw = math.max(pw, px(34) + tw(W.fonts.regular, px(12), L(f[1])) + px(16) + f[2] + px(12))
		end
		pw = math.min(pw, w - px(16))
		local ph = px(40) + 4 * row_h + px(6)
		local px1 = x + w - px(8)
		local px0 = px1 - pw
		local py = math.floor(anchor[2] + px(4))
		if py + ph > y + h - px(4) then
			py = math.floor(anchor[1] - px(4) - ph)
		end
		local nohit = W.nohit
		W.nohit = nohit or not W.set_gear
		W.gear_block = nil
		rect(x + px(4), top, x + w - px(4), y + h - px(4), fade(Color(0, 0, 0, 110), ga), px(8))
		rect(px0, py, px1, py + ph, fade(Color(31, 34, 39, 255), ga), px(10))
		hit(px0, py, px1, py + ph, "stgbg")
		if W.set_gear then
			W.gear_pop = { px0, py, px1, py + ph }
		end
		glyph(g == "window" and "\u{f2d0}" or "\u{f290}", px0 + px(19), py + px(17), px(11), fade(P.MUTED, ga))
		text(W.fonts.semi, px(11), L(g == "window" and "cd_set_window" or "cd_set_pmode_t"), px0 + px(34), py + px(17), fade(P.MUTED, ga))
		rect(px0 + px(12), py + px(31), px1 - px(12), py + px(31) + math.max(1, px(1)), fade(Color(255, 255, 255, 22), ga))
		local Q = { l = px0 + px(12), r = px1 - px(12), x0 = px0 + px(4), x1 = px1 - px(4), y = py + px(36), a = ga, popup = true }
		if g == "window" then
			cy = row(Q, "\u{f065}", L("cd_set_scale"), "g_scale")
			stepper(Q, cy, cfg.zoom, "set_scale_up", "set_scale_down", "st_b")
			cy = row(Q, "\u{f043}", L("cd_set_bg"), "g_bg")
			local val_txt = ("%d%%"):format(cfg.bg)
			local val_w = tw(W.fonts.medium, px(11), "100%")
			local tx1 = Q.r - val_w - px(K.SLIDER_GAP)
			local tx0 = tx1 - px(100)
			local k = (cfg.bg - 50) / 50
			rect(tx0, cy - px(2), tx1, cy + px(2), fade(Color(255, 255, 255, 30), ga), px(2))
			rect(tx0, cy - px(2), tx0 + (tx1 - tx0) * k, cy + px(2), fade(Color(255, 255, 255, 140), ga), px(2))
			Render.FilledCircle(Vec2(tx0 + (tx1 - tx0) * k, cy), px(6), fade(P.WHITE, ga))
			text(W.fonts.medium, px(11), val_txt, Q.r - tw(W.fonts.medium, px(11), val_txt), cy, fade(P.TEXT, ga))
			if W.set_gear then
				W.slider_rect = { tx0, tx1 }
			end
			hit(tx0 - px(8), cy - px(10), tx1 + px(4), cy + px(10), "set_bg")
			toggle(Q, "\u{f042}", "blur", L("cd_set_blur"), "g_blur")
			toggle(Q, "\u{f05a}", "tips", L("cd_set_tips"), "g_tips")
		else
			cy = row(Q, "\u{f009}", L("cd_set_pview"), "g_pview")
			seg(Q, "st_pview", { L("cd_pview0"), L("cd_pview1") }, cfg.pview, "set_pview", cy)
			cy = row(Q, "\u{f065}", L("cd_set_scale"), "g_pzoom")
			stepper(Q, cy, cfg.pzoom, "set_pzoom_up", "set_pzoom_down", "st_pz")
			toggle(Q, "\u{f3ed}", "padapt", L("cd_set_padapt"), "g_padapt")
			cy = row(Q, "\u{f04b}", L("cd_set_preview"), "g_preview")
			local plabel = W.preview and L("cd_preview_hide") or L("cd_preview_show")
			local pbx, pbh = button(Q, cy, "st_prev", plabel, "set_preview", true, nil, W.preview)
			tip("st_prev", pbx, cy - pbh / 2, Q.r, cy + pbh / 2, L("cd_set_preview"), L("cd_tip_preview"))
		end
		W.nohit = nohit
	end

	local function draw_timeline(x, y, w, a)
		if draft.mode == 1 then
			draw_free(x, y, w, a)
			return
		end
		local mid = x + w / 2
		local ty = y + px(K.TL_HEAD) / 2
		text(W.fonts.bold, px(12), L("cd_us"), x + px(K.PAD), ty, fade(P.GOOD, a))
		local en = L("cd_enemy")
		text(W.fonts.bold, px(12), en, x + w - px(K.PAD) - tw(W.fonts.bold, px(12), en), ty, fade(P.BAD, a))
		local top = y + px(K.TL_HEAD)
		local gap = px(K.TL_GAP)
		local bottom = { -math.huge, -math.huge }
		local prev = -math.huge
		local c = cur_step()
		W.cur_target = nil
		local line = fade(P.LINE, a * 1.4)
		for i, step in ipairs(K.STEPS) do
			local side = step_team(i)
			local is_pick = step.kind == "P"
			local bh = is_pick and px(K.PICK_H) or px(K.BAN_H)
			local bw = is_pick and px(K.PICK_W) or px(K.BAN_W)
			local cy
			if i == 1 then
				cy = top + bh / 2 + px(4)
			else
				cy = math.max(prev + K.TL_STEP * s, bottom[side + 1] + px(K.TL_SAME) + bh / 2)
			end
			prev = cy
			bottom[side + 1] = cy + bh / 2
			local bx = side == 0 and mid - gap - bw or mid + gap
			local lx0 = side == 0 and mid - gap or mid + px(9)
			rect(lx0, math.floor(cy), lx0 + gap - px(9), math.floor(cy) + math.max(1, px(1)), line)
			local num = tostring(i)
			local col = i == c and P.TEXT or (draft.steps[i] and P.MUTED or P.DIM)
			local font = i == c and W.fonts.bold or W.fonts.semi
			text(font, px(10), num, mid - tw(font, px(10), num) / 2, cy, fade(col, a))
			draw_slot(i, math.floor(bx), math.floor(cy - bh / 2), bw, bh, a)
		end
		draw_cursor(a)
	end

	local function draw_grid(x, y, w, h, a)
		local fx0, fy0 = x + px(10), y + px(10)
		local fx1, fy1 = x + w - px(10), fy0 + px(K.SEARCH_H)
		local fcy = (fy0 + fy1) / 2
		local focus = approach("focus", W.focus and 1 or 0, 16)
		local field_hover = approach("field_h", hovered(fx0, fy0, fx1, fy1) and 1 or 0, 20)
		rect(fx0, fy0, fx1, fy1, fade(P.FIELD, a * (1 + 0.6 * math.max(focus, field_hover * 0.5))), px(8))
		glyph("\u{f002}", fx0 + px(16), fcy, px(11), fade(mix(P.MUTED, P.TEXT, focus), a))
		hit(fx0, fy0, fx1, fy1, "search")
		local tx = fx0 + px(30)
		local ph = approach("placeholder", draft.query == "" and 1 or 0, 22)
		if ph > 0 then
			Render.PushClip(Vec2(tx, fy0), Vec2(fx1 - px(8), fy1), true)
			text(W.fonts.medium, px(11), L("cd_search"), tx, fcy, fade(P.DIM, a * ph))
			Render.PopClip()
		end
		local qw = 0
		if draft.query ~= "" then
			qw = text(W.fonts.medium, px(12), draft.query, tx, fcy, fade(P.TEXT, a))
		end
		if W.focus and os.clock() % 1 < 0.55 then
			local cx0 = tx + qw + (qw > 0 and px(2) or 0)
			rect(cx0, fcy - px(7), cx0 + math.max(1, px(1)), fcy + px(7), fade(P.TEXT, a * focus))
		end

		local gx0, gy0 = x + px(10), fy1 + px(8)
		local gx1, gy1 = x + w - px(10), y + h - px(8)
		W.grid_rect = { gx0, gy0, gx1, gy1 }
		if not D.heroes then
			spinner((gx0 + gx1) / 2, (gy0 + gy1) / 2, px(12), a, P.MUTED, math.max(1.5, px(2)))
			return
		end
		local col_w = (gx1 - gx0 - 3 * px(K.COL_GAP)) / 4
		local cell_gap = px(K.CELL_GAP)
		local cell_w = (col_w - cell_gap) / 2
		local cell_h = px(K.CELL_H)
		local head_h = px(18)
		local q = norm(draft.query)
		local used = used_set()
		local content = 0
		for _, group in pairs(D.by_attr) do
			content = math.max(content, head_h + math.ceil(#group / 2) * (cell_h + cell_gap))
		end
		local gmax = math.max(0, content - (gy1 - gy0))
		local scroll = SB.scroll("grid", "grid_scroll", gmax)
		Render.PushClip(Vec2(gx0, gy0), Vec2(gx1, gy1), true)
		local oy = gy0 - scroll
		local cx, cy = Input.GetCursorPos()
		local inside = in_rect(W.grid_rect, cx, cy) and not over_menu(cx, cy) and not W.drag
		for n, attr in ipairs({ "str", "agi", "int", "all" }) do
			local x0 = gx0 + (n - 1) * (col_w + px(K.COL_GAP))
			text(W.fonts.semi, px(10), L("cd_attr_" .. attr), x0, oy + head_h / 2 - px(2), fade(P.MUTED, a))
			for j, hero in ipairs(D.by_attr[attr]) do
				local col, row = (j - 1) % 2, (j - 1) // 2
				local hx = math.floor(x0 + col * (cell_w + cell_gap) + 0.5)
				local hy = math.floor(oy + head_h + row * (cell_h + cell_gap) + 0.5)
				local hw = math.floor(cell_w + 0.5)
				local id = hero.id
				local is_used = used[id] and true or false
				local miss = q ~= "" and match_score(hero, q) == 0
				local u = approach("gu" .. id, is_used and 1 or 0, 14)
				local mv = approach("gm" .. id, miss and 1 or 0, 18)
				local hov = inside and not is_used and cx >= hx and cx <= hx + hw and cy >= hy and cy <= hy + cell_h
				local hv = approach("gh" .. id, hov and 1 or 0, 22)
				if hy + cell_h >= gy0 and hy <= gy1 then
					local alpha = a * (1 - 0.85 * mv)
					local img = portrait(id)
					local grow = px(2) * hv
					local ix0, iy0 = hx - grow, hy - grow
					local iw, ih = hw + grow * 2, cell_h + grow * 2
					if img then
						Render.Image(img, Vec2(ix0, iy0), Vec2(iw, ih), fade(mix(P.WHITE, P.USED, u), alpha), px(4), K.ROUND,
							Vec2(0, 0), Vec2(1, 1), u)
					else
						rect(ix0, iy0, ix0 + iw, iy0 + ih, fade(P.FIELD, alpha), px(4))
					end
					if hv > 0 then
						rect(ix0, iy0, ix0 + iw, iy0 + ih, fade(P.HOVER, a * hv * 1.6), px(4))
					end
					if not is_used then
						local vy0, vy1 = math.max(hy, gy0), math.min(hy + cell_h, gy1)
						if vy1 > vy0 then
							hit(hx, vy0, hx + hw, vy1, "hero", id)
						end
					end
				end
			end
		end
		Render.PopClip()
		SB.bar("grid", x + w - px(1), gy0, gy1, scroll, gmax, a)
	end

	local function draw_reasons(row, x, cy, max_x, a)
		local size = px(11)
		local icon = px(18)
		local lx = x
		local function word(str, color)
			if lx < max_x then
				lx = lx + text(W.fonts.regular, size, str, lx, cy, color, true) + px(4)
			end
		end
		local function face(h, v)
			local img = mini(h)
			if img then
				Render.Image(img, Vec2(lx, math.floor(cy - icon / 2)), Vec2(icon, icon), fade(P.WHITE, a))
			end
			lx = lx + icon + px(2)
			local val = pct(v)
			local str = (val >= 0 and "+" or "") .. ("%.1f"):format(val)
			lx = lx + text(W.fonts.medium, size, str, lx, cy, fade(val >= 0 and P.GOOD or P.BAD, a), true) + px(6)
		end
		local good, bad = {}, nil
		for _, r in ipairs(row.reasons) do
			if pct(r.v) >= K.REASON_MIN and #good < K.REASONS then
				good[#good + 1] = r
			end
		end
		local last = row.reasons[#row.reasons]
		if last and pct(last.v) <= -K.REASON_MIN then
			bad = last
		end
		if #good == 0 and not bad then
			if #row.reasons == 0 then
				word(L("cd_rate"):format(M.base(row.h) * 100), fade(P.MUTED, a))
				if row.contest >= 0.05 then
					vline(lx, cy, px(5), a)
					lx = lx + px(7)
					word(L("cd_pro"):format(math.floor(row.contest * 100 + 0.5)), fade(P.MUTED, a))
				end
			end
			return
		end
		local groups = {
			{ label = L("cd_vs"), faces = {} },
			{ label = L("cd_with"), faces = {} },
			{ label = bad and (bad.t == "vs" and L("cd_weak") or L("cd_bad_with")), faces = { bad } },
		}
		for _, r in ipairs(good) do
			local g = groups[r.t == "vs" and 1 or 2]
			g.faces[#g.faces + 1] = r
		end
		local function face_w(r)
			local val = pct(r.v)
			return icon + px(2) + tw(W.fonts.medium, size, (val >= 0 and "+" or "") .. ("%.1f"):format(val)) + px(6)
		end
		local function total()
			local w, any = 0, false
			for _, g in ipairs(groups) do
				if #g.faces > 0 then
					if any then
						w = w + px(7)
					end
					any = true
					w = w + tw(W.fonts.regular, size, g.label) + px(4)
					for _, r in ipairs(g.faces) do
						w = w + face_w(r)
					end
				end
			end
			return w
		end
		local drop = { { 2, 2 }, { 1, 2 }, { 2, 1 } }
		for _, d in ipairs(drop) do
			if x + total() <= max_x then
				break
			end
			local list = groups[d[1]].faces
			if #list >= d[2] then
				table.remove(list, d[2])
			end
		end
		local drawn = false
		for _, g in ipairs(groups) do
			if #g.faces > 0 then
				if drawn then
					vline(lx, cy, px(5), a)
					lx = lx + px(7)
				end
				drawn = true
				word(g.label, fade(P.MUTED, a))
				for _, r in ipairs(g.faces) do
					face(r.h, r.v)
				end
			end
		end
	end

	local function draw_comp(row, x, cy, max_x, a)
		local lx = x + text(W.fonts.regular, px(10), L("cd_with_him"), x, cy, fade(P.DIM, a), true) + px(6)
		local icon = px(18)
		for _, c in ipairs(row.comp) do
			if lx + icon > max_x then
				break
			end
			lx = lx + draw_pos(c.pos, lx, cy, px(11), a) + px(2)
			local img = mini(c.h)
			if img then
				Render.Image(img, Vec2(lx, math.floor(cy - icon / 2)), Vec2(icon, icon), fade(P.WHITE, a))
			end
			lx = lx + icon + px(7)
		end
	end

	local function draw_pos_buttons(res, x, cy, a)
		local size = px(K.BTN)
		local bx = x
		local items = { { p = 0 } }
		for p = 1, 5 do
			items[#items + 1] = { p = p, busy = res.kind == "P" and res.taken[p] and draft.filter ~= p }
		end
		for _, it in ipairs(items) do
			local on = draft.filter == it.p
			local label = it.p == 0 and L("cd_auto_pos") or L("cd_pos" .. it.p)
			local open = tween("pb_o" .. it.p, on and 1 or 0, K.MOVE)
			local lw = (tw(W.fonts.medium, px(11), label) + px(6)) * open
			local bw = size + lw
			local hv = approach("pb_h" .. it.p, hovered(bx, cy - size / 2, bx + bw, cy + size / 2) and 1 or 0, 20)
			local bg = on and P.CHIP_ON or mix(P.CELL, P.HOVER, hv)
			local ba = a * (it.busy and 0.55 or 1)
			rect(bx, cy - size / 2, bx + bw, cy + size / 2, fade(bg, ba), px(7))
			local ix = bx + (size - px(15)) / 2
			if it.p == 0 then
				glyph("\u{f0d0}", bx + size / 2, cy, px(12), fade(mix(P.MUTED, P.TEXT, open), ba))
			else
				draw_pos(it.p, ix, cy, px(15), ba)
			end
			if open > 0.02 then
				Render.PushClip(Vec2(bx + size - px(4), cy - size / 2), Vec2(bx + bw, cy + size / 2), true)
				text(W.fonts.medium, px(11), label, bx + size - px(4), cy, fade(P.TEXT, ba * open), true)
				Render.PopClip()
			end
			hit(bx, cy - size / 2, bx + bw, cy + size / 2, "pos", it.p)
			local title, body
			if it.p == 0 then
				title, body = L("cd_tip_auto_t"), L("cd_tip_auto")
			else
				title = L("cd_posT" .. it.p)
				if it.busy then
					local owner = "?"
					for i, pos in pairs(draft.slot_pos) do
						if pos == it.p and draft.steps[i] and D.by_id[draft.steps[i]] then
							owner = D.by_id[draft.steps[i]].name
						end
					end
					body = L("cd_tip_taken"):format(owner)
				else
					body = L(res.kind == "B" and "cd_tip_ban" or "cd_tip_pick")
				end
			end
			tip("pos" .. it.p, bx, cy - size / 2, bx + bw, cy + size / 2, title, body, it.p > 0 and it.p or nil)
			bx = bx + bw + px(4)
		end
	end

	local function pos_picker(id, h, pos, x, cy, size, gap, a, have, loaded)
		local icon = math.floor(size * 0.64 + 0.5)
		for p = 1, 5 do
			local bx = x + (p - 1) * (size + gap)
			local on = pos == p
			local avail = not loaded or have[p] ~= nil
			local hv = approach(id .. p, hovered(bx, cy - size / 2, bx + size, cy + size / 2) and 1 or 0, 20)
			rect(bx, cy - size / 2, bx + size, cy + size / 2, fade(on and P.CHIP_ON or mix(P.CELL, P.HOVER, hv), a), px(6))
			draw_pos(p, bx + (size - icon) / 2, cy, icon, a * ((avail or on) and 1 or 0.35))
			hit(bx, cy - size / 2, bx + size, cy + size / 2, "bpos", { h = h, p = p })
			local body = have[p] and L("cd_tip_bpos"):format(have[p]) or (avail and "" or L("cd_tip_bpos_none"))
			tip(id .. "t" .. p, bx, cy - size / 2, bx + size, cy + size / 2, L("cd_posT" .. p), body, p)
		end
	end

	local SM = {}

	function SM.signed(v)
		if math.abs(v) < 0.05 then
			return "0.0"
		end
		return (v > 0 and "+" or "") .. ("%.1f"):format(v)
	end

	function SM.tone(v)
		return v >= K.SUM_MIN and P.GOOD or (v <= -K.SUM_MIN and P.BAD or P.MUTED)
	end

	function SM.item(name, x, y, w, h, q, a)
		local img = item_img(name)
		if img then
			Render.Image(img, Vec2(x, y), Vec2(w, h), fade(P.WHITE, a), px(5), K.ROUND)
		else
			rect(x, y, x + w, y + h, fade(P.FIELD, a), px(5))
		end
		if q and q > 1 then
			local label = tostring(q)
			local lw = tw(W.fonts.bold, px(9), label) + px(6)
			local bx1, by1 = x + w - px(2), y + h - px(2)
			rect(bx1 - lw, by1 - px(11), bx1, by1, fade(P.SHADE, a), px(3))
			text(W.fonts.bold, px(9), label, bx1 - lw + px(3), by1 - px(11) / 2, fade(P.TEXT, a))
		end
	end

	function SM.caption(label, sub, x, cy, a)
		local lx = x + text(W.fonts.semi, px(10), label, x, cy, fade(P.DIM, a))
		if sub then
			lx = lx + px(8)
			vline(lx, cy, px(6), a)
			text(W.fonts.regular, px(10), sub, lx + px(8), cy, fade(P.MUTED, a))
		end
	end

	function SM.posbar(h, auto_pos, right, cy, a)
		local size, gap = px(22), px(3)
		local x = right - 5 * size - 4 * gap
		pos_picker("sbp", h, I.bpos[h] or auto_pos, x, cy, size, gap, a, I.positions(h), I.buys[h] ~= nil)
		return x
	end

	function SM.qbuy(id, name, x0, y0, x1, y1, a, r)
		hit(x0, y0, x1, y1, "qbuy", { id = id, name = name })
		local hv = approach("qb_" .. id, hovered(x0, y0, x1, y1) and 1 or 0, 20)
		local fl = W.qflash and W.qflash.id == id and clamp(1 - (os.clock() - W.qflash.t) / K.QFLASH, 0, 1) or 0
		local k = 0.08 * hv + 0.3 * fl
		if k > 0.005 then
			rect(x0, y0, x1, y1, fade(Color(255, 255, 255, math.floor(255 * k)), a), r or px(4))
		end
	end

	function SM.build(sm, row, left, right, by, fade_in)
		local hero = row and D.by_id[row.h]
		local ba = fade_in(8)
		local pos = row and (I.bpos[row.h] or row.pos)
		local bar_x = row and SM.posbar(row.h, row.pos, right, by, ba) or right
		local title = L("cd_build_t"):format(hero and hero.name:upper() or "?")
		local sub = L("cd_build_sub")
		if left + tw(W.fonts.semi, px(10), title) + px(16) + tw(W.fonts.regular, px(10), sub) > bar_x - px(10) then
			sub = nil
		end
		SM.caption(title, sub, left, by, ba)
		by = by + px(20)
		local build = row and I.build(row.h, pos, sm.them)
		if build and build.none then
			by = by + px(8)
			text(W.fonts.medium, px(12), L("cd_build_nopos"):format(pos and L("cd_acc" .. pos) or "?"), left, by, fade(P.TEXT, ba))
			text(W.fonts.regular, px(10), L("cd_build_nopos2"), left, by + px(17), fade(P.DIM, ba))
			return by + px(36)
		end
		if not build or #build.slots == 0 then
			local msg, warn
			if build then
				msg = L("cd_build_none")
			elseif I.error and not I.busy then
				msg, warn = L("cd_ld_error"), true
			else
				msg = L("cd_build_loading")
			end
			by = by + px(8)
			local tx = left
			if warn then
				glyph("\u{f071}", left + px(6), by, px(10), fade(P.WARN, ba))
				tx = left + px(18)
			elseif not build then
				spinner(left + px(6), by, px(5), ba, P.MUTED, math.max(1, px(1.5)))
				tx = left + px(18)
			end
			local mw = text(W.fonts.regular, px(11), msg, tx, by, fade(P.MUTED, ba))
			if warn then
				tip("buys_err", left, by - px(10), tx + mw, by + px(10), L("cd_tip_err_t"), I.error:sub(1, 80))
			end
			return by + px(20)
		end
		local sa = fade_in(9)
		SM.caption(L("cd_build_start"), L("cd_build_gold"):format(build.gold, K.START_GOLD), left, by, sa)
		by = by + px(11)
		local iw, ih = px(40), px(29)
		local sx = left
		for n, st in ipairs(build.start) do
			SM.item(st.item.name, sx, by, iw, ih, st.q, sa)
			SM.qbuy("sti" .. n, st.item.name, sx, by, sx + iw, by + ih, sa)
			tip("sti" .. n, sx, by, sx + iw, by + ih, st.q > 1 and ("%s x%d"):format(st.item.label, st.q) or st.item.label, "")
			sx = sx + iw + px(5)
		end
		by = by + ih + px(16)
		SM.caption(L("cd_build_order"), nil, left, by, fade_in(10))
		by = by + px(11)
		local gap = px(6)
		local steps = build.steps
		local fit = math.max(K.SLOTS, math.floor((right - left + gap) / (px(K.SUM_STEP_W) + gap)))
		local rows = math.max(1, math.ceil(#steps / fit))
		local cols = math.max(K.SLOTS, math.ceil(#steps / rows))
		local sw = math.min(px(64), math.floor((right - left - gap * (cols - 1)) / cols))
		local sh = math.floor(sw * 0.72 + 0.5)
		local icon = px(16)
		local row_h = sh + px(6) + icon + px(12)
		for n, slot in ipairs(steps) do
			local x0 = left + ((n - 1) % cols) * (sw + gap)
			local y0 = by + ((n - 1) // cols) * row_h
			local ia = fade_in(10 + n * 0.5)
			SM.item(slot.item.name, x0, y0, sw, sh, nil, ia)
			SM.qbuy("sli" .. n, slot.item.name, x0, y0, x0 + sw, y0 + sh, ia)
			local src_item = slot.base or (slot.pre and slot.pre.item)
			if src_item then
				local ring = math.max(2, px(2))
				local bs = math.max(px(18), math.floor(sw * 0.52 + 0.5))
				local bh = math.floor(bs * 0.73 + 0.5)
				local bx, byy = x0 + sw - bs + px(6), y0 - px(6)
				rect(bx - ring, byy - ring, bx + bs + ring, byy + bh + ring, fade(P.BG, ia), px(5))
				local img = item_img(src_item.name)
				if img then
					Render.Image(img, Vec2(bx, byy), Vec2(bs, bh), fade(P.WHITE, ia), px(3), K.ROUND)
				end
			end
			local num = tostring(n)
			local nw = tw(W.fonts.bold, px(10), num) + px(8)
			rect(x0 + px(3), y0 + px(3), x0 + px(3) + nw, y0 + px(17), fade(P.SHADE, ia), px(4))
			text(W.fonts.bold, px(10), num, x0 + px(7), y0 + px(10), fade(P.TEXT, ia))
			if slot.vs and #slot.vs > 0 then
				local count = #slot.vs
				local vx = x0 + math.floor((sw - (count * icon + (count - 1) * px(2))) / 2)
				for _, e in ipairs(slot.vs) do
					local img = mini(e)
					if img then
						Render.Image(img, Vec2(vx, y0 + sh + px(6)), Vec2(icon, icon), fade(P.WHITE, ia))
					end
					vx = vx + icon + px(2)
				end
			end
			tip("sli" .. n, x0, y0, x0 + sw, y0 + sh + px(6) + icon, slot.item.label, slot.body)
		end
		by = by + rows * row_h
		local sp = build.spare
		if sp then
			local pa = fade_in(14)
			local siw, sih = px(36), px(26)
			SM.item(sp.item.name, left, by, siw, sih, sp.q, pa)
			SM.qbuy("spare", sp.item.name, left, by, left + siw, by + sih, pa)
			local scy = by + sih / 2
			local tx = left + siw + px(10)
			tx = tx + text(W.fonts.regular, px(11), L("cd_build_spare"), tx, scy, fade(P.MUTED, pa)) + px(5)
			for _, e in ipairs(sp.vs) do
				local img = mini(e)
				if img then
					Render.Image(img, Vec2(tx, math.floor(scy - px(9))), Vec2(px(18), px(18)), fade(P.WHITE, pa))
				end
				tx = tx + px(20)
			end
			vline(tx + px(4), scy, px(6), pa)
			text(W.fonts.regular, px(11), L("cd_th_invis"), tx + px(12), scy, fade(P.MUTED, pa))
			by = by + sih + px(8)
		end
		return by
	end

	function SM.draw(sm, x, y, w, h, a)
		local left, right = x + px(14), x + w - px(14)
		local ty = y + px(20)
		local ta = a * ease((os.clock() - W.step_t) / 0.25)
		local lx = left + text(W.fonts.bold, px(13), L("cd_sum_t"), left, ty, fade(P.TEXT, ta)) + px(8)
		if draft.chance then
			vline(lx, ty, px(7), ta)
			lx = lx + px(8)
			lx = lx + text(W.fonts.regular, px(11), L("cd_sum_chance"), lx, ty, fade(P.MUTED, ta)) + px(6)
			text(W.fonts.bold, px(12), ("%d%%"):format(math.floor(draft.chance * 100 + 0.5)), lx, ty,
				fade(draft.chance >= 0.5 and P.GOOD or P.BAD, ta))
		end

		local top, bottom = y + px(34), y + h - px(8)
		W.list_rect = { x + px(8), top, x + w - px(8), bottom }
		local scroll = SB.scroll("list", "list_scroll", W.sum_max or 0)
		Render.PushClip(Vec2(x, top), Vec2(x + w, bottom), true)
		W.hit_clip = { top, bottom }
		local now = os.clock()
		local function fade_in(k)
			return a * ease((now - W.list_t0 - k * K.STAGGER) / K.ROW_IN)
		end
		local cxm, cym = Input.GetCursorPos()
		local inside = in_rect(W.list_rect, cxm, cym) and not over_menu(cxm, cym) and not W.drag

		local cy = top + px(12) - scroll
		SM.caption(L("cd_sum_vs"), L("cd_sum_vs_sub"), left, cy, fade_in(0))
		local gap = px(3)
		local head_w, sum_w = px(50), px(44)
		local cell_w = math.floor((right - left - head_w - sum_w - gap * 6) / 5)
		local pw, ph = px(44), px(25)
		local col_x = {}
		for j = 1, 5 do
			col_x[j] = left + head_w + gap + (j - 1) * (cell_w + gap)
		end
		local sum_x = col_x[5] + cell_w + gap
		local hy = cy + px(11)
		local ha = fade_in(1)
		for j, e in ipairs(sm.them) do
			local img = portrait(e)
			if img then
				Render.Image(img, Vec2(col_x[j] + math.floor((cell_w - pw) / 2), hy), Vec2(pw, ph), fade(P.WHITE, ha), px(4), K.ROUND)
			end
		end
		local total = L("cd_sum_total")
		text(W.fonts.regular, px(10), total, sum_x + (sum_w - tw(W.fonts.regular, px(10), total)) / 2, hy + ph / 2,
			fade(P.MUTED, ha))

		local sel = I.hero(sm)
		local row_h = px(26)
		local ry = hy + ph + px(5)
		for k, row in ipairs(sm.rows) do
			local ra = fade_in(k + 1)
			local y0 = ry + (k - 1) * (row_h + gap)
			local y1 = y0 + row_h
			local rcy = y0 + row_h / 2
			local hov = inside and cym >= y0 - px(1) and cym < y1 + px(2)
			local hv = approach("sm_h" .. row.h, hov and 1 or 0, 20)
			local on = approach("sm_s" .. row.h, (sel and sel.h == row.h) and 1 or 0, 16)
			local bg = math.max(on, hv * 0.6)
			if bg > 0 then
				rect(left - px(6), y0 - px(2), right + px(6), y1 + px(2), fade(P.HOVER, ra * bg * 1.4), px(7))
			end
			local iy = y0 + math.floor((row_h - ph) / 2)
			local img = portrait(row.h)
			if img then
				Render.Image(img, Vec2(left, iy), Vec2(pw, ph), fade(P.WHITE, ra), px(4), K.ROUND)
			else
				rect(left, iy, left + pw, iy + ph, fade(P.FIELD, ra), px(4))
			end
			if row.pos then
				local size = px(11)
				rect(left + px(1), iy + ph - size - px(3), left + size + px(5), iy + ph - px(1), fade(P.SHADE, ra * 0.9), px(3))
				draw_pos(row.pos, left + px(3), iy + ph - px(2) - size / 2, size, ra)
			end
			local hero = D.by_id[row.h]
			local name = hero and hero.name or "?"
			for j, v in ipairs(row.v) do
				local c0 = col_x[j]
				local base = v >= 0 and P.GOOD or P.BAD
				local mag = math.min(1, math.abs(v) / 4)
				local cell = mag >= 0.0125 and Color(base.r, base.g, base.b, math.floor(56 * mag + 0.5)) or P.CELL
				rect(c0, y0, c0 + cell_w, y1, fade(cell, ra), px(5))
				local str = SM.signed(v)
				text(W.fonts.semi, px(12), str, c0 + (cell_w - tw(W.fonts.semi, px(12), str)) / 2, rcy, fade(SM.tone(v), ra))
				local enemy = D.by_id[sm.them[j]]
				tip("smc" .. row.h .. ":" .. j, c0, y0, c0 + cell_w, y1,
					L("cd_tip_cell_t"):format(name, enemy and enemy.name or "?"), L("cd_tip_cell"):format(str))
			end
			local str = SM.signed(row.sum)
			text(W.fonts.bold, px(12), str, sum_x + (sum_w - tw(W.fonts.bold, px(12), str)) / 2, rcy, fade(SM.tone(row.sum), ra))
			tip("sms" .. row.h, sum_x, y0, sum_x + sum_w, y1, L("cd_tip_sum_t"):format(name), L("cd_tip_sum"))
			hit(left - px(6), y0 - px(1), right + px(6), y1 + px(1), "sumrow", row.h)
		end
		local by = ry + #sm.rows * (row_h + gap) + px(8)
		text(W.fonts.regular, px(10), L("cd_sum_hint"), left, by, fade(P.DIM, fade_in(7)))
		by = SM.build(sm, sel, left, right, by + px(24), fade_in)
		Render.PopClip()
		W.hit_clip = nil
		W.sum_max = math.max(0, by + scroll - bottom)
		SB.bar("list", x + w - px(1), top, bottom, scroll, W.sum_max, a)
	end

	function SM.slot_menu(a)
		local menu = W.slot_menu
		if menu and not draft.steps[menu.slot] then
			W.slot_menu, menu = nil, nil
		end
		local ma = approach("sm_a", menu and 1 or 0, 22) * a
		if menu then
			W.sm_last = menu
		end
		menu = menu or W.sm_last
		if ma <= 0.01 or not menu then
			return
		end
		local items = { { "counter", "\u{f05b}", L("cd_sm_counter") }, { "clear", "\u{f1f8}", L("cd_sm_clear") } }
		local row_h, pad = px(28), px(4)
		local w = 0
		for _, it in ipairs(items) do
			w = math.max(w, tw(W.fonts.medium, px(12), it[3]))
		end
		w = w + px(40) + pad * 2
		local h = pad * 2 + #items * row_h
		local screen = Render.ScreenSize()
		local x = math.floor(clamp(menu.x + W.ox + px(2), 4, screen.x - w - 4))
		local y = math.floor(clamp(menu.y + W.oy + px(2), 4, screen.y - h - 4))
		outline(x, y, x + w, y + h, ma, px(8))
		if W.slot_menu then
			hit(x, y, x + w, y + h, "smbg")
			W.pm_rect = { x, y, x + w, y + h }
		end
		for k, it in ipairs(items) do
			local ry = y + pad + (k - 1) * row_h
			local hv = approach("sm_h" .. k, (W.slot_menu and hovered(x + pad, ry, x + w - pad, ry + row_h)) and 1 or 0, 20)
			if hv > 0 then
				rect(x + pad, ry, x + w - pad, ry + row_h, fade(P.HOVER, ma * hv * 1.5), px(6))
			end
			local cy = ry + row_h / 2
			glyph(it[2], x + pad + px(13), cy, px(11), fade(it[1] == "clear" and P.BAD or P.MUTED, ma))
			text(W.fonts.medium, px(12), it[3], x + pad + px(28), cy, fade(P.TEXT, ma))
			if W.slot_menu then
				hit(x + pad, ry, x + w - pad, ry + row_h, "smenu", it[1])
			end
		end
	end

	function SM.counter_view(x, y, w, h, a)
		local hero = D.by_id[W.counter]
		local left = x + px(14)
		local ty = y + px(20)
		local ib = px(24)
		local hv = approach("cnt_back", hovered(left, ty - ib / 2, left + ib, ty + ib / 2) and 1 or 0, 20)
		if hv > 0 then
			rect(left, ty - ib / 2, left + ib, ty + ib / 2, fade(P.HOVER, a * hv), px(7))
		end
		glyph("\u{f060}", left + ib / 2, ty, px(12), fade(mix(P.MUTED, P.TEXT, hv), a))
		hit(left, ty - ib / 2, left + ib, ty + ib / 2, "counter_back")
		local fx = left + ib + px(8)
		local face = mini(W.counter)
		if face then
			Render.Image(face, Vec2(fx, ty - px(10)), Vec2(px(20), px(20)), fade(P.WHITE, a))
			fx = fx + px(26)
		end
		text(W.fonts.bold, px(13), L("cd_cnt_t"):format(hero and hero.name or "?"), fx, ty, fade(P.TEXT, a), true)
		local used = used_set()
		local ids = {}
		for id in pairs(used) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		local key = ("%d:%s:%s:%s"):format(W.counter, tostring(D.sets[0].stats), tostring(D.sets[1].stats), table.concat(ids, ","))
		if not W.cnt_cache or W.cnt_cache.key ~= key then
			W.cnt_cache = { key = key, rows = M.counters(W.counter, used) }
		end
		local rows = W.cnt_cache.rows
		local lx0, ly0 = x + px(8), y + px(40)
		local lx1, ly1 = x + w - px(8), y + h - px(8)
		W.list_rect = { lx0, ly0, lx1, ly1 }
		local row_h = px(K.ROW)
		local n = math.min(#rows, K.CNT_MAX)
		local lmax = math.max(0, n * row_h - (ly1 - ly0))
		local scroll = SB.scroll("list", "list_scroll", lmax)
		Render.PushClip(Vec2(lx0, ly0), Vec2(lx1, ly1), true)
		local cxm, cym = Input.GetCursorPos()
		local inside = in_rect(W.list_rect, cxm, cym) and not over_menu(cxm, cym) and not W.drag
		local ry = ly0 - scroll
		for i = 1, n do
			local row = rows[i]
			if ry + row_h >= ly0 and ry <= ly1 then
				local hov = inside and cym >= ry and cym < ry + row_h
				local rh = approach("ch" .. row.h, hov and 1 or 0, 20)
				if rh > 0 then
					rect(lx0, ry, lx1, ry + row_h, fade(P.HOVER, a * rh), px(8))
				end
				local cy = ry + row_h / 2
				local ix, iw, ih = lx0 + px(8), px(46), px(26)
				local img = portrait(row.h)
				if img then
					Render.Image(img, Vec2(ix, math.floor(cy - ih / 2)), Vec2(iw, ih), fade(P.WHITE, a), px(5), K.ROUND)
				end
				local nx = ix + iw + px(9)
				local hr = D.by_id[row.h]
				text(W.fonts.bold, px(12), hr and hr.name or "?", nx, cy - px(8), fade(P.TEXT, a), true)
				text(W.fonts.regular, px(10), L("cd_cnt_wins"):format(("%.1f%%"):format(row.p * 100)), nx, cy + px(9), fade(P.MUTED, a), true)
				local rx = lx1 - px(8)
				local d = row.d * 100
				local num = (d >= 0 and "+" or "") .. ("%.1f"):format(d)
				local num_w = tw(W.fonts.bold, px(13), num)
				local col = d >= 0.05 and P.GOOD or (d <= -0.05 and P.BAD or P.MUTED)
				text(W.fonts.bold, px(13), num, rx - num_w, cy - px(7), fade(col, a), true)
				local games = L("cd_matches"):format(fmt_games(row.g))
				text(W.fonts.regular, px(10), games, rx - tw(W.fonts.regular, px(10), games), cy + px(9), fade(P.MUTED, a), true)
				local vy0, vy1 = math.max(ry, ly0), math.min(ry + row_h, ly1)
				if vy1 > vy0 then
					hit(lx0, vy0, lx1, vy1, "row", row.h)
				end
			end
			ry = ry + row_h
		end
		Render.PopClip()
		SB.bar("list", x + w - px(1), ly0, ly1, scroll, lmax, a)
	end

	function SM.pick(x, y, w, h, a)
		local p = W.pick
		local k = approach("pick_k", p and 1 or 0, 18)
		if p then
			W.pick_last = p
		end
		p = p or W.pick_last
		local pa = k * a
		if pa <= 0.01 or not p then
			return
		end
		rect(x, y, x + w, y + h, fade(Color(6, 7, 8, 150), pa), px(K.RADIUS))
		if W.pick then
			hit(x, y, x + w, y + h, "pickbg")
		end
		local cw, ch, pad = px(340), px(168), px(20)
		local cx0 = math.floor(x + (w - cw) / 2)
		local cy0 = math.floor(y + (h - ch) / 2 + (1 - k) * px(K.NEWS_SLIDE))
		rect(cx0, cy0, cx0 + cw, cy0 + ch, fade(P.CARD, pa), px(12))
		if W.pick then
			hit(cx0, cy0, cx0 + cw, cy0 + ch, "pickcard")
		end
		local iw, ih = px(88), px(50)
		local img = portrait(p.h)
		if img then
			Render.Image(img, Vec2(cx0 + pad, cy0 + pad), Vec2(iw, ih), fade(P.WHITE, pa), px(6), K.ROUND)
		end
		local hero = D.by_id[p.h]
		local tx = cx0 + pad + iw + px(14)
		text(W.fonts.medium, px(12), L("cd_pk_t"), tx, cy0 + pad + px(13), fade(P.MUTED, pa))
		text(W.fonts.bold, px(16), hero and hero.name or "?", tx, cy0 + pad + px(35), fade(P.TEXT, pa))
		local cxm, cym = Input.GetCursorPos()
		local function over(x0, y0, x1, y1)
			return W.pick and cxm >= x0 and cxm <= x1 and cym >= y0 and cym <= y1
		end
		local by = cy0 + px(92)
		local box = px(14)
		local lw = tw(W.fonts.regular, px(12), L("cd_pk_dont"))
		local dx1 = cx0 + pad + box + px(8) + lw
		local dhv = approach("pick_dh", over(cx0 + pad - px(4), by - px(10), dx1 + px(4), by + px(10)) and 1 or 0, 20)
		rect(cx0 + pad, by - box / 2, cx0 + pad + box, by + box / 2,
			fade(p.dont and P.CHIP_ON or mix(P.CELL, P.HOVER, dhv), pa), px(4))
		if p.dont then
			glyph("\u{f00c}", cx0 + pad + box / 2, by, px(9), fade(P.TEXT, pa))
		end
		text(W.fonts.regular, px(12), L("cd_pk_dont"), cx0 + pad + box + px(8), by, fade(mix(P.MUTED, P.TEXT, dhv), pa))
		if W.pick then
			hit(cx0 + pad - px(4), by - px(10), dx1 + px(4), by + px(10), "pick_dont")
		end
		if p.dont then
			text(W.fonts.regular, px(10), L("cd_pk_dont2"), cx0 + pad + box + px(8), by + px(16), fade(P.DIM, pa))
		end
		local bh = px(28)
		local by1 = cy0 + ch - px(16)
		local bx1 = cx0 + cw - pad
		for n, b in ipairs({ { "pick_ok", L("cd_pk_ok"), true }, { "pick_no", L("cd_pk_no"), false } }) do
			local bw = tw(W.fonts.semi, px(12), b[2]) + px(32)
			local bx0 = bx1 - bw
			local bhv = approach("pick_b" .. n, over(bx0, by1 - bh, bx1, by1) and 1 or 0, 20)
			local base = b[3] and P.CHIP_ON or P.CELL
			rect(bx0, by1 - bh, bx1, by1, fade(mix(base, Color(255, 255, 255, 60), bhv), pa), px(7))
			text(W.fonts.semi, px(12), b[2], bx0 + px(16), by1 - bh / 2, fade(P.TEXT, pa))
			if W.pick then
				hit(bx0, by1 - bh, bx1, by1, b[1])
			end
			bx1 = bx0 - px(8)
		end
	end

	function SM.toast(x, y, w, h, a)
		local t = W.toast
		if not t then
			return
		end
		local age = os.clock() - t.t
		if age > K.TOAST then
			W.toast = nil
			return
		end
		local ta = a * clamp(math.min(age / 0.15, (K.TOAST - age) / 0.3), 0, 1)
		local label = L(t.key)
		local bw, bh = tw(W.fonts.medium, px(12), label) + px(44), px(32)
		local bx0 = math.floor(x + (w - bw) / 2)
		local by0 = y + h - bh - px(18)
		outline(bx0, by0, bx0 + bw, by0 + bh, ta, px(8))
		glyph("\u{f05a}", bx0 + px(16), by0 + bh / 2, px(11), fade(P.WARN, ta))
		text(W.fonts.medium, px(12), label, bx0 + px(28), by0 + bh / 2, fade(P.TEXT, ta))
	end

	function SM.news(x, y, w, h, a)
		local k = W.news_k or 0
		if W.news then
			k = math.min(1, k + dt / K.NEWS_IN)
		else
			k = math.max(0, k - dt / K.NEWS_OUT)
		end
		W.news_k = k
		local na = k * k * (3 - 2 * k) * a
		if na <= 0.01 then
			return
		end
		local slide = math.floor((1 - ease(k)) * px(K.NEWS_SLIDE) + 0.5)
		rect(x, y, x + w, y + h, fade(Color(6, 7, 8, 150), na), px(K.RADIUS))
		if W.news then
			hit(x, y, x + w, y + h, "newsbg")
		end
		local cw = px(480)
		local pad = px(20)
		local tile = px(28)
		local function walk(cx0, y0, draw)
			local ny, kind = y0, nil
			for _, note in ipairs(K.NEWS) do
				local col = note[1] == "n" and P.GOOD or P.WARN
				if note[1] ~= kind then
					kind = note[1]
					ny = ny + px(10)
					if draw then
						local sw = text(W.fonts.semi, px(10), L(kind == "n" and "cd_news_new" or "cd_news_fix"), cx0 + pad, ny, fade(col, na))
						rect(cx0 + pad + sw + px(8), ny, cx0 + cw - pad, ny + math.max(1, px(1)), fade(P.LINE, na))
					end
					ny = ny + px(14)
				elseif draw then
					rect(cx0 + pad + tile + px(12), ny, cx0 + cw - pad, ny + math.max(1, px(1)), fade(P.LINE, na))
				end
				local lines = {}
				if note[4] then
					for line in (L(note[4]) .. "\n"):gmatch("(.-)\n") do
						lines[#lines + 1] = line
					end
				end
				local iy = ny + px(8)
				local ih = #lines > 0 and px(21) + #lines * px(15) or tile
				if draw then
					rect(cx0 + pad, iy, cx0 + pad + tile, iy + tile, fade(Color(col.r, col.g, col.b, 34), na), px(7))
					glyph(note[2], cx0 + pad + tile / 2, iy + tile / 2, px(12), fade(col, na))
					local tx = cx0 + pad + tile + px(12)
					text(W.fonts.semi, px(12), L(note[3]), tx, #lines > 0 and iy + px(7) or iy + tile / 2, fade(P.TEXT, na))
					for n, line in ipairs(lines) do
						text(W.fonts.regular, px(11), line, tx, iy + px(14) + n * px(15), fade(P.MUTED, na))
					end
				end
				ny = iy + math.max(ih, tile) + px(8)
			end
			return ny - y0
		end
		local ch = px(48) + walk(0, 0, false) + px(58)
		local cx0 = math.floor(x + (w - cw) / 2)
		local cy0 = math.floor(y + (h - ch) / 2 + px(10)) + slide
		rect(cx0, cy0, cx0 + cw, cy0 + ch, fade(P.CARD, na), px(12))
		local hy = cy0 + px(28)
		local tw0 = text(W.fonts.bold, px(15), L("cd_news_t"), cx0 + pad, hy, fade(P.TEXT, na))
		local ver = K.VERSION
		local vx = cx0 + pad + tw0 + px(10)
		local vw = tw(W.fonts.semi, px(11), ver) + px(14)
		rect(vx, hy - px(10), vx + vw, hy + px(10), fade(Color(P.GOOD.r, P.GOOD.g, P.GOOD.b, 34), na), px(6))
		text(W.fonts.semi, px(11), ver, vx + px(7), hy, fade(P.GOOD, na))
		local date = L("cd_news_date")
		text(W.fonts.regular, px(11), date, cx0 + cw - pad - tw(W.fonts.regular, px(11), date), hy, fade(P.DIM, na))
		walk(cx0, cy0 + px(48), true)
		local label = L("cd_news_ok")
		local bw, bh = tw(W.fonts.semi, px(12), label) + px(32), px(28)
		local bx1, by1 = cx0 + cw - px(20), cy0 + ch - px(16)
		local bx0, by0 = bx1 - bw, by1 - bh
		local cxm, cym = Input.GetCursorPos()
		local over = W.news and cxm >= bx0 and cxm <= bx1 and cym >= by0 and cym <= by1
		local bhv = approach("news_btn", over and 1 or 0, 20)
		rect(bx0, by0, bx1, by1, fade(mix(P.CHIP_ON, Color(255, 255, 255, 60), bhv), na), px(7))
		text(W.fonts.semi, px(12), label, bx0 + px(16), (by0 + by1) / 2, fade(P.TEXT, na))
		if W.news then
			hit(bx0, by0, bx1, by1, "news_ok")
		end
	end

	local function draw_list_view(x, y, w, h, a)
		if W.counter and not used_set()[W.counter] then
			W.counter = nil
		end
		if W.counter then
			SM.counter_view(x, y, w, h, a)
			return
		end
		local left = x + px(14)
		local res = draft.result
		if not res and draft.summary then
			SM.draw(draft.summary, x, y, w, h, a)
			return
		end
		local ty = y + px(20)
		local hk = ease((os.clock() - W.step_t) / 0.25)
		local list_top = y + px(40)
		if res then
			local key
			if res.acting == 0 then
				key = res.kind == "B" and "ban" or "pick"
			else
				key = res.kind == "B" and "eban" or "epick"
			end
			local title = L("cd_t_" .. key)
			if res.positional and draft.filter > 0 then
				title = L("cd_on"):format(title, L("cd_acc" .. draft.filter))
			end
			if draft.edit then
				title = L("cd_replace")
			end
			local sub = res.context and L("cd_s_" .. key) or L("cd_s_none")
			local lx = left
			lx = lx + text(W.fonts.bold, px(13), title, lx, ty, fade(P.TEXT, a * hk), true) + px(8)
			vline(lx, ty, px(7), a * hk)
			text(W.fonts.regular, px(11), sub, lx + px(8), ty, fade(P.MUTED, a * hk), true)
			if res.positional then
				draw_pos_buttons(res, left, y + px(52), a)
				list_top = y + px(72)
			end
		elseif not cur_step() then
			text(W.fonts.bold, px(13), L("cd_done"), left, ty, fade(P.TEXT, a), true)
		end

		local lx0, ly0 = x + px(8), list_top
		local lx1, ly1 = x + w - px(8), y + h - px(8)
		W.list_rect = { lx0, ly0, lx1, ly1 }
		local stage = load_stage()
		local la = approach("loader", (stage and not res) and 1 or 0, 9)
		if la > 0 then
			draw_loader(lx0, y, lx1, ly1, a * la, stage or A.last_stage)
		end
		if stage then
			A.last_stage = stage
		end
		if not res then
			if not stage and not cur_step() then
				local msg = L("cd_done_tip")
				text(W.fonts.regular, px(12), msg, (lx0 + lx1) / 2 - tw(W.fonts.regular, px(12), msg) / 2,
					(ly0 + ly1) / 2 - px(20), fade(P.MUTED, a * (1 - la)), true)
			end
		else
			local rows = res.rows
			if #rows == 0 then
				text(W.fonts.regular, px(12), L("cd_empty"), left, ly0 + px(24), fade(P.MUTED, a), true)
			end
			local content = 0
			for _, row in ipairs(rows) do
				content = content + (row.comp and px(K.ROW_COMP) or px(K.ROW))
			end
			local lmax = math.max(0, content - (ly1 - ly0))
			local scroll = SB.scroll("list", "list_scroll", lmax)
			Render.PushClip(Vec2(lx0, ly0), Vec2(lx1, ly1), true)
			local cxm, cym = Input.GetCursorPos()
			local inside = in_rect(W.list_rect, cxm, cym) and not over_menu(cxm, cym) and not W.drag
			local now = os.clock()
			local ry = ly0 - scroll
			local order = 0
			for _, row in ipairs(rows) do
				local row_h = row.comp and px(K.ROW_COMP) or px(K.ROW)
				if ry + row_h >= ly0 and ry <= ly1 then
					local e = ease((now - W.list_t0 - order * K.STAGGER) / K.ROW_IN)
					order = order + 1
					local ra = a * e
					local hov = inside and cym >= ry and cym < ry + row_h
					local hv = approach("lh" .. row.h, hov and 1 or 0, 20)
					if hv > 0 then
						rect(lx0, ry, lx1, ry + row_h, fade(P.HOVER, ra * hv), px(8))
					end
					local top_cy = ry + px(K.ROW) / 2
					local ix, iw, ih = lx0 + px(8), px(46), px(26)
					local iy = math.floor(top_cy - ih / 2)
					local img = portrait(row.h)
					if img then
						Render.Image(img, Vec2(ix, iy), Vec2(iw, ih), fade(P.WHITE, ra), px(5), K.ROUND)
					else
						rect(ix, iy, ix + iw, iy + ih, fade(P.FIELD, ra), px(5))
					end
					local nx = ix + iw + px(9)
					local ny = top_cy - px(8)
					local hero = D.by_id[row.h]
					local nw = text(W.fonts.bold, px(12), hero and hero.name or "?", nx, ny, fade(P.TEXT, ra), true)
					if row.pos and res.positional then
						local px0 = nx + nw + px(6)
						px0 = px0 + draw_pos(row.pos, px0, ny, px(14), ra) + px(3)
						text(W.fonts.medium, px(11), ("%d%%"):format(math.floor(row.share * 100 + 0.5)), px0, ny, fade(P.MUTED, ra), true)
					end
					local val = pct(row.delta)
					local rate = ("%.1f%%"):format(M.base(row.h) * 100)
					local games = fmt_games(M.shown_games(row.h))
					local rx = lx1 - px(8)
					local sy = top_cy + px(9)
					local num, num_col, sub_w
					if res.context then
						num = (val >= 0 and "+" or "") .. ("%.1f"):format(val)
						num_col = val >= 0.05 and P.GOOD or (val <= -0.05 and P.BAD or P.MUTED)
						local games_w = tw(W.fonts.regular, px(10), games)
						sub_w = tw(W.fonts.regular, px(10), rate) + games_w + px(13)
						text(W.fonts.regular, px(10), games, rx - games_w, sy, fade(P.MUTED, ra), true)
						vline(rx - games_w - px(7), sy, px(4), ra)
						text(W.fonts.regular, px(10), rate, rx - sub_w, sy, fade(P.MUTED, ra), true)
					else
						num, num_col = rate, P.TEXT
						local label = L("cd_matches"):format(games)
						sub_w = tw(W.fonts.regular, px(10), label)
						text(W.fonts.regular, px(10), label, rx - sub_w, sy, fade(P.MUTED, ra), true)
					end
					local num_w = tw(W.fonts.bold, px(13), num)
					text(W.fonts.bold, px(13), num, rx - num_w, top_cy - px(7), fade(num_col, ra), true)
					local max_x = rx - math.max(num_w, sub_w) - px(10)
					local vy0, vy1 = math.max(ry, ly0), math.min(ry + row_h, ly1)
					if vy1 > vy0 then
						if res.context then
							tip("num" .. row.h, max_x + px(6), vy0, rx + px(4), vy1, L("cd_tip_num_t"):format(num),
								L("cd_tip_num"):format(rate, games))
						else
							tip("num" .. row.h, max_x + px(6), vy0, rx + px(4), vy1, L("cd_tip_wr_t"):format(rate),
								L("cd_tip_wr"):format(games))
						end
					end
					Render.PushClip(Vec2(nx, ry), Vec2(max_x, ry + row_h), true)
					draw_reasons(row, nx, top_cy + px(9), max_x, ra)
					if row.comp then
						draw_comp(row, nx, top_cy + px(27), max_x, ra)
					end
					Render.PopClip()
					if vy1 > vy0 then
						hit(lx0, vy0, lx1, vy1, "row", row.h)
					end
				end
				ry = ry + row_h
			end
			Render.PopClip()
			SB.bar("list", x + w - px(1), ly0, ly1, scroll, lmax, a)
		end
	end

	local function draw_list(x, y, w, h, a)
		local target = W.settings and 1 or 0
		local k = W.set_p or target
		if W.snap then
			k = target
		elseif k < target then
			k = math.min(target, k + dt / K.PAGE_TIME)
		elseif k > target then
			k = math.max(target, k - dt / K.PAGE_TIME)
		end
		W.set_p = k
		Render.PushClip(Vec2(x, y), Vec2(x + w, y + h), true)
		W.list_rect = nil
		local out = ease(clamp(k * 2, 0, 1))
		local inn = ease(clamp(k * 2 - 1, 0, 1))
		if out < 1 then
			local off = math.floor(-out * px(K.PAGE_SLIDE) + 0.5)
			W.nohit = W.settings
			draw_list_view(x + off, y, w, h, a * (1 - out))
			if W.settings then
				W.list_rect = nil
			end
		end
		if inn > 0 then
			local off = math.floor((1 - inn) * px(K.PAGE_SLIDE) + 0.5)
			W.nohit = not W.settings
			draw_settings_page(x + off, y, w, h, a * inn)
		end
		W.nohit = false
		Render.PopClip()
	end

	local PN = {}

	PN.DEMO = {
		hero = 48,
		pos = 1,
		slots = {
			{ name = "power_treads", label = "Power Treads", state = "done", t = 346, cost = 1400 },
			{ name = "mask_of_madness", label = "Mask of Madness", state = "done", t = 608, cost = 1900 },
			{ name = "manta", label = "Manta Style", state = "next", t = 1028, cost = 4650 },
			{ name = "black_king_bar", label = "Black King Bar", state = "later", t = 1559, cost = 4050 },
			{ name = "butterfly", label = "Butterfly", state = "later", t = 1598, cost = 5450 },
			{ name = "monkey_king_bar", label = "Monkey King Bar", state = "later", t = 1880, cost = 5000,
				reason = 44, counter = { "Phantom Assassin", "evasion" } },
			{ name = "satanic", label = "Satanic", state = "later", t = 2084, cost = 5050,
				base = { name = "mask_of_madness", label = "Mask of Madness" }, kind = "dis" },
		},
		more = {
			{ name = "travel_boots", label = "Boots of Travel", state = "later", cost = 2500,
				base = { name = "power_treads", label = "Power Treads" }, kind = "up", from = "Power Treads" },
			{ name = "skadi", label = "Eye of Skadi", state = "later", cost = 5300 },
			{ name = "greater_crit", label = "Daedalus", state = "later", cost = 5100 },
		},
		start = {
			gold = 565,
			items = {
				{ name = "branches", label = "Iron Branch", cost = 55, q = 2, state = "done" },
				{ name = "quelling_blade", label = "Quelling Blade", cost = 100, q = 1, state = "done" },
				{ name = "magic_stick", label = "Magic Stick", cost = 200, q = 1, state = "done" },
				{ name = "tango", label = "Tango", cost = 90, q = 1, state = "done" },
				{ name = "faerie_fire", label = "Faerie Fire", cost = 65, q = 1, state = "done" },
			},
		},
	}
	PN.DEMO.next = PN.DEMO.slots[3]
	PN.NONE = { hero = 48, pos = 3, none = true, slots = {} }

	function PN.demo()
		local D0 = PN.DEMO
		if not D0.ready then
			D0.ready = true
			for _, d in ipairs(D0.slots) do
				local lines = {}
				if d.counter then
					lines[1] = L("cd_tip_item_vs"):format(d.counter[1])
					lines[2] = L("cd_th_" .. d.counter[2])
				end
				if d.base then
					lines[#lines + 1] = L(d.kind == "up" and "cd_tip_up_from" or "cd_tip_dis_from"):format(d.base.label)
				end
				d.body = table.concat(lines, "\n")
			end
			for _, d in ipairs(D0.more) do
				d.body = d.from and L("cd_tip_swap"):format(d.from) or ""
			end
			for _, d in ipairs(D0.start.items) do
				d.title = d.q > 1 and ("%s x%d"):format(d.label, d.q) or d.label
			end
		end
		local chosen = I.bpos[D0.hero]
		if chosen and chosen ~= 1 then
			PN.NONE.pos = chosen
			return PN.NONE
		end
		return D0
	end

	function PN.slot(d, x, y, w, h, a)
		local img = item_img(d.name)
		if img then
			Render.Image(img, Vec2(x, y), Vec2(w, h), fade(P.WHITE, a), px(4), K.ROUND)
		else
			rect(x, y, x + w, y + h, fade(P.FIELD, a), px(4))
		end
		if d.q and d.q > 1 then
			local label = tostring(d.q)
			local lw = tw(W.fonts.bold, px(9), label) + px(6)
			rect(x + px(1), y + h - px(12), x + px(1) + lw, y + h - px(1), fade(P.SHADE, a), px(3))
			text(W.fonts.bold, px(9), label, x + px(4), y + h - px(6.5), fade(P.TEXT, a))
		end
		local ring = math.max(2, px(2))
		if d.reason then
			local bs = math.max(px(15), math.floor(h * 0.62 + 0.5))
			local bx, by = x + w - bs + px(6), y - px(6)
			rect(bx - ring, by - ring, bx + bs + ring, by + bs + ring, fade(P.BG, a), px(5))
			local face = mini(d.reason)
			if face then
				Render.Image(face, Vec2(bx, by), Vec2(bs, bs), fade(P.WHITE, a))
			end
		elseif d.base then
			local bw = math.max(px(16), math.floor(w * 0.56 + 0.5))
			local bh = math.floor(bw * 0.73 + 0.5)
			local bx, by = x + w - bw + px(6), y - px(6)
			rect(bx - ring, by - ring, bx + bw + ring, by + bh + ring, fade(P.BG, a), px(5))
			local src = item_img(d.base.name)
			if src then
				Render.Image(src, Vec2(bx, by), Vec2(bw, bh), fade(P.WHITE, a), px(3), K.ROUND)
			end
		end
	end

	function PN.qbuy(plan, id, name, x0, y0, x1, y1, a, r)
		if plan ~= PN.DEMO and plan ~= PN.NONE then
			SM.qbuy("p" .. id, name, x0, y0, x1, y1, a, r)
		end
	end

	function PN.head(plan, x, y, w, a)
		local hy = y + px(20)
		local lx = x + px(12)
		local face = mini(plan.hero)
		if face then
			Render.Image(face, Vec2(lx, hy - px(10)), Vec2(px(20), px(20)), fade(P.WHITE, a))
			lx = lx + px(26)
		end
		lx = lx + text(W.fonts.bold, px(12), L("cd_p_title"), lx, hy, fade(P.TEXT, a)) + px(8)
		local hero = D.by_id[plan.hero]
		if hero then
			vline(lx, hy, px(6), a)
			text(W.fonts.regular, px(11), hero.name, lx + px(8), hy, fade(P.MUTED, a))
		end
		local size = px(20)
		local bx1 = x + w - px(8)
		local bx0 = bx1 - size
		if plan == PN.DEMO or plan == PN.NONE then
			local tag = L("cd_p_preview")
			text(W.fonts.regular, px(10), tag, bx0 - px(6) - tw(W.fonts.regular, px(10), tag), hy, fade(P.DIM, a))
		end
		hit(x, y, x + w, y + px(34), "pdrag")
		local hv = approach("phide_h", hovered(bx0, hy - size / 2, bx1, hy + size / 2) and 1 or 0, 20)
		if hv > 0 then
			rect(bx0, hy - size / 2, bx1, hy + size / 2, fade(P.HOVER, a * hv * 1.5), px(6))
		end
		glyph("\u{f00d}", bx0 + size / 2, hy, px(10), fade(mix(P.MUTED, P.TEXT, hv), a))
		hit(bx0, hy - size / 2, bx1, hy + size / 2, "phide")
		tip("phide", bx0, hy - size / 2, bx1, hy + size / 2, L("cd_p_hide_t"), L("cd_p_hide"))
	end

	function PN.roles(plan, x, cy, size, a)
		local hero = plan.hero
		local demo = plan == PN.DEMO or plan == PN.NONE
		local have = demo and not I.buys[hero] and { [1] = 400 } or I.positions(hero)
		pos_picker("pr", hero, plan.pos, x, cy, size, px(4), a, have, demo or I.buys[hero] ~= nil)
	end

	function PN.start_fit(plan, avail, max_w)
		local n = plan.start and #plan.start.items or 0
		if n == 0 then
			return 0, 0
		end
		local gap = px(3)
		local iw = math.min(max_w, math.floor((avail - gap * (n - 1)) / n))
		return iw, math.floor(iw * 0.72 + 0.5)
	end

	function PN.start(plan, x, cy, w, a)
		local st = plan.start
		if not st then
			return
		end
		local label = L("cd_p_start")
		local lw = text(W.fonts.medium, px(11), label, x, cy, fade(P.MUTED, a))
		local gold = ("%d / %d"):format(st.gold, K.START_GOLD)
		local gw = tw(W.fonts.regular, px(11), gold)
		text(W.fonts.regular, px(11), gold, x + w - gw, cy, fade(P.DIM, a))
		local ix0 = x + lw + px(10)
		local iw, ih = PN.start_fit(plan, w - lw - gw - px(20), px(30))
		for i, d in ipairs(st.items) do
			local sx = ix0 + (i - 1) * (iw + px(3))
			PN.slot(d, sx, math.floor(cy - ih / 2), iw, ih, a)
			PN.qbuy(plan, "st" .. i, d.name, sx, math.floor(cy - ih / 2), sx + iw, math.floor(cy - ih / 2) + ih, a)
			tip("pst" .. i, sx, cy - ih / 2, sx + iw, cy + ih / 2, d.title or d.label, "")
		end
	end

	function PN.none(plan, x, y, a, measure)
		local w, h = px(300), px(118)
		if measure then
			return w, h
		end
		backdrop(x, y, w, h, a, px(10))
		PN.head(plan, x, y, w, a)
		local pl = plan.pos and L("cd_acc" .. plan.pos) or "?"
		text(W.fonts.medium, px(12), L("cd_build_nopos"):format(pl), x + px(12), y + px(46), fade(P.TEXT, a))
		text(W.fonts.regular, px(10), L("cd_build_nopos2"), x + px(12), y + px(64), fade(P.DIM, a))
		PN.roles(plan, x + px(12), y + h - px(22), px(24), a)
	end

	function PN.later(x0, x1, cy, a)
		local lw = text(W.fonts.semi, px(10), L("cd_p_later"), x0, cy, fade(P.DIM, a))
		rect(x0 + lw + px(8), cy, x1, cy + math.max(1, px(1)), fade(P.LINE, a))
	end

	function PN.sell(sell, x, y, w, a)
		local bh = px(28)
		rect(x, y, x + w, y + bh, fade(P.CELL, a), px(7))
		local iw, ih = px(30), px(22)
		local img = item_img(sell.name)
		if img then
			Render.Image(img, Vec2(x + px(4), y + (bh - ih) / 2), Vec2(iw, ih), fade(P.WHITE, a), px(3), K.ROUND)
		end
		local cy = y + bh / 2
		local tx = x + px(4) + iw + px(8)
		local label = L(sell.stash and "cd_p_stash" or (sell.left and "cd_p_sell_left" or "cd_p_sell"))
		tx = tx + text(W.fonts.regular, px(11), label, tx, cy, fade(P.MUTED, a)) + px(4)
		text(W.fonts.semi, px(11), sell.label, tx, cy, fade(P.TEXT, a))
	end

	function PN.strip(plan, x, y, a, measure)
		local pad, sw, gap = px(12), px(50), px(6)
		local w = pad * 2 + 6 * sw + 5 * gap
		local rows = math.max(1, math.ceil(#plan.slots / K.STRIP_COLS))
		local cols = math.max(6, math.ceil(#plan.slots / rows))
		local iw = math.min(sw, math.floor((w - pad * 2 - gap * (cols - 1)) / cols))
		local ih = math.floor(iw * 0.74 + 0.5)
		local row_h = ih + px(10)
		local sh = rows * row_h - px(10)
		local more = plan.more or {}
		local more_h = #more > 0 and px(26) + ih or 0
		local sell_h = plan.sell and px(36) or 0
		local has_start = plan.start ~= nil
		local top = y + px(34) + (has_start and px(30) or 0)
		local h = top - y + sh + more_h + px(26) + sell_h + px(36)
		if measure then
			return w, h
		end
		backdrop(x, y, w, h, a, px(10))
		PN.head(plan, x, y, w, a)
		if has_start then
			PN.start(plan, x + pad, y + px(48), w - pad * 2, a)
		end
		local sy = top + px(4)
		for i, d in ipairs(plan.slots) do
			local sx = x + pad + ((i - 1) % cols) * (iw + gap)
			local iy = sy + ((i - 1) // cols) * row_h
			PN.slot(d, sx, iy, iw, ih, a)
			PN.qbuy(plan, "n" .. i, d.name, sx, iy, sx + iw, iy + ih, a)
			tip("pn" .. i, sx, iy, sx + iw, iy + ih, d.label, d.body)
		end
		local my = sy + sh
		if #more > 0 then
			PN.later(x + pad, x + w - pad, my + px(13), a)
			local ry = my + px(26)
			for i, d in ipairs(more) do
				local sx = x + pad + (i - 1) * (iw + gap)
				PN.slot(d, sx, ry, iw, ih, a)
				PN.qbuy(plan, "m" .. i, d.name, sx, ry, sx + iw, ry + ih, a)
				tip("pm" .. i, sx, ry, sx + iw, ry + ih, d.label, d.body or "")
			end
			my = my + more_h
		end
		local ny = my + px(15)
		local d = plan.next
		if d then
			text(W.fonts.medium, px(11), d.label, x + pad, ny, fade(P.TEXT, a))
		else
			text(W.fonts.medium, px(11), L("cd_p_all"), x + pad, ny, fade(P.MUTED, a))
		end
		if plan.sell then
			PN.sell(plan.sell, x + pad, ny + px(14), w - pad * 2, a)
		end
		PN.roles(plan, x + pad, y + h - px(20), px(24), a)
	end

	function PN.row(plan, d, id, x, w, ry, row_h, a)
		local rcy = ry + math.floor(row_h / 2)
		if d.state == "next" then
			rect(x + px(6), ry + px(1), x + w - px(6), ry + row_h - px(1), fade(Color(255, 255, 255, 14), a), px(7))
		end
		PN.qbuy(plan, id, d.name, x + px(6), ry + px(1), x + w - px(6), ry + row_h - px(1), a, px(7))
		local iw, ih = px(40), px(29)
		local ix = x + px(12)
		PN.slot(d, ix, math.floor(rcy - ih / 2), iw, ih, a)
		local tx = ix + iw + px(10)
		text(W.fonts.semi, px(12), d.label, tx, rcy - px(7), fade(P.TEXT, a))
		local sy = rcy + px(8)
		if d.from then
			local lx = tx + text(W.fonts.regular, px(11), L("cd_p_instead"):format(d.from), tx, sy, fade(P.MUTED, a)) + px(5)
			local face = d.reason and mini(d.reason)
			if face then
				Render.Image(face, Vec2(lx, math.floor(sy - px(7))), Vec2(px(14), px(14)), fade(P.WHITE, a))
			end
		else
			local sub = d.base and L(d.kind == "up" and "cd_p_up" or "cd_p_dis"):format(d.base.label)
				or L("cd_p_cost"):format(d.cost or 0)
			text(W.fonts.regular, px(11), sub, tx, sy, fade(P.MUTED, a))
		end
		tip("t" .. id, x, ry, x + w, ry + row_h, d.label, d.body or "")
	end

	function PN.list(plan, x, y, a, measure)
		local w = px(286)
		local row_h = px(38)
		local more = plan.more or {}
		local more_h = #more > 0 and px(24) + #more * row_h or 0
		local sell_h = plan.sell and px(36) or 0
		local has_start = plan.start ~= nil
		local top = y + px(34) + (has_start and px(30) or 0)
		local h = top - y + #plan.slots * row_h + more_h + sell_h + px(40)
		if measure then
			return w, h
		end
		backdrop(x, y, w, h, a, px(10))
		PN.head(plan, x, y, w, a)
		if has_start then
			PN.start(plan, x + px(12), y + px(48), w - px(24), a)
		end
		for i, d in ipairs(plan.slots) do
			PN.row(plan, d, "l" .. i, x, w, top + (i - 1) * row_h, row_h, a)
		end
		local ry = top + #plan.slots * row_h
		if #more > 0 then
			PN.later(x + px(12), x + w - px(12), ry + px(12), a)
			ry = ry + px(24)
			for i, d in ipairs(more) do
				PN.row(plan, d, "lm" .. i, x, w, ry, row_h, a)
				ry = ry + row_h
			end
		end
		if plan.sell then
			PN.sell(plan.sell, x + px(12), ry + px(4), w - px(24), a)
		end
		PN.roles(plan, x + px(12), y + h - px(20), px(24), a)
	end

	function draw_panel()
		W.panel_rect = nil
		if not W.open or cfg.panel ~= 1 then
			W.preview = false
		end
		local preview = W.preview and W.open and W.vis > 0 and not G.live
		local plan = preview and PN.demo() or G.plan
		local shop = true
		if not preview and cfg.pshop == 1 then
			local ok, open = pcall(Engine.IsShopOpen)
			shop = ok and open == true
		end
		local show = cfg.panel == 1 and plan ~= nil
			and (preview or (G.live and shop and W.phidden ~= G.match))
		local pa = approach("panel_a", show and 1 or 0, 12)
		if show then
			W.pplan = plan
		end
		plan = W.pplan
		if pa <= 0.01 or not plan then
			W.pdrag = false
			return
		end
		ensure_fonts()
		set_scale(cfg.pzoom)
		local draw = plan.none and PN.none or (cfg.pview == 1 and PN.list or PN.strip)
		local w, h = draw(plan, 0, 0, pa, true)
		local screen = Render.ScreenSize()
		if not W.px then
			W.px = Config.ReadInt(K.CONFIG, "px", -1)
			W.py = Config.ReadInt(K.CONFIG, "py", -1)
			if W.px < 0 or W.py < 0 then
				W.px, W.py = screen.x - w - px(24), math.floor(screen.y * 0.45)
			end
		end
		if W.pdrag then
			if Input.IsKeyDown(K.MOUSE1, true) then
				local cx, cy = Input.GetCursorPos()
				W.px, W.py = cx - W.pdx, cy - W.pdy
			else
				W.pdrag = false
				Config.WriteInt(K.CONFIG, "px", math.floor(W.px))
				Config.WriteInt(K.CONFIG, "py", math.floor(W.py))
			end
		end
		W.px = clamp(W.px, 0, math.max(0, screen.x - w))
		W.py = clamp(W.py, 0, math.max(0, screen.y - h))
		local x, y = math.floor(W.px), math.floor(W.py)
		if show then
			W.panel_rect = { x, y, x + w, y + h }
		end
		draw(plan, x, y, pa, false)
	end

	function draw_tips()
		draw_tip(1)
	end

	function draw_window()
		W.pm_rect, W.gear_block, W.news_block = nil, nil, nil
		if W.slider then
			if Input.IsKeyDown(K.MOUSE1, true) and W.slider_rect then
				local cx = Input.GetCursorPos()
				local k = clamp((cx - W.slider_rect[1]) / math.max(1, W.slider_rect[2] - W.slider_rect[1]), 0, 1)
				cfg.bg = math.floor(50 + 50 * k + 0.5)
			else
				W.slider = false
				set_cfg("bg", cfg.bg)
			end
		end
		local clock = os.clock()
		dt = W.clock and clamp(clock - W.clock, 0, 0.1) or 0
		W.clock = clock
		local open = W.open and ui.enable:Get()
		local was = W.vis
		W.vis = open and math.min(1, W.vis + dt / K.FADE) or math.max(0, W.vis - dt / K.FADE)
		W.hits = {}
		for key in pairs(W.held) do
			if not Input.IsKeyDown(key, true) then
				W.held[key] = nil
			end
		end
		if W.vis <= 0 then
			W.drag = false
			if not open then
				W.pick = nil
			end
			return
		end
		W.snap = was <= 0
		if W.snap then
			W.list_t0, W.step_t = os.clock() + 0.05, os.clock()
		end
		ensure_fonts()
		if draft.dirty then
			recompute()
		end
		local c = cur_step()
		local key = tostring(c) .. (draft.edit and "e" or "") .. ":" .. draft.filter
		if key ~= W.step_c then
			W.step_c, W.step_t = key, os.clock()
		end
		set_scale(cfg.zoom)
		local screen = Render.ScreenSize()
		W.w = px(K.W)
		W.h = px(K.HEAD_H) + px(K.MAIN_H)
		if not W.x then
			W.x = Config.ReadInt(K.CONFIG, "x", -1)
			W.y = Config.ReadInt(K.CONFIG, "y", -1)
			if W.x < 0 or W.y < 0 then
				W.x, W.y = math.floor((screen.x - W.w) / 2), math.floor((screen.y - W.h) / 2)
			end
		end
		if W.drag then
			if Input.IsKeyDown(K.MOUSE1, true) then
				local cx, cy = Input.GetCursorPos()
				W.x, W.y = cx - W.dx, cy - W.dy
			else
				W.drag = false
				Config.WriteInt(K.CONFIG, "x", math.floor(W.x))
				Config.WriteInt(K.CONFIG, "y", math.floor(W.y))
			end
		end
		W.x = clamp(W.x, 0, math.max(0, screen.x - W.w))
		W.y = clamp(W.y, 0, math.max(0, screen.y - W.h))

		local a = W.vis * W.vis * (3 - 2 * W.vis)
		local slide = open and (1 - ease(W.vis)) or (1 - W.vis)
		local x, y, w, h = math.floor(W.x), math.floor(W.y + slide * px(K.SLIDE)), W.w, W.h
		W.news_block = (W.news or W.pick) and { x, y, x + w, y + h } or nil
		W.ox, W.oy = x, y
		backdrop(x, y, w, h, a, px(K.RADIUS))

		draw_header(x, y, w, a)
		local my = y + px(K.HEAD_H)
		local line = math.max(1, px(1))
		rect(x, my, x + w, my + line, fade(P.LINE, a))
		local tl_w, grid_w, main_h = px(K.TL_W), px(K.GRID_W), px(K.MAIN_H)
		draw_timeline(x, my, tl_w, a)
		rect(x + tl_w, my, x + tl_w + line, y + h, fade(P.LINE, a))
		draw_grid(x + tl_w, my, grid_w, main_h, a)
		rect(x + tl_w + grid_w, my, x + tl_w + grid_w + line, y + h, fade(P.LINE, a))
		draw_list(x + tl_w + grid_w, my, w - tl_w - grid_w, main_h, a)
		draw_pos_menu(a)
		SM.slot_menu(a)
		SM.news(x, y, w, h, a)
		SM.pick(x, y, w, h, a)
		SM.toast(x, y, w, h, a)
		W.snap = false
	end
end

local function check_match()
	if not in_match() then
		return
	end
	local gs = GameRules.GetGameState()
	local id = tostring(GameRules.GetMatchID()) .. ":" .. tostring(GameRules.GetLobbyID())
	if gs == K.HERO_SELECTION then
		if draft.match ~= id then
			draft.match = id
			set_mode(GameRules.GetGameMode() == K.MODE_CM and 0 or 1)
			reset_draft()
			I.bpos = {}
			log("new draft %s", id)
			if cfg.auto == 1 then
				open_window()
				W.auto = true
			end
		end
	elseif W.auto and gs ~= K.STRATEGY then
		W.open, W.auto = false, false
	end
end

local function poll_keys()
	if not W.open or not W.focus or W.vis <= 0 then
		return
	end
	local bind = ui.key:Get()
	for _, code in ipairs(K.TYPE_KEYS) do
		if code ~= bind and Input.IsKeyDownOnce(code) then
			type_key(code)
		end
	end
end

local script = {}
local errors = {}

local function guarded(label, fn)
	local ok, err = pcall(fn)
	if not ok and tostring(err) ~= errors[label] then
		errors[label] = tostring(err)
		Log.Write("[Draft Helper] " .. label .. ": " .. errors[label])
	end
end

function script.OnUpdateEx()
	if not ui.enable:Get() then
		W.open = false
		return
	end
	if ui.key:IsPressed() and (W.focus or not Input.IsInputCaptured()) then
		if W.open then
			W.open = false
		else
			open_window()
		end
		W.auto = false
	end
	guarded("keys", poll_keys)
	guarded("data", data_tick)
	guarded("updater", U.tick)
	guarded("items", I.tick)
	guarded("panel", G.tick)
	guarded("sync", sync_free)
	guarded("match", check_match)
	guarded("pick", order_tick)
end

function script.OnFrame()
	guarded("draw", draw_window)
	guarded("panel draw", draw_panel)
	guarded("tips", draw_tips)
end

function script.OnKeyEvent(data)
	if not data then
		return true
	end
	local window_on = W.vis > 0 and W.open
	if not window_on and not W.panel_rect then
		return true
	end
	local key, ev = data.key, data.event
	local scroll = 0
	if ev == K.SCROLL_UP or ev == K.SCROLL_DOWN then
		scroll = ev == K.SCROLL_UP and -1 or 1
	elseif (key == K.WHEEL_UP or key == K.WHEEL_DOWN) and ev == K.KEY_DOWN then
		scroll = key == K.WHEEL_UP and -1 or 1
	end
	if scroll ~= 0 then
		if not cursor_in_window() then
			return true
		end
		local now = os.clock()
		if now - W.scroll_at > 0.004 then
			W.scroll_at = now
			local cx, cy = Input.GetCursorPos()
			local step = math.floor(K.SCROLL * cfg.zoom / 100 * K.BASE_ZOOM + 0.5)
			if W.settings and in_rect(W.set_rect, cx, cy) then
				W.set_scroll = (W.set_scroll or 0) + scroll * step
			elseif in_rect(W.grid_rect, cx, cy) then
				W.grid_scroll = W.grid_scroll + scroll * step
			elseif in_rect(W.list_rect, cx, cy) then
				W.list_scroll = W.list_scroll + scroll * step
			end
		end
		return false
	end
	if key == K.MOUSE1 or key == K.MOUSE2 then
		if ev == K.KEY_DOWN then
			local held = W.held[key]
			W.held[key] = true
			if held then
				return not W.swallow[key]
			end
			if cursor_in_window() then
				W.swallow[key] = true
				W.click_at = os.clock()
				local ok, err = pcall(click, key == K.MOUSE2)
				if not ok then
					Log.Write("[Draft Helper] click: " .. tostring(err))
				end
				return false
			end
			W.focus = false
		elseif ev == K.KEY_UP then
			W.held[key] = nil
			if W.swallow[key] then
				W.swallow[key] = nil
				return false
			end
		end
		return true
	end
	if not window_on or not W.focus or key == ui.key:Get() then
		return true
	end
	if K.CHARS[key] or key == K.BACKSPACE or key == K.ENTER or key == K.PAD_ENTER or key == K.ESCAPE then
		if ev == K.KEY_DOWN then
			type_key(key)
		end
		return false
	end
	return true
end

function script.OnPrepareUnitOrders(data)
	if data and data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM then
		return true
	end
	if os.clock() - W.click_at < K.CLICK_GUARD and cursor_in_window() then
		return false
	end
	return true
end

return script
