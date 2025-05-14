local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
---@class CastParam:Class
---@field New fun( ...:table ):CastParam
local CastParam = ClassMgr.Class("CastParam")

function CastParam:OnInit(...)
    local data = ... or {}
    self.power = data.power or 1.0 ---@type number
    self.cancelled = data.cancelled or false ---@type boolean
    self.realTarget = data.realTarget ---@type Entity|Vector3|nil
    self.skipTags = data.skipTags or {} ---@type table<string, boolean>
    self.extraModifiers = data.extraModifiers or {} ---@type table<string, Battle>
    self.extraParams = data.extraParams or {} ---@type table<string, any>
    self.dynamicTags = data.dynamicTags ---@type table<string, EquipingTag[]>|nil
end

function CastParam:Clone()
    local cloned = CastParam.New({
        power = self.power,
        cancelled = self.cancelled,
        realTarget = self.realTarget,
        skipTags = gg.clone(self.skipTags),
        extraModifiers = gg.clone(self.extraModifiers),
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
    -- gg.log("GetParamByName", name, v, def)
    local value = self.extraParams[name .. "." .. v] or self.extraParams[v]
    if value == nil then
        return def
    end
    
    -- 处理数值类型转换
    if type(def) == "number" then
        if math.type(value) == "integer" and math.type(def) == "float" then
            return value + 0.0 -- 将整数转为浮点数
        elseif math.type(value) == "float" and math.type(def) == "integer" then
            return math.floor(value) -- 将浮点数转为整数
        end
    end
    
    -- 尝试直接返回相同类型
    if type(value) == type(def) then
        return value
    end
    
    -- 类型不匹配时返回默认值
    warn(string.format("参数类型转换失败: %s.%s, 值类型: %s, 目标类型: %s", 
        name, v, type(value), type(def)))
    return def
end

return CastParam