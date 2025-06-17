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

---@class MailManager
local MailManager = {
    -- 邮件类型
    MAIL_TYPE = MailEventConfig.MAIL_TYPE,
    
    -- 邮件状态
    MAIL_STATUS = MailEventConfig.STATUS,

    -- 错误码
    ERROR_CODE = MailEventConfig.ERROR_CODES,
    
    -- 全服邮件缓存
    global_mail_cache = nil, ---@type GlobalMailCache
}

--- 初始化邮件管理器
function MailManager:Init()
    -- 加载全服邮件到缓存
    self.global_mail_cache = CloudMailDataAccessor:LoadGlobalMail()
    
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

    ServerEventManager.Subscribe(MailEventConfig.REQUEST.READ_MAIL, function(event)
        self:HandleReadMail(event)
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
    -- 监听玩家登录事件，为其加载邮件数据
    ServerEventManager.Subscribe("PlayerLogin", function(event)
        self:OnPlayerLogin(event.uin)
    end)
    
    -- 监听玩家登出事件，为其保存邮件数据
    ServerEventManager.Subscribe("PlayerLogout", function(event)
        local player = gg.server_players_list[event.uin]
        if player and player.mail then
            self:OnPlayerLogout(event.uin, player.mail)
        end
    end)
    
    gg.log("邮件生命周期事件处理函数注册完成")
end

--- 玩家登录事件处理
---@param uin number 玩家ID
function MailManager:OnPlayerLogin(uin)
    local playerMailData = CloudMailDataAccessor:LoadPlayerMail(uin)
    local playerGlobalMailData = CloudMailDataAccessor:LoadPlayerGlobalMailData(uin)
    
    local mailDataStruct = {
        player_mail_data_ = playerMailData,
        player_global_mail_data_ = playerGlobalMailData
    }
    
    -- 将完整的邮件数据结构附加到玩家对象上
    local player = gg.server_players_list[uin]
    if player then
        player.mail = mailDataStruct
        gg.log("玩家邮件数据加载完成", uin)
    end
end

--- 玩家登出事件处理
---@param uin number 玩家ID
---@param mail_data MailDataStruct 邮件数据
function MailManager:OnPlayerLogout(uin, mail_data)
    -- 保存个人邮件
    CloudMailDataAccessor:SavePlayerMail(uin, mail_data.player_mail_data_)
    -- 保存玩家的全服邮件状态
    CloudMailDataAccessor:SavePlayerGlobalMailData(uin, mail_data.player_global_mail_data_)

    gg.log("玩家邮件数据保存完成", uin)
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
    
    local playerMailContainer = player.mail.player_mail_data_

    -- 为邮件数据补充ID和类型
    mailData.id = self:GenerateMailId("mail_p_")
    mailData.mail_type = self.MAIL_TYPE.PERSONAL
    
    -- 使用MailBase来创建和初始化邮件对象
    local mailObject = MailBase.New(mailData)
    local storageData = mailObject:ToStorageData()

    -- 添加新邮件并保存
    playerMailContainer.mails[storageData.id] = storageData
    playerMailContainer.last_update = os.time()
    
    -- 注意：这里直接修改了player对象上的table，登出时会自动保存
    -- 如果需要立即保存，可以取消下一行注释
    -- CloudMailDataAccessor:SavePlayerMail(uin, playerMailContainer)

    gg.log("成功向玩家添加个人邮件", uin, storageData.id)
    return storageData.id
end

--- 添加全服邮件
---@param mailData MailData 邮件数据
---@return string 邮件ID
function MailManager:AddGlobalMail(mailData)
    -- 为邮件数据补充ID和类型
    mailData.id = self:GenerateMailId("mail_g_")
    mailData.mail_type = self.MAIL_TYPE.GLOBAL

    -- 使用MailBase来创建和初始化邮件对象
    local mailObject = MailBase.New(mailData)
    local storageData = mailObject:ToStorageData()

    -- 添加新邮件到缓存并立即保存到云端
    self.global_mail_cache.mails[storageData.id] = storageData
    self.global_mail_cache.last_update = os.time()
    CloudMailDataAccessor:SaveGlobalMail(self.global_mail_cache)

    gg.log("成功添加全服邮件", storageData.id)
    return storageData.id
end

---------------------------
-- 邮件操作处理函数
---------------------------

--- 处理获取邮件列表请求
---@param event table 事件数据
function MailManager:HandleGetMailList(event)
    local uin = event.uin

    -- 获取个人邮件列表
    local personalMails = self:GetPersonalMailList(uin)

    -- 获取全服邮件列表（包含玩家状态）
    local globalMails = self:GetGlobalMailList(uin)

    -- 发送邮件列表到客户端
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.LIST_RESPONSE,
        personal_mails = personalMails,
        global_mails = globalMails
    })
end

--- 处理阅读邮件请求
---@param event table 事件数据
function MailManager:HandleReadMail(event)
    local uin = event.uin
    local mailId = event.mail_id
    local isGlobal = event.is_global

    local success, message, mailData

    if isGlobal then
        success, message, mailData = self:ReadGlobalMail(uin, mailId)
    else
        success, message, mailData = self:ReadPersonalMail(uin, mailId)
    end

    -- 发送结果到客户端
    gg.network_channel:fireClient(uin, {
        cmd = MailEventConfig.RESPONSE.READ_RESPONSE,
        success = success,
        message = message,
        mail_id = mailId,
        is_global = isGlobal,
        mail_data = mailData
    })
end

--- 处理领取附件请求
---@param event table 事件数据
function MailManager:HandleClaimAttachment(event)
    local uin = event.uin
    local mailId = event.mail_id
    local isGlobal = event.is_global
    local success, message, attachments

    if isGlobal then
        success, message, attachments = self:ClaimGlobalMailAttachment(uin, mailId)
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
        success, message = self:DeleteGlobalMail(uin, mailId)
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
    local player = gg.server_players_list[uin]
    if not player then
        return {}
    end
    local playerMail = player.mail.player_mail_data_
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

            result[mailId] = mailCopy
        end
    end

    return result
end

--- 阅读个人邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 邮件数据
function MailManager:ReadPersonalMail(uin, mailId)
    local player = gg.server_players_list[uin]
    if not player then
        return false, "玩家不存在", nil
    end
    
    local mailData = player.mail.player_mail_data_.mails[mailId]
    if not mailData then
        return false, "邮件不存在", nil
    end
    
    local mailObject = MailBase.New(mailData)
    
    if mailObject:IsExpired() then return false, "邮件已过期", nil end
    
    if mailObject:MarkAsRead() then
        -- 登出时会自动保存
        return true, "阅读成功", mailObject:ToClientData()
    else
        return false, "邮件已阅读", mailObject:ToClientData()
    end
end

--- 领取个人邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 附件列表
function MailManager:ClaimPersonalMailAttachment(uin, mailId)
    local player = gg.server_players_list[uin]
    if not player then
        return false, "玩家不存在", nil
    end
    
    local mailData = player.mail.player_mail_data_.mails[mailId]
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
    local player = gg.server_players_list[uin]
    if not player then
        return false, "玩家不存在"
    end
    
    local mailData = player.mail.player_mail_data_.mails[mailId]
    if not mailData then
        return false, "邮件不存在"
    end
    
    local mailObject = MailBase.New(mailData)

    -- 已删除或无法删除
    if mailObject:IsDeleted() then return false, "邮件已删除" end
    
    -- 有未领取的附件时不能删除
    if mailObject:CanClaimAttachment() then
        return false, "请先领取附件"
    end
    
    mailObject:MarkAsDeleted()
    return true, "邮件已删除"
end

---------------------------
-- 全服邮件相关函数
---------------------------

--- 获取全服邮件列表（包含玩家状态）
---@param uin number 玩家ID
---@return table 邮件列表
function MailManager:GetGlobalMailList(uin)
    local player = gg.server_players_list[uin]
    if not player then
        return {}
    end
    
    local globalMails = self.global_mail_cache
    local playerGlobalData = player.mail.player_global_mail_data_
    local result = {}

    -- 遍历全服邮件
    for mailId, mailData in pairs(globalMails.mails) do
        local mailObject = MailBase.New(mailData)
        
        -- 跳过过期的全服邮件
        if mailObject:IsExpired() then
            -- (可以加一个逻辑，定期清理全局邮件缓存中的过期邮件)
        else
            local playerMailStatus = playerGlobalData.statuses[mailId]
            
            -- 如果玩家没有这封邮件的状态记录，或者状态不是已删除，则显示
            if not playerMailStatus or playerMailStatus.status < self.MAIL_STATUS.DELETED then
                local clientMailData = mailObject:ToClientData()
                -- 使用玩家的特定状态覆盖通用状态
                clientMailData.status = playerMailStatus and playerMailStatus.status or self.MAIL_STATUS.UNREAD
                result[mailId] = clientMailData
            end
        end
    end

    return result
end

--- 阅读全服邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 邮件数据
function MailManager:ReadGlobalMail(uin, mailId)
    local player = gg.server_players_list[uin]
    if not player then return false, "玩家不存在", nil end

    local globalMailData = self.global_mail_cache.mails[mailId]
    if not globalMailData then return false, "邮件不存在", nil end
    
    local mailObject = MailBase.New(globalMailData)
    if mailObject:IsExpired() then return false, "邮件已过期", nil end

    local playerGlobalData = player.mail.player_global_mail_data_
    local mailStatus = playerGlobalData.statuses[mailId]

    -- 如果没有状态记录，或者状态是未读，则更新为已读
    if not mailStatus or mailStatus.status < self.MAIL_STATUS.READ then
        if not mailStatus then
            playerGlobalData.statuses[mailId] = { status = self.MAIL_STATUS.READ, is_claimed = false }
        else
            mailStatus.status = self.MAIL_STATUS.READ
        end
        return true, "阅读成功", mailObject:ToClientData()
    end

    return false, "邮件已阅读", mailObject:ToClientData()
end

--- 领取全服邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
---@return table 附件列表
function MailManager:ClaimGlobalMailAttachment(uin, mailId)
    local player = gg.server_players_list[uin]
    if not player then return false, "玩家不存在", nil end
    
    local globalMailData = self.global_mail_cache.mails[mailId]
    if not globalMailData then return false, "邮件不存在", nil end
    
    local mailObject = MailBase.New(globalMailData)
    if not mailObject.has_attachment then return false, "该邮件没有附件", nil end
    if mailObject:IsExpired() then return false, "邮件已过期", nil end

    local playerGlobalData = player.mail.player_global_mail_data_
    local mailStatus = playerGlobalData.statuses[mailId]

    -- 检查是否可以领取
    if not mailStatus or mailStatus.status < self.MAIL_STATUS.CLAIMED then
        -- 分发附件给玩家
        local success, reason = self:DistributeAttachments(uin, mailObject:GetAttachments())
        if not success then
            return false, reason or "背包空间不足", nil
        end
        
        -- 更新状态
        if not mailStatus then
            playerGlobalData.statuses[mailId] = { status = self.MAIL_STATUS.CLAIMED, is_claimed = true }
        else
            mailStatus.status = self.MAIL_STATUS.CLAIMED
            mailStatus.is_claimed = true
        end

        return true, "领取成功", mailObject:GetAttachments()
    end

    return false, "附件已领取", nil
end

--- 删除全服邮件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
function MailManager:DeleteGlobalMail(uin, mailId)
    local player = gg.server_players_list[uin]
    if not player then return false, "玩家不存在" end
    
    local globalMailData = self.global_mail_cache.mails[mailId]
    if not globalMailData then return true, "删除成功" end -- 全服邮件不存在，相当于对该玩家已经"删除"
    
    local playerGlobalData = player.mail.player_global_mail_data_
    local mailStatus = playerGlobalData.statuses[mailId]

    if not mailStatus or mailStatus.status < self.MAIL_STATUS.DELETED then
        local mailObject = MailBase.New(globalMailData)
        
        -- 有未领取的附件时不能删除
        if mailObject.has_attachment and (not mailStatus or not mailStatus.is_claimed) then
             return false, "请先领取附件"
        end

        if not mailStatus then
            playerGlobalData.statuses[mailId] = { 
                status = self.MAIL_STATUS.DELETED, 
                is_claimed = mailStatus and mailStatus.is_claimed or false 
            }
        else
            mailStatus.status = self.MAIL_STATUS.DELETED
        end
        return true, "删除成功"
    end

    return false, "邮件已删除"
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
    for _, mailData in pairs(player.mail.player_mail_data_.mails) do
        if mailData.status == self.MAIL_STATUS.UNREAD then
            return true
        end
    end

    -- 检查全服邮件
    local globalMails = self.global_mail_cache.mails
    local playerStatuses = player.mail.player_global_mail_data_.statuses
    for mailId, _ in pairs(globalMails) do
        local status = playerStatuses[mailId]
        if not status or status.status == self.MAIL_STATUS.UNREAD then
            -- 还需检查邮件是否过期
            if not globalMails[mailId].expire_time or globalMails[mailId].expire_time > os.time() then
                return true
            end
        end
    end
    
    return false
end

return MailManager
