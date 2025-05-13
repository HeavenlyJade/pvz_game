local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg

---@class ClientScheduler
local ClientScheduler = {
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
        ClientScheduler.highPriorityTasks[task.taskId] = task
    elseif task.remaining <= 10 then
        ClientScheduler.mediumPriorityTasks[task.taskId] = task
    elseif task.remaining <= 100 then
        ClientScheduler.lowPriorityTasks[task.taskId] = task
    else
        ClientScheduler.lowestPriorityTasks[task.taskId] = task
    end
end

---Add a new scheduled task
---@param func function The function to execute
---@param delay number Delay in seconds before first execution
---@param repeatInterval? number Repeat interval in seconds (0 for one-time execution)
---@param isInTick? boolean 是否单位是秒
---@return number taskId The ID of the created task
function ClientScheduler.add(func, delay, repeatInterval, isInTick)
    local taskId = ClientScheduler.nextTaskId
    ClientScheduler.nextTaskId = ClientScheduler.nextTaskId + 1
    repeatInterval = repeatInterval or 0
    if not isInTick then
        delay = math.floor(delay * 30)
        repeatInterval = math.floor(repeatInterval * 30)
    end
    print("add", delay, repeatInterval)
    local task = {
        func = func,
        delay = delay,
        repeatInterval = repeatInterval,
        remaining = delay,
        taskId = taskId
    }
    
    ClientScheduler.tasks[taskId] = task
    addToPriorityQueue(task)
    
    return taskId
end

---Cancel a scheduled task
---@param taskId number The ID of the task to cancel
---@return boolean success Whether the task was successfully cancelled
function ClientScheduler.cancel(taskId)
    if ClientScheduler.tasks[taskId] then
        ClientScheduler.tasks[taskId] = nil
        ClientScheduler.highPriorityTasks[taskId] = nil
        ClientScheduler.mediumPriorityTasks[taskId] = nil
        ClientScheduler.lowPriorityTasks[taskId] = nil
        ClientScheduler.lowestPriorityTasks[taskId] = nil
        return true
    end
    return false
end

---Update all scheduled tasks
function ClientScheduler.update()
    local toRemove = {}
    local toRequeue = {}

    -- Process high priority tasks (check every frame)
    for taskId, task in pairs(ClientScheduler.highPriorityTasks) do
        if task.remaining > 0 then
            task.remaining = task.remaining - 1
        else
            -- Execute task
            local success, err = pcall(task.func)
            if not success then
                gg.log("[ERROR_1] Scheduled task failed:", err)
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
    if ClientScheduler.tick % 10 == 0 then
        for taskId, task in pairs(ClientScheduler.mediumPriorityTasks) do
            if task.remaining > 10 then
                task.remaining = task.remaining - 10
                table.insert(toRequeue, task)
            else
                task.remaining = task.remaining - 1
                if task.remaining <= 0 then
                    local success, err = pcall(task.func)
                    if not success then
                        gg.log("[ERROR_2] Scheduled task failed:", err)
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
    if ClientScheduler.tick % 100 == 0 then
        for taskId, task in pairs(ClientScheduler.lowPriorityTasks) do
            if task.remaining > 100 then
                task.remaining = task.remaining - 100
                table.insert(toRequeue, task)
            else
                task.remaining = task.remaining - 10
                if task.remaining <= 0 then
                    local success, err = pcall(task.func)
                    if not success then
                        gg.log("[ERROR_3] Scheduled task failed:", err)
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
        for taskId, task in pairs(ClientScheduler.lowestPriorityTasks) do
            if task.remaining > 100 then
                task.remaining = task.remaining - 100
                table.insert(toRequeue, task)
            else
                task.remaining = task.remaining - 10
                if task.remaining <= 0 then
                    local success, err = pcall(task.func)
                    if not success then
                        gg.log("[ERROR_4] Scheduled task failed:", err)
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
        ClientScheduler.tasks[taskId] = nil
        ClientScheduler.highPriorityTasks[taskId] = nil
        ClientScheduler.mediumPriorityTasks[taskId] = nil
        ClientScheduler.lowPriorityTasks[taskId] = nil
        ClientScheduler.lowestPriorityTasks[taskId] = nil
    end

    -- Requeue tasks to appropriate priority queues
    for _, task in ipairs(toRequeue) do
        if ClientScheduler.tasks[task.taskId] then
            ClientScheduler.highPriorityTasks[task.taskId] = nil
            ClientScheduler.mediumPriorityTasks[task.taskId] = nil
            ClientScheduler.lowPriorityTasks[task.taskId] = nil
            ClientScheduler.lowestPriorityTasks[task.taskId] = nil
            addToPriorityQueue(task)
        end
    end
end

return ClientScheduler