local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local ShopGood      = require(MainStorage.code.common.config_type.ShopGood)    ---@type ShopGood
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers

--- ShopGood配置文件
---@class ShopGoodConfig
local ShopGoodConfig = {}
local loaded = false

local function LoadConfig()
    ShopGoodConfig.config ={
    ["基金卡"] = ShopGood.New({
        ["商品名"] = "基金卡",
        ["商品描述"] = [[◆每日领取 1万阳光
◆每日领取 1千金币
◆每日领取 昼夜加速卡
◆每日挂机增益延长]],
        ["价格"] = {
            ["varKey"] = "shop_基金卡",
            ["广告模式"] = "不可看广告",
            ["广告次数"] = 0,
            ["价格类型"] = "水晶",
            ["价格数量"] = 3000
        },
        ["每日重置免费次数"] = false,
        ["限时"] = false,
        ["获得物品"] = {
            ["仙人掌"] = 20,
            ["地刺碎片"] = 80,
            ["星星果"] = 100
        },
        ["执行指令"] = {
            [[var {"变量名":"基金卡","值":"30"}]],
            [[title {"信息":"已成功购买了30天基金卡！"}]]
        },
        ["奖池"] = nil
    }),
    ["特权卡"] = ShopGood.New({
        ["商品名"] = "特权卡",
        ["商品描述"] = [[◆每日领取 1万阳光
◆每日领取 1千金币
◆每日领取 昼夜加速卡
◆每日挂机增益延长]],
        ["价格"] = {
            ["varKey"] = "shop_特权卡",
            ["广告模式"] = "不可看广告",
            ["广告次数"] = 0,
            ["价格类型"] = "水晶",
            ["价格数量"] = 3000
        },
        ["购买条件"] = Modifiers.New({
            {
                ["目标"] = "自己",
                ["条件类型"] = "HealthCondition",
                ["条件"] = {
                    ["百分比"] = true,
                    ["最小值"] = 0,
                    ["最大值"] = 100
                },
                ["动作"] = "威力乘以",
                ["数量"] = "0.5"
            }
        }),
        ["每日重置免费次数"] = false,
        ["限时"] = false,
        ["获得物品"] = {
            ["仙人掌"] = 20,
            ["地刺碎片"] = 80,
            ["星星果"] = 100
        },
        ["执行指令"] = {
            [[var {"变量名":"特权卡","值":"30"}]],
            [[title {"信息":"已成功购买了30天基金卡！"}]]
        },
        ["奖池"] = nil
    })
}loaded = true
end

---@param ShopGoodName string
---@return ShopGood
function ShopGoodConfig.Get(ShopGoodName)
    if not loaded then
        LoadConfig()
    end
    return ShopGoodConfig.config[ShopGoodName]
end

---@return ShopGood[]
function ShopGoodConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return ShopGoodConfig.config
end
return ShopGoodConfig
