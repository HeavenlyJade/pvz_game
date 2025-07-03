local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local LevelConfig = require(MainStorage.code.common.config.LevelConfig)  ---@type LevelConfig
local LotteryConfig = require(MainStorage.code.common.config.LotteryConfig)  -- 确保已 require
local Price = require(MainStorage.code.common.config_type.Price) ---@type Price
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local TweenService = game:GetService('TweenService') ---@type TweenService

---@class PackAnim
---@field angle number
---@field speed number

---@class RollCardsGui:CustomUI
local RollCardsGui = ClassMgr.Class("RollCardsGui", CustomUI)
local GRAVITY = 0 ---@type number 重力方向。
local DAMPING = 0.9
local SWAY_FORCE = 20

---@param data table
function RollCardsGui:OnInit(data)
    self.lotteryPool = LotteryConfig.Get(data["奖池"]) ---@type Lottery
    self.material = ItemTypeConfig.Get(data["需求素材"])
    self.priceConfig = Price.New(data["缺少补充价格"]) ---@type Price
    self.purchaseTriggerCommands = data["购买抽奖券点击指令"] ---@type Lottery
end

---@param player Player
function RollCardsGui:S_BuildPacket(player, packet)
    local pool = self.lotteryPool
    local pity_epic = player:GetVariable("pity_" .. pool.poolName .. "_epic")
    local pity_legendary = player:GetVariable("pity_" .. pool.poolName .. "_legendary")
    local pity_mythic = player:GetVariable("pity_" .. pool.poolName .. "_mythic")
    local item_count = player.bag:GetItemAmount(self.material)

    -- 计算下一个保底品级和还需次数
    local next_pity, next_pity_count = nil, nil
    local pity_list = {
        {name = "mythic", count = pity_mythic, max = pool.mythicPity},
        {name = "legendary", count = pity_legendary, max = pool.legendaryPity},
        {name = "epic", count = pity_epic, max = pool.epicPity},
    }
    for _, v in ipairs(pity_list) do
        if v.max and v.max > 0 and v.count < v.max then
            next_pity = v.name
            next_pity_count = v.max - v.count
            break
        end
    end
    if not next_pity then
        next_pity = "none"
        next_pity_count = 0
    end

    packet.lottery = {
        next_pity = next_pity,
        next_pity_count = next_pity_count,
        pity_list = pity_list,
        item_count = item_count,
        price_count = player.bag:GetItemAmount(self.priceConfig.priceType)
    }
end

---@param player Player
function RollCardsGui:S_DrawWithMissing(player, data)
    local missingCount = data.missingCount
    local missingCost = {power = missingCount}
    if not self.priceConfig:CanAfford(player, missingCost) then
        player:SendHoverText("数量不足，无法购买")
        return
    end
    self.priceConfig:Pay(player, missingCost)
    player.bag:GiveItem(self.material:ToItem(missingCount))
    self:S_Draw(player, data)
end

---@param player Player
function RollCardsGui:S_TriggerPurchaseCommands(player, data)
    player:ExecuteCommands(self.purchaseTriggerCommands)
end

---@param player Player
function RollCardsGui:S_Draw(player, data)
    local count = data.count
    local cost = player.bag:GetItemAmount(self.material)
    if cost < count then
        player:SendHoverText("道具不足，无法抽奖")
        return
    end
    player.bag:RemoveItems({[self.material] = cost})
    self.lotteryPool:Draw(player, count, true)
end

-----------------------客户端---------------------------
local rarityMap = {
    mythic = "UR",
    legendary = "SSR",
    epic = "SR"
}
local packAnim = {} ---@type table<UIImage, PackAnim>
local uiInitialPos = nil
local uiShakeX = 0
local uiShakeMult = 0

---@param packComponent UIImage
function RollCardsGui:_SwayPack(packComponent, speed)
    if not packAnim[packComponent] then
        packAnim[packComponent] = {
            angle = packComponent.Rotation,
            speed = 0
        }
    end
    packAnim[packComponent].speed = packAnim[packComponent].speed + speed
end

function RollCardsGui:_SwayPacks()
    ClientEventManager.Publish("PlaySound", {
        soundAssetId = "sandboxId://soundeffect/carddraw/lottery_pull[1~2].ogg"
    })
    for i = 1, self._packsList:GetChildCount(), 1 do
        local packComponent = self._packsList:GetChild(i)
        ClientScheduler.add(function ()
            self:_SwayPack(packComponent:Get("卡包").node, SWAY_FORCE * (0.8 + math.random() * 0.4))
            ClientScheduler.add(function ()
                self:_SwayPack(packComponent:Get("卡包_上层").node, SWAY_FORCE * (0.8 + math.random() * 0.4))
            end, math.random() * 0.2)
        end, i * 0.02)
    end
end

local tweenInfoUpper = TweenInfo.New(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local tweenInfoLower = TweenInfo.New(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
function RollCardsGui:_DropPack(callCb)
    self:_SwayPacks()
    uiShakeMult = self.view.node:GetAttribute("框体震动幅度")
    uiShakeX = 0
    ClientScheduler.add(function ()
        ClientEventManager.Publish("PlaySound", {
            soundAssetId = "sandboxId://soundeffect/carddraw/lottery_start.ogg"
        })
        local i = math.random(self._packsList:GetChildCount())
        local y = 325
        local tweenInfo = tweenInfoUpper
        if i > 3 then
            y = 164
            tweenInfo = tweenInfoLower
        end
        local packNode = self._packsList:GetChild(i):Get("卡包_上层").node
        packAnim[packNode] = nil
        TweenService:Create(packNode, tweenInfo, {Position = Vector2.New(packNode.Position.x, y)}):Play()
        ClientScheduler.add(callCb, 0.5)
    end, 1)
end

function RollCardsGui:C_TryDraw(count)
    if count > self.lotteryInfo.item_count then
        local confirmUI = ViewBase.GetUI("ConfirmUI") ---@type ConfirmUI
        local missingCount = count - self.lotteryInfo.item_count
        local missingCost = self.priceConfig.priceAmount * missingCount
        confirmUI:Display(string.format("%s 不足", self.material.name),
            string.format("是否要用 %sx%d 补足剩下的 %sx%d？", self.priceConfig.priceType.name, missingCost, 
            self.material.name, missingCount), function ()
                --若数量足够
                if self.lotteryInfo.price_count < missingCost then
                    confirmUI:Display(string.format("%s 不足", self.priceConfig.priceType.name), "是否要前往获取？", function ()
                        --打开充值界面
                    end)
                else
                    self:_DropPack(function ()
                        self:C_SendEvent("S_DrawWithMissing", {
                            count = count,
                            missingCount = missingCount
                        })
                    end)
                end
            end)
        return
    end
    self:_DropPack(function ()
        self:C_SendEvent("S_Draw", {
            count = count
        })
    end)
end

function RollCardsGui:C_InitUI()
    local ui = self.view
    self._packsList = ui:Get("抽卡机背景", ViewList) ---@type ViewList
    uiInitialPos = self._packsList.node.Position
    ui:Get("抽卡机背景/前挡风玻璃", ViewButton).clickCb = function (ui, button)
        self:_SwayPacks()
        uiShakeMult = ui.node:GetAttribute("框体震动幅度")
        uiShakeX = 0
    end
    self._prizesList = ui:Get("侧边奖池/奖池列表", ViewList, function (child, childPath)
        return ViewItem.New(child, ui, childPath)
        end) ---@type ViewList

    self._drawOnce = ui:Get("抽卡机背景/前挡风玻璃/单抽", ViewButton)
    self._drawOnce.clickCb = function (ui, button)
        self:C_TryDraw(1)
    end
    
    self._drawTen = ui:Get("抽卡机背景/前挡风玻璃/十连", ViewButton)
    self._drawTen.clickCb = function (ui, button)
        self:C_TryDraw(10)
    end
    ui:Get("抽卡机背景/前挡风玻璃/购买抽奖券", ViewButton).clickCb = function (ui, button)
        self:C_SendEvent("S_TriggerPurchaseCommands", {})
    end
    ui:Get("关闭", ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
    self.view.openCb = function ()
        self.updateSwayTaskId = ClientScheduler.add(function ()
            if uiShakeMult > 0.1 then
                uiShakeX = uiShakeX + ui.node:GetAttribute("框体震动频率")
                local x = math.sin(uiShakeX) * uiShakeMult
                self._packsList.node.Position = Vector2.New(uiInitialPos.x + x, uiInitialPos.y)
                uiShakeMult = uiShakeMult * ui.node:GetAttribute("框体震动阻尼")
                if math.abs(uiShakeMult) < 0.01 then
                    uiShakeMult = 0
                end
            end
            for img, anim in pairs(packAnim) do
                local angle = anim.angle or 0
                local speed = anim.speed or 0
                -- GRAVITY为最终静止角度（弧度），动画向GRAVITY收敛
                speed = speed - (angle - GRAVITY) * 0.2
                speed = speed * DAMPING
                angle = angle + speed
                if math.abs(speed) < 0.001 and math.abs(angle - GRAVITY) < 0.001 then
                    speed = 0
                    angle = GRAVITY
                end
                anim.angle = angle
                anim.speed = speed
                img.Rotation = angle
            end
        end, 0, 0.05)
    end
    self.view.closeCb = function ()
        if self.updateSwayTaskId then
            ClientScheduler.cancel(self.updateSwayTaskId)
        end
    end
end

function RollCardsGui:C_BuildUI(packet)
    local lottery = packet.lottery
    self.lotteryInfo = lottery
    local ui = self.view
    DAMPING = ui.node:GetAttribute("卡包摆动阻尼")
    SWAY_FORCE = ui.node:GetAttribute("卡包摆动初始速度")
    -- 设置顶部信息栏，显示下次保底的次数和品级
    local next_pity = lottery.next_pity
    local next_pity_count = lottery.next_pity_count
    local rarityStr = rarityMap[next_pity] or next_pity
    if next_pity ~= "none" and next_pity_count > 0 then
        ui:Get("抽卡机背景/顶部信息栏/顶部信息").node.Title = string.format("再抽取 %d 次", next_pity_count)
        ui:Get("抽卡机背景/顶部信息栏/顶部信息2").node.Title = string.format("必得 %s 级卡片", rarityStr)
    else
        ui:Get("抽卡机背景/顶部信息栏/顶部信息").node.Title = ""
        ui:Get("抽卡机背景/顶部信息栏/顶部信息2").node.Title = ""
    end
    for i = 1, self._packsList:GetChildCount(), 1 do
        local packComponent = self._packsList:GetChild(i)
        packComponent.node["卡包_上层"].Rotation = 0
        packComponent.node["卡包_上层"].Position = Vector2.New(packComponent.node["卡包_上层"].Position.x, 0)
    end

    self._prizesList:SetElementSize(0)

    -- 遍历奖池所有奖品，按品级顺序依次显示
    local prizeOrder = {
        {prizes = self.lotteryPool.mythicPrizes, rarity = "mythic"},
        {prizes = self.lotteryPool.legendaryPrizes, rarity = "legendary"},
        {prizes = self.lotteryPool.epicPrizes, rarity = "epic"},
        {prizes = self.lotteryPool.rarePrizes, rarity = "rare"},
        {prizes = self.lotteryPool.normalPrizes, rarity = "normal"},
    }
    local idx = 1
    for _, group in ipairs(prizeOrder) do
        -- 计算该品级奖池总权重
        local totalWeight = 0
        for _, prize in ipairs(group.prizes or {}) do
            totalWeight = totalWeight + (prize.weight or 1)
        end
        for _, prize in ipairs(group.prizes or {}) do
            local child = self._prizesList:GetChild(idx)
            if prize.itemType then
                child:SetItem(prize.itemType)
            end
            -- 数量
            local minAmount = prize.itemCountMin or 1
            local maxAmount = prize.itemCountMax or minAmount
            local amountStr = (minAmount == maxAmount) and tostring(minAmount) or (tostring(minAmount) .. "~" .. tostring(maxAmount))
            -- 概率
            local prob = totalWeight > 0 and (prize.weight or 1) / totalWeight or 0
            local probStr = string.format("%.2f%%", prob * 100)
            child:Get("Amount").node.Title = amountStr .. "\n" .. probStr
            idx = idx + 1
        end
    end

    ui:Get("抽卡机背景/前挡风玻璃/ItemIcon", ViewItem):SetItem(self.material:ToItem(1))
    ui:Get("抽卡机背景/前挡风玻璃/ItemIcon/Amount", ViewComponent).node.Title = gg.FormatLargeNumber(lottery.item_count)
    
    self.packet = packet
    self.view:Open()
end

return RollCardsGui