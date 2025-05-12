
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
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg


---@class UiRoleMsg
local  UiRoleMsg = {
    bg = nil
};

function UiRoleMsg.create()
    local ui_root = gg.create_ui_root()
    UiRoleMsg.bg  = ui_root.ui_role_msg.bg
    UiRoleMsg.update_msg_panel()
    local bg_ = UiRoleMsg.bg
    --关闭按钮
    bg_.title.role_msg_btn_close.Click:Connect(function()
        UiRoleMsg.show()
    end)
end

function UiRoleMsg.show()
    if  UiRoleMsg.bg == nil then
        UiRoleMsg.create()
    end
    local ui_root = gg.create_ui_root()
    ui_root.ui_role_msg.Visible = not ui_root.ui_role_msg.Visible
    --  在打开个人信息的界面对时候，数据信息同步
    if  ui_root.ui_role_msg.Visible then
        UiRoleMsg.update_msg_panel()
    end
end




function UiRoleMsg.update_msg_panel()
    print("生成角色属性信息")
    local ui_size = gg.get_ui_size()
    local ui_root = gg.create_ui_root()
    if true then
        local function create_attr_msg(key,Name,value,y_offset)
            local local_arrt = UiRoleMsg.bg.attribute:FindFirstChild(Name)
            if local_arrt then
                local_arrt.Title = key.."                       "..value
            else 
                local attr_info    = gg.cloneFromTemplate('attr_info')   
                local attr_title   =  UiRoleMsg.bg.attribute.attr_title
                local attr_title_Position = attr_title.Position
                --克隆获取玩家的属性的title的模板
                attr_info.Title = key.."                       "..value
                attr_info.Parent  = UiRoleMsg.bg.attribute
                attr_info.Name    = Name
                attr_info.Visible = true
                attr_info.Position  = Vector2.new( attr_title_Position.x, attr_title_Position.y+y_offset )
            end
        end
        local battle_data_ = gg.client_player_data.battle_data
        local ui_role_msg_bg = ui_root.ui_role_msg.bg
        local gap = 20
        local attributeList = {
            { key = "生命值",     name = "hp_max",   value = battle_data_.hp_max,  },
            { key = "魔法值",     name = "mp_max",   value = battle_data_.mp_max,  },
            { key = "力量",       name = "str",      value = battle_data_.str,    },
            { key = "体力",       name = "vit",      value = battle_data_.vit,     },
            { key = "智力",       name = "int",      value = battle_data_.int,    },
            { key = "物理攻击力", name = "attack",   value = battle_data_.attack,  },
            { key = "魔法攻击力", name = "spell",    value = battle_data_.spell,   },
            { key = "防御防御力",       name = "defence",  value = battle_data_.defence,  },
            { key = "暴击率",       name = "cr",  value = battle_data_.cr,  },
            { key = "暴击伤害",       name = "crd",  value = battle_data_.crd,  },
            { key = "命中",       name = "a_dod",  value = battle_data_.a_dod,},
        }
        
        for i, data in ipairs(attributeList) do
            local key       = data.key       -- 显示给玩家看的“属性名称”（如“生命值”）
            local name      = data.name      -- 属性对应的唯一标识（如“hp_max”）
            local value     = data.value     -- 属性的数值
            local offsetY = gap * i
            create_attr_msg(key,name, value, offsetY)
        end
        ui_role_msg_bg.head_bg.user_name.Title = gg.client_player_data.user_name
        ui_role_msg_bg.head_bg.lv.Title  = tostring(battle_data_.level)
    end
end
return UiRoleMsg