--- V109 miniw-haima
--- 材料类，继承自物品基类

local game = game
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const
local ItemBase = require(MainStorage.code.server.items.ItemBase)   ---@type ItemBase

---@class MaterialItem : ItemBase
---@field mat_id number 材料ID
---@field mat_type string 材料类型
---@field use_for table 材料用途描述
---@field num number 堆叠数量
local MaterialItem = setmetatable({}, {__index = ItemBase})
MaterialItem.__index = MaterialItem

-- 材料类型
MaterialItem.MAT_TYPE = {
    FRAGMENT = "fragment",  -- 碎片类
    ORE = "ore",            -- 矿石类
    HERB = "herb",          -- 草药类
    GEM = "gem",            -- 宝石类
    RECIPE = "recipe",      -- 配方类
    BOX = "box"             -- 宝箱类
}

--- 创建一个新材料实例
---@param data table 材料初始数据
---@return MaterialItem 材料实例
function MaterialItem.new(data)
    local self = setmetatable(ItemBase.new(data), MaterialItem)
    
    -- 材料特有属性
    self.mat_id = data.mat_id or common_const.MAT_ID.FRAGMENT
    self.mat_type = data.mat_type or MaterialItem.MAT_TYPE.FRAGMENT
    self.use_for = data.use_for or {desc = "用于合成与强化装备"}
    self.num = data.num or 1
    
    -- 确保分类正确
    self.category = ItemBase.CATEGORY.MATERIAL
    self.itype = common_const.ITEM_TYPE.MAT
    
    return self
end

--- 重写：获取物品描述
---@return string 物品描述
function MaterialItem:getDescription()
    local parts = {}
    
    -- 添加基本信息
    table.insert(parts, self:getQualityStr() .. ' ' .. (self.name or '') .. '\n\n')
    
    -- 添加数量信息
    table.insert(parts, '数量: ' .. self.num .. '\n')
    
    -- 添加材料类型
    local typeText = "未知材料"
    if self.mat_type == MaterialItem.MAT_TYPE.FRAGMENT then
        typeText = "碎片"
    elseif self.mat_type == MaterialItem.MAT_TYPE.ORE then
        typeText = "矿石"
    elseif self.mat_type == MaterialItem.MAT_TYPE.HERB then
        typeText = "草药"
    elseif self.mat_type == MaterialItem.MAT_TYPE.GEM then
        typeText = "宝石"
    elseif self.mat_type == MaterialItem.MAT_TYPE.RECIPE then
        typeText = "配方"
    elseif self.mat_type == MaterialItem.MAT_TYPE.BOX then
        typeText = "宝箱"
    end
    table.insert(parts, '材料类型: ' .. typeText .. '\n')
    
    -- 添加用途信息
    if self.use_for and self.use_for.desc then
        table.insert(parts, '\n用途: ' .. self.use_for.desc .. '\n')
    end
    
    -- 宝箱特殊描述
    if self.mat_type == MaterialItem.MAT_TYPE.BOX then
        table.insert(parts, '\n可以右键点击打开宝箱获得随机装备\n')
    end
    
    return table.concat(parts)
end

--- 重写：是否可以使用
---@return boolean 是否可使用
function MaterialItem:canUse()
    -- 只有宝箱类材料可以直接使用
    return self.mat_type == MaterialItem.MAT_TYPE.BOX
end

--- 重写：是否可以分解
---@return boolean 是否可分解
function MaterialItem:canDecompose()
    -- 材料通常不可分解
    return false
end

--- 物品使用效果
---@param player any 使用物品的玩家
---@return boolean 使用是否成功
---@return string 
function MaterialItem:onUse(player)
    -- 检查材料是否可使用
    if not self:canUse() then
        return false, "这个材料不能直接使用"
    end
    
    -- 材料使用逻辑
    if self.mat_type == MaterialItem.MAT_TYPE.BOX then
        -- 宝箱类材料处理
        -- 注意：实际的宝箱开启逻辑在物品操作器中处理
        -- 这里只返回可以开启的标志
        local qualityStr = self:getQualityStr()
        return true, "准备开启" .. qualityStr .. "宝箱"
        
    elseif self.mat_type == MaterialItem.MAT_TYPE.RECIPE then
        -- 配方类材料处理
        if self:canCraft() then
            -- 注意：实际的合成逻辑在物品操作器或合成系统中处理
            return true, "可以使用此配方进行合成"
        else
            return false, "缺少合成所需材料"
        end
    end
    
    -- 其他类型材料通常不能直接使用
    return false, "该材料无法直接使用，可用于合成或强化"
end
--- 材料是否可以合成
---@return boolean 是否可合成
function MaterialItem:canCraft()
    -- 配方类材料可以合成
    return self.mat_type == MaterialItem.MAT_TYPE.RECIPE
end

--- 是否可以堆叠
---@return boolean 是否可堆叠
function MaterialItem:canStack()
    return true  -- 所有材料都可以堆叠
end

--- 最大堆叠数量
---@return number 最大堆叠数量
function MaterialItem:getMaxStackSize()
    if self.mat_type == MaterialItem.MAT_TYPE.BOX then
        return 10  -- 宝箱最多堆叠10个
    elseif self.mat_type == MaterialItem.MAT_TYPE.RECIPE then
        return 5   -- 配方最多堆叠5个
    else
        return 999 -- 其他材料最多堆叠999个
    end
end

--- 尝试堆叠另一个材料
---@param otherMaterial MaterialItem 另一个材料
---@return boolean 是否成功堆叠
function MaterialItem:tryStack(otherMaterial)
    if not self:canStack() then
        return false
    end
    
    -- 检查材料是否相同
    if self.mat_id ~= otherMaterial.mat_id or 
       self.quality ~= otherMaterial.quality or
       self.mat_type ~= otherMaterial.mat_type then
        return false
    end
    
    -- 检查是否超过最大堆叠数
    local maxStack = self:getMaxStackSize()
    if self.num + otherMaterial.num > maxStack then
        return false
    end
    
    -- 合并数量
    self.num = self.num + otherMaterial.num
    return true
end

--- 重写：获取序列化数据(用于存储)
---@return table 序列化数据
function MaterialItem:serialize()
    local data = ItemBase.serialize(self)
    
    -- 添加材料特有字段
    data.mat_id = self.mat_id
    data.mat_type = self.mat_type
    data.use_for = self.use_for
    data.num = self.num
    
    return data
end

--- 从已存在的物品数据创建材料对象
---@param itemData table 物品数据
---@return MaterialItem 材料对象
function MaterialItem.fromData(itemData)
    return MaterialItem.new(itemData)
end

--- 创建一个碎片材料
---@param quality number 品质
---@param amount number 数量
---@return MaterialItem 材料对象
function MaterialItem.createFragment(quality, amount)
    local data = {
        uuid = gg.create_uuid('mat'),
        quality = quality or 1,
        level = 1,
        mat_id = common_const.MAT_ID.FRAGMENT,
        mat_type = MaterialItem.MAT_TYPE.FRAGMENT,
        name = "魔力碎片",
        num = amount or 1,
        asset = common_config.assets_dict.icon_mat1,
        use_for = {desc = "用于合成与强化装备"}
    }
    
    return MaterialItem.new(data)
end

--- 创建一个宝箱
---@param quality number 品质
---@param level number 等级
---@return MaterialItem 宝箱对象
function MaterialItem.createBox(quality, level)
    local data = {
        uuid = gg.create_uuid('box'),
        quality = quality or gg.rand_qulity(),
        level = level or gg.rand_int_between(1, 99),
        mat_id = common_const.MAT_ID.BOX,
        mat_type = MaterialItem.MAT_TYPE.BOX,
        name = '宝箱-' .. common_config.const_quality_name[quality or 1],
        asset = common_config.assets_dict.icon_box,
        use_for = {desc = "打开可获得随机装备"}
    }
    
    return MaterialItem.new(data)
end

return MaterialItem