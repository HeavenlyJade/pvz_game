
    
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Spell = require(MainStorage.code.common.spell.Spell) ---@type Spell
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifier.Modifiers) ---@type Modifiers
--- 魔法配置文件
---@class SpellConfig
local SpellConfig= { config = {
    ["伤害魔法"] = Spell.New({
        ["基础伤害"] = 0,
        ["基础倍率"] = 1,
        ["元素类型"] = 0,
        ["魔法名"] = "伤害魔法",
        ["打印信息"] = false,
        ["冷却"] = 0,
        ["各目标冷却"] = 0,
        ["各目标冷却倍率"] = 0,
        ["基础威力"] = 1,
        ["释放给自己"] = false,
        ["延迟"] = 0,
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1
    })
}}

---@param spellName string
---@return Spell
function SpellConfig.Get(spellName)
    return SpellConfig.config[spellName]
end

---@return Spell[]
function SpellConfig.GetAll()
    return SpellConfig.config
end
return SpellConfig
