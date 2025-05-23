-- local MainStorage = game:GetService("MainStorage")
-- local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
-- local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
-- local ShakeBeh = require(MainStorage.code.client.camera.ShakeBeh) ---@type ShakeBeh


-- ---@class CameraController
-- local CameraController = {
-- }

-- local camera = game.WorkSpace.CurrentCamera ---@type Camera
-- local deltaInputX, deltaInputY = 0, 0
-- local tweenInfo = TweenInfo.New(0.1, Enum.EasingStyle.Linear)
-- local TweenService = game:GetService('TweenService')
-- local renderTask = nil
-- local tickTask = nil

-- local function UpdateCameraRender(dt)
--     local rotOffset = Vector3.New(deltaInputX, deltaInputY, 0)
--     if ShakeBeh.IsShaking() then
--         rotOffset = rotOffset + ShakeBeh.GetRotDelta()
--     end
    
--     if rotOffset.x ~=0 or rotOffset.y ~= 0 then
--         local rotated = camera.Euler + gg.vec.Multiply3(rotOffset, dt)
--         local toQuat = Quaternion.FromEuler(rotated.x, rotated.y, rotated.z)
--         camera.Rotation = toQuat
--     end
-- end
-- local function UpdateCameraTick()
--     local posOffset = Vector3.New(0, 0, 0)
--     if ShakeBeh.IsShaking() then
--         posOffset = posOffset + ShakeBeh.GetPosDelta()
--     end
--     if posOffset.x ~=0 or posOffset.y ~= 0 then
--         local cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {Position = camera.Position + posOffset})
--         cameraTween:Play()
--     end
--     deltaInputX = 0
--     deltaInputY = 0
-- end

-- function CameraController.SetActive(active)
--     if active then
--         camera.CameraType = Enum.CameraType.Scriptable
--         if not renderTask then
--             renderTask = game.RunService.RenderStepped:Connect(UpdateCameraRender)
--         end
--         if not tickTask then
--             tickTask = game.RunService.Stepped:Connect(UpdateCameraTick)
--         end
--     else
--         camera.CameraType = Enum.CameraType.Custom
--         renderTask:Disconnect()
--         renderTask = nil
--         tickTask:Disconnect()
--         tickTask = nil
--     end
-- end

-- function CameraController.InputMove(x, y)
--     deltaInputX = x
--     deltaInputY = y
-- end


-- return CameraController