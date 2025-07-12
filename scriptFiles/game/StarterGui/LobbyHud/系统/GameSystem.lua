local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local CoreUI = game:GetService("CoreUI")
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class GameSystem:ViewBase
local GameSystem = ClassMgr.Class("GameSystem", ViewBase)

local uiConfig = {
    uiName = "GameSystem",
    layer = 0,
    hideOnInit = false,
}

---@param viewButton ViewButton
function GameSystem:RegisterMenuButton(viewButton)
    if not viewButton then return end
    viewButton:SetTouchEnable(true)
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        gg.log("菜单按钮点击", button.node.Name)
        if button.node.Name == "邮件" then
            GameSystem:onMailClick()
        elseif button.node.Name == "设置" then
            GameSystem:onSettingClick()
        end

    end
end

function GameSystem:OnInit(node, config)
    gg.log("GameSystem 初始化")

    -- 初始化邮件按钮
    self.mailButton = self:Get("邮件", ViewButton)
    self:RegisterMenuButton(self.mailButton)
    self:RegisterMenuButton(self:Get("设置", ViewButton))

    -- 获取邮件按钮的"new"提示节点
    self.mailNewNode = nil
    if self.mailButton and self.mailButton.node then
        gg.log("🔍 正在查找邮件按钮的new子节点，邮件按钮节点:", self.mailButton.node.Name)
        self.mailNewNode = self.mailButton.node["new"]
        if self.mailNewNode then
            self.mailNewNode.Visible = false -- 初始隐藏
            gg.log("✅ 找到邮件按钮的new节点:", self.mailNewNode.Name)
        else
            gg.log("⚠️ 未找到邮件按钮的new子节点")
            -- 列出所有子节点，便于调试
            gg.log("📋 邮件按钮的所有子节点:")
            for _, child in pairs(self.mailButton.node.Children) do
                gg.log("  - ", child.Name, child.ClassType)
            end
        end
    else
        gg.log("⚠️ 邮件按钮或邮件按钮节点不存在")
    end

    -- 注册邮件状态监听事件
    self:RegisterMailEvents()

    -- 在这里可以添加初始化逻辑
end

--- 注册邮件相关事件监听
function GameSystem:RegisterMailEvents()
    local gameSystemInstance = self -- 保存self引用，避免作用域问题

    -- 监听邮件状态通知
    ClientEventManager.Subscribe("MailStatusNotify", function(event)
        gg.log("🔔 接收到邮件状态通知", event.cmd, event.has_unclaimed_mails)
        self:HandleMailStatusNotify(event)
    end)

    gg.log("GameSystem 邮件事件监听注册完成")
end

--- 处理邮件状态通知
---@param event table
function GameSystem:HandleMailStatusNotify(event)
    if not event then
        gg.log("⚠️ HandleMailStatusNotify: event为空")
        return
    end

    local hasUnclaimedMails = event.has_unclaimed_mails or false

    gg.log("🎯 GameSystem收到邮件状态通知，事件数据:", event)
    gg.log("🎯 有未领取邮件:", hasUnclaimedMails and "是" or "否")
    gg.log("🎯 邮件new节点状态:", self.mailNewNode and "存在" or "不存在")

    self:UpdateMailNotification(hasUnclaimedMails)
end

--- 更新邮件按钮的提示状态
---@param showNotification boolean 是否显示提示
function GameSystem:UpdateMailNotification(showNotification)
    if not self.mailNewNode then
        gg.log("⚠️ 邮件new节点不存在，无法更新提示")
        return
    end

    gg.log("🔔 更新邮件按钮提示，当前状态:", self.mailNewNode.Visible, "→ 新状态:", showNotification)

    self.mailNewNode.Visible = showNotification

    gg.log("✅ 邮件按钮提示状态更新完成:", showNotification and "显示" or "隐藏")
end

--- 处理邮件按钮点击
function GameSystem:onMailClick()
    gg.log("邮件按钮点击")

    -- 点击邮件按钮时，暂时隐藏提示（在邮件界面关闭后会重新检查状态）
    if self.mailNewNode then
        self.mailNewNode.Visible = false
    end

    ViewBase["MailGui"]:Open()
end

--- 处理设置按钮点击
function GameSystem:onSettingClick()
    gg.log("设置按钮点击")
    CoreUI:ExitGame()
end


return GameSystem.New(script.Parent, uiConfig)
