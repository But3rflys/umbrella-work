# Runes
Table to work with rune list.

Runes.Count() -> integer
  Return size of rune list.
Runes.Get(index: integer) -> CRune|nil
  Return rune by index in cheat list. Not the same as in-game index.
  index: Index of rune in cheat list.
Runes.GetAll() -> CRune[]
  Return all runes in cheat list.
Runes.Contains(rune: CRune) -> boolean
  Check rune in cheat list.
  rune: Rune to check.
