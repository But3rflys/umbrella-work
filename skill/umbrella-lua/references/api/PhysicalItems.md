# Physical Items
Table to work with list of phisical items.

PhysicalItems.Count() -> integer
  Return size of physical item list.
PhysicalItems.Get(index: integer) -> CPhysicalItem|nil
  Return physical item by index in cheat list. Not the same as in-game index.
  index: Index of physical item in cheat list.
PhysicalItems.GetAll() -> CPhysicalItem[]
  Return all physical items in cheat list.
PhysicalItems.Contains(physical: CPhysicalItem) -> boolean
  Check physical item in cheat list.
  physical: item Physical item to check.
