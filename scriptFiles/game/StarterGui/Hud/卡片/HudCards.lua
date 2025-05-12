local MainStorage = game:GetService("MainStorage")
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton

---@class HudCards:ViewBase
local HudCards = CommonModule.Class("HudCards", ViewBase)

local uiConfig = {
    uiName = "HudCards",
    layer = 0,
    hideOnInit = false,
}

---@param viewButton ViewButton
function HudCards:OnCardClick(viewButton)
    print("点击了卡片")
end

function HudCards:OnInit(node, config)
    ViewBase.OnInit(self, node, config)

    self.cardsList = ViewList.New(self:Get("卡片列表")) ---@type ViewList<ViewButton>
    self.cardsList:SetAddElementCb(function(node)
        local button = ViewButton.New(node)
        button.Click:Connect(self.OnCardClick)
        return button
    end)
end

return HudCards.New(script.Parent, uiConfig)
