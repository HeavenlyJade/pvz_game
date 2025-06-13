local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
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
    gg.log("郵箱closeButton", self.closeButton)
    self.mailCategoryList = self:Get("邮箱分类", ViewList) ---@type ViewList
    self.mailBackground = self:Get("邮箱背景", ViewComponent) ---@type ViewComponent
    self.mailListFrame = self:Get("邮箱背景/邮件列表框", ViewComponent) ---@type ViewComponent

    -- 邮件详情相关UI
    self.titleName = self:Get("邮箱背景/Title", ViewComponent) ---@type ViewComponent
    self.title = self:Get("邮箱背景/Title", ViewComponent) ---@type ViewComponent
    self.sendTimeTitle = self:Get("邮箱背景/副Title_发送时间", ViewComponent) ---@type ViewComponent
    self.deadlineTitle = self:Get("邮箱背景/副Title_截止时间", ViewComponent) ---@type ViewComponent
    self.contentText = self:Get("邮箱背景/正文内容", ViewComponent) ---@type ViewComponent
    self.senderInfo = self:Get("邮箱背景/发送人", ViewComponent) ---@type ViewComponent

    -- 功能按钮
    self.claimButton = self:Get("邮箱背景/领取", ViewButton) ---@type ViewButton
    self.batchClaimButton = self:Get("邮箱背景/一键领取", ViewButton) ---@type ViewButton
    self.deleteButton = self:Get("邮箱背景/删除邮件", ViewButton) ---@type ViewButton

    -- 奖励显示器 - 改为ViewList
    self.rewardDisplay = self:Get("邮件物品", ViewList) ---@type ViewList

    -- 邮件列表相关
    self.mailList = self:Get("邮箱背景/邮件列表框/邮件列表", ViewList) ---@type ViewList

    -- 数据存储
    self.mailData = {} ---@type table<string, table> -- 邮件数据
    self.currentSelectedMail = nil ---@type table -- 当前选中的邮件
    self.currentCategory = "全部" ---@type string -- 当前选中的分类
    self.mailButtons = {} ---@type table<string, ViewButton> -- 邮件按钮缓存

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

    -- 存储分类信息的table
    self.categoryData = {}
    self.categoryButtons = {}

    -- 获取邮箱分类下的所有子项
    local categoryCount = self.mailCategoryList:GetChildCount()

    for i = 1, categoryCount do
        local categoryItem = self.mailCategoryList:GetChild(i)
        if categoryItem then
            -- 获取分类名称
            local categoryName = ""
            if categoryItem.node and categoryItem.node["Text"] and categoryItem.node["Text"].Title then
                categoryName = categoryItem.node["Text"].Title
            else
                -- 如果没有找到Text节点，尝试其他可能的文本节点
                categoryName = self:GetCategoryNameFromNode(categoryItem.node) or ("分类" .. i)
            end

            -- 存储分类信息
            local categoryInfo = {
                index = i,
                name = categoryName,
                node = categoryItem.node,
                isSelected = false
            }

            table.insert(self.categoryData, categoryInfo)

            -- 创建按钮并绑定事件
            local button = ViewButton.New(categoryItem.node, self)
            button.clickCb = function()
                self:OnCategoryClick(categoryName, i)
            end

            -- 存储按钮引用
            self.categoryButtons[i] = button

            gg.log("发现邮件分类:", categoryName, "索引:", i)
        end
    end

    -- 默认选中第一个分类
    if #self.categoryData > 0 then
        self:OnCategoryClick(self.categoryData[1].name, 1)
    end

    gg.log("邮件分类初始化完成，共找到", #self.categoryData, "个分类")
end

-- 从节点中获取分类名称的辅助函数
function MailGui:GetCategoryNameFromNode(node)
    if not node then return nil end

    -- 尝试多种可能的文本节点名称
    local textNodeNames = {"Text", "Title", "Label", "Name"}

    for _, nodeName in ipairs(textNodeNames) do
        if node[nodeName] and node[nodeName].Title then
            return node[nodeName].Title
        end
    end

    -- 递归查找子节点
    ---for _, child in pairs(node) do
    --    if type(child) == "table" and child.Title then
     --       return child.Title
     --   end
    --end

    return nil
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
    -- 监听邮件列表响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.MAIL_LIST, function(data)
        self:HandleMailListResponse(data)
    end)

    -- 监听邮件删除响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.DELETE_SUCCESS, function(data)
        self:HandleDeleteResponse(data)
    end)

    -- 监听邮件领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.CLAIM_SUCCESS, function(data)
        self:HandleClaimResponse(data)
    end)

    -- 监听批量领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS, function(data)
        self:HandleBatchClaimResponse(data)
    end)

    -- 监听邮件阅读响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.READ_SUCCESS, function(data)
        self:HandleReadResponse(data)
    end)

    -- 监听新邮件通知
    ClientEventManager.Subscribe(MailEventConfig.NOTIFY.NEW_MAIL, function(data)
        self:HandleNewMailNotification(data)
    end)

    -- 监听邮件同步通知
    ClientEventManager.Subscribe(MailEventConfig.NOTIFY.MAIL_SYNC, function(data)
        self:HandleMailSync(data)
    end)

    gg.log("MailGui事件注册完成，共注册", 7, "个事件处理器")
end

-- 分类点击事件
function MailGui:OnCategoryClick(categoryName, categoryIndex)
    gg.log("点击邮件分类:", categoryName, "索引:", categoryIndex)
    self.currentCategory = categoryName

    -- 更新分类选中状态
    for i, categoryInfo in ipairs(self.categoryData) do
        categoryInfo.isSelected = (i == categoryIndex)

        -- 可以在这里添加视觉反馈，比如改变按钮颜色或状态
        if self.categoryButtons[i] then
            -- 这里可以设置选中/未选中的视觉效果
            -- 例如：self.categoryButtons[i]:SetSelected(categoryInfo.isSelected)
        end
    end

    -- 清空当前选中的邮件
    self.currentSelectedMail = nil
    self:HideMailDetail()

    -- 刷新邮件列表
    self:UpdateMailList()

    gg.log("已选中分类:", categoryName)
end

-- 处理邮件列表响应
function MailGui:HandleMailListResponse(data)
    gg.log("收到邮件列表响应", data)

    if not data then
        gg.log("邮件列表响应数据为空")
        return
    end

    -- 合并个人邮件和全服邮件
    local allMails = {}

    -- 处理个人邮件
    if data.personal_mails then
        for _, mail in ipairs(data.personal_mails) do
            mail.mail_type = "personal"
            allMails[mail.id] = mail
        end
    end

    -- 处理全服邮件
    if data.global_mails then
        for _, mail in ipairs(data.global_mails) do
            mail.mail_type = "global"
            allMails[mail.id] = mail
        end
    end

    -- 更新本地邮件数据
    self.mailData = allMails

    -- 刷新邮件列表显示
    self:UpdateMailList()

    gg.log("邮件列表响应处理完成，邮件总数:", self:GetMailCount())
end

-- 处理新邮件通知
function MailGui:HandleNewMailNotification(data)
    gg.log("收到新邮件通知", data)

    -- 如果界面是打开状态，自动刷新邮件列表
    if self:IsVisible() then
        self:OnOpen()
    end
end

-- 处理阅读邮件响应
function MailGui:HandleReadResponse(data)
    gg.log("收到阅读邮件响应", data)

    if data.success and data.mail_data then
        -- 更新本地邮件状态
        if self.mailData[data.mail_id] then
            self.mailData[data.mail_id].is_read = true
            self.mailData[data.mail_id].status = 1 -- 已读状态
        end

        -- 如果当前显示的是这封邮件，更新详情显示
        if self.currentSelectedMail and self.currentSelectedMail.id == data.mail_id then
            self.currentSelectedMail.data = data.mail_data
            self:ShowMailDetail(data.mail_data)
        end
    end
end

-- 获取邮件总数
function MailGui:GetMailCount()
    local count = 0
    for _ in pairs(self.mailData) do
        count = count + 1
    end
    return count
end

-- 处理邮件同步通知
function MailGui:HandleMailSync(data)
    gg.log("收到邮件同步通知", data)

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
    if not self.mailListFrame or not self.mailList then
        gg.log("❌ 邮件列表框或邮件列表ViewList未找到")
        return
    end

    -- 清空当前选中
    self.currentSelectedMail = nil
    self:HideMailDetail()

    -- 过滤符合当前分类的邮件
    local filteredMails = self:FilterMailsByCategory(self.currentCategory)

    -- 创建邮件列表项
    self:CreateMailListItems(filteredMails)

    -- 更新一键领取按钮状态
    if self.batchClaimButton then
        local hasUnclaimedMails = self:HasUnclaimedMails()
        self.batchClaimButton:SetVisible(hasUnclaimedMails)
        self.batchClaimButton:SetTouchEnable(hasUnclaimedMails)
    end

    gg.log("📧 邮件列表更新完成，当前分类:", self.currentCategory, "邮件数量:", #filteredMails)
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
    if not self.mailList then
        gg.log("❌ 邮件列表ViewList未找到")
        return
    end

    -- 清空之前的按钮缓存
    self.mailButtons = {}

    -- 设置列表行数
    local mailCount = #filteredMails
    if mailCount == 0 then
        gg.log("📧 当前分类无邮件")
        return
    end

    -- 更新ViewList的LineCount
    self.mailList.node.LineCount = mailCount

    for i, mailItem in ipairs(filteredMails) do
        -- 创建或更新邮件项
        self:CreateMailListItem(i, mailItem.id, mailItem.data)
    end

    gg.log("📧 创建邮件列表完成，共", mailCount, "封邮件")
end

-- 设置邮件项显示信息
function MailGui:SetupMailItemDisplay(itemNode, mailInfo)
    if not itemNode then return end

    -- 设置邮件标题
    local titleNode = itemNode["邮件标题"] or itemNode["Title"] or itemNode["标题"]
    if titleNode and titleNode.Title then
        titleNode.Title = mailInfo.title or "无标题"
    end

    -- 设置发送人
    local senderNode = itemNode["发送人"] or itemNode["Sender"]
    if senderNode and senderNode.Title then
        senderNode.Title = mailInfo.sender or "系统"
    end

    -- 设置发送时间
    local timeNode = itemNode["发送时间"] or itemNode["Time"]
    if timeNode and timeNode.Title then
        timeNode.Title = mailInfo.sendTime or ""
    end

    -- 设置未读标识
    local unreadNode = itemNode["未读标记"] or itemNode["Unread"]
    if unreadNode then
        unreadNode.Visible = not mailInfo.isRead
    end

    -- 设置附件标识
    local attachmentNode = itemNode["附件标记"] or itemNode["Attachment"]
    if attachmentNode then
        attachmentNode.Visible = mailInfo.hasAttachment and not mailInfo.isClaimed
    end

    -- 设置已领取标识
    local claimedNode = itemNode["已领取标记"] or itemNode["Claimed"]
    if claimedNode then
        claimedNode.Visible = mailInfo.hasAttachment and mailInfo.isClaimed
    end

    gg.log("📧 设置邮件项显示:", mailInfo.title, "未读:", not mailInfo.isRead, "有附件:", mailInfo.hasAttachment)
end

-- 创建单个邮件列表项
function MailGui:CreateMailListItem(index, mailId, mailInfo)
    if not self.mailList then return end

    -- 获取对应位置的列表项
    local listItem = self.mailList:GetChild(index)
    if not listItem or not listItem.node then
        gg.log("❌ 无法获取邮件列表项:", index)
        return
    end

    local itemNode = listItem.node

    -- 设置邮件基本信息
    self:SetupMailItemDisplay(itemNode, mailInfo)

    -- 创建按钮并绑定点击事件
    local button = ViewButton.New(itemNode, self)
    button.extraParams = {
        mailId = mailId,
        mailInfo = mailInfo
    }

    button.clickCb = function(ui, btn)
        self:OnMailItemClick(btn.extraParams.mailId, btn.extraParams.mailInfo)
    end

    -- 缓存按钮引用
    self.mailButtons[mailId] = button

    gg.log("✅ 创建邮件项成功:", index, mailId, mailInfo.title or "无标题")
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
    if self.sendTimeTitle then self.sendTimeTitle:SetVisible(false) end
    if self.deadlineTitle then self.deadlineTitle:SetVisible(false) end
    if self.contentText then self.contentText:SetVisible(false) end
    if self.senderInfo then self.senderInfo:SetVisible(false) end
    if self.claimButton then self.claimButton:SetVisible(false) end
    if self.deleteButton then self.deleteButton:SetVisible(false) end
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
end

-- 处理奖励数据，转换为统一格式
function MailGui:ProcessRewardData(rewards)
    local rewardItems = {}

    if type(rewards) == "table" then
        for itemName, amount in pairs(rewards) do
            if amount > 0 then
                table.insert(rewardItems, {
                    itemName = itemName,
                    amount = amount,
                    icon = self:GetItemIcon(itemName), -- 获取物品图标
                    displayName = self:GetItemDisplayName(itemName) -- 获取物品显示名称
                })
            end
        end
    end

    -- 按物品名称排序
    table.sort(rewardItems, function(a, b)
        return a.itemName < b.itemName
    end)

    gg.log("🎁 处理奖励数据完成，共", #rewardItems, "个物品")
    return rewardItems
end

-- 创建单个奖励物品显示
function MailGui:CreateRewardItem(index, rewardItem)
    if not self.rewardDisplay then return end

    -- 获取对应位置的列表项
    local listItem = self.rewardDisplay:GetChild(index)
    if not listItem or not listItem.node then
        gg.log("❌ 无法获取奖励列表项:", index)
        return
    end

    local itemNode = listItem.node

    -- 设置物品图标
    local iconNode = itemNode["物品图标"] or itemNode["Icon"] or itemNode["图标"]
    if iconNode and rewardItem.icon and rewardItem.icon ~= "" then
        iconNode.Icon = rewardItem.icon
    end

    -- 设置物品名称
    local nameNode = itemNode["物品名称"] or itemNode["Name"] or itemNode["名称"]
    if nameNode and nameNode.Title then
        nameNode.Title = rewardItem.displayName or rewardItem.itemName
    end

    -- 设置物品数量
    local amountNode = itemNode["物品数量"] or itemNode["Amount"] or itemNode["数量"]
    if amountNode and amountNode.Title then
        amountNode.Title = "x" .. rewardItem.amount
    end

    gg.log("✅ 创建奖励物品:", index, rewardItem.itemName, "数量:", rewardItem.amount)
end

-- 获取物品图标（需要根据实际的物品配置系统来实现）
function MailGui:GetItemIcon(itemName)
    -- 这里需要根据实际的物品配置来获取图标
    -- 示例实现，实际需要从物品配置表获取
    local defaultIcons = {
        ["金币"] = "sandboxId://textures/ui/items/coin.png",
        ["钻石"] = "sandboxId://textures/ui/items/diamond.png",
        ["经验"] = "sandboxId://textures/ui/items/exp.png",
    }

    return defaultIcons[itemName] or "sandboxId://textures/ui/items/default.png"
end

-- 获取物品显示名称（需要根据实际的物品配置系统来实现）
function MailGui:GetItemDisplayName(itemName)
    -- 这里需要根据实际的物品配置来获取显示名称
    -- 示例实现，实际需要从物品配置表获取
    local displayNames = {
        ["金币"] = "金币",
        ["钻石"] = "钻石",
        ["经验"] = "经验值",
    }

    return displayNames[itemName] or itemName
end

-- 显示奖励信息
function MailGui:ShowRewards(rewards)
    if not self.rewardDisplay or not rewards then
        gg.log("❌ 奖励显示器或奖励数据为空")
        return
    end

    self.rewardDisplay:SetVisible(true)

    -- 处理奖励数据
    local rewardItems = self:ProcessRewardData(rewards)
    if #rewardItems == 0 then
        gg.log("⚠️ 没有有效的奖励物品")
        self.rewardDisplay:SetVisible(false)
        return
    end

    -- 设置ViewList的行数
    self.rewardDisplay.node.LineCount = #rewardItems

    -- 创建奖励物品显示
    for i, rewardItem in ipairs(rewardItems) do
        self:CreateRewardItem(i, rewardItem)
    end

    gg.log("🎁 显示邮件奖励完成，共", #rewardItems, "个物品")
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
        cmd = MailEventConfig.REQUEST.BATCH_CLAIM,
        category = self.currentCategory
    })
end

-- 发送删除请求
function MailGui:SendDeleteRequest(mailId)
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.DELETE_MAIL,
        mailId = mailId
    })
end

-- 发送领取请求
function MailGui:SendClaimRequest(mailId)
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.CLAIM_MAIL,
        mailId = mailId
    })
end

-- 发送标记已读请求
function MailGui:SendMarkAsReadRequest(mailId)
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.READ_MAIL,
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
        cmd = MailEventConfig.REQUEST.GET_LIST
    })
end

return MailGui.New(script.Parent, uiConfig)
