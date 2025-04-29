--- V109 miniw-haima
--- 通用玩家UI

local game = game
local script = script
local print = print
local math  = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs

local Vector2 = Vector2
local Vector3 = Vector3
local ColorQuad = ColorQuad
local TweenInfo = TweenInfo

local MainStorage = game:GetService("MainStorage")
local gg                 = require(MainStorage.code.common.MGlobal)            ---@type gg
local common_config      = require(MainStorage.code.common.MConfig)            ---@type common_config
local uiSkillSelect      = require(MainStorage.code.client.ui.UiSkillSelect)   ---@type UiSkillSelect
local uiBag              = require(MainStorage.code.client.ui.UiBag)           ---@type UiBag
local UiRoleMsg          = require(MainStorage.code.client.ui.UiRoleMsg)       ---@type UiRoleMsg
local uiMap              = require(MainStorage.code.client.ui.UiMap)           ---@type UiMap
local uiGameTask         = require(MainStorage.code.client.ui.UiTask.UiTaskMain)  ---@type UiGameTask

local TweenService 		 = game:GetService('TweenService')
local RunService         = game:GetService("RunService")

-- 按钮配置
local BUTTON_CONFIG = {
    JUMP = {
        size = Vector2.New(117, 119),
        offsetX = 110,
        offsetY = 100,
        icon = common_config.assets_dict.btn_jump
    },
    SKILL = {
        bigSize = Vector2.New(90, 90),
        smallSize = Vector2.New(80, 80),
        icon = common_config.assets_dict.btn_empty_frame
    }
}

-- GCD配置
local SKILL_GCD_TIME = 500 -- 0.5秒

---@class UiCommon
local UiCommon = {
    input = nil,
    skill_btn_gcd = {},    --按钮gcd
};

-- 创建按钮的工具函数
local function createButton(parent, name, icon, size, position, onClick)
    local button = SandboxNode.New('UIButton', parent)
    button.Name = name
    button.Icon = icon
    gg.formatButton(button)
    button.Size = size
    button.Position = position
    
    if onClick then
        button.Click:Connect(onClick)
    end
    
    return button
end

--战斗界面按钮
function UiCommon.init_battle_btn()
    local ui_root = gg.create_ui_root()
    local ui_size = gg.get_ui_size()
    gg.log('ui_size= ', ui_size)

    -- 跳跃按钮
    createButton(
        ui_root, 
        'btn_jump', 
        BUTTON_CONFIG.JUMP.icon, 
        BUTTON_CONFIG.JUMP.size, 
        Vector2.New(ui_size.x - BUTTON_CONFIG.JUMP.offsetX, ui_size.y - BUTTON_CONFIG.JUMP.offsetY),
        function()
            local player = gg.getClientLocalPlayer()
            player:Jump(true)
            wait(0.02)
            player:Jump(false)
        end
    )

    -- 物理攻击和技能按钮
    for i = 1, 6 do
        local size, position
        
        if i <= 2 then
            size = BUTTON_CONFIG.SKILL.bigSize
            position = Vector2.New(ui_size.x - 110 * i, ui_size.y - 220)
        else
            size = BUTTON_CONFIG.SKILL.smallSize
            position = Vector2.New(ui_size.x - 100 * (i - 1) - 30, ui_size.y - 100)
        end
        
        createButton(ui_root, 'btn_skill_' .. i,BUTTON_CONFIG.SKILL.icon,size,position,
            function()
                if uiSkillSelect.dict_btn_skill[i] and uiSkillSelect.dict_btn_skill[i] >= 1000 then
                    UiCommon.check_client_skill_btn_cd(i)     --点击技能
                else
                    uiSkillSelect.show()                --打开技能面板
                end
            end
        )
    end

    -- 请求玩家的技能数据
    gg.network_channel:FireServer({cmd = 'cmd_player_skill_req'})
end

function UiCommon.init_game_task_map()
    uiGameTask.init_map()
    gg.network_channel:FireServer({cmd = 'cmd_client_game_task_data',})

end
-- 界面按钮绑定初始化
function UiCommon.init_skill_select_ui_btn()
    gg.log("技能，背包，地图，选择面板",uiGameTask)
    local ui_root_spell = gg.get_ui_root_spell()
    
    -- 定义按钮配置
    local buttonConfigs = {
        {button = ui_root_spell.btn_skill_select,action = uiSkillSelect.show},
        {button = ui_root_spell.ui_bottom.bg.btn_bag,action = uiBag.show},
        {button = ui_root_spell.header,action = UiRoleMsg.show},
        {button = ui_root_spell.ui_map.MaskUIImage,action = uiMap.show},
        {button = ui_root_spell.world_map.close,action = uiMap.close},
        {button = ui_root_spell.ui_top.bg.game_task,action = uiGameTask.show}}
    
    -- 批量绑定按钮事件
    for _, config in ipairs(buttonConfigs) do
        config.button.Click:Connect(config.action)
    end
end

--玩家输入框
function UiCommon.openTextInput(visible_)
    if not UiCommon.input then
        --create
        local ui_size = gg.get_ui_size()
        local ui_root = gg.create_ui_root()

        -- 输入框
        ---@class UITextInput
        local inputer = SandboxNode.New('UITextInput', ui_root)
        inputer.Name = "cmd_input"
        inputer.Size = Vector2.New(180, 60)
        inputer.Position = Vector2.New(ui_size.x * 0.75 - 90, ui_size.y * 0.25 - 30)
        inputer.Visible = true
        inputer.FillColor = ColorQuad.New(97, 151, 230, 255)
        inputer.TextVAlignment = Enum.TextVAlignment.Center
        inputer.TextHAlignment = Enum.TextHAlignment.Center
        inputer.Title = "/test"
        inputer.MaxLength = 32
        inputer.FontSize = 18

        UiCommon.input = inputer;

        -- 按钮
        local tmp_button = SandboxNode.New('UIButton', inputer)
        tmp_button.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
        tmp_button.Name = 'cmd_input_ok'
        tmp_button.Title = 'debug'
        tmp_button.Icon = common_config.assets_dict.btn_press1
        tmp_button.FillColor = ColorQuad.new(0, 0, 0, 0)
        tmp_button.DownEffect = Enum.DownEffect.ColorEffect
        tmp_button.LayoutHRelation = Enum.LayoutHRelation.Right
        tmp_button.LayoutVRelation = Enum.LayoutVRelation.Bottom
        tmp_button.Size = Vector2.New(100, 50)
        tmp_button.Position = Vector2.New(230, 28)

        tmp_button.Click:Connect(function()
            local text_ = UiCommon.input.Title;
            if #text_ > 0 then
                gg.log('FireServer:', text_);
                gg.network_channel:FireServer({cmd = 'cmd_player_input', v = text_})
                UiCommon.input.Visible = false
            end
        end)
    end

    UiCommon.input.Visible = visible_
end

--客户端 skill_btn_gcd 按钮gcd
function UiCommon.check_client_skill_btn_cd(skill_id_)
    local cd_list_ = UiCommon.skill_btn_gcd
    cd_list_[skill_id_] = cd_list_[skill_id_] or 0

    local now_ = RunService:CurrentMilliSecondTimeStamp()
    if now_ - cd_list_[skill_id_] > SKILL_GCD_TIME then
        cd_list_[skill_id_] = now_
        gg.network_channel:FireServer({cmd = 'cmd_btn_press', v = skill_id_})
    end
end

--同步玩家的技能cd情况
function UiCommon.handleCdList(args1_)
    gg.log('handleCdList====', args1_)
    
    for skill_id_, info_ in pairs(args1_.v) do
        local skill_config_ = common_config.skill_def[skill_id_]
        local cd_max_ = skill_config_.cd

        if cd_max_ and cd_max_ > 0 then
            local cd_left_ = math.max(0, cd_max_ - (args1_.tick - info_.last))
            gg.log('handleCdList==', skill_id_, '==', cd_left_, ' / ', cd_max_)
            
            -- 更新技能图片cd
            local skill_cd = uiSkillSelect.dict_skill_cd[skill_id_]
            if skill_cd then
                skill_cd.cd_left = cd_left_
                skill_cd.cd_max = cd_max_
                skill_cd.FillAmount = cd_left_ / cd_max_
            end
        end
    end
end

-- TweenService 飘字
-- 参数 pps
--  txt   = 内容
--  t     = 展示时间秒
--  color = 颜色
--  FontSize  = 文字大小
function UiCommon.ShowMsg(pps_)
    local ui_root = gg.create_ui_root()
    local ui_size = gg.get_ui_size()

    local txt_msg_ = gg.createTextLabel(ui_root, pps_.txt)
    txt_msg_.Name = 'msg'
    txt_msg_.RenderIndex = 9999
    
    if pps_.color then
        txt_msg_.TitleColor = pps_.color
    end

    txt_msg_.FontSize = pps_.FontSize or 32
    txt_msg_.ShadowEnable = true
    txt_msg_.ShadowOffset = Vector2.new(2, 2)
    txt_msg_.ShadowColor = ColorQuad.new(0, 0, 0, 255)
    txt_msg_.Position = Vector2.new(ui_size.x * 0.5, ui_size.y * 0.4)

    local duration = pps_.t or 2
    local txt_msg_weenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, nil, 0, 0)
    
    local goal = {
        Position = Vector2.new(ui_size.x * 0.5, ui_size.y * 0.3)
    }
    
    local tween = TweenService:Create(txt_msg_, txt_msg_weenInfo, goal)
    tween:Play()

    -- 监听动画完成事件
    tween.Completed:Connect(function()
        txt_msg_.Visible = false
        txt_msg_:Destroy()
    end)
end

return UiCommon