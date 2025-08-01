local MainStorage = game:GetService("MainStorage")
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local MiniShopManager = require(MainStorage.code.server.bag.MiniShopManager) ---@type MiniShopManager
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
gg.isServer = true
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local Player       = require(MainStorage.code.server.entity_types.Player)          ---@type Player
local Scene      = require(MainStorage.code.server.Scene)         ---@type Scene
local bagMgr        = require(MainStorage.code.server.bag.BagMgr)          ---@type BagMgr
local cloudDataMgr  = require(MainStorage.code.server.MCloudDataMgr)    ---@type MCloudDataMgr
local cloudMailData = require(MainStorage.code.server.Mail.cloudMailData) ---@type CloudMailDataAccessor
local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
--local TransmitEvent = require(MainStorage.code.server.Transmit.TransmitEvent) ---@type TransmitEvent
-- 总入口
---@class MainServer
local MainServer = {};
local initFinished = false;
local waitingPlayers = {} -- 存储等待初始化的玩家

-- 处理午夜刷新
function MainServer.handleMidnightRefresh()
    local now = os.date("*t")
    local nextMidnight = os.time({
        year = now.year,
        month = now.month,
        day = now.day + 1,
        hour = 0,
        min = 0,
        sec = 0
    })
    local secondsUntilMidnight = nextMidnight - os.time()

    ServerScheduler.add(function()
        -- 对所有在线玩家执行刷新
        for _, player in pairs(gg.server_players_list) do
            if player and player.inited then
                player:RefreshNewDay()
            end
        end
        -- 重新设置下一个午夜的定时任务
        MainServer.handleMidnightRefresh()
    end, secondsUntilMidnight, 0, "midnight_refresh")
end

function MainServer.start_server()
    math.randomseed(os.time() + gg.GetTimeStamp())
    gg.uuid_start = gg.rand_int_between(100000, 999999)
    MainServer.register_player_in_out()   --玩家进出游戏

    MainServer.initModule()
    for _, node in  pairs(game.WorkSpace.Ground.Children) do
        Scene.New( node )
    end
    game:GetService("PhysXService"):SetCollideInfo(3, 3, false)
    game:GetService("PhysXService"):SetCollideInfo(4, 4, false)
    game:GetService("PhysXService"):SetCollideInfo(2, 2, false)
    game:GetService("PhysXService"):SetCollideInfo(1, 1, false)
    MainServer.createNetworkChannel()     --建立网络通道
    wait(1)                               --云服务器启动配置文件下载和解析繁忙，稍微等待
    MainServer.bind_update_tick()         --开始tick
    MainServer.handleMidnightRefresh()    --设置午夜刷新定时任务
    initFinished = true
    for _, player in ipairs(waitingPlayers) do
        MainServer.player_enter_game(player)
    end
    waitingPlayers = {} -- 清空等待列表
    for _, child in pairs(MainStorage.config.Children) do
        gg.log("加载配置 %s", child.Name)
        local success, err = pcall(function()
            require(child)
        end)
        
        if not success then
            gg.log(string.format("加载配置 %s 失败\n错误: %s", child.Name, err or "unknown error"))
        end
    end
    gg.log("加载指令系统")
    require(MainStorage.code.server.CommandSystem.MCommandManager) ---@type CommandManager
    local plugins = MainStorage.plugin
    if plugins then
        for _, child in pairs(plugins.Children) do
            if child and child.main then
                local plugin = require(child.main)
                if plugin.StartServer then
                    gg.log("服务端插件 %s 加载中……", child.Name)
                    local success, err = pcall(plugin.StartServer)
                    
                    if not success then
                        gg.log("服务端插件 %s 加载失败\n错误: %s", child.Name, err or "unknown error")
                    else
                        gg.log("服务端插件 %s 加载成功！", child.Name)
                    end
                end
            end
        end
    end
end

function MainServer.initModule()
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager) ---@type SkillEventManager
    local BagEventManager = require(MainStorage.code.server.bag.BagEventManager) ---@type BagEventManager
    -- gg.CommandManager = CommandManager    -- 挂载到全局gg对象上以便全局访问
    -- gg.cloudMailData = cloudMailData:Init()
    SkillEventManager.Init()
    MailManager:Init()
    --TransmitEvent.Init()
    gg.log("initModule", 3)
    BagEventManager:Init()
    gg.log("initModule", 4)
    ServerEventManager.Subscribe("PlayerClientInited", function (evt)
        evt.player:UpdateHud()
    end)
    gg.log("initModule", 5)
end

-- --设置碰撞组
-- function MainServer.SetCollisionGroup()
--     --设置碰撞组
--     local WS = game:GetService("PhysXService")
--     WS:SetCollideInfo(0, 0, false)   --玩家不与玩家碰撞
--     WS:SetCollideInfo(1, 1, false)   --怪物不与怪物碰撞
--     WS:SetCollideInfo(0, 1, false)   --玩家不与怪物碰撞
-- end

--注册玩家进游戏和出游戏消息
function MainServer.register_player_in_out()
    local players = game:GetService("Players")

    players.PlayerAdded:Connect(function(player)
        gg.log('====PlayerAdded', player.UserId)
        if initFinished then
            MainServer.player_enter_game(player)
        else
            table.insert(waitingPlayers, player)
            gg.log('====PlayerAdded to waiting list', player.UserId)
        end
    end)

    players.PlayerRemoving:Connect(function(player)
        gg.log('====PlayerRemoving', player.UserId)
        -- 如果玩家在等待列表中，需要移除
        for i, waitingPlayer in ipairs(waitingPlayers) do
            if waitingPlayer.UserId == player.UserId then
                table.remove(waitingPlayers, i)
                break
            end
        end
        MainServer.player_leave_game(player)
    end)
end

--玩家进入游戏，数据加载
function MainServer.player_enter_game(player)
    player.DefaultDie = false   --取消默认死亡

    local uin_ = player.UserId
    if gg.server_players_list[uin_] then
        gg.log('WAINING, Same uin enter game:', uin_)

        --强制离开游戏
        if gg.server_players_list[uin_] then
            gg.server_players_list[uin_]:Save()
        end
    end

    local actor_ = player.Character
    actor_.CollideGroupID = 4
    actor_.Movespeed = 800
    --actor_.ModelId = 'sandboxSysId://entity/130034/body.omod'    --默认渔民女
    -- actor_:AddAttribute("model_type", Enum.AttributeType.String)
    -- actor_:SetAttribute("model_type", "player")

    --加载数据 1 玩家历史等级经验值
    local ret1_, cloud_player_data_ = cloudDataMgr.ReadPlayerData(uin_)
    if ret1_ == 0 then
        gg.log('clould_player_data ok:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据成功' })     --飘字
    else
        gg.log('clould_player_data fail:', uin_, cloud_player_data_)
        gg.network_channel:fireClient(uin_, { cmd="cmd_client_show_msg", txt='加载玩家等级数据失败，请退出游戏后重试' })    --飘字
        return   --加载数据网络层失败
    end

    -- 玩家信息初始化
    local player_ = Player.New({
        position = Vector3.New(600, 400, -3400),      --(617,292,-3419)
        uin=uin_,
        id=1,
        nickname=player.Nickname,
        npc_type=common_const.NPC_TYPE.PLAYER,
        level = cloud_player_data_.level,
        exp = cloud_player_data_.exp,
    })
    player_.variables = cloud_player_data_.vars or {}

    --加载数据 2 玩家历史装备数据
    ---@type number, Bag
    local ret2_, bag_ins = cloudDataMgr.ReadPlayerBag(player_)
    if ret2_ == 0 then
        gg.log('cloud_player_bag ok:', uin_)
        bagMgr.setPlayerBagData(uin_, bag_ins)
    else
        gg.log('cloud_player_bag fail:', uin_)
        return     --加载背包数据失败
    end

    cloudDataMgr.ReadGameTaskData(player_)
    local mail_player_data_ = cloudMailData:LoadPlayerMailBundle(uin_)
    gg.log("cloud_player_bag_",bag_ins)
    player_.mail = mail_player_data_
    player_.bag = bag_ins
    gg.server_players_list[uin_] = player_
    gg.server_players_name_list[player.Nickname] = player_

    -- 同步玩家的全服邮件数据
    MailManager:SyncGlobalMailsForPlayer(uin_)

    actor_.Size = Vector3.New(120, 160, 120)      --碰撞盒子的大小
    actor_.Center = Vector3.New(0, 80, 0)      --盒子中心位置

    player_:setGameActor(actor_)     --player
    actor_.CollideGroupID = 4
    player_:setPlayerNetStat(common_const.PLAYER_NET_STAT.LOGIN_IN)    --player_net_stat login ok

    player_:initSkillData()                 --- 加载玩家技能
    player_:RefreshStats()               --重生 --刷新战斗属性
    player_:SetHealth(player_.maxHealth)
    player_:UpdateHud()

    if Scene.spawnScene then
        if not player_:IsNear(Scene.spawnScene.node.Position, 500) then
            actor_.Position = Scene.spawnScene.node.Position
        end
    end
    player_.inited = true
    ServerEventManager.Publish("PlayerInited", {player = player_})

    MailManager:SendMailListToClient(uin_)
end

--玩家离开游戏
function MainServer.player_leave_game(player)
    gg.log("player_leave_game====", player.UserId, player.Name, player.Nickname)
    local uin_ = player.UserId

    if gg.server_players_list[uin_] then
        gg.server_players_list[uin_]:OnLeaveGame()
        gg.server_players_list[uin_]:Save()
    end
    gg.server_players_name_list[player.Name] = nil
    gg.server_players_list[uin_] = nil
end

--建立网络通道
function MainServer.createNetworkChannel()
    --begin listen
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel")
    gg.network_channel.OnServerNotify:Connect(MainServer.OnServerNotify)

end

--消息回调 (优化版本，使用命令表和错误处理)
function MainServer.OnServerNotify(uin_, args)
    if type(args) ~= 'table' then return end
    if not args.cmd then return end

    local player_ = gg.getPlayerByUin(uin_)
    if not player_ then
        return
    end
    args.player = player_
    if args.__cb then
        args.Return = function(returnData)
            game:GetService("NetworkChannel"):fireClient({
                cmd = args.__cb .. "_Return",
                data = returnData
            })
        end
    end

    -- 自动判断：如果玩家有该事件的本地订阅，则作为本地事件发布，否则作为全局事件广播
    if ServerEventManager.HasLocalSubscription(player_, args.cmd) then
        ServerEventManager.PublishToPlayer(player_, args.cmd, args)
    else
        ServerEventManager.Publish(args.cmd, args)
    end
end

--开启update
function MainServer.bind_update_tick()
    -- 一个定时器, 实现tick update
    local timer = SandboxNode.New("Timer", game.WorkSpace)
    timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE

    timer.Name = 'timer_server'
    timer.Delay = 0.1      -- 延迟多少秒开始
    timer.Loop = true      -- 是否循环
    timer.Interval = 0.03   -- 循环间隔多少秒 (1秒=20帧)
    timer.Callback = MainServer.update
    timer:Start()     -- 启动定时器
    gg.timer = timer;
end

--定时器update
function MainServer.update()
    gg.tick = gg.tick + 1

    --更新场景
    for _, scene_ in pairs(gg.server_scene_list) do
        scene_:update()
    end
    ServerScheduler.tick = gg.tick  -- 对于服务器端
    ServerScheduler.update()  -- 对于服务器端
end

return MainServer;
