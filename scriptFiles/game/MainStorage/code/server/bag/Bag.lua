local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local common_const = require(MainStorage.code.common.MConst) ---@type common_const
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local Item = require(MainStorage.code.server.bag.Item) ---@type Item
local game = game
local BagMgr        = require(MainStorage.code.server.bag.BagMgr) ---@type BagMgr
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig

---@class Slot
---@field c number 背包类型
---@field s number 背包格子

---@class Bag : Class
---@field player Player 玩家实例
---@field uin number 玩家ID
---@field bag_index table<ItemType, Slot[]> 物品类型索引
---@field bag_items table<number, table<number, Item>> 背包物品
---@field New fun( player: Player):Bag
local Bag = ClassMgr.Class("Bag")
Bag.MoneyType = {} ---@type table<number, ItemType>

---@param player Player 玩家实例
function Bag:OnInit(player)
    self.player = player ---@type Player
    self.uin = player.uin
    self.bag_index = {} ---@type table<ItemType, Slot[]>
    self.bag_items = {} ---@type table<number, table<number, Item>>

    self.loaded = false
    self.dirtySyncSlots = {}
    self.dirtySave = false
    self.dirtySyncAll = false

    self.removedItems = {} ---@type table<string, boolean> 记录本次被移除的物品
end

---@param data table 背包数据
function Bag:Load(data)
    if not data or not data.items then
        return
    end

    -- 清空现有数据
    self.bag_index = {}
    self.bag_items = {}

    -- 加载物品数据并重建索引
    for category, itemData in pairs(data.items) do
        -- 打印物品数据内容
        self.bag_items[category] = {}
        for slot, itemData in pairs(itemData) do
            local item = Item.New()
            item:Load(itemData)
            -- 添加到类型索引
            local itemType = item:GetItemType()
            if itemType then
                self.bag_items[category][slot] = item
                if not self.bag_index[itemType] then
                    self.bag_index[itemType] = {}
                end
                table.insert(self.bag_index[itemType], {c =category, s =slot})
            end
        end
    end
    self:MarkDirty(true)
end

function Bag:Save()
    local itemData = {}
    for category, items in pairs(self.bag_items) do
        itemData[category] = {}
        if items then
            for slot, item in pairs(items) do
                if item then
                    itemData[category][slot] = item:Save()
                end
            end
        end
    end
    local data = {
        items = itemData
    }
    local cloudService = game:GetService("CloudService") --- @type CloudService
    cloudService:SetTableAsync('inv' .. self.player.uin, data, function ()
    end)
end

---@param slot number 格子序号
---@return Item|nil 物品实例
function Bag:GetItemBySlot(slot)
    return self.bag_items[slot]
end

---@param itemType ItemType 物品类型
---@return Item[] 物品列表
function Bag:GetItemByType(itemType)
    local items = {}
    local slots = self.bag_index[itemType] or {}
    for _, slot in ipairs(slots) do
        local item = self.bag_items[slot]
        if item then
            table.insert(items, item)
        end
    end
    return items
end

---@param item Item 物品实例
---@return boolean 是否添加成功
function Bag:AddItem(item)
    if not item or not item:GetItemType() then
        return false
    end

    -- 如果是可堆叠物品，尝试合并
    if item:GetAmount() > 0 then
        local itemType = item:GetItemType()
        local slots = self.bag_index[itemType] or {}
        for _, existingSlot in ipairs(slots) do
            local existingItem = self:GetItem(existingSlot)
            if existingItem and existingItem:GetItemType() == itemType and existingItem:GetEnhanceLevel() == item:GetEnhanceLevel() then
                self:SetItemAmount(existingSlot, existingItem:GetAmount() + item:GetAmount())
                return true
            end
        end
    end

    -- 无法合并，添加到指定格子
    -- 查找第一个空格子
    local category = 1
    local slot = 1
    while self.bag_items[category] and self.bag_items[category][slot] do
        slot = slot + 1
    end
    self:SetItem({c = category, s = slot}, item)
    return true
end

function Bag:SyncToClient()
    if #self.dirtySyncSlots == 0 and not self.dirtySyncAll then
        return
    end

    local moneys = {}
    for idx, itemType in ipairs(Bag.MoneyType) do
        moneys[idx] = {
            it = itemType.name,
            a = self:GetItemAmount(itemType)
        }
    end
    local syncItems = {}
    if self.dirtySyncAll then
        for category, items in pairs(self.bag_items) do
            for slot, item in pairs(items) do
                syncItems[{c =category, s =slot}] = item:Save()
            end
        end
    else
        for _, slot in ipairs(self.dirtySyncSlots) do
            local item = self:GetItem(slot)
            if item then
                syncItems[slot] = item:Save()
            end
        end
    end
    -- 新增：同步被移除的物品名列表
    local removedItems = {}
    if self.removedItems then
        for itemName, _ in pairs(self.removedItems) do
            table.insert(removedItems, itemName)
        end
        self.removedItems = {} -- 清空
    end
    self.dirtySyncAll = false
    self.dirtySyncSlots = {}

    local ret = {
        cmd = BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS,
        items = syncItems,
        moneys = moneys,
        removed = removedItems
    }
    -- gg.log("背包数据同步",ret)
    gg.network_channel:fireClient(self.player.uin, ret)
end

function Bag:SetItemAmount(slot, amount)
    local item = self:GetItem(slot)

    if amount <= 0 then
        self:SetItem(slot, nil)
        if item then
            self.removedItems[item.itemType.name] = true
        end
        return
    end
    if not item then
        return
    end
    item:SetAmount(amount)
    self:MarkDirty(slot)
end

function Bag:MarkDirty(slot)
    self.dirtySave = true
    if slot then
        if type(slot) == "boolean" then
            self.dirtySyncAll = true
        else
            table.insert(self.dirtySyncSlots, slot)
        end
    end
    BagMgr.need_sync_bag[self] = true
end

---@param slot Slot 格子序号
function Bag:UseItem(slot)
    local item = self.bag_items[slot]
    if not item then
        return
    end

    if item:IsConsumable() then
        self.player:ExecuteCommand(item.itemType.useCommands, nil)
    elseif item:IsEquipment() then
        -- 自动寻找第一个可装备的Slot
        local equipSlotType = item.itemType.equipmentSlot
        local foundSlot = nil
        -- 遍历所有装备槽，找到第一个可用的
        for slotId, slotInfo in pairs(gg.equipSlot) do
            if slotInfo[equipSlotType] then
                -- 检查该槽是否为空或可替换
                local targetSlot = {
                    category = slotId,
                    slot = 1
                }
                local equippedItem = self:GetItem(targetSlot)
                if not equippedItem or self:IsValidEquipType(targetSlot, item) then
                    foundSlot = targetSlot
                    break
                end
            end
        end
        if foundSlot then
            self:SwapItem(slot, foundSlot)
        else
            self.player:SendHoverText("没有可用的装备槽！")
        end
    end
end

---@param slot Slot 格子序号
function Bag:DecomposeItem(slot)
    local item = self.bag_items[slot]
    if not item then
        self.player:SendHoverText('该格子没有物品')
        return
    end
    -- 计算分解获得的材料类型和数量
    local materialType = item.itemType.sellableTo
    local matAmount = item:GetAmount() * item.itemType.sellPrice
    if not materialType or matAmount <= 0 then
        self.player:SendHoverText('%s 无法被分解', item:GetName())
        return
    end
    self:AddItem(materialType:ToItem(matAmount))
    self:SetItem(slot, nil)
    self.player:SendHoverText("分解成功，获得 %s x %s", materialType.name, matAmount)
end


---@return Item|nil
function Bag:GetItem(slot)
    local items = self.bag_items[slot.c]
    if not items then
        return nil
    end
    return items[slot.s]
end

---@param slot Slot 格子序号
---@param item Item|nil 物品实例
function Bag:SetItem(slot, item)
    -- 1. 处理旧物品的索引移除
    local oldItem = nil
    local items = self.bag_items[slot.c]
    if items then
        oldItem = items[slot.s]
    end
    if oldItem then
        local oldType = oldItem:GetItemType()
        if self.bag_index[oldType] then
            for i, s in ipairs(self.bag_index[oldType]) do
                if s == slot then
                    table.remove(self.bag_index[oldType], i)
                    break
                end
            end
        end
        oldItem.slot = nil
    end

    -- 2. 设置新物品
    if not items then
        if not item then
            return
        end
        items = {}
        self.bag_items[slot.c] = items
    end
    items[slot.s] = item

    -- 3. 处理新物品的索引添加
    if item then
        local newType = item:GetItemType()
        if not self.bag_index[newType] then
            self.bag_index[newType] = {}
        end
        table.insert(self.bag_index[newType], slot)
        item.slot = slot
    else
        -- 如果移除后该category下无物品，清理该category
        local hasItem = false
        for _, v in pairs(items) do
            if v then hasItem = true break end
        end
        if not hasItem then
            self.bag_items[slot.c] = nil
        end
    end

    if slot.c > 0 then
        self.player:RefreshStats()
    end
    self:MarkDirty(slot)
end

function Bag:IsValidEquipType(slot, item)
    local category = gg.equipSlot[slot]
    if not category then
        return true
    end
    local equipTypes = category[item.itype]
    if equipTypes[item.itemType.equipmentSlot] then
        return true
    end
    return false
end

---@param pos1 Slot 位置1
---@param pos2 Slot 位置2
function Bag:SwapItem(pos1, pos2)
    local item1 = self:GetItem(pos1)
    local item2 = self:GetItem(pos2)
    if item1 == nil and item2 == nil then
        return
    end

    if item2 and not self:IsValidEquipType(pos1, item2) then
        self.player:SendHoverText(string.format("%s 无法装备！", item2:GetName()))
    end
    if item1 and not self:IsValidEquipType(pos2, item1) then
        self.player:SendHoverText(string.format("%s 无法装备！", item1:GetName()))
    end
    self:SetItem(pos1, item2)
    self:SetItem(pos2, item1)
end

---@return number 打开的宝箱数量
function Bag:UseAllBoxes()
    local count = 0
    for itemType, indexes in pairs(self.bag_index) do
        if itemType.useCommands ~= nil and itemType.canAutoUse then
            for _, slot in ipairs(indexes) do
                local item = self:GetItem(slot)
                if item then
                    for i = 1, item:GetAmount() do
                        self.player:ExecuteCommand(item.itemType.useCommands, nil)
                        count = count + 1
                    end
                    self:SetItem(slot, nil)
                end
            end
        end
    end
    if count == 0 then
        self.player:SendHoverText('你的背包里没有可用物品')
    end
    return count
end

---@param rank ItemRank 目标品质等级
---@return number 分解的装备数量
function Bag:DecomposeAllLowQualityItems(rank)
    if not rank then
        return 0
    end
    local decomposedCount = 0
    local materialMap = {} -- {materialType: totalAmount}
    local toRemove = {}
    -- 统计所有可分解装备
    for category, items in pairs(self.bag_items) do
        for slot, item in pairs(items) do
            if item and item:IsEquipment() and item.itemType.quality and item.itemType.quality.priority < rank.priority and item.itemType.sellableTo then
                local materialType = item.itemType.sellableTo
                local matAmount = item:GetAmount() * (item.itemType.sellPrice or 1)
                if matAmount > 0 then
                    materialMap[materialType] = (materialMap[materialType] or 0) + matAmount
                    table.insert(toRemove, slot)
                    decomposedCount = decomposedCount + 1
                end
            end
        end
    end
    -- 合并材料到背包
    for materialType, totalAmount in pairs(materialMap) do
        self:AddItem(materialType:ToItem(totalAmount))
    end
    -- 移除原装备
    for _, slot in ipairs(toRemove) do
        self:SetItem(slot, nil)
    end
    if decomposedCount > 0 then
        -- 构造获得材料提示
        local tips = {}
        for materialType, totalAmount in pairs(materialMap) do
            table.insert(tips, string.format("%s x %d", materialType.name, totalAmount))
        end
        self.player:SendHoverText(string.format("获得材料：%s", decomposedCount, table.concat(tips, ", ")))
    else
        self.player:SendHoverText("没有发现可被分解的物品")
    end
    return decomposedCount
end

---@param item Item 物品信息
---@param source? string 获得渠道，会在GainItem词条中判断。新增了渠道后要记得在Unity的GainItemTag的注释里面注明哦
---@param silent? boolean true时，不弹出左下角的提示
---@return boolean
function Bag:GiveItem(item, source, silent)
    local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
    local param = CastParam.New()
    param.power = item.amount
    self.player:TriggerTags("获得物品时", self.player, param, item, source)
    item.amount = math.floor(param.power)
    if item.itemType.gainCommands then
        self.player:ExecuteCommands(item.itemType.gainCommands)
    end
    if item.itemType.cancelGained then
        return true
    end
    self:AddItem(item)
    if not item.itemType.isMoney and not silent then
        self.player:SendEvent("GainedItem", {
            item = item:Save()
        })
    end
    if self.player.questKey and self.player.questKey[item.itemType.name] then
        self.player:UpdateQuestsData()
    end
    self.player:PlaySound(item.itemType.gainSound)
    return true
end

---@param itemName string 物品名称
---@return table|nil 物品的背包数据，如果不存在返回nil
function Bag:GetItemDataByName(itemName)
    -- 遍历背包中所有实际物品
    for category, items in pairs(self.bag_items) do
        if items then
            for slot, item in pairs(items) do
                if item and item:GetName() == itemName then
                    -- 找到物品，直接返回详细信息
                    return {
                        category = category,
                        slot = slot,
                        amount = item:GetAmount(),
                        enhanceLevel = item:GetEnhanceLevel(),
                        uuid = item:GetUUID(),
                        itemType = item:GetItemType().name,
                        position = {c = category, s = slot}
                    }
                end
            end
        end
    end

    -- 没找到物品
    return nil
end

-- 私有方法：递归检查是否有足够货币（支持upperPrice分层进位，不会溢出）
function Bag:_HasMoney(itemType, amount)
    local own = self:GetItemAmount(itemType, false)
    if own >= amount then
        return true
    end
    -- 不足时，尝试拆分高面额
    if itemType.upperPrice and itemType.upperPriceAmount and itemType.upperPriceAmount > 0 then
        local upperOwn = self:GetItemAmount(itemType.upperPrice, false)
        local need = amount - own
        local canSplit = upperOwn * itemType.upperPriceAmount
        if canSplit <= 0 then
            return false
        end
        local total = own + canSplit
        if total >= amount then
            return true
        end
    end
    return false
end

-- 多层进位递归判断是否有足够货币
function Bag:_HasMoneyMulti(itemType, amount)
    local own = self:GetItemAmount(itemType, false)
    if own >= amount then
        return true
    end
    if itemType.upperPrice and itemType.upperPriceAmount and itemType.upperPriceAmount > 0 then
        local upperOwn = self:GetItemAmount(itemType.upperPrice, false)
        local need = amount - own
        local needUpper = math.ceil(need / itemType.upperPriceAmount)
        if upperOwn >= needUpper then
            return self:_HasMoneyMulti(itemType.upperPrice, needUpper)
        end
    end
    return false
end

-- 私有方法：递归扣除货币（优先扣低面额，不够时自动拆高面额）
function Bag:_RemoveMoney(itemType, amount)
    local own = self:GetItemAmount(itemType, false)
    if own >= amount then
        self:RemoveItems({[itemType] = amount}, false)
        return true
    end
    -- 不足时，尝试拆分高面额
    if itemType.upperPrice and itemType.upperPriceAmount and itemType.upperPriceAmount > 0 then
        local upperOwn = self:GetItemAmount(itemType.upperPrice, false)
        local need = amount - own
        local needUpper = math.ceil(need / itemType.upperPriceAmount)
        if upperOwn >= needUpper then
            -- 拆分高面额
            self:RemoveItems({[itemType.upperPrice] = needUpper}, false)
            self:AddItem(itemType:ToItem(needUpper * itemType.upperPriceAmount))
            self:RemoveItems({[itemType] = amount}, false)
            return true
        end
    end
    return false
end


--- 检查并返回资源不足的信息
---@param costs table<string|ItemType, number> 消耗表
---@return table|nil 不足的资源列表，如果没有不足则返回nil
function Bag:GetResourceShortageInfo(costs)
    if not costs or not next(costs) then
        return nil
    end

    local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig)
    local insufficientResources = {}

    for itemOrName, requiredAmount in pairs(costs) do
        local itemType
        if type(itemOrName) == "string" then
            itemType = ItemTypeConfig.Get(itemOrName)
        else
            itemType = itemOrName
        end

        if itemType then
            if itemType.isMoney then
                if not self:_HasMoneyMulti(itemType, requiredAmount) then
                    local haveAmount = self:GetItemAmount(itemType, true)
                    table.insert(insufficientResources, {
                        displayName = itemType.displayName or itemType.name,
                        isMoney = true,
                        missing = requiredAmount - haveAmount
                    })
                end
            else
                local haveAmount = self:GetItemAmount(itemType, false)
                if haveAmount < requiredAmount then
                    table.insert(insufficientResources, {
                        displayName = itemType.displayName or itemType.name,
                        missing = requiredAmount - haveAmount
                    })
                end
            end
        end
    end

    if #insufficientResources > 0 then
        return insufficientResources
    end

    return nil
end



-- 修改HasItems，支持货币多层进位递归判断，避免大数溢出
function Bag:HasItems(items)
    if not items then
        return false
    end
    for itemType, count in pairs(items) do
        if type(itemType) == "string" then
            local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
            itemType = ItemTypeConfig.Get(itemType)
        end
        if itemType.isMoney then
            if not self:_HasMoneyMulti(itemType, count) then
                return false
            end
        else
            local slots = self.bag_index[itemType] or {}
            local total = 0
            for _, slot in ipairs(slots) do
                local item = self:GetItem(slot)
                if item then
                    total = total + item:GetAmount()
                end
            end
            if total < count then
                return false
            end
        end
    end
    return true
end

-- 修改RemoveItems，支持货币分层进位
function Bag:RemoveItems(items, checkMoney)
    if checkMoney == nil then
        checkMoney = true
    end
    if not items then
        return false
    end
    if not self:HasItems(items) then
        return false
    end
    for itemType, count in pairs(items) do
        if type(itemType) == "string" then
            local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
            itemType = ItemTypeConfig.Get(itemType)
        end
        if checkMoney and itemType.isMoney then
            if not self:_RemoveMoney(itemType, count) then
                return false
            end
        else
            local remaining = count
            local slots = self.bag_index[itemType] or {}
            for _, slot in ipairs(slots) do
                if remaining <= 0 then
                    break
                end
                local item = self:GetItem(slot)
                if item then
                    local amount = item:GetAmount()
                    local toRemove = math.min(amount, remaining)
                    self:SetItemAmount(slot, amount - toRemove)
                    remaining = remaining - toRemove
                end
            end
        end
    end
    return true
end

function Bag:PrintContent()
    local categories = {}
    for category, items in pairs(self.bag_items) do
        if items then
            local categoryItems = {}
            for slot, item in pairs(items) do
                if item then
                    table.insert(categoryItems, {
                        item = item,
                        s = slot,
                        c = category
                    })
                end
            end
            if #categoryItems > 0 then
                categories[category] = categoryItems
            end
        end
    end

    local lines = {}
    local first = true
    for category, items in pairs(categories) do
        if not first then
            table.insert(lines, "==============")
        end
        first = false
        for _, itemInfo in ipairs(items) do
            table.insert(lines, string.format("[%d:%d] %s", itemInfo.c, itemInfo.s, itemInfo.item:PrintContent()))
        end
    end

    print(table.concat(lines, "\n"))
end

---@param itemType ItemType 物品类型
---@param checkMoney? boolean 物品类型
---@return number 物品总数量
function Bag:GetItemAmount(itemType, checkMoney)
    if checkMoney == nil then
        checkMoney = true
    end
    local total = 0
    local slots = self.bag_index[itemType] or {}
    for _, slot in ipairs(slots) do
        local item = self:GetItem(slot)
        if item then
            total = total + item:GetAmount()
        end
    end
    if total > 0 then
        return total
    end
    -- 检查高面额
    if checkMoney and itemType.upperPrice then
        local upper = self:GetItemAmount(itemType.upperPrice)
        if upper > 0 or upper == -1 then
            return -1
        end
    end
    return 0
end

---@param moneyId number 货币类型
---@param amount number 货币数量
---@return boolean 是否成功
function Bag:TakeMoney(moneyId, amount)
    local itemType = Bag.MoneyType[moneyId]
    if not itemType then
        return false
    end
    return self:RemoveItems({itemType = amount})
end

---@param moneyId number 货币类型
---@param amount number 货币数量
---@return boolean 是否成功
function Bag:AddMoney(moneyId, amount)
    local itemType = Bag.MoneyType[moneyId]
    if not itemType then
        return false
    end
    return self:AddItem(itemType:ToItem(amount))
end

---@param moneyId number 货币类型
---@return number 货币总数量
function Bag:GetMoneyAmount(moneyId)
    local itemType = Bag.MoneyType[moneyId]
    if not itemType then
        return 0
    end
    return self:GetItemAmount(itemType)
end

return Bag

