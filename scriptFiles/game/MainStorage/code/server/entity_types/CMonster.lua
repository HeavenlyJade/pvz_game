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
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule

local CLiving   = require(MainStorage.code.server.entity_types.CLiving)          ---@type CLiving
local skillMgr  = require(MainStorage.code.server.skill.MSkillMgr)  ---@type SkillMgr

local BATTLE_STAT_IDLE  = common_const.BATTLE_STAT.IDLE
local BATTLE_STAT_FIGHT = common_const.BATTLE_STAT.FIGHT
local BATTLE_STAT_DEAD_WAIT = common_const.BATTLE_STAT.DEAD_WAIT
local BATTLE_STAT_WAIT_SPAWN = common_const.BATTLE_STAT.WAIT_SPAWN

---@class CMonster:CLiving    --怪物类 (单个怪物) (管理怪物状态)
---@field mon_config table 怪物配置数据
---@field name string 怪物名称
---@field scene_name string 所在场景名称
---@field battle_stat number 战斗状态
---@field stat_data table 状态数据
---@field target any 目标对象
local _M = CommonModule.Class('CMonster', CLiving)

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

-- 初始化怪物
function _M:OnInit(info_)
    CLiving:OnInit(info_)    -- 父类初始化
    self.uuid = gg.create_uuid('m')  -- 唯一ID
    
    -- 加载怪物配置
    self.mon_config = common_config.dict_monster_config[info_.id]
    
    -- 设置怪物等级
    if self.mon_config then
        self.mon_config.level = info_.level
        CLiving.initBattleData(self, self.mon_config)  -- 初始化战斗数据
    else
        gg.log("警告: 怪物配置未找到，ID:", info_.id)
    end
end

-- 获取怪物位置
function _M:getPosition()
    return self.actor and self.actor.Position or Vector3.new(0, 0, 0)
end

--------------------------------------------------
-- 模型和视觉方法
--------------------------------------------------

-- 创建怪物模型
function _M:createModel()
    local info_ = self.info
    self.name = self.mon_config.name
    
    -- 创建Actor
    local container = gg.serverGetContainerMonster(self.scene_name)
    local actor_monster = SandboxNode.new('Actor', container)
    
    -- 设置模型和属性
    actor_monster.ModelId = 'sandboxSysId://entity/' .. self.mon_config.id .. '/body.omod'
    actor_monster.Name = self.uuid
    
    -- 设置初始位置
    if info_.x then
        actor_monster.LocalPosition = Vector3.new(info_.x, info_.y, info_.z)
    end
    
    -- 关联到对象
    self:setGameActor(actor_monster)
    
    -- 加载完成事件处理
    actor_monster.LoadFinish:connect(function(ret)
        -- 设置碰撞盒
        actor_monster.Size = Vector3.new(120, 160, 120)  -- 碰撞盒大小
        actor_monster.Center = Vector3.new(0, 80, 0)     -- 碰撞盒中心
        
        -- 创建头顶标题
        self:createTitle({
            name = self.mon_config.name,
            level = self.level,
            high = self.mon_config.high
        })
    end)
end

--------------------------------------------------
-- 战斗相关方法
--------------------------------------------------

-- 自动回血蓝
function _M:checkHPMP()
    if self.battle_data.hp <= 0 then
        return
    end
    
    -- 回血
    if self.battle_data.hp < self.battle_data.hp_max then
        self.battle_data.hp = self.battle_data.hp + 1
    end
    
    -- 回蓝
    if self.battle_data.mp < self.battle_data.mp_max then
        self.battle_data.mp = self.battle_data.mp + 2
    end
end

-- 尝试获取目标玩家
function _M:tryGetTargetPlayer()
    -- 在场景中寻找目标
    local player_ = self.scene and self.scene:tryGetTarget(self:getPosition())
    
    if player_ then
        self:been_hit(player_)  -- 被击中/仇恨处理
    end
end

--------------------------------------------------
-- 移动和位置相关方法
--------------------------------------------------

-- 检查怪物是否距离刷新点太远
function _M:checkTooFarFromPos()
    if not self.info or not self.info.x then return end
    
    local spawnPos = Vector3.new(self.info.x, self.info.y, self.info.z)
    local currentPos = self:getPosition()
    
    -- 如果距离超过80单位(80*80=6400)则重新刷新
    if gg.fast_out_distance(spawnPos, currentPos, 6400) then
        self:spawnRandomPos(500, 100, 500)  -- 重新刷回出生点附近
    end
end

-- 在指定范围内随机刷新位置
function _M:spawnRandomPos(rangeX, rangeY, rangeZ)
    if not self.info or not self.actor then return end
    
    local spawnPos = self.info
    local randomOffset = {
        x = gg.rand_int_both(rangeX),
        y = gg.rand_int(rangeY),
        z = gg.rand_int_both(rangeZ)
    }
    
    -- 设置新位置
    self.actor.Position = Vector3.new(
        spawnPos.x + randomOffset.x,
        spawnPos.y + randomOffset.y,
        spawnPos.z + randomOffset.z
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
        local pos_ = self.info  -- 出生点
        
        -- 设置移动速度和导航到随机位置
        self.actor.Movespeed = self.orgMoveSpeed
        self.actor:NavigateTo(Vector3.new(
            pos_.x + gg.rand_int_both(1600),
            pos_.y,
            pos_.z + gg.rand_int_both(1600)
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
    local targetPos = self.target:getPosition()
    
    -- 计算靠近目标的位置（带随机偏移）
    local dir = self:getPosition() - targetPos
    local dirWithRandomOffset = Vector3.new(
        dir.x + gg.rand_int_both(16),
        0,
        dir.z + gg.rand_int_both(16)
    )
    Vector3.Normalize(dirWithRandomOffset)
    
    -- 获取技能和攻击范围
    local skill, attackRange = self:getSkill1AndRange()
    local approachPos = Vector3.new(
        targetPos.x + dirWithRandomOffset.x * 32,
        targetPos.y,
        targetPos.z + dirWithRandomOffset.z * 32
    )
    
    -- 判断是移动还是攻击
    if gg.out_distance(self:getPosition(), approachPos, attackRange * 0.9) then
        -- 目标不在攻击范围内，导航接近
        self.actor:NavigateTo(approachPos)
        self:play_animation('100101', 1.0, 0)  -- 行走动画
    else
        -- 目标在攻击范围内，停止移动并攻击
        self.actor:StopNavigate()
        skillMgr.tryAttackSpell(self, skill)  -- 使用技能攻击
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
    
    -- 检查自动回血
    if self.tick % 10 == 0 then  -- 每10帧恢复一次
        self:checkHPMP()
    end
    
    -- 在空闲状态下寻找目标
    -- if self.battle_stat == BATTLE_STAT_IDLE and self.tick % 20 == 0 then
    --     self:tryGetTargetPlayer()
    -- end
end

return _M