--- 任务对话框

local game = game
local script = script
local print = print
local math = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs
local Vector2 = Vector2
local Vector3 = Vector3
local ColorQuad = ColorQuad
local MainStorage = game:GetService("MainStorage")
local inputservice = game:GetService("UserInputService")
local Players = game:GetService('Players')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class UIDialogBox
local UIDialogBox = {
    bg = nil,              -- 对话框背景
    content_txt = nil,     -- 对话内容文本
    text_box = nil,        -- 文本框
    user_name = nil,       -- 对话者名称
    next_btn = nil,        -- 下一步按钮
    
    current_dialog = nil,  -- 当前对话数据
    dialog_index = 1,      -- 当前对话索引
    dialogs = {},          -- 对话列表
    callback = nil,        -- 对话结束回调
}

-- 初始化对话框
function UIDialogBox.init()
    local ui_root_spell = gg.get_ui_root_spell()
    
    UIDialogBox.bg = ui_root_spell.ui_dialogue
    UIDialogBox.content_txt = ui_root_spell.ui_dialogue.content_txt
    UIDialogBox.text_box = ui_root_spell.ui_dialogue.text_box
    UIDialogBox.user_name = ui_root_spell.ui_dialogue.user_name
    UIDialogBox.next_btn = ui_root_spell.ui_dialogue.next
    
    -- 绑定下一步按钮事件
    UIDialogBox.next_btn.Click:Connect(function()
        UIDialogBox.showNextDialog()
    end)
    
    UIDialogBox.bg.Visible = false
end

-- 显示对话框
function UIDialogBox.show()
    if not UIDialogBox.bg then
        UIDialogBox.init()
    end
    UIDialogBox.bg.Visible = true
end

-- 隐藏对话框
function UIDialogBox.hide()
    UIDialogBox.bg.Visible = false
end

-- 设置对话内容
function UIDialogBox.setContent(content)
    UIDialogBox.content_txt.Title = content
end

-- 设置对话者名称
function UIDialogBox.setName(name)
    UIDialogBox.user_name.Title = name
end

-- 显示下一段对话
function UIDialogBox.showNextDialog()
    UIDialogBox.dialog_index = UIDialogBox.dialog_index + 1
    
    if UIDialogBox.dialog_index <= #UIDialogBox.dialogs then
        local dialog = UIDialogBox.dialogs[UIDialogBox.dialog_index]
        UIDialogBox.showDialog(dialog)
    else
        -- 对话结束
        UIDialogBox.hide()
        if UIDialogBox.callback then
            UIDialogBox.callback()
        end
    end
end

-- 显示指定对话
function UIDialogBox.showDialog(dialog)
    UIDialogBox.current_dialog = dialog
    UIDialogBox.setName(dialog.name)
    UIDialogBox.setContent(dialog.content)
    UIDialogBox.show()
end

-- 开始对话序列
function UIDialogBox.startDialogs(dialogs, callback)
    UIDialogBox.dialogs = dialogs
    UIDialogBox.dialog_index = 1
    UIDialogBox.callback = callback
    
    if #dialogs > 0 then
        UIDialogBox.showDialog(dialogs[1])
    else
        if callback then
            callback()
        end
    end
end

-- 设置单个对话
function UIDialogBox.setDialog(name, content, callback)
    local dialog = {
        name = name,
        content = content
    }
    
    UIDialogBox.startDialogs({dialog}, callback)
end

-- 对话框是否可见
function UIDialogBox.isVisible()
    return UIDialogBox.bg and UIDialogBox.bg.Visible
end

return UIDialogBox