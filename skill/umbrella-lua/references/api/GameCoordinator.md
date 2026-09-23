# Game Coordinator
Table to work with Game Coordinator (GC). Possible message types and message bodies could be found at here Message type id starts with k_E prefix, for example k_EMsgGCMatchmakingStatsRequest = 7197;. Message body starts with with C prefix instead of "k_E", for example message CMsgDOTAMatchmakingStatsRequest {}.

GC.SendMessage(msg: userdata, msg_type: integer, msg_size: integer)
  Sends protobuff message to game coordinator. Response will be received in OnGCMessage callback.
  msg: Pointer to protobuf message buffer.
  msg_type: Protobuf message type ID.
  msg_size: Size of the protobuf message.
```lua
local protobuf = require('protobuf')
local JSON = require('assets.JSON')
local request = protobuf.encodeFromJSON('CMsgDOTAMatchmakingStatsRequest',
	                JSON:encode({}));
GC.SendMessage( request.binary, 7197, request.size )
```
GC.GetSteamID() -> string
  Returns local player Steam ID as string.
