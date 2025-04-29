
--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local Enum         = Enum
local math         = math
local Vector2      = Vector2
local ColorQuad    = ColorQuad
local wait         = wait
local game         = game
local pairs        = pairs


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local battleMgr         = require(MainStorage.code.server.BattleMgr)  ---@type BattleMgr

local skillUtils        = require(MainStorage.code.server.skill.MSkillUtils) ---@type SkillUtils
local CSkillBase        = require(MainStorage.code.server.skill.CSkillBase)  ---@type CSkillBase


-- 技能 冰箭
---@class CSkill_2005 : CSkillBase
local _M = CommonModule.Class( "CSkill_2005", CSkillBase )
function _M:OnInit( info_ )
    CSkillBase:OnInit( info_ )
    self.missileObj = nil   --投掷物 冰箭
end


--施法前摇
function _M:castTimePre()
    local attacker_ = self.from            --攻击发起者
    --施法动作
    skillUtils:showSpellEffect( attacker_, 128, self.skill_config.cast_time*0.1 )         --特效
    attacker_:play_animation( '100112', 1.0, 0 )       --spell
end



--攻击或者施法
--return  0=成功  大于0=失败
function _M:castSpell()
    if  CSkillBase:castSpell() > 0 then
        return 1
    end

    self:createMissileObject()    --发射投掷物
    return 0  --成功
end



-- 建立一个投掷物（冰球）
function _M:createMissileObject()

    local attacker_ = self.from   --攻击发起者
    attacker_:play_animation( '100105', 1.5, 1 )  --attack 人物动作

    --投出冰球
    local actor_ = attacker_.actor
    local v3_dir = gg.getDirVector3( actor_ )    --朝向方向

    local iceball_ = SandboxNode.new('Model', game.WorkSpace )
    iceball_.Parent   = gg.serverGetContainerWeapon(self.scene_name)
    iceball_.Name     = 'model_ice'

    iceball_.Anchored = false
    iceball_.EnableGravity  = false
    iceball_.OwnerUin = attacker_.uin

    --iceball_.LocalScale = Vector3.new( 2,    2,  2 )
    iceball_.Size       = Vector3.new( 64, 128, 64 )
    iceball_.Center     = Vector3.new(  0,  32,  0 )

    iceball_.CanCollide    = false
    --iceball_.EnablePhysics = true
    --iceball_.CanTouch      = true
    --iceball_.CollideGroupID = 1    --与地面碰撞


    self.missileObj = iceball_


    --大火球特效
    local expl = SandboxNode.new('DefaultEffect', iceball_ )
    expl.AssetID = common_config.assets_dict.effect.iceball_effect


    local function distroy_iceball_( time_ )
        iceball_.Velocity = Vector3.new(0,0,0)
        wait(time_)
        self:cleanMissileObj()
    end


    local function hit_target( target_, node_ )
        iceball_.Parent = node_

        local damage_, eff_= battleMgr.calculate_attack( attacker_, target_, self.skill_config )
        target_:showDamage( damage_, eff_ )
        if  damage_ > 0 then
            target_:been_hit( attacker_ )
            target_:slowDown( 30, 0.35  )    --被减速 1秒=10帧
            self:showBlastEffect( target_:getPosition() )
            distroy_iceball_(0.5)
        end
    end


    --碰撞回调
    local function touch_func(node, pos, normal)
        if  node.ClassType == 'Actor' then

            local target_ = attacker_.target
            if  node.Name == target_.uuid or node.OwnerUin == target_.uin then
                --击中目标或者玩家
                hit_target( target_, node )
            else

            end

        else
            --击中其他物体
            --self:showBlastEffect( pos )
            --distroy_iceball_(0.5)
        end
    end
    iceball_.Touched:connect( touch_func )


    --初始位置
    local attack_pos_ = attacker_:getPosition()
    iceball_.Position = Vector3.new(attack_pos_.x, attack_pos_.y + 150, attack_pos_.z)
    iceball_.LocalScale = Vector3.new( 2, 2, 2 )

    --方向
    local attack_euler_ = attacker_.actor.Euler;
    iceball_.Euler = Vector3.new( attack_euler_.x + 180 , attack_euler_.y, attack_euler_.z )

    --速度
    wait(0.2)

    if  attacker_.target then
        --有目标的情况下
        v3_dir = attacker_:getPosition() - attacker_.target:getPosition()
        Vector3.Normalize( v3_dir )
    end

    iceball_.Velocity = v3_dir * -2048

end



--展示爆炸特效
function _M:showBlastEffect( pos_ )
    local function thread_wrap()
        --爆炸特效
        local expl = SandboxNode.new('DefaultEffect', game.WorkSpace )
        expl.AssetID = common_config.assets_dict.effect.iceball_bomb_effect
        expl.Position = Vector3.new( pos_.x, pos_.y+100, pos_.z )
        --expl.LocalScale = Vector3.new( 2, 2, 2 )
        wait(1)
        expl:Destroy()
    end
    gg.thread_call( thread_wrap )
end



--清理节点(节点会挂在game.WorldSpace下，destory后节约内存)
function _M:cleanMissileObj()
    if  self.missileObj then
        self.missileObj:Destroy()
        self.missileObj = nil
    end
end


function _M:DestroySkill()
    self:cleanMissileObj()
end


--tick
function _M:update()
    self.tick = self.tick + 1
    if  self.tick > 60 then     --最长时间 60帧=6秒
        self.stat = 99
        return self.stat
    end

    return self.stat
end


return _M
