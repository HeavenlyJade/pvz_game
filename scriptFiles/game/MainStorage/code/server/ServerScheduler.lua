local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg

---@class Task
---@field func function The function to execute
---@field delay number Delay in seconds before first execution
---@field repeatInterval number Repeat interval in seconds (0 for one-time execution)
---@field remaining number Remaining ticks before execution
---@field taskId number Unique identifier for the task
---@field rounds number For time wheel implementation (number of wheel rotations needed)

print("ServerScheduler INIT")
---@class ServerScheduler
local ServerScheduler = {
    tasks = {},  -- All tasks by ID
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
---@return number taskId The ID of the created task
function ServerScheduler.add(func, delay, repeatInterval)
    local taskId = ServerScheduler.nextTaskId
    ServerScheduler.nextTaskId = ServerScheduler.nextTaskId + 1
    
    delay = delay * 30
    if not repeatInterval then
        repeatInterval = 0
    end
    
    -- Calculate rounds and slot for the time wheel
    local totalDelay = delay
    local rounds = math.floor(totalDelay / (ServerScheduler.wheelSlots * ServerScheduler.wheelPrecision))
    local slot = (ServerScheduler.currentSlot + math.floor(totalDelay / ServerScheduler.wheelPrecision) - 1) % ServerScheduler.wheelSlots + 1
    
    local task = {
        func = func,
        delay = delay,
        repeatInterval = repeatInterval * 30,
        remaining = delay,
        taskId = taskId,
        rounds = rounds
    }
    
    ServerScheduler.tasks[taskId] = task
    table.insert(ServerScheduler.timeWheel[slot], task)
    
    return taskId
end

---Cancel a scheduled task
---@param taskId number The ID of the task to cancel
---@return nil
function ServerScheduler.cancel(taskId)
    ServerScheduler.tasks[taskId] = nil
    -- The task will be removed from the wheel when its slot is processed
end

---Update all scheduled tasks
function ServerScheduler.update()
    local tasks = ServerScheduler.timeWheel[ServerScheduler.currentSlot]
    local remainingTasks = {}
    local tasksToReschedule = {}  -- 新增：收集需要重新调度的任务
    
    for _, task in ipairs(tasks) do
        if ServerScheduler.tasks[task.taskId] then  -- Check if task wasn't cancelled
            if task.rounds <= 0 then
                -- Execute the task
                local success, err = pcall(task.func)
                if not success then
                    gg.log("[ERROR] Scheduled task failed:", err)
                end
                
                -- Handle repeating tasks
                if task.repeatInterval > 0 then
                    -- 将需要重新调度的任务收集起来
                    local newRounds = math.floor(task.repeatInterval / (ServerScheduler.wheelSlots * ServerScheduler.wheelPrecision))
                    local newSlot = (ServerScheduler.currentSlot + math.floor(task.repeatInterval / ServerScheduler.wheelPrecision) - 1) % ServerScheduler.wheelSlots + 1
                    
                    task.rounds = newRounds
                    table.insert(tasksToReschedule, {task = task, slot = newSlot})
                else
                    -- Remove one-time tasks
                    ServerScheduler.tasks[task.taskId] = nil
                end
            else
                -- Task needs more rounds, decrement and keep
                task.rounds = task.rounds - 1
                table.insert(remainingTasks, task)
            end
        end
    end
    
    -- 更新当前槽位的任务
    ServerScheduler.timeWheel[ServerScheduler.currentSlot] = remainingTasks
    
    -- 处理需要重新调度的任务
    for _, rescheduleInfo in ipairs(tasksToReschedule) do
        table.insert(ServerScheduler.timeWheel[rescheduleInfo.slot], rescheduleInfo.task)
    end
    
    ServerScheduler.currentSlot = ServerScheduler.currentSlot % ServerScheduler.wheelSlots + 1
end

return ServerScheduler