local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg

---@class Task
---@field func function The function to execute
---@field delay number Original delay in ticks (for debugging)
---@field repeatInterval number Repeat interval in ticks (0 for one-time execution)
---@field taskId number Unique identifier for the task
---@field rounds number Number of wheel rotations needed before execution
---@field key string|nil Optional key for task identification

---@class ServerScheduler
local ServerScheduler = {
    tasks = {},  -- All tasks by ID
    tasksByKey = {}, -- Tasks by key
    nextTaskId = 1,
    
    -- Time wheel configuration
    wheelSlots = 60,  -- Number of slots in the wheel (1 slot per second for 60 seconds)
    wheelPrecision = 1,  -- 1 second precision
    timeWheel = {},    -- The actual time wheel
    currentSlot = 1,   -- Current position in the wheel
    
    -- Timing statistics
    lastTime = os.time(),
    updateCount = 0,
    updatesPerSecond = 0,
    tick = 0
}

-- Initialize the time wheel
for i = 1, ServerScheduler.wheelSlots do
    ServerScheduler.timeWheel[i] = {}
end

---Add a new scheduled task
---@param func function The function to execute
---@param delay number Delay in seconds before first execution
---@param repeatInterval? number Repeat interval in seconds (0 for one-time execution)
---@param key? string Optional key for task identification
---@return number taskId The ID of the created task
function ServerScheduler.add(func, delay, repeatInterval, key)
    -- 如果提供了key，取消同key的任务
    if key and ServerScheduler.tasksByKey[key] then
        ServerScheduler.cancel(ServerScheduler.tasksByKey[key])
    end

    local taskId = ServerScheduler.nextTaskId
    ServerScheduler.nextTaskId = ServerScheduler.nextTaskId + 1
    
    delay = delay * 30
    if not repeatInterval then
        repeatInterval = 0
    end
    
    -- Calculate rounds and slot for the time wheel
    local totalTicks = delay
    local rounds = math.floor(totalTicks / ServerScheduler.wheelSlots)
    local slotOffset = totalTicks % ServerScheduler.wheelSlots
    local slot = (ServerScheduler.currentSlot + slotOffset - 1) % ServerScheduler.wheelSlots + 1
    
    local task = {
        func = func,
        delay = delay, -- 保留原始延迟用于调试
        repeatInterval = repeatInterval * 30,
        taskId = taskId,
        rounds = rounds,
        key = key,
        traceback = debug.traceback("[ServerScheduler.add] task created here:", 2):match("^[^\n]*\n([^\n]*)")
    }
    
    ServerScheduler.tasks[taskId] = task
    if key then
        ServerScheduler.tasksByKey[key] = taskId
    end
    table.insert(ServerScheduler.timeWheel[slot], task)
    
    return taskId
end

---Cancel a scheduled task
---@param taskId number The ID of the task to cancel
---@return nil
function ServerScheduler.cancel(taskId)
    local task = ServerScheduler.tasks[taskId]
    if task then
        -- 如果任务有关联的key，清除key映射
        if task.key then
            ServerScheduler.tasksByKey[task.key] = nil
        end
        ServerScheduler.tasks[taskId] = nil
    end
    -- The task will be removed from the wheel when its slot is processed
end

---Update all scheduled tasks
function ServerScheduler.update()
    local currentSlot = ServerScheduler.currentSlot
    local tasks = ServerScheduler.timeWheel[currentSlot]
    local remainingTasks = {}
    local tasksToReschedule = {}  -- 收集需要重新调度的任务
    
    for i, task in ipairs(tasks) do
        if ServerScheduler.tasks[task.taskId] then  -- Check if task wasn't cancelled
            if task.rounds <= 0 then
                -- Execute the task
                local success, err = pcall(task.func)
                if not success then
                    gg.log("[ERROR] Scheduled task failed:", err, task.traceback)
                end
                
                -- Handle repeating tasks
                if task.repeatInterval > 0 then
                    -- 重新计算下次执行的rounds和slot
                    local intervalTicks = task.repeatInterval
                    local newRounds = math.floor(intervalTicks / ServerScheduler.wheelSlots)
                    local slotOffset = intervalTicks % ServerScheduler.wheelSlots
                    local newSlot = (currentSlot + slotOffset - 1) % ServerScheduler.wheelSlots + 1
                    
                    -- 更新任务的rounds
                    task.rounds = newRounds
                    
                    -- 将任务重新调度到新的slot
                    table.insert(tasksToReschedule, {task = task, slot = newSlot})
                else
                    -- Remove one-time tasks
                    ServerScheduler.tasks[task.taskId] = nil
                    if task.key then
                        ServerScheduler.tasksByKey[task.key] = nil
                    end
                end
            else
                -- Task needs more rounds, decrement and keep
                task.rounds = task.rounds - 1
                table.insert(remainingTasks, task)
            end
        end
    end
    
    -- 清空当前槽位并放入剩余任务
    ServerScheduler.timeWheel[currentSlot] = remainingTasks
    
    -- 处理需要重新调度的任务
    for _, rescheduleInfo in ipairs(tasksToReschedule) do
        table.insert(ServerScheduler.timeWheel[rescheduleInfo.slot], rescheduleInfo.task)
    end
    
    -- 移动到下一个槽位
    ServerScheduler.currentSlot = currentSlot % ServerScheduler.wheelSlots + 1
end

-- === 诊断和调试函数 ===

---查找指定key的任务信息
---@param key string 任务key
---@return table|nil 任务信息
function ServerScheduler.findTaskByKey(key)
    local taskId = ServerScheduler.tasksByKey[key]
    if not taskId then
        return nil
    end
    
    local task = ServerScheduler.tasks[taskId]
    if not task then
        return nil
    end
    
    -- 找到任务在哪个slot中
    local foundSlot = nil
    for slot = 1, ServerScheduler.wheelSlots do
        for _, slotTask in ipairs(ServerScheduler.timeWheel[slot]) do
            if slotTask.taskId == taskId then
                foundSlot = slot
                break
            end
        end
        if foundSlot then break end
    end
    
    return {
        taskId = task.taskId,
        key = task.key,
        rounds = task.rounds,
        delay = task.delay,
        repeatInterval = task.repeatInterval,
        traceback = task.traceback,
        inSlot = foundSlot,
        currentSlot = ServerScheduler.currentSlot
    }
end

---获取时间轮的整体状态
---@return table 时间轮状态信息
function ServerScheduler.getWheelStatus()
    local totalTasks = 0
    local slotCounts = {}
    
    for slot = 1, ServerScheduler.wheelSlots do
        local count = #ServerScheduler.timeWheel[slot]
        slotCounts[slot] = count
        totalTasks = totalTasks + count
    end
    
    return {
        currentSlot = ServerScheduler.currentSlot,
        totalTasks = totalTasks,
        totalRegisteredTasks = gg.table_count(ServerScheduler.tasks),
        totalKeyedTasks = gg.table_count(ServerScheduler.tasksByKey),
        slotCounts = slotCounts,
        wheelSlots = ServerScheduler.wheelSlots
    }
end

---检查指定slot的任务详情
---@param slot number 要检查的slot编号
---@return table slot中的任务列表
function ServerScheduler.inspectSlot(slot)
    if slot < 1 or slot > ServerScheduler.wheelSlots then
        return nil
    end
    
    local tasks = ServerScheduler.timeWheel[slot]
    local result = {}
    
    for i, task in ipairs(tasks) do
        table.insert(result, {
            index = i,
            taskId = task.taskId,
            key = task.key,
            rounds = task.rounds,
            delay = task.delay,
            repeatInterval = task.repeatInterval,
            isRegistered = ServerScheduler.tasks[task.taskId] ~= nil
        })
    end
    
    return {
        slot = slot,
        taskCount = #tasks,
        tasks = result
    }
end

---强制执行指定key的任务（用于测试）
---@param key string 任务key
---@return boolean 是否成功执行
function ServerScheduler.forceExecuteTask(key)
    local taskId = ServerScheduler.tasksByKey[key]
    if not taskId then
        return false
    end
    
    local task = ServerScheduler.tasks[taskId]
    if not task then
        return false
    end
    
    local success, err = pcall(task.func)
    if not success then
        gg.log("[ERROR] Force execute task failed:", err)
        return false
    end
    
    return true
end

return ServerScheduler