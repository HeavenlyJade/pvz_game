
local MainStorage     = game:GetService("MainStorage")
local game            = game
local Enum            = Enum  ---@type Enum
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ViewBase        = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ClassMgr    = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local ClientInit = require(MainStorage.code.client.event.ClinentInit) ---@type ClientInit
---@class ClientMain
local ClientMain = ClassMgr.Class("ClientMain")
local tick = 0
local lastTickTime = os.clock()

function ClientMain.start_client()
    ClientMain.tick = 0
    math.randomseed(os.time() + os.clock());
    gg.uuid_start = gg.rand_int_between(100000, 999999);
    ClientMain.createNetworkChannel()
    ClientMain.handleCoreUISettings()
    ClientInit.init()
    local timer = SandboxNode.New("Timer", game.StarterGui)
    timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    
    timer.Name = 'timer_client'
    timer.Delay = 0.1      -- 延迟多少秒开始
    timer.Loop = true      -- 是否循环
    timer.Interval = 0.03  -- 循环间隔多少秒 (1秒=20帧)
    timer.Callback = ClientMain.update
    timer:Start()     -- 启动定时器
end


--定时器update
function ClientMain.update()
    tick = tick + 1
    ClientScheduler.tick = tick  -- 对于服务器端
    ClientScheduler.update()  -- 对于服务器端
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

function ClientMain.OnClientNotify(args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end

    gg.log("publish event:", args)
    ClientEventManager.Publish(args.cmd, args)
end

return ClientMain