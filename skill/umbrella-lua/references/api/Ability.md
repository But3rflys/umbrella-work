# Ability
Table to work with CAbility. CAbility extends CEntity

Ability.GetOwner(ability: CAbility) -> CEntity|nil
  Returns the ability owner.
Ability.IsBasic(ability: CAbility) -> boolean
  Returns true if the ability is basic.
Ability.IsUltimate(ability: CAbility) -> boolean
  Returns true if the ability is an ultimate.
Ability.IsAttributes(ability: CAbility) -> boolean
  Returns true if the ability is an attribute or a talent.
Ability.GetType(ability: CAbility) -> Enum.AbilityTypes
  Returns the ability type.
Ability.GetBehavior(ability: CAbility, [from_static_data: boolean = false]) -> Enum.AbilityBehavior
  Returns the ability type.
  from_static_data: if true will check from ability static data
Ability.IsPassive(ability: CAbility, [from_static_data: boolean = false]) -> boolean
  Returns true if the ability is passive.
  from_static_data: if true will check from ability static data
Ability.GetTargetTeam(ability: CAbility, [from_static_data: boolean = false]) -> Enum.TargetTeam
  Returns the target team of this Ability.
  from_static_data: if true will check from ability static data
Ability.GetTargetType(ability: CAbility, [from_static_data: boolean = false]) -> Enum.TargetType
  Returns the target type of this Ability.
  from_static_data: if true will check from ability static data
Ability.GetTargetFlags(ability: CAbility) -> Enum.TargetFlags
  Returns the target flags of this Ability.
Ability.GetDamageType(ability: CAbility) -> Enum.DamageTypes
  Returns the damage type of this Ability.
Ability.GetImmunityType(ability: CAbility, [from_static_data: boolean = false]) -> Enum.ImmunityTypes
  Returns the immunity type of this Ability.
  from_static_data: if true will check from ability static data
Ability.GetDispellableType(ability: CAbility, [from_static_data: boolean = false]) -> Enum.DispellableTypes
  Returns the dispel type of this Ability.
  from_static_data: if true will check from ability static data
Ability.GetLevelSpecialValueFor(ability: CAbility, name: string, [lvl: integer = -1]) -> number
  WRONG API FIX ME IT MUST BE GetSpecialValueFor.
  name: Special value name. Can be found in the ability KV file. (assets/data/npc_abilities.json)
  lvl: Ability level, if -1 will automatically get lvl.
Ability.IsReady(ability: CAbility) -> boolean
  Returns true if the ability is ready to use.
Ability.SecondsSinceLastUse(ability: CAbility) -> number
  Returns the number of seconds passed from the last usage of the ability. Will return -1 if the ability is not on the cooldown.
Ability.GetDamage(ability: CAbility) -> number
  Returns the ability damage from assets/data/npc_abilities.json field. Will return 0.0 if the ability doesn't contain this field.
Ability.GetHealthCost(ability: CAbility) -> number
  Returns the ability's health cost.
Ability.GetLevel(ability: CAbility) -> integer
  Returns the current ability level.
Ability.GetCastPoint(ability: CAbility, [include_modifiers: boolean = true]) -> number
  Gets the cast delay of this Ability.
Ability.GetCastPointModifier(ability: CAbility) -> number
  Gets the cast delay modifier of this Ability.
Ability.IsCastable(ability: CAbility, [mana: number = 0.0]) -> boolean
  Returns true if the ability is currently castable. Checks for mana cost, cooldown, level, and slot for items.
Ability.IsChannelling(ability: CAbility) -> boolean
  Returns true if the ability is in channeling state. Example: teleport, rearm, powershot etc.
Ability.GetName(ability: CAbility) -> string
  Returns the ability name or empty string.
Ability.GetBaseName(ability: CAbility) -> string
  Returns the ability base name or empty string.
Ability.IsInnate(ability: CAbility) -> boolean
  Returns true if the ability is innate.
Ability.IsInnatePassive(ability: CAbility) -> boolean
  Returns true if the ability is passive innate.
Ability.GetMaxLevel(ability: CAbility) -> integer
  Returns ability's max level.
Ability.IsGrantedByFacet(ability: CAbility) -> boolean
  Returns true when abiliti is granted by facet.
Ability.CanBeExecuted(ability: CAbility) -> Enum.AbilityCastResult
  Returns -1 if ability can be executed.
Ability.IsOwnersManaEnough(ability: CAbility) -> boolean
  Returns true if enough mana for cast.
Ability.CastNoTarget(ability: CAbility, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil])
  Casts the ability that doesn't require a target or position.
  queue: Will add order to the cast queue.
  push: Will push order to the OnPrepareUnitOrders callback.
  execute_fast: Will push order to start of the order's list.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
Ability.CastPosition(ability: CAbility, pos: Vector, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil], [force_minimap: boolean = true])
  Casts the ability at a specified position.
  pos: Order position.
  queue: Will add order to the cast queue.
  push: Will push order to the OnPrepareUnitOrders callback.
  execute_fast: Will push order to start of the order's list.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
  force_minimap: If true, the order will be forced by the minimap if possible.
Ability.CastTarget(ability: CAbility, target: CNPC, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil])
  Casts the ability on a specified target.
  target: Order target.
  queue: Will add order to the cast queue.
  push: Will push order to the OnPrepareUnitOrders callback.
  execute_fast: Will push order to start of the order's list.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
Ability.Toggle(ability: CAbility, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil])
  Toggles the ability. Example: Armlet.
  queue: Will add order to the cast queue.
  push: Will push order to the OnPrepareUnitOrders callback.
  execute_fast: Will push order to start of the order's list.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
Ability.ToggleMod(ability: CAbility, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil])
  Toggles the ability modifier. Example: Frost Arrows, Medusa's Shield.
  queue: Will add order to the cast queue.
  push: Will push order to the OnPrepareUnitOrders callback.
  execute_fast: Will push order to start of the order's list.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
Ability.GetDefaultName(ability_name: string) -> string|nil
  Returns the default ability icon name from items_game.txt
Ability.CanBeUpgraded(ability: CAbility) -> boolean
  Returns if the ability is upgradable with a specific reason.
Ability.GetAbilityID(ability: CAbility) -> integer
  Returns ability id
Ability.GetIndex(ability: CAbility) -> integer
  Returns the index of the ability in the ability owner's list. The index can be used in NPC.GetAbilityByIndex later.
Ability.GetCastRange(ability: CAbility) -> number
  Returns the cast range of the ability.
Ability.IsHidden(ability: CAbility) -> boolean
  Returns true if ability is hidden. Example: Zeus's Nimbus before purchasing agh.
Ability.IsActivated(ability: CAbility) -> boolean
  Returns true if the ability is in an activated state.
Ability.GetDirtyButtons(ability: CAbility) -> integer
  Returns we don't know what :).
Ability.GetToggleState(ability: CAbility) -> boolean
  Returns if the ability is toggled. Example: Medusa's Shield.
Ability.IsInAbilityPhase(ability: CAbility) -> boolean
  Returns true if the ability is in the cast state. Examples: Nature's Prophet's Teleport, Meepo's Poof.
Ability.GetCooldown(ability: CAbility) -> number
  Returns the amount of time before the ability can be cast.
Ability.GetCooldownLength(ability: CAbility) -> number
  Returns the amount of time the ability couldn't be cast after being used.
Ability.GetManaCost(ability: CAbility) -> number
  Returns the ability mana cost.
Ability.GetAutoCastState(ability: CAbility) -> boolean
  Returns the autocast state of the ability.
Ability.GetAltCastState(ability: CAbility) -> boolean
  Returns the alt cast state of the ability. Example: Doom's Devour.
Ability.GetChannelStartTime(ability: CAbility) -> number
  Returns the gametime the channeling of the ability will start. Requires the ability to be in the cast state when called.
Ability.GetCastStartTime(ability: CAbility) -> number
  Returns the gametime the ability will be casted. Requires the ability to be in the cast state when called.
Ability.IsInIndefinateCooldown(ability: CAbility) -> boolean
  Returns true if the cooldown of the ability is indefinite.
Ability.IsInIndefinateCooldown(ability: CAbility) -> boolean
  Returns true if the cooldown of the ability is frozen.
Ability.GetOverrideCastPoint(ability: CAbility) -> number
  Returns the overridden cast point. Example: Arcane Blink.
Ability.IsStolen(ability: CAbility) -> boolean
  Returns true if the ability is stolen.
Ability.GetCurrentCharges(ability: CAbility) -> integer
  Returns the number of charges available.
Ability.ChargeRestoreTimeRemaining(ability: CAbility) -> integer
  Returns the remaining time for the next charge to restore.
Ability.GetKeybind(ability: CAbility) -> string
  Returns the keybind of the ability.
