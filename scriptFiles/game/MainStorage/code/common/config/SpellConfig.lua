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
        ["释放条件"] = Modifiers.New({
            {
                ["目标"] = "自己",
                ["条件类型"] = "HealthCondition",
                ["条件"] = {
                    ["百分比"] = true,
                    ["最小值"] = 0,
                    ["最大值"] = 100
                },
                ["动作"] = "必须"
            }
        }),
        ["特效_释放"] = {
            {
                ["_type"] = "ParticleGraphic",
                ["特效对象"] = "CherryBomb",
                ["特效资产"] = "",
                ["绑定实体"] = false,
                ["绑定挂点"] = "",
                ["偏移"] = {
                    0,
                    0,
                    0
                },
                ["目标"] = 1,
                ["目标场景名"] = "",
                ["延迟"] = 0,
                ["持续时间"] = 2,
                ["重复次数"] = 1,
                ["重复延迟"] = 0
            }
        },
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1
    }),
    ["获得物品魔法"] = Spell.Load({
        ["类型"] = "ItemSpell",
        ["物品类型"] = "阳光",
        ["基础数量"] = 10,
        ["基础倍率"] = 1,
        ["魔法名"] = "获得物品魔法",
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
    }),
    ["豌豆射手"] = Spell.Load({
        ["类型"] = "ProjectileSpell",
        ["生成于自己位置"] = false,
        ["可重复碰撞同一目标"] = false,
        ["对同一目标生效间隔"] = -1,
        ["生效次数"] = -1,
        ["散射次数"] = 1,
        ["散射角度"] = 0,
        ["散射延迟"] = 0,
        ["持续时间"] = -1,
        ["魔法名"] = "豌豆射手",
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
