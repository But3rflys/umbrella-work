# Protobuf
Protobuf encoding/decoding module for working with Dota 2 network messages. Loaded as a require-able library: local protobuf = require('protobuf'). Message type names correspond to protobuf definitions from Dota 2 Protobufs.

protobuf.encode(name: string, data: table) -> table
  Encodes a Lua table into a serialized protobuf message. Returns a table with binary (userdata pointer) and size (number) fields.
  name: Protobuf message type name
  data: Lua table with message fields
protobuf.encodeFromJSON(name: string, json: string) -> table
  Encodes a JSON string into a serialized protobuf message. Returns a table with binary (userdata pointer) and size (number) fields.
  name: Protobuf message type name
  json: JSON string representing the message
```lua
local protobuf = require('protobuf')
local JSON = require('assets.JSON')
local request = protobuf.encodeFromJSON('CMsgDOTAMatchmakingStatsRequest', JSON:encode({}))
GC.SendMessage(request.binary, 7197, request.size)
```
protobuf.decodeToJSON(name: string, binary: userdata, size: integer) -> string
  Decodes a serialized protobuf message (from a raw pointer) into a JSON string.
  name: Protobuf message type name
  binary: Pointer to serialized protobuf data
  size: Size of the serialized data in bytes
```lua
local response = protobuf.decodeToJSON('CMsgDOTAMatchmakingStatsResponse', msg.binary_buffer_recv, msg.size)
Log.Write(response)
```
protobuf.decodeToJSONfromString(name: string, base64data: string) -> string
  Decodes a base64-encoded protobuf message into a JSON string.
  name: Protobuf message type name
  base64data: Base64-encoded serialized protobuf data
protobuf.decodeToJSONfromObject(msg_object: userdata) -> string
  Decodes a protobuf message object directly into a JSON string. Useful with callback message objects that provide a direct protobuf pointer.
  msg_object: Protobuf message object pointer
protobuf.free(binary: userdata) -> boolean
  Frees memory allocated by encode or encodeFromJSON. Returns true on success.
  binary: Pointer to previously encoded protobuf data
