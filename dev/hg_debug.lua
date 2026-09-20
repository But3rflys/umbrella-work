local tab = Menu.Create("Scripts", "Scripts", "hg_probe")
tab:Icon("\u{f120}")
local page = tab:Create("cfg")
local g_main = page:Create("core", Enum.GroupSide.Left)
local g_look = page:Create("ovl", Enum.GroupSide.Right)

local ui = {}
ui.enable = g_main:Switch("dbg_on", true)
ui.radius = g_main:Slider("scan_r", 600, 2500, 1500, "%d")
ui.log = g_main:Switch("trace_io", true)
ui.lines = g_look:Switch("vec_ov", true)
ui.text = g_look:Switch("num_ov", true)

local UT = Enum.UnitTypeFlags
local COLORS = {
	chase = Color(90, 220, 120, 220),
	idle = Color(235, 200, 90, 220),
	away = Color(235, 90, 90, 220),
	text = Color(235, 235, 235, 255),
	dim = Color(170, 170, 180, 255),
}

local track = {}
local font = nil

local function sight_blocked(a, b)
	local n = math.floor(a:Distance2D(b) / 60.0)
	for k = 1, n - 1 do
		local trees = Trees.InRadius(a:Lerp(b, k / n), 60.0, true)
		if trees and #trees > 0 then return true end
	end
	return false
end

local function our_unit()
	local hero = Heroes.GetLocal()
	if not hero then return nil end
	local player = Players.GetLocal()
	local id = player and Player.GetPlayerID(player) or -1
	local list = NPCs.GetAll() or {}
	local best, best_d = nil, math.huge
	local hero_pos = Entity.GetAbsOrigin(hero)
	for i = 1, #list do
		local u = list[i]
		if u ~= hero and Entity.IsAlive(u) and not Entity.IsDormant(u)
			and Entity.IsControllableByPlayer(u, id)
			and not NPC.IsIllusion(u) and not NPC.IsCourier(u)
			and not NPC.IsWard(u) and not NPC.IsStructure(u) and not NPC.IsLaneCreep(u) then
			local d = Entity.GetAbsOrigin(u):Distance2D(hero_pos)
			if d < best_d then best, best_d = u, d end
		end
	end
	return best or hero
end

local script = {}

function script.OnDraw()
	if not ui.enable:Get() or not Engine.IsInGame() then return end
	if not font then
		font = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
	end

	local unit = our_unit()
	if not unit then return end
	local hero = Heroes.GetLocal()
	local my_team = Entity.GetTeamNum(hero)
	local u_pos = Entity.GetAbsOrigin(unit)
	local now = GameRules.GetGameTime()
	local radius = ui.radius:Get()

	local chase, idle, away = 0, 0, 0
	local list = NPCs.GetAll(UT.TYPE_LANE_CREEP) or {}
	local seen = {}
	for i = 1, #list do
		local n = list[i]
		if NPC.IsLaneCreep(n) and Entity.IsAlive(n) and not Entity.IsDormant(n)
			and Entity.GetTeamNum(n) ~= my_team then
			local pos = Entity.GetAbsOrigin(n)
			local d = pos:Distance2D(u_pos)
			if d <= radius then
				local idx = Entity.GetIndex(n)
				seen[idx] = true
				local rec = track[idx] or { x = pos:GetX(), y = pos:GetY(), t = now, state = "idle", since = now }
				track[idx] = rec
				local dt = now - rec.t
				if dt >= 0.1 then
					local vx, vy = (pos:GetX() - rec.x) / dt, (pos:GetY() - rec.y) / dt
					local dx, dy = u_pos:GetX() - pos:GetX(), u_pos:GetY() - pos:GetY()
					local l = math.sqrt(dx * dx + dy * dy)
					rec.toward = l > 1.0 and (vx * dx + vy * dy) / l or 0.0
					rec.speed = math.sqrt(vx * vx + vy * vy)
					rec.x, rec.y, rec.t = pos:GetX(), pos:GetY(), now
				end
				local toward, speed = rec.toward or 0.0, rec.speed or 0.0
				local attacking = NPC.IsAttacking(n)
				local state = "idle"
				if attacking or toward >= 60.0 then
					state = "chase"
				elseif toward <= -60.0 then
					state = "away"
				end
				local dz = u_pos:GetZ() - pos:GetZ()
				local blocked = sight_blocked(pos, u_pos)
				if state ~= rec.pending then
					rec.pending, rec.since = state, now
				elseif state ~= rec.state and now - rec.since >= 0.3 then
					if ui.log:Get() then
						Log.Write(string.format(
							"[hg] e%d %s>%s d=%.0f dz=%.0f tr=%d tw=%.0f v=%.0f",
							idx, rec.state, state, d, dz, blocked and 1 or 0, toward, speed))
					end
					rec.state = state
				end
				state = rec.state
				if state == "chase" then
					chase = chase + 1
				elseif state == "away" then
					away = away + 1
				else
					idle = idle + 1
				end

				local a, va = Render.WorldToScreen(pos)
				local b, vb = Render.WorldToScreen(u_pos)
				if ui.lines:Get() and va and vb then
					Render.Line(a, b, COLORS[state], 1.5)
				end
				if ui.text:Get() and va then
					Render.Text(font, 13, string.format("%.0f dz%.0f v%.0f%s", d, dz, toward, blocked and " tr" or ""),
						Vec2(a.x + 8, a.y - 8), COLORS[state])
				end
			end
		end
	end
	for idx in pairs(track) do
		if not seen[idx] then track[idx] = nil end
	end

	local name = NPC.GetUnitName(unit) or "unit"
	Render.Text(font, 15, string.format("hg %s z=%.0f", name, u_pos:GetZ()), Vec2(40, 400), COLORS.text)
	Render.Text(font, 14, string.format("c=%d i=%d a=%d", chase, idle, away), Vec2(40, 418), COLORS.dim)
end

function script.OnGameEnd()
	track = {}
end

return script
