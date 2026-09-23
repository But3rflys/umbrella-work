# StringBuilder
Efficient string builder for incremental string construction. Backed by a single pre-allocated C++ buffer. Avoids O(n^2) cost of repeated Lua string concatenation.

StringBuilder() -> StringBuilder
  Create a new StringBuilder with default capacity (256 bytes).
StringBuilder:append(...: any) -> StringBuilder
  Append values to the buffer. Each argument is converted to string (strings/numbers handled inline, others via tostring). Returns self for chaining.
StringBuilder:appendf(fmt: string, ...: any) -> StringBuilder
  Append formatted string with "{}" placeholders replaced left-to-right. Excess placeholders are kept literal. Returns self for chaining.
StringBuilder:clear() -> StringBuilder
  Clear the buffer contents. Retains allocated memory. Returns self for chaining.
StringBuilder:__tostring() -> string
  Returns the accumulated string.
StringBuilder:__len() -> number
  Returns the byte length of the buffer.
