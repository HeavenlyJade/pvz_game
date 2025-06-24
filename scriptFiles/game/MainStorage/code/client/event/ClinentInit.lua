-- 添加到 scriptFiles/game/MainStorage/code/client/ClientInit.lua

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class ClientInit
local ClientInit = ClassMgr.Class("ClientInit")

-- 客户端初始化函数
function ClientInit.init()
    gg.log("客户端初始化开始")

    -- 注册事件处理器
    --ClientInit.registerEventHandlers()

    gg.log("客户端初始化完成")
end

-- 注册所有服务端到客户端的事件处理器


return ClientInit
