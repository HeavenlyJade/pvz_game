local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local Tweens = require(MainStorage.code.client.ui.Tweens) ---@type Tweens
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController

---@class BattleHud:ViewBase
local BattleHud = ClassMgr.Class("BattleHud", ViewBase)
local localPlayer = nil ---@type Player
local uiConfig = {
    uiName = "BattleHud",
    layer = 0,
    hideOnInit = true, -- 初始隐藏，当玩家靠近NPC时显示
    initHudInteract = false
}

function BattleHud:Close()
    if localPlayer then
        localPlayer.CameraMode = Enum.CameraModel.Classic
    end
end

function BattleHud:Open()
    localPlayer = game:GetService("Players").LocalPlayer
    localPlayer.CameraMode = Enum.CameraModel.LockFirstPerson
end

function BattleHud:SetFov(fov)
    if self.cameraTween then
        self.cameraTween:Destroy()
    end
    local tweenInfo = TweenInfo.New(0.2, Enum.EasingStyle.Linear)
    local TweenService = game:GetService('TweenService')
    self.cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {FieldOfView = fov})
    self.cameraTween:Play()
end

function BattleHud:OnInit(node, config)
    self.fireIcon = self:Get("开火", ViewButton)
    self.fireIcon.node.TouchBegin:Connect(
        function(node, isTouchMove, vector2, int)
            local postProcessing = game.WorkSpace["Environment"].PostProcessing
            postProcessing.ChromaticAberrationIntensity = 0.5
            postProcessing.ChromaticAberrationStartOffset = 0.9
            postProcessing.ChromaticAberrationIterationStep = 5
            postProcessing.ChromaticAberrationIterationSamples = 4
        
            self:SetFov(30)
            -- 给UI系统发送信息
            -- self.playerHUD.eventObject:FireEvent("OnFireInputBegin")
            -- 记录按下的位置
            self.fireInputBeginPos = vector2
            -- 这一句只能放在最下面，否则会堵塞后面的语句执行
            -- self.pawn.controlledWeaponPlantInstance:PullTrigger()
        end
    )

    self.fireIcon.node.TouchEnd:Connect(
        function(node, isTouchMove, vector2, int)
            local postProcessing = game.WorkSpace["Environment"].PostProcessing
            postProcessing.ChromaticAberrationIntensity = 1
            postProcessing.ChromaticAberrationStartOffset = 0.4
            postProcessing.ChromaticAberrationIterationStep = 0.01
            postProcessing.ChromaticAberrationIterationSamples = 1
        
            self:SetFov(50)
            -- 给UI系统发送信息
            -- self.playerHUD.eventObject:FireEvent("OnFireInputEnd")
            -- self.pawn.controlledWeaponPlantInstance:ReleaseTrigger()
        end
    )
    self.fireIcon.node.TouchMove:Connect(
        function(node, isTouchMove, vector2, int)
            -- 计算移动的距离
            local moveDistance = vector2 - self.fireInputBeginPos
            -- 更新按下的位置
            self.fireInputBeginPos = vector2
            CameraController.InputMove(
                moveDistance.y,
                moveDistance.x
            )
            
            
            -- local rotated = localPlayer.Euler + Vector3.New(moveDistance.x, moveDistance.y, 0)
            -- local toQuat = Quaternion.FromEuler(rotated.x, rotated.y, rotated.z)
            -- local cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {Rotation = toQuat})
            -- cameraTween:Play()
        end
    )
end

return BattleHud.New(script.Parent, uiConfig)