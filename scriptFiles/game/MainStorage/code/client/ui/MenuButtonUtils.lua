local MainStorage = game:GetService("MainStorage")
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class MenuButtonUtils
local MenuButtonUtils = {}

---注册菜单按钮 - 您原来的函数
---@param viewButton ViewButton
function MenuButtonUtils.RegisterMenuButton(viewButton)
    if not viewButton then return end
    
    viewButton:SetTouchEnable(true)
    
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        
        if button.node.Name == "活动" then
        elseif button.node.Name == "图鉴" then
                gg.network_channel:FireServer({
                cmd = "SkillRequest_GetList",
                buttonName = button.node.Name
            })
            ViewBase["CardsGui"]:Open()
        elseif button.node.Name =='关闭' then
            ViewBase["CardsGui"]:Close()
        end
        
        -- 发送菜单点击事件到服务器
        -- gg.network_channel:FireServer({
        --     cmd = "MenuClicked",
        --     buttonName = button.node.Name
        -- })
    end
end

---批量注册菜单按钮
---@param buttons ViewButton[]
function MenuButtonUtils.RegisterMenuButtons(buttons)
    for _, button in ipairs(buttons) do
        MenuButtonUtils.RegisterMenuButton(button)
    end
end

---为 ViewButton 添加菜单功能的扩展方法
---@param viewButton ViewButton
---@param menuConfig table 菜单配置
function MenuButtonUtils.ExtendAsMenuButton(viewButton, menuConfig)
    if not viewButton then return end
    
    viewButton:SetTouchEnable(true)
    
    local originalClickCb = viewButton.clickCb
    viewButton.clickCb = function(ui, button)
        -- 执行原有回调
        if originalClickCb then
            originalClickCb(ui, button)
        end
        
        -- 执行菜单逻辑
        MenuButtonUtils.HandleMenuClick(button, menuConfig)
    end
end

---处理菜单点击
---@param button ViewButton
---@param config table
function MenuButtonUtils.HandleMenuClick(button, config)
    local buttonName = button.node.Name
    gg.log("菜单按钮点击", buttonName)
    
    -- 执行配置的动作
    if config and config[buttonName] then
        config[buttonName]()
    end
    
    -- 发送服务器事件
    gg.network_channel:FireServer({
        cmd = "MenuClicked",
        buttonName = buttonName
    })
end

return MenuButtonUtils