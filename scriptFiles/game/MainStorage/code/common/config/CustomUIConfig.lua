
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI

--- ConfigSection配置文件
---@class CustomUIConfig
local CustomUIConfig = {}
local loaded = false

local function LoadConfig()
    CustomUIConfig.config ={
    ["第一章"] = CustomUI.Load({
        ["UI名"] = "LevelSelect",
        ["关卡"] = {
            "1-1（1~100级）",
            "1-2（100~200级）",
            "1-3（200级~300级）",
            "1-4（300级~400级）",
            "1-5（400级~500级）"
        },
        ["ID"] = "第一章"
    }),
    ["礼包"] = CustomUI.Load({
        ["UI名"] = "ShopGui",
        ["优先级"] = 1,
        ["其它页面"] = {
            "礼包",
            "道具"
        },
        ["商品"] = {
            "副卡大礼包"
        },
        ["ID"] = "礼包"
    }),
    ["道具"] = CustomUI.Load({
        ["UI名"] = "ShopGui",
        ["优先级"] = 1,
        ["其它页面"] = {
            "礼包",
            "道具"
        },
        ["商品"] = {
            "昼夜加速卡",
            "挂机加速卡"
        },
        ["ID"] = "道具"
    }),
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
