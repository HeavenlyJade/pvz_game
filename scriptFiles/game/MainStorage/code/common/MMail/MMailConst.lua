--- V109
--- 邮件系统常量定义

---@class MMailConst
local MMailConst = {
    -- 邮件操作类型
    OPERATION_TYPE = {
        CREATE = 1,         -- 创建邮件
        SEND = 2,           -- 发送邮件
        READ = 3,           -- 读取邮件
        CLAIM = 4,          -- 领取附件
        DELETE = 5,         -- 删除邮件
        BATCH_SEND = 6,     -- 批量发送
        RESTORE = 7,        -- 恢复已删除邮件
        UPDATE = 8,         -- 更新邮件内容
        CLEAN = 9,          -- 清理过期邮件
        FORWARD = 10,       -- 转发邮件
    },

    -- 邮件操作结果状态码
    RESULT_CODE = {
        SUCCESS = 0,                   -- 操作成功
        MAIL_NOT_FOUND = 1,            -- 邮件不存在
        MAIL_EXPIRED = 2,              -- 邮件已过期
        MAIL_DELETED = 3,              -- 邮件已删除
        ATTACHMENT_CLAIMED = 4,        -- 附件已被领取
        ATTACHMENT_EMPTY = 5,          -- 没有附件
        BAG_FULL = 6,                  -- 背包已满
        PLAYER_NOT_FOUND = 7,          -- 玩家不存在
        PERMISSION_DENIED = 8,         -- 权限不足
        INVALID_PARAMETER = 9,         -- 无效参数
        SYSTEM_ERROR = 10,             -- 系统错误
        MAIL_LIMIT_REACHED = 11,       -- 邮件数量达到上限
        ATTACHMENT_LIMIT_REACHED = 12, -- 附件数量达到上限
        CONTENT_TOO_LONG = 13,         -- 内容过长
        SEND_TOO_FREQUENTLY = 14,      -- 发送过于频繁
        OPERATION_CANCELED = 15,       -- 操作已取消
        TEMPLATE_NOT_FOUND = 16,       -- 模板不存在
        MAIL_ALREADY_EXISTS = 17,      -- 邮件已存在
        STORAGE_ERROR = 18,            -- 存储错误
    },

    -- 邮件发送者类型
    SENDER_TYPE = {
        SYSTEM = 1,         -- 系统
        PLAYER = 2,         -- 玩家
        ADMIN = 3,          -- 管理员
        GM = 4,             -- 游戏管理员
        NPC = 5,            -- NPC
        GUILD = 6,          -- 公会
    },
    
    -- 邮件发送目标类型
    TARGET_TYPE = {
        SINGLE = 1,         -- 单个玩家
        MULTIPLE = 2,       -- 多个玩家
        ALL = 3,            -- 所有玩家
        CONDITION = 4,      -- 条件筛选
        GUILD = 5,          -- 公会成员
    },
    
    -- 邮件附件状态
    ATTACHMENT_STATUS = {
        UNCLAIMED = 1,      -- 未领取
        CLAIMED = 2,        -- 已领取
        EXPIRED = 3,        -- 已过期
        INVALID = 4,        -- 无效(如物品不存在)
    },
    
    -- 邮件日志级别
    LOG_LEVEL = {
        DEBUG = 1,          -- 调试信息
        INFO = 2,           -- 普通信息
        WARNING = 3,        -- 警告
        ERROR = 4,          -- 错误
        CRITICAL = 5,       -- 严重错误
    },
    
    -- 邮件批处理操作类型
    BATCH_OPERATION = {
        READ_ALL = 1,       -- 全部标记为已读
        CLAIM_ALL = 2,      -- 领取所有附件
        DELETE_ALL = 3,     -- 删除全部指定邮件
    },
    
    -- 邮件领取附件结果
    CLAIM_RESULT = {
        ALL_SUCCESS = 1,    -- 全部成功
        PARTIAL_SUCCESS = 2, -- 部分成功
        ALL_FAILED = 3,     -- 全部失败
    },
    
    -- 邮件附件领取失败原因
    CLAIM_FAIL_REASON = {
        BAG_FULL = 1,       -- 背包已满
        ITEM_INVALID = 2,   -- 物品无效
        ALREADY_CLAIMED = 3, -- 已经领取
        MAIL_EXPIRED = 4,   -- 邮件过期
    },
    
    -- 邮件筛选类型
    FILTER_TYPE = {
        ALL = 1,            -- 全部邮件
        UNREAD = 2,         -- 未读邮件
        ATTACHMENT = 3,     -- 有附件邮件
        TYPE = 4,           -- 按类型筛选
        TIME = 5,           -- 按时间筛选
        SENDER = 6,         -- 按发送者筛选
    },
    
    -- 邮件发送优先级
    SEND_PRIORITY = {
        LOW = 1,            -- 低优先级
        NORMAL = 2,         -- 普通优先级
        HIGH = 3,           -- 高优先级
        URGENT = 4,         -- 紧急优先级
    },
    
    -- 邮件渲染模式
    RENDER_MODE = {
        TEXT = 1,           -- 纯文本
        HTML = 2,           -- HTML
        RICH_TEXT = 3,      -- 富文本
    },
    
    -- 数据同步策略
    SYNC_STRATEGY = {
        IMMEDIATE = 1,      -- 立即同步
        DELAYED = 2,        -- 延迟同步
        BATCH = 3,          -- 批量同步
    },
    
    -- 模板变量前缀和后缀
    TEMPLATE_VAR = {
        PREFIX = "{",
        SUFFIX = "}",
    },
    
    -- 系统预定义发送者
    PREDEFINED_SENDER = {
        SYSTEM = "System",
        ADMIN = "Admin",
        GAME_MASTER = "GameMaster",
        EVENT = "Event",
        REWARD = "Reward",
    },
    
    -- 领取附件时最大重试次数
    MAX_CLAIM_RETRY = 3,
    
    -- 发送邮件冷却时间(秒)
    SEND_COOLDOWN = {
        PLAYER = 60,         -- 玩家发送冷却
        SYSTEM = 5,          -- 系统发送冷却
        ADMIN = 1,           -- 管理员发送冷却
    },
    
    -- 默认邮件过期时间(如果未在配置中指定)
    DEFAULT_EXPIRY = 30 * 24 * 3600,  -- 30天(秒)
    
    -- 全服邮件投递批次间隔(秒)
    GLOBAL_MAIL_BATCH_INTERVAL = 300,  -- 5分钟
    
    -- 邮件读取时最大附件数限制
    MAX_FETCH_ATTACHMENTS = 50,
    
    -- 默认邮件分页大小
    DEFAULT_PAGE_SIZE = 10,
    
    -- 邮件标题最大长度
    MAX_TITLE_LENGTH = 50,
    
    -- 邮件内容最大长度
    MAX_CONTENT_LENGTH = 1000,
    
    -- 邮件附件最大数量
    MAX_ATTACHMENTS = 10,
    
    -- 邮件接收人最大数量(批量发送)
    MAX_RECIPIENTS = 100,
    
    -- 错误信息表
    ERROR_MESSAGE = {
        [1] = "邮件不存在",
        [2] = "邮件已过期",
        [3] = "邮件已删除",
        [4] = "附件已被领取",
        [5] = "没有附件",
        [6] = "背包已满",
        [7] = "玩家不存在",
        [8] = "权限不足",
        [9] = "无效参数",
        [10] = "系统错误",
        [11] = "邮件数量达到上限",
        [12] = "附件数量达到上限",
        [13] = "内容过长",
        [14] = "发送过于频繁",
        [15] = "操作已取消",
        [16] = "模板不存在",
        [17] = "邮件已存在",
        [18] = "存储错误",
    },
}

-- 获取操作类型名称
function MMailConst:getOperationName(operationType)
    for name, value in pairs(self.OPERATION_TYPE) do
        if value == operationType then
            return name
        end
    end
    return "UNKNOWN"
end

-- 获取结果代码对应的错误信息
function MMailConst:getErrorMessage(resultCode)
    return self.ERROR_MESSAGE[resultCode] or "未知错误"
end

-- 检查操作是否成功
function MMailConst:isSuccess(resultCode)
    return resultCode == self.RESULT_CODE.SUCCESS
end

-- 创建操作结果
function MMailConst:createResult(resultCode, data)
    return {
        code = resultCode,
        success = self:isSuccess(resultCode),
        message = self:getErrorMessage(resultCode),
        data = data or {}
    }
end

-- 检查是否需要立即同步
function MMailConst:shouldSyncImmediately(operationType)
    local highPriorityOps = {
        self.OPERATION_TYPE.SEND,
        self.OPERATION_TYPE.CLAIM,
        self.OPERATION_TYPE.DELETE,
    }
    
    for _, op in ipairs(highPriorityOps) do
        if operationType == op then
            return true
        end
    end
    
    return false
end

-- 检查附件状态是否有效
function MMailConst:isValidAttachmentStatus(status)
    for _, value in pairs(self.ATTACHMENT_STATUS) do
        if value == status then
            return true
        end
    end
    return false
end

return MMailConst