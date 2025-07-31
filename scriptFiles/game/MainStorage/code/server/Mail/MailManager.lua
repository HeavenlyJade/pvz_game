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
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig

---@class SenderInfo
---@field name string 发件人的名字 (例如 "系统" 或 "玩家A")
---@field id number 发件人的唯一ID (约定 0 为系统, 其他为玩家UIN)

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
        self:_handleClaimMail( event)
    end)

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.DELETE_MAIL, function(event)
        self:HandleDeleteMail(event)
    end)

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.BATCH_CLAIM, function(event)
        self:HandleBatchClaim(event)
    end)

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.DELETE_READ_MAILS, function(event)
        self:HandleDeleteReadMails(event)
    end)

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.MARK_READ, function(event)
        self:HandleMarkAsRead(event)
    end)

    -- 处理邮件状态更新请求（用于GameSystem邮件提示）
    ServerEventManager.Subscribe("RequestMailStatusUpdate", function(event)
        self:HandleMailStatusUpdateRequest(event)
    end)

    gg.log("邮件网络消息处理函数注册完成")
end


--- 保存指定玩家的邮件数据到云端
---@param player Player 玩家对象
function MailManager:SavePlayerMails(player)
    if not player or not player.mail then
        gg.log("保存玩家邮件失败：玩家对象或邮件数据为空", player and player.uin)
        return
    end
    CloudMailDataAccessor:SavePlayerMailBundle(player.uin, player.mail)
    gg.log("玩家邮件数据保存完成", player.uin)
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
    local player = gg.getPlayerByUin(uin)
    if not player or not player.mail then
        gg.log("添加个人邮件失败：找不到玩家或玩家邮件数据未初始化", uin)
        return nil
    end

    local playerMailContainer = player.mail.playerMail

    -- 为邮件数据补充ID（保持原有的mail_type不变）
    mailData.id = self:GenerateMailId("mail_p_")
    -- 注意：不再强制设置mail_type，保持调用方传入的值（由发件人类型决定）

    -- 使用MailBase来创建和初始化邮件对象
    local mailObject = MailBase.New(mailData)
    local storageData = mailObject:ToStorageData()

    -- 添加新邮件并保存
    playerMailContainer.mails[storageData.id] = storageData
    playerMailContainer.last_update = os.time()

    -- 注意：这里直接修改了player对象上的table，登出时会自动保存
    -- 如果需要立即保存，可以取消下一行注释
    -- CloudMailDataAccessor:SavePlayerMail(uin, playerMailContainer)

    if player and player.uin then
        local mailObject = MailBase.New(storageData)
        local clientMailData = mailObject:ToClientData()
        clientMailData.is_global_mail = false -- 明确这不是全局邮件
        gg.network_channel:FireClient(player.uin, {
            cmd = MailEventConfig.NOTIFY.NEW_MAIL,
            mail_info = clientMailData
        })
        gg.log("已向玩家发送新邮件通知", uin)
    end

    return storageData.id
end

--- 1. 新增全局邮件
---@param mailData MailData 邮件数据
---@return string 邮件ID
function MailManager:AddGlobalMail(mailData)
    local mailId = GlobalMailManager:AddGlobalMail(mailData)
    if mailId then
        local mailObject = MailBase.New(GlobalMailManager:GetGlobalMailById(mailId))
        if mailObject then
            local clientMailData = mailObject:ToClientData()
            clientMailData.is_global_mail = true -- 明确这是全局邮件

            -- 向所有在线玩家广播新邮件通知
            for _, p in pairs(gg.server_players_list) do
                gg.log("向玩家", p.uin, "发送新邮件通知")
                if p and p.uin  then
                    gg.network_channel:FireClient(p.uin , {
                        cmd = MailEventConfig.NOTIFY.NEW_MAIL,
                        mail_info = clientMailData
                    })
                end
            end
            gg.log("已向所有在线玩家广播新的全服邮件通知", mailId)
        end
    end
    return mailId
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
---@param senderInfo SenderInfo 发件人信息
---@param expireDays number|nil 过期天数
---@return string 邮件ID
function MailManager:SendPersonalMail(recipientUin, title, content, attachments, senderInfo, expireDays)
    local now = os.time()
    local finalExpireDays = expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS
    local mailData = {
        title = title,
        content = content,
        sender = senderInfo.name or "系统",
        send_time = now,
        expire_time = now + finalExpireDays * 86400,
        expire_days = finalExpireDays,
        status = self.MAIL_STATUS.UNREAD,
        attachments = attachments or {},
        has_attachment = attachments and #attachments > 0,
        mail_type = senderInfo.id == 0 and self.MAIL_TYPE.SYSTEM or self.MAIL_TYPE.PLAYER
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
        sender = "系统", -- 全服邮件发送者固定为系统
        send_time = now,
        expire_time = now + (expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS) * 86400,
        expire_days = expireDays or MailEventConfig.DEFAULT_EXPIRE_DAYS,
        status = self.MAIL_STATUS.UNREAD,
        attachments = attachments or {},
        has_attachment = attachments and #attachments > 0,
        mail_type = self.MAIL_TYPE.SYSTEM -- 全服邮件默认为系统类型
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
---@param uin number
---@param event table {uin, mail_id, is_global}
function MailManager:_handleClaimMail( event)
    local uin = event.player.uin
    local player = gg.getPlayerByUin(uin)
    if not player then
        return
    end
    local mailId = event.mail_id
    local isGlobal = event.is_global

    -- 参数校验
    if not mailId then
        self:SendClaimResponse(uin, false, nil, "无效的邮件ID", self.ERROR_CODE.INVALID_PARAMS, nil)
        return
    end

    local success, message, attachments, errorCode

    if isGlobal then
        -- 全局邮件领取
        success, message, attachments, errorCode = GlobalMailManager:ClaimGlobalMailAttachment(uin, mailId, player.mail.globalMailStatus)
    else
        -- 个人邮件领取
        success, message, attachments, errorCode = self:ClaimPersonalMail(player, mailId)
    end

    -- 获取邮件当前状态的辅助函数
    local function getCurrentMailStatus()
        if isGlobal then
            local playerStatus = player.mail.globalMailStatus.statuses[mailId]
            return playerStatus and playerStatus.status or nil
        else
            local mailData = player.mail.playerMail.mails[mailId]
            return mailData and mailData.status or nil
        end
    end

    if success then
        gg.log("附件领取成功，开始分发物品", player.name, mailId)
        -- 分发附件
        local distributed = self:_grantAttachmentsToPlayer(player, attachments)

        if distributed then
            -- 立即保存玩家的邮件数据
            self:SavePlayerMails(player)
                gg.log("玩家邮件数据已保存", player.uin)

            -- 发送成功响应（此时状态已变为CLAIMED）
            self:SendClaimResponse(uin, true, mailId, "分发成功", self.ERROR_CODE.SUCCESS, self.MAIL_STATUS.CLAIMED)

            -- 发送邮件状态更新通知
            self:SendMailStatusUpdate(uin)
        else
            -- 物品分发失败，理论上需要回滚邮件状态，但目前简化处理
            gg.log("附件分发失败，回滚状态（暂未实现）", player.uin, mailId)
            -- 注意：这里的错误处理可能需要更复杂的逻辑，例如事务回滚
            local currentStatus = getCurrentMailStatus()
            self:SendClaimResponse(uin, false, mailId, "分发失败", self.ERROR_CODE.INSUFFICIENT_BAG_SPACE, currentStatus)
        end
    else
        -- 领取失败
        gg.log("附件领取失败", player.name, mailId, message)
        local currentStatus = getCurrentMailStatus()
        self:SendClaimResponse(uin, false, mailId, message, errorCode, currentStatus)
    end
end

--- 处理标记邮件为已读请求
---@param event table 事件数据 {player, mail_id, is_global}
function MailManager:HandleMarkAsRead(event)
    local player = event.player
    local mailId = event.mail_id
    local isGlobal = event.is_global
    
    if not player or not mailId or not player.mail then
        return
    end
    
    if isGlobal then
        -- 处理全服邮件
        local playerStatus = player.mail.globalMailStatus.statuses[mailId]
        if not playerStatus then
            player.mail.globalMailStatus.statuses[mailId] = {
                status = self.MAIL_STATUS.READ,
                is_claimed = false
            }
        elseif playerStatus.status == self.MAIL_STATUS.UNREAD then
            playerStatus.status = self.MAIL_STATUS.READ
        end
        player.mail.globalMailStatus.last_update = os.time()
    else
        -- 处理个人邮件
        local mailData = player.mail.playerMail.mails[mailId]
        if mailData and mailData.status == self.MAIL_STATUS.UNREAD then
            mailData.status = self.MAIL_STATUS.READ
            player.mail.playerMail.last_update = os.time()
        end
    end
    
    -- 保存数据
    self:SavePlayerMails(player)
    
    -- 复用领取附件的响应格式（此时状态已变为READ）
    self:SendClaimResponse(player.uin, true, mailId, "标记已读成功", self.ERROR_CODE.SUCCESS, self.MAIL_STATUS.READ)
    
    -- 发送状态更新
    self:SendMailStatusUpdate(player.uin)
end

--- 处理删除邮件请求（带容错机制）
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

--- 新增：处理一键领取请求
function MailManager:HandleBatchClaim(event)
    gg.log("HandleBatchClaim", event)
    local player = gg.getPlayerByUin(event.player.uin)
    local category = event.category
    local mailIds = event.mail_ids

    if not player or not category or not mailIds or #mailIds == 0 then
        gg.log("BatchClaim: 无效的参数", player and player.uin, category, mailIds and #mailIds)
        return
    end

    local uin = player.uin
    if not player.mail then
        gg.log("BatchClaim: 找不到玩家邮件数据", uin)
        return
    end

    local successfullyClaimedMails = {} -- 用于存放成功领取的邮件数据以返回给客户端

    if category == "玩家邮件" then
        -- 批量领取个人邮件
        for _, mailId in ipairs(mailIds) do
            local mailInfo = player.mail.playerMail.mails[mailId]

            -- 验证: 邮件存在, 有附件, 未领取
            if mailInfo and mailInfo.has_attachment and not mailInfo.is_claimed then
                if self:_grantAttachmentsToPlayer(player, mailInfo.attachments) then
                    mailInfo.is_claimed = true
                    table.insert(successfullyClaimedMails, mailInfo)
                end
            else
                gg.log("BatchClaim: 个人邮件验证失败或已领取", uin, mailId)
            end
        end

    elseif category == "系统邮件" then
        -- 批量领取全服邮件
        for _, mailId in ipairs(mailIds) do
            -- 验证1: 全服邮件是否存在
            local globalMail = GlobalMailManager:GetGlobalMailById(mailId)
            if globalMail then
                -- 验证2: 玩家是否已领取过该邮件
                if not player.mail.globalMailStatus.statuses[mailId] or not player.mail.globalMailStatus.statuses[mailId].is_claimed then
                    if self:_grantAttachmentsToPlayer(player, globalMail.attachments) then
                        -- 更新玩家的全服邮件状态
                        if not player.mail.globalMailStatus.statuses[mailId] then
                            player.mail.globalMailStatus.statuses[mailId] = {
                                status = self.MAIL_STATUS.UNREAD,
                                is_claimed = false
                            }
                        end
                        player.mail.globalMailStatus.statuses[mailId].is_claimed = true
                        player.mail.globalMailStatus.statuses[mailId].status = self.MAIL_STATUS.CLAIMED

                        -- 构造包含玩家状态的邮件数据返回给客户端
                        local mailInfoForClient = {
                            id = globalMail.id,
                            title = globalMail.title,
                            content = globalMail.content,
                            sender = globalMail.sender,
                            send_time = globalMail.send_time,
                            expire_time = globalMail.expire_time,
                            mail_type = globalMail.mail_type,
                            has_attachment = globalMail.has_attachment,
                            attachments = globalMail.attachments,
                            -- 玩家个人状态
                            is_claimed = true,
                            is_global_mail = true,
                            status = self.MAIL_STATUS.CLAIMED
                        }
                        table.insert(successfullyClaimedMails, mailInfoForClient)
                    end
                else
                    gg.log("BatchClaim: 玩家已领取过该全服邮件", uin, mailId)
                end
            else
                gg.log("BatchClaim: 全服邮件不存在", mailId)
            end
        end
    end

    -- 保存玩家数据
    self:SavePlayerMails(player)

    -- 回调给客户端
    if #successfullyClaimedMails > 0 then
        gg.log("BatchClaim: 成功领取", #successfullyClaimedMails, "封邮件 for player", uin)
        player:SendEvent(MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS, {
            success = true,
            claimedMails = successfullyClaimedMails,
            claimedCount = #successfullyClaimedMails
        })
    else
        gg.log("BatchClaim: 没有成功领取的邮件 for player", uin)
        player:SendEvent(MailEventConfig.RESPONSE.BATCH_CLAIM_SUCCESS, {
            success = false,
            error = "没有可领取的邮件"
        })
    end
end

--- 处理删除已读邮件请求
---@param event table
function MailManager:HandleDeleteReadMails(event)
    local player = event.player
    if not player or not player.mail then
        gg.log("删除已读邮件失败: 找不到玩家或玩家邮件数据", player and player.uin or "unknown")
        return
    end

    local personalMailIds = event.personalMailIds or {}
    local globalMailIds = event.globalMailIds or {}
    local allDeletedIds = {}

    -- 1. 删除玩家个人邮件
    if #personalMailIds > 0 then
        local playerMailContainer = player.mail.playerMail.mails
        for _, mailId in ipairs(personalMailIds) do
            if playerMailContainer[mailId] then
                playerMailContainer[mailId] = nil
                table.insert(allDeletedIds, mailId)
            end
        end
        -- 只有在实际删除了邮件时才更新时间戳
        if #allDeletedIds > 0 then
            player.mail.playerMail.last_update = os.time()
        end
    end

    -- 2. 删除全服邮件的状态
    if #globalMailIds > 0 then
        local initialDeletedCount = #allDeletedIds
        local playerGlobalStatus = player.mail.globalMailStatus.statuses
        for _, mailId in ipairs(globalMailIds) do
            local status = playerGlobalStatus[mailId]
            -- 确保状态存在且不是已删除状态
            if status and status.status ~= self.MAIL_STATUS.DELETED then
                status.status = self.MAIL_STATUS.DELETED
                table.insert(allDeletedIds, mailId)
            end
        end
        -- 只有在实际删除了邮件状态时才更新时间戳
        if #allDeletedIds > initialDeletedCount then
            player.mail.globalMailStatus.last_update = os.time()
        end
    end

    -- 如果没有任何邮件被删除，可以提前返回，避免不必要的网络消息
    if #allDeletedIds == 0 then
        gg.log("为玩家", player.uin, "没有找到可删除的已读邮件")
        return
    end

    gg.log("为玩家", player.uin, "删除了", #allDeletedIds, "封已读邮件")

    -- 保存玩家邮件数据
    self:SavePlayerMails(player)

    -- 向客户端发送成功响应
    gg.network_channel:FireClient(player.uin, {
        cmd = MailEventConfig.RESPONSE.DELETE_READ_SUCCESS,
        success = true,
        deletedMailIds = allDeletedIds
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
    player.mail.playerMail.mails[mailId] = mailObject:ToStorageData() -- 将更新后的数据写回
    player.mail.playerMail.last_update = os.time()

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

--- 发送领取附件操作的响应
---@param uin number 玩家ID
---@param success boolean 是否成功
---@param mailId string 邮件ID
---@param message string 消息
---@param errorCode number|nil 错误码
---@param mailStatus number|nil 邮件当前状态
function MailManager:SendClaimResponse(uin, success, mailId, message, errorCode, mailStatus)
    gg.log("发送领取附件响应到", uin, "结果:", success, "邮件状态:", mailStatus)
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.CLAIM_RESPONSE,
        success = success,
        mail_id = mailId,
        error = message,
        error_code = errorCode or self.ERROR_CODE.SUCCESS,
        mail_status = mailStatus  -- 新增：邮件当前状态
    })
end

---@private
--- 将附件授予玩家
---@param player Player
---@param attachments table
---@return boolean 是否成功授予所有附件
function MailManager:_grantAttachmentsToPlayer(player, attachments)
    if not attachments or #attachments == 0 then
        return true -- 没有附件也算成功
    end

    if not player.bag then
        gg.log("Error: 玩家没有背包，无法添加附件。", player.uin)
        return false
    end

    -- 实际项目中可能需要检查背包空间等

    for _, itemData in ipairs(attachments) do
        if itemData and itemData.type and itemData.amount and itemData.amount > 0 then
            local itemType = ItemTypeConfig.Get(itemData.type)
            if itemType then
                local item = itemType:ToItem(itemData.amount)
                player.bag:GiveItem(item, "邮件")
                gg.log(string.format("授予玩家 %s 物品: %s, 数量: %d", player.uin, itemData.type, itemData.amount))
            else
                gg.log("Error: 找不到物品配置:", itemData.type, " for player:", player.uin)
            end
        end
    end

    return true
end

return MailManager

