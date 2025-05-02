--- V109
--- 邮件系统配置文件

local game = game

---@class MMailConfig
local MMailConfig = {
    -- 邮件类型定义
    MAIL_TYPES = {
        SYSTEM = 1,         -- 系统邮件（公告、通知）
        EVENT = 2,          -- 活动邮件（活动奖励、活动通知）
        REWARD = 3,         -- 奖励邮件（成就奖励、任务奖励）
        ADMIN = 4,          -- 管理员邮件（GM发送）
        PLAYER = 5,         -- 玩家邮件（玩家间发送，如果支持）
        TRADE = 6,          -- 交易邮件（拍卖、交易相关）
    },

    -- 邮件重要性级别
    IMPORTANCE_LEVEL = {
        LOW = 1,            -- 低重要性
        NORMAL = 2,         -- 普通重要性
        HIGH = 3,           -- 高重要性（会有特殊提示）
        URGENT = 4,         -- 紧急（登录时自动弹出）
    },

    -- 邮件状态定义
    MAIL_STATUS = {
        UNREAD = 1,         -- 未读
        READ = 2,           -- 已读
        ATTACHMENT_UNCLAIMED = 3,  -- 附件未领取
        ATTACHMENT_CLAIMED = 4,    -- 附件已领取
        DELETED = 5,        -- 已删除
        EXPIRED = 6,        -- 已过期
    },

    -- 附件类型映射
    ATTACHMENT_TYPES = {
        EQUIPMENT = 1,      -- 装备
        MATERIAL = 2,       -- 材料
        CONSUMABLE = 3,     -- 消耗品
        CURRENCY = 4,       -- 货币（金币、钻石等）
        CARD = 5,           -- 卡片
        TOKEN = 6,          -- 代币、活动币
    },

    -- 邮件有效期设置（单位：秒）
    EXPIRATION_TIME = {
        SYSTEM = 30 * 24 * 3600,      -- 系统邮件 30天
        EVENT = 15 * 24 * 3600,       -- 活动邮件 15天
        REWARD = 30 * 24 * 3600,      -- 奖励邮件 30天
        ADMIN = 90 * 24 * 3600,       -- 管理员邮件 90天
        PLAYER = 7 * 24 * 3600,       -- 玩家邮件 7天
        TRADE = 3 * 24 * 3600,        -- 交易邮件 3天
        
        -- 特殊规则
        CLAIMED = 7 * 24 * 3600,      -- 附件已领取的邮件保留7天
        DELETED = 24 * 3600,          -- 已删除邮件保留1天
    },

    -- 邮件自动清理设置
    AUTO_CLEANUP = {
        ENABLED = true,                -- 是否启用自动清理
        INTERVAL = 24 * 3600,          -- 清理间隔时间（秒）
        BATCH_SIZE = 50,               -- 每次清理的邮件数量
    },

    -- 邮件限制设置
    MAIL_LIMITS = {
        MAX_MAILS_PER_PLAYER = 100,       -- 每个玩家最多邮件数
        MAX_ATTACHMENTS_PER_MAIL = 10,    -- 每封邮件最多附件数
        MAX_PLAYER_RECIPIENTS = 20,       -- 玩家邮件最多收件人数
        MAX_TITLE_LENGTH = 50,            -- 标题最大长度
        MAX_CONTENT_LENGTH = 1000,        -- 内容最大长度
    },

    -- 邮件通知设置
    NOTIFICATION = {
        LOGIN_CHECK = true,            -- 登录时检查新邮件
        UNREAD_REMINDER = true,        -- 未读邮件提醒
        ATTACHMENT_REMINDER = true,    -- 未领取附件提醒
        EXPIRY_REMINDER = 3 * 24 * 3600, -- 过期前提醒时间（3天）
    },

    -- 邮件UI配置
    UI_CONFIG = {
        LIST_PAGE_SIZE = 10,            -- 列表每页显示邮件数
        AUTO_REFRESH_INTERVAL = 300,    -- 自动刷新间隔（秒）
        UNREAD_COLOR = {0, 255, 0, 255},  -- 未读邮件标题颜色
        READ_COLOR = {255, 255, 255, 255}, -- 已读邮件标题颜色
        IMPORTANT_ICON = "sandboxSysId://ministudio/ui/mail_important.png", -- 重要邮件图标
        ATTACHMENT_ICON = "sandboxSysId://ministudio/ui/mail_attachment.png", -- 附件图标
    },

    -- 邮件过滤器配置
    FILTER_CONFIG = {
        DEFAULT_FILTERS = {
            "ALL", "UNREAD", "ATTACHMENT", "SYSTEM", "EVENT", "REWARD"
        },
        FILTER_ICONS = {
            ALL = "sandboxSysId://ministudio/ui/filter_all.png",
            UNREAD = "sandboxSysId://ministudio/ui/filter_unread.png",
            ATTACHMENT = "sandboxSysId://ministudio/ui/filter_attachment.png",
            SYSTEM = "sandboxSysId://ministudio/ui/filter_system.png",
            EVENT = "sandboxSysId://ministudio/ui/filter_event.png",
            REWARD = "sandboxSysId://ministudio/ui/filter_reward.png",
        },
    },

    -- 系统邮件模板配置
    SYSTEM_MAIL_TEMPLATES = {
        WELCOME = {
            id = "welcome",
            title = "欢迎来到游戏",
            content = "亲爱的玩家，欢迎加入我们的游戏世界！这里有一些初始道具帮助你开始冒险。",
            attachments = {
                { type = 2, id = common_const.MAT_ID.FRAGMENT, quantity = 100 },
                { type = 4, id = "gold", quantity = 1000 }
            },
            importance = 3,
        },
        MAINTENANCE = {
            id = "maintenance",
            title = "服务器维护通知",
            content = "亲爱的玩家，我们将于{time}进行服务器维护，预计持续{duration}小时。感谢您的理解与支持！",
            attachments = {
                { type = 3, id = 1001, quantity = 5 } -- 补偿道具
            },
            importance = 4,
        },
        LEVEL_UP = {
            id = "level_up",
            title = "等级提升奖励",
            content = "恭喜你达到{level}级！这是给你的奖励。",
            attachments = {},  -- 根据等级动态生成
            importance = 2,
        },
    },

    -- 活动邮件配置
    EVENT_MAIL_CONFIG = {
        DELIVERY_BATCH_SIZE = 1000,    -- 批量发送数量
        RETRY_INTERVAL = 1800,         -- 发送失败重试间隔（秒）
        MAX_RETRY_COUNT = 3,           -- 最大重试次数
    },

    -- 邮件存储键前缀配置
    STORAGE_KEYS = {
        PLAYER_MAIL = "mail_",         -- 玩家邮件键前缀
        SYSTEM_MAIL = "system_mail",   -- 系统邮件存储键
        EVENT_MAIL = "event_mail_",    -- 活动邮件前缀
        MAIL_INDEX = "mail_index",     -- 邮件索引键
        MAIL_LOG = "mail_log_",        -- 邮件日志前缀
    },
}

-- 创建邮件类型与名称的映射关系
MMailConfig.MAIL_TYPE_NAMES = {}
for name, value in pairs(MMailConfig.MAIL_TYPES) do
    MMailConfig.MAIL_TYPE_NAMES[value] = name
end

-- 返回邮件类型的名称
function MMailConfig:getMailTypeName(mailType)
    return self.MAIL_TYPE_NAMES[mailType] or "UNKNOWN"
end

-- 获取邮件过期时间
function MMailConfig:getExpirationTime(mailType, hasAttachment, isClaimed)
    if isClaimed then
        return self.EXPIRATION_TIME.CLAIMED
    end
    
    if mailType and self.EXPIRATION_TIME[self:getMailTypeName(mailType)] then
        return self.EXPIRATION_TIME[self:getMailTypeName(mailType)]
    end
    
    return self.EXPIRATION_TIME.SYSTEM -- 默认使用系统邮件过期时间
end

-- 检查邮件数量是否达到上限
function MMailConfig:isMailLimitReached(currentCount)
    return currentCount >= self.MAIL_LIMITS.MAX_MAILS_PER_PLAYER
end

-- 检查附件数量是否超过限制
function MMailConfig:isAttachmentCountValid(count)
    return count <= self.MAIL_LIMITS.MAX_ATTACHMENTS_PER_MAIL
end

-- 获取过滤器图标
function MMailConfig:getFilterIcon(filterName)
    return self.FILTER_CONFIG.FILTER_ICONS[filterName] or self.FILTER_CONFIG.FILTER_ICONS.ALL
end

-- 获取系统邮件模板
function MMailConfig:getSystemMailTemplate(templateId)
    return self.SYSTEM_MAIL_TEMPLATES[templateId]
end

return MMailConfig