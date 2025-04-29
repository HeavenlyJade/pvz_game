--- V109 miniw-haima ---
-- 建立通用攻击类技能
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
local eqAttr            = require(MainStorage.code.server.equipment.MEqAttr)  ---@type EqAttr
local BuffBase          = require(MainStorage.code.server.buff.buffBase)  ---@type BuffBase
local skillUtils        = require(MainStorage.code.server.skill.MSkillUtils) ---@type SkillUtils

-- 
---@class Buff1 : BuffBase
local _M = CommonModule.Class("Buff1", BuffBase)

function _M:OnInit(info_)
    BuffBase.OnInit(self, info_)
end

-- 发动buffer
-- return 0=成功 大于0=失败
function _M:castSpell()
    if BuffBase.castSpell(self) > 0 then
        return 1
    end
    
    gg.thread_call(function()
        wait(0.5)
        self:Createbuff()
    end)
    
    return 0
end

-- 处理属性效果的辅助函数
local function processPropertyEffects(attacker, buff_config, multiplier)
    if buff_config.need_target ~= 0 then
        return
    end
    
    local buff_effect = buff_config.buff_effect
    if not buff_effect then
        return
    end
    
    -- 遍历所有效果
    for _, effect in ipairs(buff_effect) do
        -- 检查是否是属性修改效果
        if effect.type == "property" then
            local property_name = effect.name
            local value = effect.num * multiplier
            local value_type = effect.value_type or "absolute" -- 默认为绝对值
            -- print("数值编号",property_name, value, value_type)
            attacker:applyAttributeModifier(property_name, value, value_type)
        end
    end
    
    eqAttr.visitAllAttr(attacker)
    attacker:rsyncData(1)
end

-- 创建buff
function _M:Createbuff()
    processPropertyEffects(self.from, self.buff_config, 1)
end

-- 销毁buff
function _M:DestroyBuff()
    processPropertyEffects(self.from, self.buff_config, -1)
end

return _M