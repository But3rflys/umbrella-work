# NPCs
Table to work with NPC list.

NPCs.Count() -> integer
  Return size of NPC list.
NPCs.Get(index: integer) -> CNPC|nil
  Return NPC by index in cheat list. Not the same as in-game index.
  index: Index of NPC in cheat list.
NPCs.GetAll([filter: Enum.UnitTypeFlags|fun(npc: CNPC):boolean = nil]) -> CNPC[]
  Return all NPCs in cheat list. Can be filtered by unit type or custom function. Unit type filter is a much faster than custom function and can be or'ed to filter multiple types.
```lua
-- filter function to get all structures except towers
for _, v in pairs(NPCs.GetAll(function (npc)
     return NPC.IsStructure(npc) and not NPC.IsTower(npc);
end)) do
     print(NPC.GetUnitName(v))
end

-- get all towers and heroes (x5 times faster than filter function)
for _, v in pairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_TOWER | Enum.UnitTypeFlags.TYPE_HERO)) do
		print(NPC.GetUnitName(v))
end
```
NPCs.GetInScreen([filter: Enum.UnitTypeFlags|nil = nil], [skipDormant: boolean = true]) -> {entity:CNPC, position:Vec2}[]
  Return all NPCs in cheat list that visible on your screen. Can be filtered by unit type argument.
  skipDormant: true if you want to get table without dormant units
NPCs.InRadius(pos: Vector, radius: number, teamNum: Enum.TeamNum, teamType: Enum.TeamType, [omitIllusions: boolean = false], [omitDormant: boolean = true]) -> CNPC[]
  Return all NPCs in radius.
  pos: Position to check.
  radius: Radius to check.
  teamNum: Team number to check.
  teamType: Team type to filter by. Relative to teamNum param.
  omitIllusions: true if you want to get table without illusions
  omitDormant: true if you want to get table without dormant units
NPCs.Contains(npc: CNPC) -> boolean
  Check NPC in cheat list.
  npc: NPC to check.
