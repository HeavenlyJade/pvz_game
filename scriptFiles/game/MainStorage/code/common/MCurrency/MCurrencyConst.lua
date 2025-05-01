--- V109
--- 货币系统常量定义

---@class MCurrencyConst
local MCurrencyConst = {
    -- 货币操作类型
    OPERATION_TYPE = {
        GAIN = 1,           -- 获得货币
        CONSUME = 2,        -- 消费货币
        EXCHANGE = 3,       -- 货币兑换
        SYSTEM_ADJUST = 4,  -- 系统调整
        RESET = 5,          -- 重置
        REFUND = 6          -- 退款
    },

    -- 货币操作结果状态码
    RESULT_CODE = {
        SUCCESS = 0,                 -- 操作成功
        INVALID_CURRENCY = 1,        -- 无效的货币类型
        INSUFFICIENT_AMOUNT = 2,     -- 货币数量不足
        EXCEEDS_CAP = 3,             -- 超过货币上限
        INVALID_AMOUNT = 4,          -- 无效的数量
        EXCHANGE_NOT_SUPPORTED = 5,  -- 不支持的兑换
        DAILY_LIMIT_REACHED = 6,     -- 达到每日限制
        SYSTEM_ERROR = 7,            -- 系统错误
        PERMISSION_DENIED = 8        -- 权限不足
    },

    -- 货币来源类型
    SOURCE_TYPE = {
        -- 活动相关
        QUEST = 1,           -- 任务奖励
        ACHIEVEMENT = 2,     -- 成就奖励
        EVENT = 3,           -- 活动奖励
        DAILY_LOGIN = 4,     -- 每日登录
        MAIL = 5,            -- 邮件获取
        
        -- 战斗相关
        MONSTER = 10,        -- 怪物掉落
        BOSS = 11,           -- Boss掉落
        DUNGEON = 12,        -- 副本奖励
        
        -- 经济相关
        SELL_ITEM = 20,      -- 出售物品
        TRADE = 21,          -- 交易获得
        
        -- 充值相关
        RECHARGE = 30,       -- 充值获得
        VIP_REWARD = 31,     -- VIP奖励
        FIRST_RECHARGE = 32, -- 首充奖励
        
        -- 系统相关
        ADMIN = 40,          -- 管理员操作
        COMPENSATION = 41,   -- 补偿
        EXCHANGE = 42,       -- 货币兑换
        SYSTEM = 43,         -- 系统发放
        
        -- 其他
        OTHER = 99           -- 其他来源
    },
    
    -- 货币消费场景
    CONSUME_SCENE = {
        -- 商城相关
        SHOP = 1,            -- 普通商城
        PREMIUM_SHOP = 2,    -- 高级商城
        BLACK_MARKET = 3,    -- 黑市
        
        -- 角色相关
        SKILL_UPGRADE = 10,  -- 技能升级
        LEVEL_UP = 11,       -- 等级提升
        EQUIPMENT = 12,      -- 装备强化/进阶
        
        -- 社交相关
        GIFT = 20,           -- 赠送礼物
        TRADE_TAX = 21,      -- 交易税
        
        -- 玩法相关
        DUNGEON_ENTRY = 30,  -- 副本入场
        REVIVE = 31,         -- 复活
        ENERGY_RESTORE = 32, -- 恢复体力
        GACHA = 33,          -- 抽奖系统
        SKIP_COOLDOWN = 34,  -- 跳过冷却
        
        -- 兑换相关
        EXCHANGE = 40,       -- 货币兑换
        
        -- 其他
        OTHER = 99           -- 其他消费
    },
    
    -- 货币显示格式
    DISPLAY_FORMAT = {
        NORMAL = 1,          -- 普通显示 (例如: 1234)
        THOUSAND = 2,        -- 千分位显示 (例如: 1,234)
        ABBREVIATED = 3,     -- 简写显示 (例如: 1.2K, 1.2M)
        ICON_TEXT = 4        -- 图标+文字显示
    },
    
    -- 货币动画效果类型
    ANIMATION_TYPE = {
        NONE = 0,            -- 无动画
        FADE_IN = 1,         -- 淡入
        COUNT_UP = 2,        -- 数字增长
        BOUNCE = 3,          -- 弹跳效果
        FLASH = 4,           -- 闪烁效果
        FLOAT_UP = 5         -- 向上飘动
    },
    
    -- 货币日志记录级别
    LOG_LEVEL = {
        NONE = 0,            -- 不记录
        ERROR = 1,           -- 仅记录错误
        CRITICAL = 2,        -- 记录关键操作
        ALL = 3              -- 记录所有操作
    },
    
    -- 货币数量显示上限
    MAX_DISPLAY_VALUE = 999999999,
    
    -- 货币兑换最小单位
    MIN_EXCHANGE_UNIT = 1,
    
    -- 货币获取提示持续时间（毫秒）
    GAIN_NOTICE_DURATION = 3000,
    
    -- 货币不足提示持续时间（毫秒）
    INSUFFICIENT_NOTICE_DURATION = 5000,
    
    -- 数据存储相关
    STORAGE = {
        KEY_PREFIX = "player_currency_",     -- 存储键前缀
        DAILY_RESET_TIME = "04:00:00",       -- 每日重置时间（服务器时间）
        WEEKLY_RESET_DAY = 1,                -- 每周重置日（1=周一）
        EXCHANGE_RECORD_EXPIRY = 30,         -- 兑换记录保存天数
        LOG_RETENTION_DAYS = 60              -- 日志保留天数
    },
    
    -- 货币区域显示配置
    REGION_SETTINGS = {
        DECIMAL_SEPARATOR = ".",             -- 小数点符号
        THOUSAND_SEPARATOR = ",",            -- 千位分隔符
        CURRENCY_SYMBOL_POSITION = "prefix", -- 货币符号位置（prefix/suffix）
        ABBREVIATIONS = {                    -- 数值缩写
            [3] = "K",                       -- 千
            [6] = "M",                       -- 百万
            [9] = "B",                       -- 十亿
            [12] = "T"                       -- 万亿
        }
    }
}

return MCurrencyConst