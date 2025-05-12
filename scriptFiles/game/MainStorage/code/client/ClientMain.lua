
local MainStorage     = game:GetService("MainStorage")
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ViewBase        = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local CommonModule    = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
---@class ClientMain
local ClientMain = CommonModule.Class("ClientMain")

function ClientMain.start_client()
    math.randomseed(os.time() + os.clock());
    gg.uuid_start = gg.rand_int_between(100000, 999999);
    ClientMain.createNetworkChannel()
end

function ClientMain.createNetworkChannel()
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel") ---@type NetworkChannel
    gg.network_channel.OnClientNotify:Connect(ClientMain.OnClientNotify)

    gg.network_channel:FireServer({ cmd = 'cmd_heartbeat', msg = 'new_client_join' })
    gg.log('网络通道建立结束')
end

function ClientMain.OnClientNotify(args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end

    gg.log("publish event:", args)
    ClientEventManager.Publish(args.cmd, args)
end

return ClientMain