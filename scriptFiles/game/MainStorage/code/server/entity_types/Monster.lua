--- V109 miniw-haima
--- 怪物类 (单个怪物) (管理怪物状态)
local setmetatable = setmetatable
local SandboxNode = SandboxNode
local Vector3 = Vector3
local game = game
local math = math
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local common_const = require(MainStorage.code.common.MConst) ---@type common_const
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local BehaviorTree = require(MainStorage.code.server.entity_types.BehaviorTree) ---@type BehaviorTree

local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
-- local skillMgr  = require(MainStorage.code.server.skill.MSkillMgr)  ---@type SkillMgr

---@class Monster:Entity    --怪物类 (单个怪物) (管理怪物状态)
---@field name string 怪物名称
---@field scene_name string 所在场景名称
---@field stat_data table 状态数据
---@field target any 目标对象
---@field mobType MobType 怪物类型
---@field level number 怪物等级
---@field currentBehavior table 当前行为配置
---@field behaviorUpdateTick number 行为更新计时器
---@field New fun(info_:table):Monster
local _M = ClassMgr.Class('Monster', Entity)
local MOB_COLLIDE_GROUP = 3

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

-- 初始化怪物
function _M:OnInit(info_)
    -- 设置怪物类型和等级
    self.mobType = info_.mobType ---@type MobType
    self.showHealthBar = self.mobType.data["显示血条"]
    self.level = info_.level or self.mobType.data["基础等级"] or 1

    for statName, _ in pairs(self.mobType.data["属性公式"]) do
        self:AddStat(statName, self.mobType:GetStatAtLevel(statName, self.level))
    end

    -- 初始化行为系统
    self.currentBehavior = nil
    self.behaviorUpdateTick = 0

    -- 初始化攻击相关变量
    self.attackTimer = 0
    self.isAttacking = false

    -- 初始化技能系统
    self.pendingSkills = {} -- 待释放的技能列表
    self.skillCheckCounter = 0

    -- 初始化音效计时器
    self.idleSoundTimer = 0

    -- 初始化伤害记录
    self.damageRecords = {} ---@type table<string, number> 记录每个玩家造成的伤害
end

_M.GenerateUUID = function(self)
    self.uuid = gg.create_uuid('u_Mob')
end


---@override
function _M:Die()
    -- 发布怪物死亡事件，包含伤害记录
    ServerEventManager.Publish("MobDeadEvent", {
        mob = self,
        damageRecords = self.damageRecords
    })

    Entity.Die(self)
end

--- 设置目标
---@param target Entity|nil
function _M:SetTarget(target)
    if target and target.isInvulnurable then
        return
    end
    if not target and self.mobType.idleSound then
        self.scene:PlaySound(self.mobType.idleSound, self.actor, 0.8, 1.0)
    end
    self.target = target
end

--- 释放触发技能
---@param trigger string 触发时机
---@param target Entity|Vector3 目标
function _M:CastTriggerSkill(trigger, target)
    -- 获取该触发时机的所有技能
    local skills = self.mobType:GetSkillsByTiming(trigger)
    if not skills or #skills == 0 then
        return
    end

    -- 遍历并释放技能
    for _, skill in ipairs(skills) do
        skill:CastSkill(self, target)
    end
end

--------------------------------------------------
-- 模型和视觉方法
--------------------------------------------------

-- 创建怪物模型
function _M:CreateModel(scene)
    self.name = self.mobType.data["显示名"]

    -- 创建Actor
    local container = game.WorkSpace["Ground"][scene.name]["怪物"]
    local actor_monster = gg.GetChild(MainStorage["怪物模型"], self.mobType.data["模型"]) ---@type Actor
    actor_monster = actor_monster:Clone()
    actor_monster:SetParent(container)
    actor_monster.Enabled = true
    actor_monster.Visible = true
    actor_monster.SyncMode = Enum.NodeSyncMode.NORMAL
    actor_monster.CollideGroupID = MOB_COLLIDE_GROUP
    actor_monster.Name = self.uuid

    -- 设置初始位置
    if self.spawnPos then
        actor_monster.LocalPosition = self.spawnPos
    end

    -- 关联到对象
    self:setGameActor(actor_monster)

    -- 加载完成事件处理
    actor_monster.LoadFinish:connect(function(ret)
        local barNameOverride = self.className
        if self.owner then
            barNameOverride = "Minion"
        end
        self:CreateTitle(nil, nil, barNameOverride)
    end)
    self:SetHealth(self:GetStat("生命"))
    if self.mobType.data["状态机"] then
        self:SetAnimationController(self.mobType.data["状态机"])
    end
end

--------------------------------------------------
-- 战斗相关方法
--------------------------------------------------

-- 获取当前行为配置
function _M:GetCurrentBehavior()
    return self.currentBehavior
end

-- 设置当前行为配置
function _M:SetCurrentBehavior(behavior)
    self.currentBehavior = behavior
end

function _M:TryFindTarget(detectRange)
    -- 获取敌对组
    local enemyGroup = self:GetEnemyGroup()
    
    -- 使用场景的新方法查找最近的敌人
    local nearestTarget, distance = self.scene:FindNearestEntity(
        self:GetPosition(),
        detectRange,
        enemyGroup,
        function(entity)
            -- 检查是否是有效的敌对目标
            return entity.isEntity and not entity.isDead and not entity.isInvulnurable and entity:CanBeTargeted()
        end
    )

    -- 如果找到目标，设置为目标
    if nearestTarget then
        self:SetTarget(nearestTarget)
        return true
    end

    return false
end

---获取玩家造成的伤害
---@param player Player 玩家对象
---@return number 玩家造成的总伤害
function _M:GetPlayerDamage(player)
    if not player or not player.uin then return 0 end
    return self.damageRecords[player.uin] or 0
end

---获取所有玩家的伤害记录
---@return table<string, number> 玩家伤害记录表
function _M:GetAllDamageRecords()
    return self.damageRecords
end

function _M:AddHatred(amount, damager)
    local uin = damager.uuid
    if damager.isPlayer then
        uin = damager.uin
    end
    local newHatred = (self.damageRecords[uin] or 0) + amount
    self.damageRecords[uin] = newHatred
    if self.target and self.target ~= damager then
        local targetUin = self.target.uuid
        if self.target.isPlayer then
            targetUin = self.target.uin
        end
        local currentHatred = self.damageRecords[targetUin]
        if not currentHatred or currentHatred < newHatred then
            self:SetTarget(damager)
        end
    end
end

---@override
function _M:Hurt(amount, damager, isCrit)
    -- 播放受击音效

    -- 记录玩家造成的伤害
    if damager then
        self:AddHatred(amount, damager)
    end

    Entity.Hurt(self, amount, damager, isCrit)
    if self.health <= 0 then
        -- print("PlaySound", self.mobType.deadSound)
        if self.mobType.deadSound and damager.isPlayer then ---@cast damager Player
            damager:PlaySound(self.mobType.deadSound, self.actor, 1.0, 1.0)
        end
    else
        if amount > self.health * 0.05 and self.mobType.hitSound and damager.isPlayer then ---@cast damager Player
            damager:PlaySound(self.mobType.hitSound, self.actor, 1.0, 1.0)
        end
    end
    if not self.target then
        self:SetTarget(damager)
    end
end

--------------------------------------------------
-- 移动和位置相关方法
--------------------------------------------------

-- 检查怪物是否距离刷新点太远
function _M:checkTooFarFromPos()
    if not self.spawnPos then
        return
    end

    local currentPos = self:GetPosition()

    -- 如果距离超过80单位(80*80=6400)则重新刷新
    if gg.fast_out_distance(self.spawnPos, currentPos, 6400) then
        self:spawnRandomPos(500, 100, 500) -- 重新刷回出生点附近
    end
end

-- 在指定范围内随机刷新位置
function _M:spawnRandomPos(rangeX, rangeY, rangeZ)
    local randomOffset = {
        x = gg.rand_int_both(rangeX),
        y = gg.rand_int(rangeY),
        z = gg.rand_int_both(rangeZ)
    }

    -- 设置新位置
    self.actor.Position = Vector3.New(self.spawnPos.x + randomOffset.x, self.spawnPos.y + randomOffset.y,
        self.spawnPos.z + randomOffset.z)
end


-- 主更新函数
function _M:update_monster()
    -- 调用父类更新
    self:update()

    -- 每1秒更新一次行为状态
    self.behaviorUpdateTick = self.behaviorUpdateTick + 1
    if self.behaviorUpdateTick >= 10 then -- 10帧 = 1秒
        self.behaviorUpdateTick = 0
        self:UpdateBehavior()
    end

    -- 每帧更新当前行为
    self:UpdateCurrentBehavior()
end

-- 关闭AI
---@param duration  number 持续时间，0则为取消冻结
function _M:Freeze(duration)
    if duration == 0 then
        self.freezeEndTime = nil
        return
    end

    local currentTime = os.time()
    local newEndTime = currentTime + duration

    -- 如果已经有冻结时间，取较大的那个
    if self.freezeEndTime then
        self.freezeEndTime = math.max(self.freezeEndTime, newEndTime)
    else
        self.freezeEndTime = newEndTime
    end
end

function _M:IsFrozen()
    if not self.freezeEndTime then
        return false
    end

    local currentTime = os.time()
    if currentTime >= self.freezeEndTime then
        self.freezeEndTime = nil
        return false
    end

    return true
end

function _M:GetAttackDuration()
    return 1
end

-- 更新行为状态
function _M:UpdateBehavior()
    if self.isDead or self:IsFrozen() then
        return
    end

    -- 如果当前行为可以退出
    local currentBehaviorType = self.currentBehavior and self.currentBehavior["类型"]
    local newBehavior = nil

    -- 如果当前没有行为或当前行为可以退出，尝试进入新行为
    if (not self.currentBehavior or (currentBehaviorType and BehaviorTree[currentBehaviorType] and BehaviorTree[currentBehaviorType]:CanExit(self))) and self.mobType.data["行为"] then
        -- 遍历行为列表
        for _, behavior in ipairs(self.mobType.data["行为"]) do
            local behaviorType = behavior["类型"]
            if BehaviorTree[behaviorType] and BehaviorTree[behaviorType]:CanEnter(self, behavior) then
                newBehavior = behavior
                break
            end
        end

        -- 只有当新行为与当前行为不同时才执行切换
        if newBehavior and (not currentBehaviorType or newBehavior["类型"] ~= currentBehaviorType) then
            -- 退出当前行为
            if currentBehaviorType and BehaviorTree[currentBehaviorType] then
                BehaviorTree[currentBehaviorType]:OnExit(self)
            end
            -- 进入新行为
            self.currentBehavior = newBehavior
            BehaviorTree[newBehavior["类型"]]:OnEnter(self)
            -- gg.log("EnterBehavior", self, newBehavior["类型"])
        end
    end
end

-- 更新当前行为
function _M:UpdateCurrentBehavior()
    if self:IsFrozen() then
        return
    end

    local currentBehaviorType = self.currentBehavior and self.currentBehavior["类型"]
    if currentBehaviorType and BehaviorTree[currentBehaviorType] then
        BehaviorTree[currentBehaviorType]:Update(self)
    end
end

-- --- 处理待释放的技能
-- function _M:ProcessPendingSkills()
--     if #self.pendingSkills == 0 then return end
    
--     -- 复制待释放技能列表
--     local skillsToCast = self.pendingSkills
--     self.pendingSkills = {}
    
--     -- 释放所有待释放的技能
--     for _, skill in ipairs(skillsToCast) do
--         skill:CastSkill(self, self.target)
--     end
-- end

function _M:DestroyObject()
    -- 从场景中移除
    if self.scene then
        self.scene.monsters[self.uuid] = nil
    end
    Entity.DestroyObject(self)
end

return _M
