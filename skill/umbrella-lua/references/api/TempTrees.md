# TempTrees
Table to work with list of temp trees.

TempTrees.Count() -> integer
  Return size of temp trees list.
TempTrees.Get(index: integer) -> CTree|nil
  Return temp tree by index in cheat list. Not the same as in-game index.
  index: Index of temp tree in cheat list.
TempTrees.GetAll() -> CTree[]
  Return all temp trees in cheat list.
TempTrees.InRadius(pos: Vector, radius: number) -> CTree[]
  Return all temp trees in radius.
  pos: Position to check.
  radius: Radius to check.
TempTrees.Contains(tree: CTree) -> boolean
  Check temp tree in cheat list.
  tree: Temp tree to check.
