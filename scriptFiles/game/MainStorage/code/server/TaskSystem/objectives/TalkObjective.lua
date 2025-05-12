--- 对话目标实现类
--- V109 miniw-haima

local game = game
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local ClassMgr = require(MainStorage.code.common.ClassMgr)  ---@type ClassMgr
local BaseObjective = require(MainStorage.code.server.TaskSystem.objectives.BaseObjective)  ---@type BaseObjective

---@class TalkObjective:BaseObjective
local TalkObjective = ClassMgr.Class('TalkObjective', BaseObjective)

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化目标
function TalkObjective:OnInit(objectiveData)
    -- 调用基类初始化
    BaseObjective.OnInit(self, objectiveData)
    
    -- 对话目标特有属性
    self.npc_id = objectiveData.npc_id or objectiveData.target_id      -- NPC ID
    self.dialogue_id = objectiveData.dialogue_id                        -- 对话ID
    self.specific_topic = objectiveData.specific_topic                  -- 特定对话主题
    self.required_choice = objectiveData.required_choice                -- 需要选择的选项
    self.required_dialogue_progress = objectiveData.required_progress   -- 需要达到的对话进度
    
    -- 对话相关状态
    self.dialogue_started = false            -- 对话是否已开始
    self.dialogue_progress = 0               -- 当前对话进度
    self.choice_made = nil                   -- 玩家做出的选择
end

--------------------------------------------------
-- 对话目标特有方法
--------------------------------------------------

-- 处理对话开始事件
function TalkObjective:OnDialogueStarted(player, npcId, dialogueId)
    -- 如果目标已完成，则不再处理
    if self.completed then
        return false
    end
    
    -- 检查NPC ID是否匹配
    if self.npc_id ~= npcId and self.npc_id ~= 0 then  -- npc_id为0表示任意NPC
        return false
    end
    
    -- 检查对话ID是否匹配（如果有要求）
    if self.dialogue_id and self.dialogue_id ~= dialogueId then
        return false
    end
    
    -- 标记对话已开始
    self.dialogue_started = true
    
    -- 如果没有其他要求，则完成目标
    if not self.specific_topic and not self.required_choice and not self.required_dialogue_progress then
        return self:Update(player, 1)
    end
    
    return true
end

-- 处理对话进度更新事件
function TalkObjective:OnDialogueProgressUpdated(player, npcId, dialogueId, progress)
    -- 如果目标已完成或对话未开始，则不处理
    if self.completed or not self.dialogue_started then
        return false
    end
    
    -- 更新对话进度
    self.dialogue_progress = progress
    
    -- 检查是否达到所需对话进度
    if self.required_dialogue_progress and progress >= self.required_dialogue_progress then
        -- 如果没有其他要求或所有要求都已满足，则完成目标
        if not self.specific_topic or not self.required_choice or self.choice_made then
            return self:Update(player, 1)
        end
    end
    
    return true
end

-- 处理对话主题事件
function TalkObjective:OnDialogueTopic(player, npcId, dialogueId, topic)
    -- 如果目标已完成或对话未开始，则不处理
    if self.completed or not self.dialogue_started then
        return false
    end
    
    -- 检查主题是否匹配
    if self.specific_topic and topic == self.specific_topic then
        -- 如果没有其他要求或所有要求都已满足，则完成目标
        if not self.required_choice or self.choice_made then
            if not self.required_dialogue_progress or self.dialogue_progress >= self.required_dialogue_progress then
                return self:Update(player, 1)
            end
        end
    end
    
    return true
end

-- 处理对话选择事件
function TalkObjective:OnDialogueChoice(player, npcId, dialogueId, choice)
    -- 如果目标已完成或对话未开始，则不处理
    if self.completed or not self.dialogue_started then
        return false
    end
    
    -- 记录玩家选择
    self.choice_made = choice
    
    -- 检查选择是否匹配
    if self.required_choice and choice == self.required_choice then
        -- 如果没有其他要求或所有要求都已满足，则完成目标
        if not self.specific_topic or (self.specific_topic and self.dialogue_topic_matched) then
            if not self.required_dialogue_progress or self.dialogue_progress >= self.required_dialogue_progress then
                return self:Update(player, 1)
            end
        end
    end
    
    return true
end

-- 处理对话结束事件
function TalkObjective:OnDialogueEnded(player, npcId, dialogueId, completed)
    -- 如果目标已完成，则不处理
    if self.completed then
        return false
    end
    
    -- 对话结束且完成（没有特殊要求时）
    if completed and self.dialogue_started and not self.specific_topic and not self.required_choice and not self.required_dialogue_progress then
        return self:Update(player, 1)
    end
    
    -- 重置对话状态
    self.dialogue_started = false
    
    return true
end

--------------------------------------------------
-- 重写基类方法
--------------------------------------------------

-- 重写重置方法
function TalkObjective:Reset()
    BaseObjective.Reset(self)
    self.dialogue_started = false
    self.dialogue_progress = 0
    self.choice_made = nil
end

-- 重写获取描述方法
function TalkObjective:GetDescription()
    local targetName = self.target_name or "NPC"
    local optionalText = self.optional and "[可选] " or ""
    
    if self.specific_topic then
        return optionalText .. "与 " .. targetName .. " 讨论关于 '" .. self.specific_topic .. "' 的话题"
    else
        return optionalText .. "与 " .. targetName .. " 对话"
    end
end

return TalkObjective