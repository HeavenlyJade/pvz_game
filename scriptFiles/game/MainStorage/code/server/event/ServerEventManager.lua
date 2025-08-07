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
    _localListeners = {}, -- @type table<number, table<string, fun(evt: table)[]>>
    _callbackMap = {}, -- @type table<string, table<uin, fun(data: table)>> 按uin存储回调函数
    _callbackCounter = 0, -- 用于生成唯一ID
    _callbackTimeout = 2, -- 回调超时时间（秒）
    
    -- 初始化相关
    _serverInitialized = false, -- 服务器是否初始化完成
    _pendingEvents = {} -- 待发布的事件队列 @type table<{eventType: string, eventData: table, callback?: fun(data: table)}>
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

--- 标记服务器初始化完成，并发布所有待发布的事件
function ServerEventManager.SetServerInitialized()
    ServerEventManager._serverInitialized = true
    for _, eventInfo in ipairs(ServerEventManager._pendingEvents) do
        ServerEventManager._PublishImmediate(eventInfo.eventType, eventInfo.eventData, eventInfo.callback)
    end
    ServerEventManager._pendingEvents = {}
end

--- 立即发布事件（内部方法，跳过初始化检查）
---@param eventType string 事件类型
---@param eventData table 事件数据
---@param callback? fun(data: table) 回调函数
function ServerEventManager._PublishImmediate(eventType, eventData, callback)
    eventData.__class = eventType
    if ServerEventManager._eventDictionary[eventType] then
        for i, item in ipairs(ServerEventManager._eventDictionary[eventType]) do
            local success, err = pcall(item.cb, eventData)
            if not success then
                gg.log(string.format("事件执行失败 %s\\n%s", err, debug.traceback()))
            end
        end
    end
end

--- 订阅事件
---@param eventType string 事件类型
---@param listener fun(evt: table) 事件回调函数
---@param priority? number 优先级，默认为10
---@param key? string 记录ID，可用 ServerEventManager.UnsubscribeByKey(key) 移除所有指定key的监听器
function ServerEventManager.Subscribe(eventType, listener, priority, key)
    local success, err = pcall(function()
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
    end)
    
    if not success then
        gg.log(string.format("订阅事件 %s 失败\n错误: %s\n调用位置: %s", 
            eventType or "unknown", err or "unknown error", debug.traceback()))
    end
end

--- 订阅指定玩家的事件
---@param player Player 目标玩家
---@param eventType string 事件类型
---@param listener fun(evt: table) 事件回调函数
---@param key? string 记录ID
function ServerEventManager.SubscribeToPlayer(player, eventType, listener, key)
    local uin = player.uin
    if not ServerEventManager._localListeners[uin] then
        ServerEventManager._localListeners[uin] = {}
    end
    if not ServerEventManager._localListeners[uin][eventType] then
        ServerEventManager._localListeners[uin][eventType] = {}
    end
    table.insert(ServerEventManager._localListeners[uin][eventType], {
        key = key,
        cb = listener
    })
end

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

--- 取消订阅指定玩家的事件
---@param player Player 目标玩家
---@param eventType string 事件类型
---@param listener? fun(evt: table) 要取消的事件回调函数
---@param key? string 记录ID
function ServerEventManager.UnsubscribeFromPlayer(player, eventType, listener, key)
    local uin = player.uin
    if ServerEventManager._localListeners[uin] and ServerEventManager._localListeners[uin][eventType] then
        local list = ServerEventManager._localListeners[uin][eventType]
        for i = #list, 1, -1 do
            if (not listener or list[i].cb == listener) and
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
    -- 同时清理本地事件
    for uin, eventTypes in pairs(ServerEventManager._localListeners) do
        for eventType, listeners in pairs(eventTypes) do
            for i = #listeners, 1, -1 do
                if listeners[i].key == key then
                    table.remove(listeners, i)
                end
            end
        end
    end
end

--- 发布事件
---@param eventType string 事件类型
---@param eventData table 事件数据
---@param callback? fun(data: table) 回调函数
function ServerEventManager.Publish(eventType, eventData, callback)
    -- 如果服务器还未初始化完成，将事件加入待发布队列
    if not ServerEventManager._serverInitialized then
        table.insert(ServerEventManager._pendingEvents, {
            eventType = eventType,
            eventData = eventData,
            callback = callback
        })
        return
    end
    
    -- 服务器已初始化完成，立即发布事件
    ServerEventManager._PublishImmediate(eventType, eventData, callback)
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

--- 向指定玩家发布本地事件
---@param player Player 目标玩家
---@param eventType string 事件类型
---@param eventData table 事件数据
function ServerEventManager.PublishToPlayer(player, eventType, eventData)
    local uin = player.uin
    if ServerEventManager._localListeners[uin] and ServerEventManager._localListeners[uin][eventType] then
        for _, item in ipairs(ServerEventManager._localListeners[uin][eventType]) do
            local success, err = pcall(item.cb, eventData)
            if not success then
                gg.log(string.format("向玩家 %d 发布本地事件 %s 执行失败\n%s", uin, eventType, err, debug.traceback()))
            end
        end
    end
end

--- 检查指定玩家是否订阅了某个本地事件
---@param player Player 目标玩家
---@param eventType string 事件类型
---@return boolean
function ServerEventManager.HasLocalSubscription(player, eventType)
    local uin = player.uin
    if ServerEventManager._localListeners[uin] and ServerEventManager._localListeners[uin][eventType] and #ServerEventManager._localListeners[uin][eventType] > 0 then
        return true
    end
    return false
end

return ServerEventManager
