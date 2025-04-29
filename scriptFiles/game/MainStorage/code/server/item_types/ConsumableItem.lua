--- V109 miniw-haima
--- 消耗品类，继承自物品基类

local game = game
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const
local CommonModule = require(MainStorage.code.common.CommonModule)    ---@type CommonModule
local ItemBase = require(MainStorage.code.server.item_types.ItemBase)   ---@type ItemBase

---@class ConsumableItem : ItemBase
---@field effect_type string 效果类型
---@field effect_value number 效果值
---@field duration number 持续时间
---@field cooldown number 冷却时间
---@field buff_id number? Buff ID
---@field is_instant boolean 是否立即生效
---@field num number 堆叠数量
local ConsumableItem = CommonModule.Class("ConsumableItem", ItemBase)

-- 效果类型常量
ConsumableItem.EFFECT_TYPE = {
    HEAL = "heal",            -- 恢复生命
    MANA = "mana",            -- 恢复魔法
    HPMP = "hpmp",            -- 同时恢复生命和魔法
    BUFF = "buff",            -- 增益效果
    TELEPORT = "teleport",    -- 传送
    REVIVE = "revive",        -- 复活
    REMOVE_DEBUFF = "remove_debuff" -- 解除负面状态
}

--- 创建一个新消耗品实例
---@param data table 消耗品初始数据
function ConsumableItem:OnInit(data)
    -- 调用父类初始化
    ItemBase.OnInit(self, data)
    
    -- 消耗品特有属性
    self.effect_type = data.effect_type or ConsumableItem.EFFECT_TYPE.HEAL
    self.effect_value = data.effect_value or 0
    self.duration = data.duration or 0  -- 0表示立即生效
    self.cooldown = data.cooldown or 0  -- 使用冷却时间
    self.buff_id = data.buff_id         -- 关联的buff ID
    self.is_instant = data.is_instant ~= false  -- 默认为true，立即生效
    self.num = data.num or 1
    
    -- 确保分类正确
    self.category = ItemBase.CATEGORY.CONSUMABLE
    self.itype = common_const.ITEM_TYPE.CONSUMABLE
end

--- 重写：获取物品描述
---@return string 物品描述
function ConsumableItem:getDescription()
    local parts = {}
    
    -- 添加基本信息
    table.insert(parts, self:getQualityStr() .. ' ' .. (self.name or '') .. '\n\n')
    
    -- 添加数量信息
    table.insert(parts, '数量: ' .. self.num .. '\n')
    
    -- 添加效果描述
    local effectDesc = "无效果"
    
    if self.effect_type == ConsumableItem.EFFECT_TYPE.HEAL then
        effectDesc = "恢复生命值 " .. self.effect_value
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.MANA then
        effectDesc = "恢复魔法值 " .. self.effect_value
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.HPMP then
        effectDesc = "恢复生命值和魔法值 " .. self.effect_value
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.BUFF then
        effectDesc = "提供增益效果"
        if self.buff_id then
            -- 如果有buff配置，获取buff名称
            local buffConfig = common_config.buff_def[self.buff_id]
            if buffConfig then
                effectDesc = effectDesc .. " - " .. buffConfig.name
            end
        end
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.TELEPORT then
        effectDesc = "传送到指定位置"
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.REVIVE then
        effectDesc = "复活并恢复生命值 " .. self.effect_value .. "%"
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.REMOVE_DEBUFF then
        effectDesc = "解除所有负面状态"
    end
    
    table.insert(parts, '效果: ' .. effectDesc .. '\n')
    
    -- 添加持续时间信息
    if self.duration > 0 then
        table.insert(parts, '持续时间: ' .. self.duration .. '秒\n')
    else
        table.insert(parts, '立即生效\n')
    end
    
    -- 添加冷却时间信息
    if self.cooldown > 0 then
        table.insert(parts, '冷却时间: ' .. self.cooldown .. '秒\n')
    end
    
    -- 使用提示
    table.insert(parts, '\n右键点击使用\n')
    
    return table.concat(parts)
end

--- 重写：是否可以使用
---@return boolean 是否可使用
function ConsumableItem:canUse()
    return true  -- 所有消耗品都可以使用
end

--- 是否可以堆叠
---@return boolean 是否可堆叠
function ConsumableItem:canStack()
    return true  -- 所有消耗品都可以堆叠
end

--- 最大堆叠数量
---@return number 最大堆叠数量
function ConsumableItem:getMaxStackSize()
    return 99  -- 消耗品默认最多堆叠99个
end

--- 尝试堆叠另一个消耗品
---@param otherConsumable ConsumableItem 另一个消耗品
---@return boolean 是否成功堆叠
function ConsumableItem:tryStack(otherConsumable)
    if not self:canStack() then
        return false
    end
    
    -- 检查消耗品是否相同
    if self.name ~= otherConsumable.name or
       self.effect_type ~= otherConsumable.effect_type or
       self.effect_value ~= otherConsumable.effect_value or
       self.quality ~= otherConsumable.quality then
        return false
    end
    
    -- 检查是否超过最大堆叠数
    local maxStack = self:getMaxStackSize()
    if self.num + otherConsumable.num > maxStack then
        return false
    end
    
    -- 合并数量
    self.num = self.num + otherConsumable.num
    return true
end

--- 物品使用效果
---@param player CPlayer 使用物品的玩家
---@return boolean 使用是否成功
---@return string 使用结果消息
function ConsumableItem:onUse(player)
    if not self:canUse() then
        return false, "这个物品不能使用"
    end
    
    -- 检查玩家是否能使用该物品
    local canUse = false
    local message = ""
    
    if self.effect_type == ConsumableItem.EFFECT_TYPE.HEAL then
        -- 恢复生命值
        if player.battle_data.hp < player.battle_data.hp_max then
            player:spellHealth(self.effect_value, 0)
            message = "恢复了" .. self.effect_value .. "点生命值"
            canUse = true
        else
            return false, "生命值已满"
        end
        
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.MANA then
        -- 恢复魔法值
        if player.battle_data.mp < player.battle_data.mp_max then
            local oldMp = player.battle_data.mp
            player.battle_data.mp = math.min(player.battle_data.mp + self.effect_value, player.battle_data.mp_max)
            player:refreshHpMpBar()
            message = "恢复了" .. (player.battle_data.mp - oldMp) .. "点魔法值"
            canUse = true
        else
            return false, "魔法值已满"
        end
        
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.HPMP then
        -- 同时恢复生命值和魔法值
        local needHeal = player.battle_data.hp < player.battle_data.hp_max
        local needMana = player.battle_data.mp < player.battle_data.mp_max
        
        if needHeal or needMana then
            local oldHp = player.battle_data.hp
            local oldMp = player.battle_data.mp
            
            if needHeal then
                player:spellHealth(self.effect_value, 0)
            end
            
            if needMana then
                player.battle_data.mp = math.min(player.battle_data.mp + self.effect_value, player.battle_data.mp_max)
                player:refreshHpMpBar()
            end
            
            local hpGain = player.battle_data.hp - oldHp
            local mpGain = player.battle_data.mp - oldMp
            
            message = "恢复了" .. hpGain .. "点生命值和" .. mpGain .. "点魔法值"
            canUse = true
        else
            return false, "生命值和魔法值都已满"
        end
        
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.BUFF then
        -- 提供增益效果
        if self.buff_id then
            -- 应用buff效果
            player:buffer_create(self.buff_id, self.duration, {value = self.effect_value})
            message = "获得了增益效果: " .. (self.name or "Buff")
            canUse = true
        else
            return false, "无法应用增益效果"
        end
        
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.TELEPORT then
        -- 传送效果
        message = "传送成功"
        canUse = true
        
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.REVIVE then
        -- 复活效果
        if player.battle_data.hp <= 0 then
            local reviveHp = math.floor(player.battle_data.hp_max * self.effect_value / 100)
            player:revive()
            player.battle_data.hp = reviveHp
            player:refreshHpMpBar()
            message = "复活成功，恢复" .. reviveHp .. "点生命值"
            canUse = true
        else
            return false, "你没有倒下，不需要复活"
        end
        
    elseif self.effect_type == ConsumableItem.EFFECT_TYPE.REMOVE_DEBUFF then
        -- 解除负面状态
        message = "已清除所有负面状态"
        canUse = true
    end
    
    return canUse, message
end

--- 重写：获取序列化数据(用于存储)
---@return table 序列化数据
function ConsumableItem:serialize()
    local data = ItemBase.serialize(self)
    
    -- 添加消耗品特有字段
    data.effect_type = self.effect_type
    data.effect_value = self.effect_value
    data.duration = self.duration
    data.cooldown = self.cooldown
    data.buff_id = self.buff_id
    data.is_instant = self.is_instant
    data.num = self.num
    
    return data
end

--- 从已存在的物品数据创建消耗品对象
---@param itemData table 物品数据
---@return ConsumableItem 消耗品对象
function ConsumableItem.fromData(itemData)
    return ConsumableItem.New(itemData)
end

--- 创建一个生命药水
---@param quality number 品质
---@param amount number 恢复量
---@param stackSize number 堆叠数量
---@return ConsumableItem 消耗品对象
function ConsumableItem.createHealthPotion(quality, amount, stackSize)
    local data = {
        uuid = gg.create_uuid('consumable'),
        quality = quality or 1,
        level = quality or 1,
        name = "生命药水",
        effect_type = ConsumableItem.EFFECT_TYPE.HEAL,
        effect_value = amount or (50 * quality),
        num = stackSize or 1,
        asset = "sandboxSysId://items/icon11001.png"  -- 替换为实际的药水图标
    }
    
    return ConsumableItem.New(data)
end

--- 创建一个魔法药水
---@param quality number 品质
---@param amount number 恢复量
---@param stackSize number 堆叠数量
---@return ConsumableItem 消耗品对象
function ConsumableItem.createManaPotion(quality, amount, stackSize)
    local data = {
        uuid = gg.create_uuid('consumable'),
        quality = quality or 1,
        level = quality or 1,
        name = "魔法药水",
        effect_type = ConsumableItem.EFFECT_TYPE.MANA,
        effect_value = amount or (50 * quality),
        num = stackSize or 1,
        asset = "sandboxSysId://items/icon11002.png"  -- 替换为实际的药水图标
    }
    
    return ConsumableItem.New(data)
end

--- 创建一个增益药水
---@param buffId number Buff ID
---@param duration number 持续时间
---@param stackSize number 堆叠数量
---@return ConsumableItem 消耗品对象
function ConsumableItem.createBuffPotion(buffId, duration, stackSize)
    local buffConfig = common_config.buff_def[buffId]
    if not buffConfig then
        return nil
    end
    
    local data = {
        uuid = gg.create_uuid('consumable'),
        quality = buffConfig.quality or 1,
        level = buffConfig.level or 1,
        name = buffConfig.name .. "药水",
        effect_type = ConsumableItem.EFFECT_TYPE.BUFF,
        buff_id = buffId,
        duration = duration or 60,  -- 默认60秒
        num = stackSize or 1,
        asset = buffConfig.icon or "sandboxSysId://items/icon11003.png"  -- 使用buff图标或默认图标
    }
    
    return ConsumableItem.New(data)
end

return ConsumableItem