local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Monster     = require(MainStorage.code.server.entity_types.Monster) ---@type Monster
local gg           = require(MainStorage.code.common.MGlobal) ---@type gg
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell

---@class MobSkill:Class
---@field timing string 技能触发时机
---@field defaultTarget string 默认目标类型
---@field spells table 技能列表
---@field period number 技能释放周期（秒）
---@field New fun(data:table):MobSkill
local MobSkill = ClassMgr.Class("MobSkill")

function MobSkill:OnInit(data)
    self.timing = data["时机"] or "周期"
    self.defaultTarget = data["默认目标"] or "目标"
    self.spell = SubSpell.New(data["魔法"])
    -- self.power = data["power"] or 0
    self.range = data["距离"] or 0
end

function MobSkill:CanCast(caster, target)
    -- 如果没有目标，不能释放技能
    if not target then
        return false
    end

    -- 检查距离
    if self.range > 0 then
        local distanceSq = gg.vec.DistanceSq3(caster:GetPosition(), target:GetPosition())
        if distanceSq > self.range * self.range then
            return false
        end
    end

    return self.spell:CanCast(caster, target)
end

--- 释放技能
---@param caster Monster 施法者
---@param target Entity|Vector3|nil 目标
function MobSkill:CastSkill(caster, target)
    -- 如果施法者已死亡或被冻结，不能释放技能
    if caster.isDead or caster:IsFrozen() then
        return
    end

    -- 确定技能目标
    local skillTarget = target
    if not skillTarget then
        if self.defaultTarget == "目标" then
            skillTarget = caster.target
        elseif self.defaultTarget == "自己" then
            skillTarget = caster
        end
    end

    -- 如果没有目标，不能释放技能
    if not skillTarget then
        return
    end
    -- 释放技能
    self.spell:Cast(caster, skillTarget)
end

-- StatType 类
---@class MobType:Class
---@field New fun( data:table ):MobType
local MobType      = ClassMgr.Class("MobType")
function MobType:OnInit(data)
    self.data = data
    self.triggerSkills = {} ---@type table<string, MobSkill[]> --以skill.timing整理
    if data["技能"] then
        for _, skillData in ipairs(data["技能"]) do
            if skillData["魔法"] then
                local skill = MobSkill.New(skillData)
                -- 按timing分类存储技能
                if not self.triggerSkills[skill.timing] then
                    self.triggerSkills[skill.timing] = {}
                end
                table.insert(self.triggerSkills[skill.timing], skill)
            end
        end
    end
end

---@param position Vector3
---@param scene Scene
---@return Monster
function MobType:Spawn(position, level, scene)
    if not position then
        return nil
    end
    local monster_ = Monster.New({ ---@type Monster
        position = position,
        mobType  = self,
        level = level,
    })
    monster_:CreateModel(scene)
    monster_:ChangeScene(scene)
    scene.monsters[monster_.uuid] = monster_
    scene.node2Entity[monster_.actor] = monster_
    monster_:RefreshStats()
    return monster_
end

---@param statType string
---@param level number
---@return number
function MobType:GetStatAtLevel(statType, level)
    if not self.data["属性公式"][statType] then
        return 0
    end

    local expr = self.data["属性公式"][statType]:gsub("LVL", tostring(level))
    if not expr:match("^[%d%+%-%*%/%%%^%(%)(%.)%s]+$") then
        print(string.format("怪物%s的属性%s包含非法字符: %s", self["名字"], statType, expr))
        return 0
    end

    local result = gg.eval(expr)
    -- print("calc result:", expr, result)

    return result
end

--- 获取指定时机的技能列表
---@param timing string 技能触发时机
---@return MobSkill[] 技能列表
function MobType:GetSkillsByTiming(timing)
    return self.triggerSkills[timing] or {}
end

return MobType
