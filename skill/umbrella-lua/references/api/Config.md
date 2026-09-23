# Config
Table to work with configs that are stored in the configs folder with the .ini extention. На деле значения пишутся не в configs/*.ini, а в %cheat_dir%/db.json под ключом "<config>.<key>".

Config.ReadInt(config: string, key: string, [def: integer = 0]) -> integer
  Read an integer from a config file.
  config: The config file name.
  key: The key to read.
  def: The default value to return if the key is not found.
Config.ReadFloat(config: string, key: string, [def: number = 0.0]) -> number
  Read a float from a config file.
  config: The config file name.
  key: The key to read.
  def: The default value to return if the key is not found.
Config.ReadString(config: string, key: string, [def: string = ""]) -> string
  Read a string from a config file.
  config: The config file name.
  key: The key to read.
  def: The default value to return if the key is not found.
Config.WriteInt(config: string, key: string, value: integer)
  Write an integer to a config file.
  config: The config file name.
  key: The key to write.
  value: The value to write.
Config.WriteFloat(config: string, key: string, value: number)
  Write a float to a config file.
  config: The config file name.
  key: The key to write.
  value: The value to write.
Config.WriteString(config: string, key: string, value: string)
  Write a string to a config file.
  config: The config file name.
  key: The key to write.
  value: The value to write.
