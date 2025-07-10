local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local MobType = require(MainStorage.code.common.config_type.MobType) ---@type MobType
local MobTypeConfig = require(MainStorage.config.MobTypeConfig)  ---@type MobTypeConfig
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local Graphics = require(MainStorage.code.server.graphic.Graphics) ---@type Graphics
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local StatTypeConfig = require(MainStorage.config.StatTypeConfig) ---@type StatTypeConfig

---@class SummonSpell:Spell
---@field mobTypeName string 怪物类型名称
---@field summonRadius number 召唤范围
---@field summonAtTargetPos boolean 是否在目标位置召唤
---@field maxCount number 最大召唤数量
---@field inheritLevel boolean 是否继承施法者等级
---@field duration number 召唤物持续时间
---@field summonerSummons table<Entity, table<Monster, Spell>> 召唤者与其召唤物的映射表
local SummonSpell = ClassMgr.Class("SummonSpell", Spell)
SummonSpell.summonerSummons = {} ---@type table<Entity, table<Monster, Spell>>
SummonSpell.summoned2Caster = {} ---@type table<Entity, Entity>

--- 处理怪物死亡事件
---@param mob Monster 死亡的怪物
local function OnMobDead(mob)
    local summoner = SummonSpell.summoned2Caster[mob]
    if not summoner then return end

    local summons = SummonSpell.summonerSummons[summoner]
    if summons then
        summons[mob] = nil
        -- 如果召唤者没有召唤物了，清理表项
        if next(summons) == nil then
            SummonSpell.summonerSummons[summoner] = nil
        end
    end

    -- 从召唤物到召唤者的映射中移除
    SummonSpell.summoned2Caster[mob] = nil
end

--- 处理战斗后事件
---@param battle Battle 战斗实例
local function OnPostBattle(battle)
    -- 检查是否是主人的战斗
    local attacker = battle.attacker
    local target = battle.victim

    local summons = SummonSpell.summonerSummons[attacker]
    if not summons then return end

    -- 遍历主人的所有召唤物
    for mob, _ in pairs(summons) do
        if mob and mob.isEntity and not mob.target then
            mob:SetTarget(target)
        end
    end
end

-- 订阅怪物死亡事件
ServerEventManager.Subscribe("MobDeadEvent", function(event)
    OnMobDead(event.mob)
end)

-- 订阅战斗后事件
ServerEventManager.Subscribe("PostBattleEvent", function(event)
    OnPostBattle(event.battle)
end)

local function ClearAllSummonsForPlayer(player)
    if player then
        local summons = SummonSpell.summonerSummons[player]
        if summons then
            for mob, _ in pairs(summons) do
                if mob and mob.isEntity then
                    mob:DestroyObject()
                end
                SummonSpell.summoned2Caster[mob] = nil
            end
            SummonSpell.summonerSummons[player] = nil
        end
    end
end

ServerEventManager.Subscribe("PlayerLeaveGameEvent", function(event)
    ClearAllSummonsForPlayer(event.player)
end)

ServerEventManager.Subscribe("PlayerExitBattleEvent", function(event)
    ClearAllSummonsForPlayer(event.player)
end)

function SummonSpell:OnInit(data)
    self.summonAtTargetPos = data["召唤在目标位置"] ---@type boolean
    self.mobTypeName = data["怪物类型"] or ""
    self.maxCount = data["最大数量"] or 1
    self.summonRadius = data["召唤范围"] or 100
    self.inheritLevel = data["继承等级"]
    self.duration = data["持续时间"]
    self.projectileEffects = Graphics.Load(data["特效_召唤物"])
    self.extraSummonAttributes = data["额外召唤物属性"] or nil
    self.printInfo = data["打印信息"] or false
end

--- 获取召唤者的召唤物数量
---@param summoner Entity 召唤者
---@return number 召唤物数量
function SummonSpell:GetSummonCount(summoner)
    local summons = SummonSpell.summonerSummons[summoner]
    if not summons then return 0 end

    local count = 0
    for _, spell in pairs(summons) do
        if spell == self then
            count = count + 1
        end
    end
    return count
end

--- 添加召唤物到召唤者列表
---@param summoner Entity 召唤者
---@param summoned Entity 召唤物
function SummonSpell:AddSummon(summoner, summoned)
    if not SummonSpell.summonerSummons[summoner] then
        SummonSpell.summonerSummons[summoner] = {}
    end

    SummonSpell.summonerSummons[summoner][summoned] = self
    SummonSpell.summoned2Caster[summoned] = summoner

    -- 如果设置了持续时间，添加定时销毁
    if self.duration and self.duration > 0 then
        ServerScheduler.add(function()
            if summoned and summoned.isEntity then
                summoned:DestroyObject()
            end
        end, self.duration)
    end
end

--- 从召唤者列表中移除召唤物
---@param summoner Entity 召唤者
---@param summoned Entity 召唤物
function SummonSpell:RemoveSummon(summoner, summoned)
    local summons = SummonSpell.summonerSummons[summoner]
    if not summons then return end

    if summons[summoned] == self then
        summons[summoned] = nil
        SummonSpell.summoned2Caster[summoned] = nil
        -- 如果召唤者没有召唤物了，清理表项
        if next(summons) == nil then
            SummonSpell.summonerSummons[summoner] = nil
        end
    end
end

--- 清理召唤者的所有召唤物
---@param summoner Entity 召唤者
function SummonSpell:ClearSummons(summoner)
    local summons = SummonSpell.summonerSummons[summoner]
    if not summons then return end

    for mob, spell in pairs(summons) do
        if spell == self then
            if mob and mob.isEntity then
                mob:DestroyObject()
            end
            SummonSpell.summoned2Caster[mob] = nil
            summons[mob] = nil
        end
    end

    -- 如果召唤者没有召唤物了，清理表项
    if next(summons) == nil then
        SummonSpell.summonerSummons[summoner] = nil
    end
end

--- 检查是否可以释放魔法
---@param caster Entity 施法者
---@param target Entity|Vector3 目标
---@param param CastParam 参数
---@param log string[] 日志数组
---@return boolean 是否可以释放
function SummonSpell:CanCast(caster, target, param, log)
    -- 检查是否达到最大召唤数量
    if self:GetSummonCount(caster) >= self.maxCount then
        if log then
            log[#log + 1] = string.format("%s：已达到最大召唤数量 %d", self.spellName, self.maxCount)
        end
        return false
    end
    -- 首先调用父类的检查
    if not Spell.CanCast(self, caster, target, param, log) then
        return false
    end
    return true
end

function SummonSpell:ApplyExtraAttributes(caster, summoned, power)
    if not self.extraSummonAttributes or not summoned then return end
    for attrName, attrConf in pairs(self.extraSummonAttributes) do
        local extraAttr = attrConf["额外属性"]
        local attrBuff = attrConf["属性增伤"]
        if extraAttr and attrBuff then
            local baseValue = caster:GetStat(attrBuff["属性类型"])
            local addValue = (attrBuff["倍率"] or 1) * baseValue * power
            if attrBuff["增加类型"] == "增加" then
                summoned:AddStat(extraAttr, addValue, "SUMMON_EXTRA", false)
            elseif attrBuff["增加类型"] == "减少" then
                summoned:AddStat(extraAttr, -addValue, "SUMMON_EXTRA", false)
            end
            if self.printInfo then
                print(string.format("[召唤物加成] 属性: %s, 类型: %s, 基础值: %s, 倍率: %s, 最终加成: %s", tostring(extraAttr), tostring(attrBuff["增加类型"]), tostring(baseValue), tostring(attrBuff["倍率"]), tostring(addValue)))
            end
        end
    end
end

local function printSummonedStats(summoned)
    local statText = string.format("召唤物属性: %s\n", summoned.name or tostring(summoned))
    local sortedStats = StatTypeConfig.GetSortedStatList()
    for _, statName in ipairs(sortedStats) do
        local statType = StatTypeConfig.Get(statName)
        local value = summoned:GetStat(statName)
        if value and value > 0 then
            if statType.isPercentage then
                statText = statText .. string.format("%s: %.1f%%\n", statType.displayName, value)
            else
                statText = statText .. string.format("%s: %d\n", statType.displayName, value)
            end
        end
    end
    print(statText)
end

--- 实际执行魔法
---@param caster Entity 施法者
---@param target Entity|Vector3 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function SummonSpell:CastReal(caster, target, param)
    -- 检查是否超过最大召唤数量
    if self:GetSummonCount(caster) >= self.maxCount then
        gg.log("[INFO] SummonSpell: 已达到最大召唤数量", self.maxCount)
        return false
    end

    -- 获取怪物类型
    local mobType = MobTypeConfig.Get(self.mobTypeName)
    if not mobType then
        gg.log("[ERROR] SummonSpell: 找不到怪物类型", self.mobTypeName)
        return false
    end

    -- 获取召唤位置
    local position
    if self.summonAtTargetPos and target then
        position = self:GetPosition(target)
    else
        position = caster:GetPosition()
    end

    -- 获取召唤参数
    local radius = param:GetValue(self, "召唤范围", self.summonRadius)
    local level = self.inheritLevel and caster.level or param:GetValue(self, "召唤等级", 1)

    -- 获取施法者朝向
    local casterRot = caster.actor.Rotation

    -- 执行召唤
    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius
    local offset = Vector3.New(
        math.cos(angle) * distance,
        0,
        math.sin(angle) * distance
    )
    local spawnPos = position + offset

    -- 延迟召唤
    local summoned = mobType:Spawn(spawnPos, level, caster.scene)
    if summoned then
        -- 设置召唤物朝向与施法者相同
        summoned.actor.Rotation = casterRot
        summoned:SetOwner(caster)
        self:AddSummon(caster, summoned)
        caster:TriggerTags("召唤时", summoned, param, summoned)
        -- 应用额外召唤物属性
        self:ApplyExtraAttributes(caster, summoned, param.power)
        -- 打印召唤物属性
        if self.printInfo then
            printSummonedStats(summoned)
        end
    end
    self:PlayEffect(self.projectileEffects, caster, target, param)

    return true
end

return SummonSpell 