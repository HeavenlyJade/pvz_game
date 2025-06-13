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

---@class ClientScheduler
local ClientScheduler = {
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
    tick = 0,
    
    -- FPS control
    lastFrameTime = 0,       -- 上一帧的时间
}

-- Initialize the time wheel
for i = 1, ClientScheduler.wheelSlots do
    ClientScheduler.timeWheel[i] = {}
end

---Add a new scheduled task
---@param func function The function to execute
---@param delay number Delay in seconds before first execution
---@param repeatInterval? number Repeat interval in seconds (0 for one-time execution)
---@return number taskId The ID of the created task
function ClientScheduler.add(func, delay, repeatInterval)
    local taskId = ClientScheduler.nextTaskId
    ClientScheduler.nextTaskId = ClientScheduler.nextTaskId + 1
    
    delay = delay * 30
    if not repeatInterval then
        repeatInterval = 0
    end
    
    -- Calculate rounds and slot for the time wheel
    local totalDelay = delay
    local rounds = math.floor(totalDelay / (ClientScheduler.wheelSlots * ClientScheduler.wheelPrecision))
    local slot = (ClientScheduler.currentSlot + math.floor(totalDelay / ClientScheduler.wheelPrecision) - 1) % ClientScheduler.wheelSlots + 1
    
    local task = {
        func = func,
        delay = delay,
        repeatInterval = repeatInterval * 30,
        remaining = delay,
        taskId = taskId,
        rounds = rounds
    }
    
    ClientScheduler.tasks[taskId] = task
    table.insert(ClientScheduler.timeWheel[slot], task)
    
    return taskId
end

---Cancel a scheduled task
---@param taskId number The ID of the task to cancel
---@return nil
function ClientScheduler.cancel(taskId)
    ClientScheduler.tasks[taskId] = nil
    -- The task will be removed from the wheel when its slot is processed
end

---Update all scheduled tasks
function ClientScheduler.update()
    local tasks = ClientScheduler.timeWheel[ClientScheduler.currentSlot]
    local remainingTasks = {}
    local tasksToReschedule = {}  -- 新增：收集需要重新调度的任务
    
    for _, task in ipairs(tasks) do
        if ClientScheduler.tasks[task.taskId] then  -- Check if task wasn't cancelled
            if task.rounds <= 0 then
                -- Execute the task
                local success, err = pcall(task.func)
                if not success then
                    gg.log("[ERROR] Scheduled task failed:", err)
                end
                
                -- Handle repeating tasks
                if task.repeatInterval > 0 then
                    -- 将需要重新调度的任务收集起来
                    local newRounds = math.floor(task.repeatInterval / (ClientScheduler.wheelSlots * ClientScheduler.wheelPrecision))
                    local newSlot = (ClientScheduler.currentSlot + math.floor(task.repeatInterval / ClientScheduler.wheelPrecision) - 1) % ClientScheduler.wheelSlots + 1
                    
                    task.rounds = newRounds
                    table.insert(tasksToReschedule, {task = task, slot = newSlot})
                else
                    -- Remove one-time tasks
                    ClientScheduler.tasks[task.taskId] = nil
                end
            else
                -- Task needs more rounds, decrement and keep
                task.rounds = task.rounds - 1
                table.insert(remainingTasks, task)
            end
        end
    end
    
    -- 更新当前槽位的任务
    ClientScheduler.timeWheel[ClientScheduler.currentSlot] = remainingTasks
    
    -- 处理需要重新调度的任务
    for _, rescheduleInfo in ipairs(tasksToReschedule) do
        table.insert(ClientScheduler.timeWheel[rescheduleInfo.slot], rescheduleInfo.task)
    end
    
    ClientScheduler.currentSlot = ClientScheduler.currentSlot % ClientScheduler.wheelSlots + 1
end

game.RunService.Stepped:Connect(ClientScheduler.update)

return ClientScheduler