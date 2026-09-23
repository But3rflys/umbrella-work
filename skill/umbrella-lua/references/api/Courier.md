# Courier
Table to work with CCourier.CCourier extends CNPC

Courier.IsFlyingCourier(courier: CCourier) -> boolean
  Returns true if the courier is flying.
  courier: The courier to check.
Courier.GetRespawnTime(courier: CCourier) -> number
  Returns the game time when the courier will respawn.
  courier: The courier to check.
Courier.GetCourierState(courier: CCourier) -> Enum.CourierState
  Returns the courier state.
  courier: The courier to check.
Courier.GetPlayerID(courier: CCourier) -> integer
  Returns owner's player id.
  courier: The courier to check.
Courier.GetCourierStateEntity(courier: CCourier) -> CEntity|nil
  Returns the entity that the courier is currently interacting with.
  courier: The courier to check.
