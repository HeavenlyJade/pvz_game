local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager


---@class QueueingHud:ViewBase
local QueueingHud = ClassMgr.Class("QueueingHud", ViewBase)

local uiConfig = {
    uiName = "QueueingHud",
    layer = 0,
    hideOnInit = true,
}

-- 格式化时间显示
local function FormatTime(seconds)
    if seconds <= 0 then
        return "即将开始"
    end
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

function QueueingHud:OnInit(node, config)
    local exitButton = self:Get("匹配底图/退出按钮", ViewButton)
    self.matchProgress = self:Get("匹配底图/匹配进度") ---@type ViewComponent
    
    ClientEventManager.Subscribe("MatchProgressUpdate", function(data)
        if data.currentCount and data.totalCount then
            -- 更新匹配进度文本，包含关卡名称和剩余时间
            local timeText = data.remainingTime and FormatTime(data.remainingTime) or ""
            self.matchProgress.node.Title = string.format("匹配 %s: %d/%d %s", 
                data.levelName, 
                data.currentCount, 
                data.totalCount,
                timeText
            )
            self:Open()
        end
    end)

    -- 监听匹配开始事件
    ClientEventManager.Subscribe("MatchStart", function()
        -- 匹配开始时关闭UI
        self:Close()
    end)

    -- 监听匹配取消事件
    ClientEventManager.Subscribe("MatchCancel", function()
        -- 匹配取消时关闭UI
        self:Close()
    end)

    -- 监听进入匹配队列事件
    ClientEventManager.Subscribe("EnterQueue", function(data)
        if data.levelName then
            self.currentLevelName = data.levelName
        end
    end)
    
    exitButton.clickCb = function (ui, button)
        -- 发送退出匹配请求到服务器
        gg.network_channel:FireServer({
            cmd = "LeaveQueue"
        })
        -- 关闭UI
        self:Close()
    end
end

return QueueingHud.New(script.Parent, uiConfig)