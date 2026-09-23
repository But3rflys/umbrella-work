# Angle
Angle metatable
Поля: pitch: number, yaw: number, roll: number

Angle:__eq(other: Angle) -> boolean
  Compares two angles for equality.
Angle:__add(other: Angle) -> Angle
  Adds two angles together. Returns a new Angle.
Angle:__sub(other: Angle) -> Angle
  Subtracts one angle from another. Returns a new Angle.
Angle:Set(pitch: number, yaw: number, roll: number) -> Angle
  Sets pitch, yaw, roll. Returns self for chaining.
Angle:CopyFrom(other: Angle) -> Angle
  Copies values from another angle without allocating. Returns self for chaining.
Angle:Clone() -> Angle
  Creates a new angle with the same values as the original.
Angle:Get() -> number, number, number
  Returns pitch, yaw, roll as three numbers.
Angle:IsZero([tolerance: number = 0.01]) -> boolean
  Returns true if all components are near zero within tolerance.
Angle([pitch: number = 0.0], [yaw: number = 0.0], [roll: number = 0.0]) -> Angle
  Create a new Angle.
Angle:__tostring() -> string
Angle:GetForward() -> Vector
  Returns the forward vector from a given Angle.
Angle:GetVectors() -> Vector, Vector, Vector
  Returns the forward, right and up.
Angle:GetYaw() -> number
  Returns the yaw. The same as Angle.yaw.
Angle:GetRoll() -> number
  Returns the roll. The same as Angle.roll.
Angle:GetPitch() -> number
  Returns the pitch. The same as Angle.pitch.
Angle:SetYaw(value: number)
  Sets the yaw. The same as Angle.yaw = value.
Angle:SetRoll(value: number)
  Sets the roll. The same as Angle.roll = value.
Angle:SetPitch(value: number)
  Sets the pitch. The same as Angle.pitch = value.
