# Render
Table to work with render v2.

Render.FilledRect(start: Vec2, end_: Vec2, color: Color, [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None])
  Draws a filled rectangle.
  start: The starting point of the rectangle.
  end_: The ending point of the rectangle.
  color: The color of the rectangle.
  rounding: The rounding radius of the rectangle corners.
  flags: Custom flags for drawing.
Render.Rect(start: Vec2, end_: Vec2, color: Color, [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None], [thickness: number = 1.0])
  Draws an unfilled rectangle.
  start: The starting point of the rectangle.
  end_: The ending point of the rectangle.
  color: The color of the rectangle's border.
  rounding: The rounding radius of the rectangle corners.
  flags: Custom flags for drawing.
  thickness: The thickness of the rectangle's border.
Render.RoundedProgressRect(start: Vec2, end_: Vec2, color: Color, percent: number, rounding: number, [thickness: number = 1.0])
  Draw a progress rectangle.
  start: The starting point of the rectangle.
  end_: The ending point of the rectangle.
  color: The color of the rectangle.
  percent: The percentage of the rectangle to fill [0..1].
  rounding: The rounding radius of the rectangle corners.
  thickness: The thickness of the rectangle's border.
Render.DonutChart(center: Vec2, radius: number, thickness: number, segments: {value: number, color: Color, icon: number|nil, icon_color: Color|nil, font_icon: {font: number, size: number, text: string}|nil}[], [options: {separator_color:Color|nil, separator_thickness:number|nil}|nil = nil])
  Draw a donut chart.
  center: The center position of the chart.
  radius: The outer radius of the chart.
  thickness: The thickness of the donut ring.
  segments: List of data segments.
  options: Optional settings for the chart appearance.
Render.Line(start: Vec2, end_: Vec2, color: Color, [thickness: number = 1.0])
  Draws a line between two points.
  start: The starting point of the line.
  end_: The ending point of the line.
  color: The color of the line.
  thickness: The thickness of the line.
Render.PolyLine(points: Vec2[], color: Color, [thickness: number = 1.0])
  Draws a series of connected lines (polyline).
  points: A table of Vec2 points to connect with lines.
  color: The color of the polyline.
  thickness: The thickness of the polyline.
Render.Circle(pos: Vec2, radius: number, color: Color, [thickness: number = 1.0], [startDeg: number = 0.0], [percentage: number = 1.0], [rounded: boolean = false], [segments: integer = 32])
  Draws a circle.
  pos: The center position of the circle.
  radius: The radius of the circle.
  color: The color of the circle.
  thickness: The thickness of the circle's outline.
  startDeg: The starting degree for drawing the circle. 0 is right side, 90 is bottom, 180 is left, 270 is top.
  percentage: The percentage of the circle to draw, in the range [0.0-1.0].
  rounded: Whether the circle is rounded.
  segments: The number of segments used for drawing the circle.
Render.FilledCircle(pos: Vec2, radius: number, color: Color, [startDeg: number = 0.0], [percentage: number = 1.0], [segments: integer = 32])
  Draws a filled circle.
  pos: The center position of the circle.
  radius: The radius of the circle.
  color: The color of the circle.
  startDeg: The starting degree for drawing the circle. 0 is right side, 90 is bottom, 180 is left, 270 is top.
  percentage: The percentage of the circle to draw, in the range [0.0-1.0].
  segments: The number of segments used for drawing the circle.
Render.CircleGradient(pos: Vec2, radius: number, colorOuter: Color, colorInner: Color, [startDeg: number = 0.0], [percentage: number = 1.0])
  Draws a circle with a gradient.
  pos: The center position of the circle.
  radius: The radius of the circle.
  colorOuter: The outer color of the gradient.
  colorInner: The inner color of the gradient.
  startDeg: The starting degree for drawing the circle. 0 is right side, 90 is bottom, 180 is left, 270 is top.
  percentage: The percentage of the circle to draw, in the range [0.0-1.0].
Render.Triangle(points: Vec2[], color: Color, [thickness: number = 1.0])
  Draws a triangle outline.
  points: A table of three Vec2 points defining the vertices of the triangle.
  color: The color of the triangle's outline.
  thickness: The thickness of the triangle's outline.
Render.FilledTriangle(points: Vec2[], color: Color)
  Draws a filled triangle.
  points: A table of three Vec2 points defining the vertices of the triangle.
  color: The color of the triangle.
Render.TexturedPoly(points: Vertex[], textureHandle: integer, color: Color, [grayscale: number = 0.0])
  Draws a textured polygon.
  points: A table of Vertex points defining the vertices of the polygon. Each Vertex contains a position (Vec2) and a texture coordinate (Vec2).
  textureHandle: The handle to the texture to be applied to the polygon.
  color: The color to apply over the texture. This can be used to tint the texture.
  grayscale: The grayscale of the image.
Render.LoadFont(fontName: string, [fontFlag: Enum.FontCreate|integer = Enum.FontCreate.FONTFLAG_NONE], [weight: integer = 400]) -> integer
  Loads a font and returns its handle. Returns handle to the loaded font.
  fontName: The name of the font to load.
  fontFlag: Flags for font creation, such as antialiasing.
  weight: The weight (thickness) of the font. Typically, 0 means default weight.
Render.Text(font: integer, fontSize: number, text: string, pos: Vec2, color: Color)
  Draws text at a specified position.
  font: The handle to the font used for drawing the text.
  fontSize: The size of the font.
  text: The text to be drawn.
  pos: The position where the text will be drawn.
  color: The color of the text.
Render.WorldToScreen(pos: Vector) -> Vec2, boolean
  Converts a 3D world position to a 2D screen position. Returns A Vec2 representing the 2D screen position and a boolean indicating visibility on the screen.
  pos: The 3D world position to be converted.
```lua
-- Example: Convert the center of the map (0,0,0) to screen coordinates.
local worldPos = Vector(0.0, 0.0, 0.0)
local screenPos, isVisible = Render.WorldToScreen(worldPos)
if isVisible then
    Log.Write("Screen Position: " .. screenPos.x .. ", " .. screenPos.y)
else
    Log.Write("Position is not visible on the screen")
end
```
Render.ScreenSize() -> Vec2
  Retrieves the current screen size, returning it as a Vec2 where x is the width and y is the height of the screen.
Render.TextSize(font: integer, fontSize: number, text: string) -> Vec2
  Calculates the size of the given text using the specified font, returning the size as a Vec2 where x is the width and y is the height of the text.
  font: The handle to the font used for measuring the text.
  fontSize: The size of the font.
  text: The text to measure.
Render.LoadImage(path: string) -> integer
  Loads an image and returns its handle.
  path: Path to the image.
Render.LoadSvg(path: string, size: Vec2) -> integer
  Loads svg image and returns its handle.
  path: Path to the image.
  size: Size of image to scale.
Render.LoadSvgString(svg: string, size: Vec2, cacheId: string) -> integer
  Loads svg image from string and returns its handle.
  svg: Svg text itself.
  size: Size of image to scale.
  cacheId: Texture of image creates only once for every unique cache id
Render.Image(imageHandle: integer, pos: Vec2, size: Vec2, color: Color, [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None], [uvMin: Vec2 = {0.0, 0.0}], [uvMax: Vec2 = {1.0, 1.0}], [grayscale: number = 0.0])
  Draws an image at a specified position and size.
  imageHandle: The handle to the image.
  pos: The position to draw the image.
  size: The size of the image.
  color: The color to tint the image.
  rounding: The rounding radius of the image corners.
  flags: Custom flags for drawing.
  uvMin: The minimum UV coordinates for texture mapping.
  uvMax: The maximum UV coordinates for texture mapping.
  grayscale: The grayscale of the image.
Render.ImageCentered(imageHandle: integer, pos: Vec2, size: Vec2, color: Color, [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None], [uvMin: Vec2 = {0.0, 0.0}], [uvMax: Vec2 = {1.0, 1.0}], [grayscale: number = 0.0])
  Draws an image centered at a specified position and size.
  imageHandle: The handle to the image.
  pos: The center position to draw the image.
  size: The size of the image.
  color: The color to tint the image.
  rounding: The rounding radius of the image corners.
  flags: Custom flags for drawing.
  uvMin: The minimum UV coordinates for texture mapping.
  uvMax: The maximum UV coordinates for texture mapping.
  grayscale: The grayscale of the image.
Render.ImageSize(imageHandle: integer) -> Vec2
  Retrieves the size of an image. Returns the size of the image as a Vec2.
  imageHandle: The handle to the image.
Render.OutlineGradient(start: Vec2, end_: Vec2, topLeft: Color, topRight: Color, bottomLeft: Color, bottomRight: Color, [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None], [thickness: number = 1.0])
  Draws a outlined gradient rectangle.
  start: The starting point of the gradient rectangle.
  end_: The ending point of the gradient rectangle.
  topLeft: The color of the top-left corner.
  topRight: The color of the top-right corner.
  bottomLeft: The color of the bottom-left corner.
  bottomRight: The color of the bottom-right corner.
  rounding: The rounding radius of the rectangle corners.
  flags: Custom flags for drawing.
  thickness: The thickness of the outline.
Render.Gradient(start: Vec2, end_: Vec2, topLeft: Color, topRight: Color, bottomLeft: Color, bottomRight: Color, [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None])
  Draws a filled gradient rectangle.
  start: The starting point of the gradient rectangle.
  end_: The ending point of the gradient rectangle.
  topLeft: The color of the top-left corner.
  topRight: The color of the top-right corner.
  bottomLeft: The color of the bottom-left corner.
  bottomRight: The color of the bottom-right corner.
  rounding: The rounding radius of the rectangle corners.
  flags: Custom flags for drawing.
Render.Shadow(start: Vec2, end_: Vec2, color: Color, thickness: number, [obj_rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.ShadowCutOutShapeBackground], [offset: Vec2 = {0.0, 0.0}])
  Draws a shadow effect within a specified rectangular area.
  start: The starting point of the shadow rectangle.
  end_: The ending point of the shadow rectangle.
  color: The color of the shadow.
  thickness: The thickness of the shadow.
  obj_rounding: The rounding radius of the shadow rectangle corners.
  flags: Custom flags for drawing the shadow.
  offset: The offset of the shadow from the original rectangle.
Render.ShadowCircle(center: Vec2, radius: number, color: Color, thickness: number, [num_segments: integer = 12], [flags: Enum.DrawFlags = Enum.DrawFlags.ShadowCutOutShapeBackground], [offset: Vec2 = {0.0, 0.0}])
  Draws a circle shadow effect.
  center: The center point of the circle.
  radius: The radius of the circle.
  color: The color of the shadow.
  thickness: The thickness of the shadow.
  num_segments: The number of segments for drawing the circle.
  flags: Custom flags for drawing the shadow.
  offset: The offset of the shadow from the circle.
Render.ShadowConvexPoly(points: Vec2[], color: Color, thickness: number, [flags: Enum.DrawFlags = Enum.DrawFlags.ShadowCutOutShapeBackground], [offset: Vec2 = {0.0, 0.0}])
  Draws a shadow convex polygon effect.
  points: Table of Vec2 points defining the convex polygon. Should be more than 2 points.
  color: The color of the shadow.
  thickness: The thickness of the shadow.
  flags: Custom flags for drawing the shadow.
  offset: The offset of the shadow from the polygon.
Render.ShadowNGon(center: Vec2, radius: number, color: Color, thickness: number, num_segments: integer, [flags: Enum.DrawFlags = Enum.DrawFlags.ShadowCutOutShapeBackground], [offset: Vec2 = {0.0, 0.0}])
  Draws a shadow n-gon (polygon with n sides) effect.
  center: The center point of the n-gon.
  radius: The radius of the n-gon.
  color: The color of the shadow.
  thickness: The thickness of the shadow.
  num_segments: The number of segments (sides) of the n-gon.
  flags: Custom flags for drawing the shadow.
  offset: The offset of the shadow from the n-gon.
Render.Blur(start: Vec2, end_: Vec2, [strength: number = 1.0], [alpha: number = 1.0], [rounding: number = 0.0], [flags: Enum.DrawFlags = Enum.DrawFlags.None])
  Applies a blur effect within a specified rectangular area.
  start: The starting point of the blur rectangle.
  end_: The ending point of the blur rectangle.
  strength: The strength of the blur effect.
  alpha: The alpha value of the blur effect.
  rounding: The rounding radius of the blur rectangle corners.
  flags: Custom flags for the blur effect.
Render.PushClip(start: Vec2, end_: Vec2, [intersect: boolean = false])
  Begins a new clipping region. Only the rendering within the specified rectangular area will be displayed.
  start: The starting point of the clipping rectangle.
  end_: The ending point of the clipping rectangle.
  intersect: If true, the new clipping area is intersected with the current clipping area.
Render.PopClip()
  Ends the most recently begun clipping region, restoring the previous clipping region.
Render.StartRotation(angle: number)
  Begins a new rotation.
  angle: The rotation angle.
Render.StopRotation()
  End the rotation.
Render.SetGlobalAlpha(alpha: number)
  ! Do not forget to reset the global alpha value after your rendering.
  Set the global alpha value for rendering.
  alpha: The alpha value to set [0..1]
Render.ResetGlobalAlpha()
  Reset the global alpha value for rendering to 1.0.
Render.CenteredNotification(text: string, duration: number)
  Draws a centered notification.
  text: Text to draw.
  duration: Duration of the notification.
Render.Logo(center: Vec2, radius: number, [angle: number = -45], [primary_color: Color = Menu.Style("primary")], [secondary_color: Color = {227, 227, 227, 255}])
  Draws umbrella logo
  angle: rotation angle
Render.FindOrCreateRT(name: string, [w: number = nil], [h: number = nil]) -> integer
  Creates a new render target or retrieves an existing one by name. If width or height are not provided, the render target will be full screen size.
  name: The unique name of the render target.
  w: The width of the render target. Optional.
  h: The height of the render target. Optional.
Render.MarkDirtyRT(handle: integer)
  Marks a render target as dirty, causing the next Render.RenderRT call to re-bake it. Safe across frame drops: the dirty state is only cleared once the bake is actually processed.
  handle: The handle of the render target.
Render.RenderRT(callback: fun():boolean?, handle: integer, pos: Vec2, color: Color, [scale: number = 1.0], [uvSizeMin: Vec2 = {0.0, 0.0}], [uvSizeMax: Vec2 = {0.0, 0.0}]) -> boolean
  Renders a cached render target texture at the given position. If the render target is dirty (see Render.MarkDirtyRT), the callback is invoked once inside a push/pop RT context to re-bake the texture content, then the baked texture is drawn at pos. If the render target is clean, only the cached texture is drawn. The callback receives no arguments and may return a boolean: returning true signals that the content is still updating (e.g. animation in progress).
  callback: The function containing rendering commands to bake into the render target.
  handle: The handle of the render target (from Render.FindOrCreateRT).
  pos: The screen position where the render target texture will be drawn.
  color: The color tint to apply when drawing the render target texture.
  scale: The scale factor for the render target.
  uvSizeMin: The minimum UV offset for texture mapping.
  uvSizeMax: The maximum UV offset for texture mapping.
```lua
-- render_target.lua
local rt_w, rt_h = 256, 80
local rt_handle = Render.FindOrCreateRT("example_rt", rt_w, rt_h)

local font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS | Enum.FontCreate.FONTFLAG_DROPSHADOW, 500)

local white  = Color(255, 255, 255, 255)
local bg     = Color(20, 20, 20, 220)
local accent = Color(80, 200, 120, 255)
local dim    = Color(160, 160, 160, 200)
local rt_pos = Vec2(100, 100)

-- Animation state
local anim_start = 0
local anim_duration = 0.6 -- seconds
local is_animating = false
local click_count = 0

-- Draw callback is invoked ONLY when the RT is dirty.
-- Returning true  tells the caller "content is still changing" (animation in progress).
-- Returning false tells the caller "content is now static" (bake is final).
-- The engine itself does NOT use this value — it is passed through as RenderRT's return.
local function draw_rt_content()
    local t = is_animating
        and math.min((os.clock() - anim_start) / anim_duration, 1.0)
        or 0

    Render.FilledRect(Vec2(0, 0), Vec2(rt_w, rt_h), bg)
    Render.FilledRect(Vec2(0, rt_h - 8), Vec2(t * rt_w, rt_h), accent)
    Render.Text(font, 14, "Clicks: " .. click_count, Vec2(10, 10), white)

    if t >= 1.0 then
        is_animating = false
    end

    return is_animating
end

return {
    OnDraw = function()
        -- Click inside the RT rect -> start a new animation
        if Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)
            and Input.IsCursorInRect(rt_pos.x, rt_pos.y, rt_w, rt_h) then
            click_count = click_count + 1
            anim_start = os.clock()
            is_animating = true
            Render.MarkDirtyRT(rt_handle)
        end

        -- RenderRT returns true when it baked AND the callback returned true.
        -- That means the animation is still playing, so mark dirty again
        -- to force another bake next frame.
        local still_updating = Render.RenderRT(draw_rt_content, rt_handle, rt_pos, white)
        if still_updating then
            Render.MarkDirtyRT(rt_handle)
        end

        -- Print current state below the RT rect
        local state = still_updating and "Redrawing (animation)" or "Cached (using RT)"
        Render.Text(font, 12, state, Vec2(rt_pos.x, rt_pos.y + rt_h + 4), dim)
    end
}
```
Render.ResizeRT(handle: integer, [w: number = nil], [h: number = nil])
  Resizes an existing render target. If width and height are not provided, it changes the render target to be full screen size. Accepts (handle, w, h), (handle, vec2), or (handle) for full screen.
  handle: The handle of the render target to resize.
  w: The new width, or a Vec2 containing both dimensions.
  h: The new height. Not used when Vec2 is provided.
