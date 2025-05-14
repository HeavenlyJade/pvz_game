--- V109 miniw-haima
--- 怪物类 (单个怪物) (管理怪物状态)

local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local game         = game
local math         = math
local pairs        = pairs

local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local ClassMgr      = require(MainStorage.code.common.ClassMgr)    ---@type ClassMgr
local BattleState   = require(MainStorage.code.server.entity_types.BattleState) ---@type BattleState

local ServerEventManager      = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local Entity   = require(MainStorage.code.server.entity_types.Entity)          ---@type Entity
-- local skillMgr  = require(MainStorage.code.server.skill.MSkillMgr)  ---@type SkillMgr

local BATTLE_STAT_IDLE  = BattleState.BATTLE_STAT_IDLE
local BATTLE_STAT_FIGHT = BattleState.BATTLE_STAT_FIGHT
local BATTLE_STAT_DEAD_WAIT = BattleState.BATTLE_STAT_DEAD_WAIT
local BATTLE_STAT_WAIT_SPAWN = BattleState.BATTLE_STAT_WAIT_SPAWN

---@class Monster:Entity    --怪物类 (单个怪物) (管理怪物状态)
---@field name string 怪物名称
---@field scene_name string 所在场景名称
---@field battle_stat number 战斗状态
---@field stat_data table 状态数据
---@field target any 目标对象
---@field mobType MobType 怪物类型
---@field level number 怪物等级
---@field New fun(info_:table):Monster
local _M = ClassMgr.Class('Monster', Entity)

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

-- 初始化怪物
function _M:OnInit(info_)
    Entity:OnInit(info_)    -- 父类初始化
    self.uuid = gg.create_uuid('m')  -- 唯一ID
    
    -- 设置怪物类型和等级
    self.mobType = info_.mobType
    self.level = info_.level or self.mobType.data["基础等级"] or 1
    
    for statName, _ in pairs(self.mobType.data["属性公式"]) do
        self:AddStat(statName, self.mobType:GetStatAtLevel(statName, self.level))
    end
    -- 初始化状态数据
    self.stat_data = {
        idle = {
            wait = 0,
            select = 0
        },
        fight = {
            wait = 0
        }
    }
    
    -- 设置初始战斗状态
    self:setBattleStat(BATTLE_STAT_IDLE)
end

---@override
function _M:Die()
    -- 发布死亡事件
    ServerEventManager.Publish("MobDeadEvent", { mob = self.mob })
    Entity.Die(self)
end

--------------------------------------------------
-- 模型和视觉方法
--------------------------------------------------

-- 创建怪物模型
function _M:CreateModel()
    self.name = self.mobType.data["显示名"]
    
    -- 创建Actor
    local container = game.WorkSpace["Ground"][self.scene.name]["怪物"]
    local actor_monster = SandboxNode.new('Actor', container)
    
    -- 设置模型和属性
    print("model".. self.mobType.data["模型"])
    actor_monster.ModelId = self.mobType.data["模型"]
    actor_monster.Name = self.uuid
    
    -- 设置初始位置
    if self.spawnPos then
        actor_monster.LocalPosition = self.spawnPos
    end
    
    -- 关联到对象
    self:setGameActor(actor_monster)
    
    -- 加载完成事件处理
    actor_monster.LoadFinish:connect(function(ret)
        -- 创建头顶标题
        self:createTitle(actor_monster.Size[1])
    end)
    self:SetHealth(self:GetStat("生命"))
end

--------------------------------------------------
-- 战斗相关方法
--------------------------------------------------

-- 尝试获取目标玩家
function _M:tryGetTargetPlayer()
    -- 在场景中寻找目标
    local player_ = self.scene and self.scene:tryGetTarget(self:GetPosition())
    
    if player_ then
        self:SetTarget(player_)  -- 被击中/仇恨处理
    end
end

function _M:SetTarget(target)
    self.target = target
end

function _M:Hurt(amount, damager, isCrit)
    Entity.Hurt(self, amount, damager, isCrit)
    if not self.target then
        self:SetTarget(damager)
    end
end

--------------------------------------------------
-- 移动和位置相关方法
--------------------------------------------------

-- 检查怪物是否距离刷新点太远
function _M:checkTooFarFromPos()
    if not self.spawnPos then return end
    
    local currentPos = self:GetPosition()
    
    -- 如果距离超过80单位(80*80=6400)则重新刷新
    if gg.fast_out_distance(self.spawnPos, currentPos, 6400) then
        self:spawnRandomPos(500, 100, 500)  -- 重新刷回出生点附近
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
    self.actor.Position = Vector3.New(
        self.spawnPos.x + randomOffset.x,
        self.spawnPos.y + randomOffset.y,
        self.spawnPos.z + randomOffset.z
    )
end

--------------------------------------------------
-- AI状态机方法
--------------------------------------------------

-- 处理空闲状态
function _M:checkIdle(ticks, idle_data_)
    -- 减少等待时间
    if idle_data_.wait > 0 then
        idle_data_.wait = idle_data_.wait - ticks
        return
    end
    
    -- 重新选择行动
    idle_data_.select = gg.rand_int(3)  -- 随机选择行动 [0-2]
    
    if idle_data_.select == 0 then
        -- 站立不动
        idle_data_.wait = 60 + gg.rand_int(10)
        self:play_animation('100100', 1.0, 0)  -- 站立动画
        
    elseif idle_data_.select == 1 then
        -- 随机漫步
        idle_data_.wait = 60 + gg.rand_int(10)
        
        -- 设置移动速度和导航到随机位置
        self.actor.Movespeed = self:GetStat("速度")
        self.actor:NavigateTo(self:GetPosition() + Vector3.New(
            gg.rand_int_both(1600),
            0,
            gg.rand_int_both(1600)
        ))
        self:play_animation('100101', 1.0, 0)  -- 行走动画
        
    elseif idle_data_.select == 2 then
        -- 随机动作
        idle_data_.wait = 120 + gg.rand_int(10)
        
        if idle_data_.wait % 5 == 1 then
            self:play_animation('100102', 1.0, 0)  -- 躺下
        else
            self:play_animation('100103', 1.0, 0)  -- 坐下
        end
    else
        -- 默认站立
        self:play_animation('100100', 1.0, 0)
        idle_data_.wait = 20 + gg.rand_int(10)
    end
end

-- 处理战斗状态
function _M:checkFight(ticks, fight_data_)
    -- 减少等待时间
    if fight_data_.wait > 0 then
        fight_data_.wait = fight_data_.wait - ticks
        return
    end
    
    -- 检查是否有目标
    if not self.target then
        -- 失去目标，返回空闲状态
        self:setBattleStat(BATTLE_STAT_IDLE)
        return
    end
    
    -- 获取目标位置
    local targetPos = self.target:GetPosition()
    
    -- 计算靠近目标的位置（带随机偏移）
    local dir = self:GetPosition() - targetPos
    local dirWithRandomOffset = Vector3.New(
        dir.x + gg.rand_int_both(16),
        0,
        dir.z + gg.rand_int_both(16)
    )
    dirWithRandomOffset:Normalize()
    
    -- 获取技能和攻击范围
    local skill, attackRange = self:getSkill1AndRange()
    local approachPos = Vector3.New(
        targetPos.x + dirWithRandomOffset.x * 32,
        targetPos.y,
        targetPos.z + dirWithRandomOffset.z * 32
    )
    
    -- 判断是移动还是攻击
    if gg.out_distance(self:GetPosition(), approachPos, attackRange * 0.9) then
        -- 目标不在攻击范围内，导航接近
        self.actor:NavigateTo(approachPos)
        self:play_animation('100101', 1.0, 0)  -- 行走动画
    else
        -- 目标在攻击范围内，停止移动并攻击
        self.actor:StopNavigate()
        self:Attack(self.target, 0, "entity_attack")
    end
    
    -- 设置下次更新时间
    fight_data_.wait = 5  -- 等待5帧(0.5秒)再次检查
end

-- 怪物状态机更新
function _M:checkMonStat(ticks)
    if not self.battle_stat or not self.stat_data then return end
    
    local currentState = self.battle_stat
    if currentState == BATTLE_STAT_IDLE then
        -- 空闲状态
        self:checkIdle(ticks, self.stat_data.idle)
        
    elseif currentState == BATTLE_STAT_FIGHT then
        -- 战斗状态
        self:checkFight(ticks, self.stat_data.fight)
        
    elseif currentState == BATTLE_STAT_DEAD_WAIT then
        -- 死亡等待状态处理
        -- 可以添加死亡相关处理逻辑
        
    elseif currentState == BATTLE_STAT_WAIT_SPAWN then
        -- 等待重生状态处理
        -- 可以添加重生相关处理逻辑
    end
end

---@override
function _M:createHpBar( root_ )
    if self.mobType["显示血条"] then
        local bg_  = SandboxNode.new( "UIImage", root_ )
        local bar_ = SandboxNode.new( "UIImage", root_ )

        bg_.Name = 'spell_bg'
        bar_.Name = 'spell_bar'

        bg_.Icon  = "RainbowId&filetype=5://246821862532780032"
        bar_.Icon = "RainbowId&filetype=5://246821862532780032"

        bg_.FillColor  = ColorQuad.New( 255, 255, 255, 255 )
        bar_.FillColor = ColorQuad.New( 255, 0, 0, 255 )

        bg_.LayoutHRelation = Enum.LayoutHRelation.Middle
        bg_.LayoutVRelation = Enum.LayoutVRelation.Bottom

        bar_.LayoutHRelation = Enum.LayoutHRelation.Middle
        bar_.LayoutVRelation = Enum.LayoutVRelation.Bottom

        bg_.Size   = Vector2.New(256, 32)
        bar_.Size  = Vector2.New(256, 32)

        bg_.Pivot  = Vector2.New(0.5, -1.5)
        bar_.Pivot = Vector2.New(0.5, -1.5)

        bar_.FillMethod = Enum.FillMethod.Horizontal
        bar_.FillAmount = 1
        self.hp_bar = bar_
    end
end

-- 主更新函数
function _M:update_monster()
    -- 调用父类更新
    self:update()
    
    -- 更新状态机
    self:checkMonStat(1)
    
    -- 检查怪物是否离开刷新点太远
    if self.tick % 50 == 0 then  -- 每50帧检查一次
        self:checkTooFarFromPos()
    end
    
    -- 在空闲状态下寻找目标
    -- if self.battle_stat == BATTLE_STAT_IDLE and self.tick % 20 == 0 then
    --     self:tryGetTargetPlayer()
    -- end
end

return _M