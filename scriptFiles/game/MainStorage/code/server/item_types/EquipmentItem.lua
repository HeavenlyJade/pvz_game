--- V109 miniw-haima
--- 装备类，继承自物品基类

local game = game
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const
local ItemBase = require(MainStorage.code.server.item_types.ItemBase)   ---@type ItemBase

---@class EquipmentItem : ItemBase
---@field attack number? 攻击力
---@field attack2 number? 攻击上限
---@field defence number? 防御力
---@field defence2 number? 防御上限
---@field spell number? 法术强度
---@field spell2 number? 法术上限
---@field attrs table? 附加属性
---@field pos number? 装备位置
local EquipmentItem = setmetatable({}, {__index = ItemBase})
EquipmentItem.__index = EquipmentItem

--- 创建一个新装备实例
---@param data table 装备初始数据
---@return EquipmentItem 装备实例
function EquipmentItem.new(data)
    local self = setmetatable(ItemBase.new(data), EquipmentItem)
    
    -- 装备特有属性
    self.attack = data.attack or 0
    self.attack2 = data.attack2 or 0
    self.defence = data.defence or 0
    self.defence2 = data.defence2 or 0
    self.spell = data.spell or 0
    self.spell2 = data.spell2 or 0
    self.attrs = data.attrs or {}
    self.pos = data.pos or 0  -- 装备位置
    
    -- 确保分类正确
    self.category = ItemBase.CATEGORY.EQUIPMENT
    self.itype = common_const.ITEM_TYPE.EQUIPMENT
    
    return self
end

--- 获取装备位置描述
---@return string 装备位置描述
function EquipmentItem:getPosStr()
    if self.pos > 0 then
        return common_config.const_ui_eq_pos[self.pos] or '未知'
    end
    return ""
end

--- 获取属性描述
---@param attr table 属性数据
---@return string 属性描述
function EquipmentItem:getAttrStr(attr)
    -- {k=r2 v=16}
    local config = common_config.common_att_dict[attr.k]
    local ret = config.des .. ':' .. attr.v
    if config.per == 1 then
        ret = ret .. '%'
    end
    ret = ret .. '\n'
    return ret
end

--- 重写：获取物品描述
---@return string 物品描述
function EquipmentItem:getDescription()
    local parts = {}
    
    -- 添加基本信息
    table.insert(parts, self:getQualityStr() .. ' 等级' .. self.level .. '\n' .. (self.name or '') .. '\n\n')
    
    -- 添加装备位置
    if self.pos > 0 then
        table.insert(parts, '装备位置: ' .. self:getPosStr() .. '\n')
    end
    
    -- 添加攻击信息
    if self.attack > 0 or self.attack2 > 0 then
        table.insert(parts, '攻击: ' .. self.attack .. ' - ' .. self.attack2 .. '\n')
    end
    
    -- 添加法术信息
    if self.spell > 0 or self.spell2 > 0 then
        table.insert(parts, '法强: ' .. self.spell .. ' - ' .. self.spell2 .. '\n')
    end
    
    -- 添加防御信息
    if self.defence > 0 or self.defence2 > 0 then
        table.insert(parts, '防御: ' .. self.defence .. ' - ' .. self.defence2 .. '\n')
    end
    
    -- 添加属性信息
    if self.attrs then
        table.insert(parts, '\n附加属性:\n')
        for _, attr in pairs(self.attrs) do
            table.insert(parts, self:getAttrStr(attr))
        end
    end
    
    return table.concat(parts)
end

--- 重写：是否可以装备在指定位置
---@param position number 装备位置
---@return boolean 是否可装备
function EquipmentItem:canEquipAt(position)
    return self.pos == position
end

--- 重写：是否可以使用
---@return boolean 是否可使用
function EquipmentItem:canUse()
    gg.log("canUse",self.pos)
    return self.pos > 0  -- 有装备位置即表示可装备
end

--- 重写：是否可以分解
---@return boolean 是否可分解
function EquipmentItem:canDecompose()
    return true  -- 所有装备都可以分解
end

--- 计算分解可获得的材料数量
---@return number 材料数量
---@return number 材料品质
function EquipmentItem:calculateDecomposeYield()
    local matQuality = 1  -- 1=魔力碎片
    local matNum = self.quality * self.level
    return matNum, matQuality
end

--- 物品使用效果(对装备来说是穿戴)
---@param player CPlayer 使用物品的玩家
---@return boolean 使用是否成功
---@return string 使用结果消息
function EquipmentItem:onUse(player)
    -- 检查装备是否可使用
    if not self:canUse() then
        return false, "该装备不能使用"
    end
    
    -- 检查玩家等级是否足够
    if player.level < self.level then
        return false, "等级不足，需要等级 " .. self.level
    end
    
    -- 检查装备位置
    if not self.pos or self.pos <= 0 then
        return false, "该装备没有指定装备位置"
    end
    
    -- -- 检查职业限制
    -- if self.class_limit and self.class_limit ~= player.player_config.class then
    --     return false, "职业不符，无法装备"
    -- end
    
    -- 对于可装备的装备，返回可装备的信息
    -- 注意：实际的装备操作将在物品操作器中处理
    local posName = self:getPosStr() or "未知位置"
    return true, "可以装备到" .. posName
end

--- 重写：获取序列化数据(用于存储)
---@return table 序列化数据
function EquipmentItem:serialize()
    local data = ItemBase.serialize(self)
    
    -- 添加装备特有字段
    data.attack = self.attack
    data.attack2 = self.attack2
    data.defence = self.defence
    data.defence2 = self.defence2
    data.spell = self.spell
    data.spell2 = self.spell2
    data.attrs = self.attrs
    data.pos = self.pos
    
    return data
end

--- 从已存在的物品数据创建装备对象
---@param itemData table 物品数据
---@return EquipmentItem 装备对象
function EquipmentItem.fromData(itemData)
    return EquipmentItem.new(itemData)
end

--- 创建一个随机装备
---@param quality number 品质
---@param level number 等级
---@param pos number? 装备位置
---@return EquipmentItem 装备对象
function EquipmentItem.createRandom(quality, level, pos)
    local data = {
        uuid = gg.create_uuid('eq'),
        quality = quality or gg.rand_qulity(),
        level = level or 1,
        pos = pos or 0
    }
    
    -- 根据品质和等级生成属性
    local attrMultiplier = quality * (1 + level * 0.1)
    
    data.attack = math.floor(5 * attrMultiplier)
    data.attack2 = math.floor(10 * attrMultiplier)
    data.defence = math.floor(3 * attrMultiplier)
    data.defence2 = math.floor(6 * attrMultiplier)
    data.spell = math.floor(4 * attrMultiplier)
    data.spell2 = math.floor(8 * attrMultiplier)
    
    -- 随机装备名称
    local posName = "武器"
    if pos then
        posName = common_config.const_ui_eq_pos[pos] or "装备"
    end
    
    local qualityName = common_config.const_quality_name[quality] or "普通"
    data.name = qualityName .. "的" .. posName
    
    -- 生成随机词条
    data.attrs = {}
    local numAttrs = quality + math.floor(level / 10)
    numAttrs = math.min(numAttrs, 6)  -- 最多6个词条
    
    local allAttrs = {"str", "int", "agi", "vit", "cr", "crd", "r3", "r4", "r5", "r6"}
    for i = 1, numAttrs do
        local attrKey = allAttrs[math.random(1, #allAttrs)]
        local attrValue = math.floor(5 * attrMultiplier * math.random(8, 12) / 10)
        table.insert(data.attrs, {k = attrKey, v = attrValue})
    end
    
    -- 设置资源路径
    if pos and common_config.equipment_icons and common_config.equipment_icons[pos] then
        data.asset = common_config.equipment_icons[pos][math.random(1, #common_config.equipment_icons[pos])]
    else
        data.asset = "sandboxSysId://items/icon12005.png"  -- 默认图标
    end
    
    return EquipmentItem.new(data)
end

return EquipmentItem