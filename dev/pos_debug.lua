local tab = Menu.Create("Scripts", "Scripts", "pos_probe")
tab:Icon("\u{f120}")
local page = tab:Create("cfg")
local g_main = page:Create("core", Enum.GroupSide.Left)
local g_look = page:Create("ovl", Enum.GroupSide.Right)

local points = {}
local font = nil

local ui = {}
ui.enable = g_main:Switch("dbg_on", true)
ui.key = g_main:Bind("capture", Enum.ButtonCode.KEY_NONE)
ui.source = g_main:Combo("src_sel", { "self_org", "cursor_ray" }, 0)
g_main:Button("flush_buf", function()
	points = {}
	Log.Write("[pos] buf flushed")
end)

ui.path = g_look:Switch("node_ov", true)
ui.hero_text = g_look:Switch("org_ov", true)

local COLORS = {
	text = Color(235, 235, 235, 255),
	dim = Color(170, 170, 180, 255),
	point = Color(255, 205, 80, 255),
	line = Color(255, 205, 80, 150),
}

local function coords(p)
	return string.format("%.0f, %.0f, %.0f", p:GetX(), p:GetY(), p:GetZ())
end

local function source_pos()
	if ui.source:Get() == 1 then return Input.GetWorldCursorPos() end
	local hero = Heroes.GetLocal()
	return hero and Entity.GetAbsOrigin(hero) or nil
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() or not ui.key:IsPressed() then return end
	local p = source_pos()
	if not p then return end
	points[#points + 1] = p:Clone()
	Log.Write(string.format("[pos] %d { %s },", #points, coords(p)))
end

function script.OnDraw()
	if not ui.enable:Get() then return end
	if not font then
		font = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
	end

	local hero = Heroes.GetLocal()
	local hero_pos = hero and Entity.GetAbsOrigin(hero) or nil
	local cursor = Input.GetWorldCursorPos()
	local y = 340
	if hero_pos then
		Render.Text(font, 15, "org " .. coords(hero_pos), Vec2(40, y), COLORS.text)
		y = y + 18
	end
	if cursor then
		Render.Text(font, 14, "cur " .. coords(cursor), Vec2(40, y), COLORS.dim)
		y = y + 18
	end
	Render.Text(font, 14, "buf " .. #points, Vec2(40, y), COLORS.dim)

	if hero_pos and ui.hero_text:Get() then
		local s, visible = Render.WorldToScreen(hero_pos)
		if visible then
			Render.Text(font, 13, coords(hero_pos), Vec2(s.x - 60, s.y + 20), COLORS.text)
		end
	end

	if not ui.path:Get() then return end
	local prev_s, prev_v = nil, false
	for i = 1, #points do
		local s, visible = Render.WorldToScreen(points[i])
		if visible then
			Render.Circle(s, 6, COLORS.point, 2)
			Render.Text(font, 13, tostring(i), Vec2(s.x + 8, s.y - 8), COLORS.point)
			if prev_s and prev_v then Render.Line(prev_s, s, COLORS.line, 1.5) end
		end
		prev_s, prev_v = s, visible
	end
end

function script.OnGameEnd()
	points = {}
end

return script
