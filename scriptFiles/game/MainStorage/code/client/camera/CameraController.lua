local MainStorage = game:GetService("MainStorage")
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local ShakeBeh = require(MainStorage.code.client.camera.ShakeBeh) ---@type ShakeBeh


---@class CameraController
local CameraController = {
}

local camera = game.WorkSpace.CurrentCamera ---@type Camera
local deltaInputX, deltaInputY = 0, 0
local tweenInfo = TweenInfo.New(0.1, Enum.EasingStyle.Linear)
local TweenService = game:GetService('TweenService')

function CameraController.InputMove(x, y)
    deltaInputX = x
    deltaInputY = y
end

game.RunService.Stepped:Connect(function()
    local posOffset = Vector3.New(0, 0, 0)
    local rotOffset = Vector3.New(deltaInputX, deltaInputY, 0)
    if ShakeBeh.IsShaking() then
        rotOffset = rotOffset + ShakeBeh.GetRotDelta()
        posOffset = posOffset + ShakeBeh.GetPosDelta()
    end
    
    if posOffset.x ~=0 or posOffset.y ~= 0 then
        local cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {Position = camera.Position + posOffset})
        cameraTween:Play()
    end
    
    if rotOffset.x ~=0 or rotOffset.y ~= 0 then
        local rotated = camera.Euler + rotOffset
        local toQuat = Quaternion.FromEuler(rotated.x, rotated.y, rotated.z)
        local cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {Rotation = toQuat})
        cameraTween:Play()
        deltaInputX, deltaInputY = 0, 0
    end
end)


return CameraController