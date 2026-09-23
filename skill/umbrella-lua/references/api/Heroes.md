# Heroes
Table to work with hero list.

Heroes.Count() -> integer
  Return size of hero list.
Heroes.Get(index: integer) -> CHero|nil
  Return hero by index in cheat list. Not the same as in-game index.
  index: Index of hero in cheat list.
Heroes.GetAll() -> CHero[]
  Return all heroes in cheat list.
Heroes.Contains(hero: CHero) -> boolean
  Check hero in cheat list.
  hero: Hero to check.
Heroes.InRadius(pos: Vector, radius: number, teamNum: Enum.TeamNum, teamType: Enum.TeamType, [omitIllusions: boolean = false], [omitDormant: boolean = true]) -> CHero[]
  Return all heroes in radius.
  pos: Position to check.
  radius: Radius to check.
  teamNum: Team number to check.
  teamType: Team type to filter by. Relative to teamNum param.
  omitIllusions: true if you want to get table without illusions
  omitDormant: true if you want to get table without dormant units
Heroes.GetLocal() -> CHero
  Return local hero.
