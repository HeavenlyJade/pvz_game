--- V109 miniw-haima
--- 邮件基类，定义邮件的基本结构和通用方法

local game = game
local pairs = pairs
local ipairs = ipairs
local table = table
local string = string
local os = os
local math = math
local type = type

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig)   ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst)   ---@type MMailConst
local MMailUtils = require(MainStorage.code.common.MMail.MMailUtils)   ---@type MMailUtils
local CommonModule = require(MainStorage.code.common.CommonModule)   ---@type CommonModule

---@class MailBase
local MailBase = CommonModule.Class("MailBase")

-- 初始化邮件对象
function MailBase:OnInit(params)
    -- 基本属性初始化
    self.uuid = params.uuid or MMailUtils.generateMailUUID()
    self.sender = params.sender or ""
    self.sender_type = params.sender_type or MMailConst.SENDER_TYPE.SYSTEM
    self.receiver = params.receiver or ""
    self.title = params.title or ""
    self.content = params.content or ""
    self.create_time = params.create_time or MMailUtils.getCurrentTimestamp()
    self.expire_time = params.expire_time or MMailUtils.calculateExpiryTime(params.type, params.attachments and #params.attachments > 0, false)
    self.read = params.read or false
    self.attachments = params.attachments or {}
    self.claimed = params.claimed or false
    self.type = params.type or MMailConfig.MAIL_TYPES.SYSTEM
    self.category = params.category or params.type
    self.importance = params.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL
    self.deleted = params.deleted or false
    
    -- 邮件扩展属性
    self.tags = params.tags or {}
    self.custom_data = params.custom_data or {}
    
    -- 邮件跟踪属性
    self.tracking = {
        read_time = params.read_time,
        claim_time = params.claim_time,
        delete_time = params.delete_time
    }
    
    -- 验证基本参数
    self:ValidateParams()
end

-- 验证邮件参数
function MailBase:ValidateParams()
    -- 确保标题不超过长度限制
    if string.len(self.title) > MMailConst.MAX_TITLE_LENGTH then
        self.title = string.sub(self.title, 1, MMailConst.MAX_TITLE_LENGTH)
    end
    
    -- 确保内容不超过长度限制
    if string.len(self.content) > MMailConst.MAX_CONTENT_LENGTH then
        self.content = string.sub(self.content, 1, MMailConst.MAX_CONTENT_LENGTH)
    end
    
    -- 确保附件数量不超过限制
    while #self.attachments > MMailConst.MAX_ATTACHMENTS do
        table.remove(self.attachments)
    end
end

-- 标记邮件为已读
function MailBase:MarkAsRead()
    if not self.read then
        self.read = true
        self.tracking.read_time = MMailUtils.getCurrentTimestamp()
        return true
    end
    return false
end

-- 标记附件为已领取
function MailBase:MarkAsClaimed()
    if not self.claimed and self.attachments and #self.attachments > 0 then
        self.claimed = true
        self.tracking.claim_time = MMailUtils.getCurrentTimestamp()
        return true
    end
    return false
end

-- 标记邮件为已删除
function MailBase:MarkAsDeleted()
    if not self.deleted then
        self.deleted = true
        self.tracking.delete_time = MMailUtils.getCurrentTimestamp()
        return true
    end
    return false
end

-- 检查邮件是否过期
function MailBase:IsExpired()
    return MMailUtils.isExpired(self.expire_time)
end

-- 获取剩余过期时间（秒）
function MailBase:GetRemainingTime()
    return MMailUtils.getRemainingTime(self.expire_time)
end

-- 获取格式化的剩余时间文本
function MailBase:GetRemainingTimeText()
    return MMailUtils.formatRemainingTime(self.expire_time)
end

-- 是否有未领取的附件
function MailBase:HasUnclaimedAttachments()
    return self.attachments and #self.attachments > 0 and not self.claimed
end

-- 获取邮件状态
function MailBase:GetStatus()
    if self.deleted then
        return MMailConst.MAIL_STATUS.DELETED
    elseif self:IsExpired() then
        return MMailConst.MAIL_STATUS.EXPIRED
    elseif self.claimed then
        return MMailConst.MAIL_STATUS.ATTACHMENT_CLAIMED
    elseif self:HasUnclaimedAttachments() then
        return MMailConst.MAIL_STATUS.ATTACHMENT_UNCLAIMED
    elseif self.read then
        return MMailConst.MAIL_STATUS.READ
    else
        return MMailConst.MAIL_STATUS.UNREAD
    end
end

-- 获取邮件摘要信息
function MailBase:GetSummary()
    return {
        uuid = self.uuid,
        title = self.title,
        sender = self.sender,
        create_time = self.create_time,
        has_attachment = self.attachments and #self.attachments > 0,
        is_read = self.read,
        is_claimed = self.claimed,
        is_expired = self:IsExpired(),
        is_deleted = self.deleted,
        importance = self.importance,
        type = self.type,
        remaining_time = self:GetRemainingTimeText(),
        status = self:GetStatus()
    }
end

-- 添加附件
function MailBase:AddAttachment(attachment)
    if #self.attachments >= MMailConst.MAX_ATTACHMENTS then
        return false, "附件数量已达上限"
    end
    
    table.insert(self.attachments, attachment)
    return true
end

-- 移除附件
function MailBase:RemoveAttachment(index)
    if not self.attachments or #self.attachments == 0 or not self.attachments[index] then
        return false, "附件不存在"
    end
    
    table.remove(self.attachments, index)
    return true
end

-- 添加标签
function MailBase:AddTag(tag)
    if not tag or tag == "" then
        return false
    end
    
    if not self.tags then
        self.tags = {}
    end
    
    if not table.insert(self.tags, tag) then
        return false
    end
    
    return true
end

-- 移除标签
function MailBase:RemoveTag(tag)
    if not self.tags then
        return false
    end
    
    for i, v in ipairs(self.tags) do
        if v == tag then
            table.remove(self.tags, i)
            return true
        end
    end
    
    return false
end

-- 检查是否包含标签
function MailBase:HasTag(tag)
    if not self.tags then
        return false
    end
    
    for _, v in ipairs(self.tags) do
        if v == tag then
            return true
        end
    end
    
    return false
end

-- 设置自定义数据
function MailBase:SetCustomData(key, value)
    if not self.custom_data then
        self.custom_data = {}
    end
    
    self.custom_data[key] = value
    return true
end

-- 获取自定义数据
function MailBase:GetCustomData(key)
    if not self.custom_data then
        return nil
    end
    
    return self.custom_data[key]
end

-- 更新过期时间
function MailBase:UpdateExpireTime(expireTime)
    if not expireTime then
        -- 使用默认过期时间
        self.expire_time = MMailUtils.calculateExpiryTime(self.type, self.attachments and #self.attachments > 0, self.claimed)
    else
        self.expire_time = expireTime
    end
    
    return self.expire_time
end

-- 序列化邮件对象为表
function MailBase:Serialize()
    local mailData = {
        uuid = self.uuid,
        sender = self.sender,
        sender_type = self.sender_type,
        receiver = self.receiver,
        title = self.title,
        content = self.content,
        create_time = self.create_time,
        expire_time = self.expire_time,
        read = self.read,
        attachments = self.attachments,
        claimed = self.claimed,
        type = self.type,
        category = self.category,
        importance = self.importance,
        deleted = self.deleted,
        tags = self.tags,
        custom_data = self.custom_data,
        tracking = self.tracking
    }
    
    return mailData
end

-- 从表反序列化到邮件对象
function MailBase:Deserialize(mailData)
    if not mailData then
        return false
    end
    
    -- 复制所有字段
    for key, value in pairs(mailData) do
        self[key] = value
    end
    
    -- 确保某些必要的字段存在
    self.tags = self.tags or {}
    self.custom_data = self.custom_data or {}
    self.tracking = self.tracking or {}
    
    return true
end

-- 转换为字符串（调试用）
function MailBase:__tostring()
    return string.format("Mail[%s]: %s - %s", self.uuid, self.title, self:GetStatus())
end

return MailBase