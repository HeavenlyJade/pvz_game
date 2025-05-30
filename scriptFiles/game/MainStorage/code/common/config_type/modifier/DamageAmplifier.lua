local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr

---@class DamageAmplifier:Class
---@field statType string 属性类型
---@field multiplier number 倍率
---@field addType string 增加类型
---@field multiplyBaseValue boolean 是否乘以基础数值
---@field New fun( data:table ):DamageAmplifier
local DamageAmplifier = ClassMgr.Class("DamageAmplifier")

---@param data table[] 伤害修改器数组
---@return DamageAmplifier[]|nil 伤害修改器实例数组
function DamageAmplifier.Load(data)
    if data == nil then
        return nil
    end
    local amplifiers = {}
    for _, item in ipairs(data) do
        table.insert(amplifiers, DamageAmplifier.New(item))
    end
    return amplifiers
end

function DamageAmplifier:OnInit(data)
    self.statType = data["属性类型"] ---@type string
    self.multiplier = data["倍率"] ---@type number
    self.addType = data["增加类型"] ---@type string
    self.multiplyBaseValue = data["乘以基础数值"] ---@type boolean
end

---@param caster Entity 施法者
---@param baseValue number 基础数值
---@param multiplier number 倍率
---@param castParam CastParam 施法参数
---@return table|nil 伤害修改器
function DamageAmplifier:GetModifier(caster, baseValue, multiplier, castParam)
    local amount
    if self.statType then
        amount = caster:GetStat(self.statType, nil, nil, castParam)
    else
        amount = 1
    end
    if self.multiplyBaseValue then
        amount = amount * baseValue
    end
    amount = self.multiplier * amount * multiplier
    if amount == 0 then return nil end
    return {
        source = self.statType,
        modifierType = self.addType,
        amount = amount
    }
end

return DamageAmplifier