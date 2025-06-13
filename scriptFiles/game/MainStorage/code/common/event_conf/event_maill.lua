--- 邮件事件配置文件
--- 包含所有邮件系统相关的事件名称、错误码和错误消息定义
--- V109 miniw-haima

---@class MailEventConfig
local MailEventConfig = {}

--[[
===================================
事件定义部分
===================================
]]

-- 客户端请求事件
MailEventConfig.REQUEST = {
    GET_LIST = "MailRequest_GetList",           -- 获取邮件列表
    CLAIM_MAIL = "MailRequest_ClaimMail",       -- 领取指定邮件
    BATCH_CLAIM = "MailRequest_BatchClaim",     -- 一键领取邮件
    DELETE_MAIL = "MailRequest_DeleteMail",     -- 删除邮件
    READ_MAIL = "MailRequest_ReadMail",         -- 阅读邮件
}

-- 服务器响应事件
MailEventConfig.RESPONSE = {
    MAIL_LIST = "MailResponse_List",            -- 邮件列表响应
    CLAIM_SUCCESS = "MailResponse_ClaimSuccess", -- 领取成功响应
    BATCH_CLAIM_SUCCESS = "MailResponse_BatchClaimSuccess", -- 批量领取成功响应
    DELETE_SUCCESS = "MailResponse_DeleteSuccess", -- 删除成功响应
    READ_SUCCESS = "MailResponse_ReadSuccess",   -- 阅读成功响应
    ERROR = "MailResponse_Error",               -- 错误响应
}

-- 服务器通知事件
MailEventConfig.NOTIFY = {
    NEW_MAIL = "MailNotify_NewMail",           -- 新邮件通知
    MAIL_SYNC = "MailNotify_Sync",             -- 邮件同步通知
}

--[[
===================================
错误码和错误消息定义
===================================
]]

-- 错误码定义
MailEventConfig.ERROR_CODES = {
    SUCCESS = 0,
    PLAYER_NOT_FOUND = 1,
    MAIL_NOT_FOUND = 2,
    MAIL_ALREADY_CLAIMED = 3,
    MAIL_EXPIRED = 4,
    MAIL_NO_ATTACHMENT = 5,
    INSUFFICIENT_BAG_SPACE = 6,
    INVALID_PARAMETERS = 7,
    PERMISSION_DENIED = 8,
    MAIL_ALREADY_READ = 9,
    MAIL_ALREADY_DELETED = 10,
    BATCH_CLAIM_FAILED = 11,
    SYSTEM_ERROR = 12,
}

-- 错误消息映射
MailEventConfig.ERROR_MESSAGES = {
    [MailEventConfig.ERROR_CODES.SUCCESS] = "操作成功",
    [MailEventConfig.ERROR_CODES.PLAYER_NOT_FOUND] = "玩家不存在",
    [MailEventConfig.ERROR_CODES.MAIL_NOT_FOUND] = "邮件不存在",
    [MailEventConfig.ERROR_CODES.MAIL_ALREADY_CLAIMED] = "邮件附件已领取",
    [MailEventConfig.ERROR_CODES.MAIL_EXPIRED] = "邮件已过期",
    [MailEventConfig.ERROR_CODES.MAIL_NO_ATTACHMENT] = "邮件没有附件",
    [MailEventConfig.ERROR_CODES.INSUFFICIENT_BAG_SPACE] = "背包空间不足",
    [MailEventConfig.ERROR_CODES.INVALID_PARAMETERS] = "参数无效",
    [MailEventConfig.ERROR_CODES.PERMISSION_DENIED] = "权限不足",
    [MailEventConfig.ERROR_CODES.MAIL_ALREADY_READ] = "邮件已阅读",
    [MailEventConfig.ERROR_CODES.MAIL_ALREADY_DELETED] = "邮件已删除",
    [MailEventConfig.ERROR_CODES.BATCH_CLAIM_FAILED] = "批量领取失败",
    [MailEventConfig.ERROR_CODES.SYSTEM_ERROR] = "系统错误",
}

--[[
===================================
配置辅助函数
===================================
]]

--- 获取错误消息
---@param errorCode number 错误码
---@return string 错误消息
function MailEventConfig.GetErrorMessage(errorCode)
    return MailEventConfig.ERROR_MESSAGES[errorCode] or "未知错误"
end

--- 检查请求事件名称是否有效
---@param eventName string 事件名称
---@return boolean 是否有效
function MailEventConfig.IsValidRequestEvent(eventName)
    for _, event in pairs(MailEventConfig.REQUEST) do
        if event == eventName then
            return true
        end
    end
    return false
end

--- 检查响应事件名称是否有效
---@param eventName string 事件名称
---@return boolean 是否有效
function MailEventConfig.IsValidResponseEvent(eventName)
    for _, event in pairs(MailEventConfig.RESPONSE) do
        if event == eventName then
            return true
        end
    end
    return false
end

--- 获取所有请求事件列表
---@return table 请求事件列表
function MailEventConfig.GetAllRequestEvents()
    local events = {}
    for _, event in pairs(MailEventConfig.REQUEST) do
        table.insert(events, event)
    end
    return events
end

--- 获取所有响应事件列表
---@return table 响应事件列表
function MailEventConfig.GetAllResponseEvents()
    local events = {}
    for _, event in pairs(MailEventConfig.RESPONSE) do
        table.insert(events, event)
    end
    return events
end

return MailEventConfig
