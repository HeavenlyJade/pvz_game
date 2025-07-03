local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig


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
return Price