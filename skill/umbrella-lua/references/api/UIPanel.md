# UIPanel
UIPanel metatable

UIPanel:__tostring()
UIPanel:__eq(other: UIPanel) -> boolean
  ! Overload for operator ==.
UIPanel:FindChild(id: string) -> UIPanel|nil
  Finds child by ID.
  id: id of the child.
UIPanel:IsVisible() -> boolean
  Returns visible state.
UIPanel:SetVisible(newState: boolean)
  Sets visible state.
UIPanel:GetClassList() -> string[]
  Returns class name list.
UIPanel:FindChildInLayoutFile(id: string) -> UIPanel|nil
  ???.
UIPanel:FindPanelInLayoutFile(id: string) -> UIPanel|nil
  ???.
UIPanel:FindChildTraverse(id: string) -> UIPanel|nil
  Recursive find child by id.
UIPanel:FindChildWithClass(className: string) -> UIPanel|nil
  Finds first child with provided class name.
UIPanel:GetChildCount() -> integer
  Returns child by count.
UIPanel:GetChild(index: number) -> UIPanel|nil
  Returns child by index.
UIPanel:GetChildByPath(path: string[], [bLogError: boolean = false]) -> UIPanel|nil
  Returns child by path using FindChild.
  bLogError: Log error if panel not found.
UIPanel:GetChildIndex() -> integer
  Returns index in parent children list. Starts from 0.
UIPanel:GetFirstChild() -> UIPanel|nil
  Returns first child.
UIPanel:GetLastChild() -> UIPanel|nil
  Returns last child.
UIPanel:HasID() -> boolean
  Returns true if the panel has an id.
UIPanel:GetID() -> string
  Returns id of panel.
UIPanel:SetID(id: string)
  Sets the panel's id.
UIPanel:GetLayoutHeight() -> integer
  Returns the panel height.
UIPanel:GetLayoutWidth() -> integer
  Returns the panel width.
UIPanel:GetParent() -> UIPanel|nil
  Returns the panel's parent.
UIPanel:GetRootParent() -> UIPanel|nil
  Returns the panel's root parent. ???
UIPanel:GetXOffset() -> integer
  Returns the panel's relative X offset.
UIPanel:GetYOffset() -> integer
  Returns the panel's relative Y offset.
UIPanel:GetBounds([useJsFunc: boolean|nil = false]) -> {x:number, y:number, w:number, h:number}
  Returns the panel's bounds. Iterate over the parent hierarchy to get the absolute bounds.
  useJsFunc: Use js GetPositionWithinWindow function to get position.
UIPanel:GetImageSrc() -> string
  Return the panel source image.
UIPanel:GetPanelType() -> string
  Returns the panel's type.
UIPanel:BSetProperty(key: string, value: string) -> boolean
  Sets the panel property.
UIPanel:SetStyle(cssString: string) -> boolean
  Sets the panel style.
```lua
-- set_style.lua
local css_like_table = {
    ["horizontal-align"] = "center",
	["vertical-align"] = "center",
    ["transform"] = "translate3d( 0px, -0px, 0px ) scale3d(1, 1, 1)",
    ["padding-left"] = "0px",
    ["margin"] = "0px",
    ["border-radius"] = "4px",
    ["background-color"] = "none",
    ["box-shadow"] = "none",
    ["color"] = "gradient( linear, 0% 100%, 0% 0%, from( #ff00FF ), to( #5C9C68 ) )",
    ["font-size"] = "20px",
    ["text-align"] = "center",
    ["text-decoration"] = "none",
    ["background-size"] = "0% 0%",
    ["opacity-mask"] = 'url("s2r://panorama/images/masks/hudchat_mask_psd.vtex") 1.0',
    ["hue-rotation"] = "-10deg",
    ["text-shadow"] = "2px 2px #111111b0",
    ["blur"] = "gaussian(0px)",
    ["line-height"] = "120%",
    ["font-family"] = "Radiance",
    ["border-brush"] = "gradient( linear, 0% 0%, 0% 100%, from( #96c5ff96 ), to( #12142d2d ) )",
}


local function css_to_string(tbl)
    local str = ""
    for k, v in pairs(tbl) do
        str = str .. k .. ": " .. v .. "; "
    end
    return str;
end

local health_label = Panorama.GetPanelByName("HealthLabel");
if (health_label) then
    health_label:SetStyle(css_to_string(css_like_table))
end
```
UIPanel:SetAttribute(key: string, value: string)
  Sets the panel's attribute.
UIPanel:GetAttribute(key: string, default: string) -> string|nil
  Returns the panel's attribute.
UIPanel:GetPositionWithinWindow() -> Vec2
  Returns the panel's window position. Not sure about optimization.
UIPanel:GetText() -> string
  ! This method is only available for Label panels.
  Returns the label panel's text.
UIPanel:SetText(text: string)
  ! This method is only available for Label panels.
  Sets the label panel's text.
UIPanel:GetTextType() -> integer
  ! This method is only available for Label panels.
  Gets the label panel's text type. (2 = plain, 3 = html)
UIPanel:SetTextType(new: integer)
  ! This method is only available for Label panels.
  Sets the label panel's text type. (2 = plain, 3 = html). Should always set text type before setting the text
  new: value
```lua
label_panel:SetTextType(3)
label_panel:SetText("<font color='#8BFFD8'>Vitória</font>")
```
UIPanel:IsValid() -> boolean
  Checks if the panel is valid
UIPanel:HasClass(className: string) -> boolean
  Checks if the panel has a class.
  className: Class name.
UIPanel:AddClasses(classNames: string)
  Adds a class to the panel.
  classNames: Could be a space separated list of classes.
UIPanel:RemoveClasses(classNames: string)
  Removes a class to the panel.
  classNames: Could be a space separated list of classes.
