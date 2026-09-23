# Panorama
Table to work with Dota Panorama system.

Panorama.GetPanelInfo(path: string[], [bLogError: boolean|nil = false], [useJsFunc: boolean|nil = false]) -> {x:number, y:number, w:number, h:number}
  Get panel info. GetPanelByName for first argument then FindChild others and accumulate x and y.
  path: Path to the panel.
  useJsFunc: Use js GetPositionWithinWindow function to get position.
Panorama.GetPanelByPath(path: string[], [bLogError: boolean = false]) -> UIPanel|nil
  Get panel by path.
  path: Path to the panel.
  bLogError: Log error if panel not found.
Panorama.GetPanelByName(id: string, is_type_name: boolean) -> UIPanel|nil
  Get panel by id.
  id: Id of the panel.
  is_type_name: Check type name instead of names.
Panorama.CreatePanel(type: string, id: string|nil, parent: UIPanel, classes: string|nil, styles: string|nil) -> UIPanel
  Creates a new panorama panel
  type: panel type to create
  id: id of the panel
  parent: parent panel
  classes: space separated classes to add
  styles: styles to set
```lua
-- create_panel.lua
function create_category()
	local panel = Panorama.GetPanelByPath({"DOTAHeroesPage", "HeroGrid", "Footer", "ViewModeControls", "Filters"}, true);
	if (not panel) then 
		print("not on hero grid page");
		return
	end;

	local filter_category = Panorama.CreatePanel("Panel", nil, panel, "FilterCategory")
	local filter_category_title = Panorama.CreatePanel("Label", nil, filter_category, "FilterCategoryTitle");
	filter_category_title:SetText("Filter");
	local items_panel = Panorama.CreatePanel("Panel", nil, filter_category, "FilterCategoryItems")
	items_panel:AddClasses("FilterCategoryItems")

	local button_styles = {
		["CrossButton"] = 'background-image: url("s2r://panorama/images/control_icons/purgatory_png.vtex");',
		["GearButton"] = 'background-image: url("s2r://panorama/images/control_icons/settings_png.vtex");',
	};
	local buttons = {}
	for id, style in pairs(button_styles) do
		buttons[id] = Panorama.CreatePanel("Button", id, items_panel, "FilterButton", style)
	end
	local button_id, button = next(buttons);

    -- set up the button events
	Engine.RunScript(([[
		(function(){
			let ctx = $.GetContextPanel();
			let button = ctx.FindChildTraverse("%s")
			let items_panel = button.GetParent();

			let children = items_panel.Children();
			let children_count = children.length;
			for (let i = 0; i < children_count; i++) {
				let item = children[i];
				item.SetPanelEvent("onmouseover", () => $.DispatchEvent("UIShowTextTooltipStyled", item, ("Button Id: " + item.id), "GameModeTooltip"));
				item.SetPanelEvent("onmouseout", () => $.DispatchEvent("UIHideTextTooltip", item));
				item.SetPanelEvent("onactivate", () => $.Msg(item.id + " was clicked!"));
			}
		})()
	]]):format(button_id), button)
end
create_category();
```
