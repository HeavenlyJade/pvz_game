local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local common_const = require(MainStorage.code.common.MConst) ---@type common_const
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr) ---@type MCloudDataMgr
local Battle = require(MainStorage.code.server.Battle) ---@type Battle
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler

-- local StartPlayer = game:GetService("StartPlayer")
-- local MainServer = require( game:GetService("MainStorage"):WaitForChild('code').server.MServerMain )
-- local PlayerModule = require( StartPlayer.StarterPlayerScripts.PlayerModule )

local TRIGGER_STAT_TYPES = {
    ["生命"] = function(creature, value)
        creature:SetMaxHealth(value)
    end,
    ["速度"] = function(creature, value)
        if creature._moveable then
        creature.actor.Movespeed = value
        end
    end
}

---@class Entity :Class  管理单个场景中的actor实例和有共性的属性，被包含在 player monster boss中
---@field info any
---@field uuid string
---@field uin  number
---@field cd_list any
---@field tick number
---@field wait_tick number
---@field stat_flags any
---@field npc_type NPC_TYPE
---@field stat_data any
---@field model_weapon any
---@field actor Actor
---@field target Entity
---@field isDead boolean 是否已死亡
---@field isRespawning boolean 是否正在复活
---@field New fun( info_:table ):Entity
local _M = ClassMgr.Class("Entity") -- 父类 (子类： Player, Monster )
_M.node2Entity = {}

_M.TRIGGER_STAT_TYPES = TRIGGER_STAT_TYPES
-- 新增属性
function _M:OnInit(info_)
    info_ = info_ or {}
    self.spawnPos = info_.position or Vector3.New(0, 0, 0)
    self._moveable = true
    self.name = nil
    self.comboSpellProgress = {}
    self.isDestroyed = false
    self.isInvulnurable = false
    self:GenerateUUID()
    self._nameTemplate = ""
    self.isEntity = true
    self.showHealthBar = false
    self.isPlayer = false
    self.uin = info_.uin or 0
    self.scene = nil ---@type Scene
    self.exp = 0 -- 当前经验值
    self.level = 1 -- 当前等级
    self.stats = {} ---@type table<string, table<string, number>>

    self.actor = nil -- game_actor
    self.target = nil -- 当前目标 Entity
    -- self.model_weapon = nil -- 武器

    self.isDead = false -- 是否已死亡
    self.combatTime = 0 -- 战斗时间计数器

    self.bb_title = nil -- 头顶名字和等级 billboard
    self.bb_damage = nil -- 伤害飘字

    -- 冷却系统
    self.cd_list = {} -- 全局冷却列表
    self.cooldownTarget = {} -- 目标相关冷却列表

    -- 战斗属性
    self.health = 0
    self.maxHealth = 0
    ---@private 仅用于更新伤害标识,不要用于逻辑运算,获取准确值请用 self:GetStat("攻击")
    self._attackCache = 0
    self.mana = 0
    self.maxMana = 0
    self.shield = 0

    -- 词条系统
    self.tagHandlers = {} -- 词条处理器
    self.tagIds = {} -- 词条ID映射

    -- BUFF系统
    self.activeBuffs = {} -- 激活的BUFF

    -- 变量系统
    self.variables = {}

    self.tick = 0 -- 总tick值(递增)
    self.wait_tick = 0 -- 等待状态tick值(递减)（剧情使用）
    self.last_anim = '' -- 最后一个播放的动作

    self.stat_data = { -- 每个状态下的数据
        idle = {
            select = 0,
            wait = 0
        }, -- monster
        fight = {
            wait = 0
        }, -- monster
        wander = {
            wait = 0
        }, -- monster wander
        melee = {
            wait = 0
        } -- monster melee
    }
    self.modelPlayer = nil  ---@type ModelPlayer
    self.outlineTimer = nil
end

---@protected
_M.GenerateUUID = function(self)
    return ""
end

function _M:SubscribeEvent(eventType, listener, priority)
    ServerEventManager.Subscribe(eventType, listener, priority, self.uuid)
end

function _M:ExecuteCommand(command, target, silent)
    local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)  ---@type CommandManager
    command = gg.ProcessVariables(command, self, target)
    CommandManager.ExecuteCommand(command, self, silent)
end

function _M:ExecuteCommands(commands, target, silent)
    target = target or self
    for _, command in ipairs(commands) do
        local success, result = pcall(self.ExecuteCommand, self, command, target, silent)
        if not success then
            gg.log("命令执行错误: " .. command .. ", " .. tostring(result))
            return false
        end
    end
end

function _M:SetModel(model, animator, stateMachine)
    self.actor.ModelId = model
    self.actor["Animator"].ControllerAsset = animator
    self:SetAnimationController(stateMachine)
end

function _M:GetSize()
    if not self.actor then
        print(debug.traceback())
    end
    local size = self.actor.Size
    local scale = self.actor.LocalScale
    return Vector3.New(size.x * scale.x, size.y * scale.y, size.z * scale.z)
end

function _M:SetAnimationController(name)
    if self.modelPlayer and self.modelPlayer.name == name then
        return
    end
    if self.modelPlayer then
        self.modelPlayer.walkingTask:Disconnect()
        self.modelPlayer.standingTaskId:Disconnect()
        self.modelPlayer = nil
    end
    if name then
        local AnimationConfig = require(MainStorage.config.AnimationConfig) ---@type AnimationConfig
        local ModelPlayer = require(MainStorage.code.server.graphic.ModelPlayer) ---@type ModelPlayer
        local animator = self.actor.Animator
        local animationConfig = AnimationConfig.Get(name)
        if animator and animationConfig then
            self.modelPlayer = ModelPlayer.New(name, animator, animationConfig, self)
            self.modelPlayer.walkingTask = self.actor.Walking:Connect(function(isWalking)
                if isWalking then
                    self.modelPlayer:OnWalk()
                end
            end)
            self.modelPlayer.standingTaskId = self.actor.Standing:Connect(function(isStanding)
                if isStanding then
                    self.modelPlayer:OnStand()
                end
            end)
        end
    end
end

function _M:SetPosition(position)
    self.actor.LocalPosition = position
end

function _M:GetPosition()
    return self.actor and self.actor.LocalPosition or Vector3.New(0, 0, 0)
end

function _M:GetRotation()
    return self.actor and self.actor.Euler or Vector3.New(0, 0, 0)
end
function _M:SetRotation(rotation)
    self.actor.Euler = rotation
end

function _M:GetCenterPosition()
    return gg.vec.Add3(self:GetPosition(), 0, self:GetSize().y/2, 0)
end

function _M:GetDirection()
    return self.actor and self.actor.ForwardDir or Vector3.New(0, 0, 1)
end

function _M:GetToStringParams()
    return {
        name = self.name
    }
end

function _M:RefreshStats()
    if not self.actor then return end
    self:ResetStats("EQUIP")

    -- 遍历所有需要触发的属性类型并刷新
    for statName, triggerFunc in pairs(TRIGGER_STAT_TYPES) do
        local value = self:GetStat(statName)
        triggerFunc(self, value)
    end
    self._attackCache = self:GetStat("攻击")
end

-- 词条系统 --------------------------------------------------------

--- 获取词条
---@param id string 词条ID
---@return EquipingTag|nil
function _M:GetTag(id)
    if self.tagIds[id] then
        return self.tagIds[id]
    end

    -- 模糊匹配
    for tagId, tag in pairs(self.tagIds) do
        if string.find(tagId, id) then
            return tag
        end
    end

    return nil
end

--- 重建词条处理器
function _M:RebuildTagHandlers()
    self.tagHandlers = {}

    for _, equipingTag in pairs(self.tagIds) do
        for key, handlers in pairs(equipingTag.handlers) do
            if not self.tagHandlers[key] then
                self.tagHandlers[key] = {}
            end

            table.insert(self.tagHandlers[key], equipingTag)

            -- 如果有多个处理器，按优先级排序
            if #self.tagHandlers[key] > 1 then
                table.sort(self.tagHandlers[key], function(a, b)
                    return a.handlers[key][1]["优先级"] < b.handlers[key][1]["优先级"]
                end)
            end
        end
    end
end

--- 添加词条处理器
---@param equipingTag EquipingTag 词条对象
function _M:AddTagHandler(equipingTag)
    if self.tagIds[equipingTag.id] then
        -- 已存在相同ID的词条，增加等级
        local existingTag = self.tagIds[equipingTag.id]
        existingTag.level = existingTag.level + equipingTag.level
    else
        self.tagIds[equipingTag.id] = equipingTag
    end

    self:RebuildTagHandlers()
end

--- 移除词条处理器
---@param id string 词条ID
function _M:RemoveTagHandler(id)
    if self.tagIds[id] then
        local equippingTag = self.tagIds[id]

        -- 从tagHandlers中移除
        for key, handlers in pairs(equippingTag.handlers) do
            if self.tagHandlers[key] then
                for i, tag in ipairs(self.tagHandlers[key]) do
                    if tag.id == id then
                        table.remove(self.tagHandlers[key], i)
                        break
                    end
                end

                if #self.tagHandlers[key] == 0 then
                    self.tagHandlers[key] = nil
                end
            end
        end

        self.tagIds[id] = nil
    else
        -- 模糊匹配移除
        local removedIds = {}
        for tagId in pairs(self.tagIds) do
            if string.find(tagId, id) then
                table.insert(removedIds, tagId)
            end
        end

        for _, tagId in ipairs(removedIds) do
            self:RemoveTagHandler(tagId)
        end
    end
end

--- 触发词条
---@param key string 触发键
---@param target Entity 目标
---@param castParam CastParam|nil 施法参数
---@param ... any 额外参数
function _M:TriggerTags(key, target, castParam, ...)
    if not castParam then
        castParam = CastParam.New()
    end
    local args = {...}
    if castParam and castParam.dynamicTags and castParam.dynamicTags[key] then
        for _, equipingTag in ipairs(castParam.dynamicTags[key]) do
            for _, tag in ipairs(equipingTag.handlers[key]) do
                tag:Trigger(self, target, equipingTag, args)
            end
        end
    end

    -- 处理普通词条
    if self.tagHandlers[key] then
        for _, equipingTag in ipairs(self.tagHandlers[key]) do
            for _, tag in ipairs(equipingTag.handlers[key]) do
                tag:Trigger(self, target, equipingTag, args)
            end
        end
    end
end

-- BUFF系统 --------------------------------------------------------

--- 添加BUFF
---@param buff ActiveBuff BUFF对象
function _M:AddBuff(buff)
    self.activeBuffs[buff.id] = buff
end

--- 移除BUFF
---@param buffId string BUFF ID
function _M:RemoveBuff(buffId)
    self.activeBuffs[buffId] = nil
end

--- 获取BUFF堆叠数
---@param keyword string BUFF关键字
---@return number 堆叠数
function _M:GetBuffStacks(keyword)
    local stacks = 0

    if not keyword or keyword == "" then
        -- 获取所有BUFF的堆叠数
        for _, buff in pairs(self.activeBuffs) do
            stacks = stacks + buff.stack
        end
    else
        -- 获取特定关键字的BUFF堆叠数
        for _, buff in pairs(self.activeBuffs) do
            if string.find(buff.spell.spellName, keyword) then
                stacks = stacks + buff.stack
            end
        end
    end

    return stacks
end

-- 冷却系统 --------------------------------------------------------

--- 获取冷却时间
---@param reason string 冷却原因
---@param target Entity|nil 目标对象
---@return number 剩余冷却时间
function _M:GetCooldown(reason, target)
    if target then
        -- 检查目标相关的冷却
        if self.cooldownTarget[reason] then
            local targetId = target.actor and target.actor.InstanceID or 0
            if self.cooldownTarget[reason][targetId] then
                local remainingTime = self.cooldownTarget[reason][targetId] - gg.GetTimeStamp()
                return remainingTime > 0 and remainingTime or 0
            end
        end
    end

    -- 检查全局冷却
    if self.cd_list[reason] then
        local remainingTime = self.cd_list[reason] - gg.GetTimeStamp()
        return remainingTime > 0 and remainingTime or 0
    end

    return 0
end

--- 检查是否在冷却中
---@param reason string 冷却原因
---@param target Entity|Vector3|nil 目标对象
---@return boolean 是否在冷却中
function _M:IsCoolingdown(reason, target)
    return self:GetCooldown(reason, target) > 0.05
end

--- 设置冷却时间
---@param reason string 冷却原因
---@param time number 冷却时间(秒)
---@param target Entity|Vector3|nil 目标对象
function _M:SetCooldown(reason, time, target)
    if target and target.isEntity then
        -- 设置目标相关的冷却
        if not self.cooldownTarget[reason] then
            self.cooldownTarget[reason] = {}
        end
        local targetId = target.actor and target.actor.InstanceID or 0
        self.cooldownTarget[reason][targetId] = gg.GetTimeStamp() + time
    else
        -- 设置全局冷却
        self.cd_list[reason] = gg.GetTimeStamp() + time
    end
end

--- 清除目标冷却
---@param reason string|nil 冷却原因，nil表示清除所有
function _M:ClearTargetCooldowns(reason)
    if reason then
        self.cooldownTarget[reason] = nil
    else
        self.cooldownTarget = {}
    end
end

-- 变量系统 --------------------------------------------------------

--- 设置变量
---@param key string 变量名
---@param value number 变量值
function _M:SetVariable(key, value)
    self.variables[key] = value
    -- 发布变量变化事件
    ServerEventManager.Publish("VariableChanged", { entity = self, key = key, value = value })
end

--- 获取变量
---@param key string 变量名
---@return number 变量值
function _M:GetVariable(key, defaultValue)
    defaultValue = defaultValue or 0
    if string.find(key, "#") then
        local parts = {}
        for part in string.gmatch(key, "[^#]+") do
            table.insert(parts, part)
        end

        if #parts == 2 then
            local category = parts[1]
            local variable = parts[2]

            -- 创建并发布事件
            local evt = {
                category = category,
                variable = variable,
                value = 0
            }
            ServerEventManager.Publish("VariableEvent", evt)

            return evt.value or defaultValue
        end
    end

    -- 如果不是特殊格式或解析失败，返回普通变量值
    return self.variables[key] or defaultValue
end

--- 增加变量值
---@param key string 变量名
---@param value number 增加值
function _M:AddVariable(key, value)
    if not self.variables[key] then
        self.variables[key] = 0
    end
    self.variables[key] = self.variables[key] + value
    -- 发布变量变化事件
    ServerEventManager.Publish("VariableChanged", { entity = self, key = key, value = self.variables[key] })
end

--- 移除变量
---@param key string 变量名或部分名
function _M:RemoveVariable(key)
    local keysToRemove = {}

    for k in pairs(self.variables) do
        if string.find(k, key) then
            table.insert(keysToRemove, k)
        end
    end

    for _, k in ipairs(keysToRemove) do
        self.variables[k] = nil
        -- 发布变量变化事件
        ServerEventManager.Publish("VariableChanged", { entity = self, key = k, value = nil })
    end
end

-- 属性管理系统 ----------------------------------------------------

--- 添加属性
---@param statName string 属性名
---@param amount number 属性值
---@param source? string 来源，默认为"BASE"
---@param refresh? boolean 是否刷新，默认为true
function _M:AddStat(statName, amount, source, refresh)
    if not amount then
        return
    end
    source = source or "BASE"
    refresh = refresh == nil and true or refresh

    if not self.stats[source] then
        self.stats[source] = {}
    end

    if not self.stats[source][statName] then
        self.stats[source][statName] = 0
    end

    self.stats[source][statName] = self.stats[source][statName] + amount

    if self.actor and refresh and TRIGGER_STAT_TYPES[statName] then
        TRIGGER_STAT_TYPES[statName](self, self:GetStat(statName))
    end
end

--- 获取属性值
---@param statName string 属性名
---@param sources? string[] 来源列表
---@param triggerTags? boolean 是否触发词条，默认为true
---@param castParam? CastParam 施法参数
---@return number 属性值
function _M:GetStat(statName, sources, triggerTags, castParam)
    local amount = 0
    triggerTags = triggerTags == nil and true or triggerTags

    -- 遍历所有来源的属性
    for source, statMap in pairs(self.stats) do
        if not sources or table:contains(sources, source) then
            if statMap[statName] then
                amount = amount + statMap[statName]
            end
        end
    end

    -- 触发词条影响属性
    if triggerTags and self.tagHandlers[statName] then
        local battle = Battle.New(self, self, statName)
        battle:AddModifier("BASE", "增加", amount)
        self:TriggerTags(statName, self, castParam, battle)
        amount = battle:GetFinalDamage()
    end

    return amount
end

--- 重置属性
---@param id string 来源ID
function _M:ResetStats(id)
    self.stats[id] = nil
end

-- 战斗系统 --------------------------------------------------------

--- 攻击目标
---@param victim Entity 目标对象
---@param baseDamage number 基础伤害
---@param source string|nil 伤害来源
---@param castParam CastParam|nil 施法参数
---@return Battle 战斗结果
function _M:Attack(victim, baseDamage, source, castParam)
    -- 这里需要Battle类的实现，暂时简化处理
    local battle = Battle.New(self, victim, source, castParam)
    battle:AddModifier("BASE", "增加", baseDamage)
    battle:CalculateBattle()

    victim:Hurt(battle:GetFinalDamage(), self, battle.isCrit)
    return battle
end

--- 受到伤害
---@param amount number 伤害值
---@param damager Entity 伤害来源
---@param isCrit boolean 是否暴击
function _M:Hurt(amount, damager, isCrit)
    if self.isDead then
        return
    end

    -- 先扣除护盾
    if self.shield > 0 then
        if self.shield >= amount then
            self.shield = self.shield - amount
            amount = 0
        else
            amount = amount - self.shield
            self.shield = 0
        end
    end

    -- 扣除生命值
    if amount > 0 then
        self:SetHealth(self.health - amount)
        self.combatTime = 10 -- 设置战斗时间为10秒
        local player = damager:GetPlayer()
        if player then
            player:showDamage(amount, {
                cr = isCrit and 1 or 0
            }, self)
        end

        -- 显示受伤描边效果
        if self.actor then
            self.actor.OutlineActive = true
            ServerScheduler.add(function()
                if self.actor then
                    self.actor.OutlineActive = false
                end
            end, 0.5, nil, "outline_" .. self.uuid)
        end
    end

    -- 检查死亡
    if self.health <= 0 then
        self:Die()
    end
end

---@param owner Entity
function _M:SetOwner(owner)
    self.owner = owner
    
    -- 从旧的ColliderGroup实体列表中移除
    if self.scene and self.actor and self.actor.CollideGroupID then
        local oldGroupId = self.actor.CollideGroupID
        if self.scene.entities[oldGroupId] then
            for i, entity in ipairs(self.scene.entities[oldGroupId]) do
                if entity == self then
                    table.remove(self.scene.entities[oldGroupId], i)
                    break
                end
            end
        end
    end
    
    self.actor.CollideGroupID = owner.actor.CollideGroupID
    
    -- 添加到新的ColliderGroup实体列表中
    if self.scene and self.actor.CollideGroupID then
        local groupId = self.actor.CollideGroupID
        if not self.scene.entities[groupId] then
            self.scene.entities[groupId] = {}
        end
        table.insert(self.scene.entities[groupId], self)
    end
end

function _M:GetPlayer()
    if self.isPlayer then
        return self
    end
    if self.owner then
        return self.owner:GetPlayer()
    end
    return nil
end

--- 治疗
---@param health number 治疗量
---@param source string|nil 治疗来源
function _M:Heal(health, source)
    self:SetHealth(math.min(self.maxHealth, self.health + health))
end

function _M:SetHealth(health)
    self.health = health
    self.actor.Health = health
    if self.hp_bar then
        self.hp_bar.FillAmount = math.min(1, self.health / self.maxHealth)
    end
    if self.hp_bar_text then
        self.hp_bar_text.Title = string.format("%d/%d", math.ceil(self.health), math.ceil(self.maxHealth))
    end
end

--- 添加护盾
---@param amount number 护盾值
---@param source string|nil 护盾来源
function _M:AddShield(amount, source)
    self.shield = self.shield + amount
end

--- 开始处理死亡逻辑, 如果要移除对象, 请调用 DestroyObject
function _M:Die()
    if self.isDead then return end
    self.isDead = true

    -- 停止导航
    self.actor:StopNavigate()
    local deathTime = 0
    if self.modelPlayer then
        deathTime = self.modelPlayer:OnDead()
    end
    -- 发布死亡事件
    local evt = {
        entity = self,
        deathTime = deathTime
    }
    ServerEventManager.Publish("EntityDeadEvent", evt)
    if not self.isPlayer then
        if evt.deathTime > 0 then
            ServerScheduler.add(function()
                self:DestroyObject()
            end, evt.deathTime, nil, "destroy_" .. self.uuid)
        else
            self:DestroyObject()
        end
    end
end

function _M:GetEnemyGroup()
    if not self.actor then
        print(debug.traceback())
        return {1}
    end
    local groupId = self.actor.CollideGroupID
    if groupId == 3 then
        return {4}
    elseif groupId == 4 then
        return {3}
    else
        return {3, 4}
    end
end

function _M:SendLog( text, ... )
end

function _M:DestroyObject()
    if not self.isDead then
        self:Die()
    end
    self.isDestroyed = true
    
    -- 从场景的ColliderGroup实体列表中移除
    if self.scene and self.actor and self.actor.CollideGroupID then
        local groupId = self.actor.CollideGroupID
        if self.scene.entities[groupId] then
            for i, entity in ipairs(self.scene.entities[groupId]) do
                if entity == self then
                    table.remove(self.scene.entities[groupId], i)
                    break
                end
            end
        end
    end
    
    if self.actor then
        _M.node2Entity[self.actor] = nil
        self.actor:Destroy()
        self.actor = nil
    end
    ServerEventManager.UnsubscribeByKey(self.uuid)
end

function _M:SetLevel(level)
    self.level = level
    self:SetVariable("level", level)
    if self.name_level_billboard then
    self:CreateTitle()
    end
end

--- 设置最大生命值
---@param amount number 最大生命值
function _M:SetMaxHealth(amount)
    local percentage
    if self.maxHealth == 0 then
        percentage = 1
    else
        percentage = math.min(1, self.health / self.maxHealth)
    end

    self.maxHealth = amount
    self.health = self.maxHealth * percentage
    if self.actor then
        self.actor.MaxHealth = self.maxHealth
        self.actor.Health = self.health
    end
    if self.hp_bar then
        self.hp_bar.FillAmount = math.min(1, self.health / self.maxHealth)
    end
    if self.hp_bar_text then
        self.hp_bar_text.Title = string.format("%d/%d", math.ceil(self.health), math.ceil(self.maxHealth))
    end
end

-- 设置游戏场景中使用的actor实例
function _M:setGameActor(actor_)
    self.actor = actor_
    _M.node2Entity[actor_] = self

    if actor_:IsA("Actor") then
        actor_.PhysXRoleType = Enum.PhysicsRoleType.BOX
        actor_.IgnoreStreamSync = false
    end
    
    -- 添加到场景的ColliderGroup实体列表中
    if self.scene and actor_.CollideGroupID then
        local groupId = actor_.CollideGroupID
        if not self.scene.entities[groupId] then
            self.scene.entities[groupId] = {}
        end
        table.insert(self.scene.entities[groupId], self)
    end
end

-- 同步给客户端当前目标的资料
---@param target_ Entity
---@param with_name_ boolean
function _M:syncTargetInfo(target_, with_name_)
    local info_ = {
        cmd = 'cmd_sync_target_info',
        show = 1, -- 0=不显示， 1=显示

        hp = target_.health,
        hp_max = target_.maxHealth
    }

    if with_name_ then
        info_.name = target_.info.nickname
    end

    gg.network_channel:fireClient(self.uin, info_)
end

-- 玩家跳跃
function _M:doJump()
    self.actor:Jump(true)
end

-- hp为0
function _M:checkDead()
    -- 进入战斗状态
    self.combatTime = 10
end

-- 增加经验值
function _M:addExp(exp_)
    self.exp = self.exp + exp_

    local save_flag_ = false
    -- if common_config.expLevelUp[self.level + 1] then
    --     -- 是否升级
    --     if self.exp >= common_config.expLevelUp[self.level + 1] then
    --         self.level = self.level + 1
    --         self:resetBattleData(true)
    --         save_flag_ = true

    --         gg.log('addExp levelUp:', self.exp, self.level)
    --         self:showDamage(0, {
    --             levelup = self.level
    --         }, self)

    --         -- 展示特效
    --         self:showReviveEffect(self:GetPosition())
    --     end
    -- end

    cloudDataMgr.SavePlayerData(self.uin, save_flag_) -- 加经验存盘
end

-- 获得经验值
function _M:getMonExp()
    return 10 * self.level; -- 1级10经验  10级100经验
end

function _M:IsNear(loc, dist)
    return gg.vec.DistanceSq3(loc, self:GetPosition()) < dist ^ 2
end

function _M:CreateTitle(nameOverride, scale, barNameOverride)
    if not self.actor then
        print(debug.traceback())
        return
    end
    scale = scale or 1
    nameOverride = nameOverride or self.name
    local name_level_billboard = self.name_level_billboard
    if not self.name_level_billboard then
        if self._initedTitle then
            return
        end
        self._initedTitle = true
        local number_level = nil
        local title = MainStorage["特效"]["名字"]
        if title then
            if not barNameOverride then
                barNameOverride = self.className
            end
            local template = title[barNameOverride]
            if not template then
                template = title["默认"]
            end
            if template then
                name_level_billboard = template:Clone()
                self.name_level_billboard = name_level_billboard
                name_level_billboard.Parent = self.actor
                name_level_billboard.LocalPosition = template.LocalPosition + Vector3.New(0, self.actor.Size.y + 100 / self.actor.LocalScale.y, 0)
                name_level_billboard.Name = "name_level"
                number_level = name_level_billboard["名字"]
                self._nameTemplate = number_level.Title
            end
        end
        
        self.bb_title = number_level
    end
    if name_level_billboard and name_level_billboard["血条"] then
        if not self.showHealthBar then
            name_level_billboard["血条"].Visible = false
        else
            name_level_billboard["血条"].Visible = true
            self.hp_bar = name_level_billboard["血条"]["进度条"]
            self.hp_bar_text = name_level_billboard["血条"]["生命值"]
            if self.hp_bar then
                self.hp_bar.FillAmount = math.min(1, self.health / self.maxHealth)
            end
            if self.hp_bar_text then
                self.hp_bar_text.Title = string.format("%d/%d", math.ceil(self.health), math.ceil(self.maxHealth))
            end
        end
    end
    if self.bb_title then
        self.bb_title.Title = gg.ProcessVariables(self._nameTemplate:gsub("<NAME>", nameOverride), self, self)
    end
end


-- 显示伤害飘字，闪避，升级
function _M:showDamage(number_, eff_, victim)
    -- 无伤害，无特殊效果
    local victimPosition = victim:GetCenterPosition()
    local position =victimPosition + ( self:GetCenterPosition() - victimPosition):Normalize()*2 * victim:GetSize().x
    if self._attackCache == 0 then
        self._attackCache = self:GetStat("攻击")
    end
    gg.network_channel:fireClient(self.uin, {
        cmd = "ShowDamage",
        amount = number_,
        isCrit = eff_.cr == 1,
        position = {
            x = position.x,
            y = position.y + victim:GetSize().y,
            z = position.z
        },
        percent = 0.3 * number_ / self._attackCache
    })
end

-- 在actor头顶上显示一个文字
function _M:showTips(msg_)
    local damage_billboard = SandboxNode.new('UIBillboard', self.actor)
    damage_billboard.Name = 'tips'
    damage_billboard.Billboard = true
    damage_billboard.CanCollide = false -- 避免产生物理碰撞
    damage_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X

    if self.isPlayer then
        damage_billboard.Size2d = Vector2.New(3, 3)
        damage_billboard.LocalPosition = Vector3.New(0, 258, 0)
    else
        damage_billboard.Size2d = Vector2.New(8, 8)
        damage_billboard.LocalPosition = Vector3.New(0, 330, 0)
    end
    local txt_ = gg.createTextLabel(damage_billboard, msg_)
    txt_.RenderIndex = 101 -- 在高层展示
    -- self.bb_damage = damage_billboard;
    local function long_call(damage_billboard_)
        wait(0.5)
        damage_billboard_:Destroy()
    end
    coroutine.work(long_call, damage_billboard) -- 立即返回，long_call转入协程执行
end

-- 装备一个武器
function _M:equipWeapon(model_src_)
    if self.actor.Hand then
        local model = SandboxNode.new('Model', self.actor.Hand)
        model.Name = 'weapon'

        model.EnablePhysics = false
        model.CanCollide = false
        model.CanTouch = false

        model.ModelId = model_src_ -- 模型
        model.LocalScale = Vector3.New(2, 2, 2)

        self.model_weapon = model
    end
end

-- 玩家改变场景   g10 g20 g30
---@param new_scene string|Scene
function _M:ChangeScene(new_scene)
    if type(new_scene) == "string" then
        new_scene = gg.server_scene_list[new_scene]
    end
    if self.scene and self.scene == new_scene then
        return
    end

    -- 离开旧场景
    if self.scene then
        -- 从旧场景的注册表中移除
        self.scene.uuid2Entity[self.uuid] = nil
        
        -- 从ColliderGroup实体列表中移除
        if self.actor and self.actor.CollideGroupID then
            local groupId = self.actor.CollideGroupID
            if self.scene.entities[groupId] then
                for i, entity in ipairs(self.scene.entities[groupId]) do
                    if entity == self then
                        table.remove(self.scene.entities[groupId], i)
                        break
                    end
                end
            end
        end
        
        -- 如果是玩家，还需要从玩家列表中移除
        if self.isPlayer then---@cast self Player
            self.scene:player_leave(self)
        end
        
        -- 如果是怪物，还需要从怪物列表中移除
        if not self.isPlayer then
            self.scene.monsters[self.uuid] = nil
        end
    end

    -- 进入新场景
    self.scene = new_scene
    self.scene.uuid2Entity[self.uuid] = self
    
    -- 添加到新场景的ColliderGroup实体列表中
    if self.actor and self.actor.CollideGroupID then
        local groupId = self.actor.CollideGroupID
        if not new_scene.entities[groupId] then
            new_scene.entities[groupId] = {}
        end
        table.insert(new_scene.entities[groupId], self)
    end
    
    -- 如果是玩家，还需要添加到玩家列表中
    if self.isPlayer then
        ---@cast self Player
        new_scene.players[self.uin] = self
    end
    if self:Is("Monster") then
        ---@cast self Monster
        new_scene.monsters[self.uuid] = self
    end
end


-- 重置所有属性
function _M:resetBattleData(resethpmp_)
    -- TODO: 刷新属性
end

-- 设置攻击前置时间， 施法前摇，标志位和时间
function _M:setSkillCastTime(skill_uuid_, cast_time_)
    local stat_flags_ = self.stat_flags
    if stat_flags_.skill_uuid then
        self:showTips('正在施法中') -- .. (stat_flags_.cast_time or 'nil') .. '/' .. (stat_flags_.cast_time_max or 'nil' ) )
        return 1
    else
        stat_flags_.skill_uuid = skill_uuid_
        stat_flags_.cast_time = cast_time_
        stat_flags_.cast_time_max = cast_time_

        stat_flags_.cast_pos = self.actor.Position

        gg.network_channel:fireClient(self.uin, {
            cmd = 'cmd_player_spell',
            v = stat_flags_.cast_time,
            max = stat_flags_.cast_time_max
        })
        return 0
    end
end

-- 展示复活特效
function _M:showReviveEffect(pos_)
    if not gg.isServer then
        return
    end
    
    -- 创建特效事件数据
    local effectId = gg.create_uuid("revive_fx_")
    local eventData = {
        effectId = effectId,
        type = "特效",
        name = "复活特效",
        position = pos_ and {pos_.x, pos_.y, pos_.z} or {self:GetPosition().x, self:GetPosition().y, self:GetPosition().z},
        duration = 1.5,
        repeatCount = 1,
        repeatDelay = 0,
        offset = {0, 0, 0},
        data = {
            particleName = "特效/场景用/复活",
            particleAssetId = "sandboxSysId://particles/item_137_red.ent",
            boundToEntity = true,
            boundToBone = nil
        }
    }
    
    -- 如果有actor，添加绑定路径
    if self.actor then
        eventData.boundToPath = gg.GetFullPath(self.actor)
    end
    
    -- 发送特效事件
    if self.isPlayer then
        ---@cast self Player
        self:SendEvent("PlayGraphicEffect", eventData)
    elseif self.scene then
        self.scene:BroadcastEventAround("PlayGraphicEffect", eventData, nil, 0)
    end
end

-- 无法被攻击状态
function _M:CanBeTargeted()
    return not self.isDead and not self.isDestroyed
end

-- tick刷新
function _M:update()
    self.tick = self.tick + 1
    if self.combatTime > 0 then
        self.combatTime = self.combatTime - 1
    end
end

return _M
