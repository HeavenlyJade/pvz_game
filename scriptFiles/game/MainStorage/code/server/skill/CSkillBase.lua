
--- 这里是所以技能的父类,子类技能继承它，来实现相对应的技能效果
--- CSkill_Universal是子类技能通用选项

local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal)            ---@type gg
local common_config = require(MainStorage.code.common.MConfig)            ---@type common_config
local skillUtils    = require(MainStorage.code.server.skill.MSkillUtils)  ---@type SkillUtils



---@class CSkillBase
---@field uuid string
local _M = CommonModule.Class("CSkillBase")     --父类 (子类：CSkill_1001 CSkill_1002 ... )

---@class SkillInfo
---@field from CLiving 技能施放者(玩家,怪物或NPC实体)
---@field skill_id number 技能ID
---@param info SkillInfo 技能初始化信息
function _M:OnInit( info_ )
    self.info = info_  -- 入参的info数据4
    
    self.uuid = gg.create_uuid( 'sk' )    --uniq id
    
    self.stat      = 0                   -- 0, 1, 2, 3 .. (阶段)   99=等待清理
    self.tick      = 0
    self.tick_wait = 0

    ---@type CLiving
    self.from       = info_.from  --技能发起者

    if info_.from then
        self.scene_name = info_.from.scene_name

    end

    self.target   = nil             --被攻击者（可选）
    self.skill_id = info_.skill_id

    self.skill_config = common_config.skill_def[info_.skill_id]
end



--攻击或者施法
--return  0=成功  大于0=失败
function _M:castSpell()

    local attacker_ = self.from    --攻击发起者
    if  skillUtils.checkAlive( attacker_, self.skill_config ) > 0 then
        return 1
    end

    attacker_:setAttackSpellByConfig( self.skill_id, self.skill_config )   --计算攻速cd间隔 扣除法力
    attacker_:play_animation( '100105', 1.5, 1 )     --attack

    return 0
end


--清理技能
function _M:DestroySkill()
end


--tick
function _M:update()
    self.tick = self.tick + 1
    return self.stat
end


return _M