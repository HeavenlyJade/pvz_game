
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



-- 技能 治愈术
---@class CSkill_2004 : CSkillBase
local _M = CommonModule.Class( "CSkill_2004", CSkillBase )
function _M:OnInit( info_ )
    CSkillBase:OnInit( info_ )
end


--施法前摇
function _M:castTimePre()
    local attacker_ = self.from            --攻击发起者
    --施法动作
    skillUtils:showSpellEffect( attacker_, 128, self.skill_config.cast_time*0.1 )            --特效
    attacker_:play_animation( '100112', 1.0, 0 )       --spell
end



--攻击或者施法
--return  0=成功  大于0=失败
function _M:castSpell()
    --if  CSkillBase:castSpell() > 0 then
        --return 1
    --end

    local attacker_ = self.from            --攻击发起者
    attacker_:setAttackSpellByConfig( self.skill_id, self.skill_config )   --计算攻速cd间隔

    if  skillUtils.checkAlive( attacker_, self.skill_config ) > 0 then
        return 1
    end

    attacker_:spellHealth( 50, 0 )
    attacker_:play_animation( '100100', 1.5, 1 )   --idle 人物动作

    local function eff_()
        local expl = SandboxNode.new('DefaultEffect', attacker_.actor )
        expl.AssetID = common_config.assets_dict.effect.heal_effect
        expl.LocalPosition = Vector3.new( 0, 32, 0 )
        expl.LocalScale = Vector3.new( 1.5, 1.5, 1.5 )
        wait(1.1)
        expl:Destroy()
    end
    gg.thread_call( eff_ )

    self.stat = 99
end


return _M

