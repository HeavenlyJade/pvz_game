local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig

---@class AcceptedQuest:Class
local AcceptedQuest = ClassMgr.Class("AcceptedQuest")

---@param quest Quest
---@param player Player
function AcceptedQuest:OnInit(quest, player)
    self.quest = quest ---@type Quest
    self.player = player ---@type Player
    self.progress = 0
    -- 注册进度关键字，支持多个任务
    local function addKey(key)
        if not player.questKey[key] then
            player.questKey[key] = {}
        end
        table.insert(player.questKey[key], self)
    end
    if quest.questType == "变量" and quest.questVariable then
        addKey(quest.questVariable)
    elseif quest.questType == "物品" and quest.requiredItem then
        addKey(quest.requiredItem.name or quest.requiredItem)
    elseif quest.questType == "事件" and quest.eventName then
        addKey(quest.eventName)
    else
        addKey(quest.name)
    end
end

---@return boolean
function AcceptedQuest:IsCompleted()
    return self:GetProgress() >= self.quest.completionCount
end

function AcceptedQuest:GetToStringParams()
    return {
        name = self.quest.name,
        count = self:GetProgress()
    }
end

---@param amount number
function AcceptedQuest:AddProgress(amount)
    if self:IsCompleted() or not amount or amount <= 0 then
        return
    end
    self.progress = math.min(self.progress + amount, self.quest.completionCount)
    self.player:UpdateQuestsData()

    -- 检查是否达到完成条件且设置了自动提交
    if self:IsCompleted() then
        if self.quest.finishCommands then
            self.player:ExecuteCommands(self.quest.finishCommands)
        end
        if self.quest.autoTurnIn then
            self:Finish()
        end
    end
end

---@param amount number
function AcceptedQuest:SetProgress(amount)
    if self:IsCompleted() then
        return
    end
    self.progress = math.min(amount, self.quest.completionCount)
    self.player:UpdateQuestsData()

    -- 检查是否达到完成条件且设置了自动提交
    if self:IsCompleted() then
        if self.quest.finishCommands then
            self.player:ExecuteCommands(self.quest.finishCommands)
        end
        if self.quest.autoTurnIn then
            self:Finish()
        end
    end
end

function AcceptedQuest:GetProgress()
    if self.quest.questType == "物品" then
        local progress = self.player.bag:GetItemAmount(self.quest.requiredItem)
        -- 检查是否达到完成条件且设置了自动提交
        if progress >= self.quest.completionCount and self.quest.autoTurnIn then
            self:Finish()
        end
        return progress
    elseif self.quest.questType == "变量" then
        local progress = self.player:GetVariable(self.quest.questVariable)
        -- 检查是否达到完成条件且设置了自动提交
        if progress >= self.quest.completionCount and self.quest.autoTurnIn then
            self:Finish()
        end
        return progress
    else
        return self.progress
    end
end

-- 注销任务关键字
function AcceptedQuest:UnregisterKey()
    local function removeKey(key)
        local list = self.player.questKey[key]
        if list then
            for i = #list, 1, -1 do
                if list[i] == self then
                    table.remove(list, i)
                end
            end
            if #list == 0 then
                self.player.questKey[key] = nil
            end
        end
    end
    if self.quest.questType == "变量" and self.quest.questVariable then
        removeKey(self.quest.questVariable)
    elseif self.quest.questType == "物品" and self.quest.requiredItem then
        removeKey(self.quest.requiredItem.id or self.quest.requiredItem)
    elseif self.quest.questType == "事件" and self.quest.eventName then
        removeKey(self.quest.eventName)
    else
        removeKey(self.quest.name)
    end
end

function AcceptedQuest:Finish()
    -- 检查是否已完成
    if not self:IsCompleted() then
        return false
    end

    -- 发放完成奖励
    if self.quest.completionRewards then
        for itemId, amount in pairs(self.quest.completionRewards) do
            local item = ItemTypeConfig.Get(itemId):ToItem(amount)
            self.player.bag:AddItem(item)
        end
    end

    if self.quest.completionCommands then
        self.player:ExecuteCommands(self.quest.completionCommands)
    end

    -- 发放邮件奖励
    if self.quest.mailRewards then
        local mailData = {
            title = self.quest.name .. "奖励",
            content = "恭喜完成" .. self.quest.name,
            attachments = self.quest.mailRewards,  -- 直接使用 {itemId = amount} 格式的奖励
            sender = "系统",
            sender_type = "system",
            sender_id = 0
        }
        local CloudMailData = require(MainStorage.code.server.Mail.CloudMailData)  ---@type CloudMailDataAccessor
        -- CloudMailData:AddPlayerMail(self.player.uin, mailData)
    end

    -- 自动领取下一任务
    if self.quest.nextQuest then
        local nextQuest = require(MainStorage.code.common.config.QuestConfig).Get(self.quest.nextQuest)
        if nextQuest then
            nextQuest:Accept(self.player)
        end
    end

    -- 从玩家任务列表中移除
    self.player.quests[self.quest.name] = nil
    self.player.acceptedQuestIds[self.quest.name] = 1 -- 标记为已完成

    -- 注销关键字
    self:UnregisterKey()

    -- 同步到客户端
    self.player:UpdateQuestsData()
    return true
end

---@return SerializedQuest
function AcceptedQuest:GetQuestDesc()
    local title = self.quest.shortDesc
    local progress = self:GetProgress()
    return {
        name = self.quest.name,
        description = title,
        count = progress,
        countMax = self.quest.completionCount
    }
end

return AcceptedQuest
