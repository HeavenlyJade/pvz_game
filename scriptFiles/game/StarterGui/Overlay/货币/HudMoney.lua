local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local SkillTypeConfig = require(MainStorage.config.SkillTypeConfig) ---@type SkillTypeConfig
local TweenService = game:GetService("TweenService")
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local CoreUI = game:GetService("CoreUI")


---@class HudMoney:ViewBase
local HudMoney = ClassMgr.Class("HudMoney", ViewBase)

local uiConfig = {
    uiName = "HudMoney",
    layer = -1,
    hideOnInit = false,
    closeHuds = false
}

---@class MoneyAddPool
---@field pool UITextLabel[] 对象池
---@field template UITextLabel 模板对象
local MoneyAddPool = {
    pool = {},
    template = nil
}

--- 从对象池获取一个文本标签
---@return UITextLabel
function MoneyAddPool:Get()
    local label = table.remove(self.pool)
    if not label then
        -- 如果对象池为空，创建新对象
        label = self.template:Clone()
        label.Parent = self.template.Parent
    end
    return label
end

--- 将文本标签放回对象池
---@param label UITextLabel
function MoneyAddPool:Return(label)
    label.Visible = false
    label.Scale = Vector2.New(1, 1)
    table.insert(self.pool, label)
end

function OnMoneyClick(ui, viewButton)
end

function HudMoney:OnInit(node, config)
    gg.log("菜单按钮HudMoney初始化")
    self.selectingCard = 0
    -- 初始化对象池
    MoneyAddPool.template = self:Get("货币增加").node ---@type UITextLabel
    MoneyAddPool.template.Visible = false

    self.moneyButtonList = self:Get("货币/货币", ViewList, function(n)
        local button = ViewButton.New(n, self)
        button.clickCb = OnMoneyClick
        return button
    end) ---@type ViewList<ViewButton>

    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(evt)
        local evt = evt ---@type SyncInventoryItems
        -- 更新货币显示
        if evt.moneys then
            for idx, money in ipairs(evt.moneys) do
                local button = self.moneyButtonList:GetChild(idx)
                if button then
                    local node = button:Get("Text").node ---@cast node UITextLabel
                    local itemType = ItemTypeConfig.Get(money.it)
                    local mainAmount = money.a or 0
                    local displayText = ""
                    -- 检查是否有货币增加
                    if self.lastMoneyValues and self.lastMoneyValues[idx] and money.a > self.lastMoneyValues[idx] then
                        -- 从对象池获取文本标签
                        local moneyAdd = MoneyAddPool:Get()
                        -- 设置增加值的显示
                        local diff = money.a - self.lastMoneyValues[idx]
                        moneyAdd.Title = "+" .. gg.FormatLargeNumber(diff)
                        moneyAdd["UIImage"].Icon = ItemTypeConfig.Get(money.it).icon
                        moneyAdd.Scale = Vector2.New(2, 2)
                        local screenSize = self:GetScreenSize()
                        -- 添加±20%的随机浮动
                        local randomOffsetX = (math.random() * 0.4 - 0.2) * screenSize.x
                        local randomOffsetY = (math.random() * 0.4 - 0.2) * screenSize.y
                        moneyAdd.Position = Vector2.New(
                            screenSize.x/2 + randomOffsetX,
                            screenSize.y/2 + randomOffsetY
                        )
                        moneyAdd.Visible = true
                        -- 创建动画
                        local tweenInfo = TweenInfo.New(1, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                        local tween = TweenService:Create(moneyAdd, tweenInfo, {
                            Position = node:GetGlobalPos(),
                            Scale = Vector2.New(1, 1)
                        })
                        tween:Play()
                        tween.Completed:Connect(function()
                            -- 动画完成后将对象放回对象池
                            MoneyAddPool:Return(moneyAdd)
                        end)
                    end
                    node.Title = gg.FormatLargeNumber(money.a)
                    if itemType and itemType.minorPrice and itemType.minorPriceAmount and itemType.minorPriceAmount > 0 then
                        -- 获取次一级货币数量
                        local minorType = itemType.minorPrice
                        local minorIdx = nil
                        for i, m in ipairs(evt.moneys) do
                            if m.it == minorType.name then
                                minorIdx = i break
                            end
                        end
                        local minorAmount = 0
                        if minorIdx then
                            minorAmount = evt.moneys[minorIdx].a or 0
                        end
                        if mainAmount > 0 then
                            -- 显示主货币+小数形式的次一级货币
                            local decimal = minorAmount / itemType.minorPriceAmount
                            local total = mainAmount + decimal
                            total = math.floor(total * 100 + 0.5) / 100
                            displayText = gg.FormatLargeNumber(total)
                        else
                            -- 主货币为0，显示次一级货币
                            displayText = gg.FormatLargeNumber(minorAmount)
                        end
                    else
                        -- 没有进位关系，直接显示
                        displayText = gg.FormatLargeNumber(mainAmount)
                    end
                    node.Title = displayText
                end
            end
            -- 保存当前货币值用于下次比较
            self.lastMoneyValues = {}
            for idx, money in ipairs(evt.moneys) do
                self.lastMoneyValues[idx] = money.a
            end
        end
    end)

end

return HudMoney.New(script.Parent, uiConfig)
