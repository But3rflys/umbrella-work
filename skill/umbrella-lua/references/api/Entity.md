# Entity
Table to work with CEntity. CEntity is base class for all entities in the game e.g. CNPC, Hero, CPlayer, CAbility

Entity.IsEntity(entity: CEntity) -> boolean
  Returns true if the entity is in entity list. Search in unordered set.
Entity.IsNPC(entity: CEntity) -> boolean
  Returns true if the entity is in NPC list. Search in unordered set.
Entity.IsHero(entity: CEntity) -> boolean
  Returns true if the entity is in hero list. Search in unordered set.
Entity.IsPlayer(entity: CEntity) -> boolean
  Returns true if the entity is in player list. Search in unordered set.
Entity.IsAbility(entity: CEntity) -> boolean
  Returns true if the entity is in ability list. Search in unordered set. Item is ability.
Entity.Get(index: integer) -> CEntity|nil
  ! Not the same as Entities.Get(index). See example.
  Returns entity by game index.
```lua
-- get_by_index.lua
local hero = Heroes.GetLocal();
local index = Entity.GetIndex(hero);
local entity_by_index = Entity.Get(index);
assert(hero == entity_by_index, "Entity.Get() is broken!"); -- true
```
Entity.GetIndex(entity: CEntity) -> integer
  Returns game index of entity.
Entity.GetClassName(entity: CEntity) -> string
  Returns the entity's class name.
Entity.GetUnitName(entity: CEntity) -> string
  Returns the entity's name.
Entity.GetUnitDesignerName(entity: CEntity) -> string
  Returns the entity's designerName field.
Entity.GetTeamNum(entity: CEntity) -> Enum.TeamNum
  Returns the entity's team number.
Entity.IsSameTeam(entity1: CEntity, entity2: CEntity) -> boolean
  Returns true if the entities are in the same team.
Entity.GetAbsOrigin(entity: CEntity) -> Vector
  Returns the entity's position.
Entity.GetNetOrigin(entity: CEntity) -> Vector
  Returns the entity's net position.
Entity.GetRotation(entity: CEntity) -> Angle
  Returns the entity's rotation.
```lua
-- forward_pos.lua
return {
    -- get local hero's forward position and draw a circle around it
    OnUpdate = function ()
        local hero = Heroes.GetLocal();
        local rotation = Entity.GetRotation(hero);
        -- forward_direction is a vector that points 100 units in direction of my hero's rotation
        local forward_direction = rotation:GetForward():Normalized():Scaled(100);
        -- add forward_direction to my hero's position to get the forward position
        local forward_pos = Entity.GetAbsOrigin(hero) + forward_direction;
        -- screen_x and screen_y are the coordinates of forward_pos on the screen
        local screen_x, screen_y, is_on_screen = Renderer.WorldToScreen(forward_pos);
        if is_on_screen then
            -- draw a circle around the position
            Renderer.SetDrawColor(255, 255, 255, 255);
            Renderer.DrawFilledCircle(screen_x, screen_y, 10, 10);
            -- result: https://i.imgur.com/ERf1Pxk.png
        end
    end
}
```
Entity.GetAbsOriginXYZ(entity: CEntity) -> number, number, number
  Returns the entity's position as three numbers (zero allocation).
Entity.GetRotationPYR(entity: CEntity) -> number, number, number
  Returns the entity's rotation as three numbers (zero allocation).
Entity.IsAlive(entity: CEntity) -> boolean
  Returns true if the entity is alive.
Entity.IsDormant(entity: CEntity) -> boolean
  Returns true if the entity is not visible to the local player.
Entity.GetHealth(entity: CEntity) -> integer
  Returns the entity's health.
Entity.GetMaxHealth(entity: CEntity) -> integer
  Returns the entity's max health.
Entity.GetOwner(entity: CEntity) -> CEntity|nil
  Returns the entity's owner or nil if the entity has no owner. e.g. for CPlayer -> npc_dota_hero_ember_spirit -> npc_dota_hero_ember_spirit_fire_remnant ownership chain Entity.GetOwner(remnant) will return Ember Spirit's entity.
Entity.OwnedBy(entity: CEntity, owner: CEntity) -> boolean
  Returns true if the entity is owned by another entity-owner. It will check the first owner only.
  entity: - entity to check
  owner: - owner for comparison
Entity.RecursiveGetOwner(entity: CEntity) -> CEntity|nil
  Returns the entity's last owner. e.g. for CPlayer -> npc_dota_hero_ember_spirit -> npc_dota_hero_ember_spirit_fire_remnant ownership chain Entity.GetOwner(remnant) will return CPlayer.
Entity.RecursiveOwnedBy(entity: CEntity, owner: CEntity) -> boolean
  Returns true if the entity is owned by another entity-owner. It will check the whole ownership chain.
  entity: entity to check
  owner: owner for comparison
Entity.GetHeroesInRadius(entity: CEntity, radius: number, [teamType: Enum.TeamType = TEAM_ENEMY], [omitIllusions: boolean = false], [omitDormant: boolean = true]) -> CHero[]
  Returns an array of all alive and visible heroes in radius of the entity. Exclude illusion.
  entity: entity to get position
  radius: radius to search around
  teamType: relative to the entity
  omitIllusions: true if you want to get table without illusions
  omitDormant: true if you want to get table without dormant units
```lua
local hero = Heroes.GetLocal()
-- get all enemy heroes in 1200 radius
local heroes_around = Entity.GetHeroesInRadius(hero, 1200)
for i = 1, #heroes_around do
	local hero = heroes_around[i];
	Log.Write(NPC.GetUnitName(hero) .. " is near!");
end
```
Entity.GetUnitsInRadius(entity: CEntity, radius: number, [teamType: Enum.TeamType = TEAM_ENEMY], [omitIllusions: boolean = false], [omitDormant: boolean = true]) -> CNPC[]
  Returns an array of all alive and visible NPCs in radius of the entity.
  entity: entity to get position
  radius: radius to search around
  teamType: relative to the entity
  omitIllusions: true if you want to get table without illusions
  omitDormant: true if you want to get table without dormant units
```lua
local hero = Heroes.GetLocal()
-- get all ally NPCs in 1200 radius
local units_around = Entity.GetUnitsInRadius(hero, 1200, Enum.TeamType.TEAM_FRIEND)
for i = 1, #units_around do
	local unit = units_around[i];
	Log.Write(NPC.GetUnitName(unit) .. " is near!");
end
```
Entity.GetTreesInRadius(entity: CEntity, radius: number, [active: boolean = true]) -> CTree[]
  ! Active means that tree is not destroyed.
  Returns an array of all not temporary trees in radius of the entity.
  entity: entity to get position
  radius: radius to search around
  active: true if you want to get table with active trees only, otherwise for inactive trees
```lua
local hero = Heroes.GetLocal()
-- get all trees in 400 radius
local trees_around = Entity.GetTreesInRadius(hero, 400, true)
for i = 1, #trees_around do
	local tree = trees_around[i];
	Log.Write(Entity.GetClassName(tree) .. " is near!");
end
```
Entity.GetTempTreesInRadius(entity: CEntity, radius: number) -> CTree[]
  ! Temporary trees are trees planted by abilities or items.
  Returns an array of all temporary trees in radius of the entity.
  entity: entity to get position
  radius: radius to search around
```lua
local hero = Heroes.GetLocal()
-- get all trees in 400 radius
local trees_around = Entity.GetTempTreesInRadius(hero, 400)
for i = 1, #trees_around do
	local tree = trees_around[i];
	Log.Write(Entity.GetClassName(tree) .. " is near!");
end
```
Entity.IsControllableByPlayer(entity: CEntity, playerId: integer) -> boolean
  Returns true if entity is controllable by player.
  entity: entity to check
  playerId: player id
Entity.GetRoshanHealth() -> integer
  Returns Roshan's health. Onyly works in unsafe mode.
Entity.GetForwardPosition(entity: CEntity, distance: number) -> Vector
  Returns position in front of entity or (0,0,0) if entity is invalid.
  entity: entity to get position
  distance: distance to move forward
Entity.GetClassID(entity: CEntity) -> integer
  Returns entity class id. Could be as a optimized way to check entity type.
  entity: entity to get class id
Entity.GetField(entity: CEntity, fieldName: string, [dbgPrint: boolean = false]) -> any
  Returns value of the field.
  entity: entity to get field from
  fieldName: field name
  dbgPrint: print possible errors
