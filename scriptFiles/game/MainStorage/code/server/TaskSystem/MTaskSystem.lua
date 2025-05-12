--- 任务系统 - 管理游戏中所有任务逻辑
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
-- 加载任务类
local MainLineTask = require(MainStorage.code.server.TaskSystem.tasks.MainLineTask)   ---@type MainLineTask
local BranchTask = require(MainStorage.code.server.TaskSystem.tasks.BranchTask)       ---@type BranchTask
local DailyTask = require(MainStorage.code.server.TaskSystem.tasks.DailyTask)         ---@type DailyTask

-- 加载目标类
local KillObjective = require(MainStorage.code.server.TaskSystem.objectives.KillObjective)     ---@type KillObjective
local CollectObjective = require(MainStorage.code.server.TaskSystem.objectives.CollectObjective) ---@type CollectObjective
local TalkObjective = require(MainStorage.code.server.TaskSystem.objectives.TalkObjective)     ---@type TalkObjective
local BaseObjective = require(MainStorage.code.server.TaskSystem.objectives.BaseObjective)     ---@type BaseObjective

---@class TaskSystem
local TaskSystem = CommonModule.Class("TaskSystem")

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化任务系统
function TaskSystem:OnInit()
    gg.log("任务系统初始化...")
    
    self.tasks = {
        main_line = {},    -- 主线任务
        branch_line = {},  -- 支线任务
        daily_task = {},   -- 日常任务
    }
    
    -- 从配置加载任务模板
    self:LoadTaskTemplates()
end

-- 加载任务模板
function TaskSystem:LoadTaskTemplates()
    -- 主线任务
    if common_config.main_line_task_config then
        for chapterKey, chapterData in pairs(common_config.main_line_task_config) do
            if chapterData.quests then
                for _, questData in ipairs(chapterData.quests) do
                    self.tasks.main_line[questData.id] = {
                        template = questData,
                        instances = {}  -- 玩家实例
                    }
                end
            end
        end
    end
    
    -- 支线任务（如果有配置）
    if common_config.branch_line_task_config then
        for branchKey, branchData in pairs(common_config.branch_line_task_config) do
            if branchData.quests then
                for _, questData in ipairs(branchData.quests) do
                    self.tasks.branch_line[questData.id] = {
                        template = questData,
                        instances = {}  -- 玩家实例
                    }
                end
            end
        end
    end
    
    -- 日常任务（如果有配置）
    if common_config.daily_task_config then
        for categoryKey, categoryData in pairs(common_config.daily_task_config) do
            if categoryData.quests then
                for _, questData in ipairs(categoryData.quests) do
                    self.tasks.daily_task[questData.id] = {
                        template = questData,
                        instances = {}  -- 玩家实例
                    }
                end
            end
        end
    end
end

--------------------------------------------------
-- 任务配置和初始化
--------------------------------------------------

-- 获取任务配置
function TaskSystem:GetQuestConfig(questId)
    -- 寻找匹配questId的任务配置
    for chapterKey, chapterData in pairs(common_config.main_line_task_config) do
        if chapterData.quests then
            for _, quest in ipairs(chapterData.quests) do
                if quest.id == questId then
                    return quest
                end
            end
        end
    end
    
    -- 查找支线任务
    if common_config.branch_line_task_config then
        for branchKey, branchData in pairs(common_config.branch_line_task_config) do
            if branchData.quests then
                for _, quest in ipairs(branchData.quests) do
                    if quest.id == questId then
                        return quest
                    end
                end
            end
        end
    end
    
    -- 查找日常任务
    if common_config.daily_task_config then
        for categoryKey, categoryData in pairs(common_config.daily_task_config) do
            if categoryData.quests then
                for _, quest in ipairs(categoryData.quests) do
                    if quest.id == questId then
                        return quest
                    end
                end
            end
        end
    end
    
    return nil
end

-- 创建任务实例
function TaskSystem:CreateTaskInstance(questType, questId, player)
    local taskTemplate = nil
    
    -- 获取任务模板
    if self.tasks[questType] and self.tasks[questType][questId] then
        taskTemplate = self.tasks[questType][questId].template
    else
        -- 尝试从配置中获取
        if questType == "main_line" then
            taskTemplate = self:GetQuestConfig(questId)
        end
    end
    
    if not taskTemplate then
        gg.log("错误：找不到任务模板，类型：" .. questType .. "，ID：" .. questId)
        return nil
    end
    
    -- 根据任务类型创建相应的实例
    local taskInstance = nil
    if questType == "main_line" then
        taskInstance = MainLineTask.New(taskTemplate)
    elseif questType == "branch_line" then
        taskInstance = BranchTask.New(taskTemplate)
    elseif questType == "daily_task" then
        taskInstance = DailyTask.New(taskTemplate)
    else
        gg.log("错误：未知任务类型：" .. questType)
        return nil
    end
    
    -- 创建并初始化任务目标
    if taskTemplate.objectives then
        taskInstance.objectives = self:CreateObjectives(taskTemplate.objectives, taskInstance)
    end
    
    -- 将任务实例与玩家关联
    if not self.tasks[questType][questId].instances[player.uin] then
        self.tasks[questType][questId].instances[player.uin] = taskInstance
    end
    
    return taskInstance
end

-- 创建任务目标
function TaskSystem:CreateObjectives(objectivesData, taskInstance)
    local objectives = {}
    
    for i, objectiveData in ipairs(objectivesData) do
        local objectiveInstance = nil
        
        -- 根据目标类型创建相应的实例
        if objectiveData.type == "kill" then
            objectiveInstance = KillObjective.New(objectiveData)
        elseif objectiveData.type == "collect" then
            objectiveInstance = CollectObjective.New(objectiveData)
        elseif objectiveData.type == "talk" then
            objectiveInstance = TalkObjective.New(objectiveData)
        else
            -- 默认使用基本目标类
            objectiveInstance = BaseObjective.New(objectiveData)
        end
        
        -- 设置关联任务
        objectiveInstance:SetTask(taskInstance)
        
        -- 添加到目标列表
        table.insert(objectives, objectiveInstance)
    end
    
    return objectives
end

-- 初始化任务目标（向后兼容）
function TaskSystem:InitObjectivesFromConfig(questConfig)
    local objectives_data = {}
    
    if questConfig.objectives then
        for i, objective in ipairs(questConfig.objectives) do
            objectives_data[i] = {
                type = objective.type,
                target_id = objective.target_id,
                target_name = objective.target_name,
                required = objective.count or 1,
                current = 0,
                locations = objective.locations
            }
        end
    end
    
    return objectives_data
end

-- 初始化玩家默认任务
function TaskSystem:InitDefaultTasks(player)
    if not common_config.main_line_task_config then return end
    
    for chapter_key, chapter_data in pairs(common_config.main_line_task_config) do
        if chapter_data.quests then
            for _, quest in ipairs(chapter_data.quests) do
                if quest.unlock_condition == nil then
                    -- 创建任务实例
                    local taskInstance = self:CreateTaskInstance("main_line", quest.id, player)
                    
                    if taskInstance then
                        -- 将任务添加到玩家的任务列表中
                        player.dict_game_task.main_line.progress[quest.id] = {
                            start_time = os.time(),
                            objectives = self:ExtractObjectivesData(taskInstance.objectives),
                            dialogue_progress = 0,
                            unlocked_steps = {[1] = true},
                            unlocked_branches = {},
                            tracking = {active = true},
                            custom_data = {}
                        }
                    else
                        -- 向后兼容的方式
                        local objectives_data = self:InitObjectivesFromConfig(quest)
                        
                        player.dict_game_task.main_line.progress[quest.id] = {
                            start_time = os.time(),
                            objectives = objectives_data,
                            dialogue_progress = 0,
                            unlocked_steps = {[1] = true},
                            unlocked_branches = {},
                            tracking = {active = true},
                            custom_data = {}
                        }
                    end
                end
            end
        end
    end
end

-- 提取目标数据（用于存储）
function TaskSystem:ExtractObjectivesData(objectives)
    local data = {}
    
    for i, objective in ipairs(objectives) do
        data[i] = {
            type = objective.type,
            target_id = objective.target_id,
            target = objective.target,
            required = objective.required,
            current = 0,
            completed = false
        }
    end
    
    return data
end

--------------------------------------------------
-- 任务验证和检查
--------------------------------------------------

-- 获取任务目标最大进度
function TaskSystem:GetQuestObjectiveMaxProgress(player, questType, questId, targetIndex)
    -- 先尝试从任务实例获取
    if self.tasks[questType] and self.tasks[questType][questId] and 
       self.tasks[questType][questId].instances[player.uin] then
        local taskInstance = self.tasks[questType][questId].instances[player.uin]
        if taskInstance.objectives and taskInstance.objectives[targetIndex] then
            return taskInstance.objectives[targetIndex].required
        end
    end
    
    -- 向后兼容：从配置获取
    local questConfig = self:GetQuestConfig(questId)
    if not questConfig or not questConfig.objectives or not questConfig.objectives[targetIndex] then
        return 1 -- 默认为1
    end
    
    return questConfig.objectives[targetIndex].count or 1
end

-- 检查所有任务目标是否完成
function TaskSystem:AreAllQuestObjectivesComplete(player, questType, questId)
    -- 先尝试从任务实例获取
    if self.tasks[questType] and self.tasks[questType][questId] and 
       self.tasks[questType][questId].instances[player.uin] then
        local taskInstance = self.tasks[questType][questId].instances[player.uin]
        if taskInstance.status == "进行中" then
            local allCompleted = true
            for _, objective in ipairs(taskInstance.objectives) do
                if not objective.optional and not objective.completed then
                    allCompleted = false
                    break
                end
            end
            return allCompleted
        end
    end
    
    -- 向后兼容：从玩家数据获取
    local questData = player:GetQuestData(questType, questId)
    if not questData or questData.status ~= "进行中" or not questData.data.objectives then
        return false
    end
    
    local questConfig = self:GetQuestConfig(questId)
    if not questConfig or not questConfig.objectives then
        return true -- 如果没有配置目标，视为已完成
    end
    
    for i, objective in ipairs(questConfig.objectives) do
        local currentProgress = questData.data.objectives[i] or 0
        local maxProgress = objective.count or 1
        
        if currentProgress < maxProgress then
            return false
        end
    end
    
    return true
end

-- 检查并更新任务完成状态
function TaskSystem:CheckQuestCompletion(player, questType, questId)
    if self:AreAllQuestObjectivesComplete(player, questType, questId) then
        -- 更新任务状态
        player:SetQuestStatus(questType, questId, "状态", "待领取")
        
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "任务目标已全部完成，请回到发布者处领取奖励",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        return true
    end
    
    return false
end

--------------------------------------------------
-- 奖励处理
--------------------------------------------------

-- 给予任务奖励
function TaskSystem:GiveTaskReward(player, taskId)
    -- 先尝试从任务实例获取
    local taskInstance = nil
    for questType, tasks in pairs(self.tasks) do
        if tasks[taskId] and tasks[taskId].instances[player.uin] then
            taskInstance = tasks[taskId].instances[player.uin]
            break
        end
    end
    
    if taskInstance and taskInstance.config.rewards then
        -- 处理命令格式的奖励
        local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)   ---@type CommandManager
        if type(taskInstance.config.rewards) == "table" and #taskInstance.config.rewards > 0 then
            CommandManager:ProcessRewards(taskInstance.config.rewards, player)
            return
        end
    end
    
    -- 向后兼容：从配置获取
    local task_config = self:GetQuestConfig(taskId)
    
    -- 检查任务配置和奖励
    if not task_config or not task_config.rewards then
        return
    end
    
    -- 处理对象格式的奖励
    -- 处理经验奖励
    if task_config.rewards.exp then
        player.exp = player.exp + task_config.rewards.exp
        -- 可以添加升级检查
    end
    
    -- 处理物品奖励
    if task_config.rewards.items then
        for _, item in ipairs(task_config.rewards.items) do
            -- 添加物品到背包
            player:AddItem(item.type, item.id, item.count)
        end
    end
    
    -- 处理其他奖励...
    -- 金币
    if task_config.rewards.gold then
        player:AddGold(task_config.rewards.gold)
    end
    
    -- 声望
    if task_config.rewards.reputation then
        for faction, amount in pairs(task_config.rewards.reputation) do
            player:SetReputation(faction, (player:GetReputation(faction) or 0) + amount)
        end
    end
    
    -- 处理命令格式的奖励
    if task_config.rewards.commands then
        local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)   ---@type CommandManager
        CommandManager:ProcessCommands(task_config.rewards.commands, player)
    end
end

--------------------------------------------------
-- 事件处理
--------------------------------------------------

-- 处理怪物击杀事件
function TaskSystem:HandleMonsterKilled(player, monsterId, dropItems)
    -- 遍历所有进行中的任务
    for questType, tasks in pairs(player.dict_game_task) do
        for questId, questData in pairs(tasks.progress) do
            -- 获取任务实例
            local taskInstance = nil
            if self.tasks[questType] and self.tasks[questType][questId] and 
               self.tasks[questType][questId].instances[player.uin] then
                taskInstance = self.tasks[questType][questId].instances[player.uin]
                
                -- 遍历目标，找到击杀类目标进行更新
                for i, objective in ipairs(taskInstance.objectives) do
                    if objective.type == "kill" then
                        objective:OnMonsterKilled(player, monsterId, dropItems)
                    end
                end
                
                -- 检查任务是否完成
                self:CheckQuestCompletion(player, questType, questId)
            else
                -- 向后兼容：手动检查目标
                local questConfig = self:GetQuestConfig(questId)
                if questConfig and questConfig.objectives then
                    for i, objective in ipairs(questConfig.objectives) do
                        if objective.type == "kill" and 
                           (objective.target_id == monsterId or objective.target_id == 0) then
                            -- 更新进度
                            local current = questData.objectives[i].current or 0
                            local required = objective.count or 1
                            
                            if current < required then
                                questData.objectives[i].current = current + 1
                                
                                -- 通知客户端
                                if questData.objectives[i].current >= required then
                                    gg.network_channel:fireClient(player.uin, {
                                        cmd = "cmd_client_show_msg",
                                        txt = "目标已完成: 击杀 " .. (objective.target_name or "怪物"),
                                        color = ColorQuad.new(0, 255, 0, 255)
                                    })
                                end
                            end
                            
                            -- 同步任务数据
                            player:syncGameTaskData()
                            
                            -- 检查任务是否完成
                            self:CheckQuestCompletion(player, questType, questId)
                        end
                    end
                end
            end
        end
    end
end

-- 处理物品收集事件
function TaskSystem:HandleItemCollected(player, itemType, itemId, count, source)
    -- 遍历所有进行中的任务
    for questType, tasks in pairs(player.dict_game_task) do
        for questId, questData in pairs(tasks.progress) do
            -- 获取任务实例
            local taskInstance = nil
            if self.tasks[questType] and self.tasks[questType][questId] and 
               self.tasks[questType][questId].instances[player.uin] then
                taskInstance = self.tasks[questType][questId].instances[player.uin]
                
                -- 遍历目标，找到收集类目标进行更新
                for i, objective in ipairs(taskInstance.objectives) do
                    if objective.type == "collect" then
                        objective:OnItemCollected(player, itemType, itemId, count, source)
                    end
                end
                
                -- 检查任务是否完成
                self:CheckQuestCompletion(player, questType, questId)
            else
                -- 向后兼容：手动检查目标
                -- 实现类似上面怪物击杀的逻辑...
            end
        end
    end
end

-- 处理NPC对话事件
function TaskSystem:HandleNpcTalk(player, npcId, dialogueId)
    -- 遍历所有进行中的任务
    for questType, tasks in pairs(player.dict_game_task) do
        for questId, questData in pairs(tasks.progress) do
            -- 获取任务实例
            local taskInstance = nil
            if self.tasks[questType] and self.tasks[questType][questId] and 
               self.tasks[questType][questId].instances[player.uin] then
                taskInstance = self.tasks[questType][questId].instances[player.uin]
                
                -- 遍历目标，找到对话类目标进行更新
                for i, objective in ipairs(taskInstance.objectives) do
                    if objective.type == "talk" then
                        objective:OnDialogueStarted(player, npcId, dialogueId)
                    end
                end
                
                -- 检查任务是否完成
                self:CheckQuestCompletion(player, questType, questId)
            else
                -- 向后兼容：手动检查目标
                -- 实现类似上面怪物击杀的逻辑...
            end
        end
    end
end

--------------------------------------------------
-- 复杂任务管理
--------------------------------------------------

-- 设置任务对话进度
function TaskSystem:SetQuestDialogueProgress(player, questType, questId, progress)
    -- 先尝试从任务实例处理
    if self.tasks[questType] and self.tasks[questType][questId] and 
       self.tasks[questType][questId].instances[player.uin] then
        local taskInstance = self.tasks[questType][questId].instances[player.uin]
        if taskInstance.SetDialogueProgress then
            return taskInstance:SetDialogueProgress(player, progress)
        end
    end
    
    -- 向后兼容：直接修改玩家数据
    local questData = player:GetQuestData(questType, questId)
    if not questData or questData.status ~= "进行中" then
        return false
    end
    
    questData.data.dialogue_progress = progress
    
    -- 检查是否需要更新对话类目标
    local questConfig = self:GetQuestConfig(questId)
    if questConfig and questConfig.objectives then
        for i, objective in ipairs(questConfig.objectives) do
            if objective.type == "talk" and questConfig.dialogue and
               progress >= #questConfig.dialogue.sequence then
                -- 完成对话目标
                if questData.data.objectives[i] then
                    questData.data.objectives[i].current = objective.count or 1
                    questData.data.objectives[i].completed = true
                end
            end
        end
    end
    
    -- 同步到客户端
    player:syncGameTaskData()
    
    -- 检查任务是否完成
    self:CheckQuestCompletion(player, questType, questId)
    
    return true
end

-- 解锁任务步骤
function TaskSystem:UnlockQuestStep(player, questType, questId, stepIndex)
    -- 先尝试从任务实例处理
    if self.tasks[questType] and self.tasks[questType][questId] and 
       self.tasks[questType][questId].instances[player.uin] then
        local taskInstance = self.tasks[questType][questId].instances[player.uin]
        -- 如果实例有专门的方法，则调用
    end
    
    -- 向后兼容：直接修改玩家数据
    local questData = player:GetQuestData(questType, questId)
    if not questData or questData.status ~= "进行中" then
        return false
    end
    
    if not questData.data.unlocked_steps then
        questData.data.unlocked_steps = {}
    end
    
    questData.data.unlocked_steps[stepIndex] = true
    
    -- 同步到客户端
    player:syncGameTaskData()
    
    return true
end

-- 解锁任务对话分支
function TaskSystem:UnlockQuestDialogueBranch(player, questType, questId, branchId)
    -- 先尝试从任务实例处理
    if self.tasks[questType] and self.tasks[questType][questId] and 
       self.tasks[questType][questId].instances[player.uin] then
        local taskInstance = self.tasks[questType][questId].instances[player.uin]
        -- 如果实例有专门的方法，则调用
    end
    
    -- 向后兼容：直接修改玩家数据
    local questData = player:GetQuestData(questType, questId)
    if not questData or questData.status ~= "进行中" then
        return false
    end
    
    if not questData.data.unlocked_branches then
        questData.data.unlocked_branches = {}
    end
    
    questData.data.unlocked_branches[branchId] = true
    
    -- 同步到客户端
    player:syncGameTaskData()
    
    return true
end

return TaskSystem