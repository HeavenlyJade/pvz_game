local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local CastParam = require(MainStorage.code.common.spell.CastParam) ---@type CastParam
local SpellConfig = require(MainStorage.code.common.Config.SpellConfig)
local Battle            = require(MainStorage.code.server.Battle)    ---@type Battle

---@class OverrideParam
---@field objectName string
---@field paramName string
---@field value number

---@class OverrideValue
---@field objectName string
---@field paramName string
---@field paramValue DamageAmplifier
---@field isAlways boolean

---@class SubSpell:Class
---@field spell Spell 魔法
---@field overrideParams OverrideParam[] 复写参数
---@field overrideValues OverrideValue[] 修改数值
---@field dynamicTags table<string, EquipingTag[]> 动态词条
local SubSpell = ClassMgr.Class("SubSpell")

function SubSpell:OnInit( data )
    self.spell = SpellConfig.Get(data["魔法"])
    self.overrideParams = {}
    self.overrideValues = {}
    self.dynamicTags = {}
end

--- 执行子魔法
---@param caster CLiving 施法者
---@param target CLiving|Vector3 目标
---@param param CastParam|nil 参数
---@return boolean 是否成功释放
function SubSpell:Cast(caster, target, param)
    if not param then
        param = CastParam.New()
    end
    local spellParam = param:Clone()
    
    -- 合并本地的dynamicTags到spellParam的dynamicTags
    if self.dynamicTags then
        if not spellParam.dynamicTags then
            spellParam.dynamicTags = {}
        end
        
        for key, tags in pairs(self.dynamicTags) do
            if not spellParam.dynamicTags[key] then
                spellParam.dynamicTags[key] = {}
            end
            
            for _, tag in ipairs(tags) do
                -- 检查是否已存在相同ID的词条
                local existingTag = nil
                for _, t in ipairs(spellParam.dynamicTags[key]) do
                    if t.id == tag.id then
                        existingTag = t
                        break
                    end
                end
                
                if existingTag then
                    -- 如果存在相同ID的词条，增加其等级
                    existingTag.level = existingTag.level + tag.level
                else
                    -- 如果不存在，添加新词条
                    table.insert(spellParam.dynamicTags[key], tag)
                end
            end
        end
    end
    
    -- 处理修改数值
    if self.overrideValues then
        for _, modifier in ipairs(self.overrideValues) do
            if modifier.paramName then
                local name
                if not modifier.objectName or modifier.isAlways then
                    name = modifier.paramName
                else
                    name = modifier.objectName .. "." .. modifier.paramName
                end
                
                if not spellParam.extraModifiers[name] then
                    spellParam.extraModifiers[name] = Battle.New(caster, caster, name)
                end
                
                spellParam.extraModifiers[name]:AddModifier(
                    self.spell.spellName,
                    modifier.paramValue.addType,
                    modifier.paramValue.multiplier
                )
            end
        end
    end
    
    -- 处理复写参数
    if self.overrideParams then
        for _, modifier in ipairs(self.overrideParams) do
            if modifier.paramName then
                local name
                if not modifier.objectName then
                    name = modifier.paramName
                else
                    name = modifier.objectName .. "." .. modifier.paramName
                end
                
                spellParam.extraParams[name] = modifier.value
            end
        end
    end
    
    return self.spell:Cast(caster, target, spellParam)
end

return SubSpell