# GameLocalizer
Table to work with game localization. Localization tokens are stored in resource/localization folder in pak01_dir.vpk

GameLocalizer.Find(token: string) -> string
  Returns localized string by token or returns empty string if token not found.
  token: should be in format #token
```lua
GameLocalizer.Find("#DOTA_AutocastAbility5") -- Autocast Ability Ultimate
```
GameLocalizer.FindAbility(ability_name: string) -> string
  Returns localized string by ability name or returns empty string if ability not found.
```lua
GameLocalizer.FindAbility("antimage_mana_void") -- Mana Void
```
GameLocalizer.FindItem(item_name: string) -> string
  Returns localized string by item name or returns empty string if item not found.
```lua
GameLocalizer.FindItem("item_blink") -- Blink Dagger
GameLocalizer.FindItem("item_recipe_arcane_blink") -- Recipe: Arcane Blink
```
GameLocalizer.FindNPC(unit_name: string) -> string
  Returns localized string by unit name or returns empty string if unit not found.
```lua
GameLocalizer.FindNPC("npc_dota_hero_necrolyte") -- Necrophos
```
