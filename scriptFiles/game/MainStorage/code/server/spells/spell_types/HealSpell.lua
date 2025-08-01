local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
local Battle = require(MainStorage.code.server.Battle) ---@type Battle
local DamageAmplifier = require(MainStorage.code.common.config_type.modifier.DamageAmplifier) ---@type DamageAmplifier

---@class HealSpell:Spell
---@field baseHeal number 基础治疗
---@field baseMultiplier number 基础倍率
---@field damageAmplifier DamageAmplifier[] 基于释放者的属性增加伤害
---@field targetDamageAmplifier DamageAmplifier[] 基于目标的属性增加伤害
local HealSpell = ClassMgr.Class("HealSpell", Spell)

function HealSpell:OnInit(data)
    self.baseHeal = data["基础治疗"] or 0
    self.baseMultiplier = data["基础倍率"] or 1
    self.damageAmplifier = DamageAmplifier.Load(data["属性增伤"]) ---@type DamageAmplifier[]
    self.targetDamageAmplifier = DamageAmplifier.Load(data["目标属性增伤"]) ---@type DamageAmplifier[]
end

--- 实际执行魔法
---@param caster Entity 施法者
---@param target Entity 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function HealSpell:CastReal(caster, target, param)
    if not target.isEntity then return false end
    
    local battle = Battle.New(caster, target, self.spellName, nil)
    local damage = param:GetValue(self, "基础治疗", self.baseHeal)
    local multiplier = param:GetValue(self, "基础倍率", self.baseMultiplier) * param.power
    
    if damage > 0 then
        battle:AddModifier("BASE", "增加", damage * multiplier)
    end
    
    -- 处理释放者属性增伤
    if self.damageAmplifier then
        for _, amplifier in ipairs(self.damageAmplifier) do
            local modifier = amplifier:GetModifier(caster, damage, multiplier, param)
            if modifier then
                battle:AddModifier(modifier)
            end
        end
    end
    
    -- 处理目标属性增伤
    if self.targetDamageAmplifier then
        for _, amplifier in ipairs(self.targetDamageAmplifier) do
            local modifier = amplifier:GetModifier(target, damage, multiplier, param)
            if modifier then
                battle:AddModifier(modifier)
            end
        end
    end
    
    -- 打印治疗信息
    if param.printInfo then
        local log = {}
        table.insert(log, string.format("=== %s 治疗构成 ===", self.spellName))
        
        table.insert(log, "基础治疗修饰器:")
        for _, modifier in ipairs(battle:GetBaseModifiers()) do
            table.insert(log, string.format("  %s: %s (%s)", 
                modifier.source, 
                modifier.amount, 
                modifier.modifierType))
        end
        
        table.insert(log, "倍率修饰器:")
        for _, modifier in ipairs(battle:GetMultiplyModifiers()) do
            table.insert(log, string.format("  %s: %s (%s)", 
                modifier.source, 
                modifier.amount, 
                modifier.modifierType))
        end
        
        table.insert(log, "最终倍率修饰器:")
        for _, modifier in ipairs(battle:GetFinalMultiplyModifiers()) do
            table.insert(log, string.format("  %s: %s (%s)", 
                modifier.source, 
                modifier.amount, 
                modifier.modifierType))
        end
        
        table.insert(log, string.format("最终治疗: %s", battle:GetFinalDamage()))
        table.insert(log, "=====================")
        
        caster:SendLog(table.concat(log, "\n"))
    end
    
    target:Heal(battle:GetFinalDamage(), self.spellName)
    self:PlayEffect(self.castEffects, caster, target, param)
    
    return true
end

return HealSpell