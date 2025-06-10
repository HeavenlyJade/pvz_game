
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers

--- 挂机点配置文件
---@class AfkSpotConfig
local AfkSpotConfig = {}
local loaded = false

local function LoadConfig()
    AfkSpotConfig.config ={
    ["主城1花园"] = {
        ["名字"] = "主城1花园",
        ["场景"] = "g0",
        ["节点名"] = {
            "副卡挂机",
            "副卡挂机_copy_2",
            "副卡挂机_copy_3",
            "副卡挂机_copy_4",
            "副卡挂机_copy_5",
            "副卡挂机_copy_6",
            "副卡挂机_copy_7",
            "副卡挂机_copy_8",
            "副卡挂机_copy_9",
            "副卡挂机_copy_10",
            "副卡挂机_copy_11",
            "副卡挂机_copy_12",
            "副卡挂机_copy_13",
            "副卡挂机_copy_14",
            "副卡挂机_copy_15",
            "副卡挂机_copy_16",
            "副卡挂机_copy_17",
            "副卡挂机_copy_18",
            "副卡挂机_copy_19",
            "副卡挂机_copy"
        },
        ["间隔时间"] = 2,
        ["模式"] = "副卡",
        ["额外互动距离"] = {
            100,
            100,
            0
        },
        ["成长速度"] = 10
    },
    ["主城1花圃"] = {
        ["名字"] = "主城1花圃",
        ["场景"] = "g0",
        ["节点名"] = {
            "副卡挂机_copy_20",
            "副卡挂机_copy_21",
            "副卡挂机_copy_22"
        },
        ["互动条件"] = Modifiers.New({
            {
                ["目标"] = "自己",
                ["条件类型"] = "VariableCondition",
                ["条件"] = {
                    ["名字"] = "解锁花圃挂机",
                    ["最小值"] = 1,
                    ["最大值"] = 100
                },
                ["动作"] = "必须",
                ["拒绝时提示"] = "高级花圃尚未开放,敬请期待"
            }
        }),
        ["间隔时间"] = 2,
        ["模式"] = "副卡",
        ["额外互动距离"] = {
            100,
            100,
            0
        },
        ["成长速度"] = 50
    }
}loaded = true
end

function AfkSpotConfig.Get(AfkSpotName)
    if not loaded then
        LoadConfig()
    end
    return AfkSpotConfig.config[AfkSpotName]
end

function AfkSpotConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return AfkSpotConfig.config
end
return AfkSpotConfig