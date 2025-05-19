local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell
local Graphics = require(MainStorage.code.server.graphic.Graphics) ---@type Graphics



---@class Spell:Class
---@field spellName string 魔法名
---@field printInfo boolean 打印信息
---@field comment string 注释
---@field cooldown number 冷却
---@field cooldownSpeed number 冷却加速
---@field targetCooldown number 各目标冷却
---@field targetCooldownRate number 各目标冷却倍率
---@field basePower number 基础威力
---@field castOnSelf boolean 释放给自己
---@field delay number 延迟
---@field selfConditions Modifier[] 自身条件
---@field targetConditions Modifier[] 目标条件
---@field subSpells SubSpell[] 子魔法
---@field preCastEffects Graphic[] 特效_前摇释放
---@field preTargetEffects Graphic[] 特效_前摇目标
---@field castEffects Graphic[] 特效_释放
---@field targetEffects Graphic[] 特效_目标
---@field widthScale number 宽度倍率
---@field heightScale number 高度倍率
---@field sizeScale number 尺寸倍率
---@field New fun( data:table ):Spell
local Spell = ClassMgr.Class("Spell")

function Spell.Load( data )
    print("LoadSpell", data["魔法名"], data["类型"])
    local class = require(MainStorage.code.server.spells.spell_types[data["类型"]])
    return class.New(data)
end

function Spell:OnInit( data )
    -- 从配置中读取基础属性
    self.spellName = data["魔法名"] or ""
    self.printInfo = data["打印信息"] or false
    self.comment = data["注释"] or ""
    self.cooldown = data["冷却"] or 0
    self.cooldownSpeed = data["冷却加速"] or 1
    self.targetCooldown = data["各目标冷却"] or 0
    self.targetCooldownRate = data["各目标冷却倍率"] or 0
    self.basePower = data["基础威力"] or 1
    self.castOnSelf = data["释放给自己"] or false
    self.delay = data["延迟"] or 0
    self.widthScale = data["宽度倍率"] or 1
    self.heightScale = data["高度倍率"] or 1
    self.sizeScale = data["尺寸倍率"] or 1

    -- 直接使用配置中的Modifiers实例
    self.selfConditions = data["自身条件"] or {}
    self.targetConditions = data["目标条件"] or {}

    -- 初始化子魔法数组
    self.subSpells = {}
    if data["子魔法"] then
        for _, subSpellData in ipairs(data["子魔法"]) do
            local subSpell = SubSpell.New(subSpellData)
            gg.log("SubSpell", subSpell)
            table.insert(self.subSpells, subSpell)
        end
    end

    -- 加载特效
    self.preCastEffects = Graphics.Load(data["特效_前摇"])
    self.castEffects = Graphics.Load(data["特效_释放"])
end

--- 执行魔法
---@param caster Entity 施法者
---@param target Entity|Vector3|nil 目标
---@param param? CastParam 参数
---@return boolean 是否成功释放
function Spell:Cast(caster, target, param)
    if not param then
        param = CastParam.New()
    end
    param.realTarget = target

    if not caster then
        return false
    end
    if not target then
        -- 获取施法者面前的敌人
        local casterPos = caster:GetPosition()
        local ret_table = caster.scene:SelectCylinderTargets(casterPos, 5000, 5000, {3, 4}, nil)
        gg.log("ret_table", casterPos, ret_table)
        for _, hit in pairs(ret_table) do
            if hit ~= caster then
                gg.log("hit", hit)
                target = hit
                break
            end
        end
        if not target then
            print(self.spellName .. ": 找不到目标")
            return false
        end
    end

    param.power = param.power * param:GetValue(self, "基础威力", self.basePower)

    local log = {}
    if not self:CanCast(caster, target, param, log) then
        if self.printInfo then
            print(table.concat(log, "\n"))
        end
        return false
    end

    caster:TriggerTags("castSpell", target, param, self, param)
    if param.cancelled then
        if self.printInfo then
            log[#log + 1] = string.format("%s：词条【释放魔法时】被取消", self.spellName)
            print(table.concat(log, "\n"))
        end
        return false
    end

    if target and target.isEntity then
        target:TriggerTags("beCastSpell", caster, param, param)
    end
    if param.cancelled then
        if self.printInfo then
            log[#log + 1] = string.format("%s：词条【被释放魔法时】被取消", self.spellName)
            print(table.concat(log, "\n"))
        end
        return false
    end

    if param:GetParam(self, "释放给自己", self.castOnSelf) then
        target = caster
    end

    local cd = param:GetValue(self, "冷却", self.cooldown)
    if cd > 0 then
        cd = cd / param:GetValue(self, "冷却加速", self.cooldownSpeed)
        caster:SetCooldown(self.spellName, cd)
        if self.printInfo then
            log[#log + 1] = string.format("%s：设置冷却%.1f秒", self.spellName, cd)
        end
    end

    local targetCd = param:GetValue(self, "各目标冷却", self.targetCooldown)
    if targetCd > 0 and target and target.isEntity then
        caster:SetCooldown(self.spellName, targetCd, target:GetEntity())
        if self.printInfo then
            log[#log + 1] = string.format("%s：设置对该目标冷却%.1f秒", self.spellName, targetCd)
        end
    end

    self:PlayEffect(self.preCastEffects, param.realTarget, caster, param)

    table.insert(log, string.format("%s: %s对%s释放通过", self.spellName, caster.name, target.name))
    local delay = param:GetValue(self, "延迟", self.delay)
    if delay > 0 then
        if self.printInfo then
            log[#log + 1] = string.format("%s：延迟%.1f秒后释放", self.spellName, delay)
            print(table.concat(log, "\n"))
        end
        ServerScheduler.Add(function()
            self:CastReal(caster, target, param)
        end, delay)
        return true
    else
        if self.printInfo and #log > 0 then
            print(table.concat(log, "\n"))
        end
        return self:CastReal(caster, target, param)
    end
end

--- 播放特效
---@param effects Graphic[] 特效数组
---@param playFrom Entity|Vector3 播放起点
---@param playAt Entity|Vector3 播放终点
---@param param CastParam 参数
---@return Action[]|nil 特效动作数组
function Spell:PlayEffect(effects, playFrom, playAt, param)
    if not effects then return nil end
    local actions = {}
    for i, effect in ipairs(effects) do
        if effect then
            actions[i] = effect:PlayAt(self, playFrom, playAt, param)
        end
    end
    return actions
end

--- 实际执行魔法
---@param caster Entity 施法者
---@param target Entity|Vector3 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function Spell:CastReal(caster, target, param)
    return true
end

--- 检查是否可以释放魔法
---@param caster Entity 施法者
---@param target Entity|Vector3 目标
---@param param CastParam 参数
---@param log string[] 日志数组
---@return boolean 是否可以释放
function Spell:CanCast(caster, target, param, log)
    if self.cooldown > 0 and caster:IsCoolingdown(self.spellName) then
        if log then
            log[#log + 1] = string.format("%s：冷却中", self.spellName)
        end
        return false
    end

    if self.targetCooldown > 0 and target.isEntity and caster:IsCoolingdown(self.spellName, target) then
        if log then
            log[#log + 1] = string.format("%s：对该目标冷却中", self.spellName)
        end
        return false
    end

    if #self.selfConditions > 0 then
        for _, condition in ipairs(self.selfConditions) do
            local stop = condition:Check(caster, caster, param)
            if stop then break end
        end
    end

    if param.cancelled then
        if log then
            log[#log + 1] = string.format("%s：自身条件不满足", self.spellName)
        end
        return false
    end

    if #self.targetConditions > 0 then
        for _, condition in ipairs(self.targetConditions) do
            local stop = condition:Check(caster, target, param)
            if stop then break end
        end
    end

    if param.cancelled then
        if log then
            log[#log + 1] = string.format("%s：目标条件不满足", self.spellName)
        end
        return false
    end

    return true
end

return Spell
