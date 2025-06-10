local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

local uiConfig = {
    uiName = "MailGui",
    layer = 3,
    hideOnInit = true,
}

---@class MailGui:ViewBase
local MailGui = ClassMgr.Class("MailGui", ViewBase)

---@override
function MailGui:OnInit(node, config)
    -- UI组件初始化
    self.closeButton = self:Get("关闭", ViewButton) ---@type ViewButton
    self.mailCategoryList = self:Get("邮箱分类", ViewList) ---@type ViewList
    self.mailBackground = self:Get("邮件背景", ViewComponent) ---@type ViewComponent
    self.mailListFrame = self:Get("邮件背景/邮件列表框", ViewComponent) ---@type ViewComponent
    
    -- 邮件详情相关UI
    self.titleName = self:Get("邮件背景/Title名", ViewComponent) ---@type ViewComponent
    self.title = self:Get("邮件背景/Title", ViewComponent) ---@type ViewComponent
    self.subTitleName = self:Get("邮件背景/副Title名", ViewComponent) ---@type ViewComponent
    self.sendTimeTitle = self:Get("邮件背景/副Title_发送时间", ViewComponent) ---@type ViewComponent
    self.deadlineTitle = self:Get("邮件背景/副Title_截止时间", ViewComponent) ---@type ViewComponent
    self.contentText = self:Get("邮件背景/正文内容", ViewComponent) ---@type ViewComponent
    self.senderInfo = self:Get("邮件背景/发送人", ViewComponent) ---@type ViewComponent
    
    -- 功能按钮
    self.claimButton = self:Get("邮件背景/领取", ViewButton) ---@type ViewButton
    self.batchClaimButton = self:Get("邮件背景/一键领取", ViewButton) ---@type ViewButton
    self.deleteButton = self:Get("邮件背景/删除邮件", ViewButton) ---@type ViewButton
    
    -- 奖励显示器
    self.rewardDisplay = self:Get("获得物品显示器", ViewComponent) ---@type ViewComponent
    
    -- 数据存储
    self.mailData = {} ---@type table<string, table> -- 邮件数据
    self.currentSelectedMail = nil ---@type table -- 当前选中的邮件
    self.currentCategory = "全部" ---@type string -- 当前选中的分类
    
    -- 初始化UI状态
    self:InitializeUI()
    
    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()
    self:InitializeCategories()
end

-- 初始化UI状态
function MailGui:InitializeUI()
    -- 初始时隐藏邮件详情相关UI
    if self.titleName then self.titleName:SetVisible(false) end
    if self.title then self.title:SetVisible(false) end
    if self.subTitleName then self.subTitleName:SetVisible(false) end
    if self.sendTimeTitle then self.sendTimeTitle:SetVisible(false) end
    if self.deadlineTitle then self.deadlineTitle:SetVisible(false) end
    if self.contentText then self.contentText:SetVisible(false) end
    if self.senderInfo then self.senderInfo:SetVisible(false) end
    if self.claimButton then self.claimButton:SetVisible(false) end
    if self.deleteButton then self.deleteButton:SetVisible(false) end
    if self.batchClaimButton then self.batchClaimButton:SetVisible(false) end
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
    
    gg.log("MailGui UI初始化完成")
end

-- 初始化邮件分类
function MailGui:InitializeCategories()
    if not self.mailCategoryList then return end
    
    -- 设置分类列表
    local categories = {"全部", "系统邮件", "活动邮件", "奖励邮件"}
    self.mailCategoryList:SetElementSize(#categories)
    
    for i, category in ipairs(categories) do
        local categoryItem = self.mailCategoryList:GetChild(i)
        if categoryItem then
            -- 更新分类名称
            if categoryItem.node["Text"] then
                categoryItem.node["Text"].Title = category
            end
            
            -- 绑定点击事件
            local button = ViewButton.New(categoryItem.node, self)
            button.clickCb = function()
                self:OnCategoryClick(category)
            end
        end
    end
    
    gg.log("邮件分类初始化完成")
end

-- 注册按钮事件
function MailGui:RegisterButtonEvents()
    -- 关闭按钮
    if self.closeButton then
        self.closeButton.clickCb = function()
            self:Close()
        end
    end
    
    -- 删除邮件按钮
    if self.deleteButton then
        self.deleteButton.clickCb = function()
            self:OnDeleteMail()
        end
    end
    
    -- 领取附件按钮
    if self.claimButton then
        self.claimButton.clickCb = function()
            self:OnClaimReward()
        end
    end
    
    -- 一键领取按钮
    if self.batchClaimButton then
        self.batchClaimButton.clickCb = function()
            self:OnBatchClaim()
        end
    end
end

-- 注册服务端事件
function MailGui:RegisterEvents()
    -- 监听邮件同步事件
    ClientEventManager.Subscribe("MAIL_SYNC", function(data)
        self:HandleMailSync(data)
    end)
    
    -- 监听邮件删除响应
    ClientEventManager.Subscribe("MAIL_DELETE_RESPONSE", function(data)
        self:HandleDeleteResponse(data)
    end)
    
    -- 监听邮件领取响应
    ClientEventManager.Subscribe("MAIL_CLAIM_RESPONSE", function(data)
        self:HandleClaimResponse(data)
    end)
    
    -- 监听批量领取响应
    ClientEventManager.Subscribe("MAIL_BATCH_CLAIM_RESPONSE", function(data)
        self:HandleBatchClaimResponse(data)
    end)
    
    gg.log("MailGui事件注册完成")
end

-- 分类点击事件
function MailGui:OnCategoryClick(category)
    gg.log("点击邮件分类:", category)
    self.currentCategory = category
    
    -- 清空当前选中
    self.currentSelectedMail = nil
    self:HideMailDetail()
    
    -- 刷新邮件列表
    self:UpdateMailList()
end

-- 处理邮件同步数据
function MailGui:HandleMailSync(data)
    gg.log("收到邮件同步数据", data)
    
    if not data or not data.mails then
        gg.log("邮件数据为空")
        return
    end
    
    -- 更新本地邮件数据
    self.mailData = data.mails
    
    -- 刷新邮件列表显示
    self:UpdateMailList()
end

-- 更新邮件列表显示
function MailGui:UpdateMailList()
    if not self.mailListFrame then return end
    
    -- 清空当前选中
    self.currentSelectedMail = nil
    self:HideMailDetail()
    
    -- 过滤符合当前分类的邮件
    local filteredMails = self:FilterMailsByCategory(self.currentCategory)
    
    -- 创建邮件列表项 (这里需要根据实际的邮件列表框实现来调整)
    -- 假设邮件列表框是一个可滚动的容器，需要动态创建子项
    self:CreateMailListItems(filteredMails)
    
    gg.log("邮件列表更新完成，当前分类:", self.currentCategory, "邮件数量:", #filteredMails)
end

-- 根据分类过滤邮件
function MailGui:FilterMailsByCategory(category)
    local filtered = {}
    
    for mailId, mailInfo in pairs(self.mailData) do
        if category == "全部" or mailInfo.category == category then
            table.insert(filtered, {id = mailId, data = mailInfo})
        end
    end
    
    -- 按时间排序 (最新的在前)
    table.sort(filtered, function(a, b)
        return (a.data.timestamp or 0) > (b.data.timestamp or 0)
    end)
    
    return filtered
end

-- 创建邮件列表项
function MailGui:CreateMailListItems(filteredMails)
    -- 这里需要根据实际的UI结构来实现
    -- 假设邮件列表框有一个ViewList来管理子项
    -- 具体实现需要根据你的UI设计来调整
    
    for i, mailItem in ipairs(filteredMails) do
        -- 创建或更新邮件项
        self:CreateMailListItem(i, mailItem.id, mailItem.data)
    end
end

-- 创建单个邮件列表项
function MailGui:CreateMailListItem(index, mailId, mailInfo)
    -- 这里需要根据实际的邮件项UI模板来实现
    -- 绑定点击事件
    -- local button = ViewButton.New(itemNode, self)
    -- button.clickCb = function()
    --     self:OnMailItemClick(mailId, mailInfo)
    -- end
    
    gg.log("创建邮件项:", index, mailId, mailInfo.title)
end

-- 邮件项点击事件
function MailGui:OnMailItemClick(mailId, mailInfo)
    gg.log("点击邮件项", mailId, mailInfo.title)
    
    -- 更新当前选中邮件
    self.currentSelectedMail = {
        id = mailId,
        data = mailInfo
    }
    
    -- 显示邮件详情
    self:ShowMailDetail(mailInfo)
    
    -- 如果是未读邮件，自动标记为已读
    if not mailInfo.isRead then
        self:SendMarkAsReadRequest(mailId)
    end
end

-- 显示邮件详情
function MailGui:ShowMailDetail(mailInfo)
    -- 显示所有详情UI元素
    if self.titleName then self.titleName:SetVisible(true) end
    if self.title then 
        self.title:SetVisible(true)
        if self.title.node["Title"] then
            self.title.node["Title"].Title = mailInfo.title or "无标题"
        end
    end
    
    if self.subTitleName then self.subTitleName:SetVisible(true) end
    
    if self.sendTimeTitle then 
        self.sendTimeTitle:SetVisible(true)
        if self.sendTimeTitle.node["Title"] then
            self.sendTimeTitle.node["Title"].Title = "发送时间: " .. (mailInfo.sendTime or "")
        end
    end
    
    if self.deadlineTitle then 
        self.deadlineTitle:SetVisible(true)
        if self.deadlineTitle.node["Title"] then
            self.deadlineTitle.node["Title"].Title = "截止时间: " .. (mailInfo.deadline or "无")
        end
    end
    
    if self.contentText then 
        self.contentText:SetVisible(true)
        if self.contentText.node["Title"] then
            self.contentText.node["Title"].Title = mailInfo.content or "无内容"
        end
    end
    
    if self.senderInfo then 
        self.senderInfo:SetVisible(true)
        if self.senderInfo.node["Title"] then
            self.senderInfo.node["Title"].Title = "发送人: " .. (mailInfo.sender or "系统")
        end
    end
    
    -- 更新按钮状态
    self:UpdateDetailButtons(mailInfo)
    
    -- 显示奖励信息
    if mailInfo.hasAttachment and mailInfo.rewards then
        self:ShowRewards(mailInfo.rewards)
    end
    
    gg.log("邮件详情显示完成")
end

-- 隐藏邮件详情
function MailGui:HideMailDetail()
    if self.titleName then self.titleName:SetVisible(false) end
    if self.title then self.title:SetVisible(false) end
    if self.subTitleName then self.subTitleName:SetVisible(false) end
    if self.sendTimeTitle then self.sendTimeTitle:SetVisible(false) end
    if self.deadlineTitle then self.deadlineTitle:SetVisible(false) end
    if self.contentText then self.contentText:SetVisible(false) end
    if self.senderInfo then self.senderInfo:SetVisible(false) end
    if self.claimButton then self.claimButton:SetVisible(false) end
    if self.deleteButton then self.deleteButton:SetVisible(false) end
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
end

-- 显示奖励信息
function MailGui:ShowRewards(rewards)
    if not self.rewardDisplay or not rewards then return end
    
    self.rewardDisplay:SetVisible(true)
    
    -- 这里需要根据实际的奖励显示器UI来实现
    -- 显示奖励物品列表
    gg.log("显示邮件奖励:", rewards)
end

-- 更新详情面板按钮状态
function MailGui:UpdateDetailButtons(mailInfo)
    -- 领取按钮：只有有附件且未领取时显示
    if self.claimButton then
        local canClaim = mailInfo.hasAttachment and not mailInfo.isClaimed
        self.claimButton:SetVisible(canClaim)
        self.claimButton:SetTouchEnable(canClaim)
    end
    
    -- 删除按钮：总是可用
    if self.deleteButton then
        self.deleteButton:SetVisible(true)
        self.deleteButton:SetTouchEnable(true)
    end
    
    -- 一键领取按钮：根据全局状态决定
    if self.batchClaimButton then
        local hasUnclaimedMails = self:HasUnclaimedMails()
        self.batchClaimButton:SetVisible(hasUnclaimedMails)
        self.batchClaimButton:SetTouchEnable(hasUnclaimedMails)
    end
end

-- 检查是否有未领取的邮件
function MailGui:HasUnclaimedMails()
    for _, mailInfo in pairs(self.mailData) do
        if mailInfo.hasAttachment and not mailInfo.isClaimed then
            return true
        end
    end
    return false
end

-- 删除邮件
function MailGui:OnDeleteMail()
    if not self.currentSelectedMail then
        gg.log("没有选中的邮件")
        return
    end
    
    local mailId = self.currentSelectedMail.id
    gg.log("删除邮件", mailId)
    
    -- 发送删除请求
    self:SendDeleteRequest(mailId)
end

-- 领取附件
function MailGui:OnClaimReward()
    if not self.currentSelectedMail then
        gg.log("没有选中的邮件")
        return
    end
    
    local mailId = self.currentSelectedMail.id
    local mailInfo = self.currentSelectedMail.data
    
    if not mailInfo.hasAttachment or mailInfo.isClaimed then
        gg.log("邮件没有附件或已领取")
        return
    end
    
    gg.log("领取附件", mailId)
    
    -- 发送领取请求
    self:SendClaimRequest(mailId)
end

-- 一键领取
function MailGui:OnBatchClaim()
    gg.log("一键领取所有邮件附件")
    
    -- 发送批量领取请求
    gg.network_channel:FireServer({
        cmd = "MAIL_BATCH_CLAIM",
        category = self.currentCategory
    })
end

-- 发送删除请求
function MailGui:SendDeleteRequest(mailId)
    gg.network_channel:FireServer({
        cmd = "MAIL_DELETE",
        mailId = mailId
    })
end

-- 发送领取请求
function MailGui:SendClaimRequest(mailId)
    gg.network_channel:FireServer({
        cmd = "MAIL_CLAIM",
        mailId = mailId
    })
end

-- 发送标记已读请求
function MailGui:SendMarkAsReadRequest(mailId)
    gg.network_channel:FireServer({
        cmd = "MAIL_MARK_READ",
        mailId = mailId
    })
end

-- 处理删除响应
function MailGui:HandleDeleteResponse(data)
    gg.log("收到删除响应", data)
    
    if data.success and data.mailId then
        -- 从本地数据中移除
        self.mailData[data.mailId] = nil
        
        -- 清空当前选中
        self.currentSelectedMail = nil
        self:HideMailDetail()
        
        -- 刷新列表
        self:UpdateMailList()
        
        gg.log("邮件删除成功", data.mailId)
    else
        gg.log("邮件删除失败", data.error or "未知错误")
    end
end

-- 处理领取响应
function MailGui:HandleClaimResponse(data)
    gg.log("收到领取响应", data)
    
    if data.success and data.mailId then
        -- 更新本地数据
        if self.mailData[data.mailId] then
            self.mailData[data.mailId].isClaimed = true
        end
        
        -- 更新当前选中邮件数据
        if self.currentSelectedMail and self.currentSelectedMail.id == data.mailId then
            self.currentSelectedMail.data.isClaimed = true
            self:UpdateDetailButtons(self.currentSelectedMail.data)
        end
        
        -- 刷新列表
        self:UpdateMailList()
        
        gg.log("附件领取成功", data.mailId)
    else
        gg.log("附件领取失败", data.error or "未知错误")
    end
end

-- 处理批量领取响应
function MailGui:HandleBatchClaimResponse(data)
    gg.log("收到批量领取响应", data)
    
    if data.success then
        -- 更新所有相关邮件的状态
        if data.claimedMailIds then
            for _, mailId in ipairs(data.claimedMailIds) do
                if self.mailData[mailId] then
                    self.mailData[mailId].isClaimed = true
                end
            end
        end
        
        -- 更新当前选中邮件数据
        if self.currentSelectedMail then
            self:UpdateDetailButtons(self.currentSelectedMail.data)
        end
        
        -- 刷新列表
        self:UpdateMailList()
        
        gg.log("批量领取成功", data.claimedCount or 0, "封邮件")
    else
        gg.log("批量领取失败", data.error or "未知错误")
    end
end

-- 打开界面时请求邮件数据
function MailGui:OnOpen()
    gg.log("MailGui打开，请求邮件数据")
    
    -- 请求服务端同步邮件数据
    gg.network_channel:FireServer({
        cmd = "MAIL_SYNC_REQUEST"
    })
end

return MailGui.New(script.Parent, uiConfig)