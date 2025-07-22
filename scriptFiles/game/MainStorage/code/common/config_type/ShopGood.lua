local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
local Price = require(MainStorage.code.common.config_type.Price) ---@type Price
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
local MiniShopManager = require(MainStorage.code.server.bag.MiniShopManager) ---@type MiniShopManager

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


---@class ShopGood:Class
local ShopGood = ClassMgr.Class("ShopGood")

---@param data table
function ShopGood:OnInit(data)
    self.name = data["商品名"]
    self.description = data["商品描述"]
    self.price = Price.New(data["价格"]) ---@type Price
    self.dailyResetFreeCount = data["每日重置免费次数"] or false
    self.miniShopId = data["迷你商品ID"]
    if self.miniShopId then
        if self.miniShopId == 0 then
            self.miniShopId = nil
        else
            MiniShopManager.miniId2ShopGood[self.miniShopId] = self
        end
    end
    self.limitedTime = data["限时"] or false
    self.limitedCount = data["限购次数"] or 0
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
    if not self.miniShopId then
        local canAfford, reason = self.price:CanAfford(player, param)
        if not canAfford then
            return false, reason
        end
        if self.limitedCount > 0 and player:GetVariable(self.price.varKey, 0) > self.limitedCount then
            return false, "已购买"
        end
    end
    return true
end

---@param player Player
function ShopGood:Buy(player)
    local param = self:GetParam(player)
    if param.cancelled then
        player:SendHoverText("购买%s失败：条件取消", self.name)
        return false
    end
    if self.miniShopId then
        player:SendEvent("ViewMiniGood", {
            goodId = self.miniShopId,
            desc = self.description,
            amount = 1
        })
        return
    end
    local canBuy, reason = self:CanBuy(player, param)
    if not canBuy then
        player:SendHoverText("购买%s失败：%s", self.name, reason)
        return false
    end
    self.price:Pay(player, param)
    self:Give(player)
    return true
end

function ShopGood:Give(player)
    gg.log(string.format("%s %d 购买了%s", player.name, player.uin, self.name))
    if self.price.varKey then
        player:AddVariable(self.price.varKey, 1)
    end
    
    -- 构建获得物品的提示信息
    local rewardItems = {}
    for itemName, amount in pairs(self.rewards) do
        local itemType = ItemTypeConfig.Get(itemName)
        if itemType then
            player.bag:GiveItem(itemType:ToItem(amount), "商品_" .. self.name)
            table.insert(rewardItems, string.format("%s x%d", itemType.name, amount))
        end
    end
    
    -- 显示购买成功提示
    if #rewardItems > 0 then
        player:SendHoverText("购买成功！获得：%s", table.concat(rewardItems, "、"))
    else
        player:SendHoverText("购买成功！")
    end
    
    for _, command in ipairs(self.commands) do
        player:ExecuteCommand(command)
    end
end

function ShopGood:GetToStringParams()
    return {
        name = self.name
    }
end

return ShopGood