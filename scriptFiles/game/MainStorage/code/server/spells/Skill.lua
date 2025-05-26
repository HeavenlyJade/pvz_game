local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig

---@class Skill : Class
---@field New fun(player: Player, data:table): Skill
---@field player Player 玩家实例
---@field skillType SkillType 技能类型
---@field level number 技能等级
---@field equipSlot number 装备槽位
---@field cooldownCache number 冷却缓存
local Skill = ClassMgr.Class("Skill")

function Skill:OnInit(player, data)
    self.player = player
    self.skillType = SkillTypeConfig.Get(data["skill"]) ---@type SkillType
    self.level = data["level"] or 1
    self.equipSlot = data["equipSlot"] or data["slot"] or 0  -- 兼容两种命名
    self.cooldownCache = 0
    
    -- 添加技能名称属性方便访问
    self.skillName = data["skill"]
    
    -- 验证技能类型是否存在
    if not self.skillType then
        gg.log("警告: 技能类型不存在", data["skill"])
    end
end

-- 获取技能描述
---@return string
function Skill:GetDescription()
    if self.skillType then
        return self.skillType.description or ""
    end
    return ""
end

-- 获取技能显示名称
---@return string
function Skill:GetDisplayName()
    if self.skillType then
        return self.skillType.displayName or self.skillName or ""
    end
    return self.skillName or ""
end

-- 获取最大等级
---@return number
function Skill:GetMaxLevel()
    if self.skillType then
        return self.skillType.maxLevel or 1
    end
    return 1
end

-- 检查是否已学会（等级大于0）
---@return boolean
function Skill:IsLearned()
    return self.level > 0
end

-- 检查是否已装备
---@return boolean
function Skill:IsEquipped()
    return self.equipSlot > 0
end

-- 检查是否可以升级
---@return boolean
function Skill:CanLevelUp()
    return self.level < self:GetMaxLevel()
end

-- 升级技能
---@param levels number 升级等级数，默认1
---@return boolean success 是否成功
function Skill:LevelUp(levels)
    levels = levels or 1
    local maxLevel = self:GetMaxLevel()
    
    if self.level + levels <= maxLevel then
        self.level = self.level + levels
        gg.log("技能升级", "技能:", self.skillName, "新等级:", self.level)
        return true
    else
        gg.log("技能升级失败", "技能:", self.skillName, "当前等级:", self.level, "最大等级:", maxLevel)
        return false
    end
end

-- 装备技能到指定槽位
---@param slot number 槽位编号
function Skill:EquipToSlot(slot)
    self.equipSlot = slot
    gg.log("装备技能", "技能:", self.skillName, "槽位:", slot)
end

-- 卸载技能
function Skill:Unequip()
    local oldSlot = self.equipSlot
    self.equipSlot = 0
    gg.log("卸载技能", "技能:", self.skillName, "原槽位:", oldSlot)
end

-- 获取技能的序列化数据（用于保存）
---@return table
function Skill:GetSaveData()
    return {
        skill = self.skillName,
        level = self.level,
        equipSlot = self.equipSlot
    }
end

-- 调试信息
---@return string
function Skill:ToString()
    return string.format("Skill{name=%s, level=%d, slot=%d, learned=%s}", 
        self.skillName or "unknown", 
        self.level, 
        self.equipSlot, 
        tostring(self:IsLearned()))
end

return Skill