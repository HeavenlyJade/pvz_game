--- 任务相关命令处理器
--- V109 miniw-haima 修改版

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class QuestCommands
local QuestCommands = {}

-- 命令执行器工厂
local CommandExecutors = {}

-- 设置任务状态执行器
function CommandExecutors.SetQuestState(params, player)
    -- 新格式示例: "任务 主线 设置 1001 状态 %p = 进行中"
    local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem)
    
    if params.category ~= "任务" then return false end
    
    local questType = params.subcategory  -- 主线/支线/日常
    local questId = tonumber(params.id)
    
    if params.action == "状态" then
        -- 设置任务状态 (保留在Player中的方法)
        player:SetQuestStatus(questType, questId, "状态", params.value)
        return true
    elseif params.action == "追踪" then
        -- 设置任务追踪 (保留在Player中的方法)
        player:SetQuestTracking(questType, questId, params.value == "1")
        return true
    elseif params.action == "对话" and params.param == "进度" then
        -- 设置任务对话进度 (使用TaskSystem的方法)
        return TaskSystem:SetQuestDialogueProgress(player, questType, questId, tonumber(params.value))
    end
    
    return false
end

-- 更新任务目标进度执行器
function CommandExecutors.UpdateQuestObjective(params, player)
    -- 新格式示例: "任务 主线 更新 1001 目标 1 进度 %p = 1"
    local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem)
    
    if params.category ~= "任务" then return false end
    
    local questType = params.subcategory  -- 主线/支线/日常
    local questId = tonumber(params.id)
    
    if params.action == "目标" then
        local targetIndex = tonumber(params.param)
        -- 更新特定目标的进度为指定值 (保留在Player中的方法)
        player:UpdateQuestObjectiveProgress(questType, questId, targetIndex, tonumber(params.value))
        
        -- 检查是否所有目标都已完成 (使用TaskSystem的方法)
        TaskSystem:CheckQuestCompletion(player, questType, questId)
        
        return true
    end
    
    return false
end

-- 增加任务目标进度执行器
function CommandExecutors.IncrementQuestProgress(params, player)
    -- 新格式示例: "任务 主线 增加 1001 目标 2 进度 %p = 1"
    local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem)
    
    if params.category ~= "任务" then return false end
    
    local questType = params.subcategory  -- 主线/支线/日常
    local questId = tonumber(params.id)
    
    if params.action == "目标" then
        local targetIndex = tonumber(params.param)
        
        -- 获取当前进度 (保留在Player中的方法)
        local currentProgress = player:GetQuestObjectiveProgress(questType, questId, targetIndex)
        -- 获取最大进度 (使用TaskSystem的方法)
        local maxProgress = TaskSystem:GetQuestObjectiveMaxProgress(player, questType, questId, targetIndex)
        
        -- 增加进度值，但不超过最大值
        local newProgress = math.min(currentProgress + tonumber(params.value), maxProgress)
        
        -- 更新进度 (保留在Player中的方法)
        player:UpdateQuestObjectiveProgress(questType, questId, targetIndex, newProgress)
        
        -- 通知客户端更新任务UI
        player:syncGameTaskData()
        
        -- 如果单个目标完成，显示通知
        if newProgress >= maxProgress and currentProgress < maxProgress then
            gg.network_channel:fireClient(player.uin, {
                cmd = "cmd_client_show_msg",
                txt = "任务目标已完成!",
                color = ColorQuad.new(0, 255, 0, 255)
            })
        end
        
        -- 检查所有目标是否完成 (使用TaskSystem的方法)
        TaskSystem:CheckQuestCompletion(player, questType, questId)
        
        return true
    end
    
    return false
end

-- 完成任务目标执行器
function CommandExecutors.CompleteQuestObjective(params, player)
    -- 新格式示例: "任务 主线 完成 1001 目标 3 %p = 1"
    local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem)
    
    if params.category ~= "任务" then return false end
    
    local questType = params.subcategory  -- 主线/支线/日常
    local questId = tonumber(params.id)
    
    if params.action == "目标" then
        local targetIndex = tonumber(params.param)
        
        -- 直接将目标设置为最大进度值 (结合使用Player和TaskSystem的方法)
        local maxProgress = TaskSystem:GetQuestObjectiveMaxProgress(player, questType, questId, targetIndex)
        player:UpdateQuestObjectiveProgress(questType, questId, targetIndex, maxProgress)
        
        -- 检查所有目标是否完成 (使用TaskSystem的方法)
        TaskSystem:CheckQuestCompletion(player, questType, questId)
        
        return true
    end
    
    return false
end

-- 解锁任务步骤执行器
function CommandExecutors.UnlockQuestStep(params, player)
    -- 新格式示例: "任务 主线 解锁 1001 步骤 2 %p = 1"
    local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem)
    
    if params.category ~= "任务" then return false end
    
    local questType = params.subcategory  -- 主线/支线/日常
    local questId = tonumber(params.id)
    
    if params.action == "步骤" then
        local stepIndex = tonumber(params.param)
        -- 使用TaskSystem的方法
        return TaskSystem:UnlockQuestStep(player, questType, questId, stepIndex)
    elseif params.action == "对话" and params.param == "分支" then
        local branchId = params.value
        -- 使用TaskSystem的方法
        return TaskSystem:UnlockQuestDialogueBranch(player, questType, questId, branchId)
    end
    
    return false
end

-- 命令映射表
local CommandMapping = {
    ["设置"] = CommandExecutors.SetQuestState,
    ["更新"] = CommandExecutors.UpdateQuestObjective,
    ["增加"] = CommandExecutors.IncrementQuestProgress,
    ["完成"] = CommandExecutors.CompleteQuestObjective,
    ["解锁"] = CommandExecutors.UnlockQuestStep,
}

-- 命令执行函数
function QuestCommands.Execute(operation, params, player)
    local executor = CommandMapping[operation]
    if not executor then
        gg.log("未知任务命令: " .. operation)
        return false
    end
    
    return executor(params, player)
end

-- 兼容旧版接口
QuestCommands.handlers = {}
for command, executor in pairs(CommandMapping) do
    QuestCommands.handlers[command] = executor
end

return QuestCommands