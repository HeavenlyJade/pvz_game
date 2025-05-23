local Math = MS.Math
local Vec2 = MS.Math.Vec2
local Vec3 = MS.Math.Vec3
local Vec4 = MS.Math.Vec4
local Quat = MS.Math.Quat
local Mat4 = MS.Math.Mat4x4
local Mat3x4 = MS.Math.Mat3x4
local MathDefines = MS.Math.MathDefines

local ShakeController = require(script.Parent.ShakeController)

local CameraController = MS.Class.new("CameraController", MS.ActorComponent)

--摄像机模式
CameraController.CameraMode = {
    --第一人称摄像机
    FirstPerson = 0,
    --第三人称摄像机
    ThirdPerson = 1,
    --自由模式
    Free = 2
}

--初始化
function CameraController:ctor()
    -- self.updateEnabled = true
    self.laterUpdateEnabled = true
    self.inputEnabled = true
    self.shakeCtrl = ShakeController.new()

    self.postProcessing = MS.PostProcessing.new()
end
function CameraController:dtor()
    if self.TouchStartedEvent then
        self.TouchStartedEvent:Disconnect()
        self.TouchStartedEvent = nil
    end
    if self.TouchEndedEvent then
        self.TouchEndedEvent:Disconnect()
        self.TouchEndedEvent = nil
    end
    if self.TouchMovedEvent then
        self.TouchMovedEvent:Disconnect()
        self.TouchMovedEvent = nil
    end

    if self.InputBeganEvent then
        self.InputBeganEvent:Disconnect()
        self.InputBeganEvent = nil
    end
    if self.InputEndedEvent then
        self.InputEndedEvent:Disconnect()
        self.InputEndedEvent = nil
    end

    if self.InputChangedEvent then
        self.InputChangedEvent:Disconnect()
        self.InputChangedEvent = nil
    end
end

--震动屏幕
function CameraController:StartShake(name)
    self.shakeCtrl:Start(name)
end
--开始持续震动
function CameraController:StartShakeLoop(name)
    self.shakeCtrl:StartLoop(name)
end
--停止持续震动
function CameraController:StopShakeLoop(name)
    self.shakeCtrl:StopLoop(name)
end
--淡出震动
function CameraController:StopShakeFade(name)
    self.shakeCtrl:StopFade(name)
end

--停止震动
function CameraController:StopShake(name)
    self.shakeCtrl:Stop(name)
end

--停止全部
function CameraController:StopAllShake()
    self.shakeCtrl:StopAll()
end

function CameraController:ShakeUpdate(dt)
    local shakeRotData = self.shakeCtrl:GetRotDelta()
    self._mouseX = self._mouseX - shakeRotData.x
    self._mouseY = self._mouseY - shakeRotData.y

    self.shakeCtrl:Update(dt)

    if self.shakeCtrl:IsShaking() then
        shakeRotData = self.shakeCtrl:GetRotDelta()
        self._mouseX = self._mouseX + shakeRotData.x
        self._mouseY = self._mouseY + shakeRotData.y
    end
end
--是否正在震动
function CameraController:IsShaking()
    return self.shakeCtrl:IsShaking()
end
--初始化
function CameraController:Init()
    --摄像机模式
    self.cameraMode = self.CameraMode.ThirdPerson
    --摄像机跟随的目标偏移
    self.offset = Vec3.new(-140, 140, -30)
    self.pivotPositionSmoothSpeed = 4
    --锁定
    self.lockMouseX = false
    self.lockMouseY = false
    --反向
    self.invertMouseX = false
    self.invertMouseY = false
    --灵敏度
    self.mouseXSensitivity = 0.2
    self.mouseYSensitivity = 0.2
    self.wheelSensitivity = 50
    --范围限制
    self.mouseXMin = -20.0
    self.mouseXMax = 40.0
    self.mouseYMin = -90.0
    self.mouseYMax = 90.0
    --平滑时间
    self.mouseSmoothTime = 0.01
    --距离限制
    self.minDistance = 50
    self.maxDistance = 2000
    --距离平滑时间
    self.distanceSmoothTime = 0.2
    --移动对齐
    self.alignWhenMoving = false
    --对齐平滑时间
    self.alignmentSmoothTime = 0.05
    --最小对齐距离
    self.minAlignDistance = 5

    self._mouseX = 10
    self._mouseY = 180
    self._distance = 200

    self._mouseXSmooth = self._mouseX
    self._mouseYSmooth = self._mouseY
    self._mouseSmoothTime = 0.01
    self._distanceSmooth = self._distance
    self._pivotPositionSmooth = Vec3.new(0, 0, 0)
    --速率记录
    self._mouseXCurrentVelocity = 0
    self._mouseYCurrentVelocity = 0
    self._distanceCurrentVelocity = 0
    --开启锁定目标模式
    self.lockedOnTarget = false

    self.currentCameraPos = Vec3.new(0, 0, 0)
    self.currentCameraRot = Quat.new(1, 0, 0, 0)

    --触摸开始的位置
    self.touchBeginPos = Vec2.new(0, 0)
    --上一个位置
    self.lastTouchPos = Vec2.new(0, 0)
    --当前位置
    self.currentTouchPos = Vec2.new(0, 0)
    --当前的摄像机旋转
    self._rotation = Quat.new(1, 0, 0, 0)
    --记录最后点击的时间
    self.lastTouchTimeEnd = 0

    self.viewDirty = true
    self.projectionDirty = true
end
--拷贝
function CameraController:CopyFrom(other)
    self._mouseX = other._mouseX
    self._mouseY = other._mouseY
    self._distance = other._distance
    self._pivotPositionSmooth = other._pivotPositionSmooth
    self._mouseXSmooth = other._mouseXSmooth
    self._mouseXCurrentVelocity = other._mouseXCurrentVelocity
    self._mouseYSmooth = other._mouseYSmooth
    self._mouseYCurrentVelocity = other._mouseYCurrentVelocity
    self._distanceSmooth = other._distanceSmooth
    self._distanceCurrentVelocity = other._distanceCurrentVelocity
end
--启动客户端
function CameraController:StartClient()
    self:SetCamera(MS.WorkSpace.CurrentCamera)
    self._pivotPositionSmooth = self:CalcPivotPosition(self._mouseY)

    self:EnableSightTouch()

    if MS.UserInputService.TouchEnabled then -- 触摸
        self.TouchStartedEvent =
            MS.UserInputService.TouchStarted:Connect(
            function(inputObj, gameprocessed)
                self.isTouching = true
                self:OnTouchStarted(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
            end
        )

        self.TouchMovedEvent =
            MS.UserInputService.TouchMoved:Connect(
            function(inputObj, gameprocessed)
                if self.isTouching then
                    self:OnTouchMoved(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                end
            end
        )

        self.TouchEndedEvent =
            MS.UserInputService.TouchEnded:Connect(
            function(inputObj, gameprocessed)
                self.isTouching = false
                self:OnTouchEnded(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
            end
        )
    elseif MS.UserInputService.MouseEnabled then -- 鼠标
        self.InputBeganEvent =
            MS.UserInputService.InputBegan:Connect(
            function(inputObj, gameprocessed)
                if
                    inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value or
                        inputObj.UserInputType == Enum.UserInputType.MouseButton2.Value or
                        inputObj.UserInputType == Enum.UserInputType.MouseButton3.Value
                 then
                    self.isTouching = true
                    self:OnTouchStarted(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                end
            end
        )
        self.InputChangedEvent =
            MS.UserInputService.InputChanged:Connect(
            function(inputObj, gameprocessed)
                -- if inputObj.UserInputType == Enum.UserInputType.MouseWheel.Value then
                --     self:OnWheel(inputObj.Delta.y)
                -- end

                if inputObj.UserInputType == Enum.UserInputType.MouseMovement.Value then
                    local IsSight = MS.MouseService:IsSight()
                    if IsSight then
                        -- if self.canSightTouch and (self.touchId == nil) then
                        --     self.touchId = inputObj.TouchId
                        --     self.canSightTouch = false
                        -- end
                        -- self.canSightTouch = false
                        self:OnTouchMoved(
                            self.currentTouchPos.x + inputObj.Delta.x,
                            self.currentTouchPos.y + inputObj.Delta.y,
                            inputObj.TouchId
                        )
                    elseif self.isTouching then
                    -- self:OnTouchMoved(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                    end
                end
            end
        )
        self.InputEndedEvent =
            MS.UserInputService.InputEnded:Connect(
            function(inputObj, gameprocessed)
                if
                    inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value or
                        inputObj.UserInputType == Enum.UserInputType.MouseButton2.Value or
                        inputObj.UserInputType == Enum.UserInputType.MouseButton3.Value
                 then
                    self.isTouching = false
                    self:OnTouchEnded(inputObj.Position.x, inputObj.Position.y, inputObj.TouchId)
                end
            end
        )
    end
    -- Bind to the camera's render stepped event
    MS.RunService.RenderStepped:Connect(
        function(dt)
            self:LaterUpdateClient(dt)
        end
    )
end
--应用游戏设置
function CameraController:ApplyClientGameSettings(settings)
    local config = settings.CameraController
    self._distance = config.distance
    self.minDistance = config.minDistance
    self.maxDistance = config.maxDistance
    self.pivotPositionSmoothSpeed = config.positionSmoothSpeed
    self.mouseSmoothTime = config.rotateSmoothTime
end

--设置摄像机
function CameraController:SetCamera(camera)
    self.camera = camera
    self.camera.CameraType = Enum.CameraType.Scriptable
end

--更新客户端
function CameraController:LaterUpdateClient(dt)
    if not self.camera then
        print("CameraController:LaterUpdateClient no camera")
        return
    end

    self:ShakeUpdate(dt)

    if self.cameraMode == CameraController.CameraMode.ThirdPerson then
        self:ThirdPersonUpdate(dt)
    end

    self.viewDirty = true
    self.projectionDirty = true
end
--设置摄像机模式
function CameraController:SetCameraMode(mode)
    self.cameraMode = mode
end

--设置摄像机跟随的目标偏移
function CameraController:SetOffset(offset)
    self.offset = offset
end

--获取当前Yaw
function CameraController:GetYaw()
    return self._mouseXSmooth
end

--获取当前Pitch
function CameraController:GetPitch()
    return self._mouseYSmooth
end

function CameraController:SetMouseSmoothTime(smoothTime)
    if not self.shakeCtrl:IsShaking() then
        self._mouseSmoothTime = smoothTime
    end
end

--设置锁定目标
function CameraController:SetLockedOnTarget(locked)
    self.lockedOnTarget = locked
end
--设置移动时对齐摄像机
function CameraController:SetAlignWhenMoving(aligh)
    self.alignWhenMoving = aligh
end

--第三人称摄像机更新
function CameraController:ThirdPersonUpdate(dt)
    -- 设置鼠标平滑时间为默认值
    self:SetMouseSmoothTime(self.mouseSmoothTime)

    -- -- 处理摄像机对齐逻辑
    -- if self.alignWhenMoving and (not self.touchMoving or self.alignWhenMoving and self.lockedOnTarget) then -- 索敌状态对齐
    --     local invertAlignment = true
    --     local target = self.owner:GetTarget()
    --     if self.lockedOnTarget and target then
    --         -- 锁定目标时的对齐逻辑
    --         local selfPos = self.owner.AvatarComponent:GetPosition()
    --         local targetPos = target.AvatarComponent:GetPosition()
    --         -- 计算朝向目标的方向向量
    --         local dir = selfPos - targetPos
    --         if dir:Magnitude() > self.minAlignDistance then
    --             dir:Normalize()
    --             local lookRotation = Quat.new()
    --             -- 根据方向向量创建旋转四元数
    --             lookRotation:FromLookRotation(dir, Vec3.new(0, 1, 0))
    --             -- 应用对齐角度
    --             self:AlignWithAngle(lookRotation:ToEuler().y, invertAlignment)
    --         end
    --     else
    --         -- 未锁定目标时，使用角色当前的欧拉角Y轴旋转进行对齐
    --         local eulerAngleY = self.owner.AvatarComponent:GetRotation():ToEuler().y
    --         self:AlignWithAngle(eulerAngleY, invertAlignment)
    --     end

    --     -- 设置对齐时的平滑时间
    --     self:SetMouseSmoothTime(self.alignmentSmoothTime)
    -- end

    -- 使用SmoothDamp平滑处理鼠标X轴和Y轴的旋转
    self._mouseXSmooth, self._mouseXCurrentVelocity =
        Math:SmoothDamp(self._mouseXSmooth, self._mouseX, self._mouseXCurrentVelocity, self._mouseSmoothTime, 0, dt)
    self._mouseYSmooth, self._mouseYCurrentVelocity =
        Math:SmoothDamp(self._mouseYSmooth, self._mouseY, self._mouseYCurrentVelocity, self._mouseSmoothTime, 0, dt)
    -- 计算摄像机旋转
    self.currentCameraRot = self:CalcCameraRotation(self._mouseXSmooth, self._mouseYSmooth)

    -- 计算并平滑处理摄像机枢轴位置
    local pivotPosition = self:CalcPivotPosition(self._mouseYSmooth)
    self._pivotPositionSmooth = self._pivotPositionSmooth:Lerp(pivotPosition, self.pivotPositionSmoothSpeed * dt)

    -- 检测并处理摄像机与障碍物的碰撞
    local isHit, closestDistance = self:GetClosestDistance(self._pivotPositionSmooth, self.currentCameraRot)
    if not isHit then
        -- 如果没有碰撞，平滑处理摄像机距离
        self._distanceSmooth, self._distanceCurrentVelocity =
            Math:SmoothDamp(
            self._distanceSmooth,
            closestDistance,
            self._distanceCurrentVelocity,
            self.distanceSmoothTime,
            0,
            dt
        )
    else
        -- -- 如果发生碰撞，直接设置距离并重置速度
        -- self._distanceSmooth = closestDistance
        -- self._distanceCurrentVelocity = 0
    end

    -- 计算最终的摄像机位置
    self.currentCameraPos =
        self:CalcCameraPosition(
        self._pivotPositionSmooth,
        self._mouseXSmooth,
        self._mouseYSmooth,
        self._distanceSmooth,
        dt
    )

    -- 更新摄像机的位置和旋转
    self.camera.Position = Vector3.New(self.currentCameraPos.x, self.currentCameraPos.y, self.currentCameraPos.z)
    self.camera.Rotation =
        Quaternion.New(
        self.currentCameraRot.x,
        self.currentCameraRot.y,
        self.currentCameraRot.z,
        self.currentCameraRot.w
    )

    -- 保存当前旋转状态
    self._rotation = orient
end

--获取摄像机观察点位置
function CameraController:CalcPivotPosition(axisDegrees)
    local orient = Quat.new()
    orient:FromEuler(Vec3.new(0, axisDegrees, 0))
    --local pivotPosition = self.owner.AvatarComponent:GetPosition() + orient * self.offset
    local characterPosition = self.owner.bindActor.Position
    local positionVector3 = Vec3.new(characterPosition.X, characterPosition.Y, characterPosition.Z)
    local pivotPosition = positionVector3 + orient * self.offset
    return pivotPosition
end
--获取摄像机位置
function CameraController:CalcCameraPosition(pivotPosition, xAxisDegrees, yAxisDegrees, distance, dt)
    local shakePosDelta = self.shakeCtrl:GetPosDelta()
    local orient = self:CalcCameraRotation(xAxisDegrees, yAxisDegrees)
    local cameraPos = pivotPosition + orient:GetBackward() * distance + orient * shakePosDelta
    return cameraPos
end
--获取摄像机旋转
function CameraController:CalcCameraRotation(xAxisDegrees, yAxisDegrees)
    local orient = Quat.new()
    orient:FromEuler(Vec3.new(xAxisDegrees, yAxisDegrees, 0))
    return orient
end
--获取摄像机距离
function CameraController:GetClosestDistance(pos, orient)
    local dir = orient:GetBackward()
    local result =
        MS.WorldService:SweepSphere(
        50,
        Vector3.New(pos.x, pos.y, pos.z),
        Vector3.New(dir.x, dir.y, dir.z),
        self._distance,
        true,
        {2}
    )
    if result.isHit then
        return true, result.distance
    end
    return false, self._distance
end
--销毁
function CameraController:Destroy()
    self.target = nil
end

--水平对齐
function CameraController:AlignWithAngle(yAngle, inverted)
    local shakeRotDelta = self.shakeCtrl:GetRotDelta()
    local targetRotation = Quat.new()
    targetRotation:FromEuler(Vec3.new(0, (inverted and (yAngle - 180.0) or yAngle), 0))
    local inverseRotation = Quat.new()
    inverseRotation:FromEuler(Vec3.new(0, self._mouseY - shakeRotDelta.y, 0))
    inverseRotation:Inverse()
    local delta = targetRotation * inverseRotation
    local deltaEuler = delta:ToEuler().y
    local deltaEuler = delta:ToEuler().y
    if Math:IsAlmostEqual(deltaEuler, 0, 0.5) then
        return
    end
    if deltaEuler > 180 then
        deltaEuler = deltaEuler - 360
    end
    self._mouseY = self._mouseY + deltaEuler
end
--获取位置
function CameraController:GetPosition()
    local pos = self.camera.Position
    return Vec3.new(pos.x, pos.y, pos.z)
end
--获取旋转
function CameraController:GetRotation()
    if self.camera then
        local rot = self.camera.Rotation
        return Quat.new(rot.w, rot.x, rot.y, rot.z)
    end
    return Quat.identity()
end
--获取朝向旋转
function CameraController:GetFaceCameraRotation(pos, rotation, faceMode, minAnge)
    local cameraPos = self:GetPosition()
    local cameraRot = self:GetRotation()
    if faceMode == 0 then
        return cameraRot
    end
    local lookRotation = Quat.new()
    lookRotation:GetFaceCameraRotation(cameraPos, cameraRot, pos, rotation, faceMode, minAnge)
    return lookRotation
end
--世界坐标映射到屏幕坐标
function CameraController:WorldToScreen(worldPos)
    if self.camera then
        local screenPos = self.camera:WorldToUIPoint(Vector3.New(worldPos.x, worldPos.y, worldPos.z))
        return Vec2.new(screenPos.x, screenPos.y)
    end
    return Vec2.zero()
    -- if not self.camera then
    --     return Vec2.zero()
    -- end
    -- local view = self:GetView()
    -- local projection = self:GetProjection()
    -- local viewportSize = self:GetViewportSize()

    -- local eyeSpacePos = view * worldPos
    -- local ret = Vec2.new()

    -- if eyeSpacePos.z > 0.0 then
    --     local screenSpacePos = projection * eyeSpacePos
    --     ret.x = screenSpacePos.x
    --     ret.y = screenSpacePos.y
    -- else
    --     ret.x = (-eyeSpacePos.x > 0.0) and -1.0 or 1.0
    --     ret.y = (-eyeSpacePos.y > 0.0) and -1.0 or 1.0
    -- end

    -- ret.x = (ret.x / 2.0) + 0.5
    -- ret.y = 1.0 - ((ret.y / 2.0) + 0.5)

    -- ret.x = ret.x * viewportSize.x
    -- ret.y = ret.y * viewportSize.y

    -- return ret
end
--获取视口高度一半
function CameraController:GetHalfViewSize()
    if self.camera then
        local fov = self:GetFov()
        local viewportSize = self:GetViewportSize()
        return math.tan(fov * MathDefines.M_DEGTORAD * 0.5)
    end
    return 0
end
--计算固定屏幕缩放系数
function CameraController:CalculateFixedScaleFactor(pos)
    if self.camera then
        local viewportSize = self:GetViewportSize()
        local invViewHeight = 1.0 / viewportSize.y
        local halfViewSize = self:GetHalfViewSize()

        local view = self:GetView()
        local projection = self:GetProjection()

        local viewProj = projection * view
        local projPos = viewProj * Vec4.new(pos.x, pos.y, pos.z, 1.0)
        local newScaleFactor = invViewHeight * halfViewSize * projPos.w
        return newScaleFactor
    end
    return 1
end
--获取世界矩阵
function CameraController:GetEffectiveWorldTransform()
    local position = self:GetPosition()
    local rotation = self:GetRotation()
    local mat3x4 = Mat3x4.new()
    mat3x4:FromTransforms(position, rotation, 1.0)
    return mat3x4
end
--获取视图矩阵
function CameraController:GetView()
    if self.viewDirty then
        self.view = self:GetEffectiveWorldTransform():Inverse()
        self.viewDirty = false
    end
    return self.view
end
--获取投影矩阵
function CameraController:GetProjection()
    if self.projectionDirty then
        if self.projection == nil then
            self.projection = Mat4.new()
        end
        self.projection:SetData(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        local fov = self:GetFov()
        local far = self:GetFar()
        local near = self:GetNear()
        local viewportSize = self:GetViewportSize()
        local aspectRatio = viewportSize.x / viewportSize.y

        local h = (1.0 / math.tan(fov * MathDefines.M_DEGTORAD * 0.5))
        local w = h / aspectRatio
        local q = far / (far - near)
        local r = -q * near

        self.projection.m00 = w
        self.projection.m02 = 2.0
        self.projection.m11 = h
        self.projection.m12 = 2.0
        self.projection.m22 = q
        self.projection.m23 = r
        self.projection.m32 = 1.0
        self.projectionDirty = false
    end
    return self.projection
end
--获取广角
function CameraController:GetFov()
    if not self.fov then
        self.fov = self.camera.FieldOfView
    end
    return self.fov
end
--设置广角
function CameraController:SetFov(fov)
    self.fov = fov
    self.camera.FieldOfView = fov
end

--获取近截面
function CameraController:GetNear()
    if not self.near then
        self.near = self.camera.ZNear
    end
    return self.near
end

function CameraController:SetNear(near)
    self.near = near
    self.camera.ZNear = near
end
--获取远截面
function CameraController:GetFar()
    if not self.far then
        self.far = self.camera.ZFar
    end
    return self.far
end

function CameraController:SetFar(far)
    self.far = far
    self.camera.ZFar = far
end
--获取视口大小
function CameraController:GetViewportSize()
    local viewportSize = self.camera.WindowSize
    return Vec2.new(viewportSize.x, viewportSize.y)
end

--------------------------------------输入控制-----------------------------------------
--设置输入启用
function CameraController:SetInputEnabled(enabled)
    self.inputEnabled = enabled
end
--鼠标移动
function CameraController:InputMove(deltaX, deltaY)
    local mouseXinput = deltaY
    local mouseYinput = deltaX
    if self.invertMouseX then
        mouseXinput = -mouseXinput
    end
    if self.invertMouseY then
        mouseYinput = -mouseYinput
    end

    if self.lockMouseX then
        mouseXinput = 0
    end
    if self.lockMouseY then
        mouseYinput = 0
    end

    self._mouseX = self._mouseX + mouseXinput * self.mouseXSensitivity
    self._mouseY = self._mouseY + mouseYinput * self.mouseYSensitivity
    --限制角度
    self._mouseX = math.clamp(self._mouseX, self.mouseXMin, self.mouseXMax)
    -- self._mouseY = math.clamp(self._mouseY, self.mouseYMin, self.mouseYMax)
end

--鼠标滚轮
function CameraController:InputWheel(delta)
    self._distance = math.clamp(self._distance + delta * self.wheelSensitivity, self.minDistance, self.maxDistance)
end

function CameraController:OnTouchStarted(x, y, touchId)
    self.touchId = touchId
    self.touchBeginPos.x = x
    self.touchBeginPos.y = y
    self.lastTouchPos.x = x
    self.lastTouchPos.y = y
    self.currentTouchPos.x = x
    self.currentTouchPos.y = y
    self.canSightTouch = false
end

function CameraController:EnableSightTouch()
    if MS.MouseService:IsSight() then
        self.canSightTouch = true
    end
end

function CameraController:OnTouchMoved(x, y, touchId)
    if self.touchId ~= touchId then
        return
    end
    --记录最后的触摸事件，锁定鼠标情况下超过一定事件不移动当成移动结束处理
    -- self.lastTouchTimeEnd = Utils:GetServerTime() + 1
    self.touchMoving = true
    self.currentTouchPos.x = x
    self.currentTouchPos.y = y

    local delta = self.currentTouchPos - self.lastTouchPos

    if self.inputEnabled then
        if self.alignWhenMoving and self.lockedOnTarget then
            self:InputMove(0, delta.y)
        else
            self:InputMove(delta.x, delta.y)
        end
    end

    self.lastTouchPos.x = x
    self.lastTouchPos.y = y
end

function CameraController:OnTouchEnded(x, y, touchId)
    if self.touchId ~= touchId then
        return
    end
    self.touchMoving = false
end
function CameraController:OnWheel(delta)
    if self.inputEnabled then
        self:InputWheel(delta)
    end
end
--------------------------------------后处理效果-----------------------------------------

-- local ChromaticAberrationBy = GFModuleScript("ActorModule.Action.ChromaticAberrationBy")
-- local Sequence = GFModuleScript("ActorModule.Action.Sequence")
-- function CameraController:StartChromaticAberration(duration,intensity,startOffset,iterationStep,iterationSamples)
--     intensity = intensity or 1
--     startOffset = startOffset or 1
--     iterationStep = iterationStep or 4
--     iterationSamples = iterationSamples or 4

--     self.owner.PostProcessing:SetChromaticAberrationStartOffset(startOffset)
--     self.owner.PostProcessing:SetChromaticAberrationIterationStep(iterationStep)
--     self.owner.PostProcessing:SetChromaticAberrationIterationSamples(iterationSamples)

--     self.owner:StopActionByTag("ChromaticAberration")
--     local ca1 = ChromaticAberrationBy.new()
--     ca1:Init(duration / 2,intensity)
--     local ca2 = ChromaticAberrationBy.new()
--     ca2:Init(duration / 2,-intensity)
--     local seq = Sequence.new()
--     seq:Init(ca1, ca2)
--     seq:SetTag("ChromaticAberration")
--     self.owner:RunAction(seq)
-- end

-- function CameraController:StartRadialBlur(duration,intensity,startOffset,iterationStep,iterationSamples)
--     intensity = intensity or 1
--     startOffset = startOffset or 1
--     iterationStep = iterationStep or 4
--     iterationSamples = iterationSamples or 4

--     self.owner.PostProcessing:SetChromaticAberrationStartOffset(startOffset)
--     self.owner.PostProcessing:SetChromaticAberrationIterationStep(iterationStep)
--     self.owner.PostProcessing:SetChromaticAberrationIterationSamples(iterationSamples)

--     self.owner:StopActionByTag("ChromaticAberration")
--     local ca1 = ChromaticAberrationBy.new()
--     ca1:Init(duration / 2,intensity)
--     local ca2 = ChromaticAberrationBy.new()
--     ca2:Init(duration / 2,-intensity)
--     local seq = Sequence.new()
--     seq:Init(ca1, ca2)
--     seq:SetTag("ChromaticAberration")
--     self.owner:RunAction(seq)
-- end

return CameraController
