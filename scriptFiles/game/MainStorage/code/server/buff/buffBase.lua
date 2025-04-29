
--- 这里是所以技能的父类,子类技能继承它，来实现相对应的技能效果
--- CSkill_Universal是子类技能通用选项

local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal)            ---@type gg
local common_config = require(MainStorage.code.common.MConfig)            ---@type common_config
local buffConfig      = require(MainStorage.code.common.MCSkillBuffConfig.MConfigBuff)      ---@type MConfigBuff



---@class BuffBase
---@field uuid string
local BuffClass = CommonModule.Class("BuffBase")     --父类 (子类：CSkill_1001 CSkill_1002 ... )
function BuffClass:OnInit( info_ )
    self.info = info_  -- 入参的info数据
    self.uuid = gg.create_uuid( 'buff' )    --uniq id

    self.stat      = 0                   -- 0, 1, 2, 3 .. (阶段)   99=等待清理
    self.tick      = 0
    self.tick_wait = 0

    self.from       = info_.from      --技能发起者
    self.scene_name = info_.from.scene_name  -- buff场景

    self.target   = info_.from.target           -- buff目标 可选）
    self.buff_id = info_.buff_id
    self.create_time = os.time()  -- 记录buff创建时间的时间戳

    self.buff_config = common_config.buff_def[info_.buff_id]
    self.duration_time =  self.buff_config.duration_time
end



-- buff施法是否成功
--return  0=成功  大于0=失败
function BuffClass:castSpell()

    local attacker_ = self.from    --攻击发起者
    local target = self.target
    -- if  BuffClass:checkAlive() > 0 then
    --     return 1
    -- end


    return 0
end

-- 检查buff释放对相关条件释放符合
function BuffClass:checkAlive( )
    if self.buff_config.need_target == 0 then
        -- 为自己施法
    end

end

-- buff特效
function BuffClass:showSpellEffect( attack_, high_, time_ )
end
--清理buff
function BuffClass:DestroyBuff()
end




--tick
function BuffClass:update()
    self.tick = self.tick + 1
    return self.stat
end

return BuffClass