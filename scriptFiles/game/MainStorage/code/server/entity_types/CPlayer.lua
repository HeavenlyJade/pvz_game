--- V109 miniw-haima
--- 玩家类  (单个玩家) (管理玩家状态)

local print        = print
local setmetatable = setmetatable
local game         = game
local pairs        = pairs
local table        = table
local os           = os
local math         = math


local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const
local CommonModule  = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem) ---@type TaskSystem
local CLiving      = require(MainStorage.code.server.entity_types.CLiving) ---@type CLiving
-- local skillMgr     = require(MainStorage.code.server.skill.MSkillMgr) ---@type SkillMgr
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr) ---@type MCloudDataMgr
local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)  ---@type CommandManager
local ServerEventManager      = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local TagTypeConfig = require(MainStorage.code.common.config.TagTypeConfig) ---@type TagTypeConfig
---@class CPlayer : CLiving    --玩家类  (单个玩家) (管理玩家状态)
---@field dict_btn_skill table 技能按钮映射
---@field dict_game_task table 任务数据
---@field daily_tasks table 每日任务数据
---@field buff_instance table Buff实例
---@field player_net_stat PLAYER_NET_STAT 玩家网络状态
---@field auto_attack number 自动攻击技能ID
---@field auto_attack_tick number 攻击间隔
---@field auto_wait_tick number 攻击等待计时
---@field New fun( info_:table ):   CPlayer
local _M = CommonModule.Class('CPlayer', CLiving)

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

-- 初始化玩家
function _M:OnInit(info_)
    CLiving:OnInit(info_)                                       -- 父类初始化
    self.name = info_.nickname
    self.bag = nil ---@type Bag
    self.uuid             = gg.create_uuid('p')                 -- 唯一ID
    self.auto_attack      = 0                                   -- 自动攻击技能ID
    self.auto_attack_tick = 10                                  -- 攻击间隔
    self.auto_wait_tick   = 0                                   -- 等待计时
    self.daily_tasks      = {}                                  -- 每日任务
    self.dict_btn_skill   = {}                                  -- 技能按钮映射
    self.buff_instance    = {}                                  -- Buff实例
    self.dict_game_task   = {}                                  -- 任务数据
    self.player_net_stat  = common_const.PLAYER_NET_STAT.INITING -- 网络状态
    
    -- 初始化玩家配置
    self.player_config = common_config.dict_player_config[info_.id]
    if self.player_config then
        self.player_config.level = info_.level
        CLiving.initBattleData(self, self.player_config)  -- 初始化战斗数据
    else
        gg.log("警告: 玩家配置未找到，ID:", info_.id)
    end
end

-- 获取玩家位置
function _M:getPosition()
    return self.actor and self.actor.Position or Vector3.new(0, 0, 0)
end

-- 设置玩家网络状态
function _M:setPlayerNetStat(player_net_stat_)
    gg.log('设置玩家网络状态:', self.info.uin, player_net_stat_)
    self.player_net_stat = player_net_stat_
end

function _M:ExecuteCommands(commands, castParam)
    for _, command in ipairs(commands) do
        self:ExecuteCommand(command, castParam)
    end
end

---@override
function _M:Die()
    -- 发布死亡事件
    ServerEventManager.Publish("PlayerDeadEvent", { player = self })
    CLiving.Die(self)
end

function _M:ExecuteCommand(command, castParam)
    command = command:gsub("%%p", tostring(self.uin))
    CommandManager:ExecuteCommand(command, self)
end

--------------------------------------------------
-- Buff 系统方法
--------------------------------------------------

-- 创建Buff实例
function _M:buffer_create(buffId, duration, params)
    -- 在这里实现Buff创建逻辑
end

-- 销毁玩家的所有Buff
function _M:buffer_destory()
    if not self.buff_instance then return end
    
    for key, buff in pairs(self.buff_instance) do
        if buff.DestroyBuff then
            buff:DestroyBuff()
        end
    end
    self.buff_instance = {}
end

function _M:RefreshStats()
    -- 先重置装备属性
    self:ResetStats("EQUIP")
    self:RemoveTagHandler("EQUIP-")
    
    -- 直接遍历bag_items，跳过c =0
    for category, items in pairs(self.bag.bag_items) do
        if category > 0 then
            for slot, item in pairs(items) do
                if item and item.itemType then
                    -- 遍历装备的所有属性
                    for statName, amount in pairs(item:GetStat()) do
                        self:AddStat(statName, amount, {source = "EQUIP", refresh = false})
                    end
                    for _, tag in ipairs(item.itemType.boundTags) do
                        self:AddTagHandler(TagTypeConfig.Get(tag):FactoryEquipingTag("EQUIP-", 1.0))
                    end
                end
            end
        end
    end
    
    -- -- 刷新生命值和魔法值上限
    -- local maxHealth = self:GetStat("Health")
    -- local maxMana = self:GetStat("Mana")
    -- self:SetMaxHealth(maxHealth)
    -- self.maxMana = maxMana
    
    -- -- 同步到客户端
    -- self:rsyncData(1)
end

--------------------------------------------------
-- 技能系统方法
--------------------------------------------------

-- 初始化技能数据
function _M:initSkillData()
    -- 从云数据读取
    local ret1_, cloud_data_ = cloudDataMgr.ReadSkillData(self.uin)
    if ret1_ == 0 and cloud_data_ and cloud_data_.skill then
        self.dict_btn_skill = cloud_data_.skill
    else
        -- 使用默认技能配置
        self.dict_btn_skill = {
            [1] = 1001,
            [2] = 0,
        }
        
        -- 从玩家配置加载技能
        local player_config = common_config.dict_player_config[1]
        if player_config and player_config.skills then
            for i = 1, #player_config.skills do
                self.dict_btn_skill[i] = player_config.skills[i]
            end
        end
    end
    
    -- 同步到客户端
    self:syncSkillData()
end

-- 保存技能配置
function _M:saveSkillConfig()
    cloudDataMgr.SaveSkillData(self.uin)
    self:syncSkillData()
end

-- 同步技能数据到客户端
function _M:syncSkillData()
    if not self.dict_btn_skill then return end
    
    gg.network_channel:fireClient(self.uin, { 
        cmd = 'cmd_sync_player_skill', 
        uin = self.uin, 
        skill = self.dict_btn_skill 
    })
end

--------------------------------------------------
-- 任务系统方法
--------------------------------------------------

-- 初始化任务数据
function _M:initGameTaskData()
    -- 从云数据读取
    local ret1_, cloud_data_ = cloudDataMgr.ReadGameTaskData(self.uin)
    if ret1_ == 0 and cloud_data_ and cloud_data_.dict_game_task then
        self.dict_game_task = cloud_data_.dict_game_task
    else
        -- 创建默认任务结构
        self.dict_game_task = {
            main_line = {pending_pickup = {}, progress = {}, finish = {}},
            branch_line = {pending_pickup = {}, progress = {}, finish = {}},
            gaiden = {pending_pickup = {}, progress = {}, finish = {}},
            daily_task = {pending_pickup = {}, progress = {}, finish = {}}
        }

        TaskSystem:InitDefaultTasks(self)
    end
    
    -- 同步到客户端
    self:syncGameTaskData()
end

-- 初始化任务目标
function _M:initObjectivesFromConfig(questConfig)
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

-- 初始化默认任务
function _M:initDefaultTasks()
    if not common_config.main_line_task_config then return end
    
    for chapter_key, chapter_data in pairs(common_config.main_line_task_config) do
        if chapter_data.quests then
            for _, quest in ipairs(chapter_data.quests) do
                if quest.unlock_condition == nil then
                    -- 初始化任务目标
                    local objectives_data = self:initObjectivesFromConfig(quest)
                    -- 添加到进度中
                    self.dict_game_task.main_line.progress[quest.id] = {
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

-- 同步任务数据到客户端
function _M:syncGameTaskData()
    if not self.dict_game_task then return end
        gg.network_channel:fireClient(self.uin, { 
        cmd = 'cmd_sync_player_game_task', 
        uin = self.uin, 
        task_data = self.dict_game_task 
    })
end

-- 处理任务完成
function _M:handleCompleteTask(taskId)
    -- 检查任务状态
    if not self.dict_game_task.main_line.pending_pickup[taskId] then
        return false
    end
    
    -- 修改任务状态
    self.dict_game_task.main_line.pending_pickup[taskId] = nil
    self.dict_game_task.main_line.finish[taskId] = true
    
  
    TaskSystem:GiveTaskReward(self, taskId)
    
    -- 同步数据
    self:syncGameTaskData()
    
    -- 发送成功消息
    gg.network_channel:fireClient(self.uin, {
        cmd = "cmd_client_show_msg",
        msg = "任务完成，奖励已发放！"
    })
    
    return true
end

-- 获取任务状态
function _M:GetQuestStatus(questType, questId)
    local questData = self:GetQuestData(questType, questId)
    return questData and questData.status or "未接取"
end

-- 设置任务状态
function _M:SetQuestStatus(questType, questId, field, value)
    if not self.dict_game_task[questType] then
        self.dict_game_task[questType] = {
            pending_pickup = {},
            progress = {},
            finish = {}
        }
    end
    
    -- 移除旧状态
    local oldStatus = self:GetQuestStatus(questType, questId)
    if oldStatus == "进行中" then
        self.dict_game_task[questType].progress[questId] = nil
    elseif oldStatus == "待领取" then
        self.dict_game_task[questType].pending_pickup[questId] = nil
    elseif oldStatus == "已完成" then
        self.dict_game_task[questType].finish[questId] = nil
    end
    
    -- 设置新状态
    if value == "进行中" then
        self.dict_game_task[questType].progress[questId] = {
            start_time = os.time(),
            objectives = {}
        }
    elseif value == "待领取" then
        self.dict_game_task[questType].pending_pickup[questId] = true
    elseif value == "已完成" then
        self.dict_game_task[questType].finish[questId] = true
    end
    
    -- 同步到客户端
    self:syncGameTaskData()
    
    -- 保存到云端
    cloudDataMgr.saveGameTaskData(self.uin)
end

-- 获取任务数据
function _M:GetQuestData(questType, questId)
    if not self.dict_game_task[questType] then return nil end
    
    if self.dict_game_task[questType].progress[questId] then
        return {
            status = "进行中",
            data = self.dict_game_task[questType].progress[questId]
        }
    elseif self.dict_game_task[questType].pending_pickup[questId] then
        return { status = "待领取" }
    elseif self.dict_game_task[questType].finish[questId] then
        return { status = "已完成" }
    end
    
    return nil
end

-- 获取任务目标进度
function _M:GetQuestObjectiveProgress(questType, questId, targetIndex)
    local questData = self:GetQuestData(questType, questId)
    if not questData or questData.status ~= "进行中" or not questData.data.objectives then
        return 0
    end
    
    return questData.data.objectives[targetIndex] or 0
end

-- 获取任务目标最大进度
function _M:GetQuestObjectiveMaxProgress(questType, questId, targetIndex)
    return TaskSystem:GetQuestObjectiveMaxProgress(self, questType, questId, targetIndex)
end

-- 更新任务目标进度
function _M:UpdateQuestObjectiveProgress(questType, questId, targetIndex, newProgress)
    local questData = self:GetQuestData(questType, questId)
    if not questData or questData.status ~= "进行中" then
        return false
    end
    
    if not questData.data.objectives then
        questData.data.objectives = {}
    end
    
    questData.data.objectives[targetIndex] = newProgress
    
    -- 同步到客户端
    self:syncGameTaskData()
    
    -- 保存到云端
    cloudDataMgr.saveGameTaskData(self.uin)
    
    return true
end

-- 检查所有任务目标是否完成
function _M:AreAllQuestObjectivesComplete(questType, questId)
    return TaskSystem:AreAllQuestObjectivesComplete(self, questType, questId)
end

-- 获取任务配置
function _M:GetQuestConfig(questId)
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
    
    return nil
end

-- 设置任务对话进度
function _M:SetQuestDialogueProgress(questType, questId, progress)
    return TaskSystem:SetQuestDialogueProgress(self, questType, questId, progress)
end

-- 检查并更新任务完成状态
function _M:CheckQuestCompletion(questType, questId)
    return TaskSystem:CheckQuestCompletion(self, questType, questId)
end

-- 设置任务追踪
function _M:SetQuestTracking(questType, questId, isTracking)
    local questData = self:GetQuestData(questType, questId)
    if not questData then return false end
    
    if questData.status == "进行中" then
        if not questData.data.tracking then
            questData.data.tracking = {}
        end
        questData.data.tracking.active = isTracking and true or false
        
        -- 同步到客户端
        self:syncGameTaskData()
        return true
    end
    
    return false
end

-- 解锁任务步骤
function _M:UnlockQuestStep(questType, questId, stepIndex)
    return TaskSystem:UnlockQuestStep(self, questType, questId, stepIndex)
end

-- 解锁任务对话分支
function _M:UnlockQuestDialogueBranch(questType, questId, branchId)
    return TaskSystem:UnlockQuestDialogueBranch(self, questType, questId, branchId)
end

--------------------------------------------------
-- 玩家同步与更新方法
--------------------------------------------------

-- 同步玩家数据到客户端
-- op: 1=初始化同步所有数据   2=只同步exp
function _M:rsyncData(op_)
    local ret_ = {
        level     = self.level,
        exp       = self.exp,
        user_name = self.info.nickname,
        uin       = self.info.uin,
    }
    
    if op_ == 1 then
        ret_.battle_data = self.battle_data
    end
    
    gg.network_channel:fireClient(self.uin, { 
        cmd = "cmd_rsync_player_data", 
        v = ret_ 
    })
end

-- 设置自动攻击
function _M:setAutoAttack(id_, speed_time_)
    if self.auto_attack ~= id_ then
        self.auto_attack = id_
        if id_ > 0 then
            self.auto_attack_tick = speed_time_ * 10
        end
    end
end

-- 玩家离开游戏
function _M:Save()
    cloudDataMgr.SavePlayerData(self.uin, true)
    if self.bag.dirtySave then
        self.bag:Save()
    end
end

-- 自动回血蓝
function _M:checkHPMP()
    -- 只在玩家存活时处理
    if self.battle_data.hp <= 0 then
        return
    end
    
    local change_ = 0
    
    -- 回血
    if self.battle_data.hp < self.battle_data.hp_max then
        self.battle_data.hp = self.battle_data.hp + 1
        change_ = 1
    end
    
    -- 回蓝
    if self.battle_data.mp < self.battle_data.mp_max then
        self.battle_data.mp = self.battle_data.mp + 2
        change_ = 1
    end
    
    -- 发送更新通知
    if change_ == 1 and (self.tick % 2 == 1) then
        gg.network_channel:fireClient(self.uin, {
            cmd = 'cmd_player_hpmp',
            hp = self.battle_data.hp,
            hp_max = self.battle_data.hp_max,
            mp = self.battle_data.mp,
            mp_max = self.battle_data.mp_max
        })
    end
end

-- 更新玩家状态
function _M:update_player()
    -- 调用父类更新
    self:update()
    
    -- 更新Buff
    self:updateBuffs()
    
    -- 处理自动攻击
    self:processAutoAttack()
end

-- 更新Buff状态
function _M:updateBuffs()
    if not self.buff_instance then return end
    
    local current_time = os.time()
    local keys_to_remove = {}
    
    -- 检查所有Buff
    for key, buff_instance in pairs(self.buff_instance) do
        local buff_create_time = buff_instance.create_time or 0
        local duration_time = buff_instance.duration_time or 60
        
        -- 检查Buff是否过期
        if current_time > buff_create_time + duration_time then
            table.insert(keys_to_remove, key)
            
            -- 调用销毁方法
            if buff_instance.DestroyBuff then
                buff_instance:DestroyBuff()
            end
        end
    end
    
    -- 移除过期Buff
    for _, key in ipairs(keys_to_remove) do
        self.buff_instance[key] = nil
    end
end

function _M:SendChatText( text, ... )
    if ... then
        text = string.format(text, ...)
    end
    self:SendHoverText(text)
end

function _M:SendHoverText( text, ... )
    if ... then
        text = string.format(text, ...)
    end
    gg.network_channel:fireClient(self.uin, { cmd="cmd_client_show_msg", txt=text })
end

-- 处理自动攻击
-- function _M:processAutoAttack()
--     if self.auto_attack <= 0 then return end
    
--     -- 减少等待时间
--     self.auto_wait_tick = self.auto_wait_tick - 1
    
--     -- 检查是否可以攻击
--     if self.auto_wait_tick <= 0 and not self.stat_flags.skill_uuid then
--         -- 尝试自动攻击
--         skillMgr.tryAutoAttack(self, self.auto_attack)
        
--         -- 重设等待时间
--         self.auto_wait_tick = self.auto_attack_tick
--     end
-- end

return _M
