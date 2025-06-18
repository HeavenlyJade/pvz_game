--- 邮件管理器 - 邮件系统的核心模块
--- V109 miniw-haima
--- 负责邮件的创建、发送、阅读、领取附件等操作

local game = game
local pairs = pairs
local ipairs = ipairs
local type = type
local table = table
local os = os
local math = math
local tostring = tostring
local tonumber = tonumber

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local CloudMailDataAccessor = require(MainStorage.code.server.Mail.cloudMailData) ---@type CloudMailDataAccessor
local BagMgr = require(MainStorage.code.server.bag.BagMgr)  ---@type BagMgr
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
local MailBase = require(MainStorage.code.server.Mail.MailBase) ---@type MailBase
local GlobalMailManager = require(MainStorage.code.server.Mail.GlobalMailManager) ---@type GlobalMailManager
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig

---@class MailManager
local MailManager = {
    -- 邮件类型
    MAIL_TYPE = MailEventConfig.MAIL_TYPE,

    -- 邮件状态
    MAIL_STATUS = MailEventConfig.STATUS,

    -- 错误码
    ERROR_CODE = MailEventConfig.ERROR_CODES,
}

--- 初始化邮件管理器
function MailManager:Init()
    -- 初始化全局邮件管理器
    GlobalMailManager:Init()

    -- 注册网络消息处理函数
    self:RegisterNetworkHandlers()

    -- 注册玩家生命周期事件
    self:RegisterLifecycleHandlers()

    gg.log("邮件管理器初始化完成")
    return self
end

--- 注册网络消息处理函数
function MailManager:RegisterNetworkHandlers()
    -- 使用新的邮件前缀命令格式
    ServerEventManager.Subscribe(MailEventConfig.REQUEST.GET_LIST, function(event)
        self:HandleGetMailList(event)
    end)

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.CLAIM_MAIL, function(event)
        self:HandleClaimAttachment(event)
    end)

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.DELETE_MAIL, function(event)
        self:HandleDeleteMail(event)
    end)

    gg.log("邮件网络消息处理函数注册完成")
end

--- 注册玩家生命周期事件
function MailManager:RegisterLifecycleHandlers()
    -- 监听玩家登出事件，为其保存邮件数据
    ServerEventManager.Subscribe("PlayerLogout", function(event)
        local player = gg.server_players_list[event.uin]
        if player and player.mail then
            self:OnPlayerLogout(event.uin, player.mail)
        end
    end)

    gg.log("邮件生命周期事件处理函数注册完成")
end

--- 玩家登出事件处理
---@param uin number 玩家ID
---@param mail_data PlayerMailBundle 邮件数据
function MailManager:OnPlayerLogout(uin, mail_data)
    -- 使用Bundle一次性保存玩家所有邮件数据
    CloudMailDataAccessor:SavePlayerMailBundle(uin, mail_data)
    gg.log("玩家邮件数据保存完成", uin)
end

--- 同步玩家的全服邮件状态
--- 检查是否有新的全服邮件，并为玩家创建对应的状态记录
---@param uin number 玩家ID
---@return boolean 是否有数据更新
function MailManager:SyncGlobalMailsForPlayer(uin)
    local player = gg.getPlayerByUin(uin)
    if not player or not player.mail then return false end

    local allGlobalMails = GlobalMailManager:GetAllGlobalMails()
    local playerGlobalStatus = player.mail.globalMailStatus
    local updated = false

    for mailId, globalMail in pairs(allGlobalMails) do
        -- 检查玩家是否已有该邮件的状态
        if not playerGlobalStatus.statuses[mailId] then
            -- 如果没有，创建新的状态记录，默认为未读
            playerGlobalStatus.statuses[mailId] = {
                status = self.MAIL_STATUS.UNREAD,
                is_claimed = false
            }
            updated = true
            gg.log("为玩家", player.uin, "同步新的全服邮件:", mailId)
        end
    end

    if updated then
        -- 如果有更新，更新时间戳以便保存
        playerGlobalStatus.last_update = os.time()
    end

    return updated
end

---------------------------
-- 邮件创建和ID生成
---------------------------

--- 生成邮件ID
---@param prefix string 前缀，如"mail_p_"或"mail_g_"
---@return string 生成的邮件ID
function MailManager:GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return prefix .. timestamp .. "_" .. random
end

--- 添加邮件到玩家邮箱 (发送个人邮件)
---@param uin number 玩家ID
---@param mailData MailData 邮件数据
---@return string 邮件ID
function MailManager:AddPlayerMail(uin, mailData)
    local player = gg.server_players_list[uin]
    if not player or not player.mail then
        gg.log("添加个人邮件失败：找不到玩家或玩家邮件数据未初始化", uin)
        return nil
    end

    local playerMailContainer = player.mail.playerMail

    -- 为邮件数据补充ID和类型
    mailData.id = self:GenerateMailId("mail_p_")
    mailData.mail_type = self.MAIL_TYPE.PLAYER

    -- 使用MailBase来创建和初始化邮件对象
    local mailObject = MailBase.New(mailData)
    local storageData = mailObject:ToStorageData()

    -- 添加新邮件并保存
    playerMailContainer.mails[storageData.id] = storageData
    playerMailContainer.last_update = os.time()

    -- 注意：这里直接修改了player对象上的table，登出时会自动保存
    -- 如果需要立即保存，可以取消下一行注释
    CloudMailDataAccessor:SavePlayerMail(uin, playerMailContainer)

    gg.log("成功向玩家添加个人邮件", uin, storageData.id)
    return storageData.id
end

--- 1. 新增全局邮件
---@param mailData MailData 邮件数据
---@return string 邮件ID
function MailManager:AddGlobalMail(mailData)
    return GlobalMailManager:AddGlobalMail(mailData)
end

--- 2. 获取所有的全局邮件
---@return table 全局邮件列表
function MailManager:GetAllGlobalMails()
    return GlobalMailManager:GetAllGlobalMails()
end

--- 3. 删除所有的全局邮件
---@return boolean 是否成功
function MailManager:DeleteAllGlobalMails()
    return GlobalMailManager:DeleteAllGlobalMails()
end

--- 4. 删除指定ID的全局邮件
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
function MailManager:DeleteGlobalMailById(mailId)
    return GlobalMailManager:DeleteGlobalMailById(mailId)
end

--- 5. 获取指定ID的全局邮件
---@param mailId string 邮件ID
---@return table|nil 邮件数据，nil表示不存在
function MailManager:GetGlobalMailById(mailId)
    return GlobalMailManager:GetGlobalMailById(mailId)
end

--- 发送个人邮件（便利函数）
---@param recipientUin number 收件人UIN
---@param title string 标题
---@param content string 内容
---@param attachments table 附件列表
---@param senderInfo table 发件人信息
---@return string 邮件ID
function MailManager:SendPersonalMail(recipientUin, title, content, attachments, senderInfo)
    local now = os.time()
    local mailData = {
        title = title,
        content = content,
        sender = senderInfo.name or "系统",
        send_time = now,
        expire_time = now + MailEventConfig.DEFAULT_EXPIRE_DAYS * 86400,
        expire_days = MailEventConfig.DEFAULT_EXPIRE_DAYS,
        status = self.MAIL_STATUS.UNREAD,
        attachments = attachments or {},
        has_attachment = attachments and #attachments > 0 or false
    }
    return self:AddPlayerMail(recipientUin, mailData)
end

--- 发送全服邮件（便利函数）
---@param title string 标题
---@param content string 内容
---@param attachments table 附件列表
---@param expireDays number 过期天数
---@return string 邮件ID
function MailManager:SendGlobalMail(title, content, attachments, expireDays)
    local now = os.time()
    local mailData = {
        title = title,
        content = content,
        sender = "系统",
        send_time = now,
        expire_time = now + (expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS) * 86400,
        expire_days = expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS,
        status = self.MAIL_STATUS.UNREAD,
        attachments = attachments or {},
        has_attachment = attachments and #attachments > 0 or false
    }

    return self:AddGlobalMail(mailData)
end

---------------------------
-- 邮件操作处理函数
---------------------------

--- 处理获取邮件列表请求
---@param event table 事件数据
function MailManager:HandleGetMailList(event)
    if not event or not event.player then return end
    local uin = event.player.uin
    self:SendMailListToClient(uin)
end

--- 发送完整的邮件列表到客户端
---@param uin number 玩家ID
function MailManager:SendMailListToClient(uin)
    local player = gg.getPlayerByUin(uin)

    if not player or not player.mail then
        gg.log("发送邮件列表失败：玩家不存在或邮件数据未初始化", uin)
        return
    end

    -- 获取个人邮件列表
    local personalMails = self:GetPersonalMailList(uin)

    -- 获取全服邮件列表（包含玩家状态）
    local globalMails = GlobalMailManager:GetGlobalMailListForPlayer(uin, player.mail.globalMailStatus)

    -- 发送邮件列表到客户端
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.LIST_RESPONSE,
        personal_mails = personalMails,
        global_mails = globalMails
    })

    gg.log("已向玩家", uin, "发送邮件列表")
end

--- 处理领取附件请求
---@param event table {uin, mail_id, is_global}
function MailManager:HandleClaimAttachment(event)
    if not event or not event.player then return end
    local player = event.player
    local uin = player.uin
    gg.log("领取附件的请求数据",event)

    gg.log("领取附件的请求数据",player,uin)
    if not player then return end

    local mailId = event.mail_id
    local isGlobal = event.is_global


    local success, message, attachments, errorCode

    if isGlobal then
        -- 全局邮件领取
        success, message, attachments, errorCode = GlobalMailManager:ClaimGlobalMailAttachment(player.uin, mailId, player.mail.globalMailStatus)
    else
        -- 个人邮件领取
        success, message, attachments, errorCode = self:ClaimPersonalMail(player, mailId)
    end

    if success then
        gg.log("附件领取成功，开始分发物品", player.name, mailId)
        -- 分发附件
        local distributed, distMessage = self:DistributeAttachments(uin, attachments)

        if distributed then
            -- 立即保存玩家的邮件数据
            if player.mail then
                CloudMailDataAccessor:SavePlayerMailBundle(player.uin, player.mail)
                gg.log("玩家邮件数据已保存", player.uin)
            end

            -- 发送成功响应
            self:SendClaimResponse(uin, true, mailId, distMessage)
        else
            -- 物品分发失败，理论上需要回滚邮件状态，但目前简化处理
            self:SendClaimResponse(uin, false, mailId, distMessage, self.ERROR_CODE.INSUFFICIENT_BAG_SPACE)
        end
    else
        -- 领取失败
        self:SendClaimResponse(uin, false, mailId, message, errorCode)
    end
end

--- 处理删除邮件请求
---@param event table 事件数据
function MailManager:HandleDeleteMail(event)
    if not event or not event.player then return end
    local uin = event.player.uin
    local mailId = event.mail_id
    local isGlobal = event.is_global

    local success, message

    if isGlobal then
        local player = gg.server_players_list[uin]
        if player and player.mail then
            success, message = GlobalMailManager:DeleteGlobalMailForPlayer(uin, mailId, player.mail.globalMailStatus)
        else
            success, message = false, "玩家不存在"
        end
    else
        success, message = self:DeletePersonalMail(uin, mailId)
    end

    -- 发送结果到客户端
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.DELETE_RESPONSE,
        success = success,
        message = message,
        mail_id = mailId,
        is_global = isGlobal
    })
end

---------------------------
-- 个人邮件相关函数
---------------------------

--- 获取个人邮件列表
---@param uin number 玩家ID
---@return table 邮件列表
function MailManager:GetPersonalMailList(uin)
    local player = gg.getPlayerByUin(uin)
    if not player or not player.mail or not player.mail.playerMail then
        return {}
    end

    local playerMails = player.mail.playerMail.mails
    local result = {}

    -- 为客户端创建一个干净的数据副本
    for mailId, mail in pairs(playerMails) do
        -- 深拷贝邮件数据，避免修改原始数据
        local mailCopy = {
            id = mail.id,
            title = mail.title,
            content = mail.content,
            send_time = mail.send_time,
            expire_time = mail.expire_time,
            status = mail.status,
            mail_type = mail.mail_type,
            has_attachment = mail.attachments and #mail.attachments > 0,
            sender = mail.sender,
            attachments = mail.attachments,
            is_claimed = (mail.status == self.MAIL_STATUS.CLAIMED),
            is_global_mail = false -- 明确这是个人邮件
        }
        result[mailId] = mailCopy
    end

    return result
end

--- 领取个人邮件附件
---@param player Player 玩家对象
---@param mailId string 邮件ID
---@return boolean, string, table, number
function MailManager:ClaimPersonalMail(player, mailId)
    if not player then
        return false, "玩家不存在", nil, self.ERROR_CODE.PLAYER_NOT_FOUND
    end

    local mailData = player.mail.playerMail.mails[mailId]
    if not mailData then
        return false, "邮件不存在", nil, self.ERROR_CODE.MAIL_NOT_FOUND
    end

    local mailObject = MailBase.New(mailData)

    -- 使用MailBase中的方法统一检查
    if not mailObject:CanClaimAttachment() then
        if mailObject:IsExpired() then
            return false, "邮件已过期", nil, self.ERROR_CODE.MAIL_EXPIRED
        end
        if not mailObject.has_attachment then
            return false, "邮件没有附件", nil, self.ERROR_CODE.MAIL_NO_ATTACHMENT
        end
        if mailObject:IsClaimed() then
            return false, "附件已领取", nil, self.ERROR_CODE.MAIL_ALREADY_CLAIMED
        end
        return false, "无法领取附件", nil, self.ERROR_CODE.SYSTEM_ERROR
    end

    -- 更新邮件状态
    mailObject:MarkAsClaimed()
    -- mailData现在是mailObject的引用，所以mailData也更新了

    gg.log("个人邮件状态已更新为已领取", mailId)

    -- 直接返回附件列表，由上层处理分发
    return true, "领取成功", mailObject:GetAttachments()
end

--- 删除个人邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
function MailManager:DeletePersonalMail(uin, mailId)
    local player = gg.getPlayerByUin(uin)
    if not player or not player.mail then
        return false, "玩家不存在"
    end

    local mailData = player.mail.playerMail.mails[mailId]
    if not mailData then
        return true, "邮件已删除" -- 如果邮件已经不存在，也算删除成功
    end

    local mailObject = MailBase.New(mailData)

    -- 有未领取的附件时不能删除
    if mailObject:CanClaimAttachment() then
        return false, "请先领取附件"
    end

    -- 记录删除日志
    gg.log("--- 准备物理删除个人邮件 ---")
    gg.log("玩家UIN:", uin)
    gg.log("邮件ID:", mailId)
    gg.log("邮件标题:", mailData.title)

    -- 物理删除邮件
    player.mail.playerMail.mails[mailId] = nil

    return true, "邮件已删除"
end

---------------------------
-- 邮件查询与辅助函数
---------------------------

--- 分发附件给玩家
---@param uin number 玩家ID
---@param attachments table 附件列表
---@return boolean, string // 是否成功, 失败原因
function MailManager:DistributeAttachments(uin, attachments)
    if not attachments or #attachments == 0 then
        return true, "没有附件"
    end

    local player = gg.server_players_list[uin]
    if not player then
        return false, "玩家不存在"
    end

    if not player.bag then
        gg.log("附件分发失败: 玩家背包未初始化 uin:", uin)
        return false, "玩家背包未初始化"
    end

    -- 统一分发
    for _, attachment in ipairs(attachments) do
        ---@class ItemType
        local itemType = ItemTypeConfig.Get(attachment.type)
        if itemType then
            local item = itemType:ToItem(attachment.amount)
            -- 使用玩家自己的背包实例来分发物品
            player.bag:GiveItem(item)
        else
            gg.log("附件分发警告: 找不到物品配置 ->", attachment.type, " for uin:", uin)
        end
    end

    return true, "分发成功"
end

--- 检查玩家是否有未读邮件
---@param uin number 玩家ID
---@return boolean
function MailManager:HasUnreadMail(uin)
    local player = gg.server_players_list[uin]
    if not player or not player.mail then
        return false
    end

    -- 检查个人邮件
    for _, mailData in pairs(player.mail.playerMail.mails) do
        if mailData.status == self.MAIL_STATUS.UNREAD then
            return true
        end
    end

    -- 检查全服邮件
    if GlobalMailManager:HasUnreadGlobalMail(uin, player.mail.globalMailStatus) then
        return true
    end

    return false
end

--- 检查并清理过期的邮件
--- (此函数可以由定时任务周期性调用)

--- 发送领取附件操作的响应
---@param uin number 玩家ID
---@param success boolean 是否成功
---@param mailId string 邮件ID
---@param message string 消息
---@param errorCode number|nil 错误码
function MailManager:SendClaimResponse(uin, success, mailId, message, errorCode)
    gg.log("发送领取附件响应到", uin, "结果:", success)
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.CLAIM_RESPONSE,
        success = success,
        mail_id = mailId,
        error = message,
        error_code = errorCode or self.ERROR_CODE.SUCCESS
    })
end

return MailManager
