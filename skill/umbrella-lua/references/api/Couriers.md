# Couriers
Table to work with courier list.

Couriers.Count() -> integer
  Return size of courier list.
Couriers.Get(index: integer) -> CCourier|nil
  Return courier by index in cheat list. Not the same as in-game index.
  index: Index of courier in cheat list.
Couriers.GetAll() -> CCourier[]
  Return all couriers in cheat list.
Couriers.Contains(courier: CCourier) -> boolean
  Check courier in cheat list.
  courier: Courier to check.
Couriers.GetLocal() -> CCourier|nil
  Return local courier.
