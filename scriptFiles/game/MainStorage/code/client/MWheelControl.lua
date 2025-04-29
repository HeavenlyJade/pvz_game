
--- V109 miniw-haima
--- 移动端摇杆操作

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


local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal)      ---@type gg



local WorldService = game:GetService("WorldService")
local UserInputService = game:GetService("UserInputService")


local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer



-- singleton
---@class MMobileWheelControl
local MMobileWheelControl = {
    touchMoveControl = nil,

    LeftRightValue = 0,
    ForwardBackValue = 0,
    moveId = -1,

    wheel_mouse_down = 0,    --左边方向轮
    touchBeginPos = nil,

    xx = 0,   --left right
    yy = 0,   --up down

    controller = nil,            ---@type Controller
}



MMobileWheelControl._CheckInitMovementControl = function()

    -- gg.log( '_CheckInitMovementControl' )

	if  MMobileWheelControl.touchMoveControl == nil then

        -- gg.log( 'new touchMoveControl' )

        local ui_root = gg.create_ui_root()

		local imgTouchBg = SandboxNode.new("UIImage")
        imgTouchBg.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE

		imgTouchBg.Parent = ui_root
		imgTouchBg.Name = "touchBg"
		imgTouchBg.Active = false
		imgTouchBg.ClickPass = true
		imgTouchBg.LayoutHRelation = Enum.LayoutHRelation.Left
		imgTouchBg.LayoutVRelation = Enum.LayoutVRelation.Bottom
		imgTouchBg.Size = Vector2.New(193, 193)
		imgTouchBg.Icon = "sandboxSysId://ministudio/ui/touch_operate_steering_wheel.png"

		local imgDot = SandboxNode.new("UIImage")
        imgDot.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
		imgDot.Parent = imgTouchBg
		imgDot.Name = "imgDot"
		imgDot.Size = Vector2.New(89, 90)
		imgDot.Active = false
		imgDot.ClickPass = true
		imgDot.Icon = "sandboxSysId://ministudio/ui/operating_dot.png"

        MMobileWheelControl.touchMoveControl = {
			imgTouchBg = imgTouchBg;
			imgDot = imgDot;
		}


        UserInputService.TouchStarted:Connect(function(inputObj, gameprocessed)
            MMobileWheelControl.controller.handleMouse( inputObj, 1 )   --touch
        end)

        UserInputService.TouchMoved:Connect(function(inputObj, gameprocessed)
            MMobileWheelControl.controller.handleMouse( inputObj, 2 )   --touch move
        end)

        UserInputService.TouchEnded:Connect(function(inputObj, gameprocessed)
            MMobileWheelControl.controller.handleMouse( inputObj, 0 )   --touch
        end)


        MMobileWheelControl.resetTouchPos()
	end

	if  MMobileWheelControl.touchMoveControl then
		MMobileWheelControl.touchMoveControl.imgTouchBg.Visible = false
	end
end




function MMobileWheelControl.resetTouchPos()
    local viewSize = gg.get_ui_size()
    MMobileWheelControl.touchMoveControl.imgTouchBg.Position = Vector2.New(200, viewSize.y - 173)
    MMobileWheelControl.touchMoveControl.imgDot.Position = Vector2.New(97, 95)
end


function MMobileWheelControl.getUIPos( inputObj )
    local worldpos = inputObj.Position
    local uiscale = WorldService:GetUIScale()

    return { x = worldpos.x*uiscale.x; y = worldpos.y *uiscale.y }
end


function MMobileWheelControl.isValidTouchPos( pos )
    if MMobileWheelControl.moveId ~= -1 then return false end
    if not MMobileWheelControl.touchMoveControl then return false end
    local viewSize = gg.get_ui_size()
    if pos.x < viewSize.x/2 then
        return true
    end

    return false
end



--鼠标操作 PC版本
function MMobileWheelControl.handleMouse( inputObj, flag )
    --gg.log( 'handleMouse:', flag, inputObj.Position.x, inputObj.Position.y )

    if     flag == 1 then

        if  MMobileWheelControl.checkScreenArea( inputObj.Position.x, inputObj.Position.y ) == 1 then

            local pos = MMobileWheelControl.getUIPos(inputObj)
        --if  MMobileWheelControl.isValidTouchPos(pos) then

            MMobileWheelControl.wheel_mouse_down = 1       --鼠标按下
            MMobileWheelControl.touchBeginPos = pos
            -- MMobileWheelControl.touchMoveControl.imgTouchBg.Position = Vector2.New(pos.x, pos.y)
        end


    elseif flag == 2 then
        --move
        if  MMobileWheelControl.wheel_mouse_down == 1 then
            if  MMobileWheelControl.checkScreenArea( inputObj.Position.x, inputObj.Position.y ) == 1 then
                local pos = MMobileWheelControl.getUIPos(inputObj)
                local dir = Vector2.New( pos.x - MMobileWheelControl.touchBeginPos.x, pos.y - MMobileWheelControl.touchBeginPos.y )

                local xx, yy = gg.NormalizeVec2( dir.x, dir.y )
                MMobileWheelControl.touchMoveControl.imgDot.Position = Vector2.New( 97 + xx*62 , 95 + yy*62 )

                if  gg.lockClientCharactor == false then
                    LocalPlayer.Character:Move(Vector3.New(dir.x, 0, -dir.y), true)
                end

                --MMobileWheelControl.LeftRightValue = dir.x
                --MMobileWheelControl.ForwardBackValue = -dir.y
            end
        end


    else   --flag == 0

        if  MMobileWheelControl.wheel_mouse_down == 1 then
            if  MMobileWheelControl.checkScreenArea( inputObj.Position.x, inputObj.Position.y ) == 1 then
                MMobileWheelControl.wheel_mouse_down = 0
                MMobileWheelControl.resetTouchPos()
                LocalPlayer.Character:Move(Vector3.New(0, 0, 0), true)
            end
        end

        --MMobileWheelControl.LeftRightValue = 0
        --MMobileWheelControl.ForwardBackValue = 0
    end

    return 1

end





--是否在屏幕的左下角，或者右下角
function MMobileWheelControl.checkScreenArea(x,y)
    local xx, yy = gg.get_camera_window_size()
    if (x < xx*0.25 and y > yy*0.33 ) or ( x < xx*0.35 and y > yy*0.5 )  then
        return 1      --左边
    end
    if  x > xx*0.5 and y > yy*0.65 then
        return 2      --右边
    end
    return 0
end




function MMobileWheelControl.ShowView( visible )
    MMobileWheelControl.touchMoveControl.imgTouchBg.Visible = visible
end



function MMobileWheelControl.init( controller_ )
    MMobileWheelControl.controller = controller_

    -- gg.log( '初始化移动端摇杆处理' )
    MMobileWheelControl._CheckInitMovementControl();
end



--LocalPlayer.NotifyAttributeChanged:Connect(function( propName ) 
	--if propName == "TouchMovementMode" then
		--MMobileWheelControl._CheckInitMovementControl();
	--end
--end)


return MMobileWheelControl