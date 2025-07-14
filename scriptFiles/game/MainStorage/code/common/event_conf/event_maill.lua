--- 邮件事件配置文件
--- 包含所有邮件系统相关的事件名称、错误码和错误消息定义
--- V109 miniw-haima

---@class MailEventConfig
local MailEventConfig = {}

--[[
===================================
网络事件定义
===================================
]]

-- 客户端请求事件
MailEventConfig.REQUEST = {
    GET_LIST = "MailRequest_GetList",           -- 获取邮件列表
    CLAIM_MAIL = "MailRequest_ClaimMail",       -- 领取指定邮件
    BATCH_CLAIM = "MailRequest_BatchClaim",     -- 一键领取邮件
    DELETE_MAIL = "MailRequest_DeleteMail",     -- 删除邮件
    DELETE_READ_MAILS = "MailRequest_DeleteRead", -- 删除已读邮件
    MARK_READ = "MailRequest_MarkRead",         -- 标记邮件为已读
}

-- 服务器响应事件
MailEventConfig.RESPONSE = {
    LIST_RESPONSE = "MailResponse_List",      -- 邮件列表响应
    CLAIM_RESPONSE = "MailResponse_Claim", -- 领取附件响应
    DELETE_RESPONSE = "MailResponse_Delete",  -- 删除邮件响应
    NEW_NOTIFICATION = "mail_new_notification", -- 新邮件通知
    BATCH_CLAIM_SUCCESS = "MailResponse_BatchClaimSuccess",
    DELETE_READ_SUCCESS = "MailResponse_DeleteReadSuccess",
    ERROR = "MailResponse_Error",               -- 错误响应
}

-- 服务器通知事件
MailEventConfig.NOTIFY = {
    NEW_MAIL = "MailNotify_NewMail",           -- 新邮件通知
    MAIL_SYNC = "MailNotify_Sync",             -- 邮件同步通知
}

--[[
===================================
通用配置定义
===================================
]]
MailEventConfig.DEFAULT_EXPIRE_DAYS = 30    -- 邮件默认过期天数

--[[
===================================
枚举定义
===================================
]]

--- 邮件类型枚举
MailEventConfig.MAIL_TYPE = {
    SYSTEM = "系统",   -- 系统邮件 (系统公告、活动奖励等)
    PLAYER = "玩家",   -- 玩家邮件 (玩家之间的邮件)
    ADMIN = "管理员",    -- 管理员邮件 (GM发送的邮件)
    EVENT = "事件",     -- 事件邮件 (游戏事件触发的邮件)
}

--- 邮件状态枚举
MailEventConfig.STATUS = {
    UNREAD = 0,          -- 未读 (附件未领取)
    CLAIMED = 1,         -- 已领取附件
    DELETED = 2,         -- 已删除
    READ = 3             -- 已读
}

--- 邮件操作类型枚举
MailEventConfig.MAIL_OPERATION = {
    CLAIM_ATTACHMENT = 1, -- 领取附件
    DELETE = 2           -- 删除邮件
}

--- 邮件来源枚举
MailEventConfig.MAIL_SOURCE = {
    SYSTEM = 1,         -- 系统
    QUEST = 2,          -- 任务
    ACHIEVEMENT = 3,    -- 成就
    EVENT = 4,          -- 活动
    PURCHASE = 5,       -- 购买
    ADMIN = 6,          -- 管理员
    COMPENSATION = 7,   -- 补偿
    FRIEND = 8          -- 好友
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
    MAIL_ALREADY_DELETED = 10,
    BATCH_CLAIM_FAILED = 11,
    SYSTEM_ERROR = 12,
    UNCLAIMED_ATTACHMENT = 13, -- 有未领取的附件
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
    [MailEventConfig.ERROR_CODES.MAIL_ALREADY_DELETED] = "邮件已删除",
    [MailEventConfig.ERROR_CODES.BATCH_CLAIM_FAILED] = "批量领取失败",
    [MailEventConfig.ERROR_CODES.SYSTEM_ERROR] = "系统错误",
    [MailEventConfig.ERROR_CODES.UNCLAIMED_ATTACHMENT] = "请先领取附件",
}

--[[
===================================
邮件模板定义
===================================
]]
MailEventConfig.MAIL_TEMPLATES = {
    WELCOME = {
        title = "欢迎来到游戏",
        content = "亲爱的玩家，欢迎来到我们的游戏世界！这里有一些初始道具帮助你开始冒险。祝你游戏愉快！",
        sender = "系统",
        sender_type = MailEventConfig.MAIL_TYPE.SYSTEM,
        expire_days = 30
    },

    DAILY_REWARD = {
        title = "每日奖励",
        content = "这是您今日登录的奖励，请查收！",
        sender = "系统",
        sender_type = MailEventConfig.MAIL_TYPE.SYSTEM,
        expire_days = 30
    },

    ACHIEVEMENT = {
        title = "成就达成",
        content = "恭喜您完成了成就【%s】，这是您的奖励！",
        sender = "成就系统",
        sender_type = MailEventConfig.MAIL_TYPE.SYSTEM,
        expire_days = 30
    },

    COMPENSATION = {
        title = "系统补偿",
        content = "亲爱的玩家，由于%s，我们向您发放补偿，请查收。",
        sender = "系统管理员",
        sender_type = MailEventConfig.MAIL_TYPE.ADMIN,
        expire_days = 30
    }
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

--- 创建邮件模板
---@param templateKey string 模板键名
---@param params table 替换参数
---@return table 邮件数据
function MailEventConfig.CreateFromTemplate(templateKey, params)
    local template = MailEventConfig.MAIL_TEMPLATES[templateKey]
    if not template then
        return nil
    end

    -- 创建邮件数据副本
    local mailData = {}
    for k, v in pairs(template) do
        mailData[k] = v
    end

    -- 处理内容中的格式化字符串
    if params then
        if type(mailData.content) == "string" and mailData.content:find("%%") then
            mailData.content = string.format(mailData.content, table.unpack(params))
        end

        -- 合并其他参数
        for k, v in pairs(params) do
            if k ~= 1 and k ~= 2 and k ~= 3 then -- 忽略数字索引(用于格式化)
                mailData[k] = v
            end
        end
    end

    return mailData
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
