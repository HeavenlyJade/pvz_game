local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local ShopGoodConfig = require(MainStorage.config.ShopGoodConfig) ---@type ShopGoodConfig


---@class ShopGui:CustomUI
local ShopGui = ClassMgr.Class("ShopGui", CustomUI)

---@param data table
function ShopGui:OnInit(data)
    self.otherShops = data["其它页面"] ---@type string[]
    self.shopGoodsIds = data["商品"]
    self.shopGoods = {} ---@type table<string, ShopGood>
    for _, privilegeType in ipairs(data["商品"]) do
        self.shopGoods[privilegeType] = ShopGoodConfig.Get(privilegeType)
    end
    self.currentDisplayGoodIndex = 1 -- 记录当前显示物品的序号，1为第一个
    self.lastShopId = nil -- 记录上一次的shop id
end

---@param player Player
function ShopGui:S_BuildPacket(player, packet)
    packet.shopGoods = {}
    for privilegeType, shopGood in pairs(self.shopGoods) do
        local param = shopGood:GetParam(player)
        packet.shopGoods[privilegeType] = {
            affordable = shopGood.price:CanAfford(player, param),
            bought = player:GetVariable(shopGood.price.varKey),
            price = shopGood.price.priceAmount * param.power,
            priceHas = shopGood.price:GetPlayerHas(player)
        }
    end
end
function ShopGui:onViewCategory(player,evt)
    local CustomUIConfig = require(MainStorage.config.CustomUIConfig) ---@type CustomUIConfig
    local customUI = CustomUIConfig.Get(evt.shop)
    customUI:S_Open(player)
end

function ShopGui:onPurchase(player, evt)
    local shopGood = self.shopGoods[evt.shopGood]
    print("onPurchase", evt.shopGood)
    if shopGood:Buy(player) then
        self:S_Open(player)
    end
end


-----------------------客户端---------------------------

---@param node ViewButton
---@param shopGood ShopGood
---@param status ShopGoodStatus
function ShopGui:_UpdateCard(node, shopGood, status)
    node:SetChildIcon("图标", shopGood:GetIcon())
    node:Get(self.paths.IconAmount).node.Title = gg.FormatLargeNumber(shopGood:GetIconAmount())
    node:Get(self.paths.HotSale).node.Visible = shopGood.isSale
    node:Get(self.paths.Limited).node.Visible = shopGood.isLimited
    if not shopGood.price or not shopGood.price.priceType then
        gg.log("警告： 商品没有配置价格： ", shopGood.name)
        return
    end
    node:Get(self.paths.Price).node.Title = gg.FormatLargeNumber(status.price)
    node:Get(self.paths.CurrencyIcon).node.Icon = shopGood.price.priceType.icon
    node.clickCb = function (ui, button)
        self.currentDisplayGoodIndex = button.index
        self:_ShowGood(shopGood)
    end
end

---@param shopGood ShopGood
function ShopGui:_ShowGood(shopGood)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ui = self.view
    ui:Get(self.paths.BigIcon).node.Icon = shopGood:GetIcon()
    ui:Get(self.paths.BigIconAmount).node.Title = gg.FormatLargeNumber(shopGood:GetIconAmount())
    ui:Get(self.paths.Name).node.Title = shopGood.name
    ui:Get(self.paths.Desc).node.Title = shopGood.description
    local status = self.packet.shopGoods[shopGood.name] ---@type ShopGoodStatus
    local purchaseButton = ui:Get(self.paths.BuyBtn, ViewButton)
    ui:Get(self.paths.PriceIcon).node.Icon = shopGood.price.priceType.icon
    if shopGood.miniShopId then
        ui:Get(self.paths.PriceInfo).node.Title = gg.FormatLargeNumber(status.price)
        purchaseButton:SetTouchEnable(true)
    else
        ui:Get(self.paths.PriceInfo).node.Title = string.format("%s/%s",  
            gg.FormatLargeNumber(status.priceHas), gg.FormatLargeNumber(status.price))
        purchaseButton:SetTouchEnable(status.priceHas >= status.price)
    end
    purchaseButton.clickCb = function (ui, button)
        print("onPurchase", button.path)
        self:C_SendEvent("onPurchase", {
            shopGood = shopGood.name
        })
    end
end

local store = game:GetService("DeveloperStoreService")
function ShopGui:C_BuildUI(packet)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    local ui = self.view
    local paths = self.paths

    ui:Get(self.paths.MiniCoinBtn, ViewButton).clickCb = function (ui, button)
        store:MiniCoinRecharge()
    end
    self.categoryList = ui:Get(self.paths.CategoryList, ViewList, function (child, childPath)
        local c = ViewButton.New(child, ui, childPath)
        c.clickCb = function (ui, button)
            self:C_SendEvent("onViewCategory", {
                shop = self.otherShops[button.index]
            })
        end
        return c
    end) ---@type ViewList
    self.categoryList:SetElementSize(0)
    for i, shopName in ipairs(self.otherShops) do
        local child = self.categoryList:GetChild(i)
        local categoryNode = child:Get(self.paths.CategoryName)
        categoryNode.node.Title = shopName
        if shopName == self.id then
            categoryNode.node.TitleColor = ColorQuad.New(254,255,138,255)
            child.node.FillColor = ColorQuad.New(254,255,138,255)
        else
            categoryNode.node.TitleColor = ColorQuad.New(255,255,255,255)
            child.node.FillColor = ColorQuad.New(255,255,255,255)
        end
    end

    self.goodsList = ui:Get(self.paths.GoodsList, ViewList, function (child, childPath)
        local c = ViewButton.New(child, ui, childPath)
        return c
    end) ---@type ViewList
    ui:Get(self.paths.CloseBtn, ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
    self.packet = packet
    
    local index = 1
    self.goodsList:SetElementSize(0)
    for _, shopGoodId in ipairs(self.shopGoodsIds) do
        local shopGood = self.shopGoods[shopGoodId]
        self:_UpdateCard(self.goodsList:GetChild(index), shopGood, packet.shopGoods[shopGoodId])
        index = index+1
    end
    -- 检查shop id是否变化，变化则重置index
    if self.lastShopId ~= self.id then
        self.currentDisplayGoodIndex = 1
        self.lastShopId = self.id
    end
    -- 优先显示当前记录的物品序号，如果没有则显示第一个
    local idx = self.currentDisplayGoodIndex or 1
    local goodId = self.shopGoodsIds[idx]
    local good = goodId and self.shopGoods[goodId]
    if good then
        self:_ShowGood(good)
    else
        -- 显示第一个物品
        local firstGoodId = self.shopGoodsIds[1]
        if firstGoodId then
            self:_ShowGood(self.shopGoods[firstGoodId])
        end
    end
    self.view:Open()
    for i = 1, 4 do
        if _G['商城点击_货币' .. i] then
            _G['商城点击_货币' .. i] = false
        end
    end
end


return ShopGui