# Players
Table to work with player list.

Players.Count() -> integer
  Return size of player list.
Players.Get(index: integer) -> CPlayer|nil
  Return player by index in cheat list. Not the same as in-game index.
  index: Index of player in cheat list.
Players.GetAll() -> CPlayer[]
  Return all players in cheat list.
Players.Contains(player: CPlayer) -> boolean
  Check player in cheat list.
  player: Player to check.
Players.GetLocal() -> CPlayer
  Return local player.
