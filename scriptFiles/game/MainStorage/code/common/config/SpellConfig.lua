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
    ["豌豆射手-伤害"] = Spell.Load({
        ["类型"] = "PainSpell",
        ["基础伤害"] = 5,
        ["基础倍率"] = 1,
        ["元素类型"] = "无",
        ["魔法名"] = "豌豆射手-伤害",
        ["打印信息"] = false,
        ["冷却"] = 0,
        ["各目标冷却"] = 0,
        ["各目标冷却倍率"] = 0,
        ["基础威力"] = 1,
        ["释放给自己"] = false,
        ["延迟"] = 0,
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1,
        ["必须要目标"] = true
    }),
    ["豌豆射手"] = Spell.Load({
        ["类型"] = "ProjectileSpell",
        ["飞弹模型"] = "飞弹",
        ["持续时间"] = 5,
        ["生成于自己位置"] = true,
        ["散射次数"] = 1,
        ["散射角度"] = 0,
        ["散射延迟"] = 0,
        ["穿过地形"] = false,
        ["可重复碰撞同一目标"] = false,
        ["对同一目标生效间隔"] = -1,
        ["生效次数"] = 1,
        ["魔法名"] = "豌豆射手",
        ["打印信息"] = false,
        ["冷却"] = 0.3,
        ["各目标冷却"] = 0,
        ["各目标冷却倍率"] = 0,
        ["基础威力"] = 1,
        ["释放给自己"] = false,
        ["延迟"] = 0,
        ["子魔法"] = {
            {
                ["魔法"] = "豌豆射手-伤害"
            }
        },
        ["特效_前摇"] = {
            {
                ["_type"] = "CameraShakeGraphic",
                ["频率"] = 0.05,
                ["强度"] = 1,
                ["旋转"] = {
                    0,
                    0,
                    0
                },
                ["位移"] = {
                    0,
                    1,
                    0
                },
                ["循环"] = false,
                ["目标"] = "自己",
                ["目标场景名"] = "",
                ["延迟"] = 0,
                ["持续时间"] = 0,
                ["重复次数"] = 1,
                ["重复延迟"] = 0
            }
        },
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1,
        ["必须要目标"] = false
    }),
    ["副_召唤_豌豆射手"] = Spell.Load({
        ["类型"] = "SummonSpell",
        ["召唤在目标位置"] = false,
        ["怪物类型"] = "副-召唤物-豌豆射手",
        ["最大数量"] = 1,
        ["召唤范围"] = 100,
        ["持续时间"] = 0,
        ["继承等级"] = false,
        ["魔法名"] = "副_召唤_豌豆射手",
        ["打印信息"] = false,
        ["冷却"] = 0,
        ["各目标冷却"] = 0,
        ["各目标冷却倍率"] = 0,
        ["基础威力"] = 1,
        ["释放给自己"] = true,
        ["延迟"] = 0,
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1,
        ["必须要目标"] = true
    }),
    ["伤害魔法"] = Spell.Load({
        ["类型"] = "PainSpell",
        ["基础伤害"] = 30,
        ["基础倍率"] = 1,
        ["元素类型"] = "无",
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
                ["目标"] = "目标",
                ["目标场景名"] = "",
                ["延迟"] = 0,
                ["持续时间"] = 2,
                ["重复次数"] = 1,
                ["重复延迟"] = 0
            }
        },
        ["宽度倍率"] = 1,
        ["高度倍率"] = 1,
        ["尺寸倍率"] = 1,
        ["必须要目标"] = true
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
        ["尺寸倍率"] = 1,
        ["必须要目标"] = true
    })
} 
    loaded = true
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
