local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
local TweenService = game:GetService("TweenService")
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local CoreUI = game:GetService("CoreUI")
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
function HudMenu:RegisterMenuButton(viewButton)
    if not viewButton then return end
    gg.log("菜单按钮初始化", viewButton.node.Name)
    viewButton:SetTouchEnable(true)
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        gg.log("菜单按钮点击", button.node.Name)
        if button.node.Name == "活动" then
            gg.log("活动按钮点击")
        elseif button.node.Name == "卡包" then
            gg.log("卡包按钮点击")
            ViewBase["CardsGui"]:Open()
        elseif button.node.Name == "邮件" then
            gg.log("邮件按钮点击")
            ViewBase["MailGui"]:Open()
        elseif button.node.Name == "设置" then
            gg.log("设置按钮点击")

            CoreUI:ExitGame ()
            -- ViewBase["SettingGui"]:Open()
        end
        -- 发送菜单点击事件到服务器
        gg.network_channel:FireServer({
            cmd = "MenuClicked",
            buttonName = button.node.Name
        })
    end
end

function HudMenu:OnInit(node, config)
    gg.log("菜单按钮HudMenu初始化")
    self.selectingCard = 0

    self:RegisterMenuButton(self:Get("活动", ViewButton))
    self:RegisterMenuButton(self:Get("图鉴", ViewButton))
    self:RegisterMenuButton(self:Get("卡包", ViewButton))
    self:RegisterMenuButton(self:Get("邮件", ViewButton))
    self:RegisterMenuButton(self:Get("设置", ViewButton))
    self:Get("菜单/菜单按钮", ViewList, function(n)
        local button = ViewButton.New(n, self)
        self:RegisterMenuButton(button)
        return button
    end) ---@type ViewList<ViewButton>

    self.moneyButtonList = self:Get("货币/货币", ViewList, function(n)
        local button = ViewButton.New(n, self)
        button.clickCb = OnMoneyClick
        return button
    end) ---@type ViewList<ViewButton>

end

return HudMenu.New(script.Parent, uiConfig)
