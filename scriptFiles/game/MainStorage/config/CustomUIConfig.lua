local MainStorage = game:GetService('MainStorage')
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local CustomUI = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI

--- ConfigSection配置文件
---@class CustomUIConfig
local CustomUIConfig = {}
local loaded = false

local function LoadConfig()
    CustomUIConfig.config ={
    ["第一章"] = CustomUI.Load({
        ["UI名"] = "LevelSelect",
        ["解锁自动重新匹配变量"] = "可自动重匹配",
        ["未解锁重新匹配信息"] = "尚未解锁重新匹配功能！",
        ["关卡"] = {
            "1-1（新手点我）",
            "1-2（50级）",
            "1-3（2000级）",
            "1-4（20000级）"
        },
        ["ID"] = "第一章"
    }),
    ["礼包"] = CustomUI.Load({
        ["UI名"] = "ShopGui",
        ["优先级"] = 1,
        ["其它页面"] = {
            "礼包",
            "道具",
            "水晶"
        },
        ["商品"] = {
            "新手大礼包",
            "新手进阶礼包",
            "魅惑菇碎片",
            "星星果碎片",
            "仙人掌碎片",
            "寒冰射手礼包",
            "小喷菇礼包",
            "椰子炮碎片",
            "火爆辣椒碎片",
            "窝瓜碎片",
            "菜问碎片",
            "辣椒投手碎片",
            "钢铁地刺碎片"
        },
        ["ID"] = "礼包"
    }),
    ["水晶"] = CustomUI.Load({
        ["UI名"] = "ShopGui",
        ["优先级"] = 10,
        ["其它页面"] = {
            "礼包",
            "道具",
            "水晶"
        },
        ["商品"] = {
            "水晶x10",
            "水晶x250",
            "水晶x980",
            "水晶x5000",
            "能量豆补给包",
            "金币补给包",
            "阳光补给包"
        },
        ["ID"] = "水晶"
    }),
    ["道具"] = CustomUI.Load({
        ["UI名"] = "ShopGui",
        ["优先级"] = 1,
        ["其它页面"] = {
            "礼包",
            "道具",
            "水晶"
        },
        ["商品"] = {
            "单张副卡抽奖券",
            "单张限定抽奖券",
            "每周副卡抽奖券",
            "每周限定抽奖券",
            "每月副卡抽奖券",
            "每月限定抽奖券",
            "限定抽奖券",
            "主卡寒冰射手",
            "主卡小喷菇",
            "副卡仙人掌",
            "副卡抽奖券",
            "副卡椰子炮",
            "副卡菜问"
        },
        ["ID"] = "道具"
    }),
    ["抽卡页面"] = CustomUI.Load({
        ["UI名"] = "RollCardsGui",
        ["奖池"] = "副卡奖池",
        ["需求素材"] = "副卡抽奖券",
        ["缺少补充价格"] = {
            ["varKey"] = "",
            ["广告模式"] = "不可看广告",
            ["广告次数"] = 0,
            ["价格类型"] = "水晶",
            ["价格数量"] = 60
        },
        ["购买抽奖券点击指令"] = {
            [[viewUI {"界面ID":"礼包"} ]]
        },
        ["ID"] = "抽卡页面"
    }),
    ["在线奖励"] = CustomUI.Load({
        ["UI名"] = "OnlineRewards",
        ["奖励物品"] = {
            {
                ["在线时间"] = 60,
                ["物品"] = "阳光",
                ["数量"] = 4000
            },
            {
                ["在线时间"] = 240,
                ["物品"] = "金币",
                ["数量"] = 100
            },
            {
                ["在线时间"] = 360,
                ["物品"] = "阳光",
                ["数量"] = 8000
            },
            {
                ["在线时间"] = 600,
                ["物品"] = "金币",
                ["数量"] = 300
            },
            {
                ["在线时间"] = 1080,
                ["物品"] = "SR碎片",
                ["数量"] = 3
            }
        },
        ["重置周期"] = "每日",
        ["ID"] = "在线奖励"
    }),
    ["排行榜页面"] = CustomUI.Load({
        ["UI名"] = "RankingGui",
        ["ID"] = "排行榜页面"
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
