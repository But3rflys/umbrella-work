# Chat
Table to work with chat.

Chat.GetChannels() -> string[]
  Returns an array of channel names.
Chat.Print(channel: string, text: string)
  Print a message in a channel. This message will not be sent to the server.
  channel: The channel name to say the message in.
  text: The message to say.
Chat.Say(channel: string, text: string)
  Say a message in a channel.
  channel: The channel name to say the message in.
  text: The message to say.
Chat.Flip(channel: string)
  Flip the coin in a channel.
  channel: The channel name to flip the coin in.
Chat.Roll(channel: string, [min: number = 0], [max: number = 100])
  Roll a dice in a channel.
  channel: The channel name to roll the dice in.
  min: The minimum number to roll.
  max: The maximum number to roll.
