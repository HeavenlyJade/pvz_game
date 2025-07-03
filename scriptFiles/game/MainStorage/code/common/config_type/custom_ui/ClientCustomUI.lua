local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local UserInputService = game:GetService("UserInputService") ---@type UserInputService
-- local ShakeBeh = require(MainStorage.code.client.camera.ShakeBeh) ---@type ShakeBeh
local tweenInfo = TweenInfo.New(0.2, Enum.EasingStyle.Linear)
local TweenService = game:GetService('TweenService') ---@type TweenService

---@class ClientCustomUI:ViewBase
local ClientCustomUI = ClassMgr.Class("ClientCustomUI", ViewBase)

function ClientCustomUI.Load(node)
    local uiConfig = {
        uiName = node.Name,
        layer = 1,
        hideOnInit = true
    }
    return ClientCustomUI.New(node, uiConfig)
end

function ClientCustomUI:OnInit(node)
    local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
    ClientEventManager.Subscribe("ViewCustomUI"..node.Name, function (evt)
        local CustomUIConfig = require(MainStorage.code.common.config.CustomUIConfig) ---@type CustomUIConfig
        local customUI = CustomUIConfig.Get(evt.id)
        customUI.view = self
        customUI:C_BuildUI(evt)
        self:Open()
    end)
end

return ClientCustomUI
