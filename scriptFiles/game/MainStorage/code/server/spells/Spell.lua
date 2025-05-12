local MainStorage = game:GetService('MainStorage')
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell
local CastParam = require(MainStorage.code.common.spell.CastParam) ---@type CastParam



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
local Spell = CommonModule.Class("Spell")

function Spell:OnInit( data )
    self.spellName = ""
    self.printInfo = false
    self.comment = ""
    self.cooldown = 0
    self.cooldownSpeed = 1
    self.targetCooldown = 0
    self.targetCooldownRate = 0
    self.basePower = 1
    self.castOnSelf = false
    self.delay = 0
    self.selfConditions = {}
    self.targetConditions = {}
    self.subSpells = {}
    self.preCastEffects = {}
    self.preTargetEffects = {}
    self.castEffects = {}
    self.targetEffects = {}
    self.widthScale = 1
    self.heightScale = 1
    self.sizeScale = 1
end

--- 执行魔法
---@param caster CLiving 施法者
---@param target CLiving|Vector3 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function Spell:Cast(caster, target, param)
    if not param then
        param = CastParam.New()
    end
    param.realTarget = target
    
    if not caster or not target then
        return false
    end
    
    param.power = param.power * param:GetValue(self, "basePower", self.basePower)
    
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
    
    if target.isEntity then
        target:TriggerTags("beCastSpell", caster, param, param)
    end
    if param.cancelled then
        if self.printInfo then
            log[#log + 1] = string.format("%s：词条【被释放魔法时】被取消", self.spellName)
            print(table.concat(log, "\n"))
        end
        return false
    end
    
    if param:GetParam(self, "castOnSelf", self.castOnSelf) then
        target = caster
    end
    
    local cd = param:GetValue(self, "cooldown", self.cooldown)
    if cd > 0 then
        cd = cd / param:GetValue(self, "cooldownSpeed", self.cooldownSpeed)
        caster:SetCooldown(self.spellName, cd)
        if self.printInfo then
            log[#log + 1] = string.format("%s：设置冷却%.1f秒", self.spellName, cd)
        end
    end
    
    local targetCd = param:GetValue(self, "targetCooldown", self.targetCooldown)
    if targetCd > 0 and target.isEntity then
        caster:SetCooldown(self.spellName, targetCd, target:GetCLiving())
        if self.printInfo then
            log[#log + 1] = string.format("%s：设置对该目标冷却%.1f秒", self.spellName, targetCd)
        end
    end
    
    self:PlayEffect(self.preCastEffects, param.realTarget, caster, param)
    self:PlayEffect(self.preTargetEffects, caster, param.realTarget, param)
    
    local delay = param:GetValue(self, "delay", self.delay)
    if delay > 0 then
        if self.printInfo then
            log[#log + 1] = string.format("%s：延迟%.1f秒后释放", self.spellName, delay)
            print(table.concat(log, "\n"))
        end
        Timer.Register(delay, function()
            self:CastReal(caster, target, param)
        end)
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
---@param playFrom CLiving|Vector3 播放起点
---@param playAt CLiving|Vector3 播放终点
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
---@param caster CLiving 施法者
---@param target CLiving|Vector3 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function Spell:CastReal(caster, target, param)
    return true
end

--- 检查是否可以释放魔法
---@param caster CLiving 施法者
---@param target CLiving|Vector3 目标
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
