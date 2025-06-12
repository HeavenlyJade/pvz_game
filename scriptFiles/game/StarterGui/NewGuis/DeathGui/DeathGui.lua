local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton

---@class DeathGui:ViewBase
local DeathGui = ClassMgr.Class("DeathGui", ViewBase)

local uiConfig = {
    uiName = "DeathGui",
    layer = 1, -- 确保显示在最上层
    hideOnInit = true
}

function DeathGui:OnInit(node, config)
    -- 获取复活按钮
    self.respawnButton = self:Get("按钮", ViewButton)
    
    -- 监听复活按钮点击
    self.respawnButton.clickCb = function()
        self.respawnCb()
    end
    
    -- 监听死亡事件
    ClientEventManager.Subscribe("ViewDeath", function(evt)
        if evt.respawn then
            self:Close()
            return
        end
        -- 显示死亡界面
        self.respawnCb = evt.Return
        self:Open()
    end)
end

return DeathGui.New(script.Parent, uiConfig)
