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
        local price = shopGood.price.priceAmount * param.power
        local priceHas = shopGood.price:GetPlayerHas(player)
        local affordable = shopGood.price:CanAfford(player, param)
        local bought = player:GetVariable(shopGood.price.varKey)
        
        -- === 新增：检查是否为免费可领取商品 ===
        local isFreeAvailable = (price <= 0) and affordable and not bought
        
        packet.shopGoods[privilegeType] = {
            affordable = affordable,
            bought = bought,
            price = price,
            priceHas = priceHas,
            -- === 新增：添加免费可领取标识 ===
            isFreeAvailable = isFreeAvailable
        }
    end
    
    -- === 新增：更新商城红点状态 ===
    self:UpdateShopRedDots(packet.shopGoods)
end

-- === 新增方法：更新商城红点状态 ===
---@param shopGoods table<string, ShopGoodStatus>
function ShopGui:UpdateShopRedDots(shopGoods)
    -- 这里可以实现服务端红点逻辑，或者留给客户端处理
    -- 由于红点系统主要在客户端，这里暂时不实现具体逻辑
    -- 可以在后续需要时添加服务端通知客户端的逻辑
end

-- === 新增方法：清除单个商品的红点 ===
---@param shopGoodId string
function ShopGui:ClearShopGoodRedDot(shopGoodId)
    local shopGood = self.shopGoods[shopGoodId]
    if shopGood then
        -- 获取ViewBase红点系统的引用（如果在服务端需要通知客户端）
        -- 这里可以发送事件到客户端来清除红点
        -- 或者在下次S_Open时会自动更新红点状态
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
        -- === 新增：购买成功后清除该商品的红点 ===
        self:ClearShopGoodRedDot(evt.shopGood)
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
    
    -- === 新增：为商品按钮注册红点路径 ===
    local redDotPath = string.format("商城/%s/%s", self.id or "默认商城", shopGood.name)
    node:SetNewsPath(redDotPath)
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
        
        -- === 新增：为商城分类按钮注册红点路径 ===
        local redDotPath = string.format("商城/%s", shopName)
        child:SetNewsPath(redDotPath)
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
    
    -- === 新增：更新所有商品的红点状态 ===
    self:UpdateAllShopRedDots(packet.shopGoods)
    
    -- 检查shop id是否变化，变化则重置index
    if self.lastShopId ~= self.id then
        self.currentDisplayGoodIndex = 1
        self.lastShopId = self.id
    end
    -- 显示指定的物品并且判断物品是否存在
    local config_item = packet.item_name and ShopGoodConfig.Get(packet.item_name)
    if config_item then
        self:_ShowGood(config_item)
    else
        -- 显示第一个物品
        local firstGoodId = self.shopGoodsIds[1]
        if firstGoodId then
            self:_ShowGood(self.shopGoods[firstGoodId])
        end
    end

    self.view:Open()
end


-- === 新增方法：更新所有商品的红点状态 ===
---@param shopGoods table<string, ShopGoodStatus>
function ShopGui:UpdateAllShopRedDots(shopGoods)
    local ViewBase = require(MainStorage.code.client.ui.ViewBase)
    
    -- 遍历所有商品，更新红点状态
    for shopGoodId, status in pairs(shopGoods) do
        local shopGood = self.shopGoods[shopGoodId]
        if shopGood then
            -- 构建红点路径
            local redDotPath = string.format("商城/%s/%s", self.id or "默认商城", shopGood.name)
            
            -- 判断是否应该显示红点（免费可领取且未购买）
            local shouldShowRedDot = status.isFreeAvailable or false
            
            -- 设置红点状态
            ViewBase.SetNew(redDotPath, shouldShowRedDot)
        end
    end
end


return ShopGui