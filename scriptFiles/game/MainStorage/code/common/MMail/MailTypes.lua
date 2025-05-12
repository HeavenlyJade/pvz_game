--- 邮件类型和常量定义
--- V109 miniw-haima
--- 提供邮件系统使用的所有常量、枚举和错误码

---@class MailTypes
local MailTypes = {}

--- 邮件类型枚举
MailTypes.MAIL_TYPE = {
    SYSTEM = 1,   -- 系统邮件 (系统公告、活动奖励等)
    PLAYER = 2,   -- 玩家邮件 (玩家之间的邮件)
    ADMIN = 3,    -- 管理员邮件 (GM发送的邮件)
    EVENT = 4     -- 事件邮件 (游戏事件触发的邮件)
}

--- 邮件状态枚举
MailTypes.MAIL_STATUS = {
    UNREAD = 0,          -- 未读
    READ = 1,            -- 已读未领取
    CLAIMED = 2,         -- 已领取附件
    DELETED = 3          -- 已删除
}

--- 邮件操作类型枚举
MailTypes.MAIL_OPERATION = {
    READ = 1,            -- 读取邮件
    CLAIM_ATTACHMENT = 2, -- 领取附件
    DELETE = 3           -- 删除邮件
}

--- 邮件错误码枚举
MailTypes.ERROR_CODE = {
    SUCCESS = 0,               -- 操作成功
    MAIL_NOT_FOUND = 1,        -- 邮件不存在
    ALREADY_CLAIMED = 2,       -- 附件已领取
    NO_ATTACHMENT = 3,         -- 没有附件
    EXPIRED = 4,               -- 邮件已过期
    INVENTORY_FULL = 5,        -- 背包已满
    INVALID_OPERATION = 6,     -- 无效操作
    SYSTEM_ERROR = 7,          -- 系统错误
    PERMISSION_DENIED = 8,     -- 权限不足
    UNCLAIMED_ATTACHMENT = 9   -- 有未领取的附件
}

--- 邮件错误消息对照表
MailTypes.ERROR_MESSAGES = {
    [MailTypes.ERROR_CODE.SUCCESS] = "操作成功",
    [MailTypes.ERROR_CODE.MAIL_NOT_FOUND] = "邮件不存在",
    [MailTypes.ERROR_CODE.ALREADY_CLAIMED] = "附件已领取",
    [MailTypes.ERROR_CODE.NO_ATTACHMENT] = "该邮件没有附件",
    [MailTypes.ERROR_CODE.EXPIRED] = "邮件已过期",
    [MailTypes.ERROR_CODE.INVENTORY_FULL] = "背包空间不足",
    [MailTypes.ERROR_CODE.INVALID_OPERATION] = "无效操作",
    [MailTypes.ERROR_CODE.SYSTEM_ERROR] = "系统错误",
    [MailTypes.ERROR_CODE.PERMISSION_DENIED] = "权限不足",
    [MailTypes.ERROR_CODE.UNCLAIMED_ATTACHMENT] = "请先领取附件"
}

--- 邮件来源枚举
MailTypes.MAIL_SOURCE = {
    SYSTEM = 1,         -- 系统
    QUEST = 2,          -- 任务
    ACHIEVEMENT = 3,    -- 成就
    EVENT = 4,          -- 活动
    PURCHASE = 5,       -- 购买
    ADMIN = 6,          -- 管理员
    COMPENSATION = 7,   -- 补偿
    FRIEND = 8          -- 好友
}

--- 邮件预设模板
MailTypes.MAIL_TEMPLATES = {
    WELCOME = {
        title = "欢迎来到游戏",
        content = "亲爱的玩家，欢迎来到我们的游戏世界！这里有一些初始道具帮助你开始冒险。祝你游戏愉快！",
        sender = "系统",
        sender_type = MailTypes.MAIL_TYPE.SYSTEM,
        expire_days = 30
    },
    
    DAILY_REWARD = {
        title = "每日奖励",
        content = "这是您今日登录的奖励，请查收！",
        sender = "系统",
        sender_type = MailTypes.MAIL_TYPE.SYSTEM,
        expire_days = 30
    },
    
    ACHIEVEMENT = {
        title = "成就达成",
        content = "恭喜您完成了成就【%s】，这是您的奖励！",
        sender = "成就系统",
        sender_type = MailTypes.MAIL_TYPE.SYSTEM,
        expire_days = 30
    },
    
    COMPENSATION = {
        title = "系统补偿",
        content = "亲爱的玩家，由于%s，我们向您发放补偿，请查收。",
        sender = "系统管理员",
        sender_type = MailTypes.MAIL_TYPE.ADMIN,
        expire_days = 30
    }
}

--- 邮件网络命令
MailTypes.MAIL_COMMANDS = {
    -- 客户端发送
    GET_LIST = "mail_get_list",           -- 获取邮件列表
    READ = "mail_read",                   -- 阅读邮件
    CLAIM_ATTACHMENT = "mail_claim_attachment", -- 领取附件
    DELETE = "mail_delete",               -- 删除邮件
    
    -- 服务器响应
    LIST_RESPONSE = "mail_list_response",      -- 邮件列表响应
    READ_RESPONSE = "mail_read_response",      -- 读取邮件响应
    CLAIM_RESPONSE = "mail_claim_attachment_response", -- 领取附件响应
    DELETE_RESPONSE = "mail_delete_response",  -- 删除邮件响应
    NEW_NOTIFICATION = "mail_new_notification" -- 新邮件通知
}

--- 获取错误消息
---@param errorCode number 错误码
---@return string 错误消息
function MailTypes.GetErrorMessage(errorCode)
    return MailTypes.ERROR_MESSAGES[errorCode] or "未知错误"
end

--- 创建邮件模板
---@param templateKey string 模板键名
---@param params table 替换参数
---@return table 邮件数据
function MailTypes.CreateFromTemplate(templateKey, params)
    local template = MailTypes.MAIL_TEMPLATES[templateKey]
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

--- 判断邮件是否过期
---@param mail table 邮件数据
---@return boolean 是否过期
function MailTypes.IsMailExpired(mail)
    if not mail or not mail.expire_time then
        return false
    end
    
    return os.time() > mail.expire_time
end

--- 计算邮件过期时间
---@param days number 过期天数
---@return number 过期时间戳
function MailTypes.CalculateExpireTime(days)
    return os.time() + (days or 30) * 86400 -- 默认30天
end

return MailTypes