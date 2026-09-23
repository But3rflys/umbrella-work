# Player
Table to work with CPlayer. CPlayer extends CEntity

Player.PrepareUnitOrders(player: CPlayer, type: Enum.UnitOrder, target: CEntity|nil, pos: Vector, ability: CAbility|nil, issuer: Enum.PlayerOrderIssuer, issuer_npc: CNPC|CNPC[], [queue: boolean = false], [show_effects: boolean = false], [callback: boolean = false], [execute_fast: boolean = false], [identifier: string = nil], [force_minimap: boolean = true])
  Provides ability to execute such game actions as moving, attacking, or casting spells etc.
  player: The player issuing the order.
  type: The type of order to be issued.
  target: The target entity, if applicable.
  pos: The positional coordinates for the order.
  ability: The ability for order.
  issuer: The issuer capture mode.
  issuer_npc: The specific NPC or group of NPC that will issue the order.
  queue: If true, the order will be added to the Dota cast queue.
  show_effects: If true, visual effects will indicate the position of the order.
  callback: If true, the order will be pushed to the OnPrepareUnitOrders callback.
  execute_fast: If true, the order will bypass internal safety delays for immediate execution.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
  force_minimap: If true, the order will be forced by the minimap if possible.
Player.HoldPosition(player: CPlayer, issuer_npc: CNPC, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil])
  Sends the hold position action.
  player: The player issuing the order.
  issuer_npc: The specific NPC that will issue the order.
  queue: If true, the order will be added to the Dota cast queue.
  push: If true, the order will be pushed to the OnPrepareUnitOrders callback.
  execute_fast: If true, the order will bypass internal safety delays for immediate execution.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
Player.AttackTarget(player: CPlayer, issuer_npc: CNPC, target: CNPC, [queue: boolean = false], [push: boolean = false], [execute_fast: boolean = false], [identifier: string = nil], [force_minimap: boolean = true])
  Sends the attack target position.
  player: The player issuing the order.
  issuer_npc: The specific NPC that will issue the order.
  target: The target NPC.
  queue: If true, the order will be added to the Dota cast queue.
  push: If true, the order will be pushed to the OnPrepareUnitOrders callback.
  execute_fast: If true, the order will bypass internal safety delays for immediate execution.
  identifier: The identifier which will be passed to OnPrepareUnitOrders callback.
  force_minimap: If true, the order will be forced by the minimap if possible.
Player.GetPlayerID(player: CPlayer) -> integer
  Returns the player ID within the current game session. If the player ID is not valid, it will return -1.
  player: The target player.
Player.GetPlayerSlot(player: CPlayer) -> integer
  Returns the player slot number within the current game session.
  player: The target player.
Player.GetPlayerTeamSlot(player: CPlayer) -> integer
  Returns the team slot number assigned to the player within their respective team.
  player: The target player.
Player.GetName(player: CPlayer) -> string, string|nil
  Returns the player nickname and his proname
  player: The target player.
Player.GetProName(steamId: integer) -> string
  Returns cached player's proname. Works only in game callbacks
Player.GetPlayerData(player: CPlayer, [output: table = nil]) -> {valid:boolean, fullyJoined:boolean, fakeClient:boolean, connectionState:integer, steamid:integer, PlusSubscriber:boolean, MVPLastGame:boolean, PlayerName:string, ProName:string}
  Returns the player data table.
  player: The target player.
  output: Optional reusable table to populate instead of creating a new one.
Player.GetTeamData(player: CPlayer) -> {selected_hero_id:integer, kills:integer, assists:integer, deaths:integer, streak:integer, respawnTime:integer, selected_hero_variant:integer, lane_selection_flags:integer, last_buyback_time:number}
  Returns the player team data table. Team data is only available for players on the local team.
  player: The target player.
Player.GetNeutralStashItems(player: CPlayer) -> {item: CItem }[]
  Returns table with CItems available in the neutral stash.
  player: The target player.
Player.GetTeamPlayer(player: CPlayer, [output: table = nil]) -> {reliable_gold:integer, unreliable_gold:integer, starting_position:integer, totalearned_gold:integer, totalearned_xp:integer, shared_gold:integer, hero_kill_gold:integer, creep_kill_gold:integer, neutral_kill_gold:integer, courier_gold:integer, bounty_gold:integer, roshan_gold:integer, building_gold:integer, other_gold:integer, comeback_gold:integer, experimental_gold:integer, experimental2_gold:integer, creepdeny_gold:integer, tp_scrolls_purchased:integer, custom_stats:number, income_gold:integer, ward_kill_gold:integer, ability_gold:integer, networth:integer, deny_count:integer, lasthit_count:integer, lasthit_streak:integer, lasthit_multikill:integer, nearby_creep_death_count:integer, claimed_deny_count:integer, claimed_miss_count:integer, miss_count:integer, possible_hero_selection:integer, meta_level:integer, meta_experience:integer, meta_experience_awarded:integer, buyback_cooldown_time:number, buyback_gold_limit_time:number, buyback_cost_time:number, custom_buyback_cooldown:number, stuns:number, healing:number, tower_Kills:integer, roshan_kills:integer, camera_target:CEntity, override_selection_entity:CEntity, observer_wards_placed:integer, sentry_wards_placed:integer, creeps_stacked:integer, camps_stacked:integer, rune_pickups:integer, gold_spent_on_support:integer, hero_damage:integer, wards_purchased:integer, wards_destroyed:integer, commands_issued:integer, gold_spent_on_consumables:integer, gold_spent_on_items:integer, gold_spent_on_buybacks:integer, gold_lost_to_death:integer, is_new_player:boolean, is_guide_player:boolean, acquired_madstone:integer, current_madstone:integer, possible_hero_facet_selection:integer}
  Returns Team Player Data table
  player: The target player.
  output: Optional reusable table to populate instead of creating a new one.
Player.GetPlayerNeutralInfo(player: CPlayer) -> nil|{acquired_madstone:integer, current_madstone:integer, trinket_choices:integer[], enhancement_choices:integer[], selected_trinkets:integer[], selected_enhancements:integer[], times_crafted:integer[]}
  Returns info about player's neutral items
  player: The target player.
Player.IsMuted(player: CPlayer) -> boolean
  Returns the player mute status.
  player: The target player.
Player.GetSelectedUnits(player: CPlayer) -> CNPC[]
  Returns table of selected units by player.
  player: The target player.
Player.AddSelectedUnit(player: CPlayer, NPC: CNPC)
  Adds unit to player selection.
  player: The target player.
  NPC: To select.
Player.ClearSelectedUnits(player: CPlayer)
  Clears player selection.
  player: The target player.
Player.GetQuickBuyInfo(player: CPlayer) -> {m_quickBuyItems:integer[], m_quickBuyIsPurchasable:boolean[]}
  Returns table with m_quickBuyItems(item ids) and m_quickBuyIsPurchasable(table of booleans).
  player: The target player.
Player.GetCourierControllerInfo(player: CPlayer) -> {state:integer, shop:integer}
  Returns table with m_CourierController structure
  player: The target player.
Player.GetTotalGold(player: CPlayer) -> integer
  Returns total gold of player.
  player: The target player.
Player.GetAssignedHero(player: CPlayer) -> CHero|nil
  Returns player's assigned hero.
  player: The target player.
Player.GetActiveAbility(player: CPlayer) -> CAbility|nil
  Returns player's active ability.
  player: The target player.
