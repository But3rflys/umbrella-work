# Event
Table to work with game events. When you install events, you send the subscribe message to the server, which is potentially unsafe. Therefore, you won't be able to install new listeners when you have unsafe features disabled in the Settings -> Security tab. The list of events can be found in the "pak01_dir.vpk" under "resource/game.gameevents."

Event.AddListener(name: string)
  Installs an event listener for the desired event.
  name: Event name
Event.IsReliable(event: CEvent) -> boolean
  Checks if the event is reliable.
Event.IsLocal(event: CEvent) -> boolean
  Checks if the event is local or networked.
Event.IsEmpty(event: CEvent) -> boolean
  Checks if the event is empty.
Event.GetBool(event: CEvent, field: string) -> boolean
  Returns the boolean value of the specified event field.
  field: Field name
Event.GetInt(event: CEvent, field: string) -> integer
  Returns the integer value of the specified event field.
  field: Field name
Event.GetUint64(event: CEvent, field: string) -> integer
  Returns the uint64 value of the specified event field.
  field: Field name
Event.GetFloat(event: CEvent, field: string) -> number
  Returns the floating value of the specified event field.
  field: Field name
Event.GetString(event: CEvent, field: string) -> string
  Returns the string value of the specified event field.
  field: Field name
