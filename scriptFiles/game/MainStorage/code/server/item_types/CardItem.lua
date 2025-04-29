--- V109 miniw-haima
--- 卡片类，继承自物品基类

local game = game
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const
local ItemBase = require(MainStorage.code.server.items.ItemBase)   ---@type ItemBase

---@class CardItem : ItemBase
---@field card_id number 卡片ID
---@field card_type string 卡片类型
---@field card_effect table 卡片效果
---@field equippable boolean 是否可装备
---@field slot_type string 装备栏位类型
---@field unique boolean 是否唯一
local CardItem = setmetatable({}, {__index = ItemBase})
CardItem.__index = CardItem

-- 卡片类型常量
CardItem.CARD_TYPE = {
    NORMAL = "normal",        -- 普通卡片
    ABILITY = "ability",      -- 能力卡片
    EQUIPMENT = "equipment",  -- 装备卡片
    EVENT = "event",          -- 事件卡片
    MONSTER = "monster",      -- 怪物卡片
    BOSS = "boss"             -- BOSS卡片
}

-- 装备栏位类型
CardItem.SLOT_TYPE = {
    ACTIVE = "active",        -- 主动栏位
    PASSIVE = "passive",      -- 被动栏位
    SPECIAL = "special"       -- 特殊栏位
}

--- 创建一个新卡片实例
---@param data table 卡片初始数据
---@return CardItem 卡片实例
function CardItem.new(data)
    local self = setmetatable(ItemBase.new(data), CardItem)
    
    -- 卡片特有属性
    self.card_id = data.card_id or 0
    self.card_type = data.card_type or CardItem.CARD_TYPE.NORMAL
    self.card_effect = data.card_effect or {}
    self.equippable = data.equippable ~= false  -- 默认为true，可装备
    self.slot_type = data.slot_type or CardItem.SLOT_TYPE.PASSIVE
    self.unique = data.unique == true  -- 默认为false，不唯一
    
    -- 确保分类正确
    self.category = ItemBase.CATEGORY.CARD
    self.itype = common_const.ITEM_TYPE.CARD
    
    return self
end

--- 重写：获取物品描述
---@return string 物品描述
function CardItem:getDescription()
    local parts = {}
    
    -- 添加基本信息
    table.insert(parts, self:getQualityStr() .. ' ' .. (self.name or '') .. '\n\n')
    
    -- 添加卡片类型
    local typeText = "普通卡片"
    if self.card_type == CardItem.CARD_TYPE.ABILITY then
        typeText = "能力卡片"
    elseif self.card_type == CardItem.CARD_TYPE.EQUIPMENT then
        typeText = "装备卡片"
    elseif self.card_type == CardItem.CARD_TYPE.EVENT then
        typeText = "事件卡片"
    elseif self.card_type == CardItem.CARD_TYPE.MONSTER then
        typeText = "怪物卡片"
    elseif self.card_type == CardItem.CARD_TYPE.BOSS then
        typeText = "BOSS卡片"
    end
    table.insert(parts, '类型: ' .. typeText .. '\n')
    
    -- 添加卡片效果
    table.insert(parts, '\n效果:\n')
    
    if next(self.card_effect) then
        for effectName, effectValue in pairs(self.card_effect) do
            local effectText = self:formatCardEffect(effectName, effectValue)
            table.insert(parts, effectText .. '\n')
        end
    else
        table.insert(parts, '无特殊效果\n')
    end
    
    -- 添加唯一性标记
    if self.unique then
        table.insert(parts, '\n[唯一] 只能装备一张\n')
    end
    
    -- 添加装备信息
    if self.equippable then
        local slotText = "被动"
        if self.slot_type == CardItem.SLOT_TYPE.ACTIVE then
            slotText = "主动"
        elseif self.slot_type == CardItem.SLOT_TYPE.SPECIAL then
            slotText = "特殊"
        end
        table.insert(parts, '可装备到' .. slotText .. '卡槽\n')
    end
    
    return table.concat(parts)
end

--- 格式化卡片效果
---@param effectName string 效果名称
---@param effectValue any 效果值
---@return string 格式化后的效果文本
function CardItem:formatCardEffect(effectName, effectValue)
    local effectText = ""
    
    -- 效果名称映射表
    local effectNameMap = {
        hp_bonus = "生命上限",
        mp_bonus = "魔法上限",
        str_bonus = "力量",
        int_bonus = "智力",
        agi_bonus = "敏捷",
        vit_bonus = "体力",
        crit_rate = "暴击率",
        crit_damage = "暴击伤害",
        move_speed = "移动速度",
        attack_speed = "攻击速度",
        spell_power = "法术强度",
        physical_resist = "物理抗性",
        magic_resist = "魔法抗性",
        active_skill = "主动技能",
        passive_skill = "被动技能"
    }
    
    local effectNameText = effectNameMap[effectName] or effectName
    
    -- 根据效果类型格式化
    if type(effectValue) == "number" then
        -- 数值型效果
        local sign = effectValue > 0 and "+" or ""
        
        -- 百分比效果
        if effectName:find("rate") or effectName:find("speed") then
            effectText = effectNameText .. ": " .. sign .. effectValue * 100 .. "%"
        else
            effectText = effectNameText .. ": " .. sign .. effectValue
        end
    elseif type(effectValue) == "string" then
        -- 字符串型效果
        effectText = effectNameText .. ": " .. effectValue
    elseif type(effectValue) == "table" then
        -- 表格型效果
        if effectValue.name then
            effectText = effectNameText .. ": " .. effectValue.name
        else
            effectText = effectNameText .. ": 复杂效果"
        end
    else
        effectText = effectNameText .. ": " .. tostring(effectValue)
    end
    
    return effectText
end

--- 重写：是否可以使用
---@return boolean 是否可使用
function CardItem:canUse()
    -- 对卡片来说，使用是指装备或激活效果
    return self.equippable
end

--- 物品使用效果
---@param player CPlayer 使用物品的玩家
---@return boolean 使用是否成功
---@return string 使用结果消息
function CardItem:onUse(player)
    -- 检查物品是否可使用
    if not self:canUse() then
        return false, "该卡片不能使用"
    end
    
    -- 根据卡片类型执行不同的使用逻辑
    if self.card_type == CardItem.CARD_TYPE.BOX then
        -- 宝箱类卡片逻辑
        return true, "成功使用宝箱卡片"
        
    elseif self.slot_type == CardItem.SLOT_TYPE.ACTIVE and self:canActivate() then
        -- 主动类卡片逻辑
        local activated = self:activate(player)
        if activated then
            return true, "成功激活卡片效果"
        else
            return false, "无法激活卡片效果"
        end
        
    elseif self.equippable then
        -- 可装备卡片逻辑
        -- 注意：实际装备操作通常在物品操作器中处理
        -- 这里只返回可装备的标志
        return true, "该卡片可以装备"
    end
    
    return false, "无法使用此卡片"
end

--- 是否可以激活(使用主动效果)
---@return boolean 是否可激活
function CardItem:canActivate()
    return self.slot_type == CardItem.SLOT_TYPE.ACTIVE and next(self.card_effect) ~= nil
end

--- 激活卡片效果
---@param player any 玩家对象
---@return boolean 是否成功激活
function CardItem:activate(player)
    if not self:canActivate() then
        return false
    end
    
    -- 实现卡片激活效果
    local activatedEffect = false
    
    if self.card_effect.active_skill then
        -- 使用主动技能
        local skillId = self.card_effect.active_skill
        if type(skillId) == "number" then
            -- 直接使用技能ID
            -- 这里需要调用技能系统
            activatedEffect = true
        elseif type(skillId) == "table" and skillId.id then
            -- 使用技能表格
            -- 这里需要调用技能系统
            activatedEffect = true
        end
    end
    
    return activatedEffect
end

--- 获取卡片被动属性
---@return table 属性表
function CardItem:getPassiveAttributes()
    local attributes = {}
    
    -- 复制所有数值型效果作为被动属性
    for effectName, effectValue in pairs(self.card_effect) do
        if type(effectValue) == "number" and effectName ~= "active_skill" and effectName ~= "passive_skill" then
            attributes[effectName] = effectValue
        end
    end
    
    return attributes
end

--- 重写：获取序列化数据(用于存储)
---@return table 序列化数据
function CardItem:serialize()
    local data = ItemBase.serialize(self)
    
    -- 添加卡片特有字段
    data.card_id = self.card_id
    data.card_type = self.card_type
    data.card_effect = self.card_effect
    data.equippable = self.equippable
    data.slot_type = self.slot_type
    data.unique = self.unique
    
    return data
end

--- 从已存在的物品数据创建卡片对象
---@param itemData table 物品数据
---@return CardItem 卡片对象
function CardItem.fromData(itemData)
    return CardItem.new(itemData)
end

--- 创建一个能力卡片
---@param cardId number 卡片ID
---@param name string 卡片名称
---@param quality number 品质
---@param effects table 效果表
---@return CardItem 卡片对象
function CardItem.createAbilityCard(cardId, name, quality, effects)
    local data = {
        uuid = gg.create_uuid('card'),
        card_id = cardId,
        name = name,
        quality = quality or 1,
        level = quality or 1,
        card_type = CardItem.CARD_TYPE.ABILITY,
        card_effect = effects or {},
        equippable = true,
        slot_type = effects.active_skill and CardItem.SLOT_TYPE.ACTIVE or CardItem.SLOT_TYPE.PASSIVE,
        asset = "sandboxSysId://items/icon10001.png"  -- 替换为实际的卡片图标
    }
    
    return CardItem.new(data)
end

--- 创建一个怪物卡片
---@param monsterId number 怪物ID
---@param quality number 品质
---@return CardItem 卡片对象
function CardItem.createMonsterCard(monsterId, quality)
    -- 获取怪物配置
    local monsterConfig = common_config.dict_monster_config[monsterId]
    if not monsterConfig then
        return nil
    end
    
    -- 根据怪物生成卡片效果
    local effects = {}
    
    -- 添加属性加成
    effects.str_bonus = math.floor(monsterConfig.str * 0.1)
    effects.int_bonus = math.floor(monsterConfig.int * 0.1)
    effects.agi_bonus = math.floor(monsterConfig.agi * 0.1)
    effects.vit_bonus = math.floor(monsterConfig.vit * 0.1)
    
    -- 如果是BOSS，加入特殊效果
    local cardType = CardItem.CARD_TYPE.MONSTER
    if monsterConfig.is_boss then
        cardType = CardItem.CARD_TYPE.BOSS
        effects.passive_skill = "怪物天赋: " .. monsterConfig.name
    end
    
    local data = {
        uuid = gg.create_uuid('card'),
        card_id = 10000 + monsterId,
        name = monsterConfig.name .. "卡片",
        quality = quality or monsterConfig.level > 50 and 4 or (math.floor(monsterConfig.level / 15) + 1),
        level = monsterConfig.level,
        card_type = cardType,
        card_effect = effects,
        equippable = true,
        slot_type = CardItem.SLOT_TYPE.PASSIVE,
        asset = "sandboxSysId://items/icon10002.png"  -- 替换为实际的卡片图标
    }
    
    return CardItem.new(data)
end

--- 创建一个事件卡片
---@param eventId number 事件ID
---@param name string 事件名称
---@param description string 事件描述
---@return CardItem 卡片对象
function CardItem.createEventCard(eventId, name, description)
    local data = {
        uuid = gg.create_uuid('card'),
        card_id = 20000 + eventId,
        name = name,
        quality = 3,  -- 事件卡片默认为3级品质
        level = 1,
        card_type = CardItem.CARD_TYPE.EVENT,
        card_effect = {
            event_id = eventId,
            description = description
        },
        equippable = false,  -- 事件卡片不可装备
        asset = "sandboxSysId://items/icon10003.png"  -- 替换为实际的卡片图标
    }
    
    return CardItem.new(data)
end

return CardItem
