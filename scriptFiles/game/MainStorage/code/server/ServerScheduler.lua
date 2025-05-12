local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg

---@class Task
---@field func function The function to execute
---@field delay number Delay in seconds before first execution
---@field repeatInterval number Repeat interval in seconds (0 for one-time execution)
---@field remaining number Remaining ticks before execution
---@field taskId number Unique identifier for the task

---@class ServerScheduler
local ServerScheduler = {
    tasks = {},
    nextTaskId = 1,
    highPriorityTasks = {},    -- remaining <= 1
    mediumPriorityTasks = {},  -- 1 < remaining <= 10
    lowPriorityTasks = {},     -- 10 < remaining <= 100
    lowestPriorityTasks = {},  -- remaining > 100
    tick = 0
}

---Add task to appropriate priority queue
---@param task Task The task to add
local function addToPriorityQueue(task)
    if task.remaining <= 1 then
        ServerScheduler.highPriorityTasks[task.taskId] = task
    elseif task.remaining <= 10 then
        ServerScheduler.mediumPriorityTasks[task.taskId] = task
    elseif task.remaining <= 100 then
        ServerScheduler.lowPriorityTasks[task.taskId] = task
    else
        ServerScheduler.lowestPriorityTasks[task.taskId] = task
    end
end

---Add a new scheduled task
---@param func function The function to execute
---@param delay number Delay in seconds before first execution
---@param repeatInterval number Repeat interval in seconds (0 for one-time execution)
---@return number taskId The ID of the created task
function ServerScheduler.add(func, delay, repeatInterval, isInSecond)
    local taskId = ServerScheduler.nextTaskId
    ServerScheduler.nextTaskId = ServerScheduler.nextTaskId + 1
    
    if isInSecond then
        delay = math.floor(delay * 30)
        repeatInterval = math.floor(repeatInterval * 30)
    end
    
    local task = {
        func = func,
        delay = delay,
        repeatInterval = repeatInterval,
        remaining = delay,
        taskId = taskId
    }
    
    ServerScheduler.tasks[taskId] = task
    addToPriorityQueue(task)
    
    return taskId
end

---Cancel a scheduled task
---@param taskId number The ID of the task to cancel
---@return boolean success Whether the task was successfully cancelled
function ServerScheduler.cancel(taskId)
    if ServerScheduler.tasks[taskId] then
        ServerScheduler.tasks[taskId] = nil
        ServerScheduler.highPriorityTasks[taskId] = nil
        ServerScheduler.mediumPriorityTasks[taskId] = nil
        ServerScheduler.lowPriorityTasks[taskId] = nil
        ServerScheduler.lowestPriorityTasks[taskId] = nil
        return true
    end
    return false
end

---Update all scheduled tasks
function ServerScheduler.update()
    local toRemove = {}
    local toRequeue = {}

    -- Process high priority tasks (check every frame)
    for taskId, task in pairs(ServerScheduler.highPriorityTasks) do
        if task.remaining > 0 then
            task.remaining = task.remaining - 1
        else
            -- Execute task
            local success, err = pcall(task.func)
            if not success then
                gg.log("[ERROR] Scheduled task failed:", err)
            end
            
            -- Handle repeat
            if task.repeatInterval > 0 then
                task.remaining = task.repeatInterval
                table.insert(toRequeue, task)
            else
                table.insert(toRemove, taskId)
            end
        end
    end

    -- Process medium priority tasks (check every 10 frames)
    if ServerScheduler.tick % 10 == 0 then
        for taskId, task in pairs(ServerScheduler.mediumPriorityTasks) do
            if task.remaining > 10 then
                task.remaining = task.remaining - 10
                table.insert(toRequeue, task)
            else
                task.remaining = task.remaining - 1
                if task.remaining <= 0 then
                    local success, err = pcall(task.func)
                    if not success then
                        gg.log("[ERROR] Scheduled task failed:", err)
                    end
                    
                    if task.repeatInterval > 0 then
                        task.remaining = task.repeatInterval
                        table.insert(toRequeue, task)
                    else
                        table.insert(toRemove, taskId)
                    end
                else
                    table.insert(toRequeue, task)
                end
            end
        end
    end

    -- Process low priority tasks (check every 100 frames)
    if ServerScheduler.tick % 100 == 0 then
        for taskId, task in pairs(ServerScheduler.lowPriorityTasks) do
            if task.remaining > 100 then
                task.remaining = task.remaining - 100
                table.insert(toRequeue, task)
            else
                task.remaining = task.remaining - 10
                if task.remaining <= 0 then
                    local success, err = pcall(task.func)
                    if not success then
                        gg.log("[ERROR] Scheduled task failed:", err)
                    end
                    
                    if task.repeatInterval > 0 then
                        task.remaining = task.repeatInterval
                        table.insert(toRequeue, task)
                    else
                        table.insert(toRemove, taskId)
                    end
                else
                    table.insert(toRequeue, task)
                end
            end
        end

        -- Process lowest priority tasks
        for taskId, task in pairs(ServerScheduler.lowestPriorityTasks) do
            if task.remaining > 100 then
                task.remaining = task.remaining - 100
                table.insert(toRequeue, task)
            else
                task.remaining = task.remaining - 10
                if task.remaining <= 0 then
                    local success, err = pcall(task.func)
                    if not success then
                        gg.log("[ERROR] Scheduled task failed:", err)
                    end
                    
                    if task.repeatInterval > 0 then
                        task.remaining = task.repeatInterval
                        table.insert(toRequeue, task)
                    else
                        table.insert(toRemove, taskId)
                    end
                else
                    table.insert(toRequeue, task)
                end
            end
        end
    end

    -- Remove completed tasks
    for _, taskId in ipairs(toRemove) do
        ServerScheduler.tasks[taskId] = nil
        ServerScheduler.highPriorityTasks[taskId] = nil
        ServerScheduler.mediumPriorityTasks[taskId] = nil
        ServerScheduler.lowPriorityTasks[taskId] = nil
        ServerScheduler.lowestPriorityTasks[taskId] = nil
    end

    -- Requeue tasks to appropriate priority queues
    for _, task in ipairs(toRequeue) do
        if ServerScheduler.tasks[task.taskId] then
            ServerScheduler.highPriorityTasks[task.taskId] = nil
            ServerScheduler.mediumPriorityTasks[task.taskId] = nil
            ServerScheduler.lowPriorityTasks[task.taskId] = nil
            ServerScheduler.lowestPriorityTasks[task.taskId] = nil
            addToPriorityQueue(task)
        end
    end
end

return ServerScheduler