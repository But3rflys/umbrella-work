# Vec2
Vec2 metatable
Поля: x: number, y: number

Vec2:AddInPlace(other: Vec2|number) -> Vec2
  Adds other to this Vec2 in-place. Returns self for chaining.
Vec2:SubInPlace(other: Vec2|number) -> Vec2
  Subtracts other from this Vec2 in-place. Returns self for chaining.
Vec2:MulInPlace(other: Vec2|number) -> Vec2
  Multiplies this Vec2 by other in-place. Returns self for chaining.
Vec2:DivInPlace(other: Vec2|number) -> Vec2
  Divides this Vec2 by other in-place. Returns self for chaining.
Vec2:CopyFrom(other: Vec2) -> Vec2
  Copies values from another Vec2 without allocating. Returns self for chaining.
Vec2:Clone() -> Vec2
  Creates a new Vec2 with the same values as the original.
Vec2:Set(x: number, y: number) -> Vec2
  Sets x, y components. Returns self for chaining.
Vec2:IsZero([tolerance: number = 0.01]) -> boolean
  Returns true if all components are near zero within tolerance.
Vec2(x: number, y: number) -> Vec2
  Create a new Vec2.
Vec2() -> Vec2
  Create a new Vec2(0,0).
Vec2:__tostring() -> string
Vec2:__add(other: Vec2|number) -> Vec2
  ! Overload for operator +
Vec2:__sub(other: Vec2|number) -> Vec2
  ! Overload for operator -
Vec2:__div(other: Vec2|number) -> Vec2
  ! Overload for operator /
Vec2:__mul(other: Vec2|number) -> Vec2
  ! Overload for operator *
Vec2:__eq(other: Vec2) -> boolean
  ! Overload for operator ==
Vec2:Length() -> number
  Returns the length of the vector.
Vec2:Get() -> number, number
  Returns x, y of this vector.
Vec2:GetX() -> number
  Returns x of this vector. The same as Vec2.x.
Vec2:GetY() -> number
  Returns y of this vector. The same as Vec2.y.
Vec2:SetX(value: number)
  Sets x. The same as Vec2.x = value.
Vec2:SetY(value: number)
  Sets y. The same as Vec2.y = value.
