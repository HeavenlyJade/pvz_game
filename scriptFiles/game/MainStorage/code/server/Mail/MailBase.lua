local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig

---@class MailBase :Class 邮件基类，定义邮件的通用属性和方法
---@field id string 邮件唯一ID
---@field title string 邮件标题
---@field content string 邮件内容
---@field sender string 发件人
---@field send_time number 发送时间戳
---@field expire_time number 过期时间戳
---@field status number 邮件状态 (0: 未读, 1: 已领取附件, 2: 已删除)
---@field attachments table<number, MailAttachment> 附件列表
---@field has_attachment boolean 是否有附件
---@field expire_days number 有效期天数
---@field New fun(data:MailData):MailBase
local _MailBase = ClassMgr.Class("MailBase")

-- 邮件状态常量
_MailBase.STATUS = MailEventConfig.STATUS

-- 默认配置
_MailBase.DEFAULT_EXPIRE_DAYS = MailEventConfig.DEFAULT_EXPIRE_DAYS

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

--- 初始化邮件对象
---@param data MailData 邮件数据
function _MailBase:OnInit(data)
    -- 基本信息
    self.id = data.id or ""
    self.title = data.title or "无标题"
    self.content = data.content or ""
    self.sender = data.sender or "系统"

    -- 时间相关
    self.send_time = data.send_time or os.time()
    self.expire_days = data.expire_days or self.DEFAULT_EXPIRE_DAYS
    self.expire_time = data.expire_time or (self.send_time + (self.expire_days * 86400))

    -- 状态相关
    self.status = data.status or _MailBase.STATUS.UNREAD

    -- 附件相关
    self.attachments = data.attachments or {}
    self.has_attachment = self:CalculateHasAttachment()

    -- 扩展字段
    self.mail_type = data.mail_type or "personal"

    -- gg.log("邮件对象初始化完成", self.id, self.title)
end

--------------------------------------------------
-- 状态检查方法
--------------------------------------------------

--- 检查邮件是否已过期
---@return boolean 是否已过期
function _MailBase:IsExpired()
    return self.expire_time and self.expire_time < os.time()
end

--- 检查邮件是否已领取附件
---@return boolean 是否已领取附件
function _MailBase:IsClaimed()
    return self.status >= _MailBase.STATUS.CLAIMED
end

--- 检查邮件是否已删除
---@return boolean 是否已删除
function _MailBase:IsDeleted()
    return self.status >= _MailBase.STATUS.DELETED
end

--- 检查邮件是否有效（未过期且未删除）
---@return boolean 是否有效
function _MailBase:IsValid()
    return not self:IsExpired() and not self:IsDeleted()
end

--- 检查是否可以领取附件
---@return boolean 是否可以领取附件
function _MailBase:CanClaimAttachment()
    return self.has_attachment and not self:IsClaimed() and self:IsValid()
end

--------------------------------------------------
-- 附件相关方法
--------------------------------------------------

--- 计算是否有附件
---@return boolean 是否有附件
function _MailBase:CalculateHasAttachment()
    return self.attachments and #self.attachments > 0
end

--- 添加附件
---@param attachment MailAttachment 附件对象
function _MailBase:AddAttachment(attachment)
    if not self.attachments then
        self.attachments = {}
    end

    table.insert(self.attachments, attachment)
    self.has_attachment = self:CalculateHasAttachment()

    gg.log("添加邮件附件", self.id, attachment.name, attachment.amount)
end

--- 移除附件
---@param index number 附件索引
function _MailBase:RemoveAttachment(index)
    if self.attachments and self.attachments[index] then
        local removed = table.remove(self.attachments, index)
        self.has_attachment = self:CalculateHasAttachment()

        gg.log("移除邮件附件", self.id, removed.name)
        return removed
    end
    return nil
end

--- 获取附件列表
---@return table<number, MailAttachment> 附件列表
function _MailBase:GetAttachments()
    return self.attachments or {}
end

--- 清空所有附件
function _MailBase:ClearAttachments()
    self.attachments = {}
    self.has_attachment = false
    gg.log("清空邮件附件", self.id)
end

--------------------------------------------------
-- 状态管理方法
--------------------------------------------------

--- 标记为已领取附件
function _MailBase:MarkAsClaimed()
    if self.has_attachment and self.status < _MailBase.STATUS.CLAIMED then
        self.status = _MailBase.STATUS.CLAIMED
        gg.log("邮件附件已领取", self.id)
        return true
    end
    return false
end

--- 标记为已删除
function _MailBase:MarkAsDeleted()
    if self.status < _MailBase.STATUS.DELETED then
        self.status = _MailBase.STATUS.DELETED
        gg.log("邮件标记为已删除", self.id)
        return true
    end
    return false
end

--------------------------------------------------
-- 数据转换方法
--------------------------------------------------

--- 转换为客户端数据格式
---@return table 客户端邮件数据
function _MailBase:ToClientData()
    return {
        id = self.id,
        title = self.title,
        content = self.content,
        sender = self.sender,
        send_time = self.send_time,
        expire_time = self.expire_time,
        status = self.status,
        has_attachment = self.has_attachment,
        attachments = self.attachments,
        mail_type = self.mail_type,
        is_claimed = self:IsClaimed()
    }
end

--- 转换为存储数据格式
---@return table 存储邮件数据
function _MailBase:ToStorageData()
    return {
        id = self.id,
        title = self.title,
        content = self.content,
        sender = self.sender,
        send_time = self.send_time,
        expire_time = self.expire_time,
        expire_days = self.expire_days,
        status = self.status,
        attachments = self.attachments,
        mail_type = self.mail_type
    }
end

--------------------------------------------------
-- 工具方法
--------------------------------------------------

--- 获取邮件摘要信息
---@return string 邮件摘要
function _MailBase:GetSummary()
    local statusText = ""
    if self:IsDeleted() then
        statusText = "已删除"
    elseif self:IsClaimed() then
        statusText = "已领取"
    else
        statusText = "未领取"
    end

    local attachmentText = self.has_attachment and "有附件" or "无附件"

    return string.format("[%s] %s - %s (%s)", statusText, self.title, self.sender, attachmentText)
end

--- 获取格式化的发送时间
---@return string 格式化时间
function _MailBase:GetFormattedSendTime()
    return tostring(os.date("%Y-%m-%d %H:%M:%S", self.send_time))
end

--- 获取格式化的过期时间
---@return string 格式化时间
function _MailBase:GetFormattedExpireTime()
    return tostring(os.date("%Y-%m-%d %H:%M:%S", self.expire_time))
end

--- 获取剩余有效时间（秒）
---@return number 剩余时间，负数表示已过期
function _MailBase:GetRemainingTime()
    return self.expire_time - os.time()
end

--- 验证邮件数据完整性
---@return boolean, string 是否有效，错误信息
function _MailBase:Validate()
    if not self.id or self.id == "" then
        return false, "邮件ID不能为空"
    end

    if not self.title or self.title == "" then
        return false, "邮件标题不能为空"
    end

    if not self.send_time or self.send_time <= 0 then
        return false, "发送时间无效"
    end

    if not self.expire_time or self.expire_time <= 0 then
        return false, "过期时间无效"
    end

    if self.expire_time <= self.send_time then
        return false, "过期时间不能早于发送时间"
    end

    return true, ""
end

--- 获取用于调试的字符串表示
---@return string 调试信息
function _MailBase:ToString()
    return string.format("MailBase{id=%s, title=%s, sender=%s, status=%d, hasAttachment=%s}",
        self.id, self.title, self.sender, self.status, tostring(self.has_attachment))
end

return _MailBase
