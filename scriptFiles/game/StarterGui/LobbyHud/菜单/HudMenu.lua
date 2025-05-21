local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local Tweens = require(MainStorage.code.client.ui.Tweens) ---@type Tweens
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class HudMenu:ViewBase
local HudMenu = ClassMgr.Class("HudMenu", ViewBase)

local uiConfig = {
    uiName = "HudMenu",
    layer = 0,
    hideOnInit = false,
}

function OnMoneyClick(ui, viewButton)
end

---@param viewButton ViewButton
function RegisterMenuButton(viewButton)
    if not viewButton then return end
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        -- 发送菜单点击事件到服务器
        gg.network_channel:FireServer({
            cmd = "MenuClicked",
            buttonName = button.node.Name
        })
    end
end

function HudMenu:OnInit(node, config)
    ViewBase.OnInit(self, node, config)
    self.selectingCard = 0
    RegisterMenuButton(self:Get("活动", ViewButton))
    RegisterMenuButton(self:Get("图鉴", ViewButton))
    self:Get("菜单/菜单按钮", ViewList, function(n)
        local button = ViewButton.New(n, self)
        RegisterMenuButton(button)
        return button
    end) ---@type ViewList<ViewButton>

    self.moneyButtonList = self:Get("货币/货币", ViewList, function(n)
        local button = ViewButton.New(n, self)
        button.clickCb = OnMoneyClick
        return button
    end) ---@type ViewList<ViewButton>

    
    ClientEventManager.Subscribe("SyncInventoryItems", function(evt)
        local evt = evt ---@type SyncInventoryItems
        -- 更新货币显示
        if evt.moneys then
            for idx, money in ipairs(evt.moneys) do
                local button = self.moneyButtonList:GetChild(idx)
                if button then
                    local node = button:Get("Text").node ---@cast node UITextLabel
                    node.Title = tostring(money.a)
                end
            end
        end
    end)
    
end


return HudMenu.New(script.Parent, uiConfig)
