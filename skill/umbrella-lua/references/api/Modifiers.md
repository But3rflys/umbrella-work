# Modifiers
Table to work with list of modifiers.

Modifiers.Count() -> integer
  Returns size of modifiers list.
Modifiers.Get(index: integer) -> CModifier|nil
  Returns modifiers by index in cheat list. Not the same as in-game index.
  index: Index of temp tree in cheat list.
Modifiers.GetAll() -> CModifier[]
  Returns all modifiers in cheat list.
Modifiers.Contains(tree: CModifier) -> boolean
  Checks if modifiers is in list.
  tree: Temp tree to check.
