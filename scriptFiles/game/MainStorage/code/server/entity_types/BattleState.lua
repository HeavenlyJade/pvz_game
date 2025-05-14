local MainStorage = game:GetService("MainStorage")
local common_const = require(MainStorage.code.common.MConst) ---@type common_const
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

local BATTLE_STAT_IDLE = common_const.BATTLE_STAT.IDLE
local BATTLE_STAT_FIGHT = common_const.BATTLE_STAT.FIGHT
local BATTLE_STAT_DEAD_WAIT = common_const.BATTLE_STAT.DEAD_WAIT
local BATTLE_STAT_WAIT_SPAWN = common_const.BATTLE_STAT.WAIT_SPAWN

---@class BattleState:Class
---@field enter fun(self:Entity)
---@field exit fun(self:Entity)
---@field update fun(self:Entity)
local BattleState = ClassMgr.Class("BattleState")

function BattleState:OnInit()
    self.enter = function(self) end
    self.exit = function(self) end
    self.update = function(self) end
end

-- 调整一下BattleState类: 保留四个基本类型 静止, 战斗, 死亡, 复活.  制作 怪物_静止, 怪物_随机移动, DOM_MOVE, MOB_ATTACK@Entity.lua @Monster.lua @Player.lua 
---@class IdleState:BattleState
local IdleState = ClassMgr.Class("IdleState", BattleState)

function IdleState:OnInit()
    self.update = function(entity)
        -- 只处理怪物的空闲状态
        if not entity.isPlayer then
            local idle_data_ = entity.stat_data.idle
            
            -- 减少等待时间
            if idle_data_.wait > 0 then
                idle_data_.wait = idle_data_.wait - 1
                return
            end
            
            -- 重新选择行动
            idle_data_.select = gg.rand_int(3)  -- 随机选择行动 [0-2]
            
            if idle_data_.select == 0 then
                -- 站立不动
                idle_data_.wait = 60 + gg.rand_int(10)
                entity:play_animation('100100', 1.0, 0)  -- 站立动画
                
            elseif idle_data_.select == 1 then
                -- 随机漫步
                idle_data_.wait = 60 + gg.rand_int(10)
                
                -- 设置移动速度和导航到随机位置
                entity.actor.Movespeed = entity:GetStat("速度")
                entity.actor:NavigateTo(entity:GetPosition() + Vector3.New(
                    gg.rand_int_both(1600),
                    0,
                    gg.rand_int_both(1600)
                ))
                entity:play_animation('100101', 1.0, 0)  -- 行走动画
                
            elseif idle_data_.select == 2 then
                -- 随机动作
                idle_data_.wait = 120 + gg.rand_int(10)
                
                if idle_data_.wait % 5 == 1 then
                    entity:play_animation('100102', 1.0, 0)  -- 躺下
                else
                    entity:play_animation('100103', 1.0, 0)  -- 坐下
                end
            else
                -- 默认站立
                entity:play_animation('100100', 1.0, 0)
                idle_data_.wait = 20 + gg.rand_int(10)
            end
        end
    end
end

---@class FightState:BattleState
local FightState = ClassMgr.Class("FightState", BattleState)

function FightState:OnInit()
    self.update = function(entity)
        -- 只处理怪物的战斗状态
        if not entity.isPlayer then
            local fight_data_ = entity.stat_data.fight
            
            -- 减少等待时间
            if fight_data_.wait > 0 then
                fight_data_.wait = fight_data_.wait - 1
                return
            end
            
            -- 检查是否有目标
            if not entity.target then
                -- 失去目标，返回空闲状态
                entity:setBattleStat(BATTLE_STAT_IDLE)
                return
            end
            
            -- 获取目标位置
            local targetPos = entity.target:GetPosition()
            
            -- 计算靠近目标的位置（带随机偏移）
            local dir = entity:GetPosition() - targetPos
            local dirWithRandomOffset = Vector3.New(
                dir.x + gg.rand_int_both(16),
                0,
                dir.z + gg.rand_int_both(16)
            )
            dirWithRandomOffset:Normalize()
            
            -- 获取技能和攻击范围
            local skill, attackRange = entity:getSkill1AndRange()
            local approachPos = Vector3.New(
                targetPos.x + dirWithRandomOffset.x * 32,
                targetPos.y,
                targetPos.z + dirWithRandomOffset.z * 32
            )
            
            -- 判断是移动还是攻击
            if gg.out_distance(entity:GetPosition(), approachPos, attackRange * 0.9) then
                -- 目标不在攻击范围内，导航接近
                entity.actor:NavigateTo(approachPos)
                entity:play_animation('100101', 1.0, 0)  -- 行走动画
            else
                -- 目标在攻击范围内，停止移动并攻击
                entity.actor:StopNavigate()
                entity:Attack(entity.target, 0, "entity_attack")
            end
            
            -- 设置下次更新时间
            fight_data_.wait = 5  -- 等待5帧(0.5秒)再次检查
        end
    end
end

---@class DeadWaitState:BattleState
local DeadWaitState = ClassMgr.Class("DeadWaitState", BattleState)

function DeadWaitState:OnInit()
    self.enter = function(entity)
        entity.actor:StopNavigate() -- 停止导航
        if entity.isPlayer then
            -- 发消息给客户端，禁止操作
            gg.network_channel:fireClient(entity.uin, {
                cmd = 'cmd_player_actor_stat',
                v = 'dead'
            })
            entity.stat_data.dead_wait.wait = 30
        else
            entity.stat_data.dead_wait.wait = 60
        end
        entity:play_animation('100106', 1.0, 2) -- dead
    end

    self.update = function(entity)
        -- 死亡后定住N帧
        local data_ = entity.stat_data.dead_wait
        if data_.wait > 0 then
            data_.wait = data_.wait - 1
        else
            entity:setBattleStat(BATTLE_STAT_WAIT_SPAWN)
        end
    end
end

---@class WaitSpawnState:BattleState
local WaitSpawnState = ClassMgr.Class("WaitSpawnState", BattleState)

function WaitSpawnState:OnInit()
    self.enter = function(entity)
        if entity.isPlayer then
            entity.stat_data.wait_spawn.wait = 10
            entity:ChangeScene('g0') -- 返回大厅
        else
            entity.stat_data.wait_spawn.wait = 30
        end

        gg.log('set WAIT_SPAWN', entity.uuid)

        -- 回到起始坐标
        entity.actor.Visible = false
        entity.actor.Position = entity.spawnPos
        wait(0.02)
        entity.actor.Position = entity.spawnPos

        if entity.isPlayer then
            entity:showReviveEffect(entity.spawnPos)
        end
    end

    self.update = function(entity)
        -- 等待重生
        local data_ = entity.stat_data.wait_spawn
        if data_.wait > 0 then
            data_.wait = data_.wait - 1
        else
            entity:revive() -- 复活
        end
    end
end

-- 创建状态实例
local states = {
    [BATTLE_STAT_IDLE] = IdleState.New(),
    [BATTLE_STAT_FIGHT] = FightState.New(),
    [BATTLE_STAT_DEAD_WAIT] = DeadWaitState.New(),
    [BATTLE_STAT_WAIT_SPAWN] = WaitSpawnState.New()
}

return {
    states = states,
    BATTLE_STAT_IDLE = BATTLE_STAT_IDLE,
    BATTLE_STAT_FIGHT = BATTLE_STAT_FIGHT,
    BATTLE_STAT_DEAD_WAIT = BATTLE_STAT_DEAD_WAIT,
    BATTLE_STAT_WAIT_SPAWN = BATTLE_STAT_WAIT_SPAWN
} 