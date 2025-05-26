
local MainStorage     = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg
---@class SEvent
---@field __class Class 事件类型

---@class C2SEvent : SEvent
---@field player Player

---@class ServerEventManager
local ServerEventManager = {
    _eventDictionary = {} -- @type table<string, ServerEventListener[]>
}

---@class ServerEventListener
local ServerEventListener = {
    cb = nil,      -- @type fun(evt: table)
    priority = 10   -- @type integer
}

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
function ServerEventManager.Unsubscribe(eventType, listener)
    if ServerEventManager._eventDictionary[eventType] then
        local list = ServerEventManager._eventDictionary[eventType]
        for i = #list, 1, -1 do
            if list[i].cb == listener then
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
function ServerEventManager.Publish(eventType, eventData)
    eventData.__class = eventType
    gg.log("PublishEvent", eventType, eventData)
    if ServerEventManager._eventDictionary[eventType] then
        for _, item in ipairs(ServerEventManager._eventDictionary[eventType]) do
            local success, err = pcall(item.cb, eventData)
            if not success then
                warn(string.format("事件执行失败 %s\n%s", err, debug.traceback()))
            end
        end
    end
end

return ServerEventManager