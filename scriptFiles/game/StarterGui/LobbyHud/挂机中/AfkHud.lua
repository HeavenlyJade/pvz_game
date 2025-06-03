local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager


---@class AfkHud:ViewBase
local AfkHud = ClassMgr.Class("AfkHud", ViewBase)

local uiConfig = {
    uiName = "AfkHud",
    layer = 0,
    hideOnInit = true,
}

function AfkHud:OnInit(node, config)
    ViewBase.OnInit(self, node, config)
    local exitButton = self:Get("按钮", ViewButton)
    self.gainSpeed = self:Get("获取速度") ---@type ViewComponent
    exitButton.clickCb = function (ui, button)
        -- 发送退出挂机状态事件到服务器
        gg.network_channel:FireServer({
            cmd = "ExitAfkSpot"
        })
        -- 关闭UI
        self:Close()
    end

    -- 监听挂机点进入事件
    ClientEventManager.Subscribe("AfkSpotEntered", function(data)
        -- 更新获取速度显示
        self.gainSpeed.node.Title = string.format("阳光: +%d/秒", data.rewardsPerSecond)
        -- 显示UI
        self:Open()
    end)
end

function AfkHud:Open()
    ViewBase.Open(self)
    ViewBase.GetUI("HudInteract"):Close()
end


function AfkHud:Close()
    ViewBase.Close(self)
    ViewBase.GetUI("HudInteract"):Open()
end


return AfkHud.New(script.Parent, uiConfig)