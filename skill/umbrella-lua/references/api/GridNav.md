# GridNav
Table to work with in-game navigation API.

GridNav.CreateNpcMap([excluded_npcs: CEntity[]|nil = nil], [includeTempTrees: boolean = true], [customCollisionSizes: table|nil = nil]) -> GridNavNpcMap
  ! You should always call GridNav.ReleaseNpcMap after you done with your build pathing
  Creates a new GridNavNpcMap
  excluded_npcs: table with npc to exclude from the map. for example you want to exclude local hero if you build path from local hero position
  includeTempTrees: true if you want include temp trees to the map e.g. furion's 1st spell, iron branch
  customCollisionSizes: table where key is entity userdata and value is {left, top, right, bottom} offsets from entity position
GridNav.ReleaseNpcMap(npc_map: GridNavNpcMap)
  Releases allocated memory for GridNavNpcMap
  npc_map: map to release to release
GridNav.IsTraversable(pos: Vector, [flag: number = 1], [flag_excluded: number = 2]) -> boolean, integer
  Returns true if the world position is traversable. Pass flag_excluded to replicate per-ability filter masks. Examples: * IsTraversable(pos, 0x1, 0x002) - default (engine BLOCKED only) * IsTraversable(pos, 0x1, 0x102) - Techies Land Mine semantics (LOCATION 0x002 + BUILDING 0x100) * IsTraversable(pos, 0x1, 0x112) - strictest variant used by many native AOE landing checks (LOCATION + PORTAL + BUILDING)
  pos: position to check
  flag: required cell flag mask (must be set)
  flag_excluded: forbidden cell flag mask (must be clear)
GridNav.BuildPath(start: Vector, end_: Vector, [ignoreTrees: boolean = false], [npc_map: GridNavNpcMap|nil = nil]) -> Vector[]
  Build path from start to end. Returns an array with builded positions.
  start: position to start
  end_: position to end
  ignoreTrees: true if you want to exclude static trees from the pathing
  npc_map: map with the npc's positions which works as additional mask for terrain map
```lua
-- build_path.lua
return {
    OnUpdate = function()
        local ignore_trees = false;
        local my_hero = Heroes.GetLocal();
        local start_pos = Entity.GetAbsOrigin(my_hero);
        local end_pos = Input.GetWorldCursorPos();

        -- create npc map with the temp trees but with no local hero in it
        local npc_map = GridNav.CreateNpcMap({Heroes.GetLocal()}, not ignore_trees);

        local path = GridNav.BuildPath(start_pos, end_pos, ignore_trees, npc_map);
        local prev_x, prev_y = nil, nil;
        for i, pos in pairs(path) do
            local x, y, visible = Renderer.WorldToScreen(pos);
            if (prev_x and visible) then
                Renderer.SetDrawColor(255, 255, 255, 255);
                Renderer.DrawLine(prev_x, prev_y, x, y);
            end
            prev_x, prev_y = x, y;
        end

        -- releasing allocated npc map after we done with build pathing
        GridNav.ReleaseNpcMap(npc_map)
    end
}
```
GridNav.IsTraversableFromTo(start: Vector, end_: Vector, [ignoreTrees: boolean = false], [npc_map: GridNavNpcMap|nil = nil]) -> boolean
  Lite version of GridNav.BuildPath function which just cheking if the path is exists.
  start: position to start
  end_: position to end
  ignoreTrees: true if you want to exclude static trees from the pathing
  npc_map: map with the npc's positions which works as additional mask for terrain map
GridNav.DebugRender([grid_range: integer = 50], [npc_map: GridNavNpcMap|nil = nil], [render_cell_flags: boolean = false]) -> boolean
  Debug render of current GridNav with GridNavNpcMap (if provided)
  grid_range: grid radius in "cell units" from Vector(0,0,0)
  npc_map: map with the npc's positions which works as additional mask for terrain map
  render_cell_flags: render the flags value for each not approachable cell (don't think you ever want to see this numbers, so ignore this arg)
