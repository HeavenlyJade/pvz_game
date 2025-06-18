local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
local TimeUtils = require(MainStorage.code.common.func_utils.time_utils) ---@type TimeUtils
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

local uiConfig = {
    uiName = "MailGui",
    layer = 3,
    hideOnInit = true,
}

-- 邮件类型常量
local MAIL_TYPE = {
    PLAYER = "玩家",
    SYSTEM = "系统"
}

---@class MailGui:ViewBase
local MailGui = ClassMgr.Class("MailGui", ViewBase)

---@override
function MailGui:OnInit(node, config)
    -- UI组件初始化
    self.closeButton = self:Get("关闭", ViewButton) ---@type ViewButton
    self.mailCategoryList = self:Get("邮箱分类", ViewList) ---@type ViewList
    self.mailBackground = self:Get("邮箱背景", ViewComponent) ---@type ViewComponent
    self.mailListFrame = self:Get("邮箱背景/邮件列表框", ViewComponent) ---@type ViewComponent
    self.mailSystemButtom =    self:Get("邮箱分类/系统邮件", ViewButton) ---@type ViewButton
    self.mailPlayerButtom =    self:Get("邮箱分类/玩家邮件", ViewButton) ---@type ViewButton

    -- 邮件内容面板
    self.mailContentPanel = self:Get("邮箱背景/邮件内容", ViewComponent) ---@type ViewComponent


    -- 功能按钮 (基于邮件内容面板)
    self.claimButton = self:Get("邮箱背景/邮件内容/领取", ViewButton) ---@type ViewButton
    self.batchClaimButton = self:Get("邮箱背景/一键领取", ViewButton) ---@type ViewButton
    self.deleteButton = self:Get("邮箱背景/删除邮件", ViewButton) ---@type ViewButton

    -- 奖励显示器
    self.rewardDisplay = self:Get("邮箱背景/邮件内容/附件", ViewComponent) ---@type ViewComponent
    self.rewardListTemplate = self:Get("邮箱背景/邮件内容/附件/附件模板", ViewList) ---@type ViewList
    self.rewardItemTemplate = self:Get("邮箱背景/邮件内容/附件/附件模板/素材_1", ViewComponent) ---@type ViewComponent

    -- 邮件列表及模板
    self.mailItemTemplateList = self:Get("邮箱背景/邮件列表框/模板", ViewList) ---@type ViewList

    self.mailItemTemplate = self:Get("邮箱背景/邮件列表框/模板/邮件_1", ViewComponent)
    self.mailSystemList = self:Get("邮箱背景/邮件列表框/系统邮件", ViewList) ---@type ViewList
    self.mailPlayerList = self:Get("邮箱背景/邮件列表框/玩家邮件", ViewList) ---@type ViewList

    self.mailItemTemplateList:SetVisible(false)
    self.rewardDisplay:SetVisible(false)
    self.rewardListTemplate:SetVisible(false)

    -- 数据存储
    self.playerMails = {} ---@type table<string, MailData> -- 玩家邮件数据（mail_type为"玩家"的邮件）
    self.systemMails = {} ---@type table<string, MailData> -- 系统邮件数据（mail_type非"玩家"的邮件）
    self.currentSelectedMail = nil ---@type table -- 当前选中的邮件
    self.currentCategory = "系统邮件" ---@type string -- 当前选中的分类：系统邮件、玩家邮件
    self.mailButtons = {} ---@type table<string, ViewButton> -- 邮件按钮缓存
    self.attachmentLists = {} ---@type table<string, ViewComponent>

    -- 初始化UI状态
    self:InitializeUI()

    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()

    -- 默认显示系统邮件
    self:SwitchCategory("系统邮件")
end

-- 初始化UI状态
function MailGui:InitializeUI()
    -- 初始时隐藏邮件详情面板和奖励列表
    if self.mailContentPanel then self.mailContentPanel:SetVisible(false) end
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
    gg.log("MailGui UI初始化完成")

    -- 刷新邮件列表
    self:UpdateMailList()
end

-- 切换邮件分类
function MailGui:SwitchCategory(categoryName)
    gg.log("切换邮件分类:", categoryName)
    self.currentCategory = categoryName

    -- 根据分类切换列表的可见性
    if categoryName == "系统邮件" then
        self.mailSystemList:SetVisible(true)
        self.mailPlayerList:SetVisible(false)
        -- TODO: 更新按钮选中状态
    elseif categoryName == "玩家邮件" then
        self.mailSystemList:SetVisible(false)
        self.mailPlayerList:SetVisible(true)
        -- TODO: 更新按钮选中状态
    end

    -- 清空当前选中的邮件并隐藏详情
    self.currentSelectedMail = nil
    -- self:HideMailDetail()

    -- 刷新邮件列表
    self:UpdateMailList()
end

-- 清空邮件列表的UI节点
function MailGui:ClearMailList(targetList)
    if not targetList or not targetList.node then return end

    -- 创建一个临时表来持有子节点，以避免在迭代时修改集合
    local childrenToDestroy = {}
    for _, child in pairs(targetList.node.Children) do
        table.insert(childrenToDestroy, child)
    end

    for _, child in ipairs(childrenToDestroy) do
        child:Destroy()
    end
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

    -- 分类切换按钮
    if self.mailSystemButtom then
        self.mailSystemButtom.clickCb = function()
            self:SwitchCategory("系统邮件")
        end
    end
    if self.mailPlayerButtom then
        self.mailPlayerButtom.clickCb = function()
            self:SwitchCategory("玩家邮件")
        end
    end

    -- 刷新邮件列表显示
    self:UpdateMailList()
end

-- 注册服务端事件
function MailGui:RegisterEvents()
    -- 监听邮件列表响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.LIST_RESPONSE, function(data)
        self:HandleMailListResponse(data)
    end)

    -- 监听邮件删除响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.DELETE_RESPONSE, function(data)
        self:HandleDeleteResponse(data)
    end)

    -- 监听邮件领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.CLAIM_RESPONSE, function(data)
        self:HandleClaimResponse(data)
    end)

    -- 监听批量领取响应
    ClientEventManager.Subscribe(MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS, function(data)
        self:HandleBatchClaimResponse(data)
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

-- 处理邮件列表响应
function MailGui:HandleMailListResponse(data)
    gg.log("收到邮件列表响应", data)

    if not data then
        gg.log("邮件列表响应数据为空")
        return
    end

    -- 清空现有邮件数据
    self:ClearAllAttachmentLists()
    self.playerMails = {}
    self.systemMails = {}

    -- 处理个人邮件，根据mail_type分类
    if data.personal_mails then
        for mailId, mailInfo in pairs(data.personal_mails) do
            if mailInfo.mail_type == MAIL_TYPE.PLAYER then
                self.playerMails[mailId] = mailInfo
            else
                self.systemMails[mailId] = mailInfo
            end
        end
    end

    -- 处理全服邮件，根据mail_type分类
    if data.global_mails then
        for mailId, mailInfo in pairs(data.global_mails) do
            if mailInfo.mail_type == MAIL_TYPE.PLAYER then
                self.playerMails[mailId] = mailInfo
            else
                self.systemMails[mailId] = mailInfo
            end
        end
    end

    -- 为所有带附件的邮件创建附件列表

    for mailId, mailInfo in pairs(self.playerMails) do
        if mailInfo.has_attachment and mailInfo.attachments then
            self:CreateAttachmentListForMail(mailId, mailInfo)
        end
    end
    for mailId, mailInfo in pairs(self.systemMails) do
        gg.log("系统邮件",mailId,mailInfo)
        if mailInfo.has_attachment and mailInfo.attachments then
            self:CreateAttachmentListForMail(mailId, mailInfo)
        end
    end

    -- 刷新邮件列表显示
    self:UpdateMailList()

    gg.log("邮件列表响应处理完成，玩家邮件:", self:GetMailCount(self.playerMails), "系统邮件:", self:GetMailCount(self.systemMails))
end

-- 处理新邮件通知
function MailGui:HandleNewMailNotification(data)
    gg.log("收到新邮件通知", data)

    -- 如果界面是打开状态，自动刷新邮件列表
    if self:IsVisible() then
        self:OnOpen()
    end
end

-- 获取邮件总数
function MailGui:GetMailCount(mailTable)
    local count = 0
    if mailTable then
        for _ in pairs(mailTable) do
            count = count + 1
        end
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

    -- 清空现有邮件数据
    self:ClearAllAttachmentLists()
    self.playerMails = {}
    self.systemMails = {}

    -- 处理个人邮件，根据mail_type分类
    if data.mails.personal_mails then
        for mailId, mailInfo in pairs(data.mails.personal_mails) do
            if mailInfo.mail_type == MAIL_TYPE.PLAYER then
                self.playerMails[mailId] = mailInfo
            else
                self.systemMails[mailId] = mailInfo
            end
        end
    end

    -- 处理全服邮件，根据mail_type分类
    if data.mails.global_mails then
        for mailId, mailInfo in pairs(data.mails.global_mails) do
            if mailInfo.mail_type == MAIL_TYPE.PLAYER then
                self.playerMails[mailId] = mailInfo
            else
                self.systemMails[mailId] = mailInfo
            end
        end
    end

    -- 为所有带附件的邮件创建附件列表
    for mailId, mailInfo in pairs(self.playerMails) do
        if mailInfo.has_attachment and mailInfo.rewards then
            self:CreateAttachmentListForMail(mailId, mailInfo)
        end
    end
    for mailId, mailInfo in pairs(self.systemMails) do
        if mailInfo.has_attachment and mailInfo.rewards then
            self:CreateAttachmentListForMail(mailId, mailInfo)
        end
    end

    -- 刷新邮件列表显示
    self:UpdateMailList()
end

-- 更新邮件列表显示
function MailGui:UpdateMailList()
    if not self.mailItemTemplate then
        gg.log("❌ 邮件列表模板未找到，无法更新列表")
        return
    end

    -- 清空当前选中
    self.currentSelectedMail = nil
    self:HideMailDetail()

    -- 清空UI列表和按钮缓存
    self:ClearMailList(self.mailSystemList)
    self:ClearMailList(self.mailPlayerList)
    self.mailButtons = {}

    -- 排序邮件
    local sortedSystemMails = self:SortMails(self.systemMails)
    local sortedPlayerMails = self:SortMails(self.playerMails)

    -- 填充列表
    self:PopulateMailList(self.mailSystemList, sortedSystemMails)
    self:PopulateMailList(self.mailPlayerList, sortedPlayerMails)

    -- 更新一键领取按钮状态
    if self.batchClaimButton then
        local hasUnclaimedMails = self:HasUnclaimedMails()
        self.batchClaimButton:SetVisible(hasUnclaimedMails)
        self.batchClaimButton:SetTouchEnable(hasUnclaimedMails)
    end

    gg.log("📧 所有邮件列表更新完成")
end

-- 对邮件进行排序
function MailGui:SortMails(mailTable)
    local sorted = {}
    if not mailTable then return sorted end

    for mailId, mailInfo in pairs(mailTable) do
        table.insert(sorted, {id = mailId, data = mailInfo})
    end

    -- 按时间倒序排序 (最新的在前)
    table.sort(sorted, function(a, b)
        -- 使用send_time字段进行排序，如果没有则使用timestamp
        local timeA = a.data.send_time or a.data.timestamp or 0
        local timeB = b.data.send_time or b.data.timestamp or 0
        return timeA > timeB
    end)

    return sorted
end

-- 填充邮件列表
function MailGui:PopulateMailList(targetList, mailArray)
    if not targetList then
        gg.log("❌ 邮件列表ViewList未找到")
        return
    end

    for _, mailItem in ipairs(mailArray) do
        -- 创建或更新邮件项
        self:CreateMailListItem(targetList, mailItem.id, mailItem.data)
    end

    gg.log("📧 邮件列表填充完成, 列表: ", targetList.node.Name, "数量:", #mailArray)
end

-- 设置邮件项显示信息
function MailGui:SetupMailItemDisplay(itemNode, mailInfo)
    if not itemNode then return end

    -- 主标题显示邮件的title
    local titleNode = itemNode["主标题"]
    if titleNode and titleNode.Title then
        titleNode.Title = mailInfo.title or "无标题"
    end

    -- 来自谁显示sender这个字段
    local senderNode = itemNode["来自谁"]
    if senderNode and senderNode.Title then
        senderNode.Title = "来自: " .. (mailInfo.sender or "系统")
    end

    -- new: 根据是否有附件且未领取来判断
    local newNode = itemNode["new"]
    if newNode then
        -- 只对有附件的邮件显示"新"标记，直到附件被领取
        if mailInfo.has_attachment then
            newNode.Visible = not mailInfo.is_claimed
        else
            newNode.Visible = false
        end
    end

    -- 是否有物品: 根据是否有附件来判断
    local attachmentNode = itemNode["是否有物品"]
    if attachmentNode then
        attachmentNode.Visible = mailInfo.has_attachment
    end

    gg.log("📧 设置邮件项显示:", mailInfo.title, "有附件:", mailInfo.has_attachment)
end

-- 创建单个邮件列表项
function MailGui:CreateMailListItem(targetList, mailId, mailInfo)
    if not targetList or not self.mailItemTemplate then return end

    -- 从模板克隆新节点
    local itemNode = self.mailItemTemplate.node:Clone()
    itemNode:SetParent(targetList.node)
    itemNode.Visible = true -- 确保克隆出来的节点是可见的

    -- 将列表项节点的名字设置为邮件ID，方便调试
    itemNode.Name = mailId

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

    gg.log("✅ 创建邮件项成功:", mailId, mailInfo.title or "无标题")
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
end

-- 显示邮件详情
function MailGui:ShowMailDetail(mailInfo)
    -- 显示邮件详情面板
    gg.log("mailInfo邮件的切换数据",mailInfo)
    if self.mailContentPanel then self.mailContentPanel:SetVisible(true) end
    local mailContentPanelNode = self.mailContentPanel.node
    local titleNode = mailContentPanelNode["Title"]
    if titleNode then
        -- 直接设置文本控件的Title属性
        titleNode.Title = mailInfo.title or "无标题"
    end

    local sendTimeTitleNode = mailContentPanelNode["发送时间"]
    if sendTimeTitleNode then
        sendTimeTitleNode.Title = "发送时间: " .. TimeUtils.FormatTimestamp(mailInfo.send_time)
    end

    local deadlineTitleNode = mailContentPanelNode["截止时间"]
    if deadlineTitleNode then
        deadlineTitleNode.Title = "截止时间: " .. TimeUtils.FormatTimestamp(mailInfo.expire_time)
    end

    local contentTextNode = mailContentPanelNode["正文内容"]
    if contentTextNode then
        contentTextNode.Title = mailInfo.content or "无内容"
    end

    local senderInfoNode = mailContentPanelNode["发送人"]
    if senderInfoNode then
        senderInfoNode.Title = "发送人: " .. (mailInfo.sender or "系统")
    end

    -- 更新按钮状态
    self:UpdateDetailButtons(mailInfo)

    -- 隐藏所有附件列表，然后显示当前邮件的附件列表
    self:HideAllAttachmentLists()
    if mailInfo.has_attachment then
        if self.rewardDisplay then self.rewardDisplay:SetVisible(true) end
        local attachmentList = self.attachmentLists[tostring(mailInfo.id)]
        if attachmentList then
            attachmentList:SetVisible(true)
            -- 根据领取状态更新附件外观
            self:UpdateAttachmentListAppearance(mailInfo.id, mailInfo.is_claimed)
        else
            gg.log("⚠️ 找不到邮件对应的附件列表:", mailInfo.id)
        end
    end

    gg.log("邮件详情显示完成")
end

-- 隐藏邮件详情
function MailGui:HideMailDetail()
    if self.mailContentPanel then self.mailContentPanel:SetVisible(false) end
    self:HideAllAttachmentLists()
end

-- 新增：隐藏所有附件列表
function MailGui:HideAllAttachmentLists()
    if self.rewardDisplay then self.rewardDisplay:SetVisible(false) end
    if self.attachmentLists then
        for _, listComponent in pairs(self.attachmentLists) do
            if listComponent then
                listComponent:SetVisible(false)
            end
        end
    end
end

--- 更新附件列表外观（是否置灰）
function MailGui:UpdateAttachmentListAppearance(mailId, isClaimed)
    local attachmentList = self.attachmentLists[tostring(mailId)]
    if not attachmentList or not attachmentList.node or not attachmentList.node.IsValid then
        return
    end

    -- 使用引擎内置的Grayed属性来置灰/取消置灰整个附件列表节点
    attachmentList.node.Grayed = isClaimed
end

-- 新增：清空所有已生成的附件列表
function MailGui:ClearAllAttachmentLists()
    if self.attachmentLists then
        for mailId, listComponent in pairs(self.attachmentLists) do
            if listComponent and listComponent.node and listComponent.node.IsValid then
                listComponent.node:Destroy()
            end
        end
    end
    self.attachmentLists = {}
end

-- 新增：为单个邮件创建其专属的附件列表
function MailGui:CreateAttachmentListForMail(mailId, mailInfo)
    if not self.rewardListTemplate or not self.rewardItemTemplate or not self.rewardDisplay then
        gg.log("❌ 奖励列表模板、项目模板或容器未找到，无法为邮件创建附件列表:", mailId)
        return
    end
    -- 1. 克隆列表容器节点
    local newListContainerNode = self.rewardListTemplate.node:Clone()
    for _, child in ipairs(newListContainerNode.Children) do
        child:Destroy()

    end
    newListContainerNode.Parent =self.rewardDisplay.node
    newListContainerNode.Name = tostring(mailId) -- 使用邮件ID命名

    -- 2. 处理奖励数据
    local rewardItems = self:ProcessRewardData(mailInfo.attachments)
    -- gg.log("创建附件列表",mailId,mailInfo.attachments,rewardItems )
    -- 3. 循环创建附件项并填充
    for _, rewardData in ipairs(rewardItems) do
        gg.log("rewardData",rewardData)
        local newItemNode = self.rewardItemTemplate.node:Clone()
        newItemNode.Parent = newListContainerNode
        newItemNode.Visible = true
        newItemNode.Name = tostring(rewardData.itemName)
        self:SetupRewardItemDisplay(newItemNode, rewardData)
    end

    -- 4. 默认隐藏
    newListContainerNode.Visible = false

    -- 5. 缓存
    self.attachmentLists[tostring(mailId)] = ViewComponent.New(newListContainerNode, self)
    gg.log("✅ 为邮件创建附件列表成功:", mailId)
end

-- 处理奖励数据，转换为统一格式
function MailGui:ProcessRewardData(rewards)
    local rewardItems = {}
    local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig

    if type(rewards) == "table" then
        -- 附件的数据格式是一个 table 数组, e.g., { {type="itemA", amount=1}, {type="itemB", amount=2} }
        -- 因此需要用 ipairs 遍历
        for _, rewardData in ipairs(rewards) do
            -- rewardData 的格式是 { type = "物品名", amount = 数量 }
            local itemName = rewardData.type
            local amount = rewardData.amount
            if itemName and amount and amount > 0 then
                ---@type ItemType
                local itemConfig = ItemTypeConfig.Get(itemName)

                if itemConfig then
                    table.insert(rewardItems, {
                        itemName = itemName,
                        amount = amount,
                        icon = itemConfig.icon,

                    })
                else
                    gg.log("⚠️ 找不到物品配置:", itemName)
                    -- 即使找不到配置，也添加一个默认项，以防显示不全
                    table.insert(rewardItems, {
                        itemName = itemName,
                        amount = amount,
                        icon = nil, -- 使用默认图标

                    })
                end
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

-- 为单个奖励物品设置UI显示
function MailGui:SetupRewardItemDisplay(itemNode, rewardItem)
    if not itemNode then return end

    -- 设置物品图标
    local iconNode = itemNode["图标"]
    gg.log("iconNode",iconNode,rewardItem.icon)
    if iconNode and rewardItem.icon and  rewardItem.icon ~="" then
        -- 如果配置了图标则使用，否则使用默认图标
        iconNode.Icon = rewardItem.icon
    end

    -- 设置物品数量
    local amountNode = itemNode["数量"]
    if amountNode and amountNode.Title then
        amountNode.Title = tostring(rewardItem.amount)
    end
end

-- 更新详情面板按钮状态
function MailGui:UpdateDetailButtons(mailInfo)
    -- 领取按钮：只有有附件时显示，根据是否领取决定是否可交互和置灰
    if self.claimButton then
        local hasAttachment = mailInfo.has_attachment
        self.claimButton:SetVisible(hasAttachment)

        if hasAttachment then
            local canClaim = not mailInfo.is_claimed
            self.claimButton:SetTouchEnable(canClaim)
            -- 使用Grayed属性来置灰/恢复按钮
            -- if self.claimButton.node then
            --     self.claimButton.node.Grayed = not canClaim -- 如果不能领取，则置灰
            -- end
        end
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
    for _, mailInfo in pairs(self.playerMails) do
        if mailInfo.has_attachment and not mailInfo.is_claimed then
            return true
        end
    end
    for _, mailInfo in pairs(self.systemMails) do
        if mailInfo.has_attachment and not mailInfo.is_claimed then
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
    local mailInfo = self.currentSelectedMail.data
    local isGlobal = mailInfo.is_global_mail or false

    gg.log("删除邮件", mailId, "is_global:", isGlobal)

    -- 发送删除请求
    self:SendDeleteRequest(mailId, isGlobal)
end

-- 领取附件
function MailGui:OnClaimReward()
    if not self.currentSelectedMail then
        gg.log("没有选中的邮件")
        return
    end

    local mailId = self.currentSelectedMail.id
    local mailInfo = self.currentSelectedMail.data

    if not mailInfo.has_attachment or mailInfo.is_claimed then
        gg.log("邮件没有附件或已领取")
        return
    end

    local isGlobal = mailInfo.is_global_mail or false
    gg.log("领取附件", mailId, "is_global:", isGlobal)

    -- 发送领取请求
    self:SendClaimRequest(mailId, isGlobal)
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
function MailGui:SendDeleteRequest(mailId, isGlobal)
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.DELETE_MAIL,
        mail_id = mailId,
        is_global = isGlobal
    })
end

-- 发送领取请求
function MailGui:SendClaimRequest(mailId, isGlobal)
    gg.network_channel:FireServer({
        cmd = MailEventConfig.REQUEST.CLAIM_MAIL,
        mail_id = mailId,
        is_global = isGlobal
    })
end

-- 处理删除响应
function MailGui:HandleDeleteResponse(data)
    gg.log("收到删除响应", data)

    if data.success and data.mail_id then
        -- 从本地数据中移除
        if self.playerMails[data.mail_id] then
            self.playerMails[data.mail_id] = nil
        elseif self.systemMails[data.mail_id] then
            self.systemMails[data.mail_id] = nil
        end

        -- 清空当前选中
        self.currentSelectedMail = nil
        self:HideMailDetail()

        -- 刷新列表
        self:UpdateMailList()

        gg.log("邮件删除成功", data.mail_id)
    else
        gg.log("邮件删除失败", data.error or "未知错误")
    end
end

-- 处理领取响应
function MailGui:HandleClaimResponse(data)
    gg.log("收到领取响应", data)

    if data.success and data.mail_id then
        -- 更新本地数据
        if self.playerMails[data.mail_id] then
            self.playerMails[data.mail_id].is_claimed = true
        elseif self.systemMails[data.mail_id] then
            self.systemMails[data.mail_id].is_claimed = true
        end

        -- 更新当前选中邮件数据
        if self.currentSelectedMail and self.currentSelectedMail.id == data.mail_id then
            self.currentSelectedMail.data.is_claimed = true
            self:UpdateDetailButtons(self.currentSelectedMail.data)
            -- 领取成功后，更新附件列表外观
            self:UpdateAttachmentListAppearance(data.mail_id, true)
        end

        -- 刷新列表
        self:UpdateMailList()

        gg.log("附件领取成功", data.mail_id)
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
                if self.playerMails[mailId] then
                    self.playerMails[mailId].is_claimed = true
                elseif self.systemMails[mailId] then
                    self.systemMails[mailId].is_claimed = true
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
