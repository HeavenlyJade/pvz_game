local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobType      = require(MainStorage.code.common.config_type.MobType)    ---@type MobType

--- 怪物配置文件
---@class MobTypeConfig
local MobTypeConfig = {}
local loaded = false

local function LoadConfig()
    MobTypeConfig.config ={
    ["副-召唤物-豌豆射手"] = MobType.New({
        ["怪物ID"] = "副-召唤物-豌豆射手",
        ["显示名"] = "豌豆射手",
        ["尺寸"] = {
            0,
            0
        },
        ["模型"] = "僵尸",
        ["状态机"] = "卡片",
        ["是首领"] = false,
        ["基础等级"] = 1,
        ["属性公式"] = {
            ["攻击"] = "(2^(LVL/10))*(10*LVL*1*1.13*20)^1.1",
            ["生命"] = "(2^(LVL/10))*(10*LVL*1*1.13*20)^1.1",
            ["速度"] = "100"
        },
        ["技能"] = {
            {
                ["时机"] = "周期",
                ["默认目标"] = "目标",
                ["魔法"] = {
                    {
                        ["魔法"] = "豌豆射手"
                    }
                },
                ["距离"] = 0
            }
        },
        ["图鉴击杀数"] = 0,
        ["图鉴完成奖励数量"] = 0,
        ["显示血条"] = true,
        ["额外攻击距离"] = 100,
        ["攻击时点"] = 0.5
    }),
    ["野人"] = MobType.New({
        ["怪物ID"] = "野人",
        ["显示名"] = "岩浆徘行者",
        ["描述"] = "地心魔物，步履熔岩，所过皆烬",
        ["尺寸"] = {
            0,
            0
        },
        ["模型"] = "僵尸",
        ["状态机"] = "僵尸",
        ["是首领"] = true,
        ["基础等级"] = 26,
        ["属性公式"] = {
            ["攻击"] = "(2^(LVL/10))*(10*LVL*1*1.13*20)^1.1",
            ["生命"] = "(2^(LVL/10))*(10*LVL*1*1.13*20)^1.1",
            ["速度"] = "100"
        },
        ["图鉴击杀数"] = 146,
        ["图鉴完成奖励"] = nil,
        ["图鉴完成奖励数量"] = 50,
        ["显示血条"] = true,
        ["额外攻击距离"] = 100,
        ["攻击时点"] = 0.5,
        ["技能"] = {
            {
                ["时机"] = "周期",
                ["默认目标"] = "目标",
                ["魔法"] = {
                    ["魔法"] = "豌豆射手"
                },
                ["距离"] = 0
            }
        },
        ["行为"] = {
            {
                ["脱战距离"] = 2000,
                ["主动索敌"] = 50,
                ["攻击时静止"] = true,
                ["类型"] = "近战攻击"
            },
            {
                ["距离"] = 500,
                ["保持在出生点附近"] = true,
                ["几率"] = 50,
                ["类型"] = "随机移动"
            },
            {
                ["类型"] = "静止"
            }
        }
    })
}loaded = true
end

---@param mobType string
---@return MobType
function MobTypeConfig.Get(mobType)
    if not loaded then
        LoadConfig()
    end
    return MobTypeConfig.config[mobType]
end

---@return MobType[]
function MobTypeConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return MobTypeConfig.config
end
return MobTypeConfig
