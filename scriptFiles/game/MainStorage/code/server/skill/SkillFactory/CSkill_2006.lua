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

local skill_config  = common_config.skill_def[2006]


-- 技能  回旋镖
---@class CSkill_2006 : CSkillBase
local _M = CommonModule.Class( "CSkill_2006", CSkillBase )
function _M:OnInit( info_ )
    CSkillBase:OnInit( info_ )

    self.dir        = nil    --方向
    self.speed      = 100    --速度
    self.missileObj = nil   --投掷物 冰箭
end


--攻击或者施法
--return  0=成功  大于0=失败
function _M:castSpell()
    if  CSkillBase:castSpell() > 0 then
        return 1
    end

    self:createMissileObject()       --发射投掷物
    return 0  --成功
end



-- 建立一个投掷物
function _M:createMissileObject()

    local attacker_ = self.from            --攻击发起者

    --投出
    local actor_ = attacker_.actor
    local v3_dir = gg.getDirVector3( actor_ )    --朝向方向


    --建立投掷物
    local blade = SandboxNode.new('DefaultEffect', gg.serverGetContainerWeapon(self.scene_name) )
    blade.AssetID = common_config.assets_dict.effect.blade_effect
    --blade.Parent   = gg.serverGetContainerWeapon(self.scene_name)
    blade.Name     = 'm_blade'
    blade.Visible  = true

    --blade.Anchored = false
    --blade.EnableGravity  = false
    blade.OwnerUin = attacker_.uin

    blade.LocalScale = Vector3.new( 2,  2,  2 )
    --blade.Size       = Vector3.new( 32, 128, 32 )
    --blade.Center     = Vector3.new( 0,   32,  0 )

    --blade.EnablePhysics = true
    --blade.CanCollide    = false
    --blade.CanTouch      = true
    --blade.CollideGroupID = 1    --与地面碰撞

    self.missileObj = blade


    --初始位置
    local attack_pos_ = attacker_:getPosition()
    blade.Position = Vector3.new(attack_pos_.x, attack_pos_.y + 150, attack_pos_.z)

    self.target = attacker_.target

    --方向
    --local attack_euler_
    --if  self.target then
        --attack_euler_ = gg.getEulerByPositon( attacker_:getPosition(), self.target:getPosition() )
    --else
        --attack_euler_ = attacker_.actor.Euler   --攻击者朝向
    --end
    --blade.Euler = Vector3.new( attack_euler_.x - 90 , attack_euler_.y, attack_euler_.z )    --模型自身朝上，需要向x旋转90度

    --if  self.target then
        --有目标的情况下
        --v3_dir = attacker_:getPosition() - self.target:getPosition()
        --Vector3.Normalize( v3_dir )
    --else
        --v3_dir = gg.getDirVector3( attacker_.actor )    --朝向方向
    --end

    --blade.Velocity = v3_dir * -2048  --反方向，速度

    self.dir   = v3_dir
    self.speed = 160

    self.stat = 1

end




--判断是否攻击到了目标
function _M:checkMissionAttack()

    if  self.missileObj then
        local attacker_ = self.from

        --速度改变
        self.speed = self.speed - 10
        local pos1_ = self.missileObj.Position

        --移动
        self.missileObj.Position = Vector3.new( pos1_.x - self.dir.x*self.speed, pos1_.y, pos1_.z - self.dir.z*self.speed )


        if  self.speed <= -160 then
            self.stat = 99
        end


        -- 判断【攻击者】的【攻击点】是否击中【目标】
        local function tmp_attack_target_( target_ )
            local pos2_ = target_:getPosition()
            if  gg.out_distance( pos1_, pos2_, self.skill_config.size * 0.5 ) then
                return 0   --未击中
            else
                local damage_, eff_ = battleMgr.calculate_attack( attacker_, target_, self.skill_config )
                target_:showDamage( damage_, eff_ )
                if  damage_ > 0 then
                    target_:been_hit( attacker_ )
                end
            end
        end


        --每0.2秒判断一次伤害
        if self.tick % 2 == 0 then
            if  attacker_:isPlayer() then
                --玩家发起的攻击，再判断其他怪物目标
                for _, monster_ in pairs( attacker_.scene.monsters ) do
                    tmp_attack_target_( monster_ )
                    --if  tmp_attack_target_( monster_ ) == 1 then
                        --if  not attacker_.target then
                            --attacker_:changeTarget( monster_ )  --设置为当前目标
                        --end
                    --end
                end

            else
                for _, monster_ in pairs( attacker_.scene.players ) do
                    if  tmp_attack_target_( monster_ ) == 1 then
                        if  not attacker_.target then
                            attacker_:changeTarget( monster_ )  --设置为当前目标
                        end
                    end
                end
            end

        end


        --[[
        if  gg.out_distance( pos1_, pos2_, 260 ) then
            --gg.log( '====scene attack target out:' )   --未击中
            --return 0   --未击中
        else
            --gg.log( '====scene attack target ok:' )   --击中
            local damage_, eff_ = battleMgr.calculate_attack( attacker_, target_, skill_config )
            target_:showDamage( damage_, eff_ )
            if  damage_ > 0 then
                target_:been_hit( attacker_ )
            end
        end
        --]]

    end
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
    if  self.tick > 60 then       --最长时间 60帧=6秒
        self.stat = 99
        return self.stat
    end

    if      self.stat == 0 then
        --准备阶段
    elseif  self.stat == 1 then
        self:checkMissionAttack()   --飞行阶段，每一帧判断击中
    else
        --
    end


    return self.stat
end


return _M
