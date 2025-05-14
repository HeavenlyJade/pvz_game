local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobType      = require(MainStorage.code.common.config_type.MobType)    ---@type MobType

--- 怪物配置文件
---@class MobTypeConfig
local MobTypeConfig = {}
local loaded = false

local function LoadConfig()
    MobTypeConfig.config ={
    ["野人"] = MobType.New({
        ["怪物ID"] = "野人",
        ["显示名"] = "岩浆徘行者",
        ["描述"] = "地心魔物，步履熔岩，所过皆烬",
        ["尺寸"] = {
            0,
            0
        },
        ["模型"] = "sandboxSysId://entity/100063/body.omod",
        ["是首领"] = true,
        ["基础等级"] = 26,
        ["属性公式"] = {
            ["攻击"] = "(2^(LVL/10))*(10*LVL*1*1.13*20)^1.1",
            ["生命"] = "(2^(LVL/10))*(10*LVL*1*1.13*20)^1.1",
            ["速度"] = "50 "
        },
        ["图鉴击杀数"] = 146,
        ["图鉴完成奖励"] = nil,
        ["图鉴完成奖励数量"] = 50,
        ["拥有血条"] = true
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
