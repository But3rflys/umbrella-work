# Renderer
Table to work with renderer.

Renderer.SetDrawColor([r: integer = 255], [g: integer = 255], [b: integer = 255], [a: integer = 255])
  Sets the color of the renderer.
  r: Red color.
  g: Green color.
  b: Blue color.
  a: Alpha color.
Renderer.DrawLine(x0: integer, y0: integer, x1: integer, y1: integer)
  Draws a line.
  x0: X coordinate of the first point.
  y0: Y coordinate of the first point.
  x1: X coordinate of the second point.
  y1: Y coordinate of the second point.
Renderer.DrawPolyLine(points: table)
  Draws a polyline.
  points: Table of points.
Renderer.DrawPolyLineFilled(points: table)
  Draws a filled polyline.
  points: Table of points.
Renderer.DrawFilledRect(x: integer, y: integer, w: integer, h: integer)
  Draws a filled rectangle.
  x: X coordinate of the rectangle.
  y: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
Renderer.DrawOutlineRect(x: integer, y: integer, w: integer, h: integer)
  Draws an outlined rectangle.
  x: X coordinate of the rectangle.
  y: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
Renderer.DrawOutlineCircle(x: integer, y: integer, r: integer, s: integer)
  Draws an outlined circle.
  x: X coordinate of the circle.
  y: Y coordinate of the circle.
  r: Radius of the circle.
  s: Segments of the circle.
Renderer.DrawFilledCircle(x: integer, y: integer, r: integer)
  Draws a filled circle.
  x: X coordinate of the circle.
  y: Y coordinate of the circle.
  r: Radius of the circle.
Renderer.DrawOutlineRoundedRect(x: integer, y: integer, w: integer, h: integer, radius: integer)
  Draws an outlined rounded rectangle.
  x: X coordinate of the rectangle.
  y: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
  radius: Radius of the rectangle.
Renderer.DrawFilledRoundedRect(x: integer, y: integer, w: integer, h: integer, radius: integer)
  Draws a filled rounded rectangle.
  x: X coordinate of the rectangle.
  y: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
  radius: Radius of the rectangle.
Renderer.DrawOutlineTriangle(points: table)
  Draws an outlined triangle.
  points: Table of points.
Renderer.DrawFilledTriangle(points: table)
  Draws a filled triangle.
  points: Table of points.
Renderer.DrawTexturedPolygon(points: table, texture: integer)
  Draws a textured polygon.
  points: Table of points.
  texture: Texture handle.
Renderer.LoadFont(name: string, size: integer, flags: integer, weight: integer) -> integer
  Loads a font.
  name: Name of the font.
  size: Size of the font.
  flags: Font flags.
  weight: Font weight.
Renderer.DrawText(font: integer, x: integer, y: integer, text: string)
  Draws a text.
  font: Font handle.
  x: X coordinate of the text.
  y: Y coordinate of the text.
  text: Text to draw.
Renderer.WorldToScreen(pos: Vector) -> integer, integer, boolean
  Converts world coordinates to screen coordinates. Returns x, y and visible.
  pos: World coordinates.
Renderer.GetScreenSize() -> integer, integer
  Returns screen size.
Renderer.GetTextSize(font: integer, text: string) -> integer, integer
  Returns text size.
  font: Font handle.
  text: Text to measure.
Renderer.LoadImage(path: string) -> integer
  Loads an image. Returns image handle.
  path: Path to the image.
Renderer.DrawImage(handle: integer, x: integer, y: integer, w: integer, h: integer)
  Draws an image.
  handle: Image handle.
  x: X coordinate of the image.
  y: Y coordinate of the image.
  w: Width of the image.
  h: Height of the image.
Renderer.DrawImageCentered(handle: integer, x: integer, y: integer, w: integer, h: integer)
  Draws an image centered.
  handle: Image handle.
  x: X coordinate of the image.
  y: Y coordinate of the image.
  w: Width of the image.
  h: Height of the image.
Renderer.GetImageSize(handle: integer) -> integer, integer
  Returns image size.
  handle: Image handle.
Renderer.DrawFilledRectFade(x0: integer, y0: integer, x1: integer, y1: integer, alpha0: integer, alpha1: integer, bHorizontal: boolean)
  Draws a filled rectangle with fade.
  x0: X coordinate of the rectangle.
  y0: Y coordinate of the rectangle.
  x1: X coordinate of the rectangle.
  y1: Y coordinate of the rectangle.
  alpha0: Alpha of the first point.
  alpha1: Alpha of the second point.
  bHorizontal: Horizontal fade.
Renderer.DrawFilledGradRect(x0: integer, y0: integer, x1: integer, y1: integer, r: integer, g: integer, b: integer, a: integer, r2: integer, g2: integer, b2: integer, a2: integer, bHorizontal: boolean)
  Draws a filled gradient rectangle.
  x0: X coordinate of the rectangle.
  y0: Y coordinate of the rectangle.
  x1: X coordinate of the rectangle.
  y1: Y coordinate of the rectangle.
  r: Red color of the first point.
  g: Green color of the first point.
  b: Blue color of the first point.
  a: Alpha color of the first point.
  r2: Red color of the second point.
  g2: Green color of the second point.
  b2: Blue color of the second point.
  a2: Alpha color of the second point.
  bHorizontal: Horizontal gradient.
Renderer.DrawGlow(x0: integer, y0: integer, w: integer, h: integer, thickness: integer, obj_rounding: integer)
  Draws a glow.
  x0: X coordinate of the rectangle.
  y0: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
  thickness: Thickness of the glow.
  obj_rounding: Rounding of the glow.
Renderer.DrawBlur(x0: number, y0: number, w: number, h: number, strength: number, rounding: number, alpha: number)
  Draws a blur.
  x0: X coordinate of the rectangle.
  y0: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
  strength: Strength of the blur.
  rounding: Rounding of the blur.
  alpha: Alpha of the blur.
Renderer.PushClip(x: integer, y: integer, w: integer, h: integer, intersect: boolean)
  Pushes a clip rect.
  x: X coordinate of the rectangle.
  y: Y coordinate of the rectangle.
  w: Width of the rectangle.
  h: Height of the rectangle.
  intersect: Intersect with the previous clip.
Renderer.PopClip()
  Pops a clip rect.
Renderer.DrawCenteredNotification(text: string, duration: number)
  Draws a centered notification.
  text: Text to draw.
  duration: Duration of the notification.
