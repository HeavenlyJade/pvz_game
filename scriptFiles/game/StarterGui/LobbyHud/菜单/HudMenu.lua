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
    self.selectingCard = 0
    ---@param currentNode SandboxNode
    local function traverseNodes(currentNode)
        local clickImage = currentNode:GetAttribute("图片-点击")
        if clickImage ~= nil then
            local button = ViewButton.New(currentNode, self)
            self:RegisterMenuButton(button)
            gg.log(string.format("发现菜单按钮: %s, 图片-点击: %s", currentNode.Name, tostring(clickImage)))
        end
        
        -- 递归遍历所有子节点
        for _, child in pairs(currentNode.Children) do
            traverseNodes(child)
        end
    end
    traverseNodes(node)
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
end

return HudMenu.New(script.Parent, uiConfig)
