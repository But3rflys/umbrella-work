# Engine
Table to work with game engine.

Engine.IsInGame() -> boolean
  Returns true if the game is in progress.
Engine.IsShopOpen() -> boolean
  Returns true if the shop is open.
Engine.SetQuickBuy(item_name: string, [reset: boolean = true])
  Add item to quick buy list.
  item_name: The name of the item to quick buy. (e.g. blink, relic)
  reset: Reset the quick buy list.
Engine.RunScript(script: string, [contextPanel: string|UIPanel = "Dashboard"]) -> boolean
  Run a JS script in the panorama context. Return true if the script was executed successfully. [JS documentation](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Panorama/Javascript)
  script: The script to run.
  contextPanel: The id of the panel or the panel itself to run the script in.
```lua
-- in dota console, you should see "Hello from Lua!"
Engine.RunScript("$.Msg('Hello from Lua!')");
```
Engine.ExecuteCommand(command: string)
  Execute a console command.
  command: The command to execute.
```lua
-- in dota chat, you should see "Hello from Lua!"
Engine.ExecuteCommand("say \"Hello from Lua!\"");
```
Engine.PlayVol(sound: string, [volume: number = 0.1])
  Play a sound with a specific volume.
  sound: The sound to play. Could find in sounds folder in pak01_dir.vpk file.
  volume: The volume of the sound.
```lua
-- play a sound with a volume of 0.5 (very loud)
Engine.PlayVol("sounds/npc/courier/courier_acknowledge.vsnd_c", 0.5);
```
Engine.CreateConfig(config_name: string, categories: {name: string, hero_ids: integer[], x: number, y: number, width: number, height: number}[])
  Creates a new hero grid config.
  config_name: The name of the config.
```lua
Engine.CreateConfig("From lua", {
{
	name = "55%+",
	hero_ids = {1, 2, 3, 4},
	x = 0.0,
	y = 0.0,
	width = 300.0,
	height = 200.0
},
{
	name = "52%+",
	hero_ids = {5, 6},
	x = 350.0,
	y = 0.0,
	width = 300.0,
	height = 200.0
}
});
```
Engine.GetCurrentConfigName() -> string
  Returns the current hero grid config name
Engine.SetNewGridConfig(config_name: string)
  Set the new hero grid config by name
  config_name: The name of the config to set
Engine.LookAt(x: number, y: number)
  Move camera to a specific position.
Engine.CanAcceptMatch() -> boolean
  Returns true if the player can accept the match.
Engine.GetGameDirectory() -> string
  Returns the current game directory. (e.g. dota 2 beta)
Engine.GetCheatDirectory() -> string
  Returns the current cheat directory.
Engine.GetLevelName() -> string
  Returns the current level name. (e.g. maps/hero_demo_main.vpk)
Engine.GetLevelNameShort() -> string
  Returns the current level name without the extension and folder. (e.g. hero_demo_main)
Engine.AcceptMatch(state: integer)
  Accept match.
  state: DOTALobbyReadyState
Engine.ConsoleColorPrintf(r: integer, g: integer, b: integer, [a: integer = 255], text: string)
  Print a message to the dota console.
  r: Red value.
  g: Green value.
  b: Blue value.
  a: Alpha value.
  text: Text to print.
Engine.GetMMR() -> integer
  Returns the current MMR.
Engine.GetMMRV2() -> integer
  Returns the current MMR. Works better than Engine.GetMMR. Must be called from the game thread. Ex: OnNetUpdateEx, OnGCMessage, not OnFrame or on initialization.
Engine.ReloadScriptSystem()
  Executes script system reload.
Engine.ShowDotaWindow()
  Brings the game window to the forefront if it is minimized. Use this function to make the game window the topmost window.
Engine.IsInLobby() -> boolean
  Returns true if the player is in a lobby.
Engine.GetBuildVersion() -> string
  Returns the cheat version.
Engine.GetHeroIDByName(unitName: string) -> integer|nil
  Returns hero ID by unit name.
  unitName: Can be retrieved from NPC.GetUnitName
```lua
local abaddonId = Engine.GetHeroIDByName( "npc_dota_hero_abaddon" )
```
Engine.GetDisplayNameByUnitName(unitName: string) -> string|nil
  Returns hero display name by unit name.
  unitName: Can be retrieved from NPC.GetUnitName
```lua
local nevermore_name = Engine.GetDisplayNameByUnitName( "npc_dota_hero_nevermore" )
-- nevermore_name == "Shadow Fiend"
```
Engine.GetHeroNameByID(heroID: integer) -> string|nil
  Returns hero name by ID.
Engine.GetUIState() -> Enum.UIState
  Returns current UI state.
