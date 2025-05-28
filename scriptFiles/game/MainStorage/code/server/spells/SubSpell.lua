local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
local Battle            = require(MainStorage.code.server.Battle)    ---@type Battle
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg

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
---@field spellCache Spell 魔法
---@field overrideParams OverrideParam[] 复写参数
---@field overrideValues OverrideValue[] 修改数值
---@field dynamicTags table<string, EquipingTag[]> 动态词条
local SubSpell = ClassMgr.Class("SubSpell")

function SubSpell:OnInit( data )
    self.spellCache = nil
    self.spellName = data["魔法"]

    -- 初始化复写参数
    self.overrideParams = {}
    if data["复写参数"] then
        for _, param in ipairs(data["复写参数"]) do
            table.insert(self.overrideParams, {
                objectName = param["objectName"],
                paramName = param["paramName"],
                value = param["value"]
            })
        end
    end

    -- 初始化修改数值
    self.overrideValues = {}
    if data["修改数值"] then
        for _, value in ipairs(data["修改数值"]) do
            table.insert(self.overrideValues, {
                objectName = value["objectName"],
                paramName = value["paramName"],
                paramValue = {
                    multiplier = value["paramValue"]["倍率"],
                    addType = value["paramValue"]["增加类型"],
                    multiplyBase = value["paramValue"]["乘以基础数值"]
                },
                isAlways = value["isAlways"]
            })
        end
    end

    self.dynamicTags = {}
end

function SubSpell:CanCast(caster, target)
    if not self.spellCache then
        local SpellConfig = require(MainStorage.code.common.config.SpellConfig)
        self.spellCache = SpellConfig.Get(self.spellName)
        gg.log("CanCast", self.spellName, self.spellCache)
    end
    local param = CastParam.New()
    self.spellCache:CanCast(caster, target, param)
    return not param.cancelled
end

--- 执行子魔法
---@param caster Entity 施法者
---@param target Entity|Vector3 目标
---@param param CastParam|nil 参数
---@return boolean 是否成功释放
function SubSpell:Cast(caster, target, param)
    if not self.spellCache then
        local SpellConfig = require(MainStorage.code.common.config.SpellConfig)
        self.spellCache = SpellConfig.Get(self.spellName)
    end
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
                    self.spellCache.spellName,
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
    
    return self.spellCache:Cast(caster, target, spellParam)
end

return SubSpell
