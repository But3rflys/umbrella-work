# Camps
Table to work with list of neutral spawners.

Camps.Count() -> integer
  Return size of neutral spawner list.
Camps.Get(index: integer) -> CCamp|nil
  Return neutral spawner by index in cheat list. Not the same as in-game index.
  index: Index of neutral spawner in cheat list.
Camps.GetAll() -> CCamp[]
  Return all neutral spawners in cheat list.
Camps.InRadius(pos: Vector, radius: number) -> CCamp[]
  Return all neutral spawners in radius.
  pos: Position to check.
  radius: Radius to check.
Camps.Contains(camp: CCamp) -> boolean
  Check neutral spawner in cheat list.
  camp: Neutral spawner to check.
