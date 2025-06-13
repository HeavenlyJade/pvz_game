local MainStorage = game:GetService('MainStorage')
local ClassMgr      = require(MainStorage.code.common.ClassMgr)    ---@type ClassMgr
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg


---@class Condition:Class
local Condition = ClassMgr.Class("Condition")
function Condition:Check(modifier, caster, target)
    return true
end

---@class BetweenCondition:Condition
local BetweenCondition = ClassMgr.Class("BetweenCondition", Condition)
function BetweenCondition:OnInit(data)
    self.minValue = data["最小值"] or 0
    self.maxValue = data["最大值"] or 100
end
function BetweenCondition:CheckAmount(modifier, amount)
    return amount >= self.minValue and amount <= self.maxValue
end

---@class HealthCondition:BetweenCondition
local HealthCondition = ClassMgr.Class("HealthCondition", BetweenCondition)
function HealthCondition:OnInit(data)
    self.isPercentage = data["百分比"] == nil and true or data["百分比"]
end
function HealthCondition:Check(modifier, caster, target)
    if target == nil or not target.isEntity then return false end
    local amount
    if self.isPercentage then
        amount = 100 * target.health / target:GetStat("生命")
    else
        amount = target.health
    end
    return self:CheckAmount(modifier, amount)
end

---@class VariableCondition:BetweenCondition
local VariableCondition = ClassMgr.Class("VariableCondition", BetweenCondition)
function VariableCondition:OnInit(data)
    self.name = data["名字"]
end
function VariableCondition:Check(modifier, caster, target)
    if not target.isEntity then return false end
    local creature = target ---@cast creature Entity
    local amount = creature:GetVariable(self.name)
    return self:CheckAmount(modifier, amount)
end

---@class StatCondition:BetweenCondition
local StatCondition = ClassMgr.Class("StatCondition", BetweenCondition)
function StatCondition:OnInit(data)
    self.name = data["名字"]
end
function StatCondition:Check(modifier, caster, target)
    local amount = target:GetStat(self.name)
    return self:CheckAmount(modifier, amount)
end

---@class PositionCondition:BetweenCondition
local PositionCondition = ClassMgr.Class("PositionCondition", BetweenCondition)
function PositionCondition:Check(modifier, caster, target)
    error("InvalidImplementationException")
end

---@class ChanceCondition:Condition
local ChanceCondition = ClassMgr.Class("ChanceCondition", Condition)
function ChanceCondition:OnInit(data)
    self.minValue = data["最小值"] or 0
end
function ChanceCondition:Check(modifier, caster, target)
    if self.minValue >= 100 then return true end
    return math.random() < self.minValue / 100.0
end

---@class BuffActiveCondition:BetweenCondition
local BuffActiveCondition = ClassMgr.Class("BuffActiveCondition", BetweenCondition)
function BuffActiveCondition:OnInit(data)
    self.buffKeyword = data["Buff关键字"]
end
function BuffActiveCondition:Check(modifier, caster, target)
    if not target.isEntity then return false end
    local creature = target ---@cast creature Entity
    
    if self.buffKeyword == nil or self.buffKeyword == "" then
        local totalStacks = 0
        for _, buff in pairs(creature.activeBuffs) do
            totalStacks = totalStacks + buff.stack
        end
        return self:CheckAmount(modifier, totalStacks)
    end

    local stacks = 0
    for _, buff in pairs(creature.activeBuffs) do
        if string.find(buff.spell.spellName, self.buffKeyword) then
            stacks = stacks + buff.stack
        end
    end
    return self:CheckAmount(modifier, stacks)
end

---@class TagLevelCondition:BetweenCondition
local TagLevelCondition = ClassMgr.Class("TagLevelCondition", BetweenCondition)
function TagLevelCondition:OnInit(data)
    self.tagName = data["词条名"]
end
function TagLevelCondition:Check(modifier, caster, target)
    if target == nil or not target.isEntity then return false end
    local targetCreature = target ---@cast creature Entity
    print(string.format("TagLevelCondition %s %s %s", targetCreature.name, self.tagName, table.concat(targetCreature.tagIds, ",")))
    local tag = targetCreature:GetTag(self.tagName)
    if tag ~= nil then
        print(string.format("TagLevelCondition %s %d", self.tagName, tag.level))
        return self:CheckAmount(modifier, tag.level)
    end
    return false
end



---@class ShieldCondition:BetweenCondition
local ShieldCondition = ClassMgr.Class("ShieldCondition", BetweenCondition)
function ShieldCondition:OnInit(data)
    self.isPercentage = data["百分比"] == nil and true or data["百分比"]
end
function ShieldCondition:Check(modifier, caster, target)
    if target == nil or not target.isEntity then return false end
    local amount
    local creature = target ---@cast creature Entity
    if self.isPercentage then
        amount = 100 * creature.shield / target:GetStat("Health")
    else
        amount = creature.shield
    end
    return self:CheckAmount(modifier, amount)
end

---@class QuestConditionType
local QuestConditionType = {
    ACCEPTED = "已领取",
    FINISHED = "已完成或提交",
    IN_PROGRESS = "正在进行",
    COMPLETED = "已完成",
}

---@class QuestCondition:Condition
local QuestCondition = ClassMgr.Class("QuestCondition", Condition)
function QuestCondition:OnInit(data)
    self.quest = data["任务"]
    self.conditionType = data["条件"]
end

function QuestCondition:Check(modifier, caster, target)
    if not target.isPlayer then return false end
    local player = target ---@cast player Player
    
    -- 检查任务状态
    if self.conditionType == QuestConditionType.ACCEPTED then
        -- 检查是否已领取任务
        return player.quests[self.quest] ~= nil
    elseif self.conditionType == QuestConditionType.FINISHED then
        if player.acceptedQuestIds[self.quest] == 1 then
            return true
        end
        local q = player.quests[self.quest]
        if not q then
            return false
        end
        return q:IsCompleted()
    elseif self.conditionType == QuestConditionType.COMPLETED then
        -- 检查任务是否已完成
        return player.acceptedQuestIds[self.quest] == 1
    elseif self.conditionType == QuestConditionType.IN_PROGRESS then
        -- 检查任务是否正在进行中
        return player.quests[self.quest] ~= nil
    end
    
    return false
end

---@class WorldTimeCondition:BetweenCondition
local WorldTimeCondition = ClassMgr.Class("WorldTimeCondition", BetweenCondition)
function WorldTimeCondition:Check(modifier, caster, target)
    local Scene = require(MainStorage.code.server.Scene)         ---@type Scene
    return self:CheckAmount(modifier, Scene.worldTime)
end

return {
    Condition = Condition,
    BetweenCondition = BetweenCondition,
    HealthCondition = HealthCondition,
    VariableCondition = VariableCondition,
    StatCondition = StatCondition,
    PositionCondition = PositionCondition,
    ChanceCondition = ChanceCondition,
    BuffActiveCondition = BuffActiveCondition,
    TagLevelCondition = TagLevelCondition,
    ShieldCondition = ShieldCondition,
    QuestCondition = QuestCondition,
    WorldTimeCondition = WorldTimeCondition
}