local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local Battle = require(MainStorage.code.server.Battle) ---@type Battle
---@class CastParam:Class
---@field New fun( ...:table ):CastParam
local CastParam = ClassMgr.Class("CastParam")

function CastParam:OnInit(...)
    local data = ... or {}
    self.power = data.power or 1.0 ---@type number
    self.cancelled = data.cancelled or false ---@type boolean
    self.realTarget = data.realTarget ---@type Entity
    self.skipTags = data.skipTags or {} ---@type table<string, boolean>
    self.extraModifiers = data.extraModifiers or {} ---@type table<string, Battle>
    self.extraParams = data.extraParams or {} ---@type table<string, any>
    self.dynamicTags = data.dynamicTags ---@type table<string, EquipingTag[]>|nil
    self.lookDirection = nil --仅限主动释放技能： 释放时玩家的摄像机朝向
end

function CastParam:Clone()
    -- 特殊处理extraModifiers，因为它包含Battle对象不能简单clone
    local clonedExtraModifiers = {}
    if self.extraModifiers then
        for key, battle in pairs(self.extraModifiers) do
            -- 为每个Battle对象创建新的实例而不是克隆
            if battle and battle.attacker and battle.victim and battle.source then
                clonedExtraModifiers[key] = Battle.New(battle.attacker, battle.victim, battle.source)
            end
        end
    end
    
    local cloned = CastParam.New({
        power = self.power,
        cancelled = self.cancelled,
        realTarget = self.realTarget,
        skipTags = gg.clone(self.skipTags),
        extraModifiers = clonedExtraModifiers,
        extraParams = gg.clone(self.extraParams),
        dynamicTags = self.dynamicTags and gg.clone(self.dynamicTags) or nil
    })
    return cloned
end

---@param spell Spell
---@param v string
---@param def number
---@return number
function CastParam:GetValue(spell, v, def)
    return self:GetValueByName(spell.spellName, v, def)
end

---@param name string
---@param v string
---@param previousValue number
---@return number
function CastParam:GetValueByName(name, v, previousValue)
    previousValue = self:GetParamByName(name, v, previousValue)
    local adder1 = 0.0
    local adder2 = 0.0
    
    local value = self.extraModifiers[name .. "." .. v]
    if value then
        adder1 = value:GetFinalDamage(previousValue) - previousValue
    end
    
    value = self.extraModifiers[v]
    if value then
        adder2 = value:GetFinalDamage(previousValue) - previousValue
    end
    
    return previousValue + adder1 + adder2
end

---@generic T
---@param spell Spell
---@param v string
---@param def T
---@return T
function CastParam:GetParam(spell, v, def)
    return self:GetParamByName(spell.spellName, v, def)
end

---@generic T
---@param name string
---@param v string
---@param def T
---@return T
function CastParam:GetParamByName(name, v, def)
    -- 添加调试日志
    if name == "挂机获得阳光" and v == "基础数量" then
        gg.log("🔍 GetParamByName调试:", name, v, def)
        gg.log("🔍 extraParams内容:", gg.printTable(self.extraParams))
        local fullKey = name .. "." .. v
        gg.log("🔍 查找键:", fullKey, "值:", self.extraParams[fullKey])
        gg.log("🔍 备用键:", v, "值:", self.extraParams[v])
    end
    
    local value = self.extraParams[name .. "." .. v] or self.extraParams[v]
    
    if name == "挂机获得阳光" and v == "基础数量" then
        gg.log("🔍 最终返回值:", value, "默认值:", def)
    end
    
    if value == nil then
        return def
    end
    
    return value
end

function CastParam:GetToStringParams()
    return {
        power = self.power,
        cancelled = self.cancelled
    }
end

return CastParam