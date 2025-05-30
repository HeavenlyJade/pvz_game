local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local SkillType      = require(MainStorage.code.common.config_type.SkillType)    ---@type SkillType

--- 技能配置文件
---@class SkillTypeConfig
local SkillTypeConfig = {}
local entrySkills = {} ---@type SkillType[]
local loaded = false

local function LoadConfig()
    SkillTypeConfig.config ={
    ["三头豌豆"] = SkillType.New({
        ["技能名"] = "三头豌豆",
        ["最大等级"] = 1,
        ["技能描述"] = "同时发射三枚豌豆，能够穿透3个敌人，且击中敌人有50%概率造成1.5倍伤害",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "三头豌豆_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["射速1_三头豌豆"] = SkillType.New({
        ["技能名"] = "射速1_三头豌豆",
        ["显示名"] = "射速提升",
        ["最大等级"] = 10,
        ["技能描述"] = "三头豌豆射速+100%",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            nil
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "射速1_词条_三头豌豆"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["射速1_双发豌豆"] = SkillType.New({
        ["技能名"] = "射速1_双发豌豆",
        ["显示名"] = "射速提升",
        ["最大等级"] = 10,
        ["技能描述"] = "双发豌豆射速+30%",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "高速射手"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "射速1_词条_双发豌豆"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["攻击1_双发豌豆"] = SkillType.New({
        ["技能名"] = "攻击1_双发豌豆",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 10,
        ["技能描述"] = "[被动词条.1]",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "寒冰射手"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "攻击1_词条_双发豌豆"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["双发豌豆"] = SkillType.New({
        ["技能名"] = "双发豌豆",
        ["最大等级"] = 1,
        ["技能描述"] = "同时发射二枚豌豆",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "射速1_双发豌豆",
            "攻击1_双发豌豆"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "双发豌豆_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["寒冰加特林"] = SkillType.New({
        ["技能名"] = "寒冰加特林",
        ["最大等级"] = 1,
        ["技能描述"] = "对击中的敌人有30%几率造成1秒冰冻，使其受伤加重及受到持续伤害，持续2秒",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "攻击1_寒冰加特林"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "寒冰加特林_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["攻击1_寒冰加特林"] = SkillType.New({
        ["技能名"] = "攻击1_寒冰加特林",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 10,
        ["技能描述"] = "[被动词条.1]",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "火焰豌豆"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "攻击1_词条_寒冰加特林"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["减速1_寒冰射手"] = SkillType.New({
        ["技能名"] = "减速1_寒冰射手",
        ["显示名"] = "射速提升",
        ["最大等级"] = 10,
        ["技能描述"] = "寒冰射手造成的减速持续时间增加",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "寒冰加特林"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "射速1_词条_双发豌豆"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["攻击1_寒冰射手"] = SkillType.New({
        ["技能名"] = "攻击1_寒冰射手",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 10,
        ["技能描述"] = "[被动词条.1]",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "寒冰加特林"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "攻击1_词条_寒冰射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["寒冰射手"] = SkillType.New({
        ["技能名"] = "寒冰射手",
        ["最大等级"] = 1,
        ["技能描述"] = "同时发射二枚豌豆，并对命中的敌人造成减速",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "减速1_寒冰射手",
            "攻击1_寒冰射手"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "寒冰射手_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["火焰豌豆"] = SkillType.New({
        ["技能名"] = "火焰豌豆",
        ["最大等级"] = 1,
        ["技能描述"] = "转换为火焰攻击，击中敌人后造成爆炸伤害并对其造成减速及持续伤害",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "攻击1_火焰豌豆"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "火焰豌豆_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["攻击1_火焰豌豆"] = SkillType.New({
        ["技能名"] = "攻击1_火焰豌豆",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 10,
        ["技能描述"] = "[被动词条.1]",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "攻击1_词条_火焰豌豆"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["射速1_豌豆"] = SkillType.New({
        ["技能名"] = "射速1_豌豆",
        ["显示名"] = "射速提升",
        ["最大等级"] = 10,
        ["技能描述"] = "所有豌豆射手射速+20%",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "双发豌豆"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "射速1_词条_豌豆射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["攻击1_豌豆"] = SkillType.New({
        ["技能名"] = "攻击1_豌豆",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 10,
        ["技能描述"] = "[被动词条.1]",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "双发豌豆"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "攻击1_词条_豌豆射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["生命1_豌豆"] = SkillType.New({
        ["技能名"] = "生命1_豌豆",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 10,
        ["技能描述"] = "[被动词条.1]",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "双发豌豆"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "生命1_词条_豌豆射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["豌豆射手"] = SkillType.New({
        ["技能名"] = "豌豆射手",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆射手可谓你的第一道防线，他们朝来犯的僵尸射击豌豆。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "射速1_豌豆",
            "攻击1_豌豆",
            "生命1_豌豆"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "豌豆射手_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["高速加特林"] = SkillType.New({
        ["技能名"] = "高速加特林",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆能够穿透3个敌人，且击中敌人后有概率造成额外伤害",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "射速1_高速加特林"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "高速加特林_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["射速1_高速加特林"] = SkillType.New({
        ["技能名"] = "射速1_高速加特林",
        ["显示名"] = "射速提升",
        ["最大等级"] = 10,
        ["技能描述"] = "高速加特林+80%",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "三头豌豆"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "射速1_词条_高速加特林"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["高速射手"] = SkillType.New({
        ["技能名"] = "高速射手",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆会对击中的目标造成穿透",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "射速1_高速射手"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "高速射手_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["射速1_高速射手"] = SkillType.New({
        ["技能名"] = "射速1_高速射手",
        ["显示名"] = "射速提升",
        ["最大等级"] = 10,
        ["技能描述"] = "高速射手射速+60%",
        ["技能品级"] = "UR",
        ["是入口技能"] = false,
        ["技能分类"] = 0,
        ["下一技能"] = {
            "高速加特林"
        },
        ["无需装备也可生效"] = true,
        ["被动词条"] = {
            "射速1_词条_高速射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["副-仙人掌"] = SkillType.New({
        ["技能名"] = "副-仙人掌",
        ["显示名"] = "仙人掌",
        ["最大等级"] = 1,
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_仙人掌",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0.2,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["副-地刺"] = SkillType.New({
        ["技能名"] = "副-地刺",
        ["显示名"] = "坚果",
        ["最大等级"] = 1,
        ["技能描述"] = "使踩过的僵尸受到持续伤害。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "地刺_脉冲",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = false
    }),
    ["副-坚果"] = SkillType.New({
        ["技能名"] = "副-坚果",
        ["显示名"] = "坚果",
        ["最大等级"] = 1,
        ["技能描述"] = "坚果拥有极厚血量，可以抵御僵尸的伤害。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_坚果",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-星星果"] = SkillType.New({
        ["技能名"] = "副-星星果",
        ["显示名"] = "星星果",
        ["最大等级"] = 1,
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_星星果",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = false
    }),
    ["副-椰子炮"] = SkillType.New({
        ["技能名"] = "副-椰子炮",
        ["显示名"] = "椰子炮",
        ["最大等级"] = 1,
        ["技能描述"] = "发射一枚椰子，遇到第一个敌人时炸开并造成范围伤害。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_椰子炮",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-樱桃炸弹"] = SkillType.New({
        ["技能名"] = "副-樱桃炸弹",
        ["显示名"] = "樱桃炸弹",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆射手可谓你的第一道防线，他们朝来犯的僵尸射击豌豆。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副-樱桃炸弹-飞弹",
        ["目标模式"] = "位置",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-火爆辣椒"] = SkillType.New({
        ["技能名"] = "副-火爆辣椒",
        ["显示名"] = "樱桃炸弹",
        ["最大等级"] = 1,
        ["技能描述"] = "种植后立刻爆炸，对一整行的目标造成巨大火系伤害，但会解除敌人的冰冻或减速状态。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副-樱桃炸弹-飞弹",
        ["目标模式"] = "位置",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-白菜拳击手"] = SkillType.New({
        ["技能名"] = "副-白菜拳击手",
        ["显示名"] = "白菜拳击手",
        ["最大等级"] = 1,
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_白菜拳击手召唤",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-窝瓜"] = SkillType.New({
        ["技能名"] = "副-窝瓜",
        ["显示名"] = "窝瓜",
        ["最大等级"] = 1,
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_窝瓜_飞弹",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-豌豆射手"] = SkillType.New({
        ["技能名"] = "副-豌豆射手",
        ["显示名"] = "豌豆射手",
        ["最大等级"] = 1,
        ["技能描述"] = "向僵尸投掷一枚燃烧着的甜椒，并使命中的敌人受到持续伤害。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_豌豆射手",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-辣椒投手"] = SkillType.New({
        ["技能名"] = "副-辣椒投手",
        ["显示名"] = "辣椒投手",
        ["最大等级"] = 1,
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_辣椒投手",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    }),
    ["副-钢铁地刺"] = SkillType.New({
        ["技能名"] = "副-钢铁地刺",
        ["显示名"] = "钢铁地刺",
        ["最大等级"] = 1,
        ["技能描述"] = "使踩过的僵尸受到持续伤害。",
        ["技能品级"] = "UR",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "地刺_脉冲",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
        ["启用后坐力"] = false
    })
}loaded = true

--将SkillType的"下一技能"转换为SkillType
for _, skillType in pairs(SkillTypeConfig.config) do
    -- 收集入口技能
    if skillType.isEntrySkill then
        table.insert(entrySkills, skillType)
    end

    if skillType.nextSkills then
        local nextSkills = {}
        for _, skillName in ipairs(skillType.nextSkills) do
            local nextSkill = SkillTypeConfig.config[skillName]
            if nextSkill then
                table.insert(nextSkills, nextSkill)
                -- 将当前技能添加到下一技能的prerequisite列表中
                table.insert(nextSkill.prerequisite, skillType)
            else
                gg.log("技能配置错误：找不到下一技能 " .. skillName)
            end
        end
        skillType.nextSkills = nextSkills
    end
end
end

---@param name string
---@return SkillType
function SkillTypeConfig.Get(name)
    if not loaded then
        LoadConfig()
    end
    return SkillTypeConfig.config[name]
end

---@return SkillType[]
function SkillTypeConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return SkillTypeConfig.config
end

---@return SkillType[]
function SkillTypeConfig.GetEntrySkills()
    if not loaded then
        LoadConfig()
    end
    return entrySkills
end

---@class SkillTree
---@field mainSkill SkillType 主技能（入口技能）
---@field branches SkillType[] 分支技能列表
---获取技能树数据结构，按主卡分组
---@param skillCategory number 技能分类 (0=主卡, 1=副卡)
---@return table<string, SkillTree> 技能树映射表，key为主技能名称
function SkillTypeConfig.GetSkillTrees(skillCategory)
    if not loaded then
        LoadConfig()
    end

    local skillTrees = {} ---@type table<string, SkillTree>

    -- 遍历所有技能配置，找到指定分类的入口技能
    for skillName, skillType in pairs(SkillTypeConfig.config) do
        -- 筛选条件：是入口技能 且 属于指定分类
        if skillType.isEntrySkill and skillType.skillType == skillCategory then

            -- 创建技能树结构
            local skillTree = {
                mainSkill = skillType,
                branches = {} ---@type SkillType[]
            }

            -- 收集该主卡的所有分支技能
            if skillType.nextSkills then
                for _, nextSkill in ipairs(skillType.nextSkills) do
                    table.insert(skillTree.branches, nextSkill)
                end
            end

            -- 以主技能名称作为key存储技能树
            skillTrees[skillType.name] = skillTree
        end
    end

    gg.log("技能树构建完成，共", gg.table2str(skillTrees), "个技能树")
    return skillTrees
end

--- 构建技能森林（多根树结构）
---@param skillCategory number 技能分类 (0=主卡, 1=副卡)
---@return table 森林结构，每个元素是一棵技能树的根节点
function SkillTypeConfig.BuildSkillForest(skillCategory)
    if not loaded then
        LoadConfig()
    end
    
    local forest = {} ---@type SkillTree[]
    local nodeCache = {} ---@type table<string, SkillTree> -- 节点缓存
    
    -- 查找根节点（没有父节点的技能）
    local function isRoot(skillName)
        local skillType = SkillTypeConfig.config[skillName]
        if not skillType or skillType.skillType ~= skillCategory then return false end
        if skillType.isEntrySkill then
            return true
        end
        if not skillType.prerequisite or #skillType.prerequisite == 0 then
            return true
        end
        return false
    end
    
    -- 递归构建技能树
    ---@param skillName string
    ---@param pathSet table<string, boolean> 当前路径集合，用于检测循环引用
    ---@return SkillTree|nil
    local function buildTree(skillName, pathSet)
        if pathSet[skillName] then
            gg.log("检测到技能树循环引用: " .. skillName)
            return nil
        end
        local skillType = SkillTypeConfig.config[skillName]
        if not skillType or skillType.skillType ~= skillCategory then
            return nil
        end
        -- 检查缓存中是否已有该节点
        if nodeCache[skillName] then
            return nodeCache[skillName]
        end
        local treeNode = {
            name = skillName,
            data = skillType,
            children = {}
        }
        nodeCache[skillName] = treeNode
        -- 创建新的路径集合（包含当前节点）
        local newPathSet = {}
        for k, v in pairs(pathSet) do
            newPathSet[k] = v
        end
        newPathSet[skillName] = true
        -- 递归添加子节点
        if skillType.nextSkills then
            for _, nextSkill in ipairs(skillType.nextSkills) do
                local childName = nextSkill.name
                local childTree = buildTree(childName, newPathSet)
                if childTree then
                    table.insert(treeNode.children, childTree)
                end
            end
        end
        return treeNode
    end
    -- 构建森林（所有根节点）
    for skillName, _ in pairs(SkillTypeConfig.config) do
        if isRoot(skillName) and not nodeCache[skillName] then
            local tree = buildTree(skillName, {})
            if tree then
                table.insert(forest, tree)
            end
        end
    end
    -- 处理非根节点但有多个父节点的情况
    for skillName, skillType in pairs(SkillTypeConfig.config) do
        if skillType.skillType == skillCategory and not nodeCache[skillName] then
            local treeNode = {
                name = skillName,
                data = skillType,
                children = {}
            }
            nodeCache[skillName] = treeNode
            if skillType.nextSkills then
                for _, nextSkill in ipairs(skillType.nextSkills) do
                    local childName = nextSkill.name
                    local childTree = nodeCache[childName] or buildTree(childName, {[skillName] = true})
                    if childTree then
                        table.insert(treeNode.children, childTree)
                    end
                end
            end
        end
    end
    return forest
end

--- 按层级打印技能森林
---@param forest table 技能森林结构
function SkillTypeConfig.PrintSkillForest(forest)
    gg.log("========== 技能森林结构 ==========")

    local printed = {} -- 用table引用做key，防止重复递归打印

    local function printTree(node, level, isLast)
        local prefix = ""
        for i = 1, level - 1 do
            prefix = prefix .. "│   "
        end
        if level > 0 then
            prefix = prefix .. (isLast and "└── " or "├── ")
        end
        local skillType = node.data
        local entryMark = skillType.isEntrySkill and "🚪 " or ""
        local typeMark = skillType.skillType == 1 and "[副] " or "[主] "
        -- 用table引用判断是否已打印
        if printed[node] then
            gg.log(prefix .. entryMark .. typeMark .. node.name .. " (已在其他分支展开)")
            return
        end
        gg.log(prefix .. entryMark .. typeMark .. node.name)
        printed[node] = true
        for i, child in ipairs(node.children) do
            printTree(child, level + 1, i == #node.children)
        end
    end

    for i, tree in ipairs(forest) do
        gg.log("🌳 技能树 " .. i)
        printTree(tree, 0, true)
        gg.log("") -- 空行分隔
    end

    gg.log("========== 森林结构结束 ==========")
end

return SkillTypeConfig
