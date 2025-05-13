
    
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg

local Lottery      = require(MainStorage.code.server.shop.Lottery)    ---@type Lottery
--- 抽奖配置文件
---@class LotteryConfig
local LotteryConfig={ config = {
    ["普通宝石"] = Lottery.New({
        ["奖池名"] = "普通宝石",
        ["普通品级概率"] = 50,
        ["稀有品级概率"] = 20,
        ["史诗品级概率"] = 10,
        ["传说品级概率"] = 0.5,
        ["神话品级概率"] = 0,
        ["稀有保底次数"] = 0,
        ["史诗保底次数"] = 0,
        ["传说保底次数"] = 30,
        ["神话保底次数"] = 0,
        ["普通品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["稀有品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["史诗品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["传说品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        }
    }),
    ["神锋现世"] = Lottery.New({
        ["奖池名"] = "神锋现世",
        ["普通品级概率"] = 50,
        ["稀有品级概率"] = 20,
        ["史诗品级概率"] = 10,
        ["传说品级概率"] = 0.5,
        ["神话品级概率"] = 0,
        ["稀有保底次数"] = 0,
        ["史诗保底次数"] = 0,
        ["传说保底次数"] = 30,
        ["神话保底次数"] = 0,
        ["普通品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["稀有品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["史诗品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["传说品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        }
    }),
    ["试手寻锋"] = Lottery.New({
        ["奖池名"] = "试手寻锋",
        ["普通品级概率"] = 50,
        ["稀有品级概率"] = 20,
        ["史诗品级概率"] = 10,
        ["传说品级概率"] = 0.5,
        ["神话品级概率"] = 0,
        ["稀有保底次数"] = 0,
        ["史诗保底次数"] = 0,
        ["传说保底次数"] = 30,
        ["神话保底次数"] = 0,
        ["普通品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["稀有品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["史诗品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        },
        ["传说品级"] = {
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            },
            {
                ["itemType"] = nil,
                ["weight"] = 10,
                ["itemCountMin"] = 1,
                ["itemCountMax"] = 10
            }
        }
    })
}}

---@param lotteryName string
---@return Lottery
function LotteryConfig.Get(lotteryName)
    return LotteryConfig.config[lotteryName]
end

---@return Lottery[]
function LotteryConfig.GetAll()
    return LotteryConfig.config
end
return LotteryConfig
