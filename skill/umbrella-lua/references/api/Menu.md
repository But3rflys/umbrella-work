# Menu API
Классы меню и виджеты. Методы вызываются через двоеточие: widget:Get().

# Menu
Table to work with Menu.

Menu.Find(firstTabName: string, sectionName: string, secondTabName: string, thirdTabName: string, groupTabName: string, widgetName: string, attachmentName: string, widgetInGearName: string) -> CMenuSwitch|CMenuBind|CMenuSliderFloat|CMenuSliderInt|CMenuColorPicker|CMenuComboBox|CMenuButton|CMenuMultiComboBox|CMenuMultiSelect|CMenuInputBox|CMenuLabel|nil
  Returns menu item.
Menu.Create(firstTabName: string, sectionName: string, secondTabName: string, thirdTabName: string, groupTabName: string) -> CMenuGroup
  Creates tab/section/group. Returns menu item.
Menu.Style(styleColor: string) -> Color
  Creates tab/section/group. Returns color of specified style var or table of all style colors depends on param.
Menu.Opened() -> boolean
  Returns current menu open state.
Menu.VisualsIsEnabled() -> boolean
  Returns current visuals enabled state.
Menu.Alpha() -> number
  Returns current menu alpha.
Menu.Pos() -> Vec2
  Returns current menu pos.
Menu.Size() -> Vec2
  Returns current menu size.
Menu.Scale() -> integer
  Returns current menu scale percentage.
Menu.AnimDuration() -> number
  Returns current menu animation duration.

# CTabSection
CTabSection metatable

CTabSection:Name() -> string
  Returns tab's name.
CTabSection:Parent() -> CFirstTab
  Returns tab's parent.
CTabSection:Type() -> Enum.WidgetType
  Returns widget type.
CTabSection:Open()
  Opens parent tabs.
CTabSection:Create(sectionName: string) -> CSecondTab
  Creates new CSecondTab.
CTabSection:Find(sectionName: string) -> CSecondTab|nil
  Finds the CSecondTab by name.

# CFirstTab
CFirstTab metatable

CFirstTab:Name() -> string
  Returns tab's name.
CFirstTab:Parent()
  Returns parent. It's nil for CFirstTab.
CFirstTab:Type() -> Enum.WidgetType
  Returns widget type.
CFirstTab:Open()
  Opens parent tabs.
CFirstTab:Create(sectionName: string) -> CTabSection
  Creates new CTabSection.
CFirstTab:Find(sectionName: string) -> CTabSection|nil
  Finds the CTabSection by name.

# CSecondTab
CSecondTab metatable

CSecondTab:Name() -> string
  Returns tab's name.
CSecondTab:Parent() -> CTabSection
  Returns tab's parent.
CSecondTab:Type() -> Enum.WidgetType
  Returns widget type.
CSecondTab:Open()
  Opens parent tabs.
CSecondTab:Create(tabName: string) -> CThirdTab
  Creates new CThirdTab.
CSecondTab:Find(tabName: string) -> CThirdTab|nil
  Finds the CThirdTab by name.
CSecondTab:Image(imagePath: string, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's image.
  imagePath: Path to the image.
  offset: Optional image offset.
CSecondTab:ImageHandle(imageHandle: integer, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's image by already created handle.
  offset: Optional image offset.
CSecondTab:Icon(icon: string, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's icon. Icons list
  icon: icon unicode.
  offset: Optional icon offset.
```lua
-- https://fontawesome.com/icons/user?f=classic&s=solid
tab:Icon( "\u{f007}" )
```
CSecondTab:LinkHero(heroId: integer, attribute: Enum.Attributes)
  Links tab to hero and attribute.
  heroId: See Engine.GetHeroIDByName

# CThirdTab
CThirdTab metatable

CThirdTab:Name() -> string
  Returns tab's name.
CThirdTab:Parent() -> CSecondTab
  Returns tab's parent.
CThirdTab:Type() -> Enum.WidgetType
  Returns widget type.
CThirdTab:Open()
  Opens parent tabs.
CThirdTab:Create(groupName: string, [side: Enum.GroupSide = Enum.GroupSide.Default]) -> CMenuGroup
  Creates new CMenuGroup.
CThirdTab:Find(groupName: string) -> CMenuGroup|nil
  Finds the CMenuGroup by name.
CThirdTab:Image(imagePath: string, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's image.
  imagePath: Path to the image.
  offset: Optional image offset.
CThirdTab:ImageHandle(imageHandle: integer, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's image by already created handle.
  offset: Optional image offset.
CThirdTab:Visible(value: boolean)
  Gets or sets third tab's visible state. Depends on argument.
```lua
-- setter
third_tab:Visible(false)
```
CThirdTab:Visible() -> boolean
```lua
-- getter
local isVisible = third_tab:Visible()
```
CThirdTab:Icon(icon: string, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's icon. Icons list
  icon: icon unicode.
  offset: Optional icon offset.
```lua
-- https://fontawesome.com/icons/user?f=classic&s=solid
tab:Icon( "\u{f007}")
```

# CMenuGroup
CMenuGroup metatable

CMenuGroup:Name() -> string
  Returns group's name.
CMenuGroup:Parent() -> CThirdTab
  Returns group's parent.
CMenuGroup:Type() -> Enum.WidgetType
  Returns widget type.
CMenuGroup:Open()
  Opens parent tabs.
CMenuGroup:Find(widgetName: string) -> CMenuSwitch|CMenuBind|CMenuSliderFloat|CMenuSliderInt|CMenuColorPicker|CMenuComboBox|CMenuButton|CMenuMultiComboBox|CMenuMultiSelect|CMenuInputBox|CMenuLabel|nil
  Finds the widget by name.
CMenuGroup:Switch(switchName: string, [defaultValue: boolean = false], [imageIcon: string = ""]) -> CMenuSwitch
  Creates new CMenuSwitch.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGroup:Bind(bindName: string, [defaultValue: Enum.ButtonCode = Enum.ButtonCode.BUTTON_CODE_INVALID], [imageIcon: string = ""]) -> CMenuBind
  Creates new CMenuBind.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGroup:ForceLocalization(newText: string)
  ! Not recommended for use due to its complexity
  Changes text in the group header. The path to the widget is not affected. May be used for dynamic text customization or recolor.
CMenuGroup:Slider(sliderName: string, minValue: integer, maxValue: integer, defaultValue: integer, [format: string|fun(value: integer):string = "%d"]) -> CMenuSliderInt
  Creates new CMenuSliderInt or CMenuSliderFloat depents on arg types. minValue, maxValue and defaultValue should be integer to create CMenuSliderInt.
  format: Format string or function to format value. See example.
```lua
-- Create slider with integer values
group:Slider( "slider", 0, 100, 50, "%d" )
-- Create slider with integer values and custom format function
group:Slider( "slider", 0, 100, 50, function( value ) return "%d%%" end ) -- turns into
"50%"
```
CMenuGroup:Slider(sliderName: string, minValue: number, maxValue: number, defaultValue: number, [format: string|fun(value: number):string = "%f"]) -> CMenuSliderFloat
  Creates new CMenuSliderFloat.
  format: Format string or function to format value. See example.
```lua
-- Create slider with float values
group:Slider( "slider", 0.0, 1.0, 0.5, "%.2f" ) -- turns into "0.50"
-- Create slider with float values and custom format function
group:Slider( "slider", 0.0, 100.0, 50.0, function( value )
	if value < 50 then
		return "Low(%f)"
	else
		return "High(%f)"
  end
end )
```
CMenuGroup:ColorPicker(colorPickerName: string, color: Color, [imageIcon: string = ""]) -> CMenuColorPicker
  Creates new CMenuColorPicker.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGroup:Button(buttonName: string, callback: fun(this: CMenuButton):nil, [altStyle: boolean = false], [widthPercent: number = 1.0]) -> CMenuButton
  Creates new CMenuButton.
  callback: function to call on button click.
  altStyle: Use alternative button style.
  widthPercent: Button width in percents. [0.0, 1.0]
```lua
group:Button( "button", function( this )
	Log.Write( "Button '" .. this:Name() .. "' has been clicked."  )
end )
```
CMenuGroup:Combo(comboName: string, items: string[], [defaultValue: integer = 0]) -> CMenuComboBox
  Creates new CMenuComboBox.
  defaultValue: Index of default item. (starts from 0)
CMenuGroup:MultiCombo(multiComboName: string, items: string[], enabledItems: string[]) -> CMenuMultiComboBox
  Creates new CMenuMultiComboBox.
  enabledItems: table of enabled items
```lua
group:MultiCombo( "multiCombo", { "item1", "item2", "item3" }, { "item1", "item3" } )
```
CMenuGroup:MultiSelect(multiSelectName: string, items: {nameId: string, imagePath: string, isEnabled: boolean}[], [expanded: boolean = false]) -> CMenuMultiSelect
  Creates new CMenuMultiSelect.
  items: See example.
  expanded: false if you want to create MultiSelect in collapsed state.
```lua
group:MultiSelect( "multiSelect", {
 	{ "1", "panorama/images/heroes/icons/npc_dota_hero_antimage_png.vtex_c", false },
 	{ "2", "panorama/images/heroes/icons/npc_dota_hero_antimage_png.vtex_c", false },
}, true )
```
CMenuGroup:Input(inputName: string, defaultValue: string, [imageIcon: string = ""]) -> CMenuInputBox
  Creates new CMenuInputBox.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGroup:Label(labelText: string, [imageIcon: string = ""]) -> CMenuLabel
  Creates new CMenuLabel.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGroup:Disabled(value: boolean)
  Gets or sets group's disabled state. Depends on argument.
```lua
-- setter
group:Disabled( false )
```
CMenuGroup:Disabled() -> boolean
```lua
-- getter
local isDisabled = group:Disabled()
```
CMenuGroup:Visible(value: boolean)
  Gets or sets group's visible state. Depends on argument.
```lua
-- setter
group:Visible(false)
```
CMenuGroup:Visible() -> boolean
```lua
-- getter
local isVisible = group:Visible()
```
CMenuGroup:SearchHidden(value: boolean)
  Gets or sets group's search state. Depends on argument.
```lua
-- setter
group:SearchHidden(false)
```
CMenuGroup:SearchHidden() -> boolean
```lua
-- getter
local isSearchHidden = group:SearchHidden()
```

# CMenuGearAttachment
CMenuGearAttachment metatable.

CMenuGearAttachment:Name() -> string
  Returns widget's name.
CMenuGearAttachment:Parent() -> CMenuSwitch|CMenuSliderInt|CMenuSliderFloat|CMenuMultiComboBox|CMenuLabel|CMenuInputBox|CMenuComboBox|CMenuBind
  Returns widget's parent.
CMenuGearAttachment:Type() -> Enum.WidgetType
  Returns widget type.
CMenuGearAttachment:Open()
  Opens parent tabs.
CMenuGearAttachment:ForceLocalization(newText: string)
  ! Not recommended for use due to its complexity
  Changes text in the widget. The path to the widget is not affected. May be used for dynamic text customization or recolor.
CMenuGearAttachment:Find(widgetName: string) -> CMenuSwitch|CMenuBind|CMenuSliderFloat|CMenuSliderInt|CMenuColorPicker|CMenuComboBox|CMenuMultiComboBox|CMenuMultiSelect|CMenuInputBox|CMenuLabel|nil
  Finds the widget by name.
CMenuGearAttachment:Switch(switchName: string, [defaultValue: boolean = false], [imageIcon: string = ""]) -> CMenuSwitch
  Creates new CMenuSwitch.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGearAttachment:Bind(bindName: string, [defaultValue: Enum.ButtonCode = Enum.ButtonCode.BUTTON_CODE_INVALID], [imageIcon: string = ""]) -> CMenuBind
  Creates new CMenuBind.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGearAttachment:Slider(sliderName: string, minValue: integer, maxValue: integer, defaultValue: integer, [format: string|fun(value: integer):string = "%d"]) -> CMenuSliderInt
  Creates new CMenuSliderInt or CMenuSliderFloat depents on arg types. minValue, maxValue and defaultValue should be integer to create CMenuSliderInt.
  format: Format string or function to format value. See example.
```lua
-- Create slider with integer values
gear:Slider( "slider", 0, 100, 50, "%d" )
-- Create slider with integer values and custom format function
gear:Slider( "slider", 0, 100, 50, function( value ) return "%d%%" end ) -- turns into
"50%"
```
CMenuGearAttachment:Slider(sliderName: string, minValue: number, maxValue: number, defaultValue: number, [format: string|fun(value: number):string = "%f"]) -> CMenuSliderFloat
  Creates new CMenuSliderFloat.
  format: Format string or function to format value. See example.
```lua
-- Create slider with float values
gear:Slider( "slider", 0.0, 1.0, 0.5, "%.2f" ) -- turns into "0.50"
-- Create slider with float values and custom format function
gear:Slider( "slider", 0.0, 100.0, 50.0, function( value )
	if value < 50 then
		return "Low(%f)"
	else
		return "High(%f)"
  end
end )
```
CMenuGearAttachment:ColorPicker(colorPickerName: string, color: Color, [imageIcon: string = ""]) -> CMenuColorPicker
  Creates new CMenuColorPicker.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGearAttachment:Button(buttonName: string, callback: fun(this: CMenuButton):nil, [altStyle: boolean = false], [widthPercent: number = 1.0]) -> CMenuButton
  Creates new CMenuButton.
  callback: function to call on button click.
  altStyle: Use alternative button style.
  widthPercent: Button width in percents. [0.0, 1.0]
```lua
gear:Button( "button", function( this )
	Log.Write( "Button '" .. this:Name() .. "' has been clicked."  )
end )
```
CMenuGearAttachment:Combo(comboName: string, items: string[], [defaultValue: integer = 0]) -> CMenuComboBox
  Creates new CMenuComboBox.
  defaultValue: Index of default item. (starts from 0)
CMenuGearAttachment:MultiCombo(multiComboName: string, items: string[], enabledItems: string[]) -> CMenuMultiComboBox
  Creates new CMenuMultiComboBox.
  enabledItems: table of enabled items
```lua
gear:MultiCombo( "multiCombo", { "item1", "item2", "item3" }, { "item1", "item3" } )
```
CMenuGearAttachment:MultiSelect(multiSelectName: string, items: {nameId: string, imagePath: string, isEnabled: boolean}[], [expanded: boolean = false]) -> CMenuMultiSelect
  Creates new CMenuMultiSelect.
  items: See example.
  expanded: false if you want to create MultiSelect in collapsed state.
```lua
gear:MultiSelect( "multiSelect", {
 	{ "1", "panorama/images/heroes/icons/npc_dota_hero_antimage_png.vtex_c", false },
 	{ "2", "panorama/images/heroes/icons/npc_dota_hero_antimage_png.vtex_c", false },
}, true )
```
CMenuGearAttachment:Input(inputName: string, [defaultValue: string = ""], [imageIcon: string = ""]) -> CMenuInputBox
  Creates new CMenuInputBox.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGearAttachment:Label(labelText: string, [imageIcon: string = ""]) -> CMenuLabel
  Creates new CMenuLabel.
  imageIcon: Path to image or FontAwesome icon unicode.
CMenuGearAttachment:Visible(value: boolean)
  Gets or sets visible state. Depends on argument.
```lua
-- setter
widget:Visible(false)
```
CMenuGearAttachment:Visible() -> boolean
```lua
-- getter
local isVisible = widget:Visible()
```
CMenuGearAttachment:Disabled(value: boolean)
  Gets or sets disabled state. Depends on argument.
```lua
-- setter
widget:Disabled( false )
```
CMenuGearAttachment:Disabled() -> boolean
```lua
-- getter
local isDisabled = widget:Disabled()
```

# Общие методы виджетов
Есть у большинства виджетов. У каждого виджета ниже перечислено, какие из общих у него есть, и его собственные методы.

:Name() -> string
  Returns widget's name.
:Parent() -> CMenuGroup|CMenuGearAttachment
  Returns widget's parent.
:Open()
  Opens parent tabs.
:ForceLocalization(newText: string)
  ! Not recommended for use due to its complexity
  Changes text in the widget. The path to the widget is not affected. May be used for dynamic text customization or recolor.
:ToolTip(newText: string) -> string
  Gets or sets tooltip. Tooltip is displayed when mouse cursor is over the widget. Depends on the argument.
:ToolTip() -> string
:Visible(value: boolean)
  Gets or sets visible state. Depends on argument.
```lua
-- setter
widget:Visible(false)
```
:Visible() -> boolean
```lua
-- getter
local isVisible = widget:Visible()
```
:Disabled(value: boolean)
  Gets or sets disabled state. Depends on argument.
```lua
-- setter
widget:Disabled( false )
```
:Disabled() -> boolean
```lua
-- getter
local isDisabled = widget:Disabled()
```
:Unsafe(value: boolean)
  Gets or sets unsafe state. Unsafe widgets have warning sign. Depends on argument.
:Unsafe() -> boolean
:Image(imagePath: string, [offset: Vec2 = {0.0, 0.0}])
  Sets widget's image.
  imagePath: Path to the image.
  offset: Optional image offset.
:ImageHandle(imageHandle: integer, [offset: Vec2 = {0.0, 0.0}])
  Sets tab's image by already created handle.
  offset: Optional image offset.
:Icon(icon: string, [offset: Vec2 = {0.0, 0.0}])
  Sets widget's icon. Icons list
  icon: icon unicode.
  offset: Optional icon offset.
```lua
--https://fontawesome.com/icons/user?f=classic&s=solid
switch:Icon("\u{f007}")
```
:ColorPicker(name: string, color: Color) -> CMenuColorPickerAttachment
  Creates CMenuColorPickerAttachment and attaches it to the widget.
  name: Name of the attachment.
  color: Default color.
:Gear(name: string, [gearIcon: string = "\uf013"], [useSmallFont: boolean = true]) -> CMenuGearAttachment
  Creates CMenuGearAttachment and attaches it to the widget.
  name: Name of the attachment.
  gearIcon: Gear FontAwesome icon.
  useSmallFont: Use small font for gear icon.
:Type() -> Enum.WidgetType
  Returns widget type.

# CMenuBind
CMenuBind metatable.
Общие: Name, Parent, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuBind:Type() -> Enum.WidgetType
  Returns widget's type.
CMenuBind:Get([idx: 0|1 = 0]) -> Enum.ButtonCode
  Returns widget's value. To get both of the buttons use Buttons method.
  idx: index of the button to get value from
CMenuBind:Set(key1: Enum.ButtonCode, [key2: Enum.ButtonCode = Enum.ButtonCode.KEY_NONE])
  Sets widget's value.
  key1: primary button code
  key2: secondary button code
CMenuBind:Buttons() -> Enum.ButtonCode, Enum.ButtonCode
  Returns widget's buttons value.
CMenuBind:IsDown() -> boolean
  Returns true when the key or both keys is down.
CMenuBind:IsPressed() -> boolean
  Returns true when the key or both keys is pressed for the first time.
CMenuBind:IsToggled() -> boolean
  Bind stores it's toggle state and switches it when the key is pressed. This method returns this state.
CMenuBind:SetToggled(value: boolean)
  Sets the toggle state manually.
CMenuBind:SetCallback(callback: fun(this: CMenuBind):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuBind:UnsetCallback(callback: fun(this: CMenuBind):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.
CMenuBind:SetKeyCallback(callback: fun(this: CMenuBind, key: Enum.ButtonCode, event: Enum.EKeyEvent):nil)
  ! Multiple callbacks could be set.
  Sets widget's on key press/release callback.
  callback: function to be called on key press/release.
CMenuBind:UnsetKeyCallback(callback: fun(this: CMenuBind, key: Enum.ButtonCode, event: Enum.EKeyEvent):nil)
  Removes widget's on key press/release callback.
  callback: function to be removed.
CMenuBind:Properties([name: string = nil], [value: string = nil], [markAsToggle: boolean = false])
  Updates the properties of a widget for display in the bind list.
  name: Overridden name to display in bind list.
  value: Overridden value to display alongside the name in the bind list. This can be used to provide additional context about the bind.
  markAsToggle: Indicates whether the bind should be marked as a toggle, which is particularly useful if the bind's functionality includes toggling states. Recommended to be used in conjunction with the IsToggled().
CMenuBind:ShowInBindIsland(newStatus: boolean) -> boolean
  Gets or sets the visibility of the bind in the bind island.
CMenuBind:ShowInBindIsland() -> boolean
CMenuBind:MouseBinding(newStatus: boolean) -> boolean
  Gets or sets the ability to bind the mouse button.
CMenuBind:MouseBinding() -> boolean

# CMenuButton
CMenuButton metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon
CMenuButton:SetCallback(callback: fun(this: CMenuButton):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuButton:UnsetCallback(callback: fun(this: CMenuButton):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuColorPicker
CMenuColorPicker metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon
CMenuColorPicker:Get() -> Color
  Returns widget's value.
CMenuColorPicker:Set(value: Color)
  Sets widget's value.
CMenuColorPicker:SetCallback(callback: fun(this: CMenuColorPicker):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuColorPicker:UnsetCallback(callback: fun(this: CMenuColorPicker):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.
CMenuColorPicker:HideAlphaBar(value: boolean)
  Gets or sets alpha bar state. Depends on argument.
```lua
-- setter
widget:HideAlphaBar( true )
```
CMenuColorPicker:HideAlphaBar() -> boolean
```lua
-- getter
local isAlphaBarHidden = widget:HideAlphaBar()
```

# CMenuColorPickerAttachment
CMenuColorPickerAttachment metatable.
Общие: Name, Type, Open, ForceLocalization, Visible, Disabled
CMenuColorPickerAttachment:Parent() -> CMenuSwitch|CMenuSliderInt|CMenuSliderFloat|CMenuMultiComboBox|CMenuLabel|CMenuInputBox|CMenuGroup|CMenuBind
  Returns widget's parent.
CMenuColorPickerAttachment:Get() -> Color
  Returns widget's value.
CMenuColorPickerAttachment:Set(value: Color)
  Sets widget's value.
CMenuColorPickerAttachment:SetCallback(callback: fun(this: CMenuColorPickerAttachment):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuColorPickerAttachment:UnsetCallback(callback: fun(this: CMenuColorPickerAttachment):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuComboBox
CMenuComboBox metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuComboBox:Update(items: string[], [defaultValue: integer = 0])
  Update the combo box values.
  defaultValue: Index of default item. (starts from 0)
CMenuComboBox:Get() -> integer
  Returns index of the selected item. It starts from 0.
CMenuComboBox:Set(value: integer)
  Sets widget's value.
CMenuComboBox:List() -> string[]
  Returns array of the items.
CMenuComboBox:SetCallback(callback: fun(this: CMenuComboBox):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuComboBox:UnsetCallback(callback: fun(this: CMenuComboBox):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuInputBox
CMenuInputBox metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuInputBox:Get() -> string
  Returns widget's value.
CMenuInputBox:Set(value: string)
  Sets widget's value.
CMenuInputBox:SetCallback(callback: fun(this: CMenuInputBox):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuInputBox:UnsetCallback(callback: fun(this: CMenuInputBox):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuLabel
CMenuLabel metatable.
Общие: Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuLabel:Name(newText: string) -> string
  Returns widget's name.
CMenuLabel:Name() -> string

# CMenuMultiComboBox
CMenuMultiComboBox metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuMultiComboBox:Update(items: string[], enabledItems: string[])
  Updates the multicombo values.
  enabledItems: table of enabled items
CMenuMultiComboBox:Get(itemId: string) -> boolean
  Returns enable state of the item in combo box.
CMenuMultiComboBox:Set(enabledItems: string[])
  Sets a new value for the item by itemId or sets a new list of enabled items
  enabledItems: A table of enabled items; other items will be disabled.
CMenuMultiComboBox:Set(itemId: string, value: boolean)
CMenuMultiComboBox:List() -> string[]
  Returns array of itemIds.
CMenuMultiComboBox:ListEnabled() -> string[]
  Returns array of enabled itemIds.
CMenuMultiComboBox:SetCallback(callback: fun(this: CMenuMultiComboBox):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuMultiComboBox:UnsetCallback(callback: fun(this: CMenuMultiComboBox):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuMultiSelect
CMenuMultiSelect metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon
CMenuMultiSelect:Update(items: {nameId: string, imagePath: string, isEnabled: boolean}[], [expanded: boolean = false], [saveToConfig: boolean = false])
  Updates the multiselect values.
  items: See CMenuGroup:MultiSelect.
  expanded: false if you want to create MultiSelect in collapsed state.
  saveToConfig: true if you want to save to config
CMenuMultiSelect:OneItemSelection(newState: boolean) -> boolean
  Gets or sets one item selection state. One item selection allows only one item to be selected. Depends on the argument.
CMenuMultiSelect:OneItemSelection() -> boolean
CMenuMultiSelect:DragAllowed(newState: boolean) -> boolean
  Gets or sets drag allowed state. Drag allows items to be ordered by cursor. Depends on the argument.
CMenuMultiSelect:DragAllowed() -> boolean
CMenuMultiSelect:Get(itemId: string) -> boolean
  Returns enable state of the item in multiselect.
CMenuMultiSelect:Set(enabledItems: string[])
  Sets a new value for the item by itemId or sets a new list of enabled items
  enabledItems: A table of enabled items; other items will be disabled.
CMenuMultiSelect:Set(itemId: string, value: boolean)
CMenuMultiSelect:List() -> string[]
  Returns array of itemIds.
CMenuMultiSelect:ListEnabled() -> string[]
  Returns array of enabled itemIds.
CMenuMultiSelect:SetCallback(callback: fun(this: CMenuMultiSelect):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuMultiSelect:UnsetCallback(callback: fun(this: CMenuMultiSelect):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.
CMenuMultiSelect:UpdateBackgroundColors(colors: table<string>)
  Updates widget's background colors.
  colors: Table with background colors.
CMenuMultiSelect:UpdateImageColors(colors: table<string>)
  Updates widget's image colors.
  colors: Table with image colors.
CMenuMultiSelect:UpdateToolTips(colors: table<string>)
  Updates widget's tooltips
  colors: Table with new tooltips

# CMenuSliderFloat
CMenuSliderFloat metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuSliderFloat:Update(minValue: number, maxValue: number, defaultValue: number)
  Updates the slider values.
CMenuSliderFloat:Get() -> number
  Returns widget's value.
CMenuSliderFloat:Set(value: number)
  Sets widget's value.
CMenuSliderFloat:SetCallback(callback: fun(this: CMenuSliderFloat):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.\\
  forceCall: true if you want to call callback on widget creation.
CMenuSliderFloat:UnsetCallback(callback: fun(this: CMenuSliderFloat):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuSliderInt
CMenuSliderInt metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuSliderInt:Update(minValue: integer, maxValue: integer, defaultValue: integer)
  Updates the slider values.
CMenuSliderInt:Get() -> integer
  Returns widget's value.
CMenuSliderInt:Set(value: integer)
  Sets widget's value.
CMenuSliderInt:SetCallback(callback: fun(this: CMenuSliderInt):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuSliderInt:UnsetCallback(callback: fun(this: CMenuSliderInt):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.

# CMenuSwitch
CMenuSwitch metatable.
Общие: Name, Parent, Type, Open, ForceLocalization, ToolTip, Visible, Disabled, Unsafe, Image, ImageHandle, Icon, ColorPicker, Gear
CMenuSwitch:Get() -> boolean
  Returns widget's value.
CMenuSwitch:Set(value: boolean)
  Sets widget's value.
CMenuSwitch:SetCallback(callback: fun(this: CMenuSwitch):nil, [forceCall: boolean = false])
  ! Multiple callbacks could be set.
  Sets widget's on change callback.
  callback: function to be called on widget change.
  forceCall: true if you want to call callback on widget creation.
CMenuSwitch:UnsetCallback(callback: fun(this: CMenuSwitch):nil)
  Removes widget's on change callback.
  callback: function to be removed from widget's callbacks.
