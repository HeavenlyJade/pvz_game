local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local ShopGoodConfig = require(MainStorage.code.common.config.ShopGoodConfig) ---@type ShopGoodConfig


---@class ShopGui:CustomUI
local ShopGui = ClassMgr.Class("ShopGui", CustomUI)

---@param data table
function ShopGui:OnInit(data)
    self.otherShops = data["其它页面"] ---@type string[]
    self.shopGoods = {} ---@type table<string, ShopGood>
    for _, privilegeType in ipairs(data["商品"]) do
        self.shopGoods[privilegeType] = ShopGoodConfig.Get(privilegeType)
    end
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
    local CustomUIConfig = require(MainStorage.code.common.config.CustomUIConfig) ---@type CustomUIConfig
    local customUI = CustomUIConfig.Get(evt.shop)
    customUI:S_Open(player)
end

function ShopGui:onPurchase(player, evt)
    local shopGood = self.shopGoods[evt.shopGood]
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
    node:Get("图标数量").node.Title = tostring(shopGood:GetIconAmount())
    node:Get("热卖").node.Visible = shopGood.isSale
    node:Get("限定").node.Visible = shopGood.isLimited
    if not shopGood.price or not shopGood.price.priceType then
        gg.log("警告： 商品没有配置价格： ", shopGood.name)
        return
    end
    node:Get("价格").node.Title = tostring(status.price)
    node:Get("货币图标").node.Icon = shopGood.price.priceType.icon
    node.clickCb = function (ui, button)
        self:_ShowGood(shopGood)
    end
end

---@param shopGood ShopGood
function ShopGui:_ShowGood(shopGood)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ui = self.view
    ui:Get("商城主背景/物品大图标背景/物品大图标").node.Icon = shopGood:GetIcon()
    ui:Get("商城主背景/物品大图标背景/物品大图标/图标数量").node.Title = tostring(shopGood:GetIconAmount())
    ui:Get("商城主背景/信息框/名字").node.Title = shopGood.name
    ui:Get("商城主背景/信息框/详细介绍信息").node.Title = shopGood.description
    local status = self.packet.shopGoods[shopGood.name] ---@type ShopGoodStatus
    local purchaseButton = ui:Get("商城主背景/购买", ViewButton)
    ui:Get("商城主背景/价格信息/UIImage").node.Icon = shopGood.price.priceType.icon
    if shopGood.miniShopId then
        ui:Get("商城主背景/价格信息").node.Title = tostring(gg.FormatLargeNumber(status.price))
        purchaseButton:SetTouchEnable(true)
    else
        ui:Get("商城主背景/价格信息").node.Title = string.format("%s/%s",  
            gg.FormatLargeNumber(status.priceHas), gg.FormatLargeNumber(status.price))
        purchaseButton:SetTouchEnable(status.priceHas >= status.price)
    end
    purchaseButton.clickCb = function (ui, button)
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

    ui:Get("商城主背景/兑换迷你币", ViewButton).clickCb = function (ui, button)
        store:MiniCoinRecharge()
    end
    self.categoryList = ui:Get("商城主背景/分类栏背景/分类栏列表", ViewList, function (child, childPath)
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
        local categoryNode = child:Get("分类名")
        categoryNode.node.Title = shopName
        if shopName == self.id then
            categoryNode.node.TitleColor = ColorQuad.New(254,255,138,255)
            child.node.FillColor = ColorQuad.New(254,255,138,255)
        else
            categoryNode.node.TitleColor = ColorQuad.New(255,255,255,255)
            child.node.FillColor = ColorQuad.New(255,255,255,255)
        end
    end

    self.goodsList = ui:Get("商城主背景/物品栏背景/物品栏列表", ViewList, function (child, childPath)
        local c = ViewButton.New(child, ui, childPath)
        return c
    end) ---@type ViewList
    self.view:Get("商城主背景/关闭按钮", ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
    self.packet = packet
    
    local index = 1
    self.goodsList:SetElementSize(0)
    for privilegeType, shopGood in pairs(self.shopGoods) do
        self:_UpdateCard(self.goodsList:GetChild(index), shopGood, packet.shopGoods[privilegeType])
        if index == 1 then
            self:_ShowGood(shopGood)
        end
        index = index+1
    end
    self.view:Open()
end


return ShopGui