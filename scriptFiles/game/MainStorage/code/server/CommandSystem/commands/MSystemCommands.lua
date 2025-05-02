--- 系统相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class SystemCommands
local SystemCommands = {}

-- 命令执行器工厂
local CommandExecutors = {}

-- 触发系统事件执行器
function CommandExecutors.TriggerSystemEvent(params, player)
    if params.category ~= "事件" then return false end
    
    local eventType = params.subcategory
    local eventId = params.id
    
    -- 触发游戏事件
    game:TriggerEvent(eventType, eventId, player)
    
    -- 通知客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "触发事件: " .. eventType,
        color = ColorQuad.new(0, 255, 0, 255)
    })
    
    return true
end

-- 解锁地图区域执行器
function CommandExecutors.UnlockMapArea(params, player)
    if params.category ~= "地图" then return false end
    
    local mapName = params.subcategory
    
    player:UnlockMap(mapName)
    
    -- 通知客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "解锁地图: " .. mapName,
        color = ColorQuad.new(0, 255, 0, 255)
    })
    
    return true
end

-- 命令映射表
local CommandMapping = {
    ["触发"] = CommandExecutors.TriggerSystemEvent,
    ["解锁"] = CommandExecutors.UnlockMapArea,
}

-- 命令执行函数
function SystemCommands.Execute(command, params, player)
    local executor = CommandMapping[command]
    if not executor then
        gg.log("未知系统命令: " .. command)
        return false
    end
    
    return executor(params, player)
end

return SystemCommands