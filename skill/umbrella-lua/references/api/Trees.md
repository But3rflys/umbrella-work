# Trees
Table to work with list of trees.

Trees.Count() -> integer
  Return size of tree list.
Trees.Get(index: integer) -> CTree|nil
  Return tree by index in cheat list. Not the same as in-game index.
  index: Index of tree in cheat list.
Trees.GetAll() -> CTree[]
  Return all trees in cheat list.
Trees.InRadius(pos: Vector, radius: number, [active: boolean = true]) -> CTree[]
  Return all trees in radius.
  pos: Position to check.
  radius: Radius to check.
  active: Active state to check.
Trees.Contains(tree: CTree) -> boolean
  Check tree in cheat list.
  tree: Tree to check.
