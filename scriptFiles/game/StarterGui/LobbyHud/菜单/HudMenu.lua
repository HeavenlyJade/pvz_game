local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
---@class HudMenu:ViewBase
local HudMenu = ClassMgr.Class("HudMenu", ViewBase)

local uiConfig = {
    uiName = "HudMenu",
    layer = 0,
    hideOnInit = false,
}

---@param viewButton ViewButton
function HudMenu:RegisterMenuButton(viewButton)
    if not viewButton then return end
    gg.log("菜单按钮初始化", viewButton.node.Name)
    viewButton:SetTouchEnable(true)
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        gg.log("菜单按钮点击", button.node.Name)
        ClientEventManager.Publish("SendHoverText", { txt="尚未开放，敬请期待！" })
    end
end

function HudMenu:OnInit(node, config)
    gg.log("菜单按钮HudMenu初始化")
    self.selectingCard = 0

    self:RegisterMenuButton(self:Get("活动", ViewButton))
    self:RegisterMenuButton(self:Get("图鉴", ViewButton))

    self:Get("菜单/菜单按钮", ViewList, function(n)
        local button = ViewButton.New(n, self)
        self:RegisterMenuButton(button)
        return button
    end) ---@type ViewList<ViewButton>
end

return HudMenu.New(script.Parent, uiConfig)
