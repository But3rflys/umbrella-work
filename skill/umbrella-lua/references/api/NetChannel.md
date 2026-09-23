# NetChannel
Table to work with game's net channel.

NetChannel.GetLatency([flow: Enum.Flow = Enum.Flow.FLOW_OUTGOING]) -> number
  Returns the latency/ping of the net channel in seconds.
  flow: flow to get latency of
NetChannel.GetAvgLatency([flow: Enum.Flow = Enum.Flow.FLOW_OUTGOING]) -> number
  Returns the average latency/ping of the net channel in seconds.
  flow: flow to get average latency of
NetChannel.SendNetMessage(name: string, json: string) -> boolean
  ! You can repeat the same message from OnSendNetMessage if you want to know the format of the message.
  Sends a protobuff message to the game server. List of messages,
  name: name of the net message
  json: json of the net message
```lua
-- send_netmsg.lua
-- import json encoder
local JSON = require('assets.JSON');

-- https://github.com/SteamDatabase/GameTracking-Dota2/blob/master/Protobufs/dota_clientmessages.proto#L395
-- message CDOTAClientMsg_RollDice {
-- 	optional uint32 channel_type = 1;
-- 	optional uint32 roll_min = 2;
-- 	optional uint32 roll_max = 3;
-- }
NetChannel.SendNetMessage("CDOTAClientMsg_RollDice", JSON:encode({
    channel_type = 11, -- 11 - all chat
    roll_min = 11,
    roll_max = 222
}));
```
