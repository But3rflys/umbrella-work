local localization = qLocalization.new({
	en = {
		__P___group_main = "Main",
		__P___group_extra = "Behavior",
		__P___enable = "Enable",
		__P___enable_tip = "Turns the script on",
		__P___gear_extra = "Extra",
		__P___debug = "Debug log",
		__P___debug_tip = "Writes what the script is doing\nto the log",
		__P___key = "Key",
		__P___key_tip = "Press to run the action",
		__P___bind_name = "__TITLE__",
	},
	ru = {
		__P___group_main = "Основное",
		__P___group_extra = "Поведение",
		__P___enable = "Включить",
		__P___enable_tip = "Включает скрипт",
		__P___gear_extra = "Дополнительно",
		__P___debug = "Отладка в лог",
		__P___debug_tip = "Пишет в лог, что сейчас делает скрипт",
		__P___key = "Клавиша",
		__P___key_tip = "Нажми, чтобы запустить действие",
		__P___bind_name = "__TITLE__",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "__TITLE__")
	tab:Icon("\u{f013}")

	local page = tab:Create("Settings")
	local g_main = page:Create("__P___group_main", Enum.GroupSide.Left)
	local g_extra = page:Create("__P___group_extra", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("__P___enable", false, "\u{f011}")
	ui.enable:ToolTip("__P___enable_tip")
	local g_gear = ui.enable:Gear("__P___gear_extra")
	ui.debug = g_gear:Switch("__P___debug", false, "\u{f188}")
	ui.debug:ToolTip("__P___debug_tip")

	ui.key = g_main:Bind("__P___key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("__P___key_tip")
	ui.key:Properties(L("__P___bind_name"))
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.key:Disabled(not on)
	ui.debug:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)

local function log(text)
	if ui.debug:Get() then
		Log.Write("[__TITLE__] " .. text)
	end
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then return end
	if ui.key:IsPressed() and not Input.IsInputCaptured() then
		log("key pressed")
	end
end

return script
