local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg


--- 商品配置文件
---@class ShopConfig
local ShopConfig = {}
local loaded = false

local function LoadConfig()
    ShopConfig.config ={
    ["抽奖1"] = {
        ["商品名"] = "抽奖1",
        ["价格"] = {
            ["varKey"] = "daily_shop_抽奖1",
            ["广告模式"] = "不可看广告",
            ["广告次数"] = 0,
            ["价格类型"] = nil,
            ["价格数量"] = 10
        },
        ["购买类型"] = "Roulette",
        ["每日重置免费次数"] = true,
        ["奖池"] = {
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
            },
            ["name"] = "普通宝石",
            ["hideFlags"] = "None"
        },
        ["限时"] = true,
        ["活动开始时间"] = {
            ["ticks"] = 638784576000000000
        },
        ["活动结束时间"] = {
            ["ticks"] = 638784578400000000
        }
    },
    ["芯片"] = {
        ["商品名"] = "芯片",
        ["价格"] = {
            ["varKey"] = "shop_芯片",
            ["广告模式"] = "不可看广告",
            ["广告次数"] = 0,
            ["价格类型"] = nil,
            ["价格数量"] = 10
        },
        ["购买类型"] = "Item",
        ["每日重置免费次数"] = false,
        ["获得物品"] = nil,
        ["获得物品数量"] = 10,
        ["限时"] = false
    }
}loaded = true
end

---@param shopName string
---@return Shop
function ShopConfig.Get(shopName)
    if not loaded then
        LoadConfig()
    end
    return ShopConfig.config[shopName]
end

---@return Shop[]
function ShopConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return ShopConfig.config
end
return ShopConfig
