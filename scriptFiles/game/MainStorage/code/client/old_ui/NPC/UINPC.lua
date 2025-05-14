local game = game
local script = script
local print = print
local math  = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs
local Vector2 = Vector2
local ColorQuad = ColorQuad
local Vector3 = Vector3
local MainStorage = game:GetService("MainStorage")
local gg                 = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config      = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const       = require(MainStorage.code.common.MConst)    ---@type common_const

local UiYesNo            = require(MainStorage.code.client.ui.UiYesNo)    ---@type UiYesNo



---@class UiNpc
local  UiNpc = {
    npc_model = nil,
    txt_num  = nil,
    txt_info = nil,
    update_timer = nil,
};

function UiNpc.show()
    
end

function UiNpc.init_npc(args_)
    local npc_model = gg.cloneFromTemplate('Actor_test')
    local ncp_position = args_["position"]
    local scene_name_ = args_["scene_name_"]
    npc_model.Parent  =game.WorkSpace.Ground[ scene_name_ ]
    npc_model.Visible = true
    npc_model.Position = Vector3.New( ncp_position[1], ncp_position[2], ncp_position[3] )
    UiNpc.npc_model =npc_model
    
end

