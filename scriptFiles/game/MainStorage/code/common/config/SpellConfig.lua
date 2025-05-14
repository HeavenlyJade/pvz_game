local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers

--- 魔法配置文件
---@class SpellConfig
local SpellConfig = {}
local loaded = false

local function LoadConfig()
    SpellConfig.config ={
    ["伤害魔法"] = Spell.Load({
        ["类型"] = "PainSpell",
        ["基础伤害"] = 30,
        ["基础倍率"] = 1,
        ["元素类型"] = 0,
        ["魔法名"] = "伤害魔法",
        ["打印信息"] = true,
        ["冷却"] = 0,
        ["各目标冷却"] = 0,
        ["各目标冷却倍率"] = 0,
        ["基础威力"] = 1,
        ["释放给自己"] = false,
        ["延迟"] = 0,
        ["自身条件"] = Modifiers.New({
            {
                ["条件类型"] = "HealthCondition",
                ["条件"] = {
                    ["百分比"] = true,
                    ["最小值"] = 0,
                    ["最大值"] = 100
                },
                ["动作"] = "必须"
            }
        }),
        ["子魔法"] = {
            {
                ["魔法"] = "伤害魔法",
                ["复写参数"] = {
                    ["objectName"] = "伤害魔法",
                    ["paramName"] = "基础伤害",
                    ["value"] = 50
                },
                ["修改数值"] = {
                    {
                        ["objectName"] = "伤害魔法",
                        ["paramName"] = "基础倍率",
                        ["paramValue"] = {
                            ["倍率"] = 50,
                            ["增加类型"] = 1,
                            ["乘以基础数值"] = false
                        },
                        ["isAlways"] = false
                    }
                }
            }
        },
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1
    })
}loaded = true
end

---@param spellName string
---@return Spell
function SpellConfig.Get(spellName)
    if not loaded then
        LoadConfig()
    end
    return SpellConfig.config[spellName]
end

---@return Spell[]
function SpellConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return SpellConfig.config
end
return SpellConfig
