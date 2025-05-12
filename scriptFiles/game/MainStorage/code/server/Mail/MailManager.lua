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
local CloundMailData = require(MainStorage.code.server.cloundData.CloundMailData)  ---@type CloundMailData
local BagMgr = require(MainStorage.code.server.bag.BagMgr)  ---@type BagMgr
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

---@class MailManager
local MailManager = {
    -- 邮件类型
    MAIL_TYPE = {
        SYSTEM = 1,  -- 系统邮件
        PLAYER = 2,  -- 玩家邮件
        ADMIN = 3    -- 管理员邮件
    },
    
    -- 邮件状态
    MAIL_STATUS = {
        UNREAD = 0,            -- 未读
        READ = 1,              -- 已读未领取
        CLAIMED = 2,           -- 已领取附件
        DELETED = 3            -- 已删除
    },
    
    -- 邮件操作类型
    MAIL_OPERATION = {
        READ = 1,              -- 读取邮件
        CLAIM_ATTACHMENT = 2,  -- 领取附件
        DELETE = 3             -- 删除邮件
    },
    
    -- 错误码
    ERROR_CODE = {
        SUCCESS = 0,
        MAIL_NOT_FOUND = 1,
        ALREADY_CLAIMED = 2,
        NO_ATTACHMENT = 3,
        EXPIRED = 4,
        INVENTORY_FULL = 5,
        INVALID_OPERATION = 6,
        SYSTEM_ERROR = 7
    }
}

--- 初始化邮件管理器
function MailManager:Init()
    -- 注册网络消息处理函数
    self:RegisterNetworkHandlers()
    
    -- 注册玩家事件
    self:RegisterPlayerEvents()
    
    gg.log("邮件管理器初始化完成")
    return self
end

--- 注册网络消息处理函数
function MailManager:RegisterNetworkHandlers()
    -- 使用新的邮件前缀命令格式
    ServerEventManager.Subscribe("mail_get_list", function(event)
                                                self:HandleGetMailList(event.uin)
                                                end)
    
    ServerEventManager.Subscribe("mail_read", function(event)
        self:HandleReadMail(event.uin, event.mail_id, event.is_global)
    end)
    
    ServerEventManager.Subscribe("mail_claim_attachment", function(event)
        self:HandleClaimAttachment(event.uin, event.mail_id, event.is_global)
    end)
    
    ServerEventManager.Subscribe("mail_delete", function(event)
        self:HandleDeleteMail(event.uin, event.mail_id, event.is_global)
    end)
    
    gg.log("邮件网络消息处理函数注册完成")
end

--- 注册玩家事件
function MailManager:RegisterPlayerEvents()
    -- 玩家登录事件
    ServerEventManager.Subscribe("PlayerLoggedIn", function(event)
        CloundMailData:OnPlayerLogin(event.player.uin)
        -- 检查是否有未读邮件，并通知客户端
        self:CheckNewMail(event.player.uin)
    end)
    
    -- 玩家登出事件
    ServerEventManager.Subscribe("PlayerLoggedOut", function(event)
        CloundMailData:OnPlayerLogout(event.player.uin)
    end)
    
    gg.log("邮件玩家事件注册完成")
end

---------------------------
-- 邮件操作处理函数
---------------------------

--- 处理获取邮件列表请求
---@param uin number 玩家ID
function MailManager:HandleGetMailList(uin)
    -- 获取个人邮件列表
    local personalMails = self:GetPersonalMailList(uin)
    
    -- 获取全服邮件列表（包含玩家状态）
    local globalMails = self:GetGlobalMailList(uin)
    
    -- 发送邮件列表到客户端
    gg.network_channel:fireClient(uin, {
        cmd = "mail_list_response",
        personal_mails = personalMails,
        global_mails = globalMails
    })
end

--- 处理阅读邮件请求
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@param isGlobal boolean 是否是全服邮件
function MailManager:HandleReadMail(uin, mailId, isGlobal)
    local success, message, mailData
    
    if isGlobal then
        success, message, mailData = self:ReadGlobalMail(uin, mailId)
    else
        success, message, mailData = self:ReadPersonalMail(uin, mailId)
    end
    
    -- 发送结果到客户端
    gg.network_channel:fireClient(uin, {
        cmd = "mail_read_response",
        success = success,
        message = message,
        mail_id = mailId,
        is_global = isGlobal,
        mail_data = mailData
    })
end

--- 处理领取附件请求
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@param isGlobal boolean 是否是全服邮件
function MailManager:HandleClaimAttachment(uin, mailId, isGlobal)
    local success, message, attachments
    
    if isGlobal then
        success, message, attachments = self:ClaimGlobalMailAttachment(uin, mailId)
    else
        success, message, attachments = self:ClaimPersonalMailAttachment(uin, mailId)
    end
    
    -- 发送结果到客户端
    gg.network_channel:fireClient(uin, {
        cmd = "mail_claim_attachment_response",
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
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@param isGlobal boolean 是否是全服邮件
function MailManager:HandleDeleteMail(uin, mailId, isGlobal)
    local success, message
    
    if isGlobal then
        success, message = self:DeleteGlobalMail(uin, mailId)
    else
        success, message = self:DeletePersonalMail(uin, mailId)
    end
    
    -- 发送结果到客户端
    gg.network_channel:fireClient(uin, {
        cmd = "mail_delete_response",
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
    local playerMail = CloundMailData:GetPlayerMail(uin)
    local result = {}
    
    -- 过滤非删除状态的邮件
    for mailId, mail in pairs(playerMail.mails) do
        if mail.status < self.MAIL_STATUS.DELETED then  -- 非删除状态
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
                sender_type = mail.sender_type
            }
            
            table.insert(result, mailCopy)
        end
    end
    
    -- 按发送时间排序（最新的在前）
    table.sort(result, function(a, b)
        return a.send_time > b.send_time
    end)
    
    return result
end

--- 阅读个人邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 邮件数据
function MailManager:ReadPersonalMail(uin, mailId)
    local playerMail = CloundMailData:GetPlayerMail(uin)
    local mail = playerMail.mails[mailId]
    
    if not mail then
        return false, "邮件不存在", nil
    end
    
    -- 检查邮件是否过期
    if mail.expire_time and mail.expire_time < os.time() then
        return false, "邮件已过期", nil
    end
    
    -- 已经是已读状态则不需要更新
    if mail.status == self.MAIL_STATUS.UNREAD then
        mail.status = self.MAIL_STATUS.READ
        playerMail.last_update = os.time()
        
        -- 保存到云存储
        CloundMailData:SavePlayerMail(uin, false)
    end
    
    return true, "操作成功", mail
end

--- 领取个人邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 附件列表
function MailManager:ClaimPersonalMailAttachment(uin, mailId)
    local playerMail = CloundMailData:GetPlayerMail(uin)
    local mail = playerMail.mails[mailId]
    
    if not mail then
        return false, "邮件不存在", nil
    end
    
    -- 检查邮件是否过期
    if mail.expire_time and mail.expire_time < os.time() then
        return false, "邮件已过期", nil
    end
    
    -- 检查是否已领取
    if mail.status >= self.MAIL_STATUS.CLAIMED then
        return false, "附件已领取", nil
    end
    
    -- 检查是否有附件
    if not mail.attachments or #mail.attachments == 0 then
        return false, "邮件没有附件", nil
    end
    
    -- 分发附件给玩家
    local success = self:DistributeAttachments(uin, mail.attachments)
    if not success then
        return false, "背包空间不足", nil
    end
    
    -- 更新邮件状态
    mail.status = self.MAIL_STATUS.CLAIMED
    playerMail.last_update = os.time()
    
    -- 保存到云存储
    CloundMailData:SavePlayerMail(uin, true)
    
    return true, "附件已领取", mail.attachments
end

--- 删除个人邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
function MailManager:DeletePersonalMail(uin, mailId)
    local playerMail = CloundMailData:GetPlayerMail(uin)
    local mail = playerMail.mails[mailId]
    
    if not mail then
        return false, "邮件不存在"
    end
    
    -- 检查是否有未领取的附件
    if mail.attachments and #mail.attachments > 0 and mail.status < self.MAIL_STATUS.CLAIMED then
        return false, "请先领取附件"
    end
    
    -- 标记为删除状态
    mail.status = self.MAIL_STATUS.DELETED
    playerMail.last_update = os.time()
    
    -- 保存到云存储
    CloundMailData:SavePlayerMail(uin, false)
    
    return true, "邮件已删除"
end

---------------------------
-- 全服邮件相关函数
---------------------------

--- 获取全服邮件列表（带玩家状态）
---@param uin number 玩家ID
---@return table 邮件列表
function MailManager:GetGlobalMailList(uin)
    local globalMails = CloundMailData:GetGlobalMail().mails
    local bitmap = CloundMailData:GetBitmap(uin)
    local result = {}
    
    -- 检查过期
    local now = os.time()
    
    for mailId, mail in pairs(globalMails) do
        -- 跳过过期邮件
        if not mail.expire_time or mail.expire_time > now then
            -- 获取该玩家对此邮件的状态
            local bitValue = bitmap[mailId] or 0
            
            -- 只添加未删除的邮件
            if bitValue ~= self.MAIL_STATUS.DELETED then
                -- 创建邮件摘要
                local mailSummary = {
                    id = mail.id,
                    title = mail.title,
                    send_time = mail.send_time,
                    expire_time = mail.expire_time,
                    status = bitValue,
                    has_attachment = mail.attachments and #mail.attachments > 0,
                    is_read = (bitValue & 1) ~= 0,
                    is_claimed = (bitValue & 2) ~= 0
                }
                
                table.insert(result, mailSummary)
            end
        end
    end
    
    -- 按发送时间排序（最新的在前）
    table.sort(result, function(a, b)
        return a.send_time > b.send_time
    end)
    
    return result
end

--- 阅读全服邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 邮件数据
function MailManager:ReadGlobalMail(uin, mailId)
    local globalMails = CloundMailData:GetGlobalMail().mails
    local mail = globalMails[mailId]
    
    if not mail then
        return false, "邮件不存在", nil
    end
    
    -- 检查邮件是否过期
    if mail.expire_time and mail.expire_time < os.time() then
        return false, "邮件已过期", nil
    end
    
    -- 获取当前状态
    local bitValue = CloundMailData:GetMailBit(uin, mailId)
    
    -- 如果未读，则标记为已读
    if (bitValue & 1) == 0 then
        -- 设置已读位
        CloundMailData:SetMailBit(uin, mailId, bitValue | 1)
    end
    
    -- 构建完整邮件信息返回给客户端
    local mailData = {
        id = mail.id,
        title = mail.title,
        content = mail.content,
        send_time = mail.send_time,
        expire_time = mail.expire_time,
        attachments = mail.attachments,
        is_read = true,
        is_claimed = (bitValue & 2) ~= 0
    }
    
    return true, "操作成功", mailData
end

--- 领取全服邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 附件列表
function MailManager:ClaimGlobalMailAttachment(uin, mailId)
    local globalMails = CloundMailData:GetGlobalMail().mails
    local mail = globalMails[mailId]
    
    if not mail then
        return false, "邮件不存在", nil
    end
    
    -- 检查邮件是否过期
    if mail.expire_time and mail.expire_time < os.time() then
        return false, "邮件已过期", nil
    end
    
    -- 获取当前状态
    local bitValue = CloundMailData:GetMailBit(uin, mailId)
    
    -- 检查是否已领取
    if (bitValue & 2) ~= 0 then
        return false, "附件已领取", nil
    end
    
    -- 检查是否有附件
    if not mail.attachments or #mail.attachments == 0 then
        return false, "邮件没有附件", nil
    end
    
    -- 分发附件给玩家
    local success = self:DistributeAttachments(uin, mail.attachments)
    if not success then
        return false, "背包空间不足", nil
    end
    
    -- 更新状态为已读已领取 (11)
    CloundMailData:SetMailBit(uin, mailId, 3)
    
    return true, "附件已领取", mail.attachments
end

--- 删除全服邮件（仅标记状态）
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
function MailManager:DeleteGlobalMail(uin, mailId)
    local globalMails = CloundMailData:GetGlobalMail().mails
    local mail = globalMails[mailId]
    
    if not mail then
        return false, "邮件不存在"
    end
    
    -- 获取当前状态
    local bitValue = CloundMailData:GetMailBit(uin, mailId)
    
    -- 检查是否有未领取的附件
    if mail.attachments and #mail.attachments > 0 and (bitValue & 2) == 0 then
        return false, "请先领取附件"
    end
    
    -- 标记为删除状态 (11)
    CloundMailData:SetMailBit(uin, mailId, 3)
    
    return true, "邮件已删除"
end

---------------------------
-- 邮件发送相关函数
---------------------------

--- 发送个人邮件
---@param toUin number 收件人ID
---@param title string 邮件标题
---@param content string 邮件内容
---@param attachments table 附件列表
---@param senderInfo table 发送者信息
---@return string 邮件ID
function MailManager:SendPersonalMail(toUin, title, content, attachments, senderInfo)
    -- 验证参数
    if not toUin or not title or not content then
        gg.log("发送邮件失败：参数无效")
        return nil
    end
    
    -- 默认发送者信息
    senderInfo = senderInfo or {
        name = "系统",
        type = self.MAIL_TYPE.SYSTEM,
        id = 0
    }
    
    -- 创建邮件数据
    local mailData = {
        title = title,
        content = content,
        attachments = attachments or {},
        sender = senderInfo.name,
        sender_type = senderInfo.type,
        sender_id = senderInfo.id
    }
    
    -- 添加到玩家邮箱
    local mailId = CloundMailData:AddPlayerMail(toUin, mailData)
    
    -- 通知在线玩家有新邮件
    local player = gg.server_players_list[toUin]
    if player then
        self:NotifyNewMail(toUin)
    end
    
    return mailId
end

--- 发送全服邮件
---@param title string 邮件标题
---@param content string 邮件内容
---@param attachments table 附件列表
---@param expireDays number 过期天数
---@return string 邮件ID
function MailManager:SendGlobalMail(title, content, attachments, expireDays)
    -- 验证参数
    if not title or not content then
        gg.log("发送全服邮件失败：参数无效")
        return nil
    end
    
    -- 创建邮件数据
    local mailData = {
        title = title,
        content = content,
        attachments = attachments or {},
        expire_days = expireDays
    }
    
    -- 添加到全服邮件
    local mailId = CloundMailData:AddGlobalMail(mailData)
    
    -- 通知所有在线玩家有新邮件
    for uin, _ in pairs(gg.server_players_list) do
        self:NotifyNewMail(uin)
    end
    
    return mailId
end

--- 创建系统通知邮件
---@param toUin number 收件人ID
---@param title string 邮件标题
---@param content string 邮件内容
---@return string 邮件ID
function MailManager:CreateSystemNotification(toUin, title, content)
    return self:SendPersonalMail(toUin, title, content, nil, {
        name = "系统通知",
        type = self.MAIL_TYPE.SYSTEM,
        id = 0
    })
end

---------------------------
-- 辅助函数
---------------------------

--- 分发附件给玩家
---@param uin number 玩家ID
---@param attachments table 附件列表
---@return boolean 是否成功
function MailManager:DistributeAttachments(uin, attachments)
    if not attachments or #attachments == 0 then
        return true
    end
    
    local player = gg.getPlayerByUin(uin)
    if not player then
        return false
    end
    
    -- 处理每个附件
    for _, attachment in ipairs(attachments) do
        if attachment.type == "货币" then
            -- 处理货币附件
            player:AddGold(attachment.amount)
        else
            -- 处理物品附件
            local Item = require(MainStorage.code.server.bag.Item)
            local itemObj = Item.New()
            itemObj:Load({
                itype = attachment.type,
                amount = attachment.amount
            })
            player.bag:GiveItem(itemObj)
        end
    end
    
    return true
end

--- 检查是否有新邮件
---@param uin number 玩家ID
function MailManager:CheckNewMail(uin)
    local hasUnread = false
    
    -- 检查个人邮件
    local personalMails = self:GetPersonalMailList(uin)
    for _, mail in ipairs(personalMails) do
        if mail.status == self.MAIL_STATUS.UNREAD then
            hasUnread = true
            break
        end
    end
    
    -- 检查全服邮件
    if not hasUnread then
        local globalMails = self:GetGlobalMailList(uin)
        for _, mail in ipairs(globalMails) do
            if not mail.is_read then
                hasUnread = true
                break
            end
        end
    end
    
    -- 通知客户端
    if hasUnread then
        self:NotifyNewMail(uin)
    end
end

--- 通知玩家有新邮件
---@param uin number 玩家ID
function MailManager:NotifyNewMail(uin)
    gg.network_channel:fireClient(uin, {
        cmd = "mail_new_notification",
        has_new_mail = true
    })
end

---------------------------
-- 导出模块
---------------------------

return MailManager:Init()