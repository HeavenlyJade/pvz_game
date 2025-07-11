local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local soundPlayer = game:GetService("StarterGui")["UISound"] ---@type Sound
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
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

function ViewItem:OnClick(vector2)
    if self._itemCache then
        ViewBase.GetUI("ItemTooltipHud"):DisplayItem(self._itemCache, vector2.x, vector2.y)
    end
    ViewButton.OnClick(self, vector2)
end

---@param item Item|ItemType|string
function ViewItem:SetItem(item)
    self._itemCache = item
    if type(item) == "string" then
        item = ItemTypeConfig.Get(item)
    end
    local itemType = item
    if ClassMgr.Is(item, "Item") then
        itemType = item.itemType
    end
    if not itemType.icon then
        gg.log("物品没有配置图标:", itemType)
        return
    end
    self._itemCache = item
    if self.node["ItemIcon"] then
        self:SetChildIcon("ItemIcon", itemType.icon)
        self.node.Icon = itemType.rank.normalImgBg
        self.normalImg = itemType.rank.normalImgBg
        self.hoverImg = itemType.rank.hoverImgBg
        self.clickImg = itemType.rank.hoverImgBg
    else
        self.node.Icon = itemType.icon
        self.normalImg = itemType.icon
        self.hoverImg = itemType.icon
        self.clickImg = itemType.icon
    end
    if self.node["Frame"] then
        self:SetChildIcon("Frame", itemType.rank.normalImgFrame, itemType.rank.hoverImgFrame)
    end
    if ClassMgr.Is(item, "Item") then
        local amount = gg.FormatLargeNumber(item.amount)
        if amount == "1" then
            self.node["Amount"].Title = ""
        else
            self.node["Amount"].Title = amount
        end
    else
        self.node["Amount"].Title = ""
    end
end

---@param item ItemType
function ViewItem:SetItemCost(itemType, amountHas, cost)
    self._itemCache = itemType:ToItem(cost)
    self:SetChildIcon("ItemIcon", itemType.icon)
    self:SetChildIcon("Frame", itemType.rank.normalImgFrame, itemType.rank.hoverImgFrame)
    self.node.Icon = itemType.rank.normalImgBg
    self.normalImg = itemType.rank.normalImgBg
    self.hoverImg = itemType.rank.hoverImgBg
    self.clickImg = itemType.rank.hoverImgBg
    self.node["Amount"].Title = string.format("%s/\n%s", gg.FormatLargeNumber(amountHas), gg.FormatLargeNumber(cost))
end

return ViewItem
