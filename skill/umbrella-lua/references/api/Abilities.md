# Abilities
Table to work with ability list.

Abilities.Count() -> integer
  Return size of ability list.
Abilities.Get(index: integer) -> CAbility|nil
  Return ability by index in cheat list. Not the same as in-game index.
  index: Index of ability in cheat list.
Abilities.GetAll() -> CAbility[]
  Return all abilities in cheat list.
Abilities.Contains(ability: CAbility) -> boolean
  Check ability in cheat list.
  ability: Ability to check.
