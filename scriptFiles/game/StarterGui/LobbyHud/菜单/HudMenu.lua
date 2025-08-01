local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local MiscConfig = require(MainStorage.config.MiscConfig) ---@type MiscConfig
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
        ClientEventManager.SendToServer("ClickMenu", {
            menu = button.node.Name
        })
    end
end

function HudMenu:OnInit(node, config)
    gg.log("菜单按钮HudMenu初始化")
    self.selectingCard = 0
    gg.log("图鉴", self:Get("图鉴", ViewButton))
    self:RegisterMenuButton(self:Get("活动", ViewButton))
    self:RegisterMenuButton(self:Get("图鉴", ViewButton))

    self.menuButtons = {}
    self:Get("菜单/菜单按钮", ViewList, function(n)
        local button = ViewButton.New(n, self)
        self:RegisterMenuButton(button)
        self.menuButtons[n.Name] = button
        return button
    end) ---@type ViewList<ViewButton>
    
    self.key2Event = {}
    for name, menuConfig in pairs(MiscConfig.Get("总控")["菜单指令"]) do
        if menuConfig["按键"] and Enum.KeyCode[menuConfig["按键"]] then
            self.key2Event[Enum.KeyCode[menuConfig["按键"]].Value] = name
        end
    end
    ClientEventManager.Subscribe("PressKey", function (evt)
        if evt.isDown and not ViewBase.topGui then
            local menuName = self.key2Event[evt.key]
            if menuName then
                ClientEventManager.SendToServer("ClickMenu", {
                    menu = menuName
                })
            end
        end
    end)
    
    -- 监听菜单按钮显示状态更新事件
    ClientEventManager.Subscribe("UpdateMenuButtonVisibility", function(data)
        if not data or not data.visibility then return end
        
        for menuName, isVisible in pairs(data.visibility) do
            local button = self.menuButtons[menuName]
            if button and button.node then
                button.node.Visible = isVisible
            end
        end
    end)
end

return HudMenu.New(script.Parent, uiConfig)
