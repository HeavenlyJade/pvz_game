
local MainStorage     = game:GetService("MainStorage")
local game            = game
local Enum            = Enum  ---@type Enum
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ViewBase        = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ClassMgr    = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local ClientInit = require(MainStorage.code.client.event.ClinentInit) ---@type ClientInit
local Controller = require(MainStorage.code.client.MController) ---@type Controller
require(MainStorage.code.client.graphic.SoundPool)
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController
---@class ClientMain
local ClientMain = ClassMgr.Class("ClientMain")
function ClientMain.start_client()
    print("start_client", gg.isServer)
    gg.isServer = false
    ClientMain.tick = 0
    gg.uuid_start = gg.rand_int_between(100000, 999999);
    ClientMain.createNetworkChannel()
    ClientMain.handleCoreUISettings()
    ClientInit.init()
    ClientMain.initButton()

    Controller.init()
    local timer = SandboxNode.New("Timer", game.StarterGui)
    timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE


    require(MainStorage.code.client.graphic.DamagePool)
    require(MainStorage.code.client.graphic.WorldTextAnim)
    ClientEventManager.Subscribe("FetchAnimDuration", function (evt)
        local animator = gg.GetChild(game:GetService("WorkSpace"), evt.path) ---@cast animator Animator
        if animator then
            for stateId, _ in pairs(evt.states) do
                local fullState = string.format("Base Layer.%s", stateId)
                local playTimeByStr = animator:GetClipLength(fullState)
                evt.states[stateId] = playTimeByStr
            end
            evt.Return(evt.states)
        end
    end)
    if game.RunService:IsPC() then
        game.MouseService:SetMode(1)
    end
    local plugins = MainStorage.plugins
    if plugins then
        for _, child in pairs(plugins.Children) do
            if child and child.PluginMain then
                local plugin = require(child.PluginMain)
                if plugin.StartClient then
                    plugin.StartClient()
                end
            end
        end
    end
    ClientScheduler.add(function ()
        ViewBase.LockMouseVisible(false)
    end, 1)
    -- ClientEventManager.Subscribe("FetchModelSize", function (evt)
    --     local actor = gg.GetChild(game:GetService("WorkSpace"), evt.path) ---@cast actor Actor
    --     if actor then
    --         -- local modelId = actor.ModelId
    --         -- actor.ModelId = ""
    --         -- actor.ModelId = modelId
    --         local size = actor.Size
    --         print("ModelId", size)
    --         evt.Return({size.x, size.y, size.z})
    --     end
    -- end)
end



function ClientMain.createNetworkChannel()
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel") ---@type NetworkChannel
    gg.network_channel.OnClientNotify:Connect(ClientMain.OnClientNotify)

    gg.network_channel:FireServer({ cmd = 'cmd_heartbeat', msg = 'new_client_join' })

    gg.log('网络通道建立结束')
end

--  通过CoreUI 屏蔽默认的按钮组件
function ClientMain.handleCoreUISettings()
    local CoreUI = game:GetService("CoreUI")
    CoreUI:HideCoreUi(Enum.CoreUiComponent.All )
    -- CoreUI:MicSwitchBtn(false)
    -- CoreUI:HornSwitchBtn(false)
end


function ClientMain.initButton()
    -- local UiSettingBut = require(MainStorage.code.client.UiClient.SysUi.SettingBut) ---@type UiSettingBut
    -- UiSettingBut.OnInit()

end
function ClientMain.OnClientNotify(args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end

    if args.__cb then
        args.Return = function(returnData)
            gg.network_channel:FireServer({
                cmd = args.__cb .. "_Return",
                data = returnData
            })
        end
    end
    ClientEventManager.Publish(args.cmd, args)
end

return ClientMain

