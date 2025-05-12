--- V109 miniw-haima

local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local SandboxNode = SandboxNode
local Vector2  = Vector2
local Vector3  = Vector3
local ColorQuad = ColorQuad
local Enum = Enum  
local wait = wait
local math = math
local os   = os

local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager) ---@type CommandManager
local CPlayer       = require(MainStorage.code.server.entity_types.CPlayer)          ---@type CPlayer
local MTerrain      = require(MainStorage.code.server.MTerrain)         ---@type MTerrain
--local CScene      = require(MainStorage.code.server.CScene)         ---@type CScene
-- local buffMgr       = require(MainStorage.code.server.buff.BuffMgr)  ---@type BufferMgr
local bagMgr        = require(MainStorage.code.server.bag.BagMgr)          ---@type BagMgr
local cloudDataMgr  = require(MainStorage.code.server.MCloudDataMgr)    ---@type MCloudDataMgr
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
-- 总入口
---@class MainServer
local MainServer = {};

-- 定义命令处理器模块
local CommandHandlers = {}

-- 处理键盘按键
function CommandHandlers.handleKey(uin_, args)
    -- 键盘按键处理逻辑
end

-- 处理使用物品
function CommandHandlers.handleBtnUseItem(uin_, args)
    bagMgr.handleBtnUseItem(uin_, args)
end

-- 处理分解
function CommandHandlers.handleBtnDecompose(uin_, args)
    bagMgr.handleBtnDecompose(uin_, args)
end

-- 处理合成
function CommandHandlers.handleBtnCompose(uin_, args)
    bagMgr.handleBtnCompose(uin_, args)
end

-- 处理心跳
function CommandHandlers.handleHeartbeat(uin_, args)
    gg.network_channel:fireClient(uin_, { cmd='cmd_heartbeat', msg='ok', uin=uin_ })
end

-- 处理请求玩家数据
function CommandHandlers.handleReqPlayerData(uin_, args)
    local player_ = gg.server_players_list[uin_]
    if player_ then
        player_:rsyncData(1)
    end
end
-- 处理玩家任务的获取数据
function CommandHandlers.handleGetGameTaskData(uin_, args)
	local player_ = gg.server_players_list[uin_]
    if player_ then
        player_:syncGameTaskData()
    end
end

function CommandHandlers.handleCompleteTask(uin_, args)
    local player_ = gg.server_players_list[uin_]
    if player_ then
        player_:handleCompleteTask(args.task_id)
    end
end


-- 处理请求玩家物品
function CommandHandlers.handlePlayerItemsReq(uin_, args)
    bagMgr.s2c_PlayerBagItems(uin_, args)
end

-- 处理玩家物品变化
function CommandHandlers.handlePlayerItemsChange(uin_, args)
    bagMgr.handlePlayerItemsChange(uin_, args)
end

-- 处理工作空间变化完成
function CommandHandlers.handleChangeWorkSpaceOk(uin_, args)
    MTerrain.handleChangeWorkSpaceOk(uin_, args.v)
end

-- 处理地图切换
function CommandHandlers.handleChangeMap(uin_, args)
    MTerrain.changeMap(uin_, args.v)
end

-- 处理使用所有盒子/物品
function CommandHandlers.handleUseAllBox(uin_, args)
    bagMgr.handleUseAllBox(uin_, args)
end


-- 客户端对入参命令表
local COMMAND_DISPATCH = {
    cmd_key = CommandHandlers.handleKey,
    cmd_btn_press = CommandHandlers.handleClientBtn,
    cmd_btn_use_item = CommandHandlers.handleBtnUseItem,
    cmd_btn_decompose = CommandHandlers.handleBtnDecompose,
    cmd_btn_compose = CommandHandlers.handleBtnCompose,
    cmd_pick_actor = CommandHandlers.handlePickActor,
    cmd_heartbeat = CommandHandlers.handleHeartbeat,
    cmd_aoe_select_pos = CommandHandlers.handleAoeSelectPos,
    cmd_player_skill_req = CommandHandlers.handlePlayerSkillReq,
    cmd_select_skill = CommandHandlers.handlePlayerSelectSkill,
    cmd_req_player_data = CommandHandlers.handleReqPlayerData,
    cmd_player_items_req = CommandHandlers.handlePlayerItemsReq,
    cmd_player_items_change = CommandHandlers.handlePlayerItemsChange,
    cmd_change_workspace_ok = CommandHandlers.handleChangeWorkSpaceOk,
    cmd_change_map = CommandHandlers.handleChangeMap,
    cmd_use_all_box = CommandHandlers.handleUseAllBox,
    cmd_dp_all_low_eq = CommandHandlers.handleDpAllLowEq,
    cmd_player_input = CommandHandlers.handlePlayerInput,
	cmd_client_game_task_data = CommandHandlers.handleGetGameTaskData,
    cmd_complete_task = CommandHandlers.handleCompleteTask,
    cmd_core_ui_settings = CommandHandlers.handleCoreUISettings,
}

function MainServer.start_server()
    math.randomseed(os.time() + os.clock())
    gg.uuid_start = gg.rand_int_between(100000, 999999)
    -- local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager) ---@type CommandManager

    gg.log('主服务器开始初始化');
    gg.CommandManager = CommandManager  -- 挂载到全局gg对象上以便全局访问

    MTerrain.init()                       --地形管理
    MainServer.register_player_in_out()   --玩家进出游戏
    MainServer.createNetworkChannel()     --建立网络通道
    
    MainServer.SetCollisionGroup()        --设置碰撞组
    wait(1)                               --云服务器启动配置文件下载和解析繁忙，稍微等待
    MainServer.bind_update_tick()         --开始tick
end





--设置碰撞组
function MainServer.SetCollisionGroup()
    --设置碰撞组
    local WS = game:GetService("PhysXService")
    WS:SetCollideInfo(0, 0, false)   --玩家不与玩家碰撞
    WS:SetCollideInfo(1, 1, false)   --怪物不与怪物碰撞
    WS:SetCollideInfo(0, 1, false)   --玩家不与怪物碰撞
end

--注册玩家进游戏和出游戏消息
function MainServer.register_player_in_out()
    local players = game:GetService("Players")
    
    players.PlayerAdded:Connect(function(player)
        gg.log('====PlayerAdded', player.UserId)
        MainServer.player_enter_game(player)
    end)
    
    players.PlayerRemoving:Connect(function(player)
        gg.log('====PlayerRemoving', player.UserId)
        MainServer.player_leave_game(player)
    end)
end

--玩家进入游戏，数据加载
function MainServer.player_enter_game(player)
    gg.log("player enter====", player.UserId, player.Name, player.Nickname)
    
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
    actor_.Movespeed = 800
    actor_.ModelId = 'sandboxSysId://entity/130034/body.omod'    --默认渔民女
    actor_:AddAttribute("model_type", Enum.AttributeType.String)
    actor_:SetAttribute("model_type", "player")
    
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
    local player_ = CPlayer.New({
        x=600, y=400, z=-3400,      --(617,292,-3419)
        uin=uin_,
        id=1,
        nickname=player.Nickname,
        npc_type=common_const.NPC_TYPE.PLAYER,
        level = cloud_player_data_.level,
        exp = cloud_player_data_.exp
    })
    
    --加载数据 2 玩家历史装备数据
    local ret2_, cloud_player_bag_ = cloudDataMgr.ReadPlayerBag(player_)
    if ret2_ == 0 then
        gg.log('cloud_player_bag ok:', uin_)
        player_:SendHoverText('加载玩家背包数据成功')
        bagMgr.setPlayerBagData(uin_, cloud_player_bag_)
    else
        gg.log('cloud_player_bag fail:', uin_)
        player_:SendHoverText('加载玩家背包数据失败，请退出游戏后重试')
        return     --加载背包数据失败
    end
    player_.bag = cloud_player_bag_
    
    gg.server_players_list[uin_] = player_
    gg.server_players_name_list[player.Name] = player_
    
    actor_.Size = Vector3.new(120, 160, 120)      --碰撞盒子的大小
    actor_.Center = Vector3.new(0, 80, 0)      --盒子中心位置
    
    player_:setGameActor(actor_)     --player
    player_:changeScence('g0')       --默认g0大厅
    
    player_:equipWeapon(common_config.assets_dict.model.model_sword)
    player_:setPlayerNetStat(common_const.PLAYER_NET_STAT.LOGIN_IN)    --player_net_stat login ok
    
    player_:initSkillData()                 --- 加载玩家技能
    -- player_:initGameTaskData()              --- 加载玩家任务
    player_:RefreshStats()               --重生 --刷新战斗属性
end

--玩家离开游戏
function MainServer.player_leave_game(player)
    gg.log("player_leave_game====", player.UserId, player.Name, player.Nickname)
    local uin_ = player.UserId
    
    if gg.server_players_list[uin_] then
        gg.server_players_list[uin_]:Save()
    end
    gg.server_players_name_list[player.Name] = nil
    gg.server_players_list[uin_] = nil
end

--建立网络通道
function MainServer.createNetworkChannel()
    gg.log('createNetworkChannel server side')
    --begin listen
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel")
    gg.network_channel.OnServerNotify:Connect(MainServer.OnServerNotify)
end

--消息回调 (优化版本，使用命令表和错误处理)
function MainServer.OnServerNotify(uin_, args)
    -- 参数校验
    if type(args) ~= 'table' then return end
    if not args.cmd then return end
    
    -- 获取处理器
    local handler = COMMAND_DISPATCH[args.cmd]
    if not handler then
        local player_ = gg.getPlayerByUin(uin_)
        gg.log("publish event:", args)
        args.player = player_
        ServerEventManager.Publish(args.cmd, args)
        return
    end
    
    -- 执行处理
    local success, err = pcall(handler, uin_, args)
    if not success then
        gg.log("[ERROR] Command handler failed:", args.cmd, err)
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
    timer.Interval = 0.1   -- 循环间隔多少秒 (1秒=10帧)
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
    --更新技能
    -- skillMgr.update()
end

return MainServer;