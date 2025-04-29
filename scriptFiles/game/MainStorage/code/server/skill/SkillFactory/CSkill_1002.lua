
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
local battleMgr         = require(MainStorage.code.server.BattleMgr)  ---@type BattleMgr

local CSkillBase        = require(MainStorage.code.server.skill.CSkillBase)  ---@type CSkillBase
local skillUtils        = require(MainStorage.code.server.skill.MSkillUtils) ---@type SkillUtils


-- 技能 投掷长矛
---@class CSkill_1002 : CSkillBase
local _M = CommonModule.Class( "CSkill_1002", CSkillBase )
function _M:OnInit( info_ )
    CSkillBase:OnInit( info_ )
    self.missileObj = nil   --投掷物 长矛
end


--攻击或者施法
--return  0=成功  大于0=失败
function _M:castSpell()
    if  CSkillBase:castSpell() > 0 then
        return 1
    end

    --更变武器
    if  self.from.model_weapon then
        self.from.model_weapon.ModelId = common_config.assets_dict.model.model_changmao
    end

    local function func_()
        wait(0.2)
        self:createMissileObject()     --发射长矛
    end
    gg.thread_call( func_ )

    return 0  --成功
end



-- 建立一个投掷物（长矛）
function _M:createMissileObject()

    local attacker_ = self.from            --攻击发起者


    --建立长矛
    local changmao    = gg.cloneFromTemplate('changmao')     --克隆（速度更快）
    changmao.Parent   = gg.serverGetContainerWeapon(self.scene_name)
    changmao.Name     = 'm_changmao'
    changmao.Visible  = true

    changmao.Anchored       = false
    changmao.EnableGravity  = false
    changmao.CanCollide     = false
    --changmao.CanTouch      = true
    --changmao.CollideGroupID = 1    --与地面碰撞

    changmao.OwnerUin = attacker_.uin
    changmao.LocalScale = Vector3.new( 4,    2,  4 )
    changmao.Size       = Vector3.new( 32, 128, 32 )
    changmao.Center     = Vector3.new( 0,   32,  0 )


    self.missileObj = changmao

    --初始位置
    local attack_pos_ = attacker_:getPosition()
    changmao.Position = Vector3.new(attack_pos_.x, attack_pos_.y + 150, attack_pos_.z)

    self.target = attacker_.target

    --方向
    local attack_euler_
    if  self.target then
        attack_euler_ = gg.getEulerByPositon( attacker_:getPosition(), self.target:getPosition() )
    else
        attack_euler_ = attacker_.actor.Euler   --攻击者朝向
    end
    changmao.Euler = Vector3.new( attack_euler_.x - 90 , attack_euler_.y, attack_euler_.z )    --长矛模型自身朝上，需要向x旋转90度
    wait(0.1)
    local v3_dir
    if  self.target then
        --有目标的情况下
        v3_dir = attacker_:getPosition() - self.target:getPosition()
        Vector3.Normalize( v3_dir )
    else
        v3_dir = gg.getDirVector3( attacker_.actor )    --朝向方向
    end
    changmao.Velocity = v3_dir * -2048  --反方向，速度
    self.stat = 1

end




--判断是否攻击到了目标
function _M:checkMissionAttack()
    if  self.missileObj then
        local attacker_ = self.from
        local target_   = self.target

        local pos1_ = self.missileObj.Position
        local pos2_ = target_:getPosition()
        --gg.log( 'skill_config', self.skill_config )
        if  gg.out_distance( pos1_, pos2_, 260 ) then
            --gg.log( '====scene attack target out:' )   --未击中
            return 0   --未击中
        else
            --gg.log( '====scene attack target ok:' )   --击中
            local damage_, eff_ = battleMgr.calculate_attack( attacker_, target_, self.skill_config )
            target_:showDamage( damage_, eff_ )
            if  damage_ > 0 then

                --角度稍微随机变化
                self.missileObj.Parent   = target_.actor
                self.missileObj.Velocity = Vector3.new(0,0,0)
                local euler = self.missileObj.Euler
                self.missileObj.Euler = Vector3.new( euler.x+gg.rand_int_both(10) , euler.y+gg.rand_int_both(10), euler.z+gg.rand_int_both(10) )

                target_:been_hit( attacker_ )
            end

            self.tick_wait = 10
            self.stat = 2        --击中阶段
        end
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
    if  self.tick > 60 then    --最长时间 60帧=6秒
        self.stat = 99
        return self.stat
    end

    if  self.tick_wait > 0 then
        self.tick_wait = self.tick_wait - 1
        return
    end

    if      self.stat == 0 then
        --准备阶段
    elseif  self.stat == 1 then
        self:checkMissionAttack()   --长矛发出阶段
    elseif  self.stat == 2 then
        self.stat = 99              --击中
    else
        --
    end



    return self.stat
end


return _M




    --[[
    --不再使用碰撞回调
    --长矛插在目标身上后，等一会消失
    local function distroy_changmao( time_ )
        changmao.Velocity = Vector3.new(0,0,0)

        --角度稍微随机变化
        local euler = changmao.Euler
        changmao.Euler = Vector3.new( euler.x+gg.rand_int_both(10) , euler.y+gg.rand_int_both(10), euler.z+gg.rand_int_both(10) )

        wait(time_)
        self:cleanMissileObj()
    end

    local function hit_target( target_, node_ )
        local damage_, eff_= battleMgr.calculate_attack( attacker_, target_, self.skill_config )
        target_:showDamage( damage_, eff_ )
        if  damage_ > 0 then
            target_:been_hit( attacker_ )
        end

        changmao.Parent = node_
        distroy_changmao(1)
    end


    local function touch_func(node, pos, normal)
        if  node.ClassType == 'Actor' then
            --击中了玩家或者怪物
            if  node.OwnerUin == attacker_.uin then
                --忽略击中自己
            else
                --击中
                gg.log( 'touch_func hit:', node.Name )
                if  attacker_:isPlayer() then
                    --玩家攻击
                    local target_ = gg.findMonsterByUuid( node.Name )
                    if  target_ then
                        hit_target( target_, node )
                        if  not attacker_.target then
                            attacker_:changeTarget( target_ )  --设置为当前目标
                        end
                    end

                else
                    --怪物攻击
                    local target_ = gg.getPlayerByUin( node.OwnerUin )
                    if  target_ then
                        hit_target( target_, node )
                    end

                end

            end
        else
            --击中其他物体
            distroy_changmao(1)
        end
    end
    changmao.Touched:connect( touch_func )
    --]]

