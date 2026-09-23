# Vector
Vector metatable
Поля: x: number, y: number, z: number

Vector:AddInPlace(other: Vector|number) -> Vector
  Adds other to this vector in-place. Returns self for chaining.
Vector:SubInPlace(other: Vector|number) -> Vector
  Subtracts other from this vector in-place. Returns self for chaining.
Vector:MulInPlace(other: Vector|number) -> Vector
  Multiplies this vector by other in-place. Returns self for chaining.
Vector:DivInPlace(other: Vector|number) -> Vector
  Divides this vector by other in-place. Returns self for chaining.
Vector:Set(x: number, y: number, z: number) -> Vector
  Sets x, y, z components. Returns self for chaining.
Vector:SetGroundZ() -> Vector
  Sets .z = World.GetGroundZ(.x, .y). Returns self for chaining.
Vector:LerpInPlace(b: Vector, t: number) -> Vector
  Linearly interpolates this vector towards other in-place. Returns self for chaining.
Vector:CopyFrom(other: Vector) -> Vector
  Copies values from another vector without allocating. Returns self for chaining.
Vector:Clone() -> Vector
  Creates a new vector with the same values as the original.
Vector:DirectionTo(other: Vector, [dist: number = 1.0]) -> Vector
  Returns a normalized direction vector from this point to other, optionally scaled by distance. Equivalent to (other - self):Normalized():Scaled(dist) but with a single allocation.
  dist: optional scale factor
Vector:AngleBetween2D(middle: Vector, point3: Vector) -> number
  Returns the angle in radians between two 2D vectors formed by three points. Equivalent to the angle at point2 in the triangle point1-point2-point3, ignoring Z.
  middle: the vertex point (this is point1, middle is point2)
Vector:ClosestToPoint(entities: CEntity[]) -> CEntity|nil, number
  Finds the closest entity to this position from a table of entities. Returns the entity and the distance. Uses Distance2D.
Vector:DistanceSqr2D(other: Vector) -> number
  Returns the squared 2D distance to another vector. Cheaper than Distance2D (no sqrt). Use for distance comparisons: a:DistanceSqr2D(b) < range * range.
Vector:IsInRange2D(other: Vector, range: number) -> boolean
  Returns true if this position is within range of another position (2D, no sqrt).
Vector:Extend2D(target: Vector, distance: number) -> Vector
  Extends this position towards target by distance (2D, ignores Z). Single allocation. Equivalent to self + (target - self):Normalized() * distance without intermediate vectors.
Vector:Perpendicular2D() -> Vector
  Returns a 2D perpendicular vector (-y, x, z). Zero allocation if called in-place.
Vector:Negate() -> Vector
  Negates this vector in-place (-x, -y, -z). Returns self for chaining.
Vector:IsZero([tolerance: number = 0.01]) -> boolean
  Returns true if all components are near zero within tolerance.
Vector:Extrapolate(direction: Vector, scalar: number) -> Vector
  Returns self + direction * scalar. Single allocation. Useful for position extrapolation: start:Extrapolate(velocity, dt * speed).
Vector([x: number = 0.0], [y: number = 0.0], [z: number = 0.0]) -> Vector
  Create a new Vector.
Vector:__tostring() -> string
Vector:__add(other: Vector|Vec2|number) -> Vector
  ! Overload for operator +
Vector:__sub(other: Vector|Vec2|number) -> Vector
  ! Overload for operator -
Vector:__div(other: Vector|Vec2|number) -> Vector
  ! Overload for operator /
Vector:__mul(other: Vector|Vec2|number) -> Vector
  ! Overload for operator *
Vector:__eq(other: Vector) -> boolean
  ! Overload for operator ==
Vector:Distance(other: Vector) -> number
  Computes the distance from this vector to other.
Vector:Distance2D(other: Vector) -> number
  Computes the distance from this vector to other ignoring Z axis.
Vector:Normalized() -> Vector
  Returns this vector with a length of 1. When normalized, a vector keeps the same direction but its length is 1.0. Note that the current vector is unchanged and a new normalized vector is returned. If you want to normalize the current vector, use Vector:Normalize function.
Vector:Normalize()
  Makes this vector have a length of 1. When normalized, a vector keeps the same direction but its length is 1.0. Note that this function will change the current vector. If you want to keep the current vector unchanged, use Vector:Normalized function.
Vector:Dot(vector: Vector) -> number
  Dot Product of two vectors. The dot product is a float value equal to the magnitudes of the two vectors multiplied together and then multiplied by the cosine of the angle between them. For normalized vectors Dot returns 1 if they point in exactly the same direction, -1 if they point in completely opposite directions and zero if the vectors are perpendicular. More
Vector:Dot2D(vector: Vector) -> number
  Dot Product of two vectors ignoring Z axis.
Vector:Scaled(scale: number) -> Vector
  Returns this vector multiplied by the given number. The same as Vector * number.
Vector:Scale(scale: number)
  Multiplies this vector by the given number. The same as Vector = Vector * number.
Vector:Length() -> number
  Returns the length of this vector. The length of the vector is math.sqrt(x*x+y*y+z*z). If you only need to compare length of some vectors, you can compare squared magnitudes of them using LengthSqr (computing squared length is faster).
Vector:LengthSqr() -> number
  Returns the squared length of this vector. This method is faster than Length because it avoids computing a square root. Use this method if you need to compare vectors.
Vector:Length2D() -> number
  Returns the length of this vector ignoring Z axis.
Vector:Length2DSqr() -> number
  Returns the squared length of this vector ignoring Z axis. This method is faster than Length2D because it avoids computing a square root. Use this method if you need to compare vectors.
Vector:Rotated(angle: number|Angle) -> Vector
  Returns the new vector rotated counterclockwise by the given angle in the XY-plane, leaving the Z-axis unaffected.
Vector:Rotate(angle: number|Angle)
  Rotates this vector counterclockwise by the given angle in the XY-plane, leaving the Z-axis unaffected.
Vector:Lerp(b: Vector, t: number) -> Vector
  Returns linearly interpolated vector between two vectors. The value returned equals a + (b - a) * t (which can also be written a * (1-t) + b*t). When t = 0, a:Lerp(b, t) returns a. When t = 1, a:Lerp(b, t) returns b. When t = 0.5, a:Lerp(b, t) returns the point midway between a and b.
  b: end value, returned when t = 1
  t: value used to interpolate between a and b.
Vector:Cross(vector: Vector) -> Vector
  Returns cross product of two vectors. More Visualization
Vector:MoveForward(angle: Angle, distance: number) -> Vector
  Moves vector forward by a specified distance in the direction defined by a given Angle.
  distance: distance to move
```lua
-- entity position moved forward by 300
local pos = Entity.GetAbsOrigin(entity):MoveForward(Entity.GetRotation(entity), 300);
```
Vector:ToAngle() -> Vector
  Converts Vector to Angle. See <https://github.com/ValveSoftware/source-sdk-2013/blob/0565403b153dfcde602f6f58d8f4d13483696a13/src/mathlib/mathlib\_base.cpp#L535>
Vector:ToScreen() -> Vec2, boolean
  Converts Vector to screen coordinate
Vector:IsVisible() -> boolean
  Returns true if position visible on screen. To get screen position use :ToScreen method
Vector:Get() -> number, number, number
  Returns x, y and z of this vector.
Vector:GetX() -> number
  Returns x of this vector. The same as Vector.x.
Vector:GetY() -> number
  Returns y of this vector. The same as Vector.y.
Vector:GetZ() -> number
  Returns z of this vector. The same as Vector.z.
Vector:SetX(value: number)
  Sets x. The same as Vector.x = value.
Vector:SetY(value: number)
  Sets y. The same as Vector.y = value.
Vector:SetZ(value: number)
  Sets z. The same as Vector.z = value.
