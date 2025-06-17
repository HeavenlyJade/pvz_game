local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local soundPlayer = game:GetService("StarterGui")["UISound"] ---@type Sound
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
---@class ViewItem:ViewButton
---@field New fun(node: SandboxNode, ui: ViewBase, path?: string, realButtonPath?: string): ViewItem
local  ViewItem = ClassMgr.Class("ViewItem", ViewButton)


function ViewItem:OnInit(node, ui, path, realButtonPath)
    self._itemCache = nil
end

function ViewItem:OnHoverIn(vector2)
    if self._itemCache then
        ViewBase.GetUI("ItemTooltipHud"):DisplayItem(self._itemCache, vector2.x, vector2.y)
    end
    ViewButton.OnHoverIn(self)
end

function ViewItem:OnHoverOut()
    if self._itemCache then
        ViewBase.GetUI("ItemTooltipHud"):Close()
    end
    ViewButton.OnHoverOut(self)
end

function ViewItem:OnClick()
    if self._itemCache then
        ViewBase.GetUI("ItemTooltipHud"):DisplayItem(self._itemCache, vector2.x, vector2.y)
    end
    ViewButton.OnClick(self)
end

---@param item Item
function ViewItem:SetItem(item)
    self._itemCache = item
    self.node["ItemIcon"].Icon = item.itemType.icon
    self.node["Amount"].Title = gg.FormatLargeNumber(item.amount)
end

return ViewItem
