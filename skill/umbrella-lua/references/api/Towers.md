# Towers
Table to work with tower list.

Towers.Count() -> integer
  Return size of tower list.
Towers.Get(index: integer) -> CTower|nil
  Return tower by index in cheat list. Not the same as in-game index.
  index: Index of tower in cheat list.
Towers.GetAll() -> CTower[]
  Return all towers in cheat list.
Towers.InRadius(pos: Vector, radius: number, teamNum: Enum.TeamNum, [teamType: Enum.TeamType = Enum.TeamType.TEAM_ENEMY]) -> CTower[]
  Return all towers in radius.
  pos: Position to check.
  radius: Radius to check.
  teamNum: Team number to check.
  teamType: Team number to check.
Towers.Contains(tower: CTower) -> boolean
  Check tower in cheat list.
  tower: Tower to check.
