local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local Item = require(MainStorage.code.server.bag.Item) ---@type Item

---@class ItemTooltipHud:ViewBase
local ItemTooltipHud = ClassMgr.Class("ItemTooltipHud", ViewBase)


local uiConfig = {
    uiName = "ItemTooltipHud",
    layer = 20,
    hideOnInit = true,
    closeHuds = false
}

function ItemTooltipHud:OnInit(node, config)
    self.frame = self:Get("框体", ViewButton)
    self.icon = self.frame:Get("物品图标")
    self.title = self.frame:Get("物品名")
    self.description = self.frame:Get("物品描述列表/物品描述")
    self.useButton = self.frame:Get("使用", ViewButton)
    if game.RunService:IsPC() then
        ClientEventManager.Subscribe("MouseMove", function (evt)
            if self.displaying then
                self.frame.node.Position = Vector2.New(evt.x*game.WorldService:GetUIScale().x+10, evt.y*game.WorldService:GetUIScale().y+19)
            end
        end)
    else
        self.frame.touchBeginCb = function (ui, button, pos)
            self._startPos = pos
        end
        self.frame.touchMoveCb = function (ui, button, pos)
            local offset = pos - self._startPos
            self.frame.node.Position = self.frame.node.Position + offset
            self._startPos = pos
        end
    end
end

function ItemTooltipHud:DisplayItem(item, x, y)
    local itemType = item
    if ClassMgr.Is(item, "Item") then
        itemType = item.itemType
    end
    self.frame.node.Position = Vector2.New(x, y)
    if itemType.icon then
        self.icon.node["ItemIcon"].Icon = itemType.icon
    end
    local amount = gg.FormatLargeNumber(item.amount or 1)
    if amount == "1" then
        self.icon.node["Amount"].Title = ""
    else
        self.icon.node["Amount"].Title = amount
    end
    if itemType.rank then
        self.icon.node.Icon = itemType.rank.normalImgBg
        if self.icon.node["Frame"] then
            self.icon.node["Frame"].Icon = itemType.rank.normalImgFrame
        end
    end
    self.title.node.Title = itemType.name
    self.description.node.Title = itemType.description
    self.useButton:SetVisible(false)
    self:Open()
end

return ItemTooltipHud.New(script.Parent, uiConfig)