# GameRules
Table to work with GameRules.

GameRules.GetServerGameState() -> Enum.GameState
  Returns the current server game state.
GameRules.GetGameState() -> Enum.GameState
  Returns the current game state.
GameRules.GetGameMode() -> Enum.GameMode
  Returns the current game mode.
GameRules.GetPreGameStartTime() -> number
  ! Pregame time is the time before the game starts, e.g. ban phase, pick time.
  Returns pregame duration or 0 if now is pregame time.
GameRules.GetGameStartTime() -> number
  ! Game start time is 0:00 on ingame timer.
  Returns game start time duration or 0 if game is not start yet.
GameRules.GetGameEndTime() -> number
  Returns game end time or 0 if game is not end yet.
GameRules.GetGameLoadTime() -> number
  No idea what this function does. Returns 0 in all cases what I've tested.
GameRules.GetGameTime() -> number
  ! Can be used to calculate time in an in-game timer. See the example.
  Returns the current game time. Starts counting from pregame state.
```lua
local game_time = GameRules.GetGameTime();
local ingame_timer = game_time - GameRules.GetGameStartTime();
Log.Write(string.format("Current time: %d:%02d", math.floor(ingame_timer / 60),
math.floor(ingame_timer % 60)))
```
GameRules.IsPaused() -> boolean
  Returns true if game is paused.
GameRules.IsTemporaryDay() -> boolean
  ! Example: Phoenix's Supernova.
  Returns true if it's temporary day.
GameRules.IsTemporaryNight() -> boolean
  ! Example: Luna's Eclipse.
  Returns true if it's temporary night.
GameRules.IsNightstalkerNight() -> boolean
  Returns true if it's nightstalker's night.
GameRules.GetMatchID() -> integer
  Returns current match id.
GameRules.GetLobbyID() -> integer
  Returns current lobby id.
GameRules.GetGoodGlyphCD() -> number
  ! Could be less than current game time if glyph is already available.
  Returns game time when next radiant glyph will be available.
GameRules.GetBadGlyphCD() -> number
  ! Could be less than current game time if glyph is already available.
  Returns game time when next dire glyph will be available.
GameRules.GetGoodScanCD() -> number
  ! Could be less than current game time if scan is already available.
  Returns game time when next radiant scan will be available.
GameRules.GetBadScanCD() -> number
  ! Could be less than current game time if scan is already available.
  Returns game time when next dire scan will be available.
GameRules.GetGoodScanCharges() -> integer
  Returns current radiant scan charges.
GameRules.GetGoodScanCharges() -> integer
  Returns current dire scan charges.
GameRules.GetStockCount(item_id: integer, [team: Enum.TeamNum = Enum.TeamNum.TEAM_RADIANT]) -> integer
  ! Item id can be found in assets/data/items.json file in cheat folder.
  Returns amount of remaining items in shop by item id.
  team: - Optional. Default is local player's team.
```lua
-- "item_ward_observer": {
--     "ID": "42",
Log.Write("Observers available: " .. GameRules.GetStockCount(42))
```
GameRules.GetNextCycleTime() -> number, boolean
  Return time remaining to the next cycle.
GameRules.GetDaytimeStart() -> number
  Returns day start time. To work with it use GameRules.GetTimeOfDay
GameRules.GetNighttimeStart() -> number
  Returns night start time. To work with it use GameRules.GetTimeOfDay
GameRules.GetTimeOfDay() -> number
  Returns current time of day time.
GameRules.IsInBanPhase() -> boolean
  Returns true if game is in ban phase.
GameRules.GetAllDraftPhase() -> integer
  Returns index of the current draft phase.
GameRules.IsAllDraftPhaseRadiantFirst() -> boolean
  Returns true if Radiant picks first.
GameRules.GetDOTATime([pregame: boolean = false], [negative: boolean = false]) -> number
  Returns the actual DOTA in-game clock time.
  pregame: If true includes pregame time.
  negative: If true includes negative time.
GameRules.GetLobbyObjectJson() -> string|nil
  Returns CSODOTALobby protobuf object as JSON string.
GameRules.GetBannedHeroes() -> integer[]|nil
  Returns zero-based array of banned heroes where index corresponds to the player id.
GameRules.GetStateTransitionTime() -> number
  Returns time remaining between state changes.
