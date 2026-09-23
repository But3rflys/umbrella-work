# ConVar
Table to work with CConVars. ConVars are game variable that can be used to retrieve or change some game engine settings.

ConVar.Find(name: string) -> CConVar|nil
  Returns the found ConVar.
```lua
local convar = ConVar.Find("dota_camera_distance")
local camera_distance = ConVar.GetFloat(convar)
```
ConVar.GetString(convar: CConVar) -> string
  Returns string value of the Convar
ConVar.GetInt(convar: CConVar) -> integer
  Returns int value of the Convar
ConVar.GetFloat(convar: CConVar) -> number
  Returns float value of the Convar
ConVar.GetBool(convar: CConVar) -> boolean
  Returns boolean value of the Convar
ConVar.SetString(convar: CConVar, value: string)
  Assigns new string value to the ConVar
ConVar.SetInt(convar: CConVar, value: integer)
  Assigns new int value to the ConVar
ConVar.SetFloat(convar: CConVar, value: number)
  Assigns new float value to the ConVar
ConVar.SetBool(convar: CConVar, value: boolean)
  Assigns new boolean value to the ConVar
