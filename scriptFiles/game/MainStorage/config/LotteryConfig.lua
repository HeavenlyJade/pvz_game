local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Lottery      = require(MainStorage.code.common.config_type.Lottery)    ---@type Lottery

--- 抽奖配置文件
---@class LotteryConfig
local LotteryConfig = {}
local loaded = false

local function LoadConfig()
    LotteryConfig.config ={
    ["SR副卡奖池"] = Lottery.New({
        ["奖池名"] = "SR副卡奖池",
        ["普通品级概率"] = 0,
        ["稀有品级概率"] = 0,
        ["史诗品级概率"] = 10,
        ["传说品级概率"] = 0,
        ["神话品级概率"] = 0,
        ["稀有保底次数"] = 0,
        ["史诗保底次数"] = 0,
        ["传说保底次数"] = 0,
        ["神话保底次数"] = 0,
        ["史诗品级"] = {
            {
                ["itemType"] = "仙人掌碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "火爆辣椒碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "菜问碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "辣椒投手碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "钢铁地刺碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "仙人掌",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "火爆辣椒",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "菜问",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "辣椒投手",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "钢铁地刺",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            }
        }
    }),
    ["副卡奖池"] = Lottery.New({
        ["奖池名"] = "副卡奖池",
        ["普通品级概率"] = 45,
        ["稀有品级概率"] = 35,
        ["史诗品级概率"] = 15,
        ["传说品级概率"] = 5,
        ["神话品级概率"] = 0,
        ["稀有保底次数"] = 10,
        ["史诗保底次数"] = 60,
        ["传说保底次数"] = 100,
        ["神话保底次数"] = 0,
        ["普通品级"] = {
            {
                ["itemType"] = "阳光",
                ["weight"] = 20,
                ["itemCountMin"] = 500,
                ["itemCountMax"] = 5000
            }
        },
        ["稀有品级"] = {
            {
                ["itemType"] = "地刺碎片",
                ["weight"] = 80,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "坚果碎片",
                ["weight"] = 80,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "椰子炮碎片",
                ["weight"] = 80,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "樱桃炸弹碎片",
                ["weight"] = 80,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "豌豆射手碎片",
                ["weight"] = 80,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "地刺",
                ["weight"] = 20,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "坚果",
                ["weight"] = 20,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "椰子炮",
                ["weight"] = 20,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "樱桃炸弹",
                ["weight"] = 20,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "豌豆射手",
                ["weight"] = 20,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            }
        },
        ["史诗品级"] = {
            {
                ["itemType"] = "仙人掌碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "火爆辣椒碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "菜问碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "辣椒投手碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "钢铁地刺碎片",
                ["weight"] = 85,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "仙人掌",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "火爆辣椒",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "菜问",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "辣椒投手",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "钢铁地刺",
                ["weight"] = 15,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            }
        },
        ["传说品级"] = {
            {
                ["itemType"] = "星星果碎片",
                ["weight"] = 88,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "窝瓜碎片",
                ["weight"] = 88,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "魅惑菇碎片",
                ["weight"] = 88,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "星星果",
                ["weight"] = 12,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "窝瓜",
                ["weight"] = 12,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "魅惑菇",
                ["weight"] = 12,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            }
        }
    }),
    ["随机SR碎片"] = Lottery.New({
        ["奖池名"] = "随机SR碎片",
        ["普通品级概率"] = 0,
        ["稀有品级概率"] = 10,
        ["史诗品级概率"] = 0,
        ["传说品级概率"] = 0,
        ["神话品级概率"] = 0,
        ["稀有保底次数"] = 0,
        ["史诗保底次数"] = 0,
        ["传说保底次数"] = 0,
        ["神话保底次数"] = 0,
        ["稀有品级"] = {
            {
                ["itemType"] = "地刺碎片",
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "坚果碎片",
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "樱桃炸弹碎片",
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            },
            {
                ["itemType"] = "豌豆射手碎片",
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 1
            }
        }
    })
}loaded = true
end

---@param lotteryName string
---@return Lottery
function LotteryConfig.Get(lotteryName)
    if not loaded then
        LoadConfig()
    end
    return LotteryConfig.config[lotteryName]
end

---@return Lottery[]
function LotteryConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return LotteryConfig.config
end
return LotteryConfig
