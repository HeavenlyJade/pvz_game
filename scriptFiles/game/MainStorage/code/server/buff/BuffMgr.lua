
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

local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal)            ---@type gg
local common_config = require(MainStorage.code.common.MConfig)            ---@type common_config


-- 将技能加载的存放在这里
---@class BufferMgr
local BufferMgr = {
    CONST_Buffer_module = {
        --[1001] = require(MainStorage.code.server.buff.BuffFactory.Buff1),
    }
}

-- 所有技能定义buffer的 lua-modules (通过 InitSkillConfig 初始化)

function BufferMgr.InitBuffConfig()
	for buff_id, v in pairs( common_config.buff_def ) do

		v.id   = buff_id   --补齐buffer id
		v.icon = common_config.buff_def[ buff_id ].icon
		v.name = common_config.buff_def[ buff_id ].name
		local buff_sn = common_config.buff_def[ buff_id ].buff_sn
		local name_ = MainStorage.code.server.buff.BuffFactory[ 'Buff' .. buff_sn ]
		BufferMgr.CONST_Buffer_module[ buff_id ] = require( name_ )
	end

end


function BufferMgr.BUfferCreate()
    
end

return BufferMgr