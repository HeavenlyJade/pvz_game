
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers

--- 挂机点配置文件
---@class AfkSpotConfig
local AfkSpotConfig = {}
local loaded = false

local function LoadConfig()
    AfkSpotConfig.config ={
    ["挂机点"] = {
        ["名字"] = "挂机点",
        ["场景"] = "g0",
        ["节点名"] = {
            "guaji1"
        },
        ["间隔时间"] = 10,
        ["定时释放魔法"] = {
            {
                ["魔法"] = "获得物品魔法",
                ["复写参数"] = {
                    ["objectName"] = "获得物品魔法",
                    ["paramName"] = "基础数量",
                    ["value"] = 30
                }
            }
        }
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