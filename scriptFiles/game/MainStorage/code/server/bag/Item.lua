local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local ItemQualityConfig = require(MainStorage.code.common.config.ItemQualityConfig) ---@type ItemQualityConfig


---@class SerializedItem
---@field itype string|ItemType
---@field el number
---@field quality string
---@field amount number
---@field uuid string


---@class Item:Class
---@field itemType ItemType 物品类型
---@field enhanceLevel number 强化等级
---@field amount number 数量
---@field uuid string 唯一标识
---@field quality ItemQuality 品质
---@field level number 等级
---@field pos number 装备位置
---@field itype string 物品类型
---@field name string 物品名称
---@field New fun():Item
local Item = ClassMgr.Class("Item")

function Item:GetToStringParams()
    return {
        name = self.itemType.name,
        amount = self.amount
    }
end

function Item:OnInit()
    self.itemType = nil
    self.amount = 0
    self.uuid = ""
    self.slot = nil

    -----------装备-----------
    self.quality = nil
    self.enhanceLevel = 0
end

function Item:PrintContent()
    local content = {
        (self.itemType and self.itemType.name or "未知") .. "(" .. self.amount .. ")"
    }

    if self:IsEquipment() then
        if self.quality then
            table.insert(content, "品质: " .. (self.quality and self.quality.name or "未知"))
        end
        if self.enhanceLevel > 0 then
            table.insert(content, "强化: " .. self.enhanceLevel)
        end
    end

    return table.concat(content, ", ")
end

---@param data SerializedItem 物品数据
function Item:Load(data)
    if not data or not data.itype then
        return
    end
    self.uuid = data.uuid or ""
    self.amount = data.amount or 0
    self.enhanceLevel = data.el or 0
    if type(data.itype) == "string" then
        self.itemType = ItemTypeConfig.Get(data.itype)
    else
        self.itemType = data.itype
    end

    if self:IsEquipment() then
        if data.quality == nil then
            self.quality = ItemQualityConfig:GetRandomQuality()
        else
            self.quality = ItemQualityConfig.Get(data.quality)
        end
    end
end

function Item:IsEquipment()
    return self.itemType.equipmentSlot > 0
end

function Item:IsConsumable()
    return self.itemType.useCommands == nil
end

---@return SerializedItem 物品数据
function Item:Save()
    local d = {
        uuid = self.uuid,
        amount = self.amount,
        el = self.enhanceLevel,
        itype = self.itemType.name,
    }
    if self.quality then
        d.quality = self.quality.name
    end
    return d
end

---@return ItemType 物品类型
function Item:GetItemType()
    return self.itemType
end

---@return table<string, number> 物品属性
function Item:GetStat()
    if not self.itemType then
        return {}
    end

    local baseAttributes = self.itemType.attributes
    local enhanceRate = self.itemType.enhanceRate
    local stats = {}

    -- 计算基础属性
    for attrId, value in pairs(baseAttributes) do
        stats[attrId] = value
    end

    -- 计算强化加成
    if self.enhanceLevel > 0 and enhanceRate > 0 then
        local enhanceMultiplier = 1 + (self.enhanceLevel * enhanceRate)
        for attrId, value in pairs(baseAttributes) do
            stats[attrId] = value * enhanceMultiplier
        end
    end

    if self.quality then
        for attrId, value in pairs(baseAttributes) do
            stats[attrId] = value * self.quality.multiplier
        end
    end

    return stats
end

---@return number 物品战力
function Item:GetPower()
    if not self.itemType then
        return 0
    end

    local stats = self:GetStat()
    local power = self.itemType.extraPower

    -- 计算属性带来的战力
    for _, value in pairs(stats) do
        power = power + value
    end

    return power
end

---@param level number 强化等级
function Item:SetEnhanceLevel(level)
    if not self.itemType then
        return
    end

    local maxLevel = self.itemType.maxEnhanceLevel
    self.enhanceLevel = math.min(math.max(0, level), maxLevel)
end

---@return number 当前强化等级
function Item:GetEnhanceLevel()
    return self.enhanceLevel
end

---@return number 物品数量
function Item:GetAmount()
    return self.amount
end

---@param amount number 设置物品数量
function Item:SetAmount(amount)
    self.amount = math.max(0, amount)
end

---@return string 物品唯一标识
function Item:GetUUID()
    return self.uuid
end

---@return ItemQuality 物品品质
function Item:GetQuality()
    return self.quality
end

---@return number 物品等级
function Item:GetLevel()
    return self.level
end

---@return number 装备位置
function Item:GetPos()
    return self.pos
end

---@return string 物品类型
function Item:GetType()
    return self.itype
end

---@return string 物品名称
function Item:GetName()
    return self.itemType.name
end

return Item