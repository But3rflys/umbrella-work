# Humanizer
Table to work with humanizer.

Humanizer.IsInServerCameraBounds(pos: Vector) -> boolean
  Returns true if the world position is in server camera bounds.
  pos: position to check
Humanizer.GetServerCameraPos() -> Vector
  Returns server camera position.
Humanizer.GetClientCameraPos() -> Vector
  Returns client camera position.
Humanizer.GetServerCursorPos() -> Vector
  Returns the server cursor position.
Humanizer.GetOrderQueue() -> {player: CPlayer, orderType: Enum.UnitOrder, targetIndex: integer, position: Vector, abilityIndex: integer, orderIssuer: Enum.PlayerOrderIssuer, unit: CNPC, orderQueueBehavior: integer, showEffects: boolean, triggerCallBack: boolean, isByMiniMap: boolean, addTime: number }[]
  Returns information about the current humanizer order queue.
Humanizer.IsSafeTarget(entity: CEntity) -> boolean
  Returns information about the current humanizer order queue.
Humanizer.ForceUserOrderByMinimap()
  Forces current user order by minimap. Must be called in OnPrepareUnitOrder
