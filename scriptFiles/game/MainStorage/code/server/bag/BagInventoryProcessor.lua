--- 背包库存处理器
--- 监听背包同步事件，整合物品和金钱数据

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig

---@class BagInventoryProcessor
local BagInventoryProcessor = {}

-- 存储玩家的整合后库存数据
BagInventoryProcessor.playerInventories = {} ---@type table<number, table<string, number>>

--- 初始化背包库存处理器
function BagInventoryProcessor.Init()
    gg.log("初始化背包库存处理器...")
    BagInventoryProcessor.RegisterEventHandlers()
    gg.log("背包库存处理器初始化完成")
end

--- 注册事件监听器
function BagInventoryProcessor.RegisterEventHandlers()
    -- 监听背包同步响应事件
    ServerEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, BagInventoryProcessor.HandleSyncInventoryItems)
    gg.log("已注册背包同步事件监听器")
end

--- 处理背包同步事件
---@param evt table 事件数据 {cmd, items, moneys, player}
function BagInventoryProcessor.HandleSyncInventoryItems(evt)
    if not evt.player or not evt.player.uin then
        gg.log("背包同步事件缺少玩家信息")
        return
    end

    local uin = evt.player.uin
    local items = evt.items or {}
    local moneys = evt.moneys or {}

    -- 创建整合后的库存数据
    local inventory = {}

    -- 处理普通物品数据
    for slot, itemData in pairs(items) do
        if itemData and itemData.itype and itemData.amount then
            local itemName = itemData.itype
            local amount = itemData.amount or 0
            
            -- 如果物品已存在，累加数量
            if inventory[itemName] then
                inventory[itemName] = inventory[itemName] + amount
            else
                inventory[itemName] = amount
            end
        end
    end

    -- 处理货币数据
    for _, moneyData in ipairs(moneys) do
        if moneyData and moneyData.it and moneyData.a then
            local moneyName = moneyData.it
            local amount = moneyData.a or 0
            
            -- 货币直接设置（不累加，因为货币数据本身就是总数）
            inventory[moneyName] = amount
        end
    end

    -- 保存到玩家库存数据中
    BagInventoryProcessor.playerInventories[uin] = inventory

    -- -- 打印整合后的库存数据
    -- gg.log("=== 玩家 " .. uin .. " 的库存数据 ===")
    -- local sortedItems = {}
    -- for itemName, amount in pairs(inventory) do
    --     table.insert(sortedItems, {name = itemName, amount = amount})
    -- end
    
    -- -- 按物品名称排序
    -- table.sort(sortedItems, function(a, b)
    --     return a.name < b.name
    -- end)
    
    -- for _, item in ipairs(sortedItems) do
    --     gg.log(string.format("%s: %d", item.name, item.amount))
    -- end
    -- gg.log("=== 库存数据结束 ===")

    -- 可选：触发自定义事件通知其他系统
    ServerEventManager.Publish("PlayerInventoryUpdated", {
        uin = uin,
        inventory = inventory,
        player = evt.player
    })
end

--- 获取玩家的库存数据
---@param uin number 玩家ID
---@return table<string, number>|nil 库存数据，key为物品名称，value为数量
function BagInventoryProcessor.GetPlayerInventory(uin)
    return BagInventoryProcessor.playerInventories[uin]
end

--- 获取玩家指定物品的数量
---@param uin number 玩家ID
---@param itemName string 物品名称
---@return number 物品数量
function BagInventoryProcessor.GetPlayerItemAmount(uin, itemName)
    local inventory = BagInventoryProcessor.GetPlayerInventory(uin)
    if inventory then
        return inventory[itemName] or 0
    end
    return 0
end

--- 检查玩家是否拥有足够的物品
---@param uin number 玩家ID
---@param requiredItems table<string, number> 需要的物品和数量
---@return boolean, table<string, number> 是否足够，以及不足的物品列表
function BagInventoryProcessor.CheckPlayerItems(uin, requiredItems)
    local inventory = BagInventoryProcessor.GetPlayerInventory(uin)
    if not inventory then
        return false, requiredItems
    end

    local insufficientItems = {}
    for itemName, requiredAmount in pairs(requiredItems) do
        local currentAmount = inventory[itemName] or 0
        if currentAmount < requiredAmount then
            insufficientItems[itemName] = requiredAmount - currentAmount
        end
    end

    return next(insufficientItems) == nil, insufficientItems
end

--- 清理玩家库存数据（玩家离线时调用）
---@param uin number 玩家ID
function BagInventoryProcessor.ClearPlayerInventory(uin)
    BagInventoryProcessor.playerInventories[uin] = nil
end

return BagInventoryProcessor 