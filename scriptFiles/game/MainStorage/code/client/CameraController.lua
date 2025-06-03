local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ClientEventManager = require(MainStorage.code.client.ClientEventManager) ---@type ClientEventManager
local TweenService = game:GetService("TweenService")

---@class CameraController
---@field New fun( camera:Camera ):CameraController
local CameraController = ClassMgr.Class("CameraController")

---@param camera Camera
function CameraController:OnInit(camera)
    self.camera = camera
    self.currentTween = nil
    
    -- 监听视角设置事件
    ClientEventManager.Subscribe("SetCameraView", function(data)
        self:SetView(data.position, data.target, data.duration)
    end)
end

---设置相机视角
---@param position Vector3 视角位置
---@param target Vector3 视角目标点
---@param duration number 过渡时间(秒)
function CameraController:SetView(position, target, duration)
    -- 取消当前正在进行的过渡
    if self.currentTween then
        self.currentTween:Cancel()
        self.currentTween = nil
    end

    -- 创建过渡动画
    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )

    -- 创建目标状态
    local targetState = {
        Position = position,
        LookAt = target
    }

    -- 创建并启动过渡动画
    self.currentTween = TweenService:Create(self.camera, tweenInfo, targetState)
    self.currentTween:Play()
end

return CameraController 