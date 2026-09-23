# Item
Table to work with CItem. CItem extends CAbility

Item.IsCombinable(item: CItem) -> boolean
  Returns true if the item is combinable. I'm not sure if non-combinable items even exist.
Item.IsPermanent(item: CItem) -> boolean
  Returns true if the item is permanent. I'm not sure what permanent items is, but for items with stacks this function returns false.
Item.IsStackable(item: CItem) -> boolean
  Returns true if the item is stackable. e.g tangoes, wards, etc.
Item.IsRecipe(item: CItem) -> boolean
  Returns true if the item is recipe.
Item.GetSharability(item: CItem) -> Enum.ShareAbility
  Returns item's sharability type.
Item.IsDroppable(item: CItem) -> boolean
  Returns true if the item is droppable.
Item.IsPurchasable(item: CItem) -> boolean
  Returns true if the item is purchasable.
Item.IsSellable(item: CItem) -> boolean
  Returns true if the item is sellable.
Item.RequiresCharges(item: CItem) -> boolean
  Returns true if the item requires charges. e.g. urn, vessel etc.
Item.IsKillable(item: CItem) -> boolean
  Returns true if item is destroyable by autoatack.
Item.IsDisassemblable(item: CItem) -> boolean
  Returns true if item is disassemblable.
Item.IsAlertable(item: CItem) -> boolean
  Returns true if item is alertable. e.g. smoke, mekansm, arcane boots etc.
Item.GetInitialCharges(item: CItem) -> integer
  Returns initial charges of the item. e.g. 3 for bottle, 1 for dust etc.
Item.CastsOnPickup(item: CItem) -> boolean
  No idea what this function does.
Item.GetCurrentCharges(item: CItem) -> integer
  Returns amount of current charges.
Item.GetSecondaryCharges(item: CItem) -> integer
  Returns amount of secondary charges. e.g. pack of both type of wards.
Item.IsCombineLocked(item: CItem) -> boolean
  Returns true if item locked for combining.
Item.IsMarkedForSell(item: CItem) -> boolean
  Returns true if item is marked for sell.
Item.GetPurchaseTime(item: CItem) -> number
  Returns the game time when the item was purchased. If the item was assembled from other items, It returns the purchase time of the item that had the lowest index at the moment of assembling.
Item.GetAssembledTime(item: CItem) -> number
  Returns the game time when the item was assembled. If the item was not assembled, returns time when the item was purchased.
Item.PurchasedWhileDead(item: CItem) -> boolean
  Returns true if item was purchased while dead.
Item.CanBeUsedOutOfInventory(item: CItem) -> boolean
  No idea which specific item example could be used out of inventory.
Item.IsItemEnabled(item: CItem) -> boolean
  Returns false if item has CD after moving from stash.
Item.GetEnableTime(item: CItem) -> number
  ! Could be less than current game time if item is already enabled.
  Returns game time when item will be enabled.
Item.GetPlayerOwnerID(item: CItem) -> integer
  Returns player ID who owns the item.
Item.GetCost(item: CItem) -> integer
  Returns item cost.
Item.GetStockCount(item_id: integer, [team: Enum.TeamNum = Enum.TeamNum.TEAM_RADIANT]) -> integer
  ! Item id can be found in assets/data/items.json file in cheat folder.
  Returns amount of remaining items in shop by item id.
  team: - Optional. Default is local player's team.
```lua
-- "item_ward_observer": {
--     "ID": "42",
Log.Write("Observers available: " .. Item.GetStockCount(42))
```
