local MainStorage = game:GetService('MainStorage')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemType = require(MainStorage.code.common.config_type.ItemType) ---@type ItemType

--- 物品类型配置文件
---@class ItemTypeConfig
---@field Get fun(itemTypeId: string):ItemType 获取物品类型
---@field GetAll fun():ItemType[] 获取所有物品类型
local ItemTypeConfig = {}
local loaded = false
local function LoadConfig()
    ItemTypeConfig.config ={
    ["模板"] = ItemType.New({
        ["名字"] = "模板",
        ["描述"] = "aaaaaaaaaaaaaaaaaaa",
        ["额外战力"] = 800,
        ["强化倍率"] = 0,
        ["强化材料增加倍率"] = 0,
        ["最大强化等级"] = 0,
        ["属性"] = {
            ["攻击"] = 50
        },
        ["图鉴完成奖励数量"] = 0,
        ["图鉴高级完成奖励数量"] = 0,
        ["装备格子"] = 0,
        ["售出价格"] = 0,
        ["在背包里显示"] = true,
        ["是货币"] = false
    }),
    ["物品"] = ItemType.New({
        ["名字"] = "物品",
        ["描述"] = "aaaaaaaaaaaaaaaaaaa",
        ["品级"] = "传说",
        ["额外战力"] = 0,
        ["强化倍率"] = 0.1,
        ["强化素材"] = {
            ["物品"] = 20
        },
        ["强化材料增加倍率"] = 30,
        ["最大强化等级"] = 10,
        ["属性"] = {
            ["攻击"] = 50
        },
        ["标签"] = {
            "火焰"
        },
        ["图鉴完成奖励"] = "物品",
        ["图鉴完成奖励数量"] = 30,
        ["图鉴高级完成奖励数量"] = 80,
        ["装备格子"] = 1,
        ["可进阶为"] = "物品",
        ["进阶材料"] = {
            ["物品"] = 30
        },
        ["可售出为"] = "物品",
        ["售出价格"] = 50,
        ["在背包里显示"] = true,
        ["是货币"] = true,
        ["货币序号"] = 1,
        ["获得词条"] = {
            "词条2"
        }
    }),
    ["体力"] = ItemType.New({
        ["名字"] = "体力",
        ["额外战力"] = 0,
        ["强化倍率"] = 0,
        ["强化材料增加倍率"] = 0,
        ["最大强化等级"] = 0,
        ["图鉴完成奖励数量"] = 0,
        ["图鉴高级完成奖励数量"] = 0,
        ["装备格子"] = 0,
        ["售出价格"] = 0,
        ["在背包里显示"] = true,
        ["是货币"] = true,
        ["货币序号"] = 3
    }),
    ["水晶"] = ItemType.New({
        ["名字"] = "水晶",
        ["额外战力"] = 0,
        ["强化倍率"] = 0,
        ["强化材料增加倍率"] = 0,
        ["最大强化等级"] = 0,
        ["图鉴完成奖励数量"] = 0,
        ["图鉴高级完成奖励数量"] = 0,
        ["装备格子"] = 0,
        ["售出价格"] = 0,
        ["在背包里显示"] = true,
        ["是货币"] = true,
        ["货币序号"] = 3
    }),
    ["金币"] = ItemType.New({
        ["名字"] = "金币",
        ["额外战力"] = 0,
        ["强化倍率"] = 0,
        ["强化材料增加倍率"] = 0,
        ["最大强化等级"] = 0,
        ["图鉴完成奖励数量"] = 0,
        ["图鉴高级完成奖励数量"] = 0,
        ["装备格子"] = 0,
        ["售出价格"] = 0,
        ["在背包里显示"] = true,
        ["是货币"] = true,
        ["货币序号"] = 1
    }),
    ["阳光"] = ItemType.New({
        ["名字"] = "阳光",
        ["额外战力"] = 0,
        ["强化倍率"] = 0,
        ["强化材料增加倍率"] = 0,
        ["最大强化等级"] = 0,
        ["图鉴完成奖励数量"] = 0,
        ["图鉴高级完成奖励数量"] = 0,
        ["装备格子"] = 0,
        ["售出价格"] = 0,
        ["在背包里显示"] = true,
        ["是货币"] = true,
        ["货币序号"] = 2
    })
}loaded = true
    gg.log("LoadConfig", ItemTypeConfig.config)
    loaded = true
end

---@param itemType string
---@return ItemType
function ItemTypeConfig.Get(itemType)
    if not loaded then
        LoadConfig()
    end
    return ItemTypeConfig.config[itemType]
end

---@return ItemType[]
function ItemTypeConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return ItemTypeConfig.config
end

return ItemTypeConfig
