
--- V109 miniw-haima
--- 建立通用攻击类技能
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

local CSkillBase        = require(MainStorage.code.server.skill.CSkillBase)  ---@type CSkillBase
local skillUtils        = require(MainStorage.code.server.skill.MSkillUtils) ---@type SkillUtils


-- 技能 近身武器平砍

---@class CSkill_1000 : CSkillBase
local _M = CommonModule.Class( "CSkill_1000", CSkillBase )
function _M:OnInit( info_ )
    CSkillBase:OnInit( info_ )
end



-- 发动攻击
--return  0=成功  大于0=失败
function _M:castSpell()
    if  CSkillBase:castSpell() > 0 then
        return 1
    end
    --更变武器
    if  self.from.model_weapon then
        self.from.model_weapon.ModelId = common_config.assets_dict.model.model_sword
    end
    local function func_()
        wait(0.5)
        self:hitTarget()
        self.stat = 99      --技能结束，可以清理
    end
    gg.thread_call( func_ )

end


-- 
function _M:hitTarget()
    local attacker_ = self.from      -- 发起攻击的对象
    -- 若攻击者不满足施放条件（已死亡、异常状态等），直接返回
    if skillUtils.checkAlive(attacker_, self.skill_config) > 0 then
        return 1
    end

    -- 获取攻击者的角色对象和朝向向量
    local actor_ = attacker_.actor
    local dir_vec_ = gg.getDirVector3(actor_)

    -- 这里假设技能在角色面前 100 距离处生效，如果有数值策划要求，可配置化
    local pos_x = actor_.Position.x - dir_vec_.x * 100
    local pos_y = actor_.Position.y
    local pos_z = actor_.Position.z - dir_vec_.z * 100
    local attack_center_ = Vector3.new(pos_x, pos_y, pos_z)   -- 攻击中心点

    -- 定义一个子函数，用来尝试攻击某个目标
    local function try_attack_target(target_)
        -- 目标可能已经死亡或离线，也要判空
        if not target_ then
            return 0
        end
        
        -- 判断距离是否在攻击范围内
        local target_pos_ = target_:getPosition()
        if gg.out_distance(attack_center_, target_pos_, self.skill_config.range) then
            return 0   -- 未击中
        end
        
        local damage_, eff_ = battleMgr.calculate_attack(attacker_, target_, self.skill_config)
        target_:showDamage(damage_, eff_)
        
        if damage_ > 0 then
            -- 目标被有效击中，调用受击逻辑
            target_:been_hit(attacker_)
            return 1
        else
            return 0   -- 可能被闪避、格挡或目标已死亡等
        end
    end

    -- 先尝试攻击锁定目标
    if attacker_.target then
        -- 如果击中锁定目标，就直接返回（不继续对其它怪执行）
        if try_attack_target(attacker_.target) == 1 then
            return 0
        end
    else
        -- 如果没有锁定目标，则遍历场景中的所有怪物
        for _, monster_ in pairs(attacker_.scene.monsters) do
            try_attack_target(monster_)
            -- 如果此技能是“打到一个目标就结束”那种，可考虑在这里加 break：
            -- if try_attack_target(monster_) == 1 then
            --     break
            -- end
        end
    end

    -- 整个技能流程结束，返回 0 表示“已执行完毕”
    return 0
end


return _M

