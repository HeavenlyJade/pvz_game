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


---@class UiSelectDiff
local  UiSelectDiff = {
    bg = nil,

    ground_type = 1,

};



--显示或者隐藏界面  1=10 11 12 13   2=20 21 22 23  3=30 31 32 33
function UiSelectDiff.show( i )
    if  UiSelectDiff.bg == nil then
        UiSelectDiff.create()
    end

    if  i then
        UiSelectDiff.ground_type = i   --第几种大陆
    end

    UiSelectDiff.bg.Visible = not UiSelectDiff.bg.Visible     --true <-> false

    if  UiSelectDiff.bg.Visible then
        UiSelectDiff.update_button()
    end

end




--建立界面
function UiSelectDiff.create()
    local ui_size = gg.get_ui_size()
    local ui_root = gg.create_ui_root()


    --界面大背景
    local bg_ = gg.createImage( ui_root, common_config.assets_dict.skill_bg )
    bg_.Name = "diff_bg"
    bg_.Visible = false   --hide first
    bg_.Size     = Vector2.New( ui_size.x*0.6, ui_size.y*0.8 )
    bg_.Position = Vector2.New( ui_size.x*0.5, ui_size.y*0.5 )
    UiSelectDiff.bg = bg_


    --文字描述
    local text_ = gg.createTextLabel( bg_, '世界传送点' )
    text_.Name       = 'diff_comment'
    text_.TitleColor = ColorQuad.New( 255, 128, 0, 255 )
    text_.FontSize   = 28
    text_.Position   = Vector2.New( ui_size.x*0.3, ui_size.y*0.1 )


    --四个难度按钮
    for i=1, 4 do
        local tmp_button = SandboxNode.New('UIButton', bg_ )
        tmp_button.Name  = 'btn_diff' .. i
        tmp_button.Icon  =  common_config.assets_dict.btn_press3
        gg.formatButton( tmp_button )
        tmp_button.Title     = gg.getDiffString(i)
        tmp_button.TitleSize = 24
        local color_ = i*64 - 1
        tmp_button.IconColor = ColorQuad.New( color_, 255-color_ , 0, 255 )
        tmp_button.Size     = Vector2.New( ui_size.x*0.2,   ui_size.x*0.04 )
        tmp_button.Position = Vector2.New( ui_size.x*0.3,   ui_size.y*0.1 + ui_size.y*0.13 * i )

        tmp_button.Click:Connect(function()
            local name_ = 'g' .. UiSelectDiff.ground_type*10+i-1    --g0 g1 g2   g10 g11 g12
            gg.log( "press cmd_change_map", name_ )
            gg.network_channel:FireServer( { cmd='cmd_change_map', v=name_  } )   --点击切换地图
            UiSelectDiff.bg.Visible = false
        end)
    end


    --关闭按钮
    if  true then
        local tmp_button = SandboxNode.New('UIButton', bg_ )
        tmp_button.Name  = 'btn_close'
        tmp_button.Icon  =  common_config.assets_dict.btn_close   --空技能框
        gg.formatButton( tmp_button )
        tmp_button.Size     = Vector2.New( ui_size.x*0.06, ui_size.x*0.06 )
        tmp_button.Position = Vector2.New( ui_size.x*0.55,  ui_size.y*0.09 )

        tmp_button.Click:Connect(function()
            UiSelectDiff.show()
        end)
    end


end



--更新按钮描述字
function UiSelectDiff.update_button()
    for i=1, 4 do
        local name_ = 'g' .. UiSelectDiff.ground_type*10+i-1    --g0 g1 g2   g10 g11 g12
        UiSelectDiff.bg[ 'btn_diff' .. i ].Title = gg.getDiffString(i)  .. ' ' .. common_config.scene_config.getLevelStr( name_ )
    end
end





return UiSelectDiff;