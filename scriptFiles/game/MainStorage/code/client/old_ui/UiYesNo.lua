
-- 多功能通用模板
-- 1=确定取消， 2=输入， 3=选择

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
local gg                = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)    ---@type common_const


---@class UiYesNo
local UiYesNo = {
    pps = nil,

    ui_common   = nil,             --顶层窗口
    callback    = nil,             --回调函数
    select_btn  = 1,               --bgselect2选择的值
}


local Players   = game:GetService('Players')


function UiYesNo.Init()

    UiYesNo.ui_common = Players.LocalPlayer.PlayerGui.ui_root.ui_common      --主窗口
    gg.log("UiYesNo.ui_common",UiYesNo.ui_common)

    UiYesNo.ui_common.bg.Visible = false

    --确定
    UiYesNo.ui_common.bg.btn_yes.Click:Connect(function (node,issuccess,mousepos)
        UiYesNo.ui_common.bg.Visible = false

        if  UiYesNo.callback then
            if  UiYesNo.pps.type == 1 then
                --纯文字确认界面
                UiYesNo.callback(true)
            elseif UiYesNo.pps.type == 2 then
                --input类型
            elseif UiYesNo.pps.type == 3 then
                --2选1
            else

            end
        end
    end)


    --取消
    UiYesNo.ui_common.bg.btn_no.Click:Connect(function (node,issuccess,mousepos)
        UiYesNo.ui_common.bg.Visible = false
        if  UiYesNo.callback then
            UiYesNo.callback(false)
        end
    end)

end



--带回调函数的ui
function UiYesNo.showPage( pps_, callback_ )
    if  not UiYesNo.pps then
        UiYesNo.Init()
    end
       -- 确保UI组件存在
    UiYesNo.pps  = pps_
    local ui_common = UiYesNo.ui_common
    ui_common.bg.Visible = true
    ui_common.bg.title.txt.Title = pps_.title
    if  pps_.type == 1 then
        --纯文字界面
        ui_common.bg.content.Title = pps_.content
    elseif pps_.type == 2 then
        --input类型
    elseif pps_.type == 3 then
        --2选1
    else

    end
    ui_common.bg.Visible = true
    UiYesNo.callback = callback_
end




--选择值变化
function UiYesNo.bgSelect2ColorChange()

    local ui_common = UiYesNo.ui_common

    if  UiYesNo.select_btn == 1 then
        ui_common.bg.bgSelect2.btn1.FillColor = ColorQuad.New(0, 136, 204, 255)
        ui_common.bg.bgSelect2.btn2.FillColor = ColorQuad.New(0, 0, 0, 64)
    else
        ui_common.bg.bgSelect2.btn2.FillColor = ColorQuad.New(0, 136, 204, 255)
        ui_common.bg.bgSelect2.btn1.FillColor = ColorQuad.New(0, 0, 0, 64)
    end

end


return UiYesNo
