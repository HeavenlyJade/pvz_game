
--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local wait         = wait
local game         = game
local pairs        = pairs


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config

local skillUtils        = require(MainStorage.code.server.skill.MSkillUtils) ---@type SkillUtils
local CSkillBase        = require(MainStorage.code.server.skill.CSkillBase)  ---@type CSkillBase


-- 技能 闪现术
---@class CSkill_2003 : CSkillBase
local _M = CommonModule.Class( "CSkill_2003", CSkillBase )
function _M:OnInit( info_ )
    CSkillBase:OnInit( info_ )
end




--攻击或者施法
--return  0=成功  大于0=失败
function _M:castSpell()

    if  CSkillBase:castSpell() > 0 then
        return 1
    end

    local attacker_ = self.from            --攻击发起者

    if  skillUtils.checkAlive( attacker_, self.skill_config ) > 0 then
        return 1
    end


    local pos_ = attacker_:getPosition()
    local dir_ = gg.getDirVector3( attacker_.actor )

    local range_ = self.skill_config.range
    local xx=pos_.x - dir_.x*range_
    local yy=pos_.y
    local zz=pos_.z - dir_.z*range_

    attacker_.actor.Position = Vector3.new( xx, yy, zz )
    wait(0.1)
    attacker_.actor.Position = Vector3.new( xx, yy, zz )
    gg.network_channel:fireClient( attacker_.uin, { cmd='cmd_player_pos', x=xx, y=yy, z=zz, r=1 } )   --reason=1


    local function eff_()
        local expl = SandboxNode.new('DefaultEffect', game.WorkSpace )
        expl.AssetID = common_config.assets_dict.effect.tp_effect
        expl.LocalPosition = Vector3.new( pos_.x, pos_.y+32, pos_.z )
        expl.LocalScale = Vector3.new( 1.5, 1.5, 1.5 )
        wait(1.3)
        expl:Destroy()
    end
    gg.thread_call( eff_ )


    local function eff2_()
        local expl = SandboxNode.new('DefaultEffect', attacker_.actor )
        expl.AssetID = common_config.assets_dict.effect.tp_effect
        expl.LocalPosition = Vector3.new( 0, 32, 0 )
        expl.LocalScale = Vector3.new( 1.5, 1.5, 1.5 )
        wait(1.3)
        expl:Destroy()
    end
    gg.thread_call( eff2_ )


    self.stat = 99
end


return _M
