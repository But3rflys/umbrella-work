# Меню по эталону

Все имена ниже, кроме имен вкладок, это ключи локализации (см. localization.md). Меню создается через обертку `UI = localization.WrapLibrary(Menu)`.

## Дерево

```
UI.Create("Scripts", "Scripts", "<Имя>")   CSecondTab: строка скрипта в списке, ставим :Icon
  tab:Create("Settings")                   CThirdTab: страница, у простого скрипта одна
    page:Create("<p>_group_main", Enum.GroupSide.Left)    CMenuGroup: левая колонка
    page:Create("<p>_group_way",  Enum.GroupSide.Right)   CMenuGroup: правая колонка
```

- Место по умолчанию `"Scripts", "Scripts", "<Имя>"`. Другое место (вкладку встроенных функций, например `"Creeps", "Main"`) бери, только если пользователь его назвал.
- Имена вкладок пишутся обычным текстом на английском, без перевода: у вкладок нет `ForceLocalization`, а путь из имен вкладок служит ключом настроек. Группы и все пункты задаются ключами.
- Группы идут в две колонки: слева основное (включение, клавиша, выбор цели), справа поведение и тонкая настройка. Отладку и оформление убирай в шестеренку. Пустую группу не оставляй.

## Эталон

```lua
local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Lane Pull")
	tab:Icon("\u{f4d7}")

	local page = tab:Create("Settings")
	local g_main = page:Create("lp_group_main", Enum.GroupSide.Left)
	local g_way = page:Create("lp_group_way", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("lp_enable", false, "\u{f011}")
	ui.enable:ToolTip("lp_enable_tip")
	local g_extra = ui.enable:Gear("lp_gear_extra")
	ui.debug = g_extra:Switch("lp_debug", false, "\u{f188}")
	ui.debug:ToolTip("lp_debug_tip")

	ui.key = g_main:Bind("lp_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("lp_key_tip")

	ui.pick = g_main:Combo("lp_pick", { "lp_picks_hero", "lp_picks_puller", "lp_picks_cursor" }, 0)
	ui.pick:Icon("\u{f05b}")
	ui.pick:ToolTip("lp_pick_tip")

	ui.panel = g_main:Switch("lp_panel", true, "\u{f05a}")
	local g_look = ui.panel:Gear("lp_gear_panel")
	ui.panel_scale = g_look:Slider("lp_panel_scale", 80, 160, 100, "%d%%")
	ui.panel_scale:Icon("\u{f065}")
	ui.panel_y = g_look:Slider("lp_panel_y", 0, 600, 70, "%d px")
	ui.panel_y:Icon("\u{f338}")

	ui.gap = g_way:Slider("lp_gap", 250, 700, 400, "%d")
	ui.gap:Icon("\u{f337}")
	ui.gap:ToolTip("lp_gap_tip")

	ui.avoid = g_way:Switch("lp_avoid", true, "\u{f70c}")
	local g_avoid = ui.avoid:Gear("lp_gear_avoid")
	ui.avoid_radius = g_avoid:Slider("lp_avoid_radius", 500, 1600, 900, "%d")
	ui.avoid_radius:Icon("\u{f1ce}")

	ui.key:Properties(localization.Get("lp_bind_name"))
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.key:Disabled(not on)
	ui.pick:Disabled(not on)
	ui.panel:Disabled(not on)
	ui.gap:Disabled(not on)
	ui.avoid:Disabled(not on)
	ui.avoid_radius:Disabled(not on or not ui.avoid:Get())
	ui.debug:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)
ui.avoid:SetCallback(refresh_disabled)
```

Порядок в группе: главный переключатель, клавиша, выборы режима, затем числа. Подсказку (`:ToolTip`) даем всему, что не очевидно по названию.

## Шестеренка (Gear)

`widget:Gear(key, [glyph = "\u{f013}"], [smallFont = true])` возвращает `CMenuGearAttachment`: всплывающую панель у пункта. В ней те же конструкторы, что у группы: `Switch`, `Bind`, `Slider`, `ColorPicker`, `Button`, `Combo`, `MultiCombo`, `MultiSelect`, `Input`, `Label`. Ключ шестеренки переводится и становится заголовком панели.

Шестеренку можно повесить на `Switch`, `Bind`, `Slider`, `Combo`, `MultiCombo`, `Input`, `Label`. На `Button`, `ColorPicker` и `MultiSelect` ее нет. В шестеренку уходит то, что настраивают один раз: оформление, отладка, точные пороги. Главные настройки остаются в группе.

Цвет у пункта: `widget:ColorPicker(key, Color(r, g, b, a))` вешает квадрат цвета справа, `:Get()` возвращает `Color`.

## Конструкторы и иконки

| Виджет | Создание | Иконка |
| --- | --- | --- |
| Переключатель | `g:Switch(key, default, glyph)` | 3-й аргумент |
| Клавиша | `g:Bind(key, Enum.ButtonCode.KEY_NONE, glyph)` | 3-й аргумент |
| Число | `g:Slider(key, min, max, default, "%d")`. Если все три числа дробные, получится float-слайдер (`"%.2f"`) | `:Icon(glyph)` |
| Выбор | `g:Combo(key, { key1, key2 }, 0)`, `:Get()` отдает индекс с 0 | `:Icon(glyph)` |
| Несколько галочек | `g:MultiCombo(key, { id1, id2 }, { id1 })` | `:Icon(glyph)` |
| Список с картинками | `g:MultiSelect(key, { { id, image_path, enabled } }, expanded)` | `:Icon(glyph)` |
| Цвет | `g:ColorPicker(key, Color(...), glyph)` | 3-й аргумент |
| Поле ввода | `g:Input(key, "", glyph)` | 3-й аргумент |
| Кнопка | `g:Button(key, function(this) end)` | `:Icon(glyph)` |
| Надпись | `g:Label(key, glyph)` | 2-й аргумент |

Формат слайдера: `"%d"`, `"%d%%"`, `"%d px"`, `"%.1f s"`, либо функция `function(v) return ... end`.

Часть названия пункта можно подсветить цветом темы меню: `"Render in OnDraw \a{primary}fps drop"`. Метка ставится прямо в текст перевода.

Иконка всегда нужна и подбирается по смыслу пункта. Это глиф FontAwesome `"\u{f...}"`. Картинки из игры (`panorama/...`) ставь только в `MultiSelect`, там они подписывают юнитов, героев и предметы.

| Глиф | Смысл | Глиф | Смысл |
| --- | --- | --- | --- |
| f011 | вкл/выкл | f11c | клавиша |
| f188 | отладка | f05a | инфо, панель статуса |
| f05b | цель, выбор | f3c5 | место на карте |
| f4d7 | маршрут, линия | f447 | вышка |
| f1bb | деревья | f004 | здоровье |
| f70c | избегать, бег | f1ce | радиус |
| f337 | горизонталь, дистанция | f338 | вертикаль, отступ |
| f065 | размер | f043 | прозрачность |
| f042 | размытие, контраст | f03e | картинка, иконка |
| f11b | матч, игра | f11e | финиш, итог |
| f013 | настройки | f1de | тонкая настройка |
| f06e | видимость | f0f3 | уведомления |
| f53f | цвет | f001 | музыка |
| f036 | текст | f144 | воспроизведение |

## Зависимости пунктов

- `:Disabled(true)` гасит пункт, но оставляет его видимым. Так делаем все пункты при выключенном главном переключателе и дочерние при выключенном родителе.
- `:Visible(false)` прячет пункт, когда он при текущем выборе не имеет смысла: например, ширина капсулы нужна только в режиме «Отдельная капсула».
- Обновление одной функцией и `SetCallback(fn, true)`: второй аргумент `true` сразу вызывает ее, и состояние верно с самого старта.

```lua
ui.lyr_where:SetCallback(function(w) ui.lyr_width:Visible(w:Get() == 0) end, true)
```

## Клавиша

```lua
ui.key:Properties(localization.Get("<p>_bind_name"))

function script.OnUpdate()
	if not ui.enable:Get() then return end
	if ui.key:IsPressed() and not Input.IsInputCaptured() then
		...
	end
end
```

`IsPressed` срабатывает один раз на нажатие, `IsDown` держится, пока клавиша зажата, `IsToggled` дает переключатель вкл/выкл. `Input.IsInputCaptured()` истинно, пока открыт чат или консоль, и тогда нажатие игнорируем. `Properties` задает имя в списке биндов, туда передаем уже переведенную строку.

## MultiSelect

```lua
local UNITS = {
	{ id = "Dominator creep", icon = "panorama/images/items/helm_of_the_dominator_png.vtex_c", on = true },
	{ id = "Spirit Bear", icon = "panorama/images/spellicons/lone_druid_spirit_bear_png.vtex_c", on = true },
}
local items = {}
for i, u in ipairs(UNITS) do items[i] = { u.id, u.icon, u.on } end
ui.units = g_main:MultiSelect("<p>_units", items, true)
ui.units:DragAllowed(true)
```

`id` в пунктах это постоянные английские строки, а не ключи: по ним сохраняются галочки. `:Get(id)` показывает, включен ли пункт, `:ListEnabled()` возвращает включенные по порядку. При `DragAllowed(true)` порядок задает сам пользователь, и его можно считать приоритетом.

## Чтение значений

Значения читай в колбэке (`ui.x:Get()`). Если пунктов много и они нужны каждый кадр, собери их в таблицу одной функцией `read_menu()` в начале `OnUpdate`/`OnFrame`.
