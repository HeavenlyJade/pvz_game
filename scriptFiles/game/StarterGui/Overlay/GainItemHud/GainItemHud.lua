local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local Item = require(MainStorage.code.server.bag.Item) ---@type Item

---@class ItemInfo
---@field node ViewComponent
---@field fadeTimer number
---@field fadeDuration number
---@field fadeOutDuration number
---@field targetY number
---@field updateTaskId number

---@class GainItemHud:ViewBase
local GainItemHud = ClassMgr.Class("GainItemHud", ViewBase)

local uiConfig = {
    uiName = "GainItemHud",
    layer = 0,
    hideOnInit = false
}

function GainItemHud:OnInit(node, config)
    self.itemPool = {} ---@type ItemInfo[]
    self.activeItems = {} ---@type ItemInfo[]
    self.template = self:Get("获得物品").node ---@type UIComponent
    self.template.Visible = false
    
    -- 计算初始位置
    self.initialY = self.template.Position.y
    self.itemSpacing = 90 -- 物品之间的间距
    
    -- 监听获得物品事件
    ClientEventManager.Subscribe("GainedItem", function(evt)
        self:ShowGainedItem(evt.item)
    end)
end

function GainItemHud:GetItemFromPool()
    -- 尝试从对象池中获取一个物品显示对象
    local itemInfo = table.remove(self.itemPool)
    
    -- 如果没有可用的对象，创建一个新的
    if not itemInfo then
        local newNode = self.template:Clone()
        newNode:SetParent(self.template.Parent)
        itemInfo = {
            node = newNode,
            fadeTimer = 0,
            fadeDuration = 5, -- 保持显示5秒
            fadeOutDuration = 3, -- 3秒内淡出
            targetY = 0,
            updateTaskId = 0
        }
    end
    
    -- 重置状态
    itemInfo.fadeTimer = 0
    itemInfo.node.Visible = true
    itemInfo.node.Alpha = 1
    
    -- 添加到活动列表
    table.insert(self.activeItems, itemInfo)
    
    -- 注册更新任务
    itemInfo.updateTaskId = ClientScheduler.add(function()
        self:UpdateItem(itemInfo)
    end, 0, 0.06) -- 每帧更新一次
    
    return itemInfo
end

function GainItemHud:ReturnItemToPool(itemInfo)
    -- 取消更新任务
    if itemInfo.updateTaskId > 0 then
        ClientScheduler.cancel(itemInfo.updateTaskId)
        itemInfo.updateTaskId = 0
    end
    
    -- 从活动列表中移除
    for i, activeItem in ipairs(self.activeItems) do
        if activeItem == itemInfo then
            table.remove(self.activeItems, i)
            break
        end
    end
    
    -- 重置并返回对象池
    itemInfo.node.Visible = false
    table.insert(self.itemPool, itemInfo)
end

function GainItemHud:UpdateItem(itemInfo)
    -- 更新淡出计时器
    itemInfo.fadeTimer = itemInfo.fadeTimer + 0.06
    
    -- 如果超过显示时间，开始淡出
    if itemInfo.fadeTimer >= itemInfo.fadeDuration then
        local fadeProgress = (itemInfo.fadeTimer - itemInfo.fadeDuration) / itemInfo.fadeOutDuration
        if fadeProgress >= 1 then
            -- 完全淡出后返回对象池
            self:ReturnItemToPool(itemInfo)
            return
        end
        
        -- 设置透明度
        itemInfo.node.Alpha = 1 - fadeProgress
    end
    
    -- 更新位置
    local index = 0
    for i, activeItem in ipairs(self.activeItems) do
        if activeItem == itemInfo then
            index = i
            break
        end
    end
    
    if index > 0 then
        local targetY = self.initialY - (index - 1) * self.itemSpacing
        itemInfo.targetY = targetY
        
        -- 平滑移动到目标位置
        local currentPos = itemInfo.node.Position
        local newY = currentPos.y + (targetY - currentPos.y) * 0.2 -- 使用缓动效果
        itemInfo.node.Position = Vector2.New(currentPos.x, newY)
    end
end

function GainItemHud:ShowGainedItem(itemData)
    local item = Item.New()
    item:Load(itemData)
    local itemInfo = self:GetItemFromPool()
    
    itemInfo.node["Item"]["ItemIcon"].Icon = item.itemType.icon
    itemInfo.node["Item"]["Amount"].Title = tostring(item.amount)
    itemInfo.node["物品描述"].Title = string.format("%s\n%s", item.itemType.name, item.itemType.description)
    -- 显示UI
    self:Open()
end

function GainItemHud:Update()
    -- 如果没有活动物品，关闭UI
    if #self.activeItems == 0 then
        self:Close()
    end
end

return GainItemHud.New(script.Parent, uiConfig)