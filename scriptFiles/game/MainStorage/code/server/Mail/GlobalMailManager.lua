--- 全局邮件管理器
--- V109 miniw-haima
--- 负责全局邮件的创建、获取、删除等操作

local game = game
local pairs = pairs
local os = os
local math = math

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local CloudMailDataAccessor = require(MainStorage.code.server.Mail.cloudMailData) ---@type CloudMailDataAccessor
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
local MailBase = require(MainStorage.code.server.Mail.MailBase) ---@type MailBase

---@class GlobalMailManager
local GlobalMailManager = {
    -- 全服邮件缓存
    global_mail_cache = nil, ---@type GlobalMailCache
}

--- 初始化全局邮件管理器
function GlobalMailManager:Init()
    -- 加载全服邮件到缓存
    self.global_mail_cache = CloudMailDataAccessor:LoadGlobalMail()
    gg.log("全局邮件管理器初始化完成")
    return self
end

--- 生成邮件ID
---@param prefix string 前缀，如"mail_g_"
---@return string 生成的邮件ID
function GlobalMailManager:GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return prefix .. timestamp .. "_" .. random
end

--- 1. 新增全局邮件
---@param mailData MailData 邮件数据
---@return string 邮件ID
function GlobalMailManager:AddGlobalMail(mailData)
    -- 为邮件数据补充ID和类型
    mailData.id = self:GenerateMailId("mail_g_")
    mailData.mail_type = MailEventConfig.MAIL_TYPE.SYSTEM

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

--- 2. 获取所有的全局邮件
---@return table 全局邮件列表
function GlobalMailManager:GetAllGlobalMails()
    if not self.global_mail_cache then
        return {}
    end

    local result = {}
    for mailId, mailData in pairs(self.global_mail_cache.mails) do
        local mailObject = MailBase.New(mailData)

        -- 跳过过期的全服邮件
        if not mailObject:IsExpired() then
            result[mailId] = mailObject:ToClientData()
        end
    end

    return result
end

--- 3. 删除所有的全局邮件
---@return boolean 是否成功
function GlobalMailManager:DeleteAllGlobalMails()
    if not self.global_mail_cache then
        return false
    end

    -- 清空全服邮件缓存
    self.global_mail_cache.mails = {}
    self.global_mail_cache.last_update = os.time()

    -- 保存到云端
    CloudMailDataAccessor:SaveGlobalMail(self.global_mail_cache)

    gg.log("已删除所有全服邮件")
    return true
end

--- 4. 删除指定ID的全局邮件
---@param mailId string 邮件ID
---@return boolean 是否成功
---@return string 消息
function GlobalMailManager:DeleteGlobalMailById(mailId)
    if not self.global_mail_cache or not self.global_mail_cache.mails[mailId] then
        return false, "邮件不存在"
    end

    -- 从缓存中删除
    self.global_mail_cache.mails[mailId] = nil
    self.global_mail_cache.last_update = os.time()

    -- 保存到云端
    CloudMailDataAccessor:SaveGlobalMail(self.global_mail_cache)

    gg.log("已删除全服邮件", mailId)
    return true, "删除成功"
end

--- 5. 获取指定ID的全局邮件
---@param mailId string 邮件ID
---@return table|nil 邮件数据，nil表示不存在
function GlobalMailManager:GetGlobalMailById(mailId)
    if not self.global_mail_cache or not self.global_mail_cache.mails[mailId] then
        return nil
    end

    local mailData = self.global_mail_cache.mails[mailId]
    local mailObject = MailBase.New(mailData)

    -- 检查是否过期
    if mailObject:IsExpired() then
        return nil
    end

    return mailObject:ToClientData()
end

--- 获取全服邮件列表（包含玩家状态）
---@param uin number 玩家ID
---@param playerGlobalData PlayerGlobalMailContainer 玩家全服邮件状态数据
---@return table 邮件列表
function GlobalMailManager:GetGlobalMailListForPlayer(uin, playerGlobalData)
    if not self.global_mail_cache then
        return {}
    end

    local result = {}

    -- 遍历全服邮件
    for mailId, mailData in pairs(self.global_mail_cache.mails) do
        local mailObject = MailBase.New(mailData)

        -- 跳过过期的全服邮件
        if not mailObject:IsExpired() then
            local playerMailStatus = playerGlobalData.statuses[mailId]

            -- 如果玩家没有这封邮件的状态记录，或者状态不是已删除，则显示
            if not playerMailStatus or playerMailStatus.status ~= MailEventConfig.STATUS.DELETED then
                local clientMailData = mailObject:ToClientData()
                -- 使用玩家的特定状态覆盖通用状态
                clientMailData.status = playerMailStatus and playerMailStatus.status or MailEventConfig.STATUS.UNREAD
                clientMailData.is_claimed = playerMailStatus and playerMailStatus.is_claimed or false
                clientMailData.is_global_mail = true -- 明确这是全局邮件
                result[mailId] = clientMailData
            end
        end
    end

    return result
end

--- 领取全服邮件附件
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@param playerGlobalData PlayerGlobalMailContainer 玩家全服邮件状态数据
---@return boolean 是否成功
---@return string 消息
---@return table 附件列表
function GlobalMailManager:ClaimGlobalMailAttachment(uin, mailId, playerGlobalData)
    if not self.global_mail_cache or not self.global_mail_cache.mails[mailId] then
        return false, "邮件不存在", nil
    end

    local globalMailData = self.global_mail_cache.mails[mailId]
    local mailObject = MailBase.New(globalMailData)

    if not mailObject.has_attachment then
        return false, "该邮件没有附件", nil
    end
    if mailObject:IsExpired() then
        return false, "邮件已过期", nil
    end

    local mailStatus = playerGlobalData.statuses[mailId]

    -- 检查是否可以领取
    if not mailStatus or mailStatus.status < MailEventConfig.STATUS.CLAIMED then
        -- 更新状态
        if not mailStatus then
            playerGlobalData.statuses[mailId] = {
                status = MailEventConfig.STATUS.CLAIMED,
                is_claimed = true
            }
        else
            mailStatus.status = MailEventConfig.STATUS.CLAIMED
            mailStatus.is_claimed = true
        end
        -- 直接返回附件列表，由调用者处理分发
        return true, "领取成功", mailObject:GetAttachments()
    end

    return false, "附件已领取", nil
end

--- 删除玩家的全服邮件（标记为已删除）
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@param playerGlobalData PlayerGlobalMailContainer 玩家全服邮件状态数据
---@return boolean 是否成功
---@return string 消息
function GlobalMailManager:DeleteGlobalMailForPlayer(uin, mailId, playerGlobalData)
    if not self.global_mail_cache or not self.global_mail_cache.mails[mailId] then
        return true, "删除成功" -- 全服邮件不存在，相当于对该玩家已经"删除"
    end

    local globalMailData = self.global_mail_cache.mails[mailId]
    local mailStatus = playerGlobalData.statuses[mailId]

    -- 如果邮件已经是删除状态，直接返回成功
    if mailStatus and mailStatus.status == MailEventConfig.STATUS.DELETED then
        return true, "邮件已删除"
    end

        local mailObject = MailBase.New(globalMailData)
    -- 检查是否有未领取的附件
    local hasUnclaimedAttachment = mailObject.has_attachment and (not mailStatus or not mailStatus.is_claimed)
    if hasUnclaimedAttachment then
             return false, "请先领取附件"
        end

    -- 更新或创建状态记录为已删除
        if not mailStatus then
            playerGlobalData.statuses[mailId] = {
                status = MailEventConfig.STATUS.DELETED,
            is_claimed = false -- 如果之前没有记录，那肯定没领取过
            }
        else
            mailStatus.status = MailEventConfig.STATUS.DELETED
        end
    playerGlobalData.last_update = os.time()

        return true, "删除成功"
end

--- 检查玩家是否有未读的全服邮件
---@param uin number 玩家ID
---@param playerGlobalData PlayerGlobalMailContainer 玩家全服邮件状态数据
---@return boolean
function GlobalMailManager:HasUnreadGlobalMail(uin, playerGlobalData)
    if not self.global_mail_cache then
        return false
    end

    local globalMails = self.global_mail_cache.mails
    local playerStatuses = playerGlobalData.statuses

    for mailId, mailData in pairs(globalMails) do
        local status = playerStatuses[mailId]
        if not status or status.status == MailEventConfig.STATUS.UNREAD then
            -- 还需检查邮件是否过期
            if not mailData.expire_time or mailData.expire_time > os.time() then
                return true
            end
        end
    end

    return false
end

return GlobalMailManager
