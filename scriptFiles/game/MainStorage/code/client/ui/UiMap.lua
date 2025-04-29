--- 玩家小地图

local game         = game
local script       = script
local print        = print
local math         = math
local SandboxNode  = SandboxNode
local Enum         = Enum
local pairs        = pairs
local Vector2      = Vector2
local Vector3      = Vector3
local ColorQuad    = ColorQuad
local MainStorage  = game:GetService("MainStorage")
local inputservice = game:GetService("UserInputService")
local Players      = game:GetService('Players')
local gg           = require(MainStorage.code.common.MGlobal) ---@type gg



---@class UiMap
local UiMap        = {
    bg = nil,
    world_map = nil,
    mask_map = nil,
    map = nil ,
    user_logo =nil ,
    world_scale = 0.1, -- 世界坐标到地图坐标的比例，需要根据实际情况调整

}

function UiMap.show()
    if UiMap.map == nil then
        UiMap.init_map()
    end
    UiMap.updateMinimap()
    UiMap.world_map.Visible = true
    UiMap.bg.Visible = false
end

function UiMap.close()
    UiMap.world_map.Visible = false
    UiMap.bg.Visible = true
end

-- 建立地图
function UiMap.init_map()
    local ui_root_spell = gg.get_ui_root_spell()

    UiMap.bg = ui_root_spell.ui_map
    UiMap.bg.Visible =true
    UiMap.mask_map = ui_root_spell.ui_map.MaskUIImage
    UiMap.map      =  ui_root_spell.ui_map.map
    UiMap.user_logo = ui_root_spell.ui_map.user_logo
    UiMap.world_map = ui_root_spell.world_map
end



function UiMap.updateMinimap()
    if not UiMap.mask_map then
        UiMap.init_map()
    end
    
    local player = gg.getClientLocalPlayer()
    local playerPos = player.Position
    local client_scene_name = gg.client_scene_name
    
    -- 获取地形信息
    local terrain = game.WorkSpace.Ground[client_scene_name].terrain
    local terrainSize = terrain.Size
    local terrainPos = terrain.Position
    local terrainScale = terrain.LocalScale
    
    -- 计算实际地图的大小和边界
    local mapWidth = terrainSize.x * terrainScale.x
    local mapHeight = terrainSize.z * terrainScale.z
    local mapCenterX = terrainPos.x
    local mapCenterZ = terrainPos.z
    
    -- 获取用户图标在UI中的固定位置
    local userLogoPosition = UiMap.user_logo.Position
    
    -- 计算地图比例 (实际地图尺寸与小地图控件尺寸的比例)
    local miniMapSize = UiMap.map.Size
    local scaleX = miniMapSize.x / mapWidth
    local scaleZ = miniMapSize.y / mapHeight
    
    -- 计算玩家位置在小地图上的坐标
    local playerMapX = (playerPos.x - mapCenterX) * scaleX
    local playerMapZ = (playerPos.z - mapCenterZ) * scaleZ
    
    -- 计算地图位置（使玩家在地图上的位置与用户图标位置一致）
    local mapPositionX = userLogoPosition.x - playerMapX
    local mapPositionZ = userLogoPosition.y - playerMapZ
    
    -- 设置地图位置
    UiMap.map.Position = Vector2.New(mapPositionX, mapPositionZ)
    
    -- 获取玩家朝向并更新小地图图标旋转
    local dirVector = gg.getDirVector3(player)
    local yaw = math.atan2(dirVector.z, dirVector.x)
    local rotationDegrees = math.deg(yaw)
    UiMap.user_logo.Rotation = rotationDegrees

end


return UiMap

