--- 主线任务实现类
--- V109 miniw-haima

local game = game
local pairs = pairs
local table = table
local os = os

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local common_const = require(MainStorage.code.common.MConst)  ---@type common_const
local ClassMgr = require(MainStorage.code.common.ClassMgr)  ---@type ClassMgr
local BaseTask = require(MainStorage.code.server.TaskSystem.tasks.BaseTask) ---@type BaseTask

---@class MainLineTask:BaseTask
local MainLineTask = ClassMgr.Class('MainLineTask', BaseTask)

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化任务
function MainLineTask:OnInit(taskData)
    self.id = taskData.id                        -- 任务ID
    self.name = taskData.name                    -- 任务名称
    self.description = taskData.description      -- 任务描述
    self.location = taskData.location            -- 任务位置
    self.npc = taskData.npc                      -- 相关NPC
    self.config = taskData                       -- 任务配置
    
    -- 任务目标
    self.objectives = {}
    if taskData.objectives then
        for _, objectiveData in ipairs(taskData.objectives) do
            -- 目标数据初始化
            table.insert(self.objectives, {
                type = objectiveData.type,
                target = objectiveData.target,
                current = 0,
                required = objectiveData.count or 1,
                completed = false
            })
        end
    end
    
    -- 任务状态
    self.status = "未接取"         -- 可能的状态: 未接取, 进行中, 已完成, 已失败
    self.startTime = nil           -- 开始时间
    self.completeTime = nil        -- 完成时间
    self.dialogueProgress = 0      -- 对话进度
end

--------------------------------------------------
-- 任务状态管理
--------------------------------------------------

-- 接取任务
function MainLineTask:Accept(player)
    if self.status ~= "未接取" then
        return false, "无法接取任务：任务状态错误"
    end
    
    -- -- 检查任务前置条件
    -- if self.config.unlock_condition then
    --     player:ExecuteCommand(self.config.unlock_condition)
    --     if not conditionsMet then
    --         return false, "无法接取任务：未满足前置条件"
    --     end
    -- end
    
    -- 更新任务状态
    self.status = "进行中"
    self.startTime = os.time()
    
    -- 初始化任务目标
    for i, _ in ipairs(self.objectives) do
        self.objectives[i].current = 0
        self.objectives[i].completed = false
    end
    
    -- 通知玩家
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "已接取任务：" .. self.name,
        color = ColorQuad.New(0, 255, 0, 255)
    })
    
    return true, "成功接取任务"
end

-- 更新任务目标进度
function MainLineTask:UpdateObjective(player, objectiveIndex, progress)
    if self.status ~= "进行中" then
        return false, "无法更新目标：任务不在进行中"
    end
    
    -- 检查目标索引是否有效
    if not self.objectives[objectiveIndex] then
        return false, "无法更新目标：目标索引无效"
    end
    
    local objective = self.objectives[objectiveIndex]
    
    -- 更新进度
    objective.current = math.min(objective.current + progress, objective.required)
    
    -- 检查是否完成
    if objective.current >= objective.required and not objective.completed then
        objective.completed = true
        
        -- 通知玩家
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "目标已完成！",
            color = ColorQuad.New(0, 255, 0, 255)
        })
        
        -- 检查所有目标是否完成
        self:CheckCompletion(player)
    end
    
    return true, "目标进度已更新"
end

-- 检查任务是否可以完成
function MainLineTask:CheckCompletion(player)
    if self.status ~= "进行中" then
        return false, "无法检查完成状态：任务不在进行中"
    end
    
    -- 检查所有目标是否完成
    for _, objective in ipairs(self.objectives) do
        if not objective.completed then
            return false, "任务未完成：还有未完成的目标"
        end
    end
    
    -- 检查自定义完成条件
    -- if self.config.complete_conditions then
    --     local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)  ---@type CommandManager
    --     local conditionsMet = CommandManager:ProcessCommands(self.config.complete_conditions, player)
    --     if not conditionsMet then
    --         return false, "任务未完成：未满足完成条件"
    --     end
    -- end
    
    -- 更新任务状态为待领取
    self.status = "待领取"
    
    -- 通知玩家
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "任务已完成，请返回领取奖励！",
        color = ColorQuad.New(0, 255, 0, 255)
    })
    
    return true, "任务已完成"
end

-- 完成任务并领取奖励
function MainLineTask:Complete(player)
    if self.status ~= "待领取" then
        return false, "无法完成任务：任务状态错误"
    end
    
    -- 发放任务奖励
    -- if self.config.rewards then
    --     CommandManager:ProcessRewards(self.config.rewards, player)
    -- end
    
    -- 更新任务状态
    self.status = "已完成"
    self.completeTime = os.time()
    
    -- 通知玩家
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "任务已完成，奖励已发放！",
        color = ColorQuad.New(0, 255, 0, 255)
    })
    
    -- 解锁后续任务
    -- if self.config.next_quest then
    --     CommandManager:ExecuteCommand("任务 主线 设置 " .. self.config.next_quest .. " 状态 = 进行中", player)
    -- end
    
    return true, "任务已完成"
end

--------------------------------------------------
-- 任务对话和UI相关
--------------------------------------------------

-- 设置对话进度
function MainLineTask:SetDialogueProgress(player, progress)
    self.dialogueProgress = progress
    
    -- 检查是否是最后一段对话
    if self.config.dialogue and self.config.dialogue.sequence then
        local dialogueLength = #self.config.dialogue.sequence
        if progress >= dialogueLength and self.status == "进行中" then
            -- 完成对话可能会触发目标完成
            for i, objective in ipairs(self.objectives) do
                if objective.type == "talk" and not objective.completed then
                    self:UpdateObjective(player, i, 1)
                end
            end
        end
    end
    
    return true
end

-- 获取对话内容
function MainLineTask:GetDialogue(progress)
    if not self.config.dialogue or not self.config.dialogue.sequence then
        return nil
    end
    
    return self.config.dialogue.sequence[progress]
end

-- 获取任务数据（用于UI展示）
function MainLineTask:GetUIData()
    local objectivesData = {}
    
    for i, objective in ipairs(self.objectives) do
        table.insert(objectivesData, {
            type = objective.type,
            target = objective.target,
            current = objective.current,
            required = objective.required,
            completed = objective.completed,
            description = self:GetObjectiveDescription(objective)
        })
    end
    
    return {
        id = self.id,
        name = self.name,
        description = self.description,
        status = self.status,
        location = self.location,
        objectives = objectivesData
    }
end

-- 获取目标描述
function MainLineTask:GetObjectiveDescription(objective)
    local targetName = objective.target
    local typeText = common_config.typeText[objective.type] or "未知目标"
    
    -- 根据目标类型生成描述
    if objective.type == "kill" then
        return "击杀 " .. targetName .. " (" .. objective.current .. "/" .. objective.required .. ")"
    elseif objective.type == "collect" then
        return "收集 " .. targetName .. " (" .. objective.current .. "/" .. objective.required .. ")"
    elseif objective.type == "talk" then
        return "与 " .. targetName .. " 对话"
    elseif objective.type == "visit" then
        return "前往 " .. targetName
    else
        return typeText .. " (" .. objective.current .. "/" .. objective.required .. ")"
    end
end

return MainLineTask