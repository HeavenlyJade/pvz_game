local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local Tweens = require(MainStorage.code.client.ui.Tweens) ---@type Tweens
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class HudCards:ViewBase
local HudCards = ClassMgr.Class("HudCards", ViewBase)

local uiConfig = {
    uiName = "HudCards",
    layer = 0,
    hideOnInit = false,
}

---@param viewButton ViewButton
local function OnCardClick(ui, viewButton)
    local selectingCardIndex = ui.selectingCard
    ui:ResetCard()
    if selectingCardIndex ~= viewButton.index then
        --移动卡牌
        local card = viewButton ---@type ViewButton
        local newPos = card.node.Position + Vector2.New(0, -100)
        local tween = Tweens.TweenPosition.New(0.5, card.node.Position, newPos)
        tween:AddTween(Tweens.TweenRotation.New(0.5, card.node.Rotation, 0))
        tween:AddTween(Tweens.TweenColor.New(0.5, Vector4.New(0.9, 0.9, 0.9, 1), Vector4.New(1,1,1, 1)))
        card:AddTween(tween)
        ui.selectingCard = card.index
    end
end

function HudCards:OnInit(node, config)
    ViewBase.OnInit(self, node, config)
    self.selectingCard = 0
    self.cardsList = self:Get("卡片列表", ViewList, function(n)
        local button = ViewButton.New(n, self)
        button.clickCb = OnCardClick
        return button
    end) ---@type ViewList<ViewButton>
end

function HudCards:ResetCard()
    if self.selectingCard > 0 then
        local card = self.cardsList:GetChild(self.selectingCard) ---@cast card ViewButton
        local tween = Tweens.TweenPosition.New(0.5, card.node.Position, card.defaultPos)
        tween:AddTween(Tweens.TweenRotation.New(0.5, card.node.Rotation, card.defaultRotation))
        tween:AddTween(Tweens.TweenColor.New(0.5, Vector4.New(1,1,1, 1), Vector4.New(0.9, 0.9, 0.9, 1)))
        card:AddTween(tween)
        self.selectingCard = 0
    end
end

return HudCards.New(script.Parent, uiConfig)
