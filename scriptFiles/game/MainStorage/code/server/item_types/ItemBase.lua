--- V109 miniw-haima
--- 物品基类，所有物品类型都继承自此类

local game = game
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const

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
local ItemBase = {}
ItemBase.__index = ItemBase

-- 物品分类常量
ItemBase.CATEGORY = common_const.ITEM_TYPE

--- 创建一个新物品实例
---@param data table 物品初始数据
---@return ItemBase 物品实例
function ItemBase.new(data)
    local self = setmetatable({}, ItemBase)
    
    -- 基本属性
    self.uuid = data.uuid or gg.create_uuid('item')
    self.itype = data.itype
    self.category = data.category
    self.quality = data.quality or 1
    self.level = data.level or 1
    self.name = data.name or ""
    self.asset = data.asset or ""
    self.num = data.num or 1
    self.pos = data.pos or 0  -- 装备位置
    
    return self
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

--- 从已存在的物品数据创建物品对象
---@param itemData table 物品数据
---@return ItemBase 物品对象
function ItemBase.fromData(itemData)
    return ItemBase.new(itemData)
    
end

return ItemBase