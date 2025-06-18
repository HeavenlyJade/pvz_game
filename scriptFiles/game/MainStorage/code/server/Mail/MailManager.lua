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
    self:SendMailListToClient(event.uin)
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
---@param event table 事件数据
function MailManager:HandleClaimAttachment(event)
    local uin = event.uin
    local mailId = event.mail_id
    local isGlobal = event.is_global
    local success, message, attachments

    if isGlobal then
        local player = gg.server_players_list[uin]
        if player and player.mail then
            success, message, attachments = GlobalMailManager:ClaimGlobalMailAttachment(
                uin, mailId, player.mail.globalMailStatus,
                function(playerUin, attachmentList) return self:DistributeAttachments(playerUin, attachmentList) end
            )
        else
            success, message, attachments = false, "玩家不存在", nil
        end
    else
        success, message, attachments = self:ClaimPersonalMailAttachment(uin, mailId)
    end

    -- 发送结果到客户端
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.CLAIM_RESPONSE,
        success = success,
        message = message,
        mail_id = mailId,
        is_global = isGlobal
    })

    -- 如果成功，显示获得的物品
    if success and attachments and #attachments > 0 then
        local itemNames = {}
        for _, attachment in ipairs(attachments) do
            table.insert(itemNames, attachment.type .. " x" .. attachment.amount)
        end

        -- 发送飘字消息
        gg.network_channel:fireClient(uin, {
            cmd = "cmd_client_show_msg",
            txt = "获得物品：" .. table.concat(itemNames, ", "),
            color = {r = 0, g = 255, b = 0, a = 255}
        })
    end
end

--- 处理删除邮件请求
---@param event table 事件数据
function MailManager:HandleDeleteMail(event)
    local uin = event.uin
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
            has_attachment = mail.attachments and #mail.attachments > 0,
            sender = mail.sender,
            attachments = mail.attachments
        }
        result[mailId] = mailCopy
    end

    return result
end

--- 领取个人邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 附件列表
function MailManager:ClaimPersonalMailAttachment(uin, mailId)
    ---@type Player
    local player = gg.server_players_list[uin]
    if not player then
        return false, "玩家不存在", nil
    end

    local mailData = player.mail.playerMail.mails[mailId]
    if not mailData then
        return false, "邮件不存在", nil
    end

    local mailObject = MailBase.New(mailData)

    if not mailObject:CanClaimAttachment() then
        if mailObject:IsExpired() then return false, "邮件已过期", nil end
        if not mailObject.has_attachment then return false, "邮件没有附件", nil end
        if mailObject:IsClaimed() then return false, "附件已领取", nil end
        return false, "无法领取附件", nil
    end

    -- 分发附件给玩家
    local success, reason = self:DistributeAttachments(uin, mailObject:GetAttachments())
    if not success then
        return false, reason or "背包空间不足", nil
    end

    -- 更新邮件状态
    mailObject:MarkAsClaimed()

    return true, "附件已领取", mailObject:GetAttachments()
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
---@return boolean, string 是否成功, 失败原因
function MailManager:DistributeAttachments(uin, attachments)
    if not attachments or #attachments == 0 then
        return true -- 没有附件也算成功
    end

    local player = gg.server_players_list[uin]
    if not player then
        return false, "玩家不存在"
    end

    -- 示例：直接调用背包管理器添加物品
    -- 注意：这里的实现需要根据您的背包系统进行调整
    for _, attachment in ipairs(attachments) do
        local success, reason = BagMgr:AddItem(uin, attachment.type, attachment.amount)
        if not success then
            -- (需要考虑事务回滚)
            return false, reason or "背包空间不足"
        end
    end

    return true
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

return MailManager
