--- 支线任务实现类
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
local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)  ---@type CommandManager
local BaseTask = require(MainStorage.code.server.TaskSystem.tasks.BaseTask) ---@type BaseTask

---@class BranchTask:BaseTask
local BranchTask = ClassMgr.Class('BranchTask', BaseTask)

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化任务
function BranchTask:OnInit(taskData)
    self.id = taskData.id                        -- 任务ID
    self.name = taskData.name                    -- 任务名称
    self.description = taskData.description      -- 任务描述
    self.location = taskData.location            -- 任务位置
    self.npc = taskData.npc                      -- 相关NPC
    self.config = taskData                       -- 任务配置
    self.prerequisite = taskData.prerequisite    -- 前置任务要求
    self.timeLimit = taskData.timeLimit          -- 时间限制（如果有）
    
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
                completed = false,
                optional = objectiveData.optional or false  -- 支线任务可能有可选目标
            })
        end
    end
    
    -- 支线任务特有属性
    self.branches = taskData.branches or {}      -- 分支选择
    self.selectedBranch = nil                    -- 玩家选择的分支
    self.repeatableCooldown = taskData.repeatableCooldown  -- 如果是可重复任务的冷却时间
    self.lastCompletionTime = nil                -- 最后一次完成时间
    
    -- 任务状态
    self.status = "未接取"         -- 可能的状态: 未接取, 进行中, 已完成, 已失败, 冷却中
    self.startTime = nil           -- 开始时间
    self.completeTime = nil        -- 完成时间
    self.dialogueProgress = 0      -- 对话进度
end

--------------------------------------------------
-- 任务状态管理
--------------------------------------------------

-- 接取任务
function BranchTask:Accept(player)
    if self.status ~= "未接取" then
        if self.status == "冷却中" then
            return false, "该任务正在冷却中，请稍后再试"
        else
            return false, "无法接取任务：任务状态错误"
        end
    end
    
    -- 检查任务前置条件
    if self.config.unlock_condition then
        local conditionsMet = CommandManager:ProcessCommands(self.config.unlock_condition, player)
        if not conditionsMet then
            return false, "无法接取任务：未满足前置条件"
        end
    end
    
    -- 检查前置任务是否完成
    if self.prerequisite then
        for _, prerequisiteId in ipairs(self.prerequisite) do
            local questStatus = player:GetQuestStatus("branch_line", prerequisiteId) 
            if questStatus ~= "已完成" then
                return false, "需要先完成其它任务"
            end
        end
    end
    
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
        txt = "已接取支线任务：" .. self.name,
        color = ColorQuad.new(0, 255, 0, 255)
    })
    
    -- 如果有时间限制，开始计时
    if self.timeLimit then
        -- 设置任务超时定时器
        self:StartTimeLimit(player)
    end
    
    return true, "成功接取任务"
end

-- 开始时间限制
function BranchTask:StartTimeLimit(player)
    local function timeoutCheck()
        -- 等待时间限制
        wait(self.timeLimit)
        
        -- 检查任务是否还在进行中
        if self.status == "进行中" then
            -- 任务超时，标记为失败
            self.status = "已失败"
            
            -- 通知玩家
            gg.network_channel:fireClient(player.uin, {
                cmd = "cmd_client_show_msg",
                txt = "任务失败：时间已用尽！",
                color = ColorQuad.new(255, 0, 0, 255)
            })
            
            -- 同步任务状态
            player:syncGameTaskData()
        end
    end
    
    -- 使用协程异步检查超时
    coroutine.work(timeoutCheck)
end

-- 更新任务目标进度
function BranchTask:UpdateObjective(player, objectiveIndex, progress)
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
            txt = "支线任务目标已完成！",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        -- 检查所有必须目标是否完成
        self:CheckCompletion(player)
    end
    
    return true, "目标进度已更新"
end

-- 选择分支
function BranchTask:SelectBranch(player, branchId)
    if self.status ~= "进行中" then
        return false, "无法选择分支：任务不在进行中"
    end
    
    -- 检查分支ID是否有效
    if not self.branches[branchId] then
        return false, "无法选择分支：分支不存在"
    end
    
    -- 如果已经选择了分支
    if self.selectedBranch then
        return false, "已经选择了分支，无法更改"
    end
    
    -- 更新选择的分支
    self.selectedBranch = branchId
    
    -- 更新分支特定的目标
    if self.branches[branchId].objectives then
        -- 替换或添加分支特定的目标
        for _, objectiveData in ipairs(self.branches[branchId].objectives) do
            table.insert(self.objectives, {
                type = objectiveData.type,
                target = objectiveData.target,
                current = 0,
                required = objectiveData.count or 1,
                completed = false,
                optional = objectiveData.optional or false
            })
        end
    end
    
    -- 通知玩家
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "已选择分支：" .. self.branches[branchId].name,
        color = ColorQuad.new(0, 255, 0, 255)
    })
    
    -- 同步任务状态
    player:syncGameTaskData()
    
    return true, "分支选择成功"
end

-- 检查任务是否可以完成
function BranchTask:CheckCompletion(player)
    if self.status ~= "进行中" then
        return false, "无法检查完成状态：任务不在进行中"
    end
    
    -- 检查所有必须目标是否完成（跳过可选目标）
    for _, objective in ipairs(self.objectives) do
        if not objective.optional and not objective.completed then
            return false, "任务未完成：还有未完成的必要目标"
        end
    end
    
    -- 检查选择的分支目标
    if self.selectedBranch and self.branches[self.selectedBranch].objectives then
        -- 已经在上面的循环中检查了
    elseif #self.branches > 0 and not self.selectedBranch then
        -- 需要选择分支但还没选择
        return false, "请先选择一个任务分支"
    end
    
    -- 检查自定义完成条件
    if self.config.complete_conditions then
        local conditionsMet = CommandManager:ProcessCommands(self.config.complete_conditions, player)
        if not conditionsMet then
            return false, "任务未完成：未满足完成条件"
        end
    end
    
    -- 更新任务状态为待领取
    self.status = "待领取"
    
    -- 通知玩家
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "支线任务已完成，请返回领取奖励！",
        color = ColorQuad.new(0, 255, 0, 255)
    })
    
    return true, "任务已完成"
end

-- 完成任务并领取奖励
function BranchTask:Complete(player)
    if self.status ~= "待领取" then
        return false, "无法完成任务：任务状态错误"
    end
    
    -- 发放任务奖励
    if self.config.rewards then
        -- 基础奖励
        CommandManager:ProcessRewards(self.config.rewards, player)
    end
    
    -- 如果选择了分支，发放分支特定奖励
    if self.selectedBranch and self.branches[self.selectedBranch].rewards then
        CommandManager:ProcessRewards(self.branches[self.selectedBranch].rewards, player)
    end
    
    -- 更新任务状态
    self.status = "已完成"
    self.completeTime = os.time()
    self.lastCompletionTime = os.time()
    
    -- 通知玩家
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "支线任务已完成，奖励已发放！",
        color = ColorQuad.new(0, 255, 0, 255)
    })
    
    -- 如果是可重复任务，设置冷却时间
    if self.repeatableCooldown then
        -- 将任务状态设置为冷却中
        self.status = "冷却中"
        
        -- 设置冷却定时器
        self:StartCooldown(player)
    end
    
    -- 解锁后续任务
    if self.config.next_quest then
        CommandManager:ExecuteCommand("任务 支线 设置 " .. self.config.next_quest .. " 状态 = 进行中", player)
    end
    
    return true, "任务已完成"
end

-- 开始冷却倒计时
function BranchTask:StartCooldown(player)
    local function cooldownCheck()
        -- 等待冷却时间
        wait(self.repeatableCooldown)
        
        -- 冷却结束，重置任务
        self.status = "未接取"
        
        -- 通知玩家
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "支线任务 " .. self.name .. " 已重置，可以再次接取！",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        -- 同步任务状态
        player:syncGameTaskData()
    end
    
    -- 使用协程异步检查冷却
    coroutine.work(cooldownCheck)
end

--------------------------------------------------
-- 任务对话和UI相关
--------------------------------------------------

-- 设置对话进度
function BranchTask:SetDialogueProgress(player, progress)
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
function BranchTask:GetDialogue(progress)
    if not self.config.dialogue or not self.config.dialogue.sequence then
        return nil
    end
    
    -- 如果选择了分支，可能有分支特定对话
    if self.selectedBranch and 
       self.branches[self.selectedBranch].dialogue and 
       self.branches[self.selectedBranch].dialogue.sequence then
        return self.branches[self.selectedBranch].dialogue.sequence[progress]
    end
    
    return self.config.dialogue.sequence[progress]
end

-- 获取任务数据（用于UI展示）
function BranchTask:GetUIData()
    local objectivesData = {}
    
    for i, objective in ipairs(self.objectives) do
        table.insert(objectivesData, {
            type = objective.type,
            target = objective.target,
            current = objective.current,
            required = objective.required,
            completed = objective.completed,
            optional = objective.optional,
            description = self:GetObjectiveDescription(objective)
        })
    end
    
    local branchesData = {}
    for id, branch in pairs(self.branches) do
        branchesData[id] = {
            id = id,
            name = branch.name,
            description = branch.description,
            selected = (self.selectedBranch == id)
        }
    end
    
    -- 计算剩余时间（如果有时间限制）
    local timeRemaining = nil
    if self.timeLimit and self.startTime and self.status == "进行中" then
        local elapsedTime = os.time() - self.startTime
        timeRemaining = math.max(0, self.timeLimit - elapsedTime)
    end
    
    -- 计算冷却剩余时间（如果在冷却中）
    local cooldownRemaining = nil
    if self.repeatableCooldown and self.lastCompletionTime and self.status == "冷却中" then
        local elapsedTime = os.time() - self.lastCompletionTime
        cooldownRemaining = math.max(0, self.repeatableCooldown - elapsedTime)
    end
    
    return {
        id = self.id,
        name = self.name,
        description = self.description,
        status = self.status,
        location = self.location,
        timeRemaining = timeRemaining,
        cooldownRemaining = cooldownRemaining,
        objectives = objectivesData,
        branches = branchesData,
        selectedBranch = self.selectedBranch
    }
end

-- 获取目标描述
function BranchTask:GetObjectiveDescription(objective)
    local targetName = objective.target
    local typeText = common_config.typeText[objective.type] or "未知目标"
    local optionalText = objective.optional and "[可选] " or ""
    
    -- 根据目标类型生成描述
    if objective.type == "kill" then
        return optionalText .. "击杀 " .. targetName .. " (" .. objective.current .. "/" .. objective.required .. ")"
    elseif objective.type == "collect" then
        return optionalText .. "收集 " .. targetName .. " (" .. objective.current .. "/" .. objective.required .. ")"
    elseif objective.type == "talk" then
        return optionalText .. "与 " .. targetName .. " 对话"
    elseif objective.type == "visit" then
        return optionalText .. "前往 " .. targetName
    else
        return optionalText .. typeText .. " (" .. objective.current .. "/" .. objective.required .. ")"
    end
end

return BranchTask