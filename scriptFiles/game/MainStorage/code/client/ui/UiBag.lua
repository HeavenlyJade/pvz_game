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
local gg                = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)    ---@type common_const

local UiYesNo           = require(MainStorage.code.client.ui.UiYesNo)    ---@type UiYesNo



---@class UiBag
local  UiBag = {
    bg = nil,

    dict_btn_bag = {
        --[ 1000,  2000] = 身上装备【固定位置】
                [ 1001 ] = {},   --武器
                [ 1002 ] = {},   --盾牌
                [ 1003 ] = {},   --头盔
                [ 1004 ] = {},   --衣服
                [ 1005 ] = {},   --裤子
                [ 1006 ] = {},   --披风
                [ 1007 ] = {},   --鞋子
                [ 1008 ] = {},   --饰品

        --[10000, 11000] = 背包
    },

    --selector_bag_index = 0,    --1001  10000 当前选定的背包格子id
    last_bag_index     = 0,    --最后选定的一个背包格子id

    btn_use       = nil,
    btn_decompose = nil,

    eqp_pointer = nil,    --装备位置指示
    bag_pointer = nil,    --背包选定位

    desc_item_label = nil,     --物品描述信息
    desc_item_eq    = nil,     --当前已装备物品

    desc_dmg_def    = nil,     --攻防描述
}



function UiBag.show()
    if  UiBag.bg == nil then
        UiBag.create()
    end
    local ui_root = gg.create_ui_root()
    -- 切换父节点ui_bag的可见性
    ui_root.ui_bag.Visible = not ui_root.ui_bag.Visible
    -- 若需要首次打开时请求数据，可保留此逻辑
    if ui_root.ui_bag.Visible then
        UiBag.req_bag_data()
    end
end

--请求玩家包裹数据
function UiBag.req_bag_data()
    gg.network_channel:FireServer( { cmd='cmd_player_items_req', bag_ver=gg.client_bag_ver } )
end



--初始化
function UiBag.init()
    local ui_root = gg.create_ui_root()
    ui_root.ui_bag.Visible = false
end


--获得一件装备的描述文字
function UiBag.getBagItemInfoStr(info)
    if not info.uuid then return "" end
    
    local parts = {}
    
    -- 添加基本信息
    table.insert(parts, UiBag.getQualityStr(info.quality) .. ' 等级' .. info.level .. '\n' .. (info.name or '') .. '\n\n')
    
    -- 添加攻击信息
    if info.attack then
        table.insert(parts, '攻击:' .. info.attack .. ' - ' .. info.attack2 .. '\n')
    end
    
    -- 添加法术信息
    if info.spell then
        table.insert(parts, '法强:' .. info.spell .. ' - ' .. info.spell2 .. '\n')
    end
    
    -- 添加防御信息
    if info.defence then
        table.insert(parts, '防御:' .. info.defence .. ' - ' .. info.defence2 .. '\n')
    end
    
    -- 添加属性信息
    if info.attrs then
        for _, attr in pairs(info.attrs) do
            table.insert(parts, UiBag.getAttrStr(attr))
        end
    end
    
    -- 材料特殊描述
    if info.itype == common_const.ITEM_TYPE.MAT then
        table.insert(parts, '数量:' .. info.num .. '\n地图大厅铁匠NPC\n合成和强化装备的材料')
    end
    
    return table.concat(parts)
end




--显示信息
function UiBag.showItemInfo( bag_id_ )
    local index_ = gg.client_bag_index[ bag_id_ ]


    if  bag_id_ == 0 and UiBag.btn_decompose then
        UiBag.btn_decompose.Visible = false
        UiBag.btn_use.Visible       = false

        --调整绿色和黄色选定框
        UiBag.bag_pointer.Visible = false
        UiBag.eqp_pointer.Visible = false

        UiBag.desc_item_eq.Visible = false
        print("UiBag.desc_item_label",UiBag.desc_item_label)
        UiBag.desc_item_label.desc.Title = ""   --点选装备
        return
    end


    if  index_ and index_.uuid then
        local info_ = gg.client_bag_items[ index_.uuid ]
        if  info_ then
            local info_string_ = UiBag.getBagItemInfoStr( info_ )


            UiBag.desc_item_eq.Visible = false    --已穿戴的装备

            if  gg.isWearPos( bag_id_ ) then
                UiBag.desc_item_eq.Visible       = true
                UiBag.desc_item_eq.desc.Title    = info_string_           --点已穿戴的装备
                UiBag.desc_item_label.desc.Title = ''
            else
                UiBag.desc_item_label.desc.Title = info_string_        --点选背包装备
            end


            --是否显示使用按钮
            UiBag.btn_decompose.Visible = false
            UiBag.btn_use.Visible       = false

            if  info_.itype == common_const.ITEM_TYPE.BOX then
                UiBag.btn_use.Visible = true
                UiBag.btn_use.Title = '打 开'

            elseif  info_.itype == common_const.ITEM_TYPE.EQUIPMENT then
                if  not gg.isWearPos(bag_id_) then
                    UiBag.btn_use.Visible = true
                    UiBag.btn_use.Title = '穿 戴'

                    UiBag.btn_decompose.Visible = true
                end
            else
                ---
            end


            --调整绿色和黄色选定框
            UiBag.bag_pointer.Visible = false
            UiBag.eqp_pointer.Visible = false


            if  bag_id_ then

                --显示选定框
                if  UiBag.dict_btn_bag[ bag_id_ ] then
                    UiBag.bag_pointer.Visible  = true
                    UiBag.bag_pointer.Parent   = UiBag.dict_btn_bag[ bag_id_ ].btn
                    UiBag.bag_pointer.Position = Vector2.new(-5, -5)
                end


                if  bag_id_ >= 10000 then
                    -- 如果是包裹里，且是装备， 指示哪个位置可以装备
                    if  info_.itype == common_const.ITEM_TYPE.EQUIPMENT then
                        if  info_.pos then
                            if  UiBag.dict_btn_bag[ info_.pos ] then
                                UiBag.eqp_pointer.Visible  = true
                                UiBag.eqp_pointer.Parent   = UiBag.dict_btn_bag[ info_.pos ].btn
                                UiBag.eqp_pointer.Position = Vector2.new(-5, -5)

                                --显示【当前装备详情】
                                if  gg.client_bag_index[ info_.pos ] then
                                    local index_eq_ = gg.client_bag_index[ info_.pos ]
                                    if  index_eq_ and index_eq_.uuid then
                                        local info_eq_ = gg.client_bag_items[ index_eq_.uuid ]
                                        if  info_eq_ then
                                            UiBag.desc_item_eq.Visible = true
                                            local info_eq_string_ = UiBag.getBagItemInfoStr( info_eq_ )
                                            UiBag.desc_item_eq.desc.Title = info_eq_string_
                                        end
                                    end

                                end
                            end
                        end
                    end

                end
            end


        end
    end

end



--获得属性说明
function UiBag.getAttrStr( attr_ )
    -- {k=r2 v=16}
    gg.log("attr_",attr_)
    gg.log("common_config.common_att_dict",common_config.common_att_dict)
    local config_ = common_config.common_att_dict[ attr_.k ]
    if not config_ then
        return ""
    end
    local ret_ = config_.des .. ':' .. attr_.v
    if  config_.per == 1 then
        ret_ = ret_ .. '%'
    end
    ret_ = ret_ .. '\n'
    return ret_
end



--获得质量字符串

function UiBag.getQualityStr( quality_ )
    return common_config.const_quality_name[ quality_ ] or '(未知)'
end
--获得位置字符串
function UiBag.getEqPosStr( pos_ )
    return common_config.const_ui_eq_pos[ pos_ ] or '未知'
end


--建立背包界面
function UiBag.create()
    -- 获取UI根节点
    local ui_root = gg.create_ui_root()
    gg.log("创建背包UI", ui_root)
    
    UiBag.bg = ui_root.ui_bag.bg
    gg.log("检查bg是否正确获取:", UiBag.bg)
    
    local bg_ = UiBag.bg
    if not bg_ then
        gg.log("错误：无法获取背包背景")
        return
    end
    
    UiBag.desc_item_label = bg_.bag_bg_info
    UiBag.desc_item_eq = bg_.bag_bg_eq
    UiBag.desc_item_eq.Visible = false
    local bag_bg_man = bg_.bag_bg_man
    
    -- 使用服务器数据创建装备槽位
    -- 使用现有的位置逻辑，但调整为适应服务器数据
    UiBag.createEquipSlots()
    
    -- 使用服务器数据创建背包槽位
    UiBag.createInventorySlots()
    
    -- 创建装备位置指示器
    UiBag.createEquipPointers()
    
    -- 设置使用和分解按钮
    UiBag.setupActionButtons()
    
    -- 攻防描述
    UiBag.desc_dmg_def = bg_.bag_bg_man.desc_dmg_def
    if gg.client_player_data.battle_data then
        UiBag.showDescDmgDef()
    end
    
    -- 关闭按钮
    bg_.btn_close.Click:Connect(function()
        UiBag.show()
    end)
end

-- 创建装备槽位
function UiBag.createEquipSlots()
    local bg_ = UiBag.bg
    local bag_bg_man = bg_.bag_bg_man
    local man_xx = bag_bg_man.Position.x 
    local base_y = bag_bg_man.Position.y + (bag_bg_man.Size.y / 2)
    local frame_size = 64
    local xx1, y_spacing, xx2 = 150, 70, 100
    
    -- 创建装备槽位 (装备槽位ID范围是1001-1008)
    for i = 1, 8 do
        local bag_id_ = 1000 + i
        local x, y
        
        -- 根据槽位ID确定位置
        if i <= 4 then
            -- 左侧槽位
            x = man_xx - xx1
            y = base_y - y_spacing * (i - 1)
        else
            -- 右侧槽位
            x = man_xx + xx2
            y = base_y - y_spacing * (i - 5)
        end
        
        UiBag.createBagSlot(bag_id_, x, y, UiBag.getEqPosStr(bag_id_))
    end
end

-- 创建背包槽位
function UiBag.createInventorySlots()
    local bg_ = UiBag.bg
    local bag_x_start = bg_.Position.x - 100
    local bag_y_start = bg_.Position.y 
    local frame_size_bg = 66  -- 背包槽位大小
    
    -- 使用client_bag_size确定背包大小
    local bag_size = gg.client_bag_size or 36  -- 如果未定义则默认为36格
    
    -- 计算行列数
    local cols = 6  -- 每行6格
    local rows = math.ceil(bag_size / cols)  -- 根据总格子数计算行数
    
    -- 创建背包槽位
    for i = 0, bag_size - 1 do
        local row = math.floor(i / cols)
        local col = i % cols
        local bag_id_ = 10000 + i
        local x = bag_x_start + frame_size_bg * col
        local y = 50 + frame_size_bg * row
        UiBag.createBagSlot(bag_id_, x, y)
    end
end

-- 创建单个背包槽位
function UiBag.createBagSlot(bag_id_, x, y, text_)
    local bg_ = UiBag.bg
    local tmp_button = SandboxNode.New('UIButton', bg_)
    tmp_button.Name = 'btn_bag_' .. bag_id_
    tmp_button.Icon = common_config.assets_dict.btn_empty_frame
    gg.formatButton(tmp_button)
    tmp_button.Size = Vector2.New(64, 64)
    tmp_button.Pivot = Vector2.new(0, 0)
    tmp_button.Position = Vector2.New(x, y)
    
    tmp_button.Click:Connect(function()
        -- 首次点选
        if UiBag.last_bag_index == 0 then
            UiBag.last_bag_index = bag_id_
        elseif bag_id_ == UiBag.last_bag_index then
            -- 点击相同位置
            UiBag.last_bag_index = 0
        else
            -- 交换位置(旧位置必须有物品)
            local last_ = UiBag.last_bag_index
            if UiBag.can_swap_bag(last_, bag_id_) then
                gg.network_channel:FireServer({
                    cmd = 'cmd_player_items_change',
                    bag_ver = gg.client_bag_ver,
                    pos1 = last_,
                    pos2 = bag_id_
                })
                UiBag.last_bag_index = 0
            else
                UiBag.last_bag_index = bag_id_
            end
        end
        UiBag.showItemInfo(UiBag.last_bag_index)
    end)
    
    -- 记录按钮位置
    if not UiBag.dict_btn_bag[bag_id_] then
        UiBag.dict_btn_bag[bag_id_] = {}
    end
    UiBag.dict_btn_bag[bag_id_].btn = tmp_button
    
    -- 设置文本
    if text_ then
        tmp_button.Title = text_
    else
        if gg.isWearPos(bag_id_) then
            tmp_button.Title = '[' .. UiBag.getEqPosStr(bag_id_) .. ']'
        end
    end
    
    -- 如果已有该槽位的物品数据，立即显示
    if gg.client_bag_index[bag_id_] and gg.client_bag_index[bag_id_].uuid then
        local uuid_ = gg.client_bag_index[bag_id_].uuid
        if gg.client_bag_items[uuid_] then
            local item_ = gg.client_bag_items[uuid_]
            UiBag.createItemIcon(tmp_button, item_)
        end
    end
    
    return tmp_button
end

-- 创建物品图标
function UiBag.createItemIcon(btn, item_)
    if not btn.item_icon then
        -- 创建新图标
        local image_ = gg.createImage(btn, item_.asset)
        image_.Name = 'item_icon'
        image_.Active = false
        image_.ClickPass = true
        image_.Pivot = Vector2.new(0, 0)
        image_.Position = Vector2.new(0, 0)
        image_.Size = btn.Size
        
        -- 质量星号
        local text_ = gg.createTextLabel(image_, '★')
        text_.Name = 'star'
        text_.TitleColor = gg.getQualityColor(item_.quality)
        text_.FontSize = 28
        text_.Position = Vector2.new(10, 10)
        
        -- 数量
        if item_.num then
            local text_num_ = gg.createTextLabel(image_, '' .. item_.num)
            text_num_.Name = 'num'
            text_num_.FontSize = 18
            text_num_.Position = Vector2.new(btn.Size.x * 0.5, btn.Size.y - 10)
        end
    else
        -- 更新现有图标
        btn.item_icon.Icon = item_.asset
        btn.item_icon.star.TitleColor = gg.getQualityColor(item_.quality)
        
        -- 更新数量
        if item_.num then
            if not btn.item_icon.num then
                local text_num_ = gg.createTextLabel(btn.item_icon, '' .. item_.num)
                text_num_.Name = 'num'
                text_num_.FontSize = 18
                text_num_.Position = Vector2.new(btn.Size.x * 0.5, btn.Size.y - 10)
            else
                btn.item_icon.num.Title = '' .. item_.num
            end
        elseif btn.item_icon.num then
            btn.item_icon.num.Title = ''
        end
    end
end

-- 创建装备指示器和背包选择器
function UiBag.createEquipPointers()
    local bg_ = UiBag.bg
    
    -- 创建装备位置指示器（红色）
    local eqp_btn = UiBag.dict_btn_bag[1001].btn
    local image_ = gg.createImage(eqp_btn, common_config.assets_dict.icon_point_frame2)
    image_.Name = 'eqp_pointer'
    image_.Active = false
    image_.ClickPass = true
    image_.Pivot = Vector2.new(0, 0)
    image_.Position = Vector2.new(-5, -5)
    local size_ = eqp_btn.Size
    image_.Size = Vector2.new(size_.x + 10, size_.y + 10)
    image_.RenderIndex = 1
    image_.FillColor = ColorQuad.new(255, 64, 64, 255)
    UiBag.eqp_pointer = image_
    UiBag.eqp_pointer.Visible = false
    
    -- 创建背包选择指示器（绿色）
    local bag_btn = UiBag.dict_btn_bag[10000].btn
    local image2_ = gg.createImage(bag_btn, common_config.assets_dict.icon_point_frame2)
    image2_.Name = 'bag_pointer'
    image2_.Active = false
    image2_.ClickPass = true
    image2_.Pivot = Vector2.new(0, 0)
    image2_.Position = Vector2.new(-5, -5)
    local size2_ = bag_btn.Size
    image2_.Size = Vector2.new(size2_.x + 10, size2_.y + 10)
    image2_.RenderIndex = 1
    image2_.FillColor = ColorQuad.new(0, 255, 0, 255)
    UiBag.bag_pointer = image2_
    UiBag.bag_pointer.Visible = false
end

-- 设置使用和分解按钮
function UiBag.setupActionButtons()
    local bg_ = UiBag.bg
    
    -- 使用按钮
    UiBag.btn_use = bg_.btn_use
    UiBag.btn_use.Click:Connect(function()
        gg.network_channel:FireServer({ cmd='cmd_btn_use_item', bag_id=UiBag.last_bag_index })
    end)
    UiBag.btn_use.Visible = false
    
    -- 分解按钮
    UiBag.btn_decompose = bg_.btn_decompose
    UiBag.btn_decompose.Click:Connect(function()
        local item_ = gg.getClientBagItemByBagId(UiBag.last_bag_index)
        
        if item_ and item_.quality > 3 then
            UiYesNo.showPage(
                { type=1, title='分 解', content='此物品的等级较高，确定分解该物品吗？' },
                function(ret)
                    if ret then
                        gg.network_channel:FireServer({ cmd='cmd_btn_decompose', bag_id=UiBag.last_bag_index })
                    end
                end
            )
        else
            gg.network_channel:FireServer({ cmd='cmd_btn_decompose', bag_id=UiBag.last_bag_index })
        end
    end)
    UiBag.btn_decompose.Visible = false
end

--可以交换位置    --if  (UiBag.dict_btn_bag[last_] and UiBag.dict_btn_bag[last_].btn.item_icon) then
function UiBag.can_swap_bag( last_, new_ )
    gg.log( 'call can_swap_bag:', last_, new_ )

    local dict_ = UiBag.dict_btn_bag
    if  dict_[last_] and dict_[last_].btn.item_icon then
        if  dict_[new_] and dict_[new_].btn.item_icon == nil then
            return true       --目标是空位置
        end

        if  gg.isWearPos( new_ ) then
            return true       --目标是穿戴位置
        end
    end

    return false
end


--数据回调 玩家物品
function UiBag.handleSyncPlayerItems( args1_ )
    --{ cmd='cmd_player_items_ret', index=data_, items=items_,size=int } )
    gg.log('数据回调玩家物品handleSyncPlayerItems====', args1_ )
    if  args1_.index then
        gg.client_bag_size = args1_.size
        gg.client_bag_index = args1_.index
        if  args1_.items then
            gg.client_bag_items = args1_.items
        end
        if  args1_.bag_ver then
            gg.client_bag_ver   = args1_.bag_ver
        end

        UiBag.refreshUi()

    end
end



--刷新描述字符串
function UiBag.showDescDmgDef()
    local v = gg.client_player_data.battle_data     ---@type table
    local str_ = 'HP:' .. v.hp_max .. ' MP:' .. v.mp_max .. '\n攻:' .. v.attack .. ' 法:' .. v.spell .. ' 防:' .. v.defence
    UiBag.desc_dmg_def.Title = str_
end


--重新刷新ui (数据有变化后)
function UiBag.refreshUi()
    for bag_id_, btn_info_ in pairs( UiBag.dict_btn_bag ) do
                                  --[1001] = { btn }
        if  gg.client_bag_index[ bag_id_ ] and gg.client_bag_index[ bag_id_ ].uuid then   --[1001] = { uuid='test001' }
            --有物品
            local new_item_uuid_ = gg.client_bag_index[ bag_id_ ].uuid
            local asset_id_, quality_, num_
            if  gg.client_bag_items[ new_item_uuid_ ] then
                asset_id_ = gg.client_bag_items[ new_item_uuid_ ].asset
                quality_  = gg.client_bag_items[ new_item_uuid_ ].quality
                num_      = gg.client_bag_items[ new_item_uuid_ ].num
            end

            local tmp_button = btn_info_.btn

            if  tmp_button then
                UiBag.updateItemIcon(tmp_button, asset_id_, quality_, num_)
            end

        else
            --没有物品, 清理图标
            if  btn_info_.btn and btn_info_.btn.item_icon then
                btn_info_.btn.item_icon:Destroy()
            end

        end
    end

    --开箱子后，刷新箱子格子物品描述
    if  UiBag.last_bag_index then
        UiBag.showItemInfo( UiBag.last_bag_index )
    end

end


-- 创建指示器统一函数
function UiBag.createPointer(parent, name, color)
    local image = gg.createImage(parent, common_config.assets_dict.icon_point_frame2)
    image.Name = name
    image.Active = false
    image.ClickPass = true
    image.Pivot = Vector2.new(0, 0)
    image.Position = Vector2.new(0, 0)
    local size = parent.Size
    image.Size = Vector2.new(10 + size.x, 10 + size.y)
    image.RenderIndex = 1
    image.FillColor = color
    return image
end

-- 处理装备位置指示
function UiBag.updateEquipmentPointer(bag_id, info)
    if bag_id >= 10000 and info.itype == common_const.ITEM_TYPE.EQUIPMENT and info.pos then
        local equipBtn = UiBag.dict_btn_bag[info.pos]
        if equipBtn then
            UiBag.eqp_pointer.Visible = true
            UiBag.eqp_pointer.Parent = equipBtn.btn
            UiBag.eqp_pointer.Position = Vector2.new(-5, -5)
            
            -- 显示当前装备详情
            UiBag.updateEquippedItemInfo(info.pos)
        end
    end
end

-- 显示已装备物品信息
function UiBag.updateEquippedItemInfo(pos)
    local indexEq = gg.client_bag_index[pos]
    if indexEq and indexEq.uuid then
        local infoEq = gg.client_bag_items[indexEq.uuid]
        if infoEq then
            UiBag.desc_item_eq.Visible = true
            UiBag.desc_item_eq.desc.Title = UiBag.getBagItemInfoStr(infoEq)
        end
    end
end

-- 更新物品图标
function UiBag.updateItemIcon(button, asset_id, quality, num)
    if not button.item_icon then
        -- 创建新图标
        local image = gg.createImage(button, asset_id)
        image.Name = 'item_icon'
        image.Active = false
        image.ClickPass = true
        image.Pivot = Vector2.new(0, 0)
        image.Position = Vector2.new(0, 0)
        image.Size = button.Size
        
        -- 质量星号
        local text = gg.createTextLabel(image, '★')
        text.Name = 'star'
        text.TitleColor = gg.getQualityColor(quality)
        text.FontSize = 28
        text.Position = Vector2.new(10, 10)
        
        -- 数量
        if num then
            local textNum = gg.createTextLabel(image, tostring(num))
            textNum.Name = 'num'
            textNum.FontSize = 18
            textNum.Position = Vector2.new(button.Size.x * 0.5, button.Size.y - 10)
        end
    else
        -- 更新现有图标
        if button.item_icon.Icon ~= asset_id and asset_id then
            button.item_icon.Icon = asset_id
        end
        
        -- 更新星号
        button.item_icon.star.TitleColor = gg.getQualityColor(quality)
        
        -- 更新数量
        if num then
            if not button.item_icon.num then
                local textNum = gg.createTextLabel(button.item_icon, tostring(num))
                textNum.Name = 'num'
                textNum.FontSize = 18
                textNum.Position = Vector2.new(button.Size.x * 0.5, button.Size.y - 10)
            else
                button.item_icon.num.Title = tostring(num)
            end
        elseif button.item_icon.num then
            button.item_icon.num.Title = ''
        end
    end
end

-- 装备位置配置
local EQUIPMENT_POSITIONS = {
    {id = 1001, side = "left", row = 0}, -- 武器
    {id = 1003, side = "left", row = 1}, -- 头盔
    {id = 1004, side = "left", row = 2}, -- 衣服
    {id = 1005, side = "left", row = 3}, -- 裤子
    {id = 1002, side = "right", row = 0}, -- 盾牌
    {id = 1006, side = "right", row = 1}, -- 披风
    {id = 1007, side = "right", row = 2}, -- 鞋子
    {id = 1008, side = "right", row = 3}, -- 饰品
}

return UiBag;
