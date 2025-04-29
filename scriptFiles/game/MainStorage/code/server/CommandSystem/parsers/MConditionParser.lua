--- 条件解析器 - 负责解析和评估条件语句
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class ConditionParser
local ConditionParser = {}

-- 解析并评估条件表达式
function ConditionParser:EvaluateCondition(condition, player)
    -- 分割条件字符串
    local parts = {}
    for part in condition:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 解析条件类型
    if parts[1] == "拥有" and parts[2] == "物品" then
        return self:EvaluateItemCondition(parts, player)
    elseif parts[1] == "任务" then
        return self:EvaluateQuestCondition(parts, player)
    elseif parts[1] == "等级" then
        return self:EvaluateLevelCondition(parts, player)
    elseif parts[1] == "属性" then
        return self:EvaluateAttributeCondition(parts, player)
    else
        gg.log("未知条件类型: " .. parts[1])
        return false
    end
end

-- 评估物品条件: "拥有 物品 装备 1001 数量 >= 1"
function ConditionParser:EvaluateItemCondition(parts, player)
    local itemType = parts[3]  -- 装备, 消耗品等
    local itemId = tonumber(parts[4])
    -- 跳过"数量"
    local operator = parts[6]   -- >=, <=, ==, >等
    local required = tonumber(parts[7])
    
    -- 获取玩家物品数量
    local count = player:GetItemCount(itemType, itemId)
    
    -- 评估条件
    return self:CompareValues(count, operator, required)
end

-- 评估任务条件: "任务 主线 1001 目标 全部 已完成"
function ConditionParser:EvaluateQuestCondition(parts, player)
    local questType = parts[2]
    local questId = tonumber(parts[3])
    
    if parts[4] == "目标" then
        if parts[5] == "全部" and parts[6] == "已完成" then
            return player:AreAllQuestObjectivesComplete(questType, questId)
        elseif tonumber(parts[5]) then
            -- 检查特定目标的完成状态
            local targetIndex = tonumber(parts[5])
            local currentProgress = player:GetQuestObjectiveProgress(questType, questId, targetIndex)
            local maxProgress = player:GetQuestObjectiveMaxProgress(questType, questId, targetIndex)
            return currentProgress >= maxProgress
        end
    elseif parts[4] == "状态" then
        local status = player:GetQuestStatus(questType, questId)
        return status == parts[5]
    end
    
    return false
end

-- 评估等级条件: "等级 >= 10"
function ConditionParser:EvaluateLevelCondition(parts, player)
    local operator = parts[2]
    local required = tonumber(parts[3])
    
    return self:CompareValues(player.level, operator, required)
end

-- 评估属性条件: "属性 力量 >= 20"
function ConditionParser:EvaluateAttributeCondition(parts, player)
    local attrName = parts[2]  -- 力量, 智力等
    local operator = parts[3]
    local required = tonumber(parts[4])
    
    local attrValue = player.battle_data[attrName]
    if not attrValue then
        gg.log("未知属性: " .. attrName)
        return false
    end
    
    return self:CompareValues(attrValue, operator, required)
end

-- 通用比较函数
function ConditionParser:CompareValues(value, operator, required)
    if operator == ">=" then
        return value >= required
    elseif operator == "<=" then
        return value <= required
    elseif operator == "==" or operator == "=" then
        return value == required
    elseif operator == ">" then
        return value > required
    elseif operator == "<" then
        return value < required
    else
        gg.log("未知比较操作符: " .. operator)
        return false
    end
end

return ConditionParser