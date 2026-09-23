# NPC
Table to work with CNPC. CNPC extends CEntity

NPC.GetOwnerNPC(npc: CNPC) -> CNPC|nil
  Returns owner of the CNPC. Works for spirit bear.
  npc: npc to get owner from
NPC.GetItem(npc: CNPC, name: string, [isReal: boolean = true]) -> CItem|nil
  Returns CItem by name.
  npc: npc to get item from
  name: name of the item
  isReal: if true, returns only 1-6 slots and neutral item, otherwise returns all items (including backpack and stash)
NPC.HasItem(npc: CNPC, name: string, [isReal: boolean = true]) -> boolean
  Returns true if the CNPC has item with specified name.
  npc: npc to check
  name: name of the item
  isReal: if true, returns only 1-6 slots and neutral item, otherwise returns all items (including backpack and stash)
NPC.HasModifier(npc: CNPC, name: string) -> boolean
  Returns true if the CNPC has modifier with specified name.
  npc: npc to check
  name: name of the modifier
NPC.GetModifier(npc: CNPC, name: string) -> CModifier|nil
  Returns CModifier by name.
  npc: npc to get modifier from
  name: name of the modifier
NPC.GetModifiers(npc: CNPC, [poperty_filter: Enum.ModifierFunction = Enum.ModifierFunction.MODIFIER_FUNCTION_INVALID]) -> CModifier[]
  ! poperty_filter doesnt filter all modifiers every call, it uses already prefiltered list.
  Returns an array of all NPC's CModifiers.
  npc: npc to get modifiers from
  poperty_filter: Filter modifiers by specified property
NPC.HasAnyModifier(npc: CNPC, names: string[]|table<string, boolean>) -> boolean
  Returns true if the NPC has any modifier from the given set. Accepts either an array {"mod_a", "mod_b"} or a hash set {mod_a = true, mod_b = true}. The hash set form is faster: O(M) hash lookups vs O(M*N) strcmp, where M = modifier count, N = names count.
NPC.GetModifierByIndex(npc: CNPC, index: integer) -> CModifier|nil
  Returns the modifier at the given 1-based index, or nil if out of range. Use with NPC.GetModifiers count or iterate until nil.
  index: 1-based index
NPC.HasInventorySlotFree(npc: CNPC, [isReal: boolean = true]) -> boolean
  Returns true if the CNPC has free inventory slot.
  npc: npc to check
  isReal: if true, returns only 1-6 slots and neutral item, otherwise returns all items (including backpack and stash)
NPC.HasState(npc: CNPC, state: Enum.ModifierState) -> boolean
  Returns true if the CNPC has state. The best way to check if the CNPC is stunned, silenced, hexed, has BKB immune etc.
  npc: npc to check
  state: state to check
NPC.GetStatesDuration(npc: CNPC, states: integer[], [only_active_states: boolean = true]) -> table
  Returns table of remaining modifier states duration. See the example
  npc: npc to check
  states: states to check
  only_active_states: if true then check only states that active on unit, otherwise check all states. e.g. rooted while debuff immune
```lua
local states_to_check = {
		[Enum.ModifierState.MODIFIER_STATE_STUNNED] = true,
		[Enum.ModifierState.MODIFIER_STATE_HEXED] = true,
}
local states = NPC.GetStatesDuration(unit, states_to_check)
local hex_duration = states[Enum.ModifierState.MODIFIER_STATE_HEXED]
local stun_duration = states[Enum.ModifierState.MODIFIER_STATE_STUNNED]
```
NPC.IsWaitingToSpawn(npc: CNPC) -> boolean
  Returns true if waiting to spawn. For example, creeps are waiting to spawn under the ground near the barracks.
  npc: npc to check
NPC.IsIllusion(npc: CNPC) -> boolean
  Returns true if the CNPC is illusion.
  npc: npc to check
NPC.IsVisible(npc: CNPC) -> boolean
  Returns true if the CNPC is visible to local player.
  npc: npc to check
NPC.IsVisibleToEnemies(npc: CNPC) -> boolean
  Returns true if the CNPC is visible enemies.
  npc: npc to check
NPC.IsCourier(npc: CNPC) -> boolean
  Returns true if the CNPC is a courier.
  npc: npc to check
NPC.IsRanged(npc: CNPC) -> boolean
  Returns true if the CNPC is a ranged unit.
  npc: npc to check
NPC.IsCreep(npc: CNPC) -> boolean
  Returns true if the CNPC is a creep.
  npc: npc to check
NPC.IsLaneCreep(npc: CNPC) -> boolean
  Returns true if the CNPC is a lane creep.
  npc: npc to check
NPC.IsStructure(npc: CNPC) -> boolean
  Returns true if the CNPC is a structure.
  npc: npc to check
NPC.IsTower(npc: CNPC) -> boolean
  Returns true if the CNPC is a tower.
  npc: npc to check
NPC.GetUnitType(npc: CNPC) -> Enum.UnitTypeFlags
  Returns unit type flags.
  npc: npc to check
NPC.IsConsideredHero(npc: CNPC) -> boolean
  Returns true if it is unit a considered a hero for targeting purposes.
  npc: npc to check
NPC.IsBarracks(npc: CNPC) -> boolean
  Returns true if the CNPC is a barracks.
  npc: npc to check
NPC.IsFort(npc: CNPC) -> boolean
  Returns true if the CNPC is the Ancient/Throne building (the win-condition structure). Distinct from IsAncient, which checks for ancient-tier neutral camps.
  npc: npc to check
NPC.IsBoss(npc: CNPC) -> boolean
  Returns true if the CNPC is a boss-like unit (TYPE_BOSS bit).
  npc: npc to check
NPC.IsTormentor(npc: CNPC) -> boolean
  Returns true if the CNPC is a Tormentor / mini-boss. Renders with the siege-wide healthbar (same as Roshan).
  npc: npc to check
NPC.IsAncient(npc: CNPC) -> boolean
  Returns true if the CNPC is an ancient creeps.
  npc: npc to check
NPC.IsRoshan(npc: CNPC) -> boolean
  Returns true if the CNPC is a Roshan.
  npc: npc to check
NPC.IsNeutral(npc: CNPC) -> boolean
  Returns true if the CNPC is a neutral. Neutral creeps, ancient creeps.
  npc: npc to check
NPC.IsHero(npc: CNPC) -> boolean
  Returns true if the CNPC is a hero.
  npc: npc to check
NPC.IsWard(npc: CNPC) -> boolean
  Returns true if the CNPC is a ward.
  npc: npc to check
NPC.IsMeepoClone(npc: CNPC) -> boolean
  Returns true if the CNPC is a meepo clone.
  npc: npc to check
NPC.IsEntityInRange(npc: CNPC, npc2: CNPC, range: number) -> boolean
  Returns true if the CNPC in range of other CNPC.
  npc: npc to check
  npc2: npc to check
  range: range to check
NPC.IsPositionInRange(npc: CNPC, pos: Vector, range: number, [hull: number = 0.0]) -> boolean
  Returns true if the CNPC in range of position.
  npc: npc to check
  pos: position to check
  range: range to check
  hull: hull just added to range
NPC.IsLinkensProtected(npc: CNPC) -> boolean
  Returns true if the CNPC is protected by Linkens Sphere.
  npc: npc to check
NPC.IsMirrorProtected(npc: CNPC) -> boolean
  Returns true if the CNPC is protected by Mirror Shield.
  npc: npc to check
NPC.IsChannellingAbility(npc: CNPC) -> boolean
  ! Do not work for items.
  Returns true if the CNPC is channeling ability. Black Hole, Life Drain, etc.
  npc: npc to check
NPC.GetChannellingAbility(npc: CNPC) -> CAbility|nil
  Returns the currently channelling CAbility.
  npc: target npc
NPC.IsRunning(npc: CNPC) -> boolean
  Returns true if the CNPC is running.
  npc: target npc
NPC.IsAttacking(npc: CNPC) -> boolean
  Returns true if the CNPC is attacking.
  npc: target npc
NPC.IsSilenced(npc: CNPC) -> boolean
  Returns true if the CNPC is silenced.
  npc: target npc
NPC.IsStunned(npc: CNPC) -> boolean
  Returns true if the CNPC is stunned.
  npc: target npc
NPC.HasAegis(npc: CNPC) -> boolean
  Returns true if the CNPC has aegis.
  npc: target npc
NPC.IsKillable(npc: CNPC) -> boolean
  Returns true if the CNPC has killable. Example: false if affected by Eul.
  npc: target npc
NPC.GetActivity(npc: CNPC) -> Enum.GameActivity
  Returns the CNPC activity, such as running, attacking, casting, etc.
  npc: target npc
NPC.GetAnimationInfo(npc: CNPC) -> {sequence:integer, cycle:number, name:string, mdl_name:string}
  Returns information about the current animation of the CNPC.
  npc: target npc
NPC.GetAttackRange(npc: CNPC) -> integer
  Returns the base attack range of the CNPC.
  npc: target npc
NPC.GetAttackRangeBonus(npc: CNPC) -> integer
  Returns the bonus attack range of the CNPC.
  npc: target npc
NPC.GetCastRangeBonus(npc: CNPC) -> integer
  Returns the bonus cast range of the CNPC.
  npc: target npc
NPC.GetPhysicalArmorValue(npc: CNPC, [excludeWhiteArmor: boolean = true]) -> number
  Returns the physical armor value of the CNPC.
  npc: target npc
  excludeWhiteArmor: exclude white armor
NPC.GetPhysicalDamageReduction(npc: CNPC) -> number
  Returns the physical damage reduction value of the CNPC.
  npc: target npc
NPC.GetArmorDamageMultiplier(npc: CNPC) -> number
  Returns the physical damage multiplier value of the CNPC.
  npc: target npc
NPC.GetMagicalArmorValue(npc: CNPC) -> number
  Returns the magical armor value of the CNPC.
  npc: target npc
NPC.GetMagicalArmorDamageMultiplier(npc: CNPC) -> number
  Returns the magical damage multiplier value of the CNPC.
  npc: target npc
NPC.GetIncreasedAttackSpeed(npc: CNPC, [ignore_temp_attack_speed: boolean = false]) -> number
  Returns increased attack speed of the CNPC.
  npc: target npc
  ignore_temp_attack_speed: ignore temporary attack speed
NPC.GetAttacksPerSecond(npc: CNPC, [ignore_temp_attack_speed: boolean = false]) -> number
  Returns the number of attacks per second that the CNPC can deal.
  npc: target npc
  ignore_temp_attack_speed: ignore temporary attack speed
NPC.GetAttackTime(npc: CNPC) -> number
  Returns the amount of time needed for the CNPC to perform an attack.
  npc: target npc
NPC.GetAttackSpeed(npc: CNPC, [ignore_temp_attack_speed: boolean = false]) -> number
  Returns the attack speed of the CNPC.
  npc: target npc
  ignore_temp_attack_speed: ignore temporary attack speed
NPC.GetBaseAttackSpeed(npc: CNPC) -> number
  Returns the base attack speed of the CNPC.
  npc: target npc
NPC.GetHullRadius(npc: CNPC) -> number
  Returns the model interaction radius of the CNPC.
  npc: target npc
NPC.GetPaddedCollisionRadius(npc: CNPC) -> number
  Returns the collision hull radius (including padding) of this NPC.
  npc: target npc
NPC.GetCollisionPadding(npc: CNPC) -> number
  Returns the collision including padding of this NPC.
  npc: target npc
NPC.GetPaddedCollisionRadius(npc: CNPC) -> number
  Returns the ring radius of this NPC.
  npc: target npc
NPC.GetProjectileCollisionSize(npc: CNPC) -> number
  ! see: <https://dota2.fandom.com/wiki/Unit\_Size#Collision\_Size>
  Returns the collision size of the CNPC. Collision size is the internal size that prevents other units from passing through.
  npc: target npc
NPC.GetTurnRate(npc: CNPC) -> number
  ! see: <https://dota2.fandom.com/wiki/Turn\_rate>
  Returns the turn rate, which is the speed at which the CNPC can turn.
  npc: target npc
NPC.GetAttackAnimPoint(npc: CNPC) -> number
  ! see: <https://dota2.fandom.com/wiki/Attack\_animation>
  Returns the attack animation point, nil if not found.
  npc: target npc
NPC.GetAttackProjectileSpeed(npc: CNPC) -> integer
  ! see: <https://dota2.fandom.com/wiki/Projectile\_Speed>
  Returns the attack projectile speed, nil if not found.
  npc: target npc
NPC.IsTurning(npc: CNPC) -> boolean
  Returns true if the CNPC is turning.
  npc: target npc
NPC.GetAngleDiff(npc: CNPC) -> integer
  ! doesn't work for creeps
  Returns the remaining degree angle needed to complete the turn of the CNPC.
  npc: target npc
NPC.GetPhysicalArmorMainValue(npc: CNPC) -> number
  Returns the (main) white armor of the CNPC.
  npc: target npc
NPC.GetTimeToFace(npc: CNPC, target: CNPC) -> number
  Returns the amount of time needed for the source CNPC to face the target CNPC.
  npc: source npc
  target: target npc
NPC.FindRotationAngle(npc: CNPC, pos: Vector) -> number
  Returns the rotation angle of the CNPC.
  npc: source npc
  pos: position to find the rotation angle
NPC.GetTimeToFacePosition(npc: CNPC, pos: Vector) -> number
  Returns the amount of time needed for the source CNPC to face a specific position.
  npc: source npc
  pos: target position
NPC.FindFacingNPC(npc: CNPC, ignoreNpc: CNPC, [team_type: Enum.TeamType = TEAM_BOTH], [angle: number = 0.0], [distance: number = 0.0]) -> CNPC|nil
  Returns the CNPC that the source CNPC is currently facing.
  npc: source npc
  ignoreNpc: ignore npc
  team_type: team type
  angle: max angle to check
  distance: max distance to check
NPC.GetBaseSpeed(npc: CNPC) -> integer
  Returns the base move speed of the CNPC.
  npc: target npc
NPC.GetMoveSpeed(npc: CNPC) -> number
  Returns the move speed of the CNPC.
  npc: target npc
NPC.GetMinDamage(npc: CNPC) -> number
  Returns the minumum attack damage of the CNPC.
  npc: target npc
NPC.GetBonusDamage(npc: CNPC) -> number
  Returns the bonus attack damage of the CNPC.
  npc: target npc
NPC.GetTrueDamage(npc: CNPC) -> number
  Returns the minumum attack damage + bonus damage of the CNPC.
  npc: target npc
NPC.GetTrueMaximumDamage(npc: CNPC) -> number
  Returns the maximum attack damage + bonus damage of the CNPC.
  npc: target npc
NPC.GetItemByIndex(npc: CNPC, index: integer) -> CItem|nil
  Returns the CItem by index.
  npc: target npc
  index: item index
NPC.GetAbilityByIndex(npc: CNPC, index: integer) -> CAbility|nil
  Returns the CAbility by index.
  npc: target npc
  index: ability index
NPC.GetAbilityByActivity(npc: CNPC, activity: Enum.GameActivity) -> CAbility|nil
  Returns the CAbility by game activity.
  npc: npc to get ability from
  activity: game activity
NPC.GetAbility(npc: CNPC, name: string) -> CAbility|nil
  Returns the CAbility by name.
  npc: target npc
  name: ability name
NPC.HasAbility(npc: CNPC, name: string) -> boolean
  Returns true if the CNPC has this ability.
  npc: target npc
  name: ability name
NPC.GetMana(npc: CNPC) -> number
  Returns the current mana of the CNPC.
  npc: target npc
NPC.GetMaxMana(npc: CNPC) -> number
  Returns the maximum mana of the CNPC.
  npc: target npc
NPC.GetManaRegen(npc: CNPC) -> number
  Returns the mana regeneration rate of the CNPC.
  npc: target npc
NPC.GetHealthRegen(npc: CNPC) -> number
  Returns the health regeneration rate of the CNPC.
  npc: target npc
NPC.CalculateHealthRegen(npc: CNPC) -> number
  ! Works for creeps but really slow.
  Iterate over all modifiers and returns the health regeneration rate of the CNPC.
  npc: target npc
NPC.GetCurrentLevel(npc: CNPC) -> number
  Returns the current level of the CNPC.
  npc: target npc
NPC.GetDayTimeVisionRange(npc: CNPC) -> integer
  Returns the day-time vision range of the CNPC.
  npc: target npc
NPC.GetNightTimeVisionRange(npc: CNPC) -> integer
  Returns the night-time vision range of the CNPC.
  npc: target npc
NPC.GetUnitName(npc: CNPC) -> string
  Returns the unit-name of the CNPC.
  npc: target npc
NPC.GetHealthBarOffset(npc: CNPC, [checkOverride: boolean = true]) -> integer
  Returns the health bar offset of the CNPC.
  npc: target npc
  checkOverride: returns override offset if it exists
NPC.GetUnitNameIndex(npc: CNPC) -> integer
  ! index can change when new unit are added
  Returns unit-name index of the CNPC.
  npc: target npc
NPC.GetAttachment(npc: CNPC, name: string) -> Vector
  Returns the attachment position of the CNPC by the name.
  npc: target npc
  name: attachment name. e.g. "attach_hitloc"
```lua
-- attachments.txt
attach_hitloc
attach_eye_r
attach_eye_l
attach_mouth
attach_totem
attach_head
attach_tidebringer
attach_tidebringer_2
attach_sword
attach_attack1
attach_weapon
attach_eyes
attach_prop_l
attach_prop_r
attach_light
attach_staff
attach_mouthbase
attach_mouthend
attach_mom_l
attach_mom_r
attach_attack2
attach_fuse
attach_mane
attach_tail
attach_upper_jaw
attach_weapon_core_fx
attach_bow_top
attach_bow_bottom
attach_bow_mid
attach_armor
attach_chimmney
attach_eyeR
attach_eyeL
attach_spine4
attach_spine5
attach_spine6
attach_spine7
attach_spine8
attach_spine9
attach_armlet_1
attach_armlet_2
attach_armlet_3
attach_armlet_4
attach_armlet_5
attach_vanguard_guard_1
attach_vanguard_guard_2
attach_weapon_offhand
attach_vanguard_1
attach_vanguard_2
attach_attack3
attach_attack4
attach_banner
attach_fx
attach_portcullis
attach_gem
```
NPC.GetAttachmentByIndex(npc: CNPC, index: integer) -> Vector
  Returns the attachment position of the CNPC by the specified index.
  npc: target npc
  index: attachment index
NPC.GetAttachmentIndexByName(npc: CNPC, name: string) -> integer
  Returns the attachment index of the CNPC by the name.
  npc: target npc
  name: attachment name. e.g. "attach_hitloc"
NPC.GetBountyXP(npc: CNPC) -> integer
  Returns the amount of experience points (XP) you can earn for killing the CNPC.
  npc: target npc
NPC.GetGoldBountyMin(npc: CNPC) -> integer
  Returns the minimum amount gold you can earn for killing the CNPC.
  npc: target npc
NPC.GetGoldBountyMax(npc: CNPC) -> integer
  Returns the maximum amount gold you can earn for killing the CNPC.
  npc: target npc
NPC.MoveTo(npc: CNPC, position: Vector, [queue: boolean = false], [show: boolean = false], [callback: boolean = false], [executeFast: boolean = false], [identifier: string = nil], [force_minimap: boolean = true])
  Initiates an order for the CNPC to move to a specified position.
  npc: The target NPC.
  position: The destination position.
  queue: Add the order to the Dota queue.
  show: Show the order position.
  callback: Push the order to the OnPrepareUnitOrders callback.
  executeFast: Place the order at the top of the queue.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
  force_minimap: If true, the order will be forced by the minimap if possible.
NPC.SetZDelta(npc: CNPC, z: number)
  Sets the Z position of the CNPC model.
  npc: The target NPC.
  z: Z pos
NPC.HasScepter(npc: CNPC) -> boolean
  Returns true if the CNPC has or consumed Aghanim Scepter.
  npc: The target NPC.
NPC.HasShard(npc: CNPC) -> boolean
  Returns true if the CNPC has or consumed Aghanim Shard.
  npc: The target NPC.
NPC.GetScepterUpgradeID(npc: CNPC) -> integer
  Returns index of selected scepter upgrade.
  npc: The target NPC.
NPC.GetShardUpgradeID(npc: CNPC) -> integer
  Returns index of selected shard upgrade.
  npc: The target NPC.
NPC.SequenceDuration(npc: CNPC, sequence: integer) -> number
  Returns sequence duration of the npc with the specified sequence index.
  npc: The target NPC.
  sequence: The sequence index.
NPC.GetSecondsPerAttack(npc: CNPC, bIgnoreTempAttackSpeed: boolean) -> number
  Returns the seconds per attack of the npc.
  npc: The target NPC.
  bIgnoreTempAttackSpeed: Ignore temporary attack speed.
NPC.GetBarriers(npc: CNPC) -> {physical:{total:number, current:number}, magic:{total:number, current:number}, all:{total:number, current:number}}
  Returns a table with information about the barriers of the CNPC.
  npc: The target NPC.
NPC.GetGlow(npc: CNPC) -> {m_bSuppressGlow:boolean, m_bFlashing:boolean, m_bGlowing:boolean, m_iGlowType:integer, r:integer, g:integer, b:integer}
  Returns a table with information about the current glow effect of the CNPC.
  npc: The target NPC.
NPC.SetGlow(npc: CNPC, suppress_glow: boolean, flashing: boolean, glowing: boolean, glow_type: integer, r: integer, g: integer, b: integer)
  Sets the CNPC glow effect.
  npc: The target NPC.
  suppress_glow: suppress_glow
  flashing: flashing
  glowing: glowing
  glow_type: glow type
  r: r factor
  g: g factor
  b: b factor
NPC.SetColor(npc: CNPC, r: integer, g: integer, b: integer)
  Sets the CNPC model color.
  npc: The target NPC.
  r: r factor
  g: g factor
  b: b factor
NPC.IsInRangeOfShop(npc: CNPC, shop_type: Enum.ShopType, [specific: boolean = false]) -> boolean
  Checks if the CNPC is in range of a shop.
  npc: The target NPC.
  shop_type: Shop type to check.
  specific: No idea what is that.
NPC.GetBaseSpellAmp(npc: CNPC) -> number
  Returns the base spell amplification of the CNPC.
  npc: The target NPC.
NPC.GetModifierProperty(npc: CNPC, property: Enum.ModifierFunction) -> number
  Returns the property value for the CNPC.
  npc: The target NPC.
  property: Property enum.
NPC.IsControllableByPlayer(npc: CNPC, playerId: integer) -> boolean
  Returns true if npc is controllable by player.
  npc: npc to check
  playerId: player id
NPC.GetModifierPropertyHighest(npc: CNPC, property: Enum.ModifierFunction) -> number
  ! Fixes the issue when you have multiple Kaya items that actually don't stack.
  Returns the hieghest property value for the CNPC.
  npc: The target NPC.
  property: Property enum.
