# GlobalVars
Talbe to work with game's global variables.

GlobalVars.GetFrameCount() -> integer
  Returns absolute frame counter. Continues to increase even if game is paused.
GlobalVars.GetAbsFrameTime() -> number
  Returns absolute frame time.
GlobalVars.GetAbsFrameTimeDev() -> number
  Returns absolute frame time. No idea what's the difference between this and GetAbsFrameTime.
GlobalVars.GetMapName() -> string
  Returns full name of the current map. For example, "maps/dota.vpk" or "maps/hero_demo_main.vpk".
GlobalVars.GetMapGroupName() -> string
  Returns short name of the current map. For example, "dota" or "hero_demo_main".
GlobalVars.GetCurTime() -> number
  TODO
GlobalVars.GetServerTick() -> integer
  TODO
GlobalVars.GetIntervalPerTick() -> number
  TODO
