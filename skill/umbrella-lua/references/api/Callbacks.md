# Callbacks
Callbacks for lua Scripts should return a table with the following functions. If the table contains one of the functions below, it will be registered as a callback and will be called at the appropriate time. Это ключи таблицы, которую возвращает скрипт: `function script.OnUpdate() end ... return script`. Если колбэк вернул false, событие (приказ, клавиша и т.п.) блокируется там, где это поддерживается.

OnScriptsLoaded()
  Called after all scripts are loaded.
OnDraw()
  Called when the game is drawing. Works only in the game. Recommended to use for drawing only.
OnFrame()
  The same as OnDraw, but called in the menu too.
OnUpdate()
  Called every game update. Works only in the game. Recommended to use for logic.
OnPreHumanizer()
  TODO
OnUpdateEx()
  Called every game update. Same as OnUpdate but as well called in the menu. Recommended to use for logic.
OnEntityCreate(entity: CEntity)
  Called when a new entity is created.
  entity: The entity that was created.
OnNpcSpawned(npc: CNpc)
  Called when a npc is spawned. Unlike OnAddEntity, the entity is fully initialized here.
  npc: The npc that was created.
OnEntityDestroy(entity: CEntity)
  Called when an entity is destroyed.
  entity: The entity that was destroyed.
OnModifierCreate(entity: CNPC, modifier: CModifier)
  Called when a modifier is created.
  entity: The entity that has the modifier.
  modifier: The modifier that was created.
OnModifierDestroy(entity: CNPC, modifier: CModifier)
  Called when a modifier is destroyed.
  entity: The entity that has the modifier.
  modifier: The modifier that was destroyed.
OnModifierUpdate(entity: CNPC, modifier: CModifier)
  Called when a modifier is updated/refreshed.
  entity: The entity that has the modifier.
  modifier: The modifier that was updated.
OnEntityHurt(data: {source:CEntity|nil, target:CEntity|nil, ability:CAbility|nil, damage:number})
  ! This callback is called only in unsafe mode.
  Called when an entity is hurt.
  data: The data about the event.
OnEntityKilled(data: {source:CEntity|nil, target:CEntity|nil, ability:CAbility|nil})
  ! This callback is called only in unsafe mode.
  Called when an entity is killed.
  data: The data about the event.
OnFireEventClient(data: {name:string, event:Event})
  ! This callback is called only in unsafe mode.
  Called when a game event is fired.
  data: The data about the event.
OnUnitAnimation(data: {unit: CNPC, sequenceVariant: number, playbackRate: number, castpoint: number, type: integer, activity: integer, sequence: integer, sequenceName: string, lag_compensation_time: number})
  Called when a unit animation is played.
  data: The data about the event.
  unit: The unit that played the animation.
  sequenceVariant: The sequence variant.
  playbackRate: The playback rate.
  castpoint: The castpoint.
  type: The type.
  activity: The activity.
  sequence: The sequence.
  sequenceName: The sequence name.
  lag_compensation_time: The lag compensation time.
OnUnitAnimationEnd(data: {unit: CNPC, snap: boolean})
  Called when a unit animation ends.
  data: The data about the event.
  unit: The unit that played the animation.
  snap: The snap.
OnProjectile(data: {source: CNPC, target: CNPC, ability: CAbility, moveSpeed: integer, sourceAttachment: integer, particleSystemHandle: integer, dodgeable: boolean, isAttack: boolean, expireTime: number, maxImpactTime: number, launch_tick: integer, colorGemColor: integer, fullName: string, name: string, handle: integer, target_loc: Vector, original_move_speed: integer})
  Called when new projectile is created.
  data: The data about the event.
  source: The source entity.
  target: The target entity.
  ability: The ability linked to the projectile.
  moveSpeed: The move speed.
  sourceAttachment: The source attachment.
  particleSystemHandle: The particle system handle.
  dodgeable: The dodgeable.
  isAttack: The is attack.
  expireTime: The expire time.
  maxImpactTime: The max impact time.
  launch_tick: The tick the pojectile was launched.
  colorGemColor: The color gem color.
  fullName: The full name of projectile.
  name: The short name of projectile.
  handle: The handle of projectile.
  target_loc: The location of the target.
  original_move_speed: The original move speed.
OnProjectileLoc(data: {target?: CNPC, sourceLoc: Vector, targetLoc: Vector, moveSpeed: integer, original_move_speed: integer, particleSystemHandle: integer, dodgeable: boolean, isAttack: boolean, expireTime: number, colorGemColor: integer, launchTick: integer, handle: integer, fullName: string, name: string})
  Called when new projectile loc is created.
  data: The data about the event.
  target: The source entity.
  sourceLoc: The source location.
  targetLoc: The target location.
  moveSpeed: The move speed.
  original_move_speed: The original move speed.
  particleSystemHandle: The particle system handle.
  dodgeable: The dodgeable.
  isAttack: The is attack.
  expireTime: The expire time.
  colorGemColor: The color gem color.
  launchTick: The launch tick.
  handle: The handle of projectile.
  fullName: The full name of projectile.
  name: The short name of projectile.
OnLinearProjectileCreate(data: {source: CNPC, origin: Vector, velocity: Vector, particleIndex: integer, handle: integer, acceleration: Vector, maxSpeed: number, fowRadius: number, distance: number, colorGemColor: integer, fullName: string, name: string})
  Called when new linear projectile is created.
  data: The data about the event.
  source: The source entity.
  origin: The origin.
  velocity: The velocity.
  particleIndex: The particle index.
  handle: The handle of projectile.
  acceleration: The acceleration.
  maxSpeed: The max speed.
  fowRadius: The fow radius.
  distance: The distance.
  colorGemColor: The color gem color.
  fullName: The full name of projectile.
  name: The short name of projectile.
OnLinearProjectileDestroy(data: {handle: integer})
  Called when linear projectile is destroyed.
  data: The data about the event.
  handle: The handle of projectile.
OnParticleCreate(data: {index: integer, entity?: CNPC, entity_id: integer, entityForModifiers?: CNPC, entity_for_modifiers_id: integer, attachType: Enum.ParticleAttachment, fullName: string, name: string, hash: integer, particleNameIndex: integer})
  Called when new particle is created.
  data: The data about the event.
  index: The index of particle.
  entity: The entity.
  entity_id: The entity id.
  entityForModifiers: The entity for modifiers.
  entity_for_modifiers_id: The entity for modifiers id.
  attachType: The attach type.
  fullName: The full name of particle.
  name: The short name of particle.
  hash: The hash of particle.
  particleNameIndex: The particle name index.
OnParticleUpdate(data: {index: integer, controlPoint: integer, position: Vector})
  Called when particle is updated.
  data: The data about the event.
  index: The index of particle.
  controlPoint: The control point.
  position: The position.
OnParticleUpdateFallback(data: {index: integer, controlPoint: integer, position: Vector})
  Called when particle is updated. Alternative version for some particles.
  data: The data about the event.
  index: The index of particle.
  controlPoint: The control point.
  position: The position.
OnParticleUpdateEntity(data: {index: integer, controlPoint: integer, entity: CEntity, entIdx: integer, attachType: Enum.ParticleAttachment, attachmentName: string, position: Vector, includeWearables: boolean})
  Called when particle is updated on entity.
  data: The data about the event.
  index: The index of particle.
  controlPoint: The control point.
  entity: The entity.
  entIdx: The entity id.
  attachType: The attach type.
  attachmentName: The attachment name.
  position: The position.
  includeWearables: Include wearables.
OnParticleDestroy(data: {index: integer, destroyImmediately: boolean})
  Called when particle is destroyed.
  data: The data about the event.
  index: The index of destroyed particle.
  destroyImmediately: Destroy immediately.
OnStartSound(data: {source?: CEntity, hash: integer, guid: integer, seed: integer, name: string, position: Vector})
  Called when sound is started.
  data: The data about the event.
  source: The source of sound.
  hash: The hash of sound.
  guid: The guid of sound.
  seed: The seed of sound.
  name: The name of sound.
  position: The position of sound.
OnSpeak(data: {source: CNPC|nil, name: string}) -> boolean
  Called every time unit/announcer talk. You could return false to prevent the sound from being played.
  data: The data about the event.
  source: The unit who speak.
  name: The name of the sound.
OnChatEvent(data: {type: integer, value: integer, value2: integer, value3: integer, playerid_1: integer, playerid_2: integer, playerid_3: integer, playerid_4: integer, playerid_5: integer, playerid_6: integer})
  Called on chat event.
  data: The data about the event.
  type: The type of chat event.
  value: The value of chat event.
  value2: The value2 of chat event.
  value3: The value3 of chat event.
  playerid_1: The playerid_1 of chat event.
  playerid_2: The playerid_2 of chat event.
  playerid_3: The playerid_3 of chat event.
  playerid_4: The playerid_4 of chat event.
  playerid_5: The playerid_5 of chat event.
  playerid_6: The playerid_6 of chat event.
OnOverHeadEvent(data: {player_source:CPlayer|nil, player_target:CPlayer|nil, target_npc:CNPC, value:integer})
  Called on event above the hero's head.
  data: The table with the event info.
OnUnitAddGesture(data: {npc?: CNPC, sequenceVariant: integer, playbackRate: number, fadeIn: number, fadeOut: number, slot: integer, activity: integer, sequenceName: string})
  Called when a unit is added to a gesture.
  data: The data about the event.
  npc: The unit that is added to a gesture.
  sequenceVariant: The sequence variant.
  playbackRate: The playback rate.
  fadeIn: The fade in.
  fadeOut: The fade out.
  slot: The slot.
  activity: The activity.
  sequenceName: The sequence name.
OnPrepareUnitOrders(data: {player: CPlayer, order: Enum.UnitOrder, target?: CEntity, position: Vector, ability?: CAbility, orderIssuer: Enum.PlayerOrderIssuer, npc: CNPC, queue: boolean, showEffects: boolean}) -> boolean
  Called on every player order. Return false to prevent the order from being executed.
  data: The data about the event.
  player: The player that issued the order.
  order: The order type.
  target: The target of the order.
  position: The position of the order.
  ability: The ability of the order.
  orderIssuer: The order issuer.
  npc: The unit of the order.
  queue: If the order is queued.
  showEffects: The show effects of the order.
OnGCMessage(data: {msg_type: number, size: number, binary_buffer_send?: userdata, binary_buffer_recv?: userdata}) -> boolean
  Called when a game coordinator protobuff message is received. Return false to prevent the message from being sent (doesnt work with recieved messages). For more look at GC table description.
  msg_type: The message type.
  size: The size of the message.
  binary_buffer_send: The binary buffer of the send message.
  binary_buffer_recv: The binary buffer of the recieved message.
```lua
-- ongc_message.lua
-- import protobuf and json libraries
local protobuf = require('protobuf');
local JSON = require('assets.JSON');

-- do the stats request
local request = protobuf.encodeFromJSON('CMsgDOTAMatchmakingStatsRequest', JSON:encode({}));
GC.SendMessage( request.binary, 7197, request.size );

return {
    OnGCMessage = function(msg)
        if (msg.msg_type ~= 7198) then
            return true;
        end

        -- decode the response and print it
        local response = protobuf.decodeToJSON('CMsgDOTAMatchmakingStatsResponse', msg.binary_buffer_recv, msg.size);
        Log.Write(response);

        return true;
    end
}
```
OnSendNetMessage(data: {message_id: number, message_name: string, buffer: lightuserdata, size: number}) -> boolean
  Called when a net message is sent. Return false to prevent the message from being sent. See example
  data: The data about the event.
  message_id: The message id.
  message_name: The message name.
  buffer: The encoded buffer of the message.
  size: The size of the message.
```lua
-- onsend_netmsg.lua
-- anti-mute script for dota 2
-- redirects all chat messages to console command 'say' or 'say_team'

-- import protobuf and json libraries
local protobuf = require('protobuf');
local JSON = require('assets.JSON');
return {
    OnSendNetMessage = function(msg)
        if msg.message_id ~= 394 then
            return true;
        end

        -- decode protobuf message to json
        local json_message = JSON:decode(protobuf.decodeToJSONfromObject(msg));
        if not json_message then
            return true;
        end

        -- message CDOTAClientMsg_ChatMessage {
        --     optional uint32 channel_type = 1;
        --     optional string message_text = 2;
        -- }

        local text_message = json_message.message_text;
        -- skip commands starting with '-'
        if text_message:find("-") == 1 then
            return true;
        end
    
        -- 11 - all chat 
        if (json_message.channel_type == 11) then
            Engine.ExecuteCommand('say "'..text_message..'"');
            return false;
        -- 12 - team chat
        elseif (json_message.channel_type == 12) then
            Engine.ExecuteCommand('say_team "'..text_message..'"');
            return false;
        end
    end
}
```
OnPostReceivedNetMessage(data: {message_id: number, msg_object: lightuserdata}) -> boolean
  Called when a net message is received. Return false to prevent the message from being recieved
  data: The data about the event.
  message_id: The message id.
  msg_object: The encoded buffer of the message.
```lua
-- onrecv_netmsg.lua
local protobuf = require('protobuf')
local JSON = require('assets.JSON')
return {
    OnPostReceivedNetMessage = function(msg)
        if msg.message_id == 612 then -- DOTA_UM_ChatMessage https://github.com/SteamDatabase/GameTracking-Dota2/blob/932a8b002f651262ffda6562b758d8ca97c98297/Protobufs/dota_usermessages.proto#L152
            local json = protobuf.decodeToJSONfromObject(msg.msg_object);
            Log.Write(json)
            local lua_table = JSON:decode(json)
            -- ...
        end
    end
}
```
OnGameEnd()
  Called on game end. Recommended to use for zeroing.
OnKeyEvent(data: {key: Enum.ButtonCode, event: Enum.EKeyEvent}) -> boolean
  Called on key and mouse input. Return false to prevent the event from being processed.
  data: The data about the event.
  key: The key code.
  event: Key event.
OnUnitInventoryUpdated(data: CNPC)
  Called on unit inventory updated.
  data: The data about the event.
OnSetDormant(npc: CNPC, type: Enum.DormancyType)
  Called on NPC dormancy state changed.
  npc: The target npc.
  type: The type of change.
OnGameRulesStateChange(data: {})
  Called on gamestate change.
  data: The table with new game state info.
OnNpcDying(npc: CNPC)
  Called on NPC dying.
  npc: The target npc.
OnThemeUpdate()
  Called when the UI theme colors are changed. This includes animated theme transitions (called every frame during animation) and manual per-color edits via the theme color picker.
