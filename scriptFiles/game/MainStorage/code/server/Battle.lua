local MainStorage = game:GetService('MainStorage')
local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule
local ServerEventManager      = require(MainStorage.code.server.event.ServerEventManager)

---@class Battle:Class
---@field New fun( attacker:CLiving, victim:CLiving, source:string, castParam:CastParam|nil ):Battle
local Battle = CommonModule.Class("Battle")

-- 静态属性
Battle.ATTACKER_BATTLE_STATS = {
    ["攻击"] = function(battle, amount)
        if battle.source == "普攻" then
            battle:AddModifier("ATTACK", "增加", amount)
        end
    end,
    ["暴率"] = function(battle, amount)
        battle.critChance = battle.critChance + amount / 100.0
    end,
    ["暴伤"] = function(battle, amount)
        battle.critDamage = battle.critDamage + amount
    end
}
Battle.VICTIM_BATTLE_STATS = {
    ["防御"] = function(battle, amount)
        -- local attack = battle.GetDamageModifier("攻击")
        battle.AddDModifier("ARMOR", "增加", -amount)
    end
}

-- 初始化方法
function Battle:OnInit(attacker, victim, source, castParam)
    self.attacker = attacker
    self.victim = victim
    self.source = source
    self.castParam = castParam
    self.baseModifiers = {}
    self.multiplyModifiers = {}
    self.finalMultiplyModifiers = {}
    self.critChance = 0
    self.critDamage = 0
    self.isCrit = false
    self.elementType = "无"
    self.skipTags = {}
end

-- 获取修饰器列表
function Battle:GetBaseModifiers()
    return self.baseModifiers
end

function Battle:GetMultiplyModifiers()
    return self.multiplyModifiers
end

function Battle:GetFinalMultiplyModifiers()
    return self.finalMultiplyModifiers
end

-- 添加伤害修饰器
function Battle:AddDamageModifier(modifier)
    local targetList
    if modifier.modifierType == "增加" then
        targetList = self.baseModifiers
    elseif modifier.modifierType == "倍率" then
        targetList = self.multiplyModifiers
    else
        targetList = self.finalMultiplyModifiers
    end
    table.insert(targetList, modifier)
end

function Battle:AddModifier(source, modifierType, amount)
    self:AddDamageModifier({
        source = source,
        modifierType = modifierType,
        amount = amount
    })
end

-- 计算战斗
function Battle:CalculateBattle()
    ServerEventManager.Publish("PreBattleEvent", { battle = self })
    
    for statName, statCb in pairs(Battle.ATTACKER_BATTLE_STATS) do
        local amount = self.attacker:GetStat(statName)
        if amount ~= 0 then
            statCb(self, amount)
        end
    end
    for statName, statCb in pairs(Battle.VICTIM_BATTLE_STATS) do
        local amount = self.victim:GetStat(statName)
        if amount ~= 0 then
            statCb(self, amount)
        end
    end
    
    self.attacker:TriggerTags("攻击时", self.victim, self.castParam, self)
    self.victim:TriggerTags("被攻击时", self.attacker, self.castParam, self)
    
    if math.random() < self.critChance then
        self.isCrit = true
        self:AddModifier("CRIT", "最终倍率", self.critDamage)
    end
    
    self.attacker:TriggerTags("攻击时（判断暴击后）", self.victim, self.castParam, self)
    self.victim:TriggerTags("被攻击时（判断暴击后）", self.attacker, self.castParam, self)
    
    ServerEventManager.Publish("PostBattleEvent", { battle = self })
end

-- 获取特定修饰器
function Battle:GetDamageModifier(statName, modifierType)
    local targetList
    if modifierType == "增加" then
        targetList = self.baseModifiers
    elseif modifierType == "倍率" then
        targetList = self.multiplyModifiers
    else
        targetList = self.finalMultiplyModifiers
    end
    
    for _, item in ipairs(targetList) do
        if item.source == statName then
            return item
        end
    end
    return nil
end

-- 计算最终伤害
function Battle:GetFinalDamage(baseValue)
    baseValue = baseValue or 0
    local damage = baseValue
    
    -- 处理基础加成
    for _, item in ipairs(self.baseModifiers) do
        damage = damage + item.amount
    end
    
    -- 处理倍率加成
    local multiplier = 1.0
    for _, item in ipairs(self.multiplyModifiers) do
        multiplier = multiplier + item.amount / 100.0
    end
    
    -- 处理最终倍率加成
    local finalMultiplier = 1.0
    for _, item in ipairs(self.finalMultiplyModifiers) do
        finalMultiplier = finalMultiplier * (1 + item.amount / 100.0)
    end
    
    return damage * multiplier * finalMultiplier
end



return Battle