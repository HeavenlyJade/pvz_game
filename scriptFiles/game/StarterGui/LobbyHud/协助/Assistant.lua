local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class Assistant:ViewBase
local Assistant = ClassMgr.Class("Assistant", ViewBase)

local uiConfig = {
    uiName = "Assistant",
    layer = 0,
    hideOnInit = false,
}

---@override
function Assistant:OnInit(node, config)
    -- 获取"脱离卡死"按钮
    self.unstuckButton = self:Get("脱离卡死", ViewButton) ---@type ViewButton
    if not self.unstuckButton then
        return
    end

    -- 注册按钮事件
    self:RegisterEventFunction()
end

---为按钮注册点击事件
function Assistant:RegisterEventFunction()
    if self.unstuckButton then
        self.unstuckButton.clickCb = function(ui, button)
            -- gg.log(""脱离卡死"按钮被点击")
            -- 发送执行指令的请求到服务器
            -- gg.network_channel:FireServer({
            --     cmd = "ExecuteCommand",
            --     command = "/unstuck"
            -- })
            -- 可以在这里给用户一些反馈，例如显示一个提示
            -- UIBase.GetUI("ToastHud"):Show("已发送求助信号，请稍候...")
        end
    end
end

return Assistant.New(script.Parent, uiConfig)