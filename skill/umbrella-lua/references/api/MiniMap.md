# MiniMap
Table to work with in-game minimap.

MiniMap.Ping(pos: Vector, type: Enum.PingType)
  Pings on the minimap.
  pos: world position to ping
  type: ping type
MiniMap.SendLine(pos: Vector, initial: boolean, clientside: boolean)
  Draws a line on the minimap.
  pos: world position to draw line to
  initial: start a new line, otherwise continue the last one
  clientside: draw only for local player
MiniMap.SendLine(x: number, y: number, initial: boolean, clientside: boolean)
  Draws a line on the minimap.
  x: x world position to draw line
  y: y world position to draw line
  initial: start a new line, otherwise continue the last one
  clientside: draw only for local player
MiniMap.DrawCircle(pos: Vector, [r: integer = 255], [g: integer = 255], [b: integer = 255], [a: integer = 255], [size: number = 800])
  Draws a circle on the minimap.
  pos: world position to draw circle
  r: red color
  g: green color
  b: blue color
  a: alpha color
  size: circle size
MiniMap.DrawHeroIcon(unitName: string, pos: Vector, [r: integer = 255], [g: integer = 255], [b: integer = 255], [a: integer = 255], [size: number = 800])
  Draws a hero icon on the minimap.
  unitName: unit name to draw icon. Can get it from NPC.GetUnitName
  pos: world position to draw icon
  r: red color
  g: green color
  b: blue color
  a: alpha color
  size: icon size
MiniMap.DrawIconByName(iconName: string, pos: Vector, [r: integer = 255], [g: integer = 255], [b: integer = 255], [a: integer = 255], [size: number = 800])
  Draws a icon on the minimap.
  iconName: could get it from game\dota\pak01_dir.vpk (scripts\mod_textures.txt).
  pos: world position to draw icon
  r: red color
  g: green color
  b: blue color
  a: alpha color
  size: icon size
MiniMap.GetMousePosInWorld() -> Vector
  Returns world position the mouse on the minimap, if the mouse is not on the minimap, it will return (0,0,0).
MiniMap.IsCursorOnMinimap() -> boolean
  Returns true if the mouse is on the minimap.
MiniMap.GetMinimapToWorld(ScreenX: integer, ScreenY: integer) -> Vector
  Returns world position from minimap position. The same as GetMousePosInWorld, but you can pass any position on screen, not only mouse position.
