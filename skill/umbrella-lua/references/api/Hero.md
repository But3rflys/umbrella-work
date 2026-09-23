# Hero
Table to work with CHero. CHero extends CNPC

Hero.GetCurrentXP(hero: CHero) -> integer
  Returns the hero's current XP.
Hero.GetAbilityPoints(hero: CHero) -> integer
  Returns the hero's available ability points.
Hero.GetRespawnTime(hero: CHero) -> number
  ! Could be less than current game time if hero is already alive.
  Returns the game time when the hero will respawn.
Hero.GetRespawnTimePenalty(hero: CHero) -> number
  Returns the next respawn time penalty, e.g. buyback.
Hero.GetPrimaryAttribute(hero: CHero) -> Enum.Attributes
  Returns the hero's primary attribute type.
Hero.GetStrength(hero: CHero) -> number
  Returns white value of strength.
Hero.GetAgility(hero: CHero) -> number
  Returns white value of agility.
Hero.GetIntellect(hero: CHero) -> number
  Returns white value of intellect.
Hero.GetStrengthTotal(hero: CHero) -> number
  Returns total value of strength.
Hero.GetAgilityTotal(hero: CHero) -> number
  Returns total value of agility.
Hero.GetIntellectTotal(hero: CHero) -> number
  Returns total value of intellect.
Hero.GetLastHurtTime(hero: CHero) -> number
  Returns the time when the hero was last hurt.
Hero.GetHurtAmount(hero: CHero) -> number
  Returns the amount of damage the hero last received.
Hero.GetRecentDamage(hero: CHero) -> integer
  Returns the damage taken by the hero in the last in \~1 second.
Hero.GetPainFactor(hero: CHero) -> number
  Returns the pain factor of the hero. Not sure what it is.
Hero.GetTargetPainFactor(hero: CHero) -> number
  Returns the pain factor of the hero's target. Not sure what it is.
Hero.GetLifeState(hero: CHero) -> boolean
  Returns true if the hero is alive. Recommended to use Entity.IsAlive instead.
Hero.GetPlayerID(hero: CHero) -> integer
  Returns the ID of the hero player.
Hero.GetReplicatingOtherHeroModel(hero: CHero) -> CHero|nil
  If the hero is an illusion, Arc's copy, Meepo clone, etc. returns the original hero, otherwise returns nil.
Hero.TalentIsLearned(hero: CHero, talent: Enum.TalentTypes) -> boolean
  Returns true if talent is learned.
```lua
TALENT_8 <=> TALENT_7
TALENT_6 <=> TALENT_5
TALENT_4 <=> TALENT_3
TALENT_2 <=> TALENT_1
```
Hero.GetFacetAbilities(hero: CHero) -> CAbility[]
  Returns facet ability array.
Hero.GetFacetID(hero: CHero) -> integer
  Returns facet id. Start from 1.
Hero.GetLastMaphackPos(hero: CHero) -> Vector|nil
  Returns the last hero pos from maphack.
Hero.GetLastVisibleTime(hero: CHero) -> float|nil
  Returns the last visible time from VBE.
