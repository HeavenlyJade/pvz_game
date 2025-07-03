
--- V109 miniw-haima
--- 客户端输入控制模块

local game = game
local script = script
local print = print
local math  = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs

local Vector2 = Vector2
local Vector3 = Vector3
local ColorQuad = ColorQuad

local MainStorage = game:GetService("MainStorage")

local gg            = require(MainStorage.code.common.MGlobal)           ---@type gg
-- local UiCommon      = require(MainStorage.code.client.ui.UiCommon)       ---@type UiCommon
-- local wheelControl  = require( MainStorage.code.client.MWheelControl )   ---@type MMobileWheelControl

local WorldService  = game:GetService( 'WorldService' )
local inputservice = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")



--处理玩家输入（键盘，鼠标等）
---@class Controller
---@field m_enableMove boolean
local  Controller = {
    last_pick_actor = nil,

    m_enableMove = true,

    last_press_pos  = { x=0, y=0, t=0 },       --最后点击的屏幕坐标
};



function Controller.init()
    -- local UiSettingBut = require(MainStorage.code.client.UiClient.SysUi.SettingBut) ---@type UiSettingBut
    -- local NpcClient = require(MainStorage.code.client.UiClient.Npc) ---@type NpcClient
    gg.log("Controller初始化")
    local ui_size_x = gg.get_ui_size().x
    Controller.press_xy_limit = ui_size_x * 0.01   --屏幕长度的1/100(用来判断是否是点击动作)

    Controller.initKeyboard()
    gg.get_camera_window_size()


end




function Controller.initKeyboard()

    -- 按空格键触发上面的测试函数
    local function inputBegan( inputObj, passed )
        if  inputObj.UserInputType == Enum.UserInputType.Keyboard.Value then
            Controller.handleKeyboard( inputObj.KeyCode, 1 )
        elseif inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
            Controller.handleMouse( inputObj, 1 )   --keyboard
        end
    end
    inputservice.InputBegan:Connect( inputBegan )



    local function onInputChanged( inputObj, passed )
        if inputObj.UserInputType == Enum.UserInputType.MouseMovement.Value then      --鼠标移动
            Controller.handleMouse( inputObj, 2 )   --keyboard
        end
    end
    inputservice.InputChanged:Connect( onInputChanged )



    --抬起
    local function onInputEnded( inputObj, passed )
        if  inputObj.UserInputType == Enum.UserInputType.Keyboard.Value then
            Controller.handleKeyboard( inputObj.KeyCode, 0 )
        elseif inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
            Controller.handleMouse( inputObj, 0 )   --keyboard
        end
    end
    inputservice.InputEnded:Connect( onInputEnded )


end



--窗口大小变化
function Controller.handleWinSizeChange( inputObj )
    local winSize = gg.getClientWorkSpace().CurrentCamera.WindowSize
    local ui_size = game:GetService( 'WorldService' ):GetUISize()
    gg.log( 'handleWinSizeChange==', winSize, ui_size )
end



local const_allow_keyboard = {
    --[ Enum.KeyCode.W.Value ] = {},
    --[ Enum.KeyCode.S.Value ] = {},
    --[ Enum.KeyCode.A.Value ] = {},
    --[ Enum.KeyCode.D.Value ] = {},

    --[ Enum.KeyCode.Q.Value ] = {},
    --[ Enum.KeyCode.E.Value ] = {},
    --[ Enum.KeyCode.Space.Value ] = {},

    [ Enum.KeyCode.T.Value ] = {},           --haima test debug  /anim  /skin
    [ Enum.KeyCode.Z.Value ] = {},           --test pick
}



--键盘输入 keyCode:按键值,  flag：1=按下 2=变化  0=抬起 (debug使用)
function Controller.handleKeyboard( keyCode, flag )
    if  const_allow_keyboard[ keyCode ] then
        if  flag == 0 then         --按键抬起
            if  keyCode == Enum.KeyCode.T.Value then
                -- UiCommon.openTextInput( true )

            elseif  keyCode == Enum.KeyCode.Z.Value then
                --测试拾取物品
                local pick_ = gg.clientPickObjectMiddle()
                if  pick_ and pick_.ClassType == 'Actor' then
                    if  Controller.last_pick_actor then
                        Controller.last_pick_actor.CubeBorderEnable = false
                    end
                    Controller.last_pick_actor = pick_
                    Controller.last_pick_actor.CubeBorderEnable = true
                end

            else

            end
        end
        --gg.network_channel:FireServer( { cmd='cmd_key', v=keyCode, flag=flag } )  --通知给服务器
    end
end





--鼠标输入
function Controller.handleMouse( inputObj, flag )

    if  Controller.m_enableMove ~= true then
        return
    end

    --检测按钮在屏幕的左下角摇杆区域， 右下角按钮区域
    -- if  wheelControl.handleMouse( inputObj, flag ) == 0 then
    --     return 0   --不再透传
    -- end


    --快速点击，判断为点选和切换目标（左键和屏幕点击）
    if  flag == 1 then
        if  gg.client_aoe_cylinder then
            --有aoe选择控件
            Controller.tryAoeRayGround( inputObj.Position.x, inputObj.Position.y )
        else
            Controller.last_press_pos.x = inputObj.Position.x
            Controller.last_press_pos.y = inputObj.Position.y
            Controller.last_press_pos.t = RunService:CurrentMilliSecondTimeStamp()
        end

    elseif  flag == 0 then
        --抬起
        if  gg.client_aoe_cylinder then
            --有aoe选择控件
            Controller.AoeRayRelease()

        else

            local len_delta_  = math.abs( inputObj.Position.x - Controller.last_press_pos.x ) + math.abs( inputObj.Position.y - Controller.last_press_pos.y )
            if  len_delta_ < Controller.press_xy_limit then
                --在相同的位置
                local time_delta_ = RunService:CurrentMilliSecondTimeStamp() - Controller.last_press_pos.t
                if  time_delta_ < 200 then  --0.2秒
                    --（ 快速点击屏幕同一个地方 ）
                    -- gg.log( 'press pick obj:', len_delta_, time_delta_, inputObj.Position.x, inputObj.Position.y  )   --是一个快速点击动作
                    Controller.tryPickObject( inputObj.Position.x, inputObj.Position.y )
                end
            end
        end


    elseif  flag == 2 then
        --滑动

        if  gg.client_aoe_cylinder then
            --有aoe选择控件
            Controller.tryAoeRayGround( inputObj.Position.x, inputObj.Position.y )
        end

    else


    end

end



--点选一个当前目标
function Controller.tryPickObject( x, y )

    local obj_list = {}     --查找范围
    local  monster_container = gg.clentGetContainerMonster()
    if not monster_container then
        return
    end
    for k, v in pairs( monster_container.Children ) do
        obj_list[ #obj_list+1] = v     --只找怪物
    end


    --当前点击位置
    local pick_node_

    --扩散协助选择
    for xx = 1, 10 do
        for yy = 1, 5 do
            pick_node_ = inputservice:PickObjects( x+xx*5, y+yy*5, obj_list )
            if  pick_node_ then break end

            pick_node_ = inputservice:PickObjects( x-xx*5, y-yy*5, obj_list )
            if  pick_node_ then break end
        end
        if  pick_node_ then break end
    end


    if  pick_node_ then
        --改动框的显示，明确是否被选中
        if  pick_node_.ClassType == 'Actor' then
            gg.log( 'tryPickObject:', pick_node_, pick_node_.Name )
            gg.network_channel:FireServer( { cmd='cmd_pick_actor', v=pick_node_.Name } )   --1=选中其他actor
        end
    end

end




--选择AOE技能
function Controller.handleAoePos( args_ )

    gg.log( 'handleAoePos', args_ )


    if  not gg.client_aoe_cylinder then
        --{ cmd='cmd_aoe_pos', range=skill_config.range, size=skill_config.size, uuid=sk1234 } )

        local aoe_box_   = gg.cloneFromTemplate('aoe_position')
        aoe_box_.Parent  = gg.getClientWorkSpace()
        aoe_box_.Name    = args_.uuid
        aoe_box_.Visible = true

        aoe_box_.EnablePhysics = false
        aoe_box_.CanCollide    = false
        aoe_box_.CanTouch      = false
        aoe_box_.CastShadow    = false
        aoe_box_.ReceiveShadow = false

        --aoe_box_.Top.BaseMaterial   = Enum.MaterialTemplate.LambertBlend
       --aoe_box_.Top.RimColor         = ColorQuad.New( 255, 255, 255, 128 )

        gg.client_aoe_cylinder = aoe_box_

       -- gg.lockCamera( true )
    end

    --gg.client_aoe_cylinder.Parent = gg.getClientWorkSpace()


    local size_ = args_.size * 0.01
    gg.client_aoe_cylinder.LocalScale = Vector3.New( size_, 0.01, size_ )

    local pos_ = gg.getClientLocalPlayer().Position
    gg.client_aoe_cylinder.LocalPosition = Vector3.New( pos_.x, pos_.y+1, pos_.z )
    gg.client_aoe_range = args_.range

end



--开启碰撞检测
function Controller.EnableOverlap(enable)
    if not WorldService.SetSceneId then
        gg.log("Actor:EnableOverlap error SetSceneId is nil")
        return
    end
    if  enable then
        local workspaceId = gg.getClientWorkSpace().SceneId
        WorldService:SetSceneId(workspaceId)
    else
        WorldService:SetSceneId(0)
    end
end



--尝试选择技能触地位置
function Controller.tryAoeRayGround( x, y )

    local winSize = gg.getClientWorkSpace().CurrentCamera.WindowSize
    --gg.log( 'tryAoeRayGround:', x, y, winSize.x, winSize.y )

    local ray_   = gg.getClientWorkSpace().Camera:ViewportPointToRay( x, winSize.y-y, 12800 )
    WorldService = game:GetService( 'WorldService' )

    --Controller.EnableOverlap(true)

    -- gg.log( 'ViewportPointToRay3:', ray_.Origin, ray_.Direction, gg.getClientWorkSpace().Camera.Position )

    --local ret_table = WorldService:RaycastAll( ray_.Origin, ray_.Direction, 12800, true, {2} )
    local ret_table = WorldService:RaycastClosest( ray_.Origin, ray_.Direction, 12800, true, {2} )
    --ret_table = 1={normal={-0.000000, 1.000000, -0.000971} distance=2428.7092285156 position={650.002686, -0.343750, 2228.231445} obj=[node(754493)(Model):base]}
        --2={normal={0.000000, 1.000000, 0.000000} distance=1996.7115478516 position={620.065369, 100.000000, 1809.116821} obj=[node(793564)(GeoSolid):Cube]}

    if  ret_table then
        -- gg.log ( 'RaycastClosest=', gg.getClientWorkSpace().Camera, ret_table, ret_table.position )

        -- 多点碰撞 RaycastAll
        --local pos1_
        --local nearst_dis_ = 12800
        --for i=1, #ret_table do
            --if  ret_table[i].distance < nearst_dis_ then
                --nearst_dis_ = ret_table[i].distance
                --pos1_ = ret_table[i].position
            --end
        --end

        -- 单点碰撞 RaycastClosest
        local pos1_ = ret_table.position

        if  pos1_ then
            local pos2_ = gg.getClientLocalPlayer().Position

            --距离是否太远
            if  gg.out_distance( pos1_, pos2_, gg.client_aoe_range ) then
                --距离太远
                --gg.client_aoe_cylinder.Color    = ColorQuad.New( 255, 0, 0, 128 )
                --计算点
                local dir_ = pos1_ - pos2_
                Vector3.Normalize( dir_ )
                local range_ = gg.client_aoe_range
                local pos3_ = Vector3.New( pos2_.x+dir_.x*range_, pos2_.y+dir_.y*range_+2, pos2_.z+dir_.z*range_ )
                gg.client_aoe_cylinder.Position = pos3_

            else
                --gg.client_aoe_cylinder.Color    = ColorQuad.New( 255, 255, 255, 128 )
                gg.client_aoe_cylinder.Position = Vector3.New( pos1_.x, pos1_.y+1, pos1_.z )
            end
        end

    end

end



--aoe技能选择地点ok
function Controller.AoeRayRelease()
    local pos_ = gg.client_aoe_cylinder.Position
    gg.network_channel:FireServer( { cmd='cmd_aoe_select_pos', uuid=gg.client_aoe_cylinder.Name, x=pos_.x, y=pos_.y, z=pos_.z } )

    gg.client_aoe_cylinder:Destroy()
    gg.client_aoe_cylinder = nil

    -- gg.lockCamera( false )
end



return Controller
