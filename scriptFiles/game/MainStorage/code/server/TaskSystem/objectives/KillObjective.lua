--- 击杀目标实现类
--- V109 miniw-haima

local game = game
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local CommonModule = require(MainStorage.code.common.CommonModule)  ---@type CommonModule
local BaseObjective = require(MainStorage.code.server.TaskSystem.objectives.BaseObjective)  ---@type BaseObjective

---@class KillObjective:BaseObjective
local KillObjective = CommonModule.Class('KillObjective', BaseObjective)

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化目标
function KillObjective:OnInit(objectiveData)
    -- 调用基类初始化
    BaseObjective.OnInit(self, objectiveData)
    
    -- 击杀目标特有属性
    self.monster_id = objectiveData.monster_id or objectiveData.target_id  -- 怪物ID
    self.dropRequired = objectiveData.dropRequired or false   -- 是否需要掉落物
    self.killCount = {}  -- 记录每个怪物的击杀数量，格式 {monster_id = count}
end

--------------------------------------------------
-- 击杀目标特有方法
--------------------------------------------------

-- 处理怪物击杀事件
function KillObjective:OnMonsterKilled(player, monsterId, dropItems)
    -- 如果目标已完成，则不再处理
    if self.completed then
        return false
    end
    
    -- 检查是否是目标怪物
    if self.monster_id ~= monsterId and self.monster_id ~= 0 then  -- monster_id为0表示任意怪物
        return false
    end
    
    -- 检查是否需要掉落物且怪物有掉落
    if self.dropRequired and (not dropItems or #dropItems == 0) then
        return false
    end
    
    -- 记录击杀数量
    self.killCount[monsterId] = (self.killCount[monsterId] or 0) + 1
    
    -- 更新目标进度
    return self:Update(player, 1)
end

-- 获取总击杀数量
function KillObjective:GetTotalKills()
    local total = 0
    for _, count in pairs(self.killCount) do
        total = total + count
    end
    return total
end

--------------------------------------------------
-- 重写基类方法
--------------------------------------------------

-- 重写重置方法
function KillObjective:Reset()
    BaseObjective.Reset(self)
    self.killCount = {}
end

-- 重写获取描述方法
function KillObjective:GetDescription()
    local targetName = self.target_name or "怪物"
    local optionalText = self.optional and "[可选] " or ""
    
    return optionalText .. "击杀 " .. targetName .. " (" .. self.current .. "/" .. self.required .. ")"
end

return KillObjective