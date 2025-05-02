--- V109 miniw-haima
--- 物品基类，所有物品类型都继承自此类

local game = game
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const
local CommonModule = require(MainStorage.code.common.CommonModule)    ---@type CommonModule

---@class ItemBase
---@field uuid string 物品唯一ID
---@field itype number 物品类型
---@field category string 物品分类
---@field quality number 品质
---@field level number 等级
---@field name string 名称
---@field asset string 资源路径
---@field num number? 堆叠数量
---@field pos number? 装备位置
local ItemBase = CommonModule.Class("ItemBase")

-- 物品分类常量
ItemBase.CATEGORY = common_const.ITEM_TYPE

--- 创建一个新物品实例（OnInit替代原来的new方法）
---@param data table 物品初始数据
function ItemBase:OnInit(data)
    -- 基本属性
    self.uuid = data.uuid or gg.create_uuid('item')
    self.itype = data.itype
    self.category = data.category
    self.quality = data.quality
    self.level = data.level
    self.name = data.name
    self.asset = data.asset
    self.num = data.num
    self.pos = data.pos  -- 物品位置
    self.maxLevel = data.maxLevel or 100
    self.enhanceLevel = data.enhanceLevel
end

--- 获取物品描述
---@return string 物品描述
function ItemBase:getDescription()
    local parts = {}
    
    -- 添加基本信息
    table.insert(parts, self:getQualityStr() .. ' 等级' .. self.level .. '\n' .. (self.name or '') .. '\n\n')
    
    return table.concat(parts)
end

--- 获取品质文字描述
---@return string 品质描述
function ItemBase:getQualityStr()
    return common_config.const_quality_name[self.quality] or '(未知)'
end

--- 获取品质颜色
---@return ColorQuad 品质对应的颜色
function ItemBase:getQualityColor()
    return gg.getQualityColor(self.quality)
end

--- 是否可以使用
---@return boolean 是否可使用
function ItemBase:canUse()
    return false  -- 基类默认不可使用，子类可重写
end

--- 是否可以分解
---@return boolean 是否可分解
function ItemBase:canDecompose()
    return false  -- 基类默认不可分解，子类可重写
end

--- 物品使用效果
---@param player CPlayer 使用物品的玩家
---@return boolean 使用是否成功
---@return string 使用结果消息
function ItemBase:onUse(player)
    -- 基类中默认实现
    -- 子类应该重写此方法以提供特定的物品使用逻辑
    
    -- 检查物品是否可使用
    if not self:canUse() then
        return false, "该物品不能使用"
    end
    
    -- 基类默认返回失败，因为基础物品没有具体使用行为
    return false, "无法使用此类型的物品"
end

--- 获取序列化数据(用于存储)
---@return table 序列化数据
function ItemBase:serialize()
    local data = {
        uuid = self.uuid,
        itype = self.itype,
        category = self.category,
        quality = self.quality,
        level = self.level,
        name = self.name,
        asset = self.asset,
        num = self.num
    }
    
    return data
end

--- 获取物品属性/统计数据
---@return table<string, number> 计算后的物品属性
function ItemBase:GetStat()
    local stats = {}
    
    -- 基类中实现通用逻辑，子类可以覆盖此方法以提供特定实现
    if self.attrs then
        for _, attr in pairs(self.attrs) do
            stats[attr.k] = attr.v
        end
    end
    
    -- 添加基础战斗属性（如果存在）
    if self.attack then stats.attack = self.attack end
    if self.attack2 then stats.attack2 = self.attack2 end
    if self.defence then stats.defence = self.defence end
    if self.defence2 then stats.defence2 = self.defence2 end
    if self.spell then stats.spell = self.spell end
    if self.spell2 then stats.spell2 = self.spell2 end
    
    -- 如果适用，应用强化倍率
    if self.enhanceLevel and self.enhanceLevel > 0 then
        local enhanceRate = 0.1 -- 每级10%，根据需要调整
        local multiplier = 1 + (self.enhanceLevel * enhanceRate)
        
        for k, v in pairs(stats) do
            stats[k] = math.floor(v * multiplier)
        end
    end
    
    return stats
end

--- 计算物品战力/分数
---@return number 物品战力值
function ItemBase:GetPower()
    local stats = self:GetStat()
    local power = 0
    
    -- 来自品质和等级的基础战力
    power = power + ((self.quality or 1) * 10) + ((self.level or 1) * 5)
    
    -- 添加属性带来的战力
    for _, value in pairs(stats) do
        power = power + value
    end
    
    return math.floor(power)
end

--- 设置物品强化等级
---@param level number 要设置的强化等级
function ItemBase:SetEnhanceLevel(level)
    -- 基于品质的最大强化等级

    self.enhanceLevel = math.min(math.max(0, level), self.maxLevel)
    
    -- 保存对象状态变更
    return self.enhanceLevel
end

--- 获取当前强化等级
---@return number 当前强化等级
function ItemBase:GetEnhanceLevel()
    return self.enhanceLevel
end

--- 获取物品数量
---@return number 物品数量
function ItemBase:GetAmount()
    return self.num
end

--- 设置物品数量
---@param amount number 要设置的物品数量
function ItemBase:SetAmount(amount)
    self.num = math.max(0, amount)
end

--- 获取物品唯一标识
---@return string 物品唯一标识
function ItemBase:GetUUID()
    return self.uuid
end

--- 获取物品品质
---@return number 物品品质
function ItemBase:GetQuality()
    return self.quality
end

--- 获取物品等级
---@return number 物品等级
function ItemBase:GetLevel()
    return self.level
end

--- 获取装备位置
---@return number 装备位置
function ItemBase:GetPos()
    return self.pos
end

--- 获取物品类型
---@return number 物品类型
function ItemBase:GetType()
    return self.itype
end

--- 获取物品名称
---@return string 物品名称
function ItemBase:GetName()
    return self.name
end


--- 从已存在的物品数据创建物品对象
---@param itemData table 物品数据
---@return ItemBase 物品对象
function ItemBase.fromData(itemData)
    return ItemBase.New(itemData)
end

return ItemBase