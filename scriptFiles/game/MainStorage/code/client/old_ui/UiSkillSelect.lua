--- V109 miniw-haima
--- 玩家UI技能选择ui

local game = game
local script = script
local print = print
local math  = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs
local Vector2 = Vector2
local ColorQuad = ColorQuad

local MainStorage = game:GetService("MainStorage")
local gg                 = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config      = require(MainStorage.code.common.MConfig)   ---@type common_config

local Players            = game:GetService('Players')



---@class UiSkillSelect
local  UiSkillSelect = {
    bg = nil,

    btn_list = {},              --当前技能按钮列表

    dict_btn_skill = nil,       --当前玩家的实际技能数据  [ btn_id = skill_id ]

    selector_btn_id = 6,         --当前技能框位置
    btn_pointer     = nil,       --选定后的提示框

    dict_skill_cd = {},         --技能id到cd图片
};



--服务器下发本玩家的技能数据
function UiSkillSelect.handleSyncPlayerSkill( args1_ )
    gg.log( '玩家当前的仅能数据', args1_ )
    if  args1_.skill then
        UiSkillSelect.dict_btn_skill = args1_.skill

        UiSkillSelect.dict_skill_cd = {}   --清空


        --更新技能图标        --{ 1=1002 2=2004 3=2005 4=2006 }
        for i=1, 6 do
            local skill_id_ = UiSkillSelect.dict_btn_skill[i]
            if  skill_id_ and skill_id_ >= 1000 then
                local icon_ = common_config.skill_def[ skill_id_ ].icon
                if  icon_ then
                    local btn_ = Players.LocalPlayer.PlayerGui.ui_root[ 'btn_skill_' .. i ]    --技能按钮
                    if  btn_ then
                        btn_.Icon = icon_
                    end

                    if  UiSkillSelect.btn_list[i] then
                        UiSkillSelect.btn_list[i].Icon = icon_
                    end


                    --cd 创建冷却背景
                    local cd_mask_ = gg.createImage( btn_, common_config.assets_dict.skill_cd_mask )
                    cd_mask_.FillColor = ColorQuad.new( 255, 255, 0, 128 )
                    cd_mask_.Name     = 'cd_mask'

                    cd_mask_.Size     = Vector2.new( btn_.Size.x-2, btn_.Size.y-2)
                    cd_mask_.Position = Vector2.new(1, 1)
                    cd_mask_.Pivot    = Vector2.new(0, 0)
                    cd_mask_.Active   = false
                    --cd_mask_.FillMethod = Enum.FillMethod.Radial360
                    cd_mask_.FillMethod = Enum.FillMethod.Vertical
                    cd_mask_.FillOrigin = Enum.FillOrigin.Bottom
                    cd_mask_.FillAmount = 0

                    UiSkillSelect.dict_skill_cd[ skill_id_ ] = { cd_img=cd_mask_, cd_left=0, cd_max=1 }


                    --cd_mask_.Size     = tmp_button.Size
                    --cd_mask_.Position = tmp_button.Position
                end

            else
                --清理图标
                if  UiSkillSelect.btn_list[i] then
                    UiSkillSelect.btn_list[i].Icon = common_config.assets_dict.btn_empty_frame
                end

                local btn_ = Players.LocalPlayer.PlayerGui.ui_root[ 'btn_skill_' .. i ]    --技能按钮
                if  btn_ then
                    btn_.Icon = common_config.assets_dict.btn_empty_frame
                    if  btn_.cd_mask then
                        btn_.cd_mask:Destroy()
                    end
                end

            end

        end

    end
end


--显示或者隐藏界面
function UiSkillSelect.show()
    if  UiSkillSelect.bg == nil then
        UiSkillSelect.create()
    end

    if  UiSkillSelect.dict_btn_skill == nil then
        gg.network_channel:FireServer( { cmd='cmd_player_skill_req' } )
    end

    UiSkillSelect.bg.Visible =  not UiSkillSelect.bg.Visible     --true <-> false

end



-- 创建技能界面
function UiSkillSelect.create()
    local ui_size = gg.get_ui_size()
    local ui_root = gg.create_ui_root()

    local bg_ = SandboxNode.new("UIImage", ui_root )
    bg_.RenderIndex = 2

    bg_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    bg_.Name = "skill_select_bg"
    bg_.Visible = false   --hide first

    bg_.Size  = Vector2.New(ui_size.x*0.9, ui_size.y*0.78)
    bg_.Icon  = common_config.assets_dict.skill_bg

    --bg_.Pivot = Vector2.new(0.5, 0.5)
    bg_.Position = Vector2.new( ui_size.x*0.5, ui_size.y*0.45 )
    UiSkillSelect.bg = bg_

    ----- 技能框 右下两排
    for i=1, 6 do
        local tmp_button = SandboxNode.New('UIButton', bg_ )
        tmp_button.Name  = 'btn_skill_' .. i
        tmp_button.Icon  =  common_config.assets_dict.btn_empty_frame   --空框
        gg.formatButton( tmp_button )
        --tmp_button.Pivot = Vector2.new(0.5, 0.5)

        if  i <= 2 then
            tmp_button.Size = Vector2.New( 80, 80 )
            tmp_button.Position =  Vector2.New( ui_size.x*0.9-110*i,         ui_size.y*0.78-240)
        else
            tmp_button.Size = Vector2.New( 70, 70 )
            tmp_button.Position =  Vector2.New( ui_size.x*0.9-100*(i-1)-30,  ui_size.y*0.78-120)
        end


        tmp_button.Click:Connect(function()
            UiSkillSelect.selector_btn_id = i
            UiSkillSelect.btn_pointer.Parent   = tmp_button
            UiSkillSelect.btn_pointer.Size     = Vector2.new( tmp_button.Size.x+10, tmp_button.Size.y+10 )
            UiSkillSelect.btn_pointer.Position = Vector2.new(-5, -5)
        end)

        UiSkillSelect.btn_list[ i ] = tmp_button
    end

    --更新技能图标
    for i=1, 6 do
        local skill_id_ = UiSkillSelect.dict_btn_skill[i]
        if  skill_id_ and skill_id_ >= 1000 then
            local icon_ = common_config.skill_def[ skill_id_ ].icon
            if  icon_ then
                if  UiSkillSelect.btn_list[i] then
                    UiSkillSelect.btn_list[i].Icon = icon_
                end
            end
        end
    end
    ------ 可选技能列表 左边N排
    local xx, yy = 0, 0
    for skill_id_, skill_data in pairs(common_config.skill_def) do
        local tmp_button = SandboxNode.New('UIButton', bg_)
        tmp_button.Name = 'btn_skill_option_' .. skill_id_
        tmp_button.Icon = skill_data.icon  -- 直接使用 skill_data 而不是重复查找
        gg.formatButton(tmp_button)
        
        xx = xx + 1
        if xx > 4 then
            yy = yy + 1
            xx = 1
        end
        
        tmp_button.Size = Vector2.New(72, 72)
        tmp_button.Position = Vector2.New(ui_size.x * 0.01 + xx * 100, ui_size.y * 0.17 + yy * 120)
        
        tmp_button.Click:Connect(function()
            if skill_id_ and common_config.skill_def[skill_id_] then
                bg_.skill_desc.Title = skill_data.desc  -- 使用 skill_data
            end
            gg.network_channel:FireServer({
                cmd = 'cmd_select_skill',
                btn = UiSkillSelect.selector_btn_id,
                skill_id = skill_id_
            })
        end)
        
        -- 增加文字描述
        local skill_name_ = gg.createTextLabel(tmp_button, skill_data.name)  -- 使用 skill_data
        skill_name_.FontSize = 22
        skill_name_.Size = Vector2.new(100, 30)
        skill_name_.Position = Vector2.new(36, 90)
        skill_name_.TitleColor = ColorQuad.new(0, 0, 255, 255)
    end

    --技能提示
    local  skill_tip_ = gg.createTextLabel( bg_, '点选技能进行设置：' )
    skill_tip_.Name   = 'skill_tip'
    skill_tip_.FontSize   = 20
    skill_tip_.Size       = Vector2.new( ui_size.x*0.4, 30 )
    skill_tip_.Pivot      = Vector2.new( 0, 0 )
    skill_tip_.Position   = Vector2.new( ui_size.x*0.05, ui_size.y*0.05 )
    skill_tip_.TitleColor = ColorQuad.new( 0, 0, 255, 255 )
    skill_tip_.TextHAlignment = Enum.TextHAlignment.Left   --Left Right


    --技能描述
    local  skill_desc_ = gg.createTextLabel( bg_, '' )
    skill_desc_.Name   = 'skill_desc'
    skill_desc_.FontSize   = 20
    skill_desc_.Size       = Vector2.new( ui_size.x*0.25, 70 )
    skill_desc_.Position   = Vector2.new( ui_size.x*0.65, ui_size.y*0.15 )
    skill_desc_.TitleColor = ColorQuad.new( 0, 0, 255, 255 )
    skill_tip_.Pivot       = Vector2.new( 0, 0 )
    skill_desc_.TextVAlignment = Enum.TextVAlignment.Top    --Top  Bottom
    skill_desc_.TextHAlignment = Enum.TextHAlignment.Left   --Left Right


    if  true then
        local  bt_size_ = UiSkillSelect.btn_list[ UiSkillSelect.selector_btn_id ].Size
        local image_ = gg.createImage( UiSkillSelect.btn_list[ UiSkillSelect.selector_btn_id ], common_config.assets_dict.icon_point_frame2 )
        image_.Name      = 'btn_pointer'
        image_.Active    = false   --不能点击
        image_.ClickPass = true
        image_.Pivot    = Vector2.new(0, 0)
        image_.Position = Vector2.new(-5, -5)
        image_.Size     = Vector2.new(bt_size_.x+10, bt_size_.y+10)
        image_.RenderIndex = 2
        image_.FillColor   = ColorQuad.new( 0, 255, 0, 255 )
        UiSkillSelect.btn_pointer = image_

    end


    --关闭按钮
    if  true then
        local tmp_button = SandboxNode.New('UIButton', bg_ )
        tmp_button.Name  = 'btn_close'
        tmp_button.Icon  =  common_config.assets_dict.btn_close   --空技能框
        gg.formatButton( tmp_button )

        tmp_button.Size     = Vector2.New( ui_size.x*0.06, ui_size.x*0.06 )
        tmp_button.Position = Vector2.New( ui_size.x*0.85, ui_size.y*0.09 )

        tmp_button.Click:Connect(function()
            UiSkillSelect.show()
        end)
    end

end



--更新施法进度条
function UiSkillSelect.update(dt)
    if  next( UiSkillSelect.dict_skill_cd ) then
        for _, info_ in pairs( UiSkillSelect.dict_skill_cd ) do
            if  info_.cd_left > 0 then
                info_.cd_left = info_.cd_left - dt*10    -- 一帧=0.1秒
                if  info_.cd_left < 0 then info_.cd_left = 0 end
                info_.cd_img.FillAmount = info_.cd_left / info_.cd_max
            end
        end
    end
end



return UiSkillSelect;