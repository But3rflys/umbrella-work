# Modifier
Table to work with CModifier. You can get modifiers from NPC.GetModifierfunction.

Modifier.GetName(modifier: CModifier) -> string
  Returns the name of the modifier.
  modifier: modifier to get name of
Modifier.GetClass(modifier: CModifier) -> string
  Returns the name of the modifier's class.
Modifier.GetModifierAura(modifier: CModifier) -> string
  ! Deprecated.
  Should return the name of the modifier's aura, but instead, it returns an empty string in all the cases I have tested.
  modifier: modifier to get aura of
Modifier.GetSerialNumber(modifier: CModifier) -> integer
  ! Deprecated.
  Should return the serial number of the modifier, but instead, it returns 0 in all the cases I have tested.
  modifier: modifier to get serial number of
Modifier.GetStringIndex(modifier: CModifier) -> integer
  ! Deprecated.
  Should return the string index of the modifier, but instead, it returns 0 in all the cases I have tested.
  modifier: modifier to get string index of
Modifier.GetIndex(modifier: CModifier) -> GetIndex
  Returns the hero's modifier index. The index is an incrementable value with each new modifier the NPC gets
  modifier: modifier to get index of
Modifier.GetCreationTime(modifier: CModifier) -> number
  Returns the game time when the modifier was created.
  modifier: modifier to get creation time of
Modifier.GetCreationFrame(modifier: CModifier) -> integer
  Returns the frame when the modifier was created. You could get current frame count from GlobalVars.GetFrameCount function.
  modifier: modifier to get creation frame of
Modifier.GetLastAppliedTime(modifier: CModifier) -> number
  Returns the game time when the modifier was last applied. Don't know cases when it can be different from GetCreationTime.
  modifier: modifier to get last applied time of
Modifier.GetDuration(modifier: CModifier) -> number
  Returns the duration of the modifier.
  modifier: modifier to get duration of
Modifier.GetDieTime(modifier: CModifier) -> number
  Returns the game time when the modifier will expire.
  modifier: modifier to get expiration time of
Modifier.GetStackCount(modifier: CModifier) -> integer
  If there are stacks of the modifier, it returns the amount of stacks; otherwise, it returns 0\.
  modifier: modifier to get stack count of
Modifier.GetAuraSearchTeam(modifier: CModifier) -> integer
  ! Deprecated.
  Returns aura search team of the modifier.
  modifier: modifier to get aura search team of
Modifier.GetAuraSearchType(modifier: CModifier) -> integer
  ! Deprecated.
  Returns aura search type of the modifier.
  modifier: modifier to get aura search type of
Modifier.GetAuraSearchFlags(modifier: CModifier) -> integer
  ! Deprecated.
  Returns aura search flags of the modifier.
  modifier: modifier to get aura search flags of
Modifier.GetAuraRadius(modifier: CModifier) -> number
  ! Deprecated.
  Returns aura radius of the modifier.
  modifier: modifier to get aura radius of
Modifier.GetTeam(modifier: CModifier) -> Enum.TeamNum
  Returns team of the modifier.
  modifier: modifier to get team of
Modifier.GetAttributes(modifier: CModifier) -> integer
  ! Deprecated.
  Returns the attributes of the modifier.
  modifier: modifier to get attributes of
Modifier.IsAura(modifier: CModifier) -> boolean
  ! Deprecated.
  Returns true if the modifier is an aura.
  modifier: modifier to check
Modifier.IsAuraActiveOnDeath(modifier: CModifier) -> boolean
  ! Deprecated.
  Returns true if the modifier aura active on death.
  modifier: modifier to check
Modifier.GetMarkedForDeletion(modifier: CModifier) -> boolean
  ! Deprecated.
  Returns true if the modifier is marked for deletion.
  modifier: modifier to check
Modifier.GetAuraIsHeal(modifier: CModifier) -> boolean
  ! Deprecated.
  Returns true if aura is heal.
  modifier: modifier to check
Modifier.GetProvidedByAura(modifier: CModifier) -> boolean
  Returns true if modifier is provided by an aura.
  modifier: modifier to check
Modifier.GetPreviousTick(modifier: CModifier) -> number
  Returns the game time of the last modifier tick (\~0.033 seconds).
  modifier: modifier to get last tick time of
Modifier.GetThinkInterval(modifier: CModifier) -> number
  ! Deprecated.
  Returns the modifier's think interval.
  modifier: modifier to get think interval of
Modifier.GetThinkTimeAccumulator(modifier: CModifier) -> number
  ! Deprecated.
  Return the modifier's think interval time accumulator.
  modifier: modifier to get think time accumulator of
Modifier.IsCurrentlyInAuraRange(modifier: CModifier) -> boolean
  Returns true if is in aura range.
  modifier: modifier to check
Modifier.GetAbility(modifier: CModifier) -> CAbility|nil
  Returns the modifier's ability or nil if ability not in the cheat's ability list
  modifier: modifier to get ability of
Modifier.GetAuraOwner(modifier: CModifier) -> CEntity|nil
  Returns the owner of aura
  modifier: modifier
Modifier.GetParent(modifier: CModifier) -> CEntity|nil
  Returns the parent of modifier
  modifier: modifier
Modifier.GetCaster(modifier: CModifier) -> CEntity|nil
  Returns caster of modifier
  modifier: modifier
Modifier.GetState(modifier: CModifier) -> number, number
  Returns the modifier state masks. See the example.
  modifier: modifier to get state of
```lua
local m_nEnabledStateMask, m_nDisabledStateMask = Modifier.GetState(mod)
local mod_is_hex = (m_nEnabledStateMask >> Enum.ModifierState.MODIFIER_STATE_HEXED & 1) > 0
local mod_is_stun = (m_nEnabledStateMask >> Enum.ModifierState.MODIFIER_STATE_STUNNED & 1) > 0
```
Modifier.IsDebuff(modifier: CModifier) -> boolean
  Returns true if the modifier is a debuff.
  modifier: modifier to check
Modifier.GetField(modifier: CModifier, fieldName: string, [dbgPrint: boolean = false]) -> any
  Returns value of the field.
  modifier: modifier to get field from
  fieldName: field name
  dbgPrint: print possible errors
