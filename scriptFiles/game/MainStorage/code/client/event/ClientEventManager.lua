local MainStorage = game:GetService("MainStorage")

local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class ClientEventManager
local ClientEventManager = {
    _eventDictionary = {}, -- @type table<string, ClientEventListener[]>
    _callbackMap = {}, -- @type table<string, fun(data: table)> 存储回调函数
    _callbackCounter = 0 -- 用于生成唯一ID
}
---@class CEvent
---@field __class Class 事件类型

---@class S2CEvent : CEvent

---@class ClientEventListener
local ClientEventListener = {
    cb = nil,      -- @type fun(evt: table)
    priority = 10   -- @type integer
}

--- 生成唯一的回调ID
---@return string
local function GenerateCallbackId()
    ClientEventManager._callbackCounter = ClientEventManager._callbackCounter + 1
    return tostring(ClientEventManager._callbackCounter)
end

--- 清理回调
---@param callbackId string
local function CleanupCallback(callbackId)
    ClientEventManager._callbackMap[callbackId] = nil
    ClientEventManager.Unsubscribe(callbackId .. "_Return", nil, nil, callbackId)
end

--- 订阅事件
---@param eventType string 事件类型
---@param listener fun(evt: table) 事件回调函数
---@param priority? number 优先级，默认为10
---@param key? string 记录ID
function ClientEventManager.Subscribe(eventType, listener, priority, key)
    -- 参数验证
    if not eventType then
        gg.log("错误：eventType 不能为 nil",eventType,listener)
        return
    end

    if not listener then
        gg.log("错误：listener 不能为 nil")
        return
    end

    -- 确保 _eventDictionary 不为 nil
    if not ClientEventManager._eventDictionary then
        ClientEventManager._eventDictionary = {}
    end

    local priority = priority or 10
    local l = {
        key = key,
        cb = listener,
        priority = priority
    }

    if not ClientEventManager._eventDictionary[eventType] then
        ClientEventManager._eventDictionary[eventType] = {}
    end
    table.insert(ClientEventManager._eventDictionary[eventType], l)
    -- 按优先级排序
    table.sort(ClientEventManager._eventDictionary[eventType], function(a, b)
        return a.priority < b.priority
    end)
end

-- -- 监听怪物死亡事件
-- ClientEventManager.Subscribe("MobDeadEvent", function(evt)
--     ---@type MobDeadEvent
--     local mobDeadEvent = evt
--     mobDeadEvent.
--     print("怪物死亡:", mobDeadEvent.mob)
-- end)
-- -- 监听战斗前事件
-- ClientEventManager.Subscribe("PreBattleEvent", function(evt)
--     ---@type PreBattleEvent
--     local preBattleEvent = evt
--     print("战斗开始:", preBattleEvent.battle)
-- end)


--- 取消订阅事件
---@param eventType string 事件类型
---@param listener fun(evt: table) 要取消的事件回调函数
---@param priority? number 优先级
---@param key? string 记录ID
function ClientEventManager.Unsubscribe(eventType, listener, priority, key)
    if ClientEventManager._eventDictionary[eventType] then
        local list = ClientEventManager._eventDictionary[eventType]
        for i = #list, 1, -1 do
            if (not listener or list[i].cb == listener) and 
               (not priority or list[i].priority == priority) and
               (not key or list[i].key == key) then
                table.remove(list, i)
            end
        end
    end
end

--- 发布事件
---@param eventType string 事件类型
---@param eventData table 事件数据
function ClientEventManager.Publish(eventType, eventData)
    eventData.__class = eventType

    if ClientEventManager._eventDictionary[eventType] then
        for _, item in ipairs(ClientEventManager._eventDictionary[eventType]) do
            local success, err = pcall(item.cb, eventData)
            if not success then
                gg.log(string.format("事件执行失败 %s\n%s", err, debug.traceback()))
            end
        end
    end
end

--- 发送事件到服务器
---@param eventType string 事件类型
---@param eventData table 事件数据
---@param callback? fun(data: table) 回调函数
function ClientEventManager.SendToServer(eventType, eventData, callback)
    eventData.cmd = eventType
    if callback then
        local callbackId = GenerateCallbackId()
        eventData.__cb = callbackId
        -- 存储回调函数
        ClientEventManager._callbackMap[callbackId] = callback
        -- 监听服务端返回的事件
        ClientEventManager.Subscribe(callbackId .. "_Return", function(returnData)
            local cb = ClientEventManager._callbackMap[callbackId]
            if cb then
                cb(returnData.data)
                CleanupCallback(callbackId)
            end
        end, 0, callbackId)
    end
    gg.network_channel:FireServer(eventData)
end

--- 处理来自服务器的事件
-- ---@param eventType string 事件类型
-- ---@param eventData table 事件数据
-- function ClientEventManager.HandleServerEvent(eventType, eventData)
--     eventData.__class = eventType
    
--     -- 如果事件需要回调，添加Return函数
--     if eventData.__cb then
--         eventData.Return = function(returnData)
--             game:GetService("NetworkChannel"):FireServer({
--                 cmd = eventData.__cb .. "_Return",
--                 data = returnData
--             })
--         end
--     end
--     gg.log("HandleServerEvent", eventData)

--     if ClientEventManager._eventDictionary[eventType] then
--         for _, item in ipairs(ClientEventManager._eventDictionary[eventType]) do
--             local success, err = pcall(item.cb, eventData)
--             if not success then
--                 gg.log(string.format("事件执行失败 %s\n%s", err, debug.traceback()))
--             end
--         end
--     end
-- end

return ClientEventManager
