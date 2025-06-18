
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI

--- ConfigSection配置文件
---@class CustomUIConfig
local CustomUIConfig = {}
local loaded = false

local function LoadConfig()
    CustomUIConfig.config ={
    ["在线奖励"] = CustomUI.Load({
        ["UI名"] = "OnlineRewards",
        ["奖励物品"] = {
            {
                ["在线时间"] = 0,
                ["物品"] = "仙人掌",
                ["数量"] = 30
            },
            {
                ["在线时间"] = 0,
                ["物品"] = "仙人掌碎片",
                ["数量"] = 30
            }
        },
        ["ID"] = "在线奖励"
    }),
    ["月卡"] = CustomUI.Load({
        ["UI名"] = "MonthlyRewards",
        ["特权类型"] = {
            "基金卡",
            "特权卡"
        },
        ["ID"] = "月卡"
    })
}loaded = true
end

---@param name string
---@return CustomUI
function CustomUIConfig.Get(name)
    if not loaded then
        LoadConfig()
    end
    return CustomUIConfig.config[name]
end

---@return CustomUI[]
function CustomUIConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return CustomUIConfig.config
end
return CustomUIConfig
