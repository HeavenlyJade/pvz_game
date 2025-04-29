--- 收集目标实现类
--- V109 miniw-haima

local game = game
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local CommonModule = require(MainStorage.code.common.CommonModule)  ---@type CommonModule
local BaseObjective = require(MainStorage.code.server.TaskSystem.objectives.BaseObjective)  ---@type BaseObjective

---@class CollectObjective:BaseObjective
local CollectObjective = CommonModule.Class('CollectObjective', BaseObjective)

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化目标
function CollectObjective:OnInit(objectiveData)
    -- 调用基类初始化
    BaseObjective.OnInit(self, objectiveData)
    
    -- 收集目标特有属性
    self.item_id = objectiveData.item_id or objectiveData.target_id    -- 物品ID
    self.item_type = objectiveData.item_type or "消耗品"                -- 物品类型
    self.quality = objectiveData.quality                                -- 物品品质要求
    self.consumeOnComplete = objectiveData.consumeOnComplete or true    -- 完成时是否消耗物品
    self.specific_source = objectiveData.specific_source                -- 特定来源要求
end

--------------------------------------------------
-- 收集目标特有方法
--------------------------------------------------

-- 处理物品获取事件
function CollectObjective:OnItemCollected(player, itemType, itemId, count, source)
    -- 如果目标已完成，则不再处理
    if self.completed then
        return false
    end
    
    -- 检查物品类型和ID是否匹配
    if (self.item_type ~= itemType and self.item_type ~= "任意") or 
       (self.item_id ~= itemId and self.item_id ~= 0) then
        return false
    end
    
    -- 检查物品品质（如果有要求）
    if self.quality and player:GetItemQuality(itemType, itemId) < self.quality then
        return false
    end
    
    -- 检查特定来源（如果有要求）
    if self.specific_source and source ~= self.specific_source then
        return false
    end
    
    -- 更新目标进度
    return self:Update(player, count)
end

-- 检查玩家背包中是否有足够的物品
function CollectObjective:CheckInventory(player)
    -- 获取玩家背包中的物品数量
    local count = player:GetItemCount(self.item_type, self.item_id)
    
    -- 检查物品品质（如果有要求）
    if self.quality then
        count = player:GetQualityItemCount(self.item_type, self.item_id, self.quality)
    end
    
    -- 更新当前进度
    if count > self.current then
        self:Update(player, count - self.current)
    end
    
    return self.current >= self.required
end

-- 完成收集目标
function CollectObjective:Complete(player)
    -- 如果需要消耗物品，从玩家背包中移除
    if self.consumeOnComplete then
        player:RemoveItem(self.item_type, self.item_id, self.required)
    end
    
    return true
end

--------------------------------------------------
-- 重写基类方法
--------------------------------------------------

-- 重写获取描述方法
function CollectObjective:GetDescription()
    local targetName = self.target_name or "物品"
    local optionalText = self.optional and "[可选] " or ""
    local qualityText = ""
    
    if self.quality then
        qualityText = "（" .. common_config.getQualityStr(self.quality) .. "）"
    end
    
    return optionalText .. "收集 " .. targetName .. qualityText .. " (" .. self.current .. "/" .. self.required .. ")"
end

return CollectObjective