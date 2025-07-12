local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local ShopGoodConfig = require(MainStorage.config.ShopGoodConfig) ---@type ShopGoodConfig

---@class ShopGoodStatus
---@field affordable boolean
---@field bought number
---@field price number
---@field priceHas number
---@field days number


---@class MonthlyRewards:CustomUI
local MonthlyRewards = ClassMgr.Class("MonthlyRewards", CustomUI)

---@param data table
function MonthlyRewards:OnInit(data)
    self.privilegeTypes = {} ---@type table<string, ShopGood>
    for _, privilegeType in ipairs(data["特权类型"]) do
        self.privilegeTypes[privilegeType] = ShopGoodConfig.Get(privilegeType)
    end
end

---@param player Player
function MonthlyRewards:S_BuildPacket(player, packet)
    packet.privilegeTypes = {}
    for privilegeType, shopGood in pairs(self.privilegeTypes) do
        local param = shopGood:GetParam(player)
        packet.privilegeTypes[privilegeType] = {
            affordable = shopGood.price:CanAfford(player, param),
            bought = player:GetVariable(shopGood.price.varKey),
            days = player:GetVariable(privilegeType),
            price = shopGood.price.priceAmount * param.power,
        }
    end
end

function MonthlyRewards:onPurchase(player, evt)
    local shopGood = self.privilegeTypes[evt.index]
    if shopGood:Buy(player) then
        self:S_Open(player)
    end
end
-----------------------客户端---------------------------
---@param node ViewComponent
---@param shopGood ShopGood
---@param status ShopGoodStatus
function MonthlyRewards:_UpdateCard(node, shopGood, status)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    
    local rewardList = node:Get("奖励列表背景/奖励列表", ViewList, function (child, childPath)
        local c = ViewItem.New(child, node.ui, childPath)
        return c
    end) ---@type ViewList
    local index = 1
    for itemName, amount in pairs(shopGood.rewards) do
        local itemType = ItemTypeConfig.Get(itemName)
        if itemType then
            rewardList:GetChild(index):SetItem(itemType:ToItem(amount))
            index = index + 1
        end
    end
    node:Get("权益信息框/权益介绍信息").Title = shopGood.description
    node:Get("已激活").node.Visible = status.days > 0
    node:Get("已激活/剩余时长").node.Title = string.format("剩余时间：%d天", status.days)

    local purchaseButton = node:Get("续费", ViewButton)
    purchaseButton:SetTouchEnable(status.affordable)
    if status.days > 0 then
        purchaseButton:Get("价格").node.Title = string.format("续费\n%d", status.price)
    else
        purchaseButton:Get("价格").node.Title = tostring(status.price)
    end
    purchaseButton:Get("价格图标").node.Icon = shopGood.price.priceType.icon
    purchaseButton.clickCb = function (ui, button)
        self:C_SendEvent("onPurchase", {
            index = shopGood.name
        })
    end
end

function MonthlyRewards:C_BuildUI(packet)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    self.view:Get("关闭按钮", ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
    self.packet = packet
    local ui = self.view
    for privilegeType, shopGood in pairs(self.privilegeTypes) do
        self:_UpdateCard(ui:Get(privilegeType), shopGood, packet.privilegeTypes[privilegeType])
    end
end

return MonthlyRewards