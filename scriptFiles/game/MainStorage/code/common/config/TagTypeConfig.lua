local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local TagType      = require(MainStorage.code.common.config_type.tags.TagType)    ---@type TagType

--- 词条配置文件
---@class TagTypeConfig
local TagTypeConfig = {}
local loaded = false

local function LoadConfig()
    TagTypeConfig.config ={
    ["词条2"] = TagType.New({
        ["名字"] = "词条2",
        ["最高等级"] = 1,
        ["描述"] = "有[1.几率]%几率,伤害+[1.增伤]%， 并造成[50:0.2]伤害",
        ["功能"] = {
            {
                ["影响魔法关键字"] = "",
                ["即将击杀"] = false,
                ["要求元素类型"] = 0,
                ["增伤"] = 30,
                ["增加暴击率"] = 0,
                ["增加暴击伤害"] = 2,
                ["属性增伤倍率"] = 1,
                ["释放魔法继承威力"] = false,
                ["释放魔法威力增加"] = 0,
                ["类型"] = "DamageTagHandler",
                ["打印信息"] = false,
                ["m_trigger"] = "攻击时",
                ["优先级"] = 5,
                ["冷却"] = 0,
                ["每级增强"] = 1,
                ["几率"] = 20,
                ["升级增加数值"] = {
                    {
                        ["paramName"] = "增伤",
                        ["number"] = 1
                    }
                }
            }
        }
    }),
    ["豌豆射手_射速1"] = TagType.New({
        ["名字"] = "豌豆射手_射速1",
        ["最高等级"] = 999,
        ["描述"] = "所有豌豆射手的射速增加",
        ["详细属性"] = "射速 +[1.修改数值.1]%",
        ["功能"] = {
            {
                ["影响魔法关键字"] = "豌豆射手",
                ["威力增加"] = 0,
                ["威力增加表达式"] = "",
                ["取消"] = false,
                ["修改数值"] = {
                    {
                        ["objectName"] = "伤害魔法",
                        ["paramName"] = "冷却加速",
                        ["paramValue"] = {
                            ["倍率"] = 5,
                            ["增加类型"] = 0,
                            ["乘以基础数值"] = false
                        },
                        ["isAlways"] = false
                    }
                },
                ["修改数值倍率"] = 1,
                ["释放魔法继承威力"] = false,
                ["释放魔法威力增加"] = 0,
                ["类型"] = "SpellTagHandler",
                ["打印信息"] = false,
                ["m_trigger"] = "释放魔法时",
                ["优先级"] = 5,
                ["冷却"] = 0,
                ["每级增强"] = 1,
                ["几率"] = 0,
                ["升级增加数值"] = {
                    {
                        ["paramName"] = "修改数值倍率",
                        ["number"] = 1
                    }
                }
            }
        }
    }),
    ["豌豆射手_攻击1"] = TagType.New({
        ["名字"] = "豌豆射手_攻击1",
        ["最高等级"] = 999,
        ["描述"] = "所有豌豆射手的伤害增加",
        ["详细属性"] = "伤害 +[1.属性增伤.1]",
        ["功能"] = {
            {
                ["影响魔法关键字"] = "豌豆射手",
                ["即将击杀"] = false,
                ["要求元素类型"] = 0,
                ["增伤"] = 20,
                ["增加暴击率"] = 0,
                ["增加暴击伤害"] = 0,
                ["属性增伤"] = {
                    {
                        ["倍率"] = 5,
                        ["增加类型"] = 0,
                        ["乘以基础数值"] = false
                    }
                },
                ["属性增伤倍率"] = 1,
                ["释放魔法继承威力"] = false,
                ["释放魔法威力增加"] = 0,
                ["类型"] = "DamageTagHandler",
                ["打印信息"] = false,
                ["m_trigger"] = "攻击时",
                ["优先级"] = 5,
                ["冷却"] = 0,
                ["每级增强"] = 1,
                ["几率"] = 0,
                ["升级增加数值"] = {
                    {
                        ["paramName"] = "属性增伤倍率",
                        ["number"] = 1
                    }
                }
            }
        }
    }),
    ["豌豆射手_生命1"] = TagType.New({
        ["名字"] = "豌豆射手_生命1",
        ["最高等级"] = 999,
        ["描述"] = "所有植物生命增加",
        ["详细属性"] = "生命+[1.增加]",
        ["功能"] = {
            {
                ["属性"] = "生命",
                ["增加"] = 20,
                ["百分比"] = false,
                ["类型"] = "AttributeTagHandler",
                ["打印信息"] = false,
                ["m_trigger"] = "生命",
                ["优先级"] = 5,
                ["冷却"] = 0,
                ["每级增强"] = 1,
                ["几率"] = 0,
                ["升级增加数值"] = {
                    {
                        ["paramName"] = "增加",
                        ["number"] = 1
                    }
                }
            }
        }
    })
}loaded = true
end

---@param tagTypeName string
---@return TagType
function TagTypeConfig.Get(tagTypeName)
    if not loaded then
        LoadConfig()
    end
    return TagTypeConfig.config[tagTypeName]
end

---@return TagType[]
function TagTypeConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return TagTypeConfig.config
end
return TagTypeConfig
