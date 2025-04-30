--- V109 miniw-haima
--- 客户端主逻辑

local game        = game
local type        = type
local math        = math
local ipairs      = ipairs

local ColorQuad   = ColorQuad
local Vector2     = Vector2
local Vector3     = Vector3

local SandboxNode = SandboxNode
local Enum        = Enum


local MainStorage     = game:GetService("MainStorage")
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config   = require(MainStorage.code.common.MConfig) ---@type common_config
local Controller      = require(MainStorage.code.client.MController) ---@type Controller

local uiSkillSelect   = require(MainStorage.code.client.ui.UiSkillSelect) ---@type UiSkillSelect
local uiBag           = require(MainStorage.code.client.ui.UiBag) ---@type UiBag
local UiCommon        = require(MainStorage.code.client.ui.UiCommon) ---@type UiCommon
local UiSelectDiff    = require(MainStorage.code.client.ui.UiSelectDiff) ---@type UiSelectDiff
local UiNpcBlackSmith = require(MainStorage.code.client.ui.UiNpcBlackSmith) ---@type UiNpcBlackSmith
local uiMap           = require(MainStorage.code.client.ui.UiMap) ---@type UiMap
local uiGameTask      = require(MainStorage.code.client.ui.UiTask.UiTaskMain) ---@type UiGameTask
local Players         = game:GetService('Players')
local SceneMgr        = game:GetService("SceneMgr")


---@class MainClient
local MainClient = {
    client_player_data = {
        hp = 0,
        mp = 0,
        hp_max = 0,
        mp_max = 0,
    },


    spell_remain_time = 0, --进度条残留时间

    spell_rate_now = 0,    --当前进度
    spell_rate_max = 0,    --最大时间


    spell_bar = nil,
    spell_bg  = nil,
    hp_bar    = nil,
    mp_bar    = nil,
    exp_bar   = nil,
    txt_level = nil,
}



--客户端入口
function MainClient.start_client()
    math.randomseed(os.time() + os.clock());
    gg.uuid_start = gg.rand_int_between(100000, 999999);

    MainClient.showStartupBg() --加载背景
    MainClient.setGameConfig() --改动配置文件

    gg.log('启动加载客户端MainClient.start_client', os.time(), os.clock());
    wait(1) --客户端启动配置文件下载和解析繁忙，稍微等待

    uiBag.init()
end

--点击开始游戏（按钮回调）
function MainClient.pressStartGame()
    gg.log('点击开始游戏');

    --[[ 隐藏默认UI按钮
    local LocalPlayer = Players.LocalPlayer
    if  LocalPlayer then
        LocalPlayer.PlayerGui.TouchUIMain.Visible = false
    end
    --]]

    MainClient.SetCollisionGroup() -- 初始化碰撞组
    MainClient.createNetworkChannel()
    MainClient.setSpellBar()
    MainClient.init_client_player()
    MainClient.bind_update_render_tick()
    MainClient.init_npc("g0")
    MainClient.initTeleport()
    Controller.init()

    --MainClient.installSceneSwitch()
end

--改动配置文件
function MainClient.setGameConfig()
    local environment = game.WorkSpace:WaitForChild("Environment")
    environment.Atmosphere.FogType = Enum.FogType.Disable --去掉雾效 Linear
    --距离控制
    --gg.log( 'ViewRange:', game.GameSetting.ViewRange )
    if not (game.GameSetting.ViewRange == Enum.ViewRange.Farther or game.GameSetting.ViewRange == Enum.ViewRange.Farthest) then
        game.GameSetting.ViewRange = Enum.ViewRange.Farther
    end
end

function MainClient.loadNpcConfig()
    -- 从公共配置获取NPC数据（参考材料12）
    local npcConfig = common_config.npc_spawn_config
    -- 获取当前场景NPC容器（参考材料11）
end

--展示加载界面
function MainClient.showStartupBg()
    local root_ = Players.LocalPlayer.PlayerGui:WaitForChild('ui_root_spell')

    gg.log('加载背景:', root_)

    if true then
        local startup_bg_       = gg.createImage(root_,
            common_config.assets_dict.startup_bg[(os.time() % #common_config.assets_dict.startup_bg) + 1])
        startup_bg_.Name        = "startup_bg"

        local ui_size           = game:GetService('WorldService'):GetUISize() --直接获得size

        startup_bg_.Size        = Vector2.New(ui_size.x * 1.1, ui_size.y * 1.1)
        startup_bg_.Pivot       = Vector2.new(0, 0)
        startup_bg_.RenderIndex = 1


        --按钮
        local tmp_button           = SandboxNode.New('UIButton', startup_bg_)
        tmp_button.Name            = 'btn_startup'
        tmp_button.RenderIndex     = 2
        tmp_button.Icon            = common_config.assets_dict.btn_press2
        tmp_button.FillColor       = ColorQuad.new(0, 0, 0, 0)
        tmp_button.DownEffect      = Enum.DownEffect.ColorEffect
        tmp_button.LayoutHRelation = Enum.LayoutHRelation.Right
        tmp_button.LayoutVRelation = Enum.LayoutVRelation.Bottom
        tmp_button.TitleSize       = 36
        tmp_button.Title           = '开 始 游 戏'
        tmp_button.Size            = Vector2.New(370, 80)
        tmp_button.Position        = Vector2.New(ui_size.x * 0.5, ui_size.y * 0.8)
        tmp_button.Click:Connect(function()
            startup_bg_:Destroy()
            wait(1)
            MainClient.pressStartGame() --开始游戏
        end)
    end
end

--设置碰撞组
function MainClient.SetCollisionGroup()
    --actor_.CollideGroupID = 1      --碰撞组  玩家=0 怪物=1 地表=2 （改为1不碰撞）
    --设置碰撞组
    local WS = game:GetService("PhysXService")
    WS:SetCollideInfo(0, 0, false) --玩家不与玩家碰撞
    WS:SetCollideInfo(1, 1, false) --怪物不与怪物碰撞
    WS:SetCollideInfo(0, 1, false) --玩家不与怪物碰撞
end

--建立网络通道
function MainClient.createNetworkChannel()
    gg.log('建立網絡通道')

    --begin listen
    gg.network_channel = MainStorage:WaitForChild("NetworkChannel")
    gg.network_channel.OnClientNotify:Connect(MainClient.OnClientNotify)

    gg.network_channel:FireServer({ cmd = 'cmd_heartbeat', msg = 'new_client_join' })
    gg.log('网络通道建立结束')
end

--允许或者禁止当前玩家的行动
function MainClient.enableUserInput(flag_)
    if flag_ == 1 then
        --开启控制
        if Keyboard then
            --Keyboard:UnbindContextActions()

            Keyboard.m_actor = Keyboard.m_actor_bak
            Keyboard.m_actor_bak = nil
            Keyboard.m_enable = true
        end

        Controller.m_enableMove = true

        --local LocalPlayer = Players.LocalPlayer
        --if  LocalPlayer then
        --local imgTouchBg = LocalPlayer.PlayerGui.TouchUIMain
        --imgTouchBg.Visible = true
        --end
    else
        --关闭控制
        if Keyboard then
            Keyboard:handleLoseFocus()
            --Keyboard:BindContextActions()

            Keyboard.m_actor_bak = Keyboard.m_actor
            Keyboard.m_actor = nil
            Keyboard.m_enable = false
        end

        Controller.m_enableMove = false

        --local LocalPlayer = Players.LocalPlayer
        --if  LocalPlayer then
        --local imgTouchBg = LocalPlayer.PlayerGui.TouchUIMain
        --imgTouchBg.Visible = false
        --end
    end
end

function MainClient.init_client_player()
    --Players.LocalPlayer.DefaultDie = false

    local name_ = 'p' .. gg.get_client_uin()  --只有client会使用
    gg.log('获取客户的玩家id', name_)

    --设置选中控件
    gg.client_selected               = gg.cloneFromTemplate('player_selected')
    gg.client_selected.Parent        = gg.getClientWorkSpace().template
    gg.client_selected.Name          = 'my_selected'

    --gg.client_selected.SyncMode = Enum.SyncMode.DISABLE
    gg.client_selected.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    gg.client_selected.Visible       = false
    --gg.client_selected.LocalPosition = Vector3.new( 0, 10000, 0 )

    --拉取服务器数据
    gg.network_channel:FireServer({ cmd = "cmd_req_player_data" })
end

--数据回调 玩家属性
function MainClient.handleSyncPlayerData(args1_)
    if args1_.v.level then
        local level_ = args1_.v.level

        if args1_.v.exp then
            local this_exp = common_config.expLevelUp[level_]
            local next_exp = common_config.expLevelUp[level_ + 1]

            if this_exp and next_exp then
                local rate_ = (args1_.v.exp - this_exp) / (next_exp - this_exp)
                if rate_ < 0 then
                    rate_ = 0
                elseif rate_ > 1 then
                    rate_ = 1
                end
                MainClient.exp_bar.FillAmount = rate_
            end
        end

        MainClient.txt_level.Title = '' .. level_
    end

    if args1_.v.battle_data then
        gg.client_player_data.battle_data = args1_.v.battle_data
        gg.client_player_data.user_name = args1_.v.user_name
        gg.client_player_data.user_id = args1_.v.uin

        if uiBag.desc_dmg_def then
            uiBag.showDescDmgDef()
        end
    end
end

--设置血条和施法条
function MainClient.setSpellBar()
    local ui_root_spell = Players.LocalPlayer.PlayerGui.ui_root_spell

    --血条和魔法条
    print("设置经验条.exp_bar", ui_root_spell.exp_bar)
    MainClient.hp_bar             = ui_root_spell.hp_bar
    MainClient.mp_bar             = ui_root_spell.mp_bar
    MainClient.exp_bar            = ui_root_spell.exp_bar

    MainClient.hp_bar.FillAmount  = 1
    MainClient.mp_bar.FillAmount  = 1
    MainClient.exp_bar.FillAmount = 0

    MainClient.txt_level          = ui_root_spell.txt_level


    --施法进度条
    MainClient.spell_bar = ui_root_spell.spell_bar
    MainClient.spell_bg  = ui_root_spell.spell_bg


    local ui_size                 = gg.get_ui_size()
    MainClient.spell_bar.Position = Vector2.new(ui_size.x * 0.5, ui_size.y * 0.75)
    MainClient.spell_bg.Position  = Vector2.new(ui_size.x * 0.5, ui_size.y * 0.75)

    MainClient.spell_bar.Visible  = false
    MainClient.spell_bg.Visible   = false

    ui_root_spell.name.Title      = Players.LocalPlayer.Nickname



    --target 血条名字
    MainClient.target_hp_bar            = ui_root_spell.target_hp_bar
    MainClient.target_mp_bar            = ui_root_spell.target_mp_bar
    MainClient.target_hp_bg             = ui_root_spell.target_hp_bg
    MainClient.target_mp_bg             = ui_root_spell.target_mp_bg

    MainClient.target_hp_bar.FillAmount = 1
    MainClient.target_mp_bar.FillAmount = 1

    MainClient.target_hp_bar.Visible    = false
    MainClient.target_mp_bar.Visible    = false
    MainClient.target_hp_bg.Visible     = false
    MainClient.target_mp_bg.Visible     = false
    --名字
    MainClient.target_name              = ui_root_spell.target_name
    MainClient.target_name.Visible      = false
end

--同步当前目标资料
function MainClient.syscTargetInfo(args1_)
    --[[
    local info_ = {
        cmd    = 'cmd_sync_target_info',

        name   = 'xxxx',
        hp     = target_.battle_data.hp,
        hp_max = target_.battle_data.hp_max,

        mp     = target_.battle_data.mp,
        mp_max = target_.battle_data.mp_max,

        show = 1,   --0=不显示， 1=显示
    }
    --]]

    --target 血条名字
    if args1_.show == 0 then
        --关闭显示（目标丢失）
        MainClient.target_hp_bar.Visible = false
        MainClient.target_mp_bar.Visible = false
        MainClient.target_hp_bg.Visible  = false
        MainClient.target_mp_bg.Visible  = false
        MainClient.target_name.Visible   = false

        if gg.client_selected then
            --hide
            gg.client_selected.Parent  = gg.getClientWorkSpace().template
            gg.client_selected.Visible = false
            --gg.client_selected.LocalPosition = Vector3.new( 0, 10000, 0 )
        end
    else
        --显示
        MainClient.target_hp_bar.Visible = true
        MainClient.target_mp_bar.Visible = true
        MainClient.target_hp_bg.Visible  = true
        MainClient.target_mp_bg.Visible  = true
        MainClient.target_name.Visible   = true

        if args1_.hp then
            local rate_ = args1_.hp / args1_.hp_max
            MainClient.target_hp_bar.FillAmount = rate_
        end

        if args1_.mp then
            local rate_ = args1_.mp / args1_.mp_max
            MainClient.target_mp_bar.FillAmount = rate_
        end

        if args1_.name then
            MainClient.target_name.Title = args1_.name
        end
    end
end

--施法朝向选定的目标node
function MainClient.faceTargetNode()
    if gg.client_target_node then
        local pos1 = gg.getClientLocalPlayer().Position
        local pos2 = gg.client_target_node.Position

        gg.getClientLocalPlayer().Euler = gg.getEulerByPositonY0(pos1, pos2)
    end
end

--玩家位置变化 cmd_player_pos
function MainClient.handlePlayerPos(args_)
    --{ cmd='cmd_player_pos', x=xx, y=yy, z=zz, r=1 }
    if args_.r then
        local actor_ = gg.getClientLocalPlayer()

        actor_.Position = Vector3.new(args_.x, args_.y, args_.z)
        wait(0.1)
        actor_.Position = Vector3.new(args_.x, args_.y, args_.z)
    end
end

--回城
function MainClient.handleChangeWorkSpace(args_)
    gg.log('call handleChangeWorkSpace')
    SceneMgr:SwitchScene(args_.sceneid)   --客户端切场景 【回调】 MainClient.installSceneSwitch
end

--测试消息
function MainClient.handleDebugPlayerInput(args_)
    gg.log('handleDebugPlayerInput:', args_)

    if args_[1] == '/anim2' then
        local p1 = gg.getClientWorkSpace().player1;
        MainClient.debugAnimation(p1)
    elseif args_[1] == '/skin' then
        gg.getClientWorkSpace().player1.ModelId = 'sandboxSysId://entity/' .. args_[2] .. '/body.omod'
    else
        gg.log("empty input debug")
    end
end

--动作测试
function MainClient.debugAnimation(actor_monster)
    -- 所有动作列表
    -- 1=100100(stand) 2=100130(下蹲) 3=100101(walk) 4=100111(run) 5=100105(attack) 6=100112(双手互搓) 7=100109(跳跃) 8=100200 9=100113(骑乘)
    -- 100124(jump die)  100114(eat)  100115(摇头)  100102(sleep)  100106(die)  100107(受击)

    -- 增加碰撞回调函数 ( 只能在客户端执行，可以查看所有动作列表 )
    actor_monster.Touched:connect(function(node, pos1, normal1)
        if node then
            gg.log("touched:", node, node.Name, pos1, normal1)

            local animationIDs = actor_monster:GetAnimationIDs() -- 新动作管理类
            gg.log("animationIDs:", animationIDs)
            gg.print_table(animationIDs, 'GetAnimationIDs')

            local legacy_animation = actor_monster:GetLegacyAnimation()     -- 旧版动作管理类
            if legacy_animation then
                local anim_name_list = legacy_animation:GetAnimationIDs()   -- 动作名字列表
                gg.print_table(animationIDs, 'Legacy1')
                gg.print_table(anim_name_list, 'Legacy2')
            end
        end
    end)
end

--创建G0节点NPC
function MainClient.init_npc(scene_name_)
    local npc_blacksmith = game.WorkSpace.Ground.g0.npc_blacksmith
    npc_blacksmith.CollideGroupID = 2 --可以被玩家碰撞

    local function touch_func(node, pos, normal)
        if node.ClassType == 'Actor' and node.OwnerUin == gg.get_client_uin() then
            UiNpcBlackSmith.show(true)
        end
    end
    npc_blacksmith.Touched:connect(touch_func)
end

--初始化传送门
function MainClient.initTeleport()
    if true then
        --大厅g0到gx的传送门
        local lnitial_point = game.WorkSpace.Ground.g0
        if not lnitial_point then
            lnitial_point = MainStorage.Ground.g0
        end

        for i = 1, 10 do
            local tp_ = lnitial_point['tp' .. i]   --g0.tp1  g0.tp2
            if tp_ then
                -- 传送门特效
                local expl = SandboxNode.new('DefaultEffect', tp_)
                expl.AssetID = common_config.assets_dict.effect.end_table_effect
                expl.LocalPosition = Vector3.new(50, 150, 50);   --位置

                local function touch_func(node, pos, normal)
                    if node.OwnerUin >= 1000 then
                        UiSelectDiff.show(i)
                    end
                end
                tp_.Touched:connect(touch_func)
            else
                break;
            end
        end
    end
end

--同步施法条，玩家地图
function MainClient.update_spell_bar(dt)
    MainClient.spell_remain_time = MainClient.spell_remain_time - dt
    local spell_bar = MainClient.spell_bar                            --进度条ui_image
    if MainClient.spell_rate_now > 0 then
        MainClient.spell_rate_now = MainClient.spell_rate_now - dt * 10 -- 1 tick = 0.1秒

        if MainClient.spell_rate_now < 0 then
            MainClient.spell_rate_now = 0
        end

        spell_bar.FillAmount = 1 - MainClient.spell_rate_now / MainClient.spell_rate_max

        MainClient.spell_remain_time = 0.5 --仍在显示
    end

    --隐藏
    if MainClient.spell_remain_time <= 0 then
        MainClient.spell_bar.Visible = false
        MainClient.spell_bg.Visible  = false
        MainClient.spell_remain_time = 0
    end
end

--开启update
function MainClient.bind_update_render_tick()
    --render定时器
    local runService = game:GetService("RunService")
    runService:BindToRenderStep("update1", Enum.RenderPriority.Camera.Value + 1, MainClient.renderUpdate)
end

local dt_real_cost = 0 --避免帧数过高，性能损耗
--显示更新
function MainClient.renderUpdate(dt)
    dt_real_cost = dt_real_cost + dt
    if dt_real_cost > 0.0333 then  --1/30
        if MainClient.spell_remain_time > 0 then
            MainClient.update_spell_bar(dt_real_cost)
        end
        uiMap.updateMinimap()
        uiSkillSelect.update(dt_real_cost)
        dt_real_cost = 0
    end
end

--注册切换workspace回调
function MainClient.installSceneSwitch()
    --监听切换场景开始通知
    SceneMgr.SceneSwitchStart:Connect(function(optype, sceneid, result, uin)
        gg.log('MainClient SceneSwitchStart:', optype, sceneid, result, uin)
    end)

    --监听场景操作结果通知（客户端）
    SceneMgr.SceneOpResult:Connect(function(optype, sceneid, result, uin)
        gg.log('MainClient SceneOpResult:', optype, sceneid, result, uin)

        --optype: 1(切换)  2(添加)  3(删除)
        --sceneid: 切换后的场景id
        --result:  0成功   其他错误码
        if optype == 2 and result == 0 then     -- 新建场景成功的时候
            --固定场景，没有新建
        elseif optype == 1 and result == 0 then                                          -- 切换场景
            local workspace = game:GetWorkSpace(sceneid)
            gg.network_channel:FireServer({ cmd = "cmd_change_workspace_ok", v = sceneid }) --通知服务器切服成功

            if workspace and sceneid == 0 then
                --回到g0地图中心
                local actor_ = gg.getClientLocalPlayer()
                actor_.Position = Vector3.new(0, 600, 0)
                wait(0.1)
                actor_.Position = Vector3.new(0, 600, 0)
            end
        elseif optype == 3 and result == 0 then -- 删除场景得时候

        end
    end)
end

local CommandHandlers = {}

function CommandHandlers.changeTarget(args)
    -- gg.log("[CMD] Handle change target", args)
    if not gg.client_scene_name == args.scene_name then
        gg.log("[ERROR] Pick obj from other scene:", gg.client_scene_name, args.scene_name)
        return
    end

    local node = gg.findMonsterClientContainer(args.scene_name, args.v)
    if not node then return end

    -- if gg.client_target_node then
    --     gg.client_target_node.CubeBorderEnable = false
    -- end

    gg.client_selected.Parent = node
    gg.client_selected.Visible = true
    gg.client_selected.LocalPosition = Vector3.new(0, 2, 0)
    gg.client_selected.Euler = Vector3.new(0, 0, 0)
    gg.client_target_node = node
    -- node.CubeBorderEnable = true
end

function CommandHandlers.syncTargetInfo(args)
    MainClient.syscTargetInfo(args)
end

function CommandHandlers.handleCdList(args)
    UiCommon.handleCdList(args)
end

function CommandHandlers.showMessage(args)
    UiCommon.ShowMsg(args)
end

function CommandHandlers.playerSpell(args)
    if args.v and args.max and args.max > 0 then
        MainClient.spell_rate_now = args.v
        MainClient.spell_rate_max = args.max
        MainClient.spell_remain_time = 0.5 -- 建议提取为常量
        MainClient.spell_bar.Visible = true
        MainClient.spell_bg.Visible = true
    end
    MainClient.faceTargetNode()
end

function CommandHandlers.playerHpMp(args)
    if args.hp and args.hp_max then
        MainClient.hp_bar.FillAmount = args.hp / args.hp_max
    end
    if args.mp and args.mp_max then
        MainClient.mp_bar.FillAmount = args.mp / args.mp_max
    end
end

function CommandHandlers.syncPlayerSkill(args)
    uiSkillSelect.handleSyncPlayerSkill(args)
end

function CommandHandlers.syncPlaeyerGameTask(args)
    uiGameTask.handleSyncPlayerGameTask(args)
end

function CommandHandlers.syncPlayerItems(args)
    uiBag.handleSyncPlayerItems(args)
end

function CommandHandlers.syncPlayerData(args)
    MainClient.handleSyncPlayerData(args)
end

function CommandHandlers.composeRet(args)
    UiNpcBlackSmith.handleComposeRet(args)
end

function CommandHandlers.heartbeat(args)
    -- 物理类型设置建议增加有效性校验
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            player.Character.PhysXRoleType = Enum.PhysicsRoleType.BOX
        end
    end
end

function CommandHandlers.playerPos(args)
    MainClient.handlePlayerPos(args)
end

function CommandHandlers.changeWorkSpace(args)
    MainClient.handleChangeWorkSpace(args)
end

function CommandHandlers.changeScene(args)
    gg.client_scene_name = args.v
end

function CommandHandlers.aoePos(args)
    Controller.handleAoePos(args)
end

function CommandHandlers.playerInput(args)
    MainClient.handleDebugPlayerInput(args)
end

function CommandHandlers.handleCompleteTask(args)
    MainClient.handleCompleteTask(args)
end

function CommandHandlers.playerActorStat(args)
    if args.v == 'dead' then
        MainClient.enableUserInput(0)
    elseif args.v == 'revive' then
        MainClient.enableUserInput(1)
        -- 复用已有处理方法
        CommandHandlers.playerHpMp(args)
    end
end

function CommandHandlers.syncTaskConfigData(args)
    uiGameTask.handleSyncTaskConfigData(args)
end

--- 同步NPC对话框可见性
function CommandHandlers.handleNpcDialogueVisibility(args)
    if not args.npc_id then return end
    
    -- 查找NPC对象
    local container_npc = gg.clentGetContainerNpc()
    local npc_node = container_npc[args.npc_id]
    if npc_node and npc_node.Task and npc_node.Task.Dialogue then
        -- 只在本地客户端修改可见性
        npc_node.Task.Dialogue.Visible = args.visible
    end
end

-- 命令分发表
local COMMAND_DISPATCH = {
    cmd_change_target = CommandHandlers.changeTarget,
    cmd_sync_target_info = CommandHandlers.syncTargetInfo,
    cmd_cd_list = CommandHandlers.handleCdList,
    cmd_client_show_msg = CommandHandlers.showMessage,
    cmd_player_spell = CommandHandlers.playerSpell,
    cmd_player_hpmp = CommandHandlers.playerHpMp,
    cmd_sync_player_skill = CommandHandlers.syncPlayerSkill,
    cmd_sync_player_game_task = CommandHandlers.syncPlaeyerGameTask,
    cmd_player_items_ret = CommandHandlers.syncPlayerItems,
    cmd_rsync_player_data = CommandHandlers.syncPlayerData,
    cmd_btn_compose_ret = CommandHandlers.composeRet,
    cmd_heartbeat = CommandHandlers.heartbeat,
    cmd_player_pos = CommandHandlers.playerPos,
    cmd_change_workspace = CommandHandlers.changeWorkSpace,
    change_scene_ok = CommandHandlers.changeScene,
    cmd_aoe_pos = CommandHandlers.aoePos,
    cmd_player_input = CommandHandlers.playerInput,
    cmd_player_actor_stat = CommandHandlers.playerActorStat,
    cmd_npc_dialogue_visibility = CommandHandlers.handleNpcDialogueVisibility
    -- cmd_sync_task_config_data = CommandHandlers.syncTaskConfigData,
}
function MainClient.OnClientNotify(args)
    -- 参数校验
    -- gg.log("参数说明",args)

    if type(args) ~= 'table' then return end
    if not args.cmd then return end
    -- 获取处理器
    local handler = COMMAND_DISPATCH[args.cmd]
    if not handler then
        gg.log("[WARN] Unhandled command:", args.cmd)
        return
    end

    -- 执行处理
    local success, err = pcall(handler, args)
    if not success then
        gg.log("[ERROR] Command handler failed:", args.cmd, err)
    end
end

return MainClient;
