
--- V109 miniw-haima

local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local SandboxNode = SandboxNode
local Vector2  = Vector2
local Vector3  = Vector3
local ColorQuad = ColorQuad
local Enum = Enum
local wait = wait
local math = math
local os   = os
local require = require

local MainStorage = game:GetService("MainStorage")
local gg              = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config   = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const    = require(MainStorage.code.common.MConst)    ---@type common_const


-- 攻击和技能公共库
---@class SkillUtils
local SkillUtils = {}



--检查攻击者和目标是否都存活
function SkillUtils.checkAlive( attacker_, skill_config_ )

    --是否攻击者无法攻击
    if  attacker_:canNotBeenAttarked() then
        return 1        --攻击者死亡
    end

    --技能是否需要有目标
    if  skill_config_.need_target == 1 then
        --是否有目标
        if  attacker_.target then
            if  attacker_.target:canNotBeenAttarked() then

                if  attacker_:isPlayer() then
                    attacker_:showTips( '无效的目标' )
                else
                    attacker_.target = nil     --怪物失去目标
                end
                return 1  --目标死亡
            end
        else
            attacker_:showTips( '没有当前目标' )
            return 1   --没有目标
        end
    end

    return 0   --成功
end



--释法特效
function SkillUtils:showSpellEffect( attack_, high_, time_ )
    --local pos_ = attack_:getPosition()
    --local v3_dir = gg.getDirVector3( actor_ )    --朝向方向

    local function thread_wrap()
        local expl = SandboxNode.new('DefaultEffect', attack_.actor )
        expl.AssetID = common_config.assets_dict.effect.spell_effect
        --expl.Position = Vector3.new( pos_.x, pos_.y + high_ , pos_.z )
        expl.LocalPosition = Vector3.new( 0, high_, -64 )
        --expl.LocalScale = Vector3.new( 3, 3, 3 )
        wait( time_ )
        expl:Destroy()
    end
    gg.thread_call( thread_wrap )
end



return SkillUtils
