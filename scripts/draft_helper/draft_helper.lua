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
		cd_ld_matches = "Loading matches",
		cd_ld_build = "Counting stats",
		cd_ld_wait = "Preparing data",
		cd_ld_count = "%s of %s",
		cd_ld_first = "The first time takes a couple of minutes, then it loads from cache",
		cd_ld_error = "No connection to OpenDota",
		cd_ld_slow = "OpenDota is slow to answer",
		cd_tip_err_t = "Why",
		cd_ld_retry = "retry in %d s",
		cd_ld_short = "matches %d%%",
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
		cd_set_bg = "Background",
		cd_set_debug = "Debug log",
		cd_set_refresh = "Update",
		cd_src_long1 = "Captains Mode",
		cd_upd_now = "updated just now",
		cd_upd_min = "updated %d min ago",
		cd_upd_hour = "updated %d h ago",
		cd_upd_day = "updated %d d ago",
		cd_upd_never = "not loaded yet",
		cd_eta_s = "about %d s left",
		cd_eta_m = "about %d min left",
		cd_eta_short_s = "about %d s",
		cd_eta_short_m = "about %d min",
		cd_ld_days = "%s over %d of %d days",
		cd_cm_now = "Now %s over %d of %d days",
		cd_cm_done = "Loaded %s over %d days",
		cd_cm_total = "about %s in the end",
		cd_cm_wait = "Loading, this takes a few minutes",
		cd_cm_why = "Few CM games, about %d a day, hero pairs lean on ranked",
		cd_cm_why0 = "Few CM games, hero pairs lean on ranked matches",
		cd_lang = "en",
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
		cd_tip_dis_from = "Disassemble %s and build this",
		cd_p_up = "from %s",
		cd_set_preview = "Panel preview",
		cd_preview_show = "Show",
		cd_preview_hide = "Hide",
		cd_tip_preview = "Shows the panel with a sample build,\nyou can drag it with the mouse",
		cd_p_dis = "disassemble %s",
		cd_tip_swap = "Instead of %s",
		cd_tip_swap_why = "%s has %s",
		cd_p_all = "Build complete",
		cd_tip_skipped = "Skipped for now, it stays at the end",
		cd_set_panel = "In-game build panel",
		cd_set_window = "Draft window",
		cd_sec_view = "WINDOW AND PANEL",
		cd_set_pview = "Look",
		cd_pview0 = "Strip",
		cd_pview1 = "List",
		cd_pview2 = "Pill",
		cd_set_pshop = "Only while the shop is open",
		cd_set_padapt = "Adapt to enemy items",
		cd_set_phide = "Hide when the build is complete",
		cd_p_title = "Build",
		cd_p_more = "%d more",
		cd_p_enough = "enough gold",
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
		cd_ld_matches = "Загружаю матчи",
		cd_ld_build = "Считаю статистику",
		cd_ld_wait = "Готовлю данные",
		cd_ld_count = "%s из %s",
		cd_ld_first = "В первый раз это пара минут, дальше всё из кэша",
		cd_ld_error = "Нет связи с OpenDota",
		cd_ld_slow = "OpenDota долго отвечает",
		cd_tip_err_t = "Причина",
		cd_ld_retry = "повтор через %d с",
		cd_ld_short = "матчи %d%%",
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
		cd_set_bg = "Фон",
		cd_set_debug = "Отладка в лог",
		cd_set_refresh = "Обновить",
		cd_src_long1 = "Captains Mode",
		cd_upd_now = "обновлено только что",
		cd_upd_min = "обновлено %d мин назад",
		cd_upd_hour = "обновлено %d ч назад",
		cd_upd_day = "обновлено %d дн назад",
		cd_upd_never = "ещё не загружено",
		cd_eta_s = "осталось около %d с",
		cd_eta_m = "осталось около %d мин",
		cd_eta_short_s = "около %d с",
		cd_eta_short_m = "около %d мин",
		cd_ld_days = "%s за %d из %d дней",
		cd_cm_now = "Сейчас %s за %d из %d дней",
		cd_cm_done = "Загружено %s за %d дней",
		cd_cm_total = "в итоге около %s",
		cd_cm_wait = "Загружаю, это займёт несколько минут",
		cd_cm_why = "В CM мало игр, около %d в день, пары героев дополняются рейтинговыми",
		cd_cm_why0 = "В CM мало игр, пары героев дополняются рейтинговыми",
		cd_lang = "ru",
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
		cd_tip_dis_from = "Разобрать %s и собрать",
		cd_p_up = "из %s",
		cd_set_preview = "Предпросмотр панели",
		cd_preview_show = "Показать",
		cd_preview_hide = "Скрыть",
		cd_tip_preview = "Показывает панель с примером сборки,\nеё можно передвинуть мышью",
		cd_p_dis = "разобрать %s",
		cd_tip_swap = "Вместо %s",
		cd_tip_swap_why = "У %s: %s",
		cd_p_all = "Сборка собрана",
		cd_tip_skipped = "Пропущен, стоит в конце очереди",
		cd_set_panel = "Панель сборки в игре",
		cd_set_window = "Окно драфта",
		cd_sec_view = "ОКНО И ПАНЕЛЬ",
		cd_set_pview = "Вид",
		cd_pview0 = "Полоса",
		cd_pview1 = "Список",
		cd_pview2 = "Плашка",
		cd_set_pshop = "Только при открытом магазине",
		cd_set_padapt = "Менять по предметам врагов",
		cd_set_phide = "Прятать, когда всё собрано",
		cd_p_title = "Сборка",
		cd_p_more = "ещё %d",
		cd_p_enough = "хватает",
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
local CFG_DEFAULTS = {
	source = 0, rank = 2, volume = 1, zoom = 100, bg = 88, blur = 1, tips = 1, auto = 1, debug = 0,
	panel = 1, pview = 0, pzoom = 100, pshop = 0, padapt = 1, phide = 0,
}
for key, value in pairs(CFG_DEFAULTS) do
	cfg[key] = Config.ReadInt("draft_helper", "set_" .. key, value)
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
	VERSION = "1.2.5",
	UPDATE_URL = "https://raw.githubusercontent.com/But3rflys/umbrella-work/main/scripts/draft_helper/version.json",
	UPDATE_EVERY = 6 * 3600,
	UPDATE_MIN_SIZE = 50000,
	UPDATE_RELOAD_DELAY = 1.2,
	SCRIPT_NAME = "draft_helper.lua",

	EXPLORER = "https://api.opendota.com/api/explorer?sql=",
	HEROES_URL = "https://api.opendota.com/api/heroes",
	HEADERS = { ["User-Agent"] = "Umbrella/draft_helper", ["Accept"] = "application/json" },
	TIMEOUT = 40,
	RETRY = 60,
	RETRY_SHORT = 5,
	GAP = 1.1,
	CONFIG = "draft_helper",
	CACHE_FILE = "draft_helper.dat",
	CACHE_MAGIC = "DHC2",
	CACHE_KEYS = 6,
	HEROES_TTL = 7 * 86400,
	PRO_TTL = 3 * 86400,
	MATCHES_TTL = 6 * 3600,
	PRO_MATCHES = 6000,
	CONTEST_MATCHES = 2000,

	PAGE = 2000,
	PAGE_CM = 500,
	PAGE_MIN = 100,
	CM_WINDOW = 4000000,
	CM_MAX = 40000,
	CM_DAYS = 60,
	PARTIAL = 20000,
	PARTIAL_CM = 3000,
	SAVE_EVERY = 10,
	RANKS = { 0, 60, 70, 75 },
	VOLUMES = { 50000, 100000, 200000 },
	REC = 20,
	PACK = "<I8" .. ("B"):rep(12),
	CHUNK = 2500,
	ETA_WARMUP = 4,

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
	},
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

	ITEMS_URL = "https://api.opendota.com/api/constants/items",
	ITEMS_TTL = 7 * 86400,
	BUYS_SQL = "with p as (select pm.match_id, pm.player_slot<128 r, pm.purchase_log, ((pm.player_slot<128) = m.radiant_win) "
		.. "won, "
		.. "array[pm.item_0,pm.item_1,pm.item_2,pm.item_3,pm.item_4,pm.item_5,pm.backpack_0,pm.backpack_1,pm.backpack_2] "
		.. "fin from player_matches pm join matches m using(match_id) where pm.hero_id=%d and pm.purchase_log is not null "
		.. "order by pm.match_id desc limit %d), tm as (select pm.match_id, pm.hero_id, coalesce(pm.lane_role,4) l, "
		.. "pm.gold_per_min gp from player_matches pm join p on p.match_id=pm.match_id and (pm.player_slot<128)=p.r where "
		.. "pm.gold_per_min is not null), c as (select *, row_number() over (partition by match_id, l order by gp desc) "
		.. "lr from tm), d as (select *, case when l in (1,2,3) and lr=1 then l end core from c), e as (select *, "
		.. "row_number() over (partition by match_id, (core is null) order by gp desc) sr from d), q as (select match_id, "
		.. "coalesce(core, case when sr=1 then 4 else 5 end) pos from e where hero_id=%d), x as (select p.match_id, "
		.. "q.pos, p.won, v->>'key' i, (v->>'time')::int t from p join q using(match_id), unnest(p.purchase_log) v), f as "
		.. "(select match_id, pos, won, i, min(t) t, sum(case when t<=0 then 1 else 0 end) s from x group by 1,2,3,4), k "
		.. "as (select distinct p.match_id, q.pos, unnest(p.fin) it from p join q using(match_id)), g as (select q.pos, "
		.. "count(*) g, sum(case when p.won then 1 else 0 end) gw from q join p using(match_id) group by q.pos) select "
		.. "f.pos p, i, count(*) n, sum(case when won then 1 else 0 end) w, percentile_cont(0.5) within group (order by "
		.. "t)::int t, sum(s) s, sum(case when s>0 then 1 else 0 end) m, max(g.g) g, max(g.gw) gw from f join g "
		.. "using(pos) group by f.pos, i having count(*) >= greatest(2, max(g.g) * 0.03) union all select k.pos, '#' || "
		.. "it, count(*), 0, 0, 0, 0, max(g.g), max(g.gw) from k join g using(pos) where it>0 group by k.pos, it having "
		.. "count(*) >= greatest(2, max(g.g) * 0.03)",
	BUYS_VER = 4,
	WIN_MIN = 20,
	BUYS_MATCHES = 400,
	BUYS_MIN = 30,
	BUYS_TTL = 3 * 86400,
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
	COUNTERS = {
		black_king_bar = { magic = 0.5, disable = 0.5, silence = 0.4, roots = 0.4, targeted = 0.5 },
		pipe = { magic = 0.5 },
		glimmer_cape = { magic = 0.4 },
		mage_slayer = { magic = 0.35 },
		sange_and_yasha = { disable = 0.25, silence = 0.25, roots = 0.25 },
		sphere = { targeted = 1 },
		lotus_orb = { targeted = 0.7, silence = 0.5, roots = 0.5 },
		manta = { silence = 0.8, roots = 0.7 },
		cyclone = { silence = 0.6, roots = 0.5, pierce = 0.6, burst = 0.3 },
		wind_waker = { silence = 0.6, roots = 0.5, pierce = 0.6, burst = 0.3 },
		guardian_greaves = { silence = 0.5, roots = 0.4 },
		sheepstick = { escape = 1 },
		orchid = { escape = 0.7 },
		bloodthorn = { escape = 0.7, evasion = 0.5 },
		abyssal_blade = { escape = 0.8 },
		harpoon = { escape = 0.6 },
		rod_of_atos = { escape = 0.5 },
		gungir = { escape = 0.5, illusions = 0.7 },
		diffusal_blade = { escape = 0.4 },
		disperser = { escape = 0.4, saves = 0.8 },
		nullifier = { escape = 0.3, saves = 1 },
		silver_edge = { passives = 1 },
		monkey_king_bar = { evasion = 1 },
		mjollnir = { illusions = 0.8 },
		bfury = { illusions = 0.8 },
		radiance = { illusions = 0.6 },
		shivas_guard = { illusions = 0.5, heal = 0.6, phys = 0.6 },
		skadi = { heal = 0.7, escape = 0.3 },
		spirit_vessel = { heal = 1 },
		ghost = { phys = 0.9, burst = 0.8 },
		ethereal_blade = { phys = 0.5 },
		solar_crest = { phys = 0.6 },
		pavise = { phys = 0.5 },
		force_staff = { phys = 0.3 },
		hurricane_pike = { phys = 0.4 },
		assault = { phys = 0.8 },
		butterfly = { phys = 0.7 },
		heavens_halberd = { phys = 0.8, burst = 0.6 },
		blade_mail = { burst = 1, phys = 0.6, pierce = 0.5 },
		crimson_guard = { phys = 0.5 },
		aeon_disk = { pierce = 0.5, burst = 0.4 },
	},
	FIT = {
		black_king_bar = { core = true },
		pipe = { support = true, core = { str = true } },
		glimmer_cape = { support = true },
		mage_slayer = { core = { agi = true, int = true } },
		sange_and_yasha = { core = { str = true, agi = true, all = true } },
		sphere = { core = true },
		lotus_orb = { support = true, core = { str = true, int = true } },
		manta = { core = { agi = true, all = true } },
		cyclone = { support = true, core = { int = true } },
		guardian_greaves = { support = true },
		sheepstick = { core = { int = true } },
		orchid = { core = { int = true, agi = true } },
		bloodthorn = { core = { int = true, agi = true } },
		abyssal_blade = { core = { str = true, agi = true, all = true } },
		harpoon = { core = { str = true, agi = true, all = true } },
		rod_of_atos = { support = true, core = { int = true } },
		diffusal_blade = { core = { agi = true } },
		silver_edge = { core = { str = true, agi = true, all = true } },
		monkey_king_bar = { core = { str = true, agi = true, all = true } },
		mjollnir = { core = { str = true, agi = true, all = true } },
		gungir = { core = { int = true } },
		bfury = { core = { str = true, agi = true, all = true }, melee = true },
		radiance = { core = { str = true, agi = true, all = true } },
		shivas_guard = { core = { str = true, int = true } },
		skadi = { core = { agi = true, all = true } },
		spirit_vessel = { support = true, core = { str = true } },
		ghost = { support = true },
		solar_crest = { support = true },
		pavise = { support = true },
		ethereal_blade = { core = { int = true } },
		force_staff = { support = true, core = { int = true } },
		assault = { core = { str = true, agi = true, all = true } },
		butterfly = { core = { agi = true, all = true } },
		heavens_halberd = { core = { str = true } },
		blade_mail = { core = { str = true } },
		crimson_guard = { core = { str = true } },
		aeon_disk = { core = true },
		nullifier = { core = true },
	},
	MUST = {
		{ "evasion", 0.8, { [1] = true, [2] = true, [3] = true }, true },
		{ "heal", 0.8, { [4] = true } },
	},
	MUST_MAX = 2,
	MUST_COVER = 0.5,
	PHYS_MIN = 0.8,
	PHYS_ITEMS = {
		bfury = true, manta = true, butterfly = true, greater_crit = true, lesser_crit = true, desolator = true,
		monkey_king_bar = true, skadi = true, satanic = true, mjollnir = true, maelstrom = true, abyssal_blade = true,
		basher = true, disperser = true, diffusal_blade = true, silver_edge = true, bloodthorn = true, echo_sabre = true,
		harpoon = true, armlet = true, mask_of_madness = true, sange_and_yasha = true, nullifier = true, radiance = true,
	},
	REACT = {
		{ items = { "butterfly" }, threat = "evasion", counters = { "monkey_king_bar", "bloodthorn" }, phys = true },
		{ items = { "ghost", "ethereal_blade", "glimmer_cape", "cyclone", "wind_waker" }, threat = "saves",
			counters = { "nullifier" }, rate = true },
		{ items = { "satanic", "heart", "holy_locket", "bloodstone", "guardian_greaves" }, threat = "heal",
			counters = { "spirit_vessel", "skadi", "shivas_guard" } },
		{ items = { "sheepstick", "orchid", "bloodthorn", "abyssal_blade", "nullifier" }, threat = "targeted",
			counters = { "sphere", "lotus_orb" } },
	},
	REACT_MAX = 2,
	REACT_RATE = 0.03,
	RATE_MIN_GAMES = 60,
	HERO_TAGS = "abaddon heal .5;alchemist heal 1;antimage escape .8 passives .3;"
		.. "arc_warden evasion .5 illusions .5 silence .3;axe passives .4 pierce 1 targeted .5;"
		.. "bane pierce .5 targeted 1;batrider escape .3 pierce .6 targeted .9;"
		.. "beastmaster illusions .3 pierce .5 targeted .7;bloodseeker pierce .4 silence .4;"
		.. "bounty_hunter invis .8;brewmaster evasion .5;bristleback passives 1;broodmother illusions .8;"
		.. "chaos_knight illusions .8 passives .5 targeted .4;chen heal .6;clinkz burst .5 invis .8;"
		.. "crystal_maiden roots .4;dark_seer illusions .3;dark_willow escape .5 roots .4;dawnbreaker heal .8;"
		.. "dazzle heal .6;death_prophet silence .5;disruptor silence .6;doom_bringer pierce .7 targeted 1;"
		.. "dragon_knight heal .3 passives .3 targeted .3;drow_ranger passives .6 silence .5;"
		.. "earth_spirit escape .4 silence .3;ember_spirit burst .3 escape .7 roots .5;enchantress heal .6;"
		.. "enigma illusions .4 pierce .7;faceless_void escape .6 passives .5 pierce .6;"
		.. "furion escape .3 illusions .5;grimstroke targeted .4;hoodwink escape .4 evasion .4;"
		.. "huskar burst .6 heal .6 passives .8;invoker illusions .3 invis .5;"
		.. "juggernaut burst .9 heal .6 passives .4;kez escape .4 heal .4 silence .4;kunkka targeted .3;"
		.. "legion_commander burst .7 heal .3 passives .3 pierce .6 targeted 1;lich targeted .4;"
		.. "life_stealer heal .6;lina targeted .4;lion targeted .9;lone_druid illusions .5 roots .3;"
		.. "luna passives .4;lycan burst .3 heal .4 illusions .5;magnataur escape .3 pierce .8;"
		.. "marci burst .6 escape .3 silence .3;mars passives .6;medusa pierce .4;meepo illusions 1 roots .4;"
		.. "mirana escape .5 evasion .3 invis .6;monkey_king escape .5 heal .4 passives .4;morphling escape .6;"
		.. "muerta silence .4;naga_siren evasion .4 illusions 1 roots .5;"
		.. "necrolyte heal .8 passives .4 targeted .6;night_stalker silence .5;nyx_assassin escape .4 invis .8;"
		.. "obsidian_destroyer targeted .4;omniknight heal 1;oracle heal 1;pangolier escape .8;"
		.. "phantom_assassin burst .5 escape .4 evasion 1 passives 1;"
		.. "phantom_lancer escape .5 evasion .5 illusions 1 invis .3;phoenix heal .5;primal_beast pierce .5;"
		.. "puck escape 1 silence .4;pudge pierce .4 targeted .7;pugna heal .4;queenofpain escape .7;"
		.. "rattletrap pierce .3;razor targeted .4;riki burst .4 escape .3 invis 1 silence .5;"
		.. "rubick targeted .4;sand_king escape .3 invis .5;shadow_demon targeted .8;"
		.. "shadow_shaman illusions .4 targeted 1;shredder escape .5 passives .8;silencer silence 1;"
		.. "skeleton_king heal .5 passives .4;skywrath_mage silence .6;slardar passives .4;"
		.. "slark escape 1 passives .7;sniper passives .3;spectre illusions .3 passives .8;"
		.. "spirit_breaker passives .4 pierce .3;storm_spirit escape 1;sven burst .5;techies invis .6;"
		.. "templar_assassin invis .4 passives .3 silence .3;terrorblade burst .4 illusions .8;"
		.. "tidehunter passives .6;tinker escape .4 targeted .3;treant heal 1 pierce .3 roots .4;"
		.. "troll_warlord burst .6 heal .5 passives .5;tusk pierce .3;undying heal .5 illusions .3;"
		.. "ursa burst .8 passives .7;vengefulspirit targeted .3;venomancer illusions .4;"
		.. "viper passives .4 targeted .4;visage illusions .3 invis .5 passives .5;void_spirit escape .9;"
		.. "warlock heal .4 illusions .3;weaver escape .9 invis .8 passives .4;"
		.. "windrunner burst 1 escape .4 evasion .6;winter_wyvern heal .5 pierce .4 targeted .5;"
		.. "wisp escape .3 heal .8;witch_doctor heal .6",

	PANEL_EVERY = 0.5,
	PILL_QUEUE = 6,
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
	COVER = 0.8,
	ENEMY_ITEMS = {
		invis_sword = { invis = 1 },
		silver_edge = { invis = 1 },
		shadow_amulet = { invis = 0.4 },
		glimmer_cape = { invis = 0.3, saves = 0.5 },
		butterfly = { evasion = 1, phys = 0.2 },
		talisman_of_evasion = { evasion = 0.4 },
		heavens_halberd = { evasion = 0.4, roots = 0.4 },
		satanic = { heal = 0.7, phys = 0.2 },
		heart = { heal = 0.6 },
		holy_locket = { heal = 0.4 },
		guardian_greaves = { heal = 0.4 },
		bloodstone = { heal = 0.4 },
		mekansm = { heal = 0.3 },
		vladmir = { heal = 0.2 },
		manta = { illusions = 0.4 },
		helm_of_the_overlord = { illusions = 0.2 },
		orchid = { silence = 0.6, targeted = 0.5 },
		bloodthorn = { silence = 0.8, targeted = 0.6, phys = 0.3 },
		sheepstick = { disable = 0.6, targeted = 0.8 },
		rod_of_atos = { roots = 0.5 },
		gungir = { roots = 0.5 },
		nullifier = { targeted = 0.4 },
		abyssal_blade = { phys = 0.4, targeted = 0.5 },
		dagon = { magic = 0.4 },
		dagon_2 = { magic = 0.4 },
		dagon_3 = { magic = 0.4 },
		dagon_4 = { magic = 0.4 },
		dagon_5 = { magic = 0.4 },
		ethereal_blade = { magic = 0.4, saves = 0.3 },
		veil_of_discord = { magic = 0.2 },
		revenants_brooch = { magic = 0.3 },
		phylactery = { magic = 0.2 },
		blink = { escape = 0.4 },
		swift_blink = { escape = 0.4 },
		arcane_blink = { escape = 0.4 },
		overwhelming_blink = { escape = 0.4 },
		ghost = { saves = 0.5 },
		cyclone = { saves = 0.4 },
		wind_waker = { saves = 0.6 },
		force_staff = { saves = 0.3 },
		hurricane_pike = { saves = 0.4 },
		aeon_disk = { saves = 0.7 },
		lotus_orb = { saves = 0.3 },
		greater_crit = { phys = 0.6 },
		lesser_crit = { phys = 0.3 },
		desolator = { phys = 0.4 },
		basher = { phys = 0.3 },
		monkey_king_bar = { phys = 0.3 },
		bfury = { phys = 0.3 },
		mjollnir = { phys = 0.3 },
		diffusal_blade = { phys = 0.2 },
		disperser = { phys = 0.2 },
	},
	ANTI = {
		monkey_king_bar = { butterfly = 0.5, talisman_of_evasion = 0.3 },
		bloodthorn = { butterfly = 0.3 },
		nullifier = { ghost = 0.5, glimmer_cape = 0.5, cyclone = 0.2 },
		spirit_vessel = { satanic = 0.25, heart = 0.3 },
		skadi = { satanic = 0.2, heart = 0.2 },
		shivas_guard = { satanic = 0.15 },
	},
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
	contest_at = 0,
	pos_prob = {},
	sets = nil,
	loading = nil,
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

local store, store_save, store_load

do
	local function cheat_path(name)
		local dir = Engine.GetCheatDirectory()
		if not dir:match("[\\/]$") then
			dir = dir .. "\\"
		end
		return dir .. "configs\\" .. name
	end

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

	store = { data = { sets = {} }, blobs = {} }

	local function evict()
		local keys = {}
		for key in pairs(store.blobs) do
			keys[#keys + 1] = key
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
		local magic = blob:sub(1, 4)
		local n = string.unpack("<I4", blob, 5)
		local data = decode(blob:sub(9, 8 + n))
		if not data then
			error("broken cache")
		end
		data.sets = type(data.sets) == "table" and data.sets or {}
		local pos = 9 + n
		local blobs = {}
		if magic == "DHC1" then
			local old_sets = data.sets
			data.sets = {}
			for source = 0, 1 do
				local len = string.unpack("<I4", blob, pos)
				local part = blob:sub(pos + 4, pos + 3 + len)
				pos = pos + 4 + len
				local meta = old_sets[tostring(source)]
				if meta and #part > 0 and meta.rank then
					local key = source .. ":" .. math.floor(tonumber(meta.rank))
					blobs[key] = part
					data.sets[key] = meta
				end
			end
		else
			for _, key in ipairs(type(data.blob_keys) == "table" and data.blob_keys or {}) do
				local len = string.unpack("<I4", blob, pos)
				local part = blob:sub(pos + 4, pos + 3 + len)
				if #part ~= len then
					error("broken cache")
				end
				blobs[key] = part
				pos = pos + 4 + len
			end
		end
		return data, blobs
	end

	function store_load()
		local blob = read_path(cheat_path(K.CACHE_FILE))
		local magic = blob and blob:sub(1, 4)
		if blob and #blob >= 8 and (magic == K.CACHE_MAGIC or magic == "DHC1") then
			local ok, data, blobs = pcall(store_read, blob)
			if ok then
				store.data, store.blobs = data, blobs
				if magic ~= K.CACHE_MAGIC then
					store_save()
				end
				return
			end
			log("cache file broken, starting fresh")
		end
	end
end

local function url_encode(s)
	return (s:gsub("[^%w%-_%.~]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
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

local function pack_record(id, ids, win, tier)
	return string.pack(K.PACK, id, ids[1], ids[2], ids[3], ids[4], ids[5], ids[6], ids[7], ids[8], ids[9], ids[10],
		win, tier)
end

local function new_set(source)
	return {
		source = source,
		file = source == 1 and "cm" or "ranked",
		page = source == 1 and K.PAGE_CM or K.PAGE,
		recs = {},
		rank = nil,
		updated = 0,
		job = nil,
		build = nil,
		stats = nil,
		loaded = false,
		force = false,
		exhausted = false,
	}
end

D.sets = { [0] = new_set(0), [1] = new_set(1) }

local function source()
	return cfg.source == 1 and 1 or 0
end

local function load_set(S, rank)
	S.loaded = true
	S.recs, S.stats, S.build, S.job = {}, nil, nil, nil
	S.rank, S.updated, S.exhausted, S.oldest = rank, 0, false, nil
	local key = S.source .. ":" .. rank
	local meta = store.data.sets[key]
	local blob = store.blobs[key]
	if meta and blob and #blob % K.REC == 0 then
		S.updated = tonumber(meta.updated) or 0
		S.exhausted = meta.exhausted == true
		S.oldest = tonumber(meta.oldest)
		local recs = {}
		for i = 1, #blob, K.REC do
			recs[#recs + 1] = blob:sub(i, i + K.REC - 1)
		end
		S.recs = recs
		meta.used = os.time()
	end
	draft.dirty = true
	log("cache %s rank %d: %d matches", S.file, rank, #S.recs)
end

local function load_cache()
	D.loaded = true
	store_load()
	local heroes = store.data.heroes
	if heroes and type(heroes.list) == "table" then
		set_heroes(heroes.list)
		D.heroes_at = tonumber(heroes.time) or 0
	end
	local pro = store.data.pro
	if type(pro) == "table" then
		if type(pro.pos) == "table" then
			set_pos(pro.pos)
			D.pos_at = tonumber(pro.pos_time) or 0
		end
		if type(pro.contest) == "table" then
			set_contest(pro.contest)
			D.contest_at = tonumber(pro.contest_time) or 0
		end
	end
	load_set(D.sets[0], K.RANKS[cfg.rank + 1] or 70)
end

local function save_matches(S)
	if not S.rank then
		return
	end
	local key = S.source .. ":" .. S.rank
	store.blobs[key] = table.concat(S.recs)
	store.data.sets[key] = { updated = S.updated, exhausted = S.exhausted, oldest = S.oldest, used = os.time() }
	store_save()
end

local function record_id(rec)
	return (string.unpack("<I8", rec))
end

local function build_chunk(b)
	local st, recs = b.st, b.recs
	local bg, bw, vg, vw, sg, sw = st.bg, st.bw, st.vg, st.vw, st.sg, st.sw
	local h = b.h
	local last = math.min(st.n, b.i + K.CHUNK)
	for i = b.i + 1, last do
		local rec = recs[i]
		h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8], h[9], h[10] = rec:byte(9, 18)
		local rad = rec:byte(19) == 1
		for j = 1, 10 do
			local a = h[j]
			bg[a] = (bg[a] or 0) + 1
			if (j <= 5) == rad then
				bw[a] = (bw[a] or 0) + 1
			end
		end
		for j = 1, 5 do
			local a = h[j]
			for l = 6, 10 do
				local c = h[l]
				local key, won
				if a < c then
					key, won = a * 256 + c, rad
				else
					key, won = c * 256 + a, not rad
				end
				vg[key] = (vg[key] or 0) + 1
				if won then
					vw[key] = (vw[key] or 0) + 1
				end
			end
		end
		for t = 0, 5, 5 do
			local won = (t == 0) == rad
			for j = 1, 4 do
				local a = h[t + j]
				for l = j + 1, 5 do
					local c = h[t + l]
					local key = a < c and a * 256 + c or c * 256 + a
					sg[key] = (sg[key] or 0) + 1
					if won then
						sw[key] = (sw[key] or 0) + 1
					end
				end
			end
		end
	end
	b.i = last
	return last >= st.n
end

local function start_build(S, recs)
	recs = recs or S.recs
	S.build = {
		recs = recs,
		i = 0,
		h = {},
		st = { bg = {}, bw = {}, vg = {}, vw = {}, sg = {}, sw = {}, n = #recs },
	}
	log("building %s stats from %d matches", S.file, #recs)
end

local function step_build(S)
	local b = S.build
	if not b then
		return
	end
	local ok, done = pcall(build_chunk, b)
	if not ok then
		Log.Write("[Draft Helper] build: " .. tostring(done))
		S.build = nil
		return
	end
	if done then
		S.build = nil
		local counts = {}
		for _, g in pairs(b.st.bg) do
			if g >= K.MIN_GAMES then
				counts[#counts + 1] = g
			end
		end
		table.sort(counts)
		b.st.median = counts[math.max(1, math.floor(#counts / 2))] or 1
		S.stats = b.st
		draft.dirty = true
		log("%s stats ready: %d matches", S.file, b.st.n)
	end
end

local function matches_sql(S, rank, above, below)
	local where = { S.source == 1 and "game_mode=2" or "lobby_type=7" }
	if rank > 0 then
		where[#where + 1] = "avg_rank_tier>=" .. rank
	end
	if above then
		where[#where + 1] = ("match_id>%d"):format(above)
	end
	if below then
		where[#where + 1] = ("match_id<%d"):format(below)
	end
	return ("select match_id m, radiant_team r, dire_team d, radiant_win w, avg_rank_tier t, start_time s from public_matches where %s order by match_id desc limit %d")
		:format(table.concat(where, " and "), S.page)
end

local function parse_matches(text)
	if type(text) ~= "string" then
		return nil, "empty response"
	end
	local err = text:match('"err":"([^"]*)"')
	if err then
		return nil, err
	end
	local count = tonumber(text:match('"rowCount":(%d+)'))
	if not count then
		return nil, "no rows"
	end
	local out, low, oldest, high, newest = {}, nil, nil, nil, nil
	for obj in text:gmatch('{"m":[^{}]-}') do
		local id = math.tointeger(tonumber(obj:match('"m":(%d+)')))
		local r, d = obj:match('"r":%[([%d,]*)%]'), obj:match('"d":%[([%d,]*)%]')
		local w = obj:match('"w":(%a+)')
		local t = tonumber(obj:match('"t":(%d+)')) or 0
		local s = tonumber(obj:match('"s":(%d+)'))
		if id then
			low = low and math.min(low, id) or id
			high = high and math.max(high, id) or id
			if s then
				oldest = oldest and math.min(oldest, s) or s
				newest = newest and math.max(newest, s) or s
			end
			if r and d and (w == "true" or w == "false") then
				local ids, ok = {}, true
				for hero in (r .. "," .. d):gmatch("%d+") do
					local v = tonumber(hero)
					if not v or v < 1 or v > 255 then
						ok = false
					end
					ids[#ids + 1] = v
				end
				if ok and #ids == 10 then
					out[#out + 1] = pack_record(id, ids, w == "true" and 1 or 0, clamp(t, 0, 255))
				end
			end
		end
	end
	return out, count, low, oldest, high, newest
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
	local sent = HTTP.Request("GET", url, { headers = K.HEADERS, timeout = K.TIMEOUT }, function(res)
		D.busy = false
		D.next_request = os.clock() + K.GAP
		local ok, err = pcall(on_done, res)
		if not ok then
			D.error = tostring(err):gsub("^.-:%d+: ", "")
			D.next_request = os.clock() + (D.error:lower():find("timeout", 1, true) and K.RETRY_SHORT or K.RETRY)
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

local function fail(what, res)
	local body = type(res.response) == "string" and res.response:match('"err":"([^"]*)"') or ""
	error(("%s: http %s %s %s"):format(what, tostring(res.code), tostring(res.error_message or ""), body))
end

local function request_heroes()
	D.status = "cd_st_heroes"
	request(K.HEROES_URL, "cd_heroes", function(res)
		if tostring(res.code) ~= "200" then
			fail("heroes", res)
		end
		local list = JSON:decode(res.response)
		if type(list) ~= "table" or #list < 100 then
			error("heroes: bad list")
		end
		set_heroes(list)
		D.heroes_at = os.time()
		D.error = nil
		store.data.heroes = { time = D.heroes_at, list = list }
		store_save()
		log("heroes loaded: %d", #D.heroes)
	end)
end

local function explorer(sql, param, on_rows)
	request(K.EXPLORER .. url_encode(sql), param, function(res)
		if tostring(res.code) ~= "200" then
			fail(param, res)
		end
		local data = JSON:decode(res.response)
		if type(data) ~= "table" or data.err or type(data.rows) ~= "table" then
			error(param .. ": " .. tostring(type(data) == "table" and data.err or "no rows"))
		end
		on_rows(data.rows)
		D.error = nil
	end)
end

local function save_pro(rows_pos, rows_contest)
	local pro = type(store.data.pro) == "table" and store.data.pro or {}
	if rows_pos then
		pro.pos, pro.pos_time = rows_pos, D.pos_at
	end
	if rows_contest then
		pro.contest, pro.contest_time = rows_contest, D.contest_at
	end
	store.data.pro = pro
	store_save()
end

local function request_pos()
	D.status = "cd_st_pro"
	local sql = ("with m as (select match_id from matches order by match_id desc limit %d), "
		.. "p as (select pm.match_id, pm.hero_id h, pm.player_slot<128 t, coalesce(pm.lane_role,4) l, pm.gold_per_min g "
		.. "from player_matches pm join m using(match_id) where pm.gold_per_min is not null), "
		.. "c as (select *, row_number() over (partition by match_id, t, l order by g desc) lr from p), "
		.. "d as (select *, case when l in (1,2,3) and lr=1 then l end core from c), "
		.. "e as (select *, row_number() over (partition by match_id, t, (core is null) order by g desc) sr from d) "
		.. "select h, coalesce(core, case when sr=1 then 4 else 5 end) pos, count(*) n from e group by 1,2")
		:format(K.PRO_MATCHES)
	explorer(sql, "cd_pos", function(rows)
		set_pos(rows)
		D.pos_at = os.time()
		save_pro(rows, nil)
		log("positions loaded: %d rows", #rows)
	end)
end

local function request_contest()
	D.status = "cd_st_pro"
	local sql = ("with m as (select match_id from matches where game_mode=2 order by match_id desc limit %d) "
		.. "select hero_id h, count(*) c, (select count(*) from m) n from picks_bans join m using(match_id) group by 1")
		:format(K.CONTEST_MATCHES)
	explorer(sql, "cd_contest", function(rows)
		set_contest(rows)
		D.contest_at = os.time()
		save_pro(nil, rows)
		log("pro contest loaded: %d heroes", #rows)
	end)
end

local function finish_job(S)
	local job = S.job
	S.job = nil
	S.updated = os.time()
	save_matches(S)
	start_build(S)
	log("%s ready: %d (rank %d, %d new)", S.file, #S.recs, S.rank, job.added or 0)
end

local function next_window(job)
	job.cursor = job.lo + 1
	job.lo = job.cursor - K.CM_WINDOW
end

local function request_page(S)
	local job = S.job
	local rank, target = want(S)
	if rank ~= S.rank then
		S.job = nil
		return
	end
	local windowed = S.source == 1 and job.phase == "tail" and job.lo ~= nil
	local sql
	if job.phase == "head" then
		sql = matches_sql(S, rank, job.top, job.cursor)
	elseif windowed then
		sql = matches_sql(S, rank, job.lo, job.cursor)
	else
		sql = matches_sql(S, rank, nil, job.cursor)
	end
	D.status = "cd_st_matches"
	D.loading = S
	local cutoff = S.source == 1 and os.time() - K.CM_DAYS * 86400 or nil
	request(K.EXPLORER .. url_encode(sql), "cd_page", function(res)
		if S.job ~= job then
			return
		end
		local recs, count, low, oldest, high, newest
		if tostring(res.code) == "200" then
			recs, count, low, oldest, high, newest = parse_matches(res.response)
		else
			count = type(res.response) == "string" and res.response:match('"err":"([^"]*)"')
				or ("http " .. tostring(res.code) .. " " .. tostring(res.error_message or ""))
		end
		if not recs then
			local timeout = tostring(count):lower():find("timeout", 1, true)
			if timeout then
				if S.page > K.PAGE_MIN then
					S.page = math.max(K.PAGE_MIN, math.floor(S.page / 2))
				elseif windowed then
					job.fails = (job.fails or 0) + 1
					if job.fails >= 2 then
						job.fails = 0
						next_window(job)
						log("%s: window skipped after timeouts", S.file)
					end
				end
			end
			error("page: " .. tostring(count))
		end
		D.error = nil
		job.fails = 0
		job.pages = job.pages + 1
		job.added = (job.added or 0) + #recs
		if oldest then
			job.oldest = job.oldest and math.min(job.oldest, oldest) or oldest
			S.oldest = S.oldest and math.min(S.oldest, oldest) or oldest
		end
		if S.source == 1 and not job.floor and high and low and newest and oldest and newest > oldest then
			local rate = (high - low) / (newest - oldest)
			job.floor = math.floor(high - rate * K.CM_DAYS * 86400)
		end
		local too_old = (cutoff and oldest and oldest < cutoff) or (job.floor and job.cursor and job.cursor < job.floor)
		if job.phase == "head" then
			for _, rec in ipairs(recs) do
				job.newer[#job.newer + 1] = rec
			end
			job.cursor = low
			if count < S.page or not low or #job.newer >= target or too_old then
				local merged = job.newer
				if #merged < target then
					for _, rec in ipairs(S.recs) do
						merged[#merged + 1] = rec
						if #merged >= target then
							break
						end
					end
				end
				S.recs = merged
				job.newer = nil
				if #S.recs < target and #S.recs > 0 and not too_old and not S.exhausted then
					job.phase, job.cursor = "tail", record_id(S.recs[#S.recs])
					if S.source == 1 then
						job.lo = job.cursor - K.CM_WINDOW
					end
				else
					if too_old then
						S.exhausted = true
					end
					finish_job(S)
					return
				end
			end
		else
			for _, rec in ipairs(recs) do
				if #S.recs >= target then
					break
				end
				S.recs[#S.recs + 1] = rec
			end
			if S.source == 1 then
				if not job.lo then
					job.cursor = low
					job.lo = low and low - K.CM_WINDOW or nil
				elseif count < S.page or not low then
					next_window(job)
				else
					job.cursor = low
				end
				local done = too_old or #S.recs >= target or not job.cursor
				if done then
					if #S.recs < target then
						S.exhausted = true
					end
					finish_job(S)
					return
				end
			else
				job.cursor = low
				if count < S.page or not low or #S.recs >= target or too_old then
					if #S.recs < target then
						S.exhausted = true
					end
					finish_job(S)
					return
				end
			end
			if job.pages % K.SAVE_EVERY == 0 then
				save_matches(S)
			end
		end
		if not S.stats and not S.build then
			local pool = (S.job and S.job.newer and #S.recs == 0) and S.job.newer or S.recs
			if #pool >= (S.source == 1 and K.PARTIAL_CM or K.PARTIAL) then
				start_build(S, pool)
			end
		end
	end)
end

local function job_counts()
	local S = D.loading or D.sets[source()]
	local _, target = want(S)
	local job = S.job
	local have = #S.recs
	if job and job.newer then
		have = math.min(target, #job.newer + #S.recs)
	end
	return have, target
end

local function job_progress()
	local have, target = job_counts()
	local p = clamp(have / target, 0, 1)
	local S = D.loading
	if S and S.source == 1 and S.job and S.job.oldest and S.job.phase == "tail" then
		p = math.max(p, clamp((os.time() - S.job.oldest) / (K.CM_DAYS * 86400), 0, 1))
	end
	return p
end

local function job_days()
	local S = D.loading
	if S and S.source == 1 and S.job and S.job.oldest then
		return math.floor((os.time() - S.job.oldest) / 86400)
	end
	return nil
end

local function job_eta()
	local S = D.loading
	local job = S and S.job
	if not job or not job.t0 then
		return nil
	end
	local p = job_progress()
	job.p0 = job.p0 or p
	local elapsed = os.clock() - job.t0
	if elapsed < K.ETA_WARMUP or p <= job.p0 + 0.005 then
		return nil
	end
	return elapsed * (1 - p) / (p - job.p0)
end

local function plan_job(S)
	if S.job then
		return
	end
	local rank, target = want(S)
	if not S.loaded then
		load_set(S, rank)
	elseif S.rank ~= rank then
		if #S.recs > 0 then
			save_matches(S)
		end
		load_set(S, rank)
	end
	if #S.recs > target then
		for i = #S.recs, target + 1, -1 do
			S.recs[i] = nil
		end
		save_matches(S)
		start_build(S)
	end
	local stale = os.time() - S.updated > K.MATCHES_TTL
	if S.force then
		S.exhausted = false
	end
	if S.force or stale or (#S.recs < target and not S.exhausted) then
		local top = #S.recs > 0 and record_id(S.recs[1]) or nil
		if top then
			S.job = { phase = "head", top = top, cursor = nil, newer = {}, pages = 0 }
		else
			S.job = { phase = "tail", cursor = nil, pages = 0 }
		end
		S.job.t0 = os.clock()
		S.job.p0 = clamp(#S.recs / target, 0, 1)
		S.force = false
		log("job %s: rank %d, have %d, want %d, top %s", S.file, rank, #S.recs, target, tostring(top))
	elseif not S.stats and not S.build and #S.recs > 0 then
		start_build(S)
	end
end

local function any_busy()
	for _, S in pairs(D.sets) do
		if S.job or S.build then
			return true
		end
	end
	return false
end

local function data_tick()
	if not D.loaded then
		load_cache()
	end
	step_build(D.sets[0])
	step_build(D.sets[1])
	if D.busy or os.clock() < D.next_request then
		return
	end
	local now = os.time()
	if not D.heroes or now - D.heroes_at > K.HEROES_TTL then
		request_heroes()
		return
	end
	if not D.pos_count or now - D.pos_at > K.PRO_TTL then
		request_pos()
		return
	end
	if not D.contest or now - D.contest_at > K.PRO_TTL then
		request_contest()
		return
	end
	local order = { D.sets[0] }
	if source() == 1 then
		order = (D.sets[0].stats or D.sets[0].build) and { D.sets[1], D.sets[0] } or { D.sets[0], D.sets[1] }
	end
	for _, S in ipairs(order) do
		plan_job(S)
		if S.job then
			request_page(S)
			return
		end
	end
	D.loading = nil
	D.status = any_busy() and "cd_st_build" or nil
end

local function refresh_data()
	D.heroes_at, D.pos_at, D.contest_at = 0, 0, 0
	for _, S in pairs(D.sets) do
		S.force = true
	end
	D.next_request, D.error = 0, nil
	log("manual refresh")
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
		local dir = Engine.GetCheatDirectory()
		if not dir:match("[\\/]$") then
			dir = dir .. "\\"
		end
		return dir .. "scripts\\" .. K.SCRIPT_NAME
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
				best_map = { (table.unpack or unpack)(map, 1, n) }
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
	tags = nil,
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
				}
				items[id] = item
				by_name[item.name] = item
			end
		end
		I.items, I.by_name, I.builds = items, by_name, {}
	end

	local function parse_items(text)
		local starts, pos = {}, 1
		while true do
			local s, e, key = text:find('"([%w_]+)":{', pos)
			if not s then
				break
			end
			starts[#starts + 1] = { s = s, e = e, key = key }
			pos = e + 1
		end
		local list = {}
		for i, st in ipairs(starts) do
			if not st.key:find("^recipe") then
				local seg = text:sub(st.e, starts[i + 1] and starts[i + 1].s - 1 or #text)
				local id = tonumber(seg:match('"id":(%d+)'))
				if id then
					local parts = (seg:match('"components":%[([^%]]*)%]') or ""):gsub('"', "")
					list[#list + 1] = {
						id = id,
						n = st.key,
						d = seg:match('"dname":"([^"]*)"'),
						c = tonumber(seg:match('"cost":(%d+)')) or 0,
						m = seg:find('"created":true', 1, true) and 1 or 0,
						p = parts,
					}
				end
			end
		end
		return list
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

	local function load()
		I.loaded = true
		local items = store.data.items
		if type(items) == "table" and type(items.list) == "table" then
			set_items(items.list)
			I.items_at = tonumber(items.time) or 0
		end
		local buys = store.data.buys
		if type(buys) == "table" then
			for key, entry in pairs(buys) do
				local h = math.tointeger(tonumber(key))
				if h and type(entry) == "table" and type(entry.rows) == "table" and entry.v == K.BUYS_VER then
					set_buys(h, entry.rows)
					I.buys_at[h] = tonumber(entry.time) or 0
				end
			end
		end
	end

	local function fetch(url, param, on_done)
		I.busy = true
		local sent = HTTP.Request("GET", url, { headers = K.HEADERS, timeout = K.TIMEOUT }, function(res)
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

	local function keep_buys(h, rows)
		local buys = type(store.data.buys) == "table" and store.data.buys or {}
		buys[tostring(h)] = { time = I.buys_at[h], rows = rows, v = K.BUYS_VER }
		local keys = {}
		for key in pairs(buys) do
			keys[#keys + 1] = key
		end
		if #keys > K.BUYS_KEEP then
			table.sort(keys, function(x, y)
				return (tonumber(buys[x].time) or 0) > (tonumber(buys[y].time) or 0)
			end)
			for n = K.BUYS_KEEP + 1, #keys do
				buys[keys[n]] = nil
			end
		end
		store.data.buys = buys
		I.dirty = true
	end

	local function request_items()
		fetch(K.ITEMS_URL, "cd_items", function(res)
			if tostring(res.code) ~= "200" or type(res.response) ~= "string" then
				error(("items: http %s %s"):format(tostring(res.code), tostring(res.error_message or "")))
			end
			local list = parse_items(res.response)
			if #list < 100 then
				error("items: bad list")
			end
			set_items(list)
			I.items_at = os.time()
			store.data.items = { time = I.items_at, list = list }
			I.dirty = true
			log("items loaded: %d", #list)
		end)
	end

	local function request_buys(h)
		local url = K.EXPLORER .. url_encode(K.BUYS_SQL:format(h, K.BUYS_MATCHES, h))
		fetch(url, "cd_buys", function(res)
			if tostring(res.code) ~= "200" or type(res.response) ~= "string" then
				I.skip[h] = os.clock() + K.ITEM_FAIL_SKIP
				error(("purchases %d: http %s %s"):format(h, tostring(res.code), tostring(res.error_message or "")))
			end
			local data = JSON:decode(res.response)
			if type(data) ~= "table" or data.err or type(data.rows) ~= "table" then
				I.skip[h] = os.clock() + K.ITEM_FAIL_SKIP
				error(("purchases %d: %s"):format(h, tostring(type(data) == "table" and data.err or "bad answer")))
			end
			local rows = {}
			for _, r in ipairs(data.rows) do
				rows[#rows + 1] = {
					p = tonumber(r.p),
					i = r.i,
					n = tonumber(r.n) or 0,
					w = tonumber(r.w) or 0,
					t = tonumber(r.t) or 0,
					s = tonumber(r.s) or 0,
					m = tonumber(r.m) or 0,
					g = tonumber(r.g) or 0,
					gw = tonumber(r.gw) or 0,
				}
			end
			I.buys_at[h] = os.time()
			set_buys(h, rows)
			keep_buys(h, rows)
			log("purchases loaded for %d: %d rows", h, #rows)
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
		if I.busy or os.clock() < I.next_at then
			return
		end
		if sm or I.want then
			local now = os.time()
			if not I.items or now - I.items_at > K.ITEMS_TTL then
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
				local stale = not I.buys[h] or now - (I.buys_at[h] or 0) > K.BUYS_TTL
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

	local function parse_tags()
		local tags = {}
		for entry in K.HERO_TAGS:gmatch("[^;]+") do
			local words = {}
			for word in entry:gmatch("%S+") do
				words[#words + 1] = word
			end
			local t = {}
			for k = 2, #words - 1, 2 do
				t[words[k]] = tonumber(words[k + 1])
			end
			tags["npc_dota_hero_" .. words[1]] = t
		end
		return tags
	end

	function I.threats(h)
		local cached = I.threat_of[h]
		if cached then
			return cached
		end
		I.tags = I.tags or parse_tags()
		local hero = D.by_id[h]
		local t = {}
		if hero then
			for k, v in pairs(I.tags[hero.unit] or {}) do
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
			if not locked(sl) and not sl.must and not K.BOOTS[sl.item.name] then
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
		local new = {}
		for k, v in pairs(cd) do
			new[k] = v
		end
		new.replaced, new.drop, new.core = slots[idx].item, nil, nil
		slots[idx] = new
		return new
	end

	function I.must(slots, cands, T, per, them, h, pos, locked)
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

	function I.react(slots, cands, them, seen, h, pos, locked)
		local added = {}
		local phys = I.physical(h, pos)
		for _, rule in ipairs(K.REACT) do
			local source
			for _, e in ipairs(them) do
				for _, name in ipairs(rule.items) do
					if not source and seen[e] and seen[e][name] then
						source = { e = e, item = name }
					end
				end
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
		local key = ("%d:%d:%s:%d:%d"):format(h, pos or 0, table.concat(them, ","), I.items_at, I.buys_at[h] or 0)
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
		I.must(picked, cands, T, per, them, h, pos, function(s)
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
		local build = { slots = picked, steps = steps, start = start, gold = gold, spare = spare, early = early }
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

local function hero_score(h, allies, enemies, reasons)
	local delta = 0
	for _, e in ipairs(enemies) do
		local v = M.adv(h, e) * K.ADV_W
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
			if q == p then
				manual[j] = nil
			end
		end
	end
	manual[i] = p
	draft.dirty = true
end

local function recompute()
	draft.dirty = false
	local c0 = cur_step()
	if draft.mode == 1 and c0 and c0 == draft.me and draft.my_role and draft.filter == 0 and not draft.filter_user then
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
	local cs = cur_step()
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
	local base_fit, base_map = 0, {}
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
	local early = #allies + #enemies < 4
	local pick_no = math.min(5, #allies + 1)
	local function order_bonus(pos)
		if not our_pick or sel > 0 or not pos then
			return 0
		end
		return K.ORDER_W * math.log(K.PICK_ORDER[pick_no][pos] / 0.2)
	end
	local rows = {}
	local team = { (table.unpack or unpack)(rest) }
	local slot = #team + 1
	for _, hero in ipairs(D.heroes) do
		local h = hero.id
		if not used[h] and M.games(h) >= K.MIN_GAMES and not (our_pick and #allies >= 5) then
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
			if ok then
				local reasons = {}
				local delta = hero_score(h, allies, enemies, reasons)
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
	draft.result = { acting = acting, kind = kind, persp = persp, taken = taken, rows = rows, positional = acting == 0,
		context = #allies + #enemies > 0 }
	W.list_t0 = os.clock()
end

local function reset_draft()
	draft.steps, draft.edit, draft.query, draft.filter, draft.dirty = {}, nil, "", 0, true
	draft.known_pos, draft.me, draft.my_role, draft.filter_user, draft.sync_sig = {}, nil, nil, false, nil
	draft.tentative, draft.build_h, draft.summary_sig = {}, nil, nil
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

local enemy_panel_heroes

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

local function collect_units(panel, out, seen, depth)
	if depth > K.PANEL_DEPTH then
		return
	end
	local okv, visible = pcall(panel.IsVisible, panel)
	if okv and visible == false then
		return
	end
	local unit = panel_unit(panel)
	if unit and not seen[unit] then
		seen[unit] = true
		out[#out + 1] = unit
	end
	local okc, count = pcall(panel.GetChildCount, panel)
	if not okc or not count then
		return
	end
	for i = 0, count - 1 do
		local okg, child = pcall(panel.GetChild, panel, i)
		if okg and child then
			collect_units(child, out, seen, depth + 1)
		end
	end
end

function enemy_panel_heroes(my_team)
	local id = my_team == K.TEAM_DIRE and "RadiantTeamPlayers" or "DireTeamPlayers"
	local ok, root = pcall(Panorama.GetPanelByName, id, false)
	local out = {}
	if ok and root then
		collect_units(root, out, {}, 0)
	end
	if draft.panel_log ~= (ok and root and "found" or "missing") .. #out then
		draft.panel_log = (ok and root and "found" or "missing") .. #out
		log("panel %s: %s, heroes: %s", id, (ok and root) and "found" or "missing", table.concat(out, " "))
	end
	return out
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
		for j, id in ipairs(list) do
			if j <= 10 then
				set(10 + j, id)
			end
			sig[#sig + 1] = "b" .. id
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
	bpos = nil,
	gold = 0,
	time = 0,
	plan = nil,
	sig = nil,
	next_at = 0,
}

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

	local function copy(cd)
		local out = {}
		for k, v in pairs(cd) do
			out[k] = v
		end
		return out
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

	local function add_threats(e, T, from, with_items)
		local t = {}
		for k, v in pairs(I.threats(e)) do
			t[k] = v
		end
		if with_items then
			for name in pairs(G.seen[e] or {}) do
				for threat, w in pairs(K.ENEMY_ITEMS[name] or {}) do
					t[threat] = (t[threat] or 0) + w
					from[#from + 1] = { e = e, item = name, threat = threat, w = w }
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
					if s.item == item then
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
		for _, e in ipairs(G.them) do
			add_threats(e, T0, {}, false)
			per1[e] = add_threats(e, T1, from, adapt)
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
			for _, new in ipairs(I.must(slots, cands, T1, per1, G.them, G.hero, G.bpos, locked)) do
				new.swapped, new.from = true, new.replaced
				new.reason = reason_for(new, from)
			end
			for _, new in ipairs(I.react(slots, cands, G.them, G.seen, G.hero, G.bpos, locked)) do
				new.swapped, new.from = true, new.replaced
			end
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
		local steps = {}
		for _, sl in ipairs(slots) do
			if sl.pre then
				steps[#steps + 1] = { s = sl, item = sl.pre.item, t = sl.pre.t, pre = true }
			end
			steps[#steps + 1] = { s = sl, item = sl.item, t = sl.t, via = sl.pre and sl.pre.item }
			if sl.after then
				steps[#steps + 1] = { s = sl, item = sl.after.item, t = sl.after.t, base = sl.item, kind = sl.after_kind }
			end
		end
		for _, e in ipairs(base.early or {}) do
			steps[#steps + 1] = { item = e.item, t = e.t, early = e }
		end
		table.sort(steps, function(a, b)
			if a.t ~= b.t then
				return a.t < b.t
			end
			return (a.base and 1 or 0) < (b.base and 1 or 0)
		end)
		local function step_done(st)
			if st.base or st.pre or st.early then
				return owns(st.item)
			end
			return st.s.bought or owns(st.item)
		end
		local last = 0
		for i, st in ipairs(steps) do
			if step_done(st) then
				last = i
			end
		end
		local order, skipped = {}, {}
		for i, st in ipairs(steps) do
			local done = step_done(st)
			st.have = done and 0 or progress(st.item, {}, 0)
			st.signal = done and 0 or progress(st.item, {}, 0, K.SIGNAL_MIN, (st.base or st.via or {}).name)
			if not done and i < last and st.signal == 0 then
				if not st.early then
					st.skipped = true
					skipped[#skipped + 1] = st
				end
			else
				order[#order + 1] = st
			end
		end
		for _, st in ipairs(skipped) do
			order[#order + 1] = st
		end
		steps = order
		local target, target_k
		for _, st in ipairs(steps) do
			if not step_done(st) and st.signal > 0 then
				local k = st.signal / math.max(1, st.item.cost)
				if not target or k > target_k then
					target, target_k = st, k
				end
			end
		end
		if not target then
			for _, st in ipairs(steps) do
				if not target and not step_done(st) then
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
				d.state, d.have = "next", st.have
				plan.next = d
			else
				d.state = "later"
			end
			local lines = {}
			if st.early then
				lines[1] = st.early.up and L("cd_tip_upgrade"):format(st.early.up.label) or nil
			elseif st.pre then
				lines[1] = L("cd_tip_upgrade"):format(s.item.label)
			elseif st.base then
				d.base, d.kind = { name = st.base.name, label = st.base.label }, st.kind
				lines[1] = L(st.kind == "up" and "cd_tip_up_from" or "cd_tip_dis_from"):format(st.base.label)
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
				lines[#lines + 1] = I.body(s)
			end
			if st.skipped then
				lines[#lines + 1] = L("cd_tip_skipped")
			end
			d.body = table.concat(lines, "\n")
			plan.slots[i] = d
		end
		plan.complete = plan.next == nil
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
			G.match, G.seen, G.plan, G.sig, G.pos_for, G.ever = match, {}, nil, nil, nil, {}
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
						local now = {}
						for slot = 0, K.ENEMY_INV_LAST do
							local item = NPC.GetItemByIndex(e, slot)
							local name = item and item_name(item)
							if name then
								now[name] = true
								if not old[name] and (K.ENEMY_ITEMS[name] or K.ANTI[name]) then
									log("panel: %s has %s", ei.name, name)
								end
							end
						end
						for name in pairs(old) do
							if not now[name] and (K.ENEMY_ITEMS[name] or K.ANTI[name]) then
								log("panel: %s no longer has %s", ei.name, name)
							end
						end
						G.seen[ei.id] = now
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
		local okp, tp = pcall(Player.GetTeamPlayer, Players.GetLocal())
		G.gold = (okp and type(tp) == "table") and (tonumber(tp.reliable_gold) or 0) + (tonumber(tp.unreliable_gold) or 0) or 0
		if G.pos_for ~= info.id then
			G.pos, G.pos_for = my_pos(info.id), info.id
		end
		for name in pairs(owned) do
			G.ever[name] = true
		end
		G.hero, G.them, G.owned, G.live, I.want = info.id, them, owned, true, info.id
		G.bpos = I.bpos[info.id] or G.pos
		G.time = GameRules.GetDOTATime(true, true)
		local sig = { info.id, G.bpos, table.concat(them, ","), I.items_at, I.buys_at[info.id] or 0, cfg.padapt }
		local names = {}
		for name, n in pairs(owned) do
			names[#names + 1] = name .. n
		end
		for name in pairs(G.ever) do
			names[#names + 1] = "~" .. name
		end
		table.sort(names)
		sig[#sig + 1] = table.concat(names, ",")
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
				log("panel plan for %d: %d slots", info.id, #G.plan.slots)
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

local function click(right)
	local cx, cy = Input.GetCursorPos()
	local hit = hit_at(cx, cy)
	local kind, arg = hit and hit[5], hit and hit[6]
	if W.pos_menu and kind ~= "posset" and kind ~= "posbadge" and kind ~= "pmbg" then
		W.pos_menu = nil
	end
	if W.set_gear and kind ~= "set_gear" and not in_rect(W.gear_pop, cx, cy) then
		W.set_gear = nil
	end
	if not hit then
		return
	end
	if kind == "pmbg" or kind == "stgbg" then
		return
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
	elseif kind == "set_pview" then
		set_cfg("pview", arg)
	elseif kind == "set_pzoom_up" or kind == "set_pzoom_down" then
		set_cfg("pzoom", clamp(cfg.pzoom + (kind == "set_pzoom_up" and 10 or -10), 60, 160))
	elseif kind == "bpos" then
		I.bpos[arg.h] = arg.p
	elseif kind == "qbuy" then
		if not right then
			local item = I.by_name[arg.name]
			local ok, info = pcall(Player.GetQuickBuyInfo, Players.GetLocal())
			local has = false
			for _, id in ipairs(ok and type(info) == "table" and type(info.m_quickBuyItems) == "table" and info.m_quickBuyItems or {}) do
				if item and id == item.id then
					has = true
				end
			end
			if has or pcall(Engine.SetQuickBuy, arg.name, false) then
				W.qflash = { id = arg.id, t = os.clock() }
			end
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
		if W.settings then
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
		if W.gear_block and in_rect(W.gear_block, cx, cy) then
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

	local function fmt_eta(sec, short)
		if not sec then
			return nil
		end
		local key = short and "cd_eta_short_" or "cd_eta_"
		if sec < 60 then
			return L(key .. "s"):format(math.max(5, math.floor(sec / 5 + 0.5) * 5))
		end
		return L(key .. "m"):format(math.floor(sec / 60 + 0.5))
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
		matches = "cd_ld_matches",
		build = "cd_ld_build",
		wait = "cd_ld_wait",
		error = "cd_ld_error",
		slow = "cd_ld_slow",
	}

	function load_stage()
		if D.error and os.clock() < D.next_request then
			return D.error:lower():find("timeout", 1, true) and "slow" or "error"
		end
		local sets = source() == 1 and { D.sets[0], D.sets[1] } or { D.sets[0] }
		for _, S in ipairs(sets) do
			if S.job then
				return "matches"
			end
		end
		if D.status == "cd_st_heroes" then
			return "heroes"
		end
		if D.status == "cd_st_pro" then
			return "pro"
		end
		for _, S in ipairs(sets) do
			if S.build then
				return "build"
			end
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

	local function kilo(n)
		return ("%dk"):format(math.floor(n / 1000 + 0.5))
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
		if W.nohit or (W.pos_menu and id:sub(1, 2) ~= "pm") then
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
		rect(x, y, x + w, y + h, fade(P.TIP, ta), px(8))
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
		local sub, eta
		if err or stage == "slow" then
			sub = L("cd_ld_retry"):format(math.max(1, math.ceil(D.next_request - os.clock())))
		elseif stage == "matches" then
			local have, target = job_counts()
			local days = job_days()
			if days then
				sub = L("cd_ld_days"):format(kilo(have), days, K.CM_DAYS)
			else
				sub = L("cd_ld_count"):format(kilo(have), kilo(target))
			end
			eta = fmt_eta(job_eta(), false)
		end
		if sub then
			local sw = tw(W.fonts.regular, px(11), sub)
			local ew = eta and tw(W.fonts.regular, px(11), eta) + px(16) or 0
			local sx = cx - (sw + ew) / 2
			text(W.fonts.regular, px(11), sub, sx, cy + px(20), fade(P.MUTED, a))
			if eta then
				vline(sx + sw + px(8), cy + px(20), px(6), a)
				text(W.fonts.regular, px(11), eta, sx + sw + px(16), cy + px(20), fade(P.MUTED, a))
			end
		end
		if err then
			return
		end
		local bw, bh = px(180), math.max(2, px(3))
		local by = cy + px(38)
		local prog = tween("loader_p", stage == "matches" and job_progress() or (stage == "build" and 1 or 0), 0.4)
		rect(cx - bw / 2, by, cx + bw / 2, by + bh, fade(P.CELL, a * 1.6), bh / 2)
		if prog > 0 then
			rect(cx - bw / 2, by, cx - bw / 2 + bw * prog, by + bh, fade(P.GOOD, a * 0.85), bh / 2)
		end
		if not D.sets[0].stats then
			local hint = L("cd_ld_first")
			text(W.fonts.regular, px(10), hint, cx - tw(W.fonts.regular, px(10), hint) / 2, by + px(22), fade(P.DIM, a))
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
					local bh = approach("bh" .. i, (step_team(i) == 0 and hovered(x, y + h - size - px(5), x + size + px(8), y + h)) and 1 or 0, 20)
					local bg = mix(P.SHADE, P.TIP, math.max(bh, manual and 0.6 or 0))
					rect(x + px(1), y + h - size - px(3), x + size + px(5), y + h - px(1), fade(bg, pa * 0.9), px(3))
					draw_pos(pos, x + px(3), y + h - px(2) - size / 2, size, pa)
					if step_team(i) == 0 then
						badge = { x, y + h - size - px(5), x + size + px(8), y + h }
					end
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
		rect(x, y, x + w, y + h, fade(P.TIP, ma), px(8))
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
			local str = stage == "matches" and L("cd_ld_short"):format(math.floor(job_progress() * 100))
				or L(STAGE_TEXT[stage] or "cd_ld_wait")
			local sx = left + px(18) + text(W.fonts.regular, px(11), str, left + px(18), cy, fade(P.MUTED, a * ba))
			if (stage == "error" or stage == "slow") and D.error then
				tip("err", left, cy - px(10), sx, cy + px(10), L("cd_tip_err_t"), D.error:sub(1, 80))
			end
			local eta = stage == "matches" and fmt_eta(job_eta(), true)
			if eta then
				vline(sx + px(8), cy, px(6), a * ba)
				sx = sx + px(16) + text(W.fonts.regular, px(11), eta, sx + px(16), cy, fade(P.MUTED, a * ba))
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

	local function draw_free(x, y, w, h, a)
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
			local n = #CM.recs
			local days = CM.oldest and math.max(1, math.floor((os.time() - CM.oldest) / 86400 + 0.5)) or nil
			local rate = (days and n > 0) and n / days or nil
			local l1 = C.y + px(12)
			local l2 = C.y + px(29)
			glyph("\u{f05a}", left + px(7), l1, px(10), fade(P.MUTED, na))
			local tx = left + px(22)
			if n == 0 or not days then
				text(W.fonts.regular, px(11), L("cd_cm_wait"), tx, l1, fade(P.MUTED, na))
			elseif CM.exhausted then
				text(W.fonts.regular, px(11), L("cd_cm_done"):format(fmt_games(n), math.min(days, K.CM_DAYS)), tx, l1, fade(P.MUTED, na))
			else
				local lx = tx + text(W.fonts.regular, px(11), L("cd_cm_now"):format(fmt_games(n), math.min(days, K.CM_DAYS), K.CM_DAYS), tx, l1, fade(P.MUTED, na)) + px(8)
				if rate and days < K.CM_DAYS then
					vline(lx, l1, px(6), na)
					text(W.fonts.regular, px(11), L("cd_cm_total"):format(fmt_games(math.min(K.CM_MAX, math.floor(rate * K.CM_DAYS)))), lx + px(8), l1, fade(P.MUTED, na))
				end
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

		local tx
		cy, tx = row(C, "\u{f1da}", nil, "info")
		local S = D.sets[source()]
		local parts = {}
		if S.stats then
			parts[#parts + 1] = L("cd_matches"):format(fmt_games(S.stats.n))
		end
		parts[#parts + 1] = S.job and L("cd_upd_loading") or fmt_updated(S.updated)
		local lx = tx
		for n, part in ipairs(parts) do
			if n > 1 then
				vline(lx, cy, px(6), a)
				lx = lx + px(8)
			end
			lx = lx + text(W.fonts.regular, px(11), part, lx, cy, fade(P.MUTED, a)) + px(8)
		end
		local label = L("cd_set_refresh")
		local bw = tw(W.fonts.medium, px(11), label) + px(32)
		local bh = px(22)
		local busy = any_busy()
		local rb = approach("st_refresh", (not busy and not covered and hovered(right - bw, cy - bh / 2, right, cy + bh / 2)) and 1 or 0, 20)
		local ba = a * (busy and 0.45 or 1)
		rect(right - bw, cy - bh / 2, right, cy + bh / 2, fade(mix(P.CELL, P.HOVER, rb), ba), px(6))
		glyph("\u{f021}", right - bw + px(13), cy, px(10), fade(P.MUTED, ba))
		text(W.fonts.medium, px(11), label, right - bw + px(23), cy, fade(P.TEXT, ba))
		if not busy then
			hit(right - bw, cy - bh / 2, right, cy + bh / 2, "set_refresh")
		end

		section(C, "cd_sec_view")
		cy = row(C, "\u{f2d0}", L("cd_set_window"), "win")
		gear(C, "window", cy)
		hit(C.x0, cy - row_h / 2, C.r - px(24), cy + row_h / 2, "set_gear", "window")
		cy = row(C, "\u{f290}", L("cd_set_panel"), "panel")
		local gs = gear(C, "panel", cy)
		mini_switch("panel", C.r - gs - px(8), cy, a)
		hit(C.x0, cy - row_h / 2, C.r - gs - px(4), cy + row_h / 2, "set_toggle", "panel")
		if cfg.panel == 1 then
			cy = row(C, "\u{f06e}", L("cd_set_preview"), "preview")
			local plabel = W.preview and L("cd_preview_hide") or L("cd_preview_show")
			local pbw = tw(W.fonts.medium, px(11), plabel) + px(24)
			local pbh = px(22)
			local pon = W.preview == true
			local pbx0 = C.r - pbw
			local phv = approach("st_prev", (not covered and hovered(C.x0, cy - row_h / 2, C.x1, cy + row_h / 2)) and 1 or 0, 20)
			rect(pbx0, cy - pbh / 2, C.r, cy + pbh / 2, fade(pon and P.CHIP_ON or mix(P.CELL, P.HOVER, phv), a), px(6))
			text(W.fonts.medium, px(11), plabel, pbx0 + px(12), cy, fade(P.TEXT, a))
			hit(C.x0, cy - row_h / 2, C.x1, cy + row_h / 2, "set_preview")
			tip("st_prev", pbx0, cy - pbh / 2, C.r, cy + pbh / 2, L("cd_set_preview"), L("cd_tip_preview"))
		end
		toggle(C, "\u{f52b}", "auto", L("cd_set_auto"), "auto")
		toggle(C, "\u{f188}", "debug", L("cd_set_debug"), "debug")

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
		local rows = g == "window" and 4 or 5
		local pw = px(280)
		local ph = px(40) + rows * row_h + px(6)
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
		local title_icon = g == "window" and "\u{f2d0}" or "\u{f290}"
		glyph(title_icon, px0 + px(19), py + px(17), px(11), fade(P.MUTED, ga))
		text(W.fonts.semi, px(11), g == "window" and L("cd_set_window") or L("cd_set_panel"), px0 + px(34), py + px(17), fade(P.MUTED, ga))
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
			seg(Q, "st_pview", { L("cd_pview0"), L("cd_pview1"), L("cd_pview2") }, cfg.pview, "set_pview", cy)
			cy = row(Q, "\u{f065}", L("cd_set_scale"), "g_pzoom")
			stepper(Q, cy, cfg.pzoom, "set_pzoom_up", "set_pzoom_down", "st_pz")
			toggle(Q, "\u{f54e}", "pshop", L("cd_set_pshop"), "g_pshop")
			toggle(Q, "\u{f3ed}", "padapt", L("cd_set_padapt"), "g_padapt")
			toggle(Q, "\u{f070}", "phide", L("cd_set_phide"), "g_phide")
		end
		W.nohit = nohit
	end

	local function draw_timeline(x, y, w, h, a)
		if draft.mode == 1 then
			draw_free(x, y, w, h, a)
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
		local img = image("panorama/images/items/" .. name .. "_png.vtex_c")
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
		local have = I.positions(h)
		local loaded = I.buys[h] ~= nil
		local pos = I.bpos[h] or auto_pos
		local x = right - 5 * size - 4 * gap
		for k = 1, 5 do
			local bx = x + (k - 1) * (size + gap)
			local on = pos == k
			local avail = not loaded or have[k] ~= nil
			local hv = approach("sbp" .. k, hovered(bx, cy - size / 2, bx + size, cy + size / 2) and 1 or 0, 20)
			rect(bx, cy - size / 2, bx + size, cy + size / 2, fade(on and P.CHIP_ON or mix(P.CELL, P.HOVER, hv), a), px(6))
			draw_pos(k, bx + (size - px(14)) / 2, cy, px(14), a * ((avail or on) and 1 or 0.35))
			hit(bx, cy - size / 2, bx + size, cy + size / 2, "bpos", { h = h, p = k })
			local body = have[k] and L("cd_tip_bpos"):format(have[k]) or (avail and "" or L("cd_tip_bpos_none"))
			tip("sbpt" .. k, bx, cy - size / 2, bx + size, cy + size / 2, L("cd_posT" .. k), body, k)
		end
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
				tip("item_err", left, by - px(10), tx + mw, by + px(10), L("cd_tip_err_t"), I.error:sub(1, 80))
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
				local img = image("panorama/images/items/" .. src_item.name .. "_png.vtex_c")
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

	local function draw_list_view(x, y, w, h, a)
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
		gold = 1300,
		pos = 1,
		slots = {
			{ name = "power_treads", label = "Power Treads", state = "done", t = 346, cost = 1400 },
			{ name = "mask_of_madness", label = "Mask of Madness", state = "done", t = 608, cost = 1900 },
			{ name = "manta", label = "Manta Style", state = "next", t = 1028, cost = 4650, have = 2100 },
			{ name = "black_king_bar", label = "Black King Bar", state = "later", t = 1559, cost = 4050 },
			{ name = "butterfly", label = "Butterfly", state = "later", t = 1598, cost = 5450 },
			{ name = "monkey_king_bar", label = "Monkey King Bar", state = "later", t = 1880, cost = 5000,
				reason = 44, counter = { "Phantom Assassin", "evasion" } },
			{ name = "satanic", label = "Satanic", state = "later", t = 2084, cost = 5050,
				base = { name = "mask_of_madness", label = "Mask of Madness" }, kind = "dis" },
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

	function PN.item_img(name)
		return image("panorama/images/items/" .. name .. "_png.vtex_c")
	end

	function PN.slot(d, x, y, w, h, a)
		local img = PN.item_img(d.name)
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
			local src = PN.item_img(d.base.name)
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

	function PN.need(plan, d)
		local gold = plan == PN.DEMO and PN.DEMO.gold or G.gold
		local need = math.max(0, (d.cost or 0) - (d.have or 0))
		local k = tween("pn_prog", (d.cost or 0) > 0 and ((d.have or 0) + math.min(gold, need)) / d.cost or 0, 0.4)
		if gold >= need then
			return L("cd_p_enough"), P.GOOD, k
		end
		return L("cd_p_more"):format(need - gold), P.MUTED, k
	end

	function PN.bar(x0, x1, cy, k, a)
		local bh = math.max(2, px(3))
		local y0 = math.floor(cy - bh / 2)
		rect(x0, y0, x1, y0 + bh, fade(Color(255, 255, 255, 26), a), bh / 2)
		if k > 0 then
			rect(x0, y0, x0 + (x1 - x0) * clamp(k, 0, 1), y0 + bh, fade(P.GOOD, a), bh / 2)
		end
	end

	function PN.back(x, y, w, h, a)
		if cfg.blur == 1 then
			local strength = clamp((a - 0.5) / 0.5, 0, 1)
			if strength > 0.01 then
				Render.Blur(Vec2(x, y), Vec2(x + w, y + h), strength, 1.0, px(10), K.ROUND)
			end
		end
		rect(x, y, x + w, y + h, fade(Color(P.BG.r, P.BG.g, P.BG.b, math.floor(255 * cfg.bg / 100 + 0.5)), a), px(10))
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
		if plan == PN.DEMO or plan == PN.NONE then
			local tag = L("cd_p_preview")
			text(W.fonts.regular, px(10), tag, x + w - px(12) - tw(W.fonts.regular, px(10), tag), hy, fade(P.DIM, a))
		end
		hit(x, y, x + w, y + px(34), "pdrag")
	end

	function PN.roles_w(size)
		return 5 * size + 4 * px(4)
	end

	function PN.roles(plan, x, cy, size, a)
		local gap = px(4)
		local hero = plan.hero
		local demo = plan == PN.DEMO or plan == PN.NONE
		local have = demo and not I.buys[hero] and { [1] = 400 } or I.positions(hero)
		local loaded = demo or I.buys[hero] ~= nil
		for p = 1, 5 do
			local bx = x + (p - 1) * (size + gap)
			local on = plan.pos == p
			local avail = not loaded or have[p] ~= nil
			local hv = approach("pr" .. p, hovered(bx, cy - size / 2, bx + size, cy + size / 2) and 1 or 0, 20)
			rect(bx, cy - size / 2, bx + size, cy + size / 2, fade(on and P.CHIP_ON or mix(P.CELL, P.HOVER, hv), a), px(6))
			local icon = math.floor(size * 0.64 + 0.5)
			draw_pos(p, bx + (size - icon) / 2, cy, icon, a * ((avail or on) and 1 or 0.35))
			hit(bx, cy - size / 2, bx + size, cy + size / 2, "bpos", { h = hero, p = p })
			local body = have[p] and L("cd_tip_bpos"):format(have[p]) or (avail and "" or L("cd_tip_bpos_none"))
			tip("pr" .. p, bx, cy - size / 2, bx + size, cy + size / 2, L("cd_posT" .. p), body, p)
		end
		return PN.roles_w(size)
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
		PN.back(x, y, w, h, a)
		PN.head(plan, x, y, w, a)
		local pl = plan.pos and L("cd_acc" .. plan.pos) or "?"
		text(W.fonts.medium, px(12), L("cd_build_nopos"):format(pl), x + px(12), y + px(46), fade(P.TEXT, a))
		text(W.fonts.regular, px(10), L("cd_build_nopos2"), x + px(12), y + px(64), fade(P.DIM, a))
		PN.roles(plan, x + px(12), y + h - px(22), px(24), a)
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
		local has_start = plan.start ~= nil
		local top = y + px(34) + (has_start and px(30) or 0)
		local h = top - y + sh + px(26) + px(36)
		if measure then
			return w, h
		end
		PN.back(x, y, w, h, a)
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
		local ny = sy + sh + px(15)
		local d = plan.next
		if d then
			local lx = x + pad + text(W.fonts.medium, px(11), d.label, x + pad, ny, fade(P.TEXT, a)) + px(10)
			local str, col, k = PN.need(plan, d)
			local rw = tw(W.fonts.regular, px(11), str)
			text(W.fonts.regular, px(11), str, x + w - pad - rw, ny, fade(col, a))
			PN.bar(lx, x + w - pad - rw - px(10), ny, k, a)
		else
			text(W.fonts.medium, px(11), L("cd_p_all"), x + pad, ny, fade(P.MUTED, a))
		end
		PN.roles(plan, x + pad, y + h - px(20), px(24), a)
	end

	function PN.list(plan, x, y, a, measure)
		local w = px(286)
		local row_h = px(38)
		local has_start = plan.start ~= nil
		local top = y + px(34) + (has_start and px(30) or 0)
		local h = top - y + #plan.slots * row_h + px(40)
		if measure then
			return w, h
		end
		PN.back(x, y, w, h, a)
		PN.head(plan, x, y, w, a)
		if has_start then
			PN.start(plan, x + px(12), y + px(48), w - px(24), a)
		end
		local iw, ih = px(40), px(29)
		for i, d in ipairs(plan.slots) do
			local ry = top + (i - 1) * row_h
			local rcy = ry + math.floor(row_h / 2)
			if d.state == "next" then
				rect(x + px(6), ry + px(1), x + w - px(6), ry + row_h - px(1), fade(Color(255, 255, 255, 14), a), px(7))
			end
			PN.qbuy(plan, "l" .. i, d.name, x + px(6), ry + px(1), x + w - px(6), ry + row_h - px(1), a, px(7))
			local ix = x + px(12)
			PN.slot(d, ix, math.floor(rcy - ih / 2), iw, ih, a)
			local tx = ix + iw + px(10)
			local rx = x + w - px(14)
			text(W.fonts.semi, px(12), d.label, tx, rcy - px(7), fade(P.TEXT, a))
			local sy = rcy + px(8)
			if d.state == "next" then
				local str, col, k = PN.need(plan, d)
				local rw = tw(W.fonts.semi, px(11), str)
				text(W.fonts.semi, px(11), str, rx - rw, rcy, fade(col, a))
				PN.bar(tx, rx - rw - px(10), sy + px(1), k, a)
			elseif d.from then
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
			tip("pl" .. i, x, ry, x + w, ry + row_h, d.label, d.body or "")
		end
		PN.roles(plan, x + px(12), y + h - px(20), px(24), a)
	end

	function PN.pill(plan, x, y, a, measure)
		local iw, ih = px(38), px(28)
		local d = plan.next
		local queue = {}
		for _, sl in ipairs(plan.slots) do
			if sl.state == "later" and #queue < K.PILL_QUEUE then
				queue[#queue + 1] = sl
			end
		end
		local name = d and d.label or L("cd_p_all")
		local str, col, k = "", P.MUTED, nil
		if d then
			str, col, k = PN.need(plan, d)
		end
		local nw = tw(W.fonts.bold, px(12), name)
		local body_w = math.max(px(110), nw + px(8) + tw(W.fonts.regular, px(11), str))
		local qw, qh, qg = px(31), px(23), px(8)
		local queue_w = #queue > 0 and px(18) + #queue * (qw + qg) - qg or 0
		local size = px(20)
		local roles_w = PN.roles_w(size)
		local start_n = plan.start and #plan.start.items or 0
		local start_w = start_n > 0 and start_n * (px(22) + px(3)) - px(3) or 0
		local row1 = px(6) + iw + px(9) + body_w + queue_w + px(12)
		local row2 = px(12) + start_w + (start_w > 0 and px(16) or 0) + roles_w + px(12)
		local w = math.max(row1, row2)
		local h = px(40) + px(30)
		if measure then
			return w, h
		end
		PN.back(x, y, w, h, a)
		hit(x, y, x + w, y + px(40), "pdrag")
		local cy = y + px(20)
		local ix = x + px(6)
		if d then
			PN.slot(d, ix, cy - math.floor(ih / 2), iw, ih, a)
			PN.qbuy(plan, "pp", d.name, ix, cy - math.floor(ih / 2), ix + iw, cy - math.floor(ih / 2) + ih, a)
			tip("pp", ix, cy - ih / 2, ix + iw, cy + ih / 2, d.label, d.body or "")
		else
			local face = mini(plan.hero)
			if face then
				Render.Image(face, Vec2(ix + (iw - ih) / 2, cy - ih / 2), Vec2(ih, ih), fade(P.WHITE, a))
			end
		end
		local tx = ix + iw + px(9)
		local ty = k and cy - px(5) or cy
		text(W.fonts.bold, px(12), name, tx, ty, fade(d and P.TEXT or P.MUTED, a))
		if str ~= "" then
			text(W.fonts.regular, px(11), str, tx + nw + px(8), ty, fade(col, a))
		end
		if k then
			PN.bar(tx, tx + body_w, cy + px(9), k, a)
		end
		if #queue > 0 then
			local qx = tx + body_w + px(9)
			vline(qx, cy, px(7), a)
			qx = qx + px(9)
			for i, sl in ipairs(queue) do
				PN.slot(sl, qx, cy - math.floor(qh / 2), qw, qh, a)
				PN.qbuy(plan, "pq" .. i, sl.name, qx, cy - math.floor(qh / 2), qx + qw, cy - math.floor(qh / 2) + qh, a)
				tip("pq" .. i, qx, cy - qh / 2, qx + qw, cy + qh / 2, sl.label, sl.body or "")
				qx = qx + qw + qg
			end
		end
		rect(x + px(10), y + px(40), x + w - px(10), y + px(40) + math.max(1, px(1)), fade(P.LINE, a))
		local cy2 = y + px(55)
		local sx = x + px(12)
		if start_n > 0 then
			local sh = px(16)
			for i, it in ipairs(plan.start.items) do
				PN.slot(it, sx, cy2 - sh / 2, px(22), sh, a)
				PN.qbuy(plan, "ps" .. i, it.name, sx, cy2 - sh / 2, sx + px(22), cy2 + sh / 2, a)
				tip("pst" .. i, sx, cy2 - sh / 2, sx + px(22), cy2 + sh / 2, it.title or it.label, "")
				sx = sx + px(25)
			end
		end
		PN.roles(plan, x + w - px(12) - roles_w, cy2, size, a)
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
			and (preview or (G.live and shop and not (cfg.phide == 1 and plan.complete)))
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
		local menu_scale = Menu.Scale()
		s = cfg.pzoom / 100 * K.BASE_ZOOM * ((menu_scale >= 50 and menu_scale <= 300) and menu_scale / 100 or 1)
		local draw = plan.none and PN.none or ({ PN.strip, PN.list, PN.pill })[cfg.pview + 1] or PN.strip
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
		W.pm_rect, W.gear_block = nil, nil
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
		local menu_scale = Menu.Scale()
		s = cfg.zoom / 100 * K.BASE_ZOOM * ((menu_scale >= 50 and menu_scale <= 300) and menu_scale / 100 or 1)
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
		W.ox, W.oy = x, y
		local r = px(K.RADIUS)
		local p0, p1 = Vec2(x, y), Vec2(x + w, y + h)
		if cfg.blur == 1 then
			local strength = clamp((a - 0.5) / 0.5, 0, 1)
			if strength > 0.01 then
				Render.Blur(p0, p1, strength, 1.0, r, K.ROUND)
			end
		end
		local bg = Color(P.BG.r, P.BG.g, P.BG.b, math.floor(255 * cfg.bg / 100 + 0.5))
		Render.FilledRect(p0, p1, fade(bg, a), r, K.ROUND)

		draw_header(x, y, w, a)
		local my = y + px(K.HEAD_H)
		local line = math.max(1, px(1))
		rect(x, my, x + w, my + line, fade(P.LINE, a))
		local tl_w, grid_w, main_h = px(K.TL_W), px(K.GRID_W), px(K.MAIN_H)
		draw_timeline(x, my, tl_w, main_h, a)
		rect(x + tl_w, my, x + tl_w + line, y + h, fade(P.LINE, a))
		draw_grid(x + tl_w, my, grid_w, main_h, a)
		rect(x + tl_w + grid_w, my, x + tl_w + grid_w + line, y + h, fade(P.LINE, a))
		draw_list(x + tl_w + grid_w, my, w - tl_w - grid_w, main_h, a)
		draw_pos_menu(a)
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
	local ok, err = pcall(poll_keys)
	if not ok and tostring(err) ~= W.poll_error then
		W.poll_error = tostring(err)
		Log.Write("[Draft Helper] keys: " .. W.poll_error)
	end
	ok, err = pcall(data_tick)
	if not ok and tostring(err) ~= D.tick_error then
		D.tick_error = tostring(err)
		Log.Write("[Draft Helper] data: " .. D.tick_error)
	end
	ok, err = pcall(U.tick)
	if not ok and tostring(err) ~= W.upd_error then
		W.upd_error = tostring(err)
		Log.Write("[Draft Helper] updater: " .. W.upd_error)
	end
	ok, err = pcall(I.tick)
	if not ok and tostring(err) ~= I.tick_error then
		I.tick_error = tostring(err)
		Log.Write("[Draft Helper] items: " .. I.tick_error)
	end
	ok, err = pcall(G.tick)
	if not ok and tostring(err) ~= G.tick_error then
		G.tick_error = tostring(err)
		Log.Write("[Draft Helper] panel: " .. G.tick_error)
	end
	ok, err = pcall(sync_free)
	if not ok and tostring(err) ~= D.sync_error then
		D.sync_error = tostring(err)
		Log.Write("[Draft Helper] sync: " .. D.sync_error)
	end
	ok, err = pcall(check_match)
	if not ok and tostring(err) ~= D.match_error then
		D.match_error = tostring(err)
		Log.Write("[Draft Helper] match: " .. D.match_error)
	end
end

function script.OnFrame()
	local ok, err = pcall(draw_window)
	if not ok and tostring(err) ~= W.draw_error then
		W.draw_error = tostring(err)
		Log.Write("[Draft Helper] draw: " .. W.draw_error)
	end
	ok, err = pcall(draw_panel)
	if not ok and tostring(err) ~= W.panel_error then
		W.panel_error = tostring(err)
		Log.Write("[Draft Helper] panel draw: " .. W.panel_error)
	end
	ok, err = pcall(draw_tips)
	if not ok and tostring(err) ~= W.tip_error then
		W.tip_error = tostring(err)
		Log.Write("[Draft Helper] tips: " .. W.tip_error)
	end
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

function script.OnPrepareUnitOrders()
	if os.clock() - W.click_at < K.CLICK_GUARD and cursor_in_window() then
		return false
	end
	return true
end

return script
