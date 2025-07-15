local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local MConfig = require(MainStorage.code.common.MConfig)

---@class Assistant:ViewBase
local Assistant = ClassMgr.Class("Assistant", ViewBase)

local uiConfig = {
    uiName = "Assistant",
    layer = 0,
    hideOnInit = false,
}

---@override
function Assistant:OnInit(node, config)
    -- 获取"脱离卡死"按钮
    self.unstuckButton = self:Get("脱离卡死", ViewButton) ---@type ViewButton

    -- 获取确认传送UI组件
    self.confirmTeleportUI = self:Get("确认传送", ViewComponent) ---@type ViewComponent
    self.confirmTeleportContent = self.confirmTeleportUI.node.content ---@type UITextLabel
    self.confirmTeleportButton = self:Get("确认传送/b_confirm", ViewButton) ---@type ViewButton
    self.cancelTeleportButton = self:Get("确认传送/b_cancel", ViewButton) ---@type ViewButton

    if not self.unstuckButton or not self.confirmTeleportUI then
        return
    end

    -- 默认隐藏确认UI
    self.confirmTeleportUI:SetVisible(false)

    -- 注册按钮事件
    self:RegisterEventFunction()
end

---为按钮注册点击事件
function Assistant:RegisterEventFunction()
    -- "脱离卡死"按钮事件
    if self.unstuckButton then
        self.unstuckButton.clickCb = function(ui, button)
            gg.log("'脱离卡死'按钮被点击")

            local teleportPointId = "g0"
            local teleportPath = MConfig.TeleportPoints[teleportPointId]

            if not teleportPath then
                gg.log("错误: 在MConfig中未找到传送点配置: " .. teleportPointId)
                return
            end

            -- 显示确认UI
            local message = string.format("您确定要传送到安全点吗？")
            self.confirmTeleportContent.Title = message
            self.confirmTeleportUI:SetVisible(true)
        end
    end

    -- "确认传送"按钮事件
    if self.confirmTeleportButton then
        self.confirmTeleportButton.clickCb = function(ui, button)
            gg.network_channel:FireServer({ cmd = "RequestPlayerTeleport" })
            self.confirmTeleportUI:SetVisible(false)
        end
    end

    -- "取消传送"按钮事件
    if self.cancelTeleportButton then
        self.cancelTeleportButton.clickCb = function(ui, button)
            self.confirmTeleportUI:SetVisible(false)
        end
    end
end

return Assistant.New(script.Parent, uiConfig)