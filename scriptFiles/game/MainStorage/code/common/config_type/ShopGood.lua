local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam

---@enum ShopGoodRefreshType
local ShopGoodRefreshType = {
    NONE = "不刷新",
    DAILY = "每日",
    WEEKLY = "每周",
    MONTHLY = "每月"
}

---@enum ShopGoodType
local ShopGoodType = {
    NONE = "无类型",
    VARIABLE = "变量",
    ITEM = "物品",
    EVENT = "事件"
}

---@class Price:Class
local Price = ClassMgr.Class("Price")

---@param data table
function Price:OnInit(data)
    self.varKey = data["varKey"]
    self.adMode = data["广告模式"]
    self.adCount = data["广告次数"]
    self.priceType = ItemTypeConfig.Get(data["价格类型"]) ---@type ItemType
    self.priceAmount = data["价格数量"]
end

---@param player Player
---@param param CastParam
function Price:CanAfford(player, param)
    if self.priceType then
        if not player.bag:HasItems({[self.priceType] = self.priceAmount * param.power}) then
            return false, "货币不足"
        end
    end
    return true
end

---@param player Player
---@param param CastParam
function Price:GetPlayerHas(player)
    if self.priceType then
        return player.bag:GetItemAmount(self.priceType)
    end
    return 0
end

---@param player Player
function Price:Pay(player, param)
    if self.priceType then
        player.bag:RemoveItems({[self.priceType] = self.priceAmount * param.power})
    end
end

---@class ShopGood:Class
local ShopGood = ClassMgr.Class("ShopGood")

---@param data table
function ShopGood:OnInit(data)
    self.name = data["商品名"]
    self.description = data["商品描述"]
    self.price = Price.New(data["价格"]) ---@type Price
    self.dailyResetFreeCount = data["每日重置免费次数"] or false
    self.limitedTime = data["限时"] or false
    self.rewards = data["获得物品"] or {} ---@type table<string, number>
    self.commands = data["执行指令"] or {}
    self.prizePool = data["奖池"]
    self.icon = data["图标复写"]
    self.iconAmount = data["图标数量复写"]
    self.isSale = data["热卖"]
    self.isLimited = data["限定"]
    self.modifiers = data["购买条件"] ---@type Modifiers
end

function ShopGood:GetIcon()
    if self.icon then
        return self.icon
    end
    if self.rewards then
        for k, _ in pairs(self.rewards) do
            local itemType = ItemTypeConfig.Get(k)
            if itemType then
                return itemType.icon
            end
        end
    end
    return nil
end


function ShopGood:GetIconAmount()
    if self.iconAmount and self.iconAmount ~= 0 then
        return self.iconAmount
    end
    if self.rewards then
        for _, v in pairs(self.rewards) do
            return v
        end
    end
    return nil
end

---@return CastParam
function ShopGood:GetParam(player)
    if self.modifiers then
        return self.modifiers:Check(player, player)
    end
    return CastParam.New()
end

---@param player Player
function ShopGood:CanBuy(player, param)
    if param.cancelled then
        return false, "条件取消"
    end
    local canAfford, reason = self.price:CanAfford(player, param)
    if not canAfford then
        return false, reason
    end
    if player:GetVariable(self.price.varKey, 0) > 0 then
        return false, "已购买"
    end
    return true
end

---@param player Player
function ShopGood:Buy(player)
    local param = self:GetParam(player)
    local canBuy, reason = self:CanBuy(player, param)
    if not canBuy then
        player:SendHoverText("购买%s失败：%s", self.name, reason)
        return false
    end
    self.price:Pay(player)
    if self.price.varKey then
        player:AddVariable(self.price.varKey, 1)
    end
    for itemName, amount in pairs(self.rewards) do
        local itemType = ItemTypeConfig.Get(itemName)
        if itemType then
            player.bag:GiveItem(itemType:ToItem(amount))
        end
    end
    for _, command in ipairs(self.commands) do
        player:ExecuteCommand(command)
    end

    return true
end

function ShopGood:GetToStringParams()
    return {
        name = self.name
    }
end

return ShopGood
