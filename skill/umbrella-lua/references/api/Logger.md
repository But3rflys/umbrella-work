# Logger
Named logger with per-level methods and per-logger level filtering. Messages are written to the debug log as [LEVEL] [LoggerName] message.

Logger(name: string) -> Logger
  Create a new Logger with the given name. Default level is DEBUG (all messages pass).
Logger:debug(...: any)
  Log a debug-level message. Arguments are converted to strings and joined with spaces.
Logger:info(...: any)
  Log an info-level message.
Logger:warning(...: any)
  Log a warning-level message.
Logger:error(...: any)
  Log an error-level message.
Logger:set_level(level: number)
  Set the minimum log level. Messages below this level are suppressed.
  level: Logger.DEBUG
Logger:get_level() -> number
  Get the current minimum log level.
Logger:get_name() -> string
  Get the logger name.
