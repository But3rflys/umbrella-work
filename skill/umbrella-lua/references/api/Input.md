# Input
Table to work with input system.

Input.GetWorldCursorPos() -> Vector
  Returns world cursor position.
Input.GetCursorPos() -> number, number
  Returns screen cursor position (x, y). See example.
```lua
local x, y =	Input.GetCursorPos()
```
Input.IsCursorInRect(x: number, y: number, w: number, h: number) -> boolean
  Returns true if cursor is in rect.
  x: x position
  w: width
  h: height
Input.IsCursorInBounds(x0: number, y0: number, x1: number, y1: number) -> boolean
  Returns true if cursor is in bounds.
Input.GetNearestUnitToCursor(teamNum: Enum.TeamNum, teamType: Enum.TeamType) -> CNPC|nil
  ! Excludes not visible, illusions and dead units.
  Returns nearest unit to cursor.
  teamNum: team number. Could be get from Entity.GetTeamNum
  teamType: team type to search relative to teamNum param
Input.GetNearestHeroToCursor(teamNum: Enum.TeamNum, teamType: Enum.TeamType) -> CHero|nil
  ! Excludes not visible, illusions and dead heroes.
  Returns nearest hero to cursor.
  teamNum: team number. Could be get from Entity.GetTeamNum
  teamType: team type to search relative to teamNum param
Input.IsInputCaptured() -> boolean
  Returns true if input is captured. e.g. opened console, chat, shop.
Input.IsPopupOpen() -> boolean
  ! Tracks the dashboard popup manager. Same signal the game uses to suppress its own gameplay key binds while a popup is shown.
  Returns true if any panorama popup is currently open (settings, accept-match, item picker, party invite, etc.).
Input.IsKeyDown(KeyCode: Enum.ButtonCode, [bIgnoreLock: boolean = false]) -> boolean
  Returns true if key is down.
  bIgnoreLock: when true, ignores the input capture lock (chat / settings popup / console) and returns the raw key state. Default false preserves the previous behavior - returns false while any of those is active.
Input.IsKeyDownOnce(KeyCode: Enum.ButtonCode, [bIgnoreLock: boolean = false]) -> boolean
  ! This function will return true only once per key press.
  Return true if key is down once.
  bIgnoreLock: when true, ignores the input capture lock (chat / settings popup / console) and returns the raw key-pressed state. Default false preserves the previous behavior.
