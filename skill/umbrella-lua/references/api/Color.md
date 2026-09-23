# Color
Color metatable
Поля: r: number (red), g: number (green), b: number (blue), a: number (alpha)

Color:__eq(other: Color) -> boolean
  Compares two colors for equality.
Color:Set(r: number, g: number, b: number, [a: number = 255]) -> Color
  Sets r, g, b, a components. Returns self for chaining.
Color:LerpInPlace(other: Color, t: number) -> Color
  Linearly interpolates this color towards other in-place. Returns self for chaining.
Color:IsZero([tolerance: number = 0.01]) -> boolean
  Returns true if all components are near zero within tolerance.
Color([r: number = 255], [g: number = 255], [b: number = 255], [a: number = 255]) -> Color
  Create a new Color.
Color(hex: string) -> Color
  Create a new Color from hex string.
  hex: Hex string. Do not use "#" symbol.
Color:AsFraction(r: number, g: number, b: number, a: number) -> Color
  Overwrites the color's ranges using the fraction values. Returns itself.
  r: New R color range as a percentage in the range [0.0, 1.0]
  g: New G color range as a percentage in the range [0.0, 1.0]
  b: New B color range as a percentage in the range [0.0, 1.0]
  a: New A color range as a percentage in the range [0.0, 1.0]
Color:AsInt(value: number) -> Color
  Overwrites the color's ranges converting the int value to RGBA values. Returns itself.
  value: int color value
Color:AsHsv(h: number, s: number, v: number, a: number) -> Color
  Overwrites the color's ranges converting the HSV to RGBA values. Returns itself.
  h: Hue color range [0.0, 1.0]
  s: Saturation color range [0.0, 1.0]
  v: Value color range [0.0, 1.0]
  a: Alpha color range [0.0, 1.0]
Color:AsHsl(h: number, s: number, l: number, a: number) -> Color
  Overwrites the color's ranges converting the HSL to RGBA values. Returns itself.
  h: Hue color range [0.0, 1.0]
  s: Saturation color range [0.0, 1.0]
  l: Lightness color range [0.0, 1.0]
  a: Alpha color range [0.0, 1.0]
Color:ToFraction() -> number, number, number, number
  Returns the r, g, b, and a ranges of the color as a percentage in the range of [0.0, 1.0].
Color:ToInt() -> number
  Returns the int value representing the color.
Color:ToHsv() -> number, number, number
  Returns the HSV representation of the color.
Color:ToHsl() -> number, number, number
  Returns the ToHsl representation of the color.
Color:ToHex() -> string
  Returns the hex string representing the color.
Color:Lerp(other: Color, weight: number) -> Color
  Returns the linearly interpolated color between two colors by the specified weight.
  other: The color to interpolate to
  weight: A value between 0 and 1 that indicates the weight of other
Color:Grayscale(weight: number) -> Color
  Returns the grayscaled color.
  weight: A value between 0 and 1 that indicates the weight of grayscale
Color:AlphaModulate(alpha: number) -> Color
  Returns the alpha modulated color.
  alpha: Alpha color range [0.0, 1.0]
Color:Clone() -> Color
  Creates and returns a copy of the color object.
Color:Unpack() -> number, number, number, number
  Returns the r, g, b, and a values of the color. Note that these fields can be accessed by indexing r, g, b, and a.
Color:__tostring() -> string
  Returns hex string representing the color.
