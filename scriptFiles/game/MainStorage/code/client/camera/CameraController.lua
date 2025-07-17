local MainStorage = game:GetService('MainStorage')
local Players = game:GetService('Players')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Vec2 = require(MainStorage.code.common.math.Vec2)
local Vec3 = require(MainStorage.code.common.math.Vec3)
local Vec4 = require(MainStorage.code.common.math.Vec4)
local Quat = require(MainStorage.code.common.math.Quat)
local Mat4x4 = require(MainStorage.code.common.math.Matrix4x4)
local Mat3x4 = require(MainStorage.code.common.math.Matrix3x4)
local MathDefines = require(MainStorage.code.common.math.MathDefines)
local ShakeController = require(MainStorage.code.client.camera.ShakeController) ---@type ShakeController
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class CameraController
local CameraController = {}

--摄像机模式
CameraController.CameraMode = {
    --第一人称摄像机
    FirstPerson = 0,
    --第三人称摄像机
    ThirdPerson = 1,
    --自由模式
    Free = 2
}

-- 静态变量
local _inputEnabled = true
local _projection = nil
local _camera = nil ---@type Camera
local _owner = nil ---@type MiniPlayer
local _cameraMode = CameraController.CameraMode.ThirdPerson
local _offset = Vec3.new(100, 140, -50)
local _pivotPositionSmoothSpeed = 8
local _lockMouseX = false
local _lockMouseY = false
local _invertMouseX = false
local _invertMouseY = false
local _mouseXSensitivity = 0.2
local _mouseYSensitivity = 0.1
local _wheelSensitivity = 50
local _mouseXMin = -60.0
local _mouseXMax = 60.0
local _mouseYMin = -90.0
local _mouseYMax = 90.0
local _mouseSmoothTime = 0.005
local _minDistance = 50
local _maxDistance = 2000
local _distanceSmoothTime = 0.1
local _alignWhenMoving = false
local _alignmentSmoothTime = 0.05
local _minAlignDistance = 5

local _mouseX = 10
local _mouseY = 0
local _distance = 200

local _rawMouseX = _mouseX  -- 记录未经抖动修改的原始mouseX
local _rawMouseY = _mouseY  -- 记录未经抖动修改的原始mouseY

local _mouseXSmooth = _mouseX
local _mouseYSmooth = _mouseY
local _mouseSmoothTime = 0.01
local _distanceSmooth = _distance
local _pivotPositionSmooth = Vec3.new(0, 0, 0)
local _mouseXCurrentVelocity = 0
local _mouseYCurrentVelocity = 0
local _distanceCurrentVelocity = 0
local _lockedOnTarget = false

local _currentCameraPos = Vec3.new(0, 0, 0)
local _currentCameraRot = Quat.new(1, 0, 0, 0)

local _touchBeginPos = Vec2.new(0, 0)
local _lastTouchPos = Vec2.new(0, 0)
local _currentTouchPos = Vec2.new(0, 0)
local _rotation = Quat.new(1, 0, 0, 0)
local _lastTouchTimeEnd = 0
local _touchStartTime = 0  -- Add touch start time variable

local _viewDirty = true
local _projectionDirty = true

local _isTouching = false
local _touchId = nil
local _touchMoving = false
local _canSightTouch = false
local _blockMouseMove = false

local _TouchStartedEvent = nil
local _TouchEndedEvent = nil
local _TouchMovedEvent = nil
local _InputBeganEvent = nil
local _InputEndedEvent = nil
local _InputChangedEvent = nil

local _cameraLocked = false -- 新增：摄像机锁定标志

local _lastExtremeInputTime = 0 -- 极限输入冷却
local EXTREME_INPUT_THRESHOLD = 20
local EXTREME_INPUT_COOLDOWN = 1.0

local _extremeInputBlockUntil = 0 -- 极限输入保护期
local _pendingExtremeInputBlockDuration = nil -- 新增：待激活保护时长

local _lastDeltaX = 0
local _lastDeltaY = 0

ClientEventManager.Subscribe("UpdateCameraView", function(data)
    if data.x then
        CameraController.RotateTo(data.x, data.y)
    end
end)
-- 在 CameraController.lua 中，替换 SetActive 函数中的鼠标处理部分：
local touchCameraId = nil

function CameraController.RotateTo(x, y)
    _rawMouseY = x
    _rawMouseX = y + 180
end
function CameraController.SetActive(active)
    local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
    _owner = Players.LocalPlayer
    if active then
        CameraController.SetCamera(game.WorkSpace.CurrentCamera)
        _pivotPositionSmooth = CameraController.CalcPivotPosition(_mouseY)

        if game.UserInputService.TouchEnabled then -- 触摸设备
            _TouchStartedEvent =
                game.UserInputService.TouchStarted:Connect(
                function(inputObj, gameprocessed)
                    if inputObj.Position.x > ViewBase.GetScreenSize().x / 2 then
                        touchCameraId = inputObj.TouchId
                        _isTouching = true
                        CameraController.OnTouchStarted(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                    end
                end
            )

            _TouchMovedEvent =
                game.UserInputService.TouchMoved:Connect(
                function(inputObj, gameprocessed)
                    if _isTouching and inputObj.TouchId == touchCameraId then
                        CameraController.OnTouchMoved(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                    end
                end
            )

            _TouchEndedEvent =
                game.UserInputService.TouchEnded:Connect(
                function(inputObj, gameprocessed)
                    if inputObj.TouchId == touchCameraId then
                        _isTouching = false
                        CameraController.OnTouchEnded(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                    end
                end
            )
        elseif game.UserInputService.MouseEnabled then -- 鼠标设备
            _InputBeganEvent =
                game.UserInputService.InputBegan:Connect(
                function(inputObj, gameprocessed)
                    -- 只有鼠标右键才开始摄像头控制
                    if inputObj.UserInputType == Enum.UserInputType.MouseButton2.Value then
                        _isTouching = true
                        CameraController.OnTouchStarted(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                    end
                end
            )

            _InputChangedEvent =
                game.UserInputService.InputChanged:Connect(
                function(inputObj, gameprocessed)
                    if inputObj.UserInputType == Enum.UserInputType.MouseMovement.Value then
                        if _isTouching or game.MouseService:IsSight() then
                            local currentTime = gg.GetTimeStamp()  -- Use gg.GetTimeStamp() instead of game.TimeService:GetTime()
                            local elapsedTime = currentTime - _touchStartTime
                            if _inputEnabled and elapsedTime >= 0.1 then  -- Only allow movement after 0.1 seconds
                                local deltaY = inputObj.Delta.y
                                if game.RunService:IsPC() then
                                    if not game.MouseService:IsSight() then
                                        deltaY = -deltaY
                                    end
                                end
                                if _alignWhenMoving and _lockedOnTarget then
                                    CameraController.InputMove(0, deltaY)
                                else
                                    CameraController.InputMove(inputObj.Delta.x, deltaY)
                                end
                            end
                        end
                    end
                end
            )

            _InputEndedEvent =
                game.UserInputService.InputEnded:Connect(
                function(inputObj, gameprocessed)
                    -- 只有鼠标右键抬起才停止摄像头控制
                    if inputObj.UserInputType == Enum.UserInputType.MouseButton2.Value then
                        _isTouching = false
                        CameraController.OnTouchEnded(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                    end
                end
            )
        end

        -- 绑定渲染更新事件
        game.RunService.RenderStepped:Connect(
            function(dt)
                CameraController.LaterUpdateClient(dt)
            end
        )
    else
        _camera.CameraType = Enum.CameraType.Custom
        -- 断开所有事件连接的代码保持不变...
        if _TouchStartedEvent then
            _TouchStartedEvent:Disconnect()
            _TouchStartedEvent = nil
        end
        if _TouchEndedEvent then
            _TouchEndedEvent:Disconnect()
            _TouchEndedEvent = nil
        end
        if _TouchMovedEvent then
            _TouchMovedEvent:Disconnect()
            _TouchMovedEvent = nil
        end
        if _InputBeganEvent then
            _InputBeganEvent:Disconnect()
            _InputBeganEvent = nil
        end
        if _InputEndedEvent then
            _InputEndedEvent:Disconnect()
            _InputEndedEvent = nil
        end
        if _InputChangedEvent then
            _InputChangedEvent:Disconnect()
            _InputChangedEvent = nil
        end
    end
end
--设置摄像机
function CameraController.SetCamera(camera)
    _camera = camera
    _camera.CameraType = Enum.CameraType.Scriptable
end

--更新客户端
function CameraController.LaterUpdateClient(dt)
    if not _camera then
        print("CameraController:LaterUpdateClient no camera")
        return
    end

    if _cameraLocked then
        -- 摄像机锁定时不自动更新位置和旋转
        return
    end

    CameraController.ShakeUpdate(dt)

    if _cameraMode == CameraController.CameraMode.ThirdPerson then
        CameraController.ThirdPersonUpdate(dt)
    end

    _viewDirty = true
    _projectionDirty = true
end

--设置摄像机模式
function CameraController.SetCameraMode(mode)
    _cameraMode = mode
end

--设置摄像机跟随的目标偏移
function CameraController.SetOffset(offset)
    _offset = offset
end

--获取当前Yaw
function CameraController.GetYaw()
    return _rawMouseX
end

--获取当前Pitch
function CameraController.GetPitch()
    return _rawMouseY
end

function CameraController.SetMouseSmoothTime(smoothTime)
    -- if not CameraController.IsShaking() then
    --     _mouseSmoothTime = smoothTime
    -- end
end

--设置锁定目标
function CameraController.SetLockedOnTarget(locked)
    _lockedOnTarget = locked
end

--设置移动时对齐摄像机
function CameraController.SetAlignWhenMoving(aligh)
    _alignWhenMoving = aligh
end

local function fixMouseXJump()
    local diff = _mouseX - _mouseXSmooth
    if math.abs(diff) > 180 then
        if _mouseX > _mouseXSmooth then
            _mouseXSmooth = _mouseXSmooth + 360
        else
            _mouseXSmooth = _mouseXSmooth - 360
        end
    end
end

--第三人称摄像机更新
function CameraController.ThirdPersonUpdate(dt)
    -- 设置鼠标平滑时间为默认值
    CameraController.SetMouseSmoothTime(_mouseSmoothTime)
    fixMouseXJump()

    -- 使用SmoothDamp平滑处理鼠标X轴和Y轴的旋转
    _mouseXSmooth, _mouseXCurrentVelocity =
        gg.math.SmoothDamp(_mouseXSmooth, _mouseX, _mouseXCurrentVelocity, _mouseSmoothTime, 0, dt)
    _mouseYSmooth, _mouseYCurrentVelocity =
        gg.math.SmoothDamp(_mouseYSmooth, _mouseY, _mouseYCurrentVelocity, _mouseSmoothTime, 0, dt)
    -- 计算摄像机旋转
    _currentCameraRot = CameraController.CalcCameraRotation(_mouseXSmooth, _mouseYSmooth)

    -- 计算并平滑处理摄像机枢轴位置 （现在用真实的偏航值）
    local pivotPosition = CameraController.CalcPivotPosition(_mouseXSmooth)
    _pivotPositionSmooth = _pivotPositionSmooth:Lerp(pivotPosition, _pivotPositionSmoothSpeed * dt)

    -- 检测并处理摄像机与障碍物的碰撞
    local isHit, closestDistance = CameraController.GetClosestDistance(_pivotPositionSmooth, _currentCameraRot)
    if not isHit then
        -- 如果没有碰撞，平滑处理摄像机距离
        _distanceSmooth, _distanceCurrentVelocity =
            gg.math.SmoothDamp(
            _distanceSmooth,
            closestDistance,
            _distanceCurrentVelocity,
            _distanceSmoothTime,
            0,
            dt
        )
    end

    -- 计算最终的摄像机位置
    _currentCameraPos =
        CameraController.CalcCameraPosition(
        _pivotPositionSmooth,
        _mouseXSmooth,
        _mouseYSmooth,
        _distanceSmooth,
        dt
    )

    -- 更新摄像机的位置和旋转
    _camera.Position = Vector3.New(_currentCameraPos.x, _currentCameraPos.y, _currentCameraPos.z)
    _camera.Rotation =
        Quaternion.New(
        _currentCameraRot.x,
        _currentCameraRot.y,
        _currentCameraRot.z,
        _currentCameraRot.w
    )

    -- 保存当前旋转状态
    _rotation = orient
end

function CameraController.RaytraceScene(filterGroup)
    local winSize = _camera.WindowSize
    local ray_   =  _camera:ViewportPointToRay( winSize.x/2, winSize.y/2, 12800 )
    local result = game.WorldService:RaycastClosest(ray_.Origin, ray_.Direction, 12800, true, filterGroup)
    if result.isHit then
        return ray_.Origin + ray_.Direction * result.distance, result.obj
    end
    return nil, nil
end

--获取摄像机朝向，未抖动
function CameraController.GetForward()
    local winSize = _camera.WindowSize
    local ray_   =  _camera:ViewportPointToRay( winSize.x/2, winSize.y/2, 12800 )
    return ray_.Direction
end

-- function CameraController.GetRealForward(horizontalRecoil, verticalRecoil)
--     return gg.vec.ToDirection(Vector3.New(_mouseX + horizontalRecoil, _mouseY + verticalRecoil, 0))
-- end

--获取摄像机观察点位置
function CameraController.CalcPivotPosition(axisDegrees)
    local orient = Quat.new()
    orient:FromEuler(Vec3.new(0, axisDegrees, 0))
    local characterPosition = _owner.Position
    local positionVector3 = Vec3.new(characterPosition)
    local pivotPosition = positionVector3 + orient * _offset
    return pivotPosition
end

function CameraController.CalcCameraPosition(pivotPosition, xAxisDegrees, yAxisDegrees, distance, dt)
    local shakePosDelta = ShakeController.GetPosDelta()
    local orient = CameraController.CalcCameraRotation(xAxisDegrees, yAxisDegrees)
    local cameraPos = pivotPosition + orient:GetBackward() * distance + orient * shakePosDelta
    return cameraPos
end

 --获取摄像机旋转（第一个参数是 yaw, 第二个是 pitch）
 function CameraController.CalcCameraRotation(yawDegrees, pitchDegrees)
     local orient = Quat.new()
     -- FromEuler(Vec3(pitch, yaw, 0))
     orient:FromEuler(Vec3.new(pitchDegrees, yawDegrees, 0))
     return orient
 end

--获取摄像机距离
function CameraController.GetClosestDistance(pos, orient)
    local dir = orient:GetBackward()
    local result =
        game.WorldService:SweepSphere(
        50,
        Vector3.New(pos.x, pos.y, pos.z),
        Vector3.New(dir.x, dir.y, dir.z),
        _distance,
        true,
        {2}
    )
    if result.isHit then
        return true, result.distance
    end
    return false, _distance
end

--水平对齐
function CameraController.AlignWithAngle(yAngle, inverted)
    local shakeRotDelta = ShakeController.GetRotDelta()
    local targetRotation = Quat.new()
    targetRotation:FromEuler(Vec3.new(0, (inverted and (yAngle - 180.0) or yAngle), 0))
    local inverseRotation = Quat.new()
    inverseRotation:FromEuler(Vec3.new(0, _mouseY - shakeRotDelta.y, 0))
    inverseRotation:Inverse()
    local delta = targetRotation * inverseRotation
    local deltaEuler = delta:ToEuler().y
    local deltaEuler = delta:ToEuler().y
    if gg.math.IsAlmostEqual(deltaEuler, 0, 0.5) then
        return
    end
    if deltaEuler > 180 then
        deltaEuler = deltaEuler - 360
    end
    _mouseY = _mouseY + deltaEuler
end

--获取位置
function CameraController.GetPosition()
    local pos = _camera.Position
    return Vec3.new(pos.x, pos.y, pos.z)
end

--获取旋转
function CameraController.GetRotation()
    if _camera then
        local rot = _camera.Rotation ---@type Quaternion
        return Quat.new(rot.w, rot.x, rot.y, rot.z)
    end
    return Quat.identity()
end

--获取朝向旋转
function CameraController.GetFaceCameraRotation(pos, rotation, faceMode, minAnge)
    local cameraPos = CameraController.GetPosition()
    local cameraRot = CameraController.GetRotation()
    if faceMode == 0 then
        return cameraRot
    end
    local lookRotation = Quat.new()
    lookRotation:GetFaceCameraRotation(cameraPos, cameraRot, pos, rotation, faceMode, minAnge)
    return lookRotation
end

--世界坐标映射到屏幕坐标
function CameraController.WorldToScreen(worldPos)
    if _camera then
        local screenPos = _camera:WorldToUIPoint(Vector3.New(worldPos.x, worldPos.y, worldPos.z))
        return Vec2.new(screenPos.x, screenPos.y)
    end
    return Vec2.zero()
end

--获取视口高度一半
function CameraController.GetHalfViewSize()
    if _camera then
        local fov = _camera.FieldOfView
        local viewportSize = CameraController.GetViewportSize()
        return math.tan(fov * MathDefines.M_DEGTORAD * 0.5)
    end
    return 0
end

--计算固定屏幕缩放系数
function CameraController.CalculateFixedScaleFactor(pos)
    if _camera then
        local viewportSize = CameraController.GetViewportSize()
        local invViewHeight = 1.0 / viewportSize.y
        local halfViewSize = CameraController.GetHalfViewSize()

        local view = CameraController.GetView()
        local projection = CameraController.GetProjection()

        local viewProj = projection * view
        local projPos = viewProj * Vec4.new(pos.x, pos.y, pos.z, 1.0)
        local newScaleFactor = invViewHeight * halfViewSize * projPos.w
        return newScaleFactor
    end
    return 1
end

--获取世界矩阵
function CameraController.GetEffectiveWorldTransform()
    local position = CameraController.GetPosition()
    local rotation = CameraController.GetRotation()
    local mat3x4 = Mat3x4.new()
    mat3x4:FromTransforms(position, rotation, 1.0)
    return mat3x4
end

--获取视图矩阵
function CameraController.GetView()
    if _viewDirty then
        _view = CameraController.GetEffectiveWorldTransform():Inverse()
        _viewDirty = false
    end
    return _view
end


--获取投影矩阵
function CameraController.GetProjection()
    if _projectionDirty then
        if _projection == nil then
            _projection = Mat4x4.new()
        end
        _projection:SetData(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        local fov = _camera.FieldOfView
        local far = _camera.ZFar
        local near = _camera.ZNear
        local viewportSize = CameraController.GetViewportSize()
        local aspectRatio = viewportSize.x / viewportSize.y

        local h = (1.0 / math.tan(fov * MathDefines.M_DEGTORAD * 0.5))
        local w = h / aspectRatio
        local q = far / (far - near)
        local r = -q * near

        _projection.m00 = w
        _projection.m02 = 2.0
        _projection.m11 = h
        _projection.m12 = 2.0
        _projection.m22 = q
        _projection.m23 = r
        _projection.m32 = 1.0
        _projectionDirty = false
    end
    return _projection
end

--获取视口大小
function CameraController.GetViewportSize()
    local viewportSize = _camera.WindowSize
    return Vec2.new(viewportSize.x, viewportSize.y)
end

--------------------------------------输入控制-----------------------------------------
--设置输入启用
function CameraController.SetInputEnabled(enabled)
    _inputEnabled = enabled
end

function CameraController.InputMove(deltaX, deltaY)
    local now = gg.GetTimeStamp()
    -- 若有待激活保护，首次输入时激活保护期
    if _pendingExtremeInputBlockDuration then
        _extremeInputBlockUntil = now + _pendingExtremeInputBlockDuration
        _pendingExtremeInputBlockDuration = nil
    end
    if now < _extremeInputBlockUntil then
        if math.abs(deltaX) > EXTREME_INPUT_THRESHOLD or math.abs(deltaY) > EXTREME_INPUT_THRESHOLD then
            return
        end
    end

    local yawInput   = deltaX
    local pitchInput = deltaY

    -- X 轴反转应该影响水平旋转，Y 轴反转应该影响垂直旋转
    if _invertMouseX then
        yawInput = -yawInput
    end
    if _invertMouseY then
        pitchInput = -pitchInput
    end

    -- 锁定时阻止对应轴的输入
    if _lockMouseX then
        yawInput = 0
    end
    if _lockMouseY then
        pitchInput = 0
    end

    -- 更新 raw 值
    _rawMouseX = _rawMouseX + yawInput   * _mouseXSensitivity
    _rawMouseY = _rawMouseY + pitchInput * _mouseYSensitivity
    -- 偏航限制Y轴
    _rawMouseY = math.clamp(_rawMouseY, _mouseYMin, _mouseYMax)
end

--鼠标滚轮
function CameraController.InputWheel(delta)
    _distance = math.clamp(_distance + delta * _wheelSensitivity, _minDistance, _maxDistance)
end

function CameraController.OnTouchStarted(x, y, touchId)
    _touchId = touchId
    _touchBeginPos.x = x
    _touchBeginPos.y = y
    _lastTouchPos.x = x
    _lastTouchPos.y = y
    _currentTouchPos.x = x
    _currentTouchPos.y = y
    _canSightTouch = false
    _touchStartTime = gg.GetTimeStamp()  -- Use gg.GetTimeStamp() instead of game.TimeService:GetTime()
end

function CameraController.EnableSightTouch()
    if game.MouseService:IsSight() then
        _canSightTouch = true
    end
end

function CameraController.SetCameraAt(pos, rot)
    local Vec3 = require(MainStorage.code.common.math.Vec3)
    local Quat = require(MainStorage.code.common.math.Quat)
    local targetPos = Vec3.new(pos)
    local targetRot = Quat.new()
    targetRot:FromEuler(Vec3.new(rot))
    if _camera then
        _camera.Position = Vector3.New(targetPos.x, targetPos.y, targetPos.z)
        _camera.Rotation = Quaternion.New(targetRot.x, targetRot.y, targetRot.z, targetRot.w)
    end
    _viewDirty = true
    _projectionDirty = true
    _cameraLocked = true -- 新增：锁定摄像机
end

function CameraController.UnlockCamera()
    _cameraLocked = false
    -- 触发一次自动更新，恢复摄像机到当前跟随/第三人称等逻辑
    if _cameraMode == CameraController.CameraMode.ThirdPerson then
        CameraController.ThirdPersonUpdate(0)
    end
    _viewDirty = true
    _projectionDirty = true
end

function CameraController.OnTouchMoved(x, y, touchId)
    _currentTouchPos.x = x
    _currentTouchPos.y = y

    if _lastTouchPos.x ~= 0 and _lastTouchPos.y ~= 0 then
        local delta = _currentTouchPos - _lastTouchPos
        if _alignWhenMoving and _lockedOnTarget then
            CameraController.InputMove(0, delta.y)
        else
            CameraController.InputMove(delta.x, delta.y)
        end
    end

    _lastTouchPos.x = x
    _lastTouchPos.y = y
end

function CameraController.OnTouchEnded(x, y, touchId)
    if _touchId ~= touchId then
        return
    end
    _touchMoving = false
end

function CameraController.OnWheel(delta)
    if _inputEnabled then
        CameraController.InputWheel(delta)
    end
end

--震动更新
function CameraController.ShakeUpdate(dt)
    local shakeRotData = ShakeController.GetRotDelta()
    _mouseX = _rawMouseX + shakeRotData.x
    _mouseY = _rawMouseY + shakeRotData.y
end

--是否在震动
function CameraController.IsShaking()
    return ShakeController.IsShaking()
end

function CameraController.BlockExtremeInputFor(duration)
    _pendingExtremeInputBlockDuration = duration
end

CameraController.SetActive(true)
return CameraController
