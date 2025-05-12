
    
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local TagType      = require(MainStorage.code.common.config_type.tags.TagType)    ---@type TagType
--- 词条配置文件
---@class TagTypeConfig


--默认数值模板
local TagTypeConfig= { config = {
    ["词条2"] = TagType.New({
        ["名字"] = "词条2",
        ["最高等级"] = 1,
        ["功能"] = {
            {
                ["影响魔法关键字"] = "",
                ["即将击杀"] = false,
                ["要求元素类型"] = 0,
                ["增伤"] = 0,
                ["增加暴击率"] = 0,
                ["增加暴击伤害"] = 2,
                ["释放魔法继承威力"] = false,
                ["类型"] = "DamageTagHandler",
                ["打印信息"] = false,
                ["m_trigger"] = "攻击时",
                ["优先级"] = 5,
                ["冷却"] = 0,
                ["每级增强"] = 1,
                ["几率"] = 0
            }
        }
    })
}}

---@param tagTypeName string
---@return TagType
function TagTypeConfig.Get(tagTypeName)
    return TagTypeConfig.config[tagTypeName]
end

---@return TagType[]
function TagTypeConfig.GetAll()
    return TagTypeConfig.config
end
return TagTypeConfig
