local MainStorage     = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler

---@class SEvent
---@field __class Class 事件类型

---@class C2SEvent : SEvent
---@field player Player

---@class ServerEventManager
local ServerEventManager = {
    _eventDictionary = {}, -- @type table<string, ServerEventListener[]>
    _callbackMap = {}, -- @type table<string, table<uin, fun(data: table)>> 按uin存储回调函数
    _callbackCounter = 0, -- 用于生成唯一ID
    _callbackTimeout = 2 -- 回调超时时间（秒）
}

---@class ServerEventListener
local ServerEventListener = {
    cb = nil,      -- @type fun(evt: table)
    priority = 10   -- @type integer
}

--- 生成唯一的回调ID
---@return string
local function GenerateCallbackId()
    ServerEventManager._callbackCounter = ServerEventManager._callbackCounter + 1
    return tostring(ServerEventManager._callbackCounter)
end

--- 清理回调
---@param callbackId string
---@param uin? number 玩家uin，如果提供则只清理该玩家的回调
local function CleanupCallback(callbackId, uin)
    -- 取消超时定时任务
    if uin then
        -- 只清理指定玩家的回调
        if ServerEventManager._callbackMap[callbackId] then
            ServerEventManager._callbackMap[callbackId][uin] = nil
            -- 如果该callbackId下没有其他玩家的回调了，则移除整个callbackId
            local hasCallbacks = false
            for _ in pairs(ServerEventManager._callbackMap[callbackId]) do
                hasCallbacks = true
                break
            end
            if not hasCallbacks then
                ServerEventManager._callbackMap[callbackId] = nil
            end
        end
    else
        -- 清理所有玩家的回调
        ServerEventManager._callbackMap[callbackId] = nil
    end
    
    ServerEventManager.Unsubscribe(callbackId .. "_Return", nil, nil, callbackId)
end

--- 清理指定玩家的所有回调
---@param uin number 玩家uin
function ServerEventManager.CleanupPlayerCallbacks(uin)
    for callbackId, callbacks in pairs(ServerEventManager._callbackMap) do
        if callbacks[uin] then
            CleanupCallback(callbackId, uin)
        end
    end
end

--- 订阅事件
---@param eventType string 事件类型
---@param listener fun(evt: table) 事件回调函数
---@param priority? number 优先级，默认为10
---@param key? string 记录ID，可用 ServerEventManager.UnsubscribeByKey(key) 移除所有指定key的监听器
function ServerEventManager.Subscribe(eventType, listener, priority, key)
    local priority = priority or 10
    local l = {
        key = key,
        cb = listener,
        priority = priority
    }
    if not ServerEventManager._eventDictionary[eventType] then
        ServerEventManager._eventDictionary[eventType] = {}
    end
    table.insert(ServerEventManager._eventDictionary[eventType], l)
    -- 按优先级排序
    table.sort(ServerEventManager._eventDictionary[eventType], function(a, b)
        return a.priority < b.priority
    end)
end

-- -- 监听怪物死亡事件
-- ServerEventManager.Subscribe("MobDeadEvent", function(evt)
--     ---@type MobDeadEvent
--     local mobDeadEvent = evt
--     mobDeadEvent.
--     print("怪物死亡:", mobDeadEvent.mob)
-- end)
-- -- 监听战斗前事件
-- ServerEventManager.Subscribe("PreBattleEvent", function(evt)
--     ---@type PreBattleEvent
--     local preBattleEvent = evt
--     print("战斗开始:", preBattleEvent.battle)
-- end)


--- 取消订阅事件
---@param eventType string 事件类型
---@param listener fun(evt: table) 要取消的事件回调函数
---@param priority? number 优先级
---@param key? string 记录ID
function ServerEventManager.Unsubscribe(eventType, listener, priority, key)
    if ServerEventManager._eventDictionary[eventType] then
        local list = ServerEventManager._eventDictionary[eventType]
        for i = #list, 1, -1 do
            if (not listener or list[i].cb == listener) and 
               (not priority or list[i].priority == priority) and
               (not key or list[i].key == key) then
                table.remove(list, i)
            end
        end
    end
end

--- 通过key取消订阅事件
---@param key string 要取消的事件监听器的key
function ServerEventManager.UnsubscribeByKey(key)
    for eventType, listeners in pairs(ServerEventManager._eventDictionary) do
        for i = #listeners, 1, -1 do
            if listeners[i].key == key then
                table.remove(listeners, i)
            end
        end
    end
end

--- 发布事件
---@param eventType string 事件类型
---@param eventData table 事件数据
---@param callback? fun(data: table) 回调函数
function ServerEventManager.Publish(eventType, eventData, callback)
    eventData.__class = eventType
    if ServerEventManager._eventDictionary[eventType] then
        for _, item in ipairs(ServerEventManager._eventDictionary[eventType]) do
            local success, err = pcall(item.cb, eventData)
            if not success then
                gg.log(string.format("事件执行失败 %s\n%s", err, debug.traceback()))
            end
        end
    end
end

---@param eventType string 事件类型
---@param eventData table 事件数据
---@param callback? fun(data: table) 回调函数
function ServerEventManager.SendToClient(uin, eventType, eventData, callback)
    eventData.__class = eventType
    if callback then
        local callbackId = GenerateCallbackId()
        eventData.__cb = callbackId
        -- 存储回调函数，按uin分类
        if not ServerEventManager._callbackMap[callbackId] then
            ServerEventManager._callbackMap[callbackId] = {}
        end
        ServerEventManager._callbackMap[callbackId][uin] = callback
        
        -- 监听客户端返回的事件
        ServerEventManager.Subscribe(callbackId .. "_Return", function(returnData)
            local callbacks = ServerEventManager._callbackMap[callbackId]
            if callbacks and callbacks[uin] then
                callbacks[uin](returnData.data)
                CleanupCallback(callbackId, uin)
            end
        end, 0, callbackId)
    end
    gg.network_channel:fireClient(uin, eventData)
end

return ServerEventManager