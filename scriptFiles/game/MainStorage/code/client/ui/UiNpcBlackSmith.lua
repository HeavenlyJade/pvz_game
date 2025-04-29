
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
local common_const       = require(MainStorage.code.common.MConst)    ---@type common_const

local UiYesNo            = require(MainStorage.code.client.ui.UiYesNo)    ---@type UiYesNo


---@class UiNpcBlackSmith
local  UiNpcBlackSmith = {
    bg = nil,
    txt_num  = nil,
    txt_info = nil,
    update_timer = nil,
};



--显示或者隐藏界面
function UiNpcBlackSmith.show( flag_ )
    if  UiNpcBlackSmith.bg == nil then
        UiNpcBlackSmith.create()
    end

    if  UiNpcBlackSmith.bg.Visible ~= flag_ then
        --状态有切换
        UiNpcBlackSmith.bg.Visible = flag_
        if  UiNpcBlackSmith.bg.Visible then
            UiNpcBlackSmith.bg.timer_ui:Start()
        else
            UiNpcBlackSmith.bg.timer_ui:Stop()
        end
    end

    UiNpcBlackSmith.txt_info.Title = ""
    UiNpcBlackSmith.updateMatNum()
end



function UiNpcBlackSmith.createTimer()
    --开启update
	-- 一个定时器,  实现tick update
	local timer = SandboxNode.New( "Timer", UiNpcBlackSmith.bg )
	timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE

	timer.Name = 'timer_ui'
	timer.Delay = 0        -- 延迟多少秒开始
	timer.Loop = true      -- 是否循环
	timer.Interval = 0.5   -- 循环间隔多少秒   (1秒=10帧)
	timer.Callback = UiNpcBlackSmith.update

	--timer:Start()     -- 启动定时器
    --timer:Pause()     -- 立即暂停

end




--刷新材料数量
function UiNpcBlackSmith.updateMatNum()
    if  UiNpcBlackSmith.bg.Visible then
        --update 数量
        local num_ = gg.getClientBagMatNum( common_const.MAT_ID.FRAGMENT , 1 )  --魔力碎片
        UiNpcBlackSmith.txt_num.Title = '' .. num_

        --提示
        if  gg.ifClientBagFull() then
            UiNpcBlackSmith.txt_info.Title = "背包已满"
        end


        --宝箱和低级别装备数量
        local box_num_, low_eq_num_ = 0, 0

        for bag_id_, v in pairs( gg.client_bag_index ) do
            --gg.log(  "bag_index=",  bag_id_, v )
            if  bag_id_ >= 10000 then
                if  v.uuid then
                    local item_ = gg.client_bag_items[ v.uuid ]
                    --gg.log(  "item=",  item_ )
                    if  item_ then
                        if  item_.itype == common_const.ITEM_TYPE.BOX then
                            gg.log(  "item box=", bag_id_, v, item_ )
                            box_num_ = box_num_ + 1
                        elseif item_.itype == common_const.ITEM_TYPE.EQUIPMENT and item_.quality < 4 then
                            gg.log(  "item low eq=", bag_id_, v, item_ )
                            low_eq_num_ = low_eq_num_ + 1
                        end
                    end
                end
            end
        end

        gg.log( 'updateMatNum:', box_num_, low_eq_num_ )

        UiNpcBlackSmith.bg.btn_use_all_box.txt.Title   = '一共' .. box_num_ .. '个'
        UiNpcBlackSmith.bg.btn_dp_all_low_eq.txt.Title = '分解背包里所有传奇及以下级别装备，一共' .. low_eq_num_ .. '件'

    end


end

--建立界面
function UiNpcBlackSmith.create()

    local ui_root       = gg.create_ui_root()
    print("ui_root.ui_blacksmith.bg",ui_root.ui_blacksmith.bg)
    UiNpcBlackSmith.bg  = ui_root.ui_blacksmith.bg

    UiNpcBlackSmith.txt_num  = UiNpcBlackSmith.bg.img.txt_num
    UiNpcBlackSmith.txt_info = UiNpcBlackSmith.bg.txt_info


    --合成箱子按钮
    if  true then
        UiNpcBlackSmith.bg.btn_box.Click:Connect(function()
            gg.log( "press btn_compose" )
            local num_ = gg.getClientBagMatNum( common_const.MAT_ID.FRAGMENT , 1 )  --魔力碎片
            if  num_ < 800 then
                UiNpcBlackSmith.txt_info.Title = "魔力碎片的数量不够"
            else
                gg.network_channel:FireServer( { cmd='cmd_btn_compose', v=1 } )   --点击
            end
        end)
    end


    --打开所有宝箱按钮
    if  true then
        UiNpcBlackSmith.bg.btn_use_all_box.Click:Connect(function()
            gg.network_channel:FireServer( { cmd='cmd_use_all_box' } )   --点击打开所有箱子
        end)
    end


    --分解所有低等装备按钮
    if  true then
        UiNpcBlackSmith.bg.btn_dp_all_low_eq.Click:Connect(function()
            UiYesNo.showPage(
                { type=1, title='分解低等装备', content='当前背包里所有【传奇及以下级别】装备都将被分解' },
                function ( ret )
                    if ret then
                        gg.network_channel:FireServer( { cmd='cmd_dp_all_low_eq'  } )   --点击分解所有低级装备
                    end
                end
            )
        end)

    end



    --关闭按钮
    if  true then
        UiNpcBlackSmith.bg.btn_close.Click:Connect(function()
            UiNpcBlackSmith.show( false )
        end)
    end

    UiNpcBlackSmith.createTimer()   --挂载update
end



--合成的回调
function UiNpcBlackSmith.handleComposeRet( args1_ )
    if     args1_.msg == "full" then
        UiNpcBlackSmith.txt_info.Title = "背包已满"
    elseif args1_.msg == "no_enough" then
        UiNpcBlackSmith.txt_info.Title = "没有足够的魔力碎片"
    elseif args1_.msg == "ok" then
        UiNpcBlackSmith.txt_info.Title      = "你获得了: " .. args1_.name
        UiNpcBlackSmith.txt_info.TitleColor = gg.getQualityColor( args1_.quality )
    else

    end

    if  args1_.num then
        UiNpcBlackSmith.txt_num.Title = '' .. args1_.num
    end

end


--更新ui
function UiNpcBlackSmith.update()
    --gg.log( "UiNpcBlackSmith.update" )
    --判断距离，太远就自动关闭
    local pos1_ = gg.getClientLocalPlayer().Position
    local pos2_ = game.WorkSpace.Ground.g0.npc_blacksmith.Position
    if  gg.fast_out_distance( pos1_, pos2_, 500 ) then
        UiNpcBlackSmith.show(false)
    end

end


return UiNpcBlackSmith;