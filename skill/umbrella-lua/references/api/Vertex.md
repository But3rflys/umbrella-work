# Vertex
Vertex metatable
Поля: pos: Vec2 (screen pos), uv: Vec2 (texture uv)

Vertex(pos: Vec2, uv: Vec2) -> Vertex
  Create a new Vertex.
Vertex(posx: number, posy: number, uvx: number, uvy: number) -> Vertex
  Create a new Vertex(0,0).
Vertex:__tostring() -> string
Vertex:__add(other: Vertex|number) -> Vertex
  ! Overload for operator +
Vertex:__sub(other: Vertex|number) -> Vertex
  ! Overload for operator -
