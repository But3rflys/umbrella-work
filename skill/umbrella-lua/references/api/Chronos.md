# Chronos
High-resolution monotonic timer module. Loaded as a require-able library: local chronos = require('chronos'). Uses QueryPerformanceCounter on Windows for nanosecond-class precision.

chronos.nanotime() -> number
  Returns the current monotonic time in seconds with nanosecond precision. The returned value is relative to an unspecified epoch — only differences between two calls are meaningful.
```lua
local chronos = require('chronos')

local start = chronos.nanotime()
-- ... work ...
local elapsed = chronos.nanotime() - start
Log.Write("Elapsed: " .. tostring(elapsed) .. " seconds")
```
