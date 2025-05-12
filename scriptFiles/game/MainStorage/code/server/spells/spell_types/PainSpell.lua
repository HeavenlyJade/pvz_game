local MainStorage = game:GetService('MainStorage')
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local CastParam = require(MainStorage.code.common.spell.CastParam) ---@type CastParam
local Battle            = require(MainStorage.code.server.Battle)    ---@type Battle


---@class PainSpell:Spell
---@field baseDamage number 基础伤害
---@field baseMultiplier number 基础倍率
---@field extraStats table<string, number> 额外属性
---@field elementType string 元素类型
---@field damageAmplifiers DamageAmplifier[] 基于释放者的属性增加伤害
---@field targetDamageAmplifiers DamageAmplifier[] 基于目标的属性增加伤害
local PainSpell = CommonModule.Class("PainSpell", Spell)

function PainSpell:OnInit(data)
    Spell.OnInit(self, data)
    self.baseDamage = data.baseDamage or 0
    self.baseMultiplier = data.baseMultiplier or 1
    self.extraStats = data.extraStats or {}
    self.elementType = data.elementType or "无"
    self.damageAmplifiers = data.damageAmplifiers or {}
    self.targetDamageAmplifiers = data.targetDamageAmplifiers or {}
end

--- 实际执行魔法
---@param caster CLiving 施法者
---@param target CLiving 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function PainSpell:CastReal(caster, target, param)
    if not target.isEntity then return false end
    
    local damage = param:GetValue(self, "baseDamage", self.baseDamage)
    local multiplier = param:GetValue(self, "baseMultiplier", self.baseMultiplier) * param.power
    
    -- 添加临时属性
    if next(self.extraStats) then
        for statName, statValue in pairs(self.extraStats) do
            caster:AddStat(statName, statValue, "TEMP")
        end
    end
    
    local battle = Battle.New(caster, target, self.spellName, nil)
    battle.skipTags = param.skipTags
    battle.elementType = self.elementType
    
    if damage > 0 then
        battle:AddModifier("BASE", "增加", damage * multiplier)
    end
    
    -- 处理释放者属性增伤
    if #self.damageAmplifiers > 0 then
        for _, amplifier in ipairs(self.damageAmplifiers) do
            local modifier = amplifier:GetModifier(caster, damage, multiplier, param)
            if modifier then
                battle:AddModifier(modifier)
            end
        end
    end
    
    
    -- 处理目标属性增伤
    if #self.targetDamageAmplifiers > 0 then
        for _, amplifier in ipairs(self.targetDamageAmplifiers) do
            local modifier = amplifier:GetModifier(target, damage, multiplier, param)
            if modifier then
                battle:AddModifier(modifier)
            end
        end
    end
    
    local attackBattle = caster:Attack(target, battle:GetFinalDamage(), self.spellName)
    
    -- 打印伤害信息
    if self.printInfo then
        local log = {}
        table.insert(log, string.format("=== %s 伤害构成 ===", self.spellName))
        
        table.insert(log, "基础伤害修饰器:")
        for _, modifier in ipairs(attackBattle:GetBaseModifiers()) do
            table.insert(log, string.format("  %s: %s (%s)", 
                modifier.source, 
                modifier.amount, 
                modifier.modifierType))
        end
        
        table.insert(log, "倍率修饰器:")
        for _, modifier in ipairs(attackBattle:GetMultiplyModifiers()) do
            table.insert(log, string.format("  %s: %s (%s)", 
                modifier.source, 
                modifier.amount, 
                modifier.modifierType))
        end
        
        table.insert(log, "最终倍率修饰器:")
        for _, modifier in ipairs(attackBattle:GetFinalMultiplyModifiers()) do
            table.insert(log, string.format("  %s: %s (%s)", 
                modifier.source, 
                modifier.amount, 
                modifier.modifierType))
        end
        
        table.insert(log, string.format("最终伤害: %s", attackBattle:GetFinalDamage()))
        table.insert(log, "=====================")
        
        print(table.concat(log, "\n"))
    end
    
    -- 重置临时属性
    if next(self.extraStats) then
        caster:ResetStats("TEMP")
    end
    
    self:PlayEffect(self.castEffects, target, caster, param)
    self:PlayEffect(self.targetEffects, caster, target, param)
    
    return true
end

return PainSpell
