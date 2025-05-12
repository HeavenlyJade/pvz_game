print("Hello world!")--- V109
--- 游戏货币系统配置文件

---@class MCurrencyConfig
local MCurrencyConfig = {
    -- 货币类型定义
    CURRENCY_TYPES = {
        DIAMOND = "diamond",      -- 钻石（充值货币）
        ENERGY_BEAN = "energy_bean", -- 能量豆（游戏法定货币）
        SUNSHINE = "sunshine",    -- 阳光（资源货币）
        GOLD_COIN = "gold_coin"   -- 金币（基础经济货币）
    },

    -- 货币图标资源
    CURRENCY_ICONS = {
        diamond = "RainbowId&filetype=5://257359971842330624",      -- 钻石图标
        energy_bean = "RainbowId&filetype=5://257359999172415488",  -- 能量豆图标
        sunshine = "RainbowId&filetype=5://257359922353737728",     -- 阳光图标
        gold_coin = "RainbowId&filetype=5://257360030067658752"     -- 金币图标
    },

    -- 货币显示名称
    CURRENCY_NAMES = {
        diamond = "钻石",
        energy_bean = "能量豆",
        sunshine = "阳光",
        gold_coin = "金币"
    },

    -- 初始货币数量（新玩家）
    INITIAL_CURRENCY = {
        diamond = 0,         -- 充值货币，初始为0
        energy_bean = 0,  -- 法定货币，给予一定初始数量
        sunshine = 0,      -- 资源货币，给予少量初始值
        gold_coin = 0      -- 基础货币，给予较多初始值
    },

    -- 货币上限设置（0表示无上限）
    CURRENCY_CAPS = {
        diamond = 9999999999,          -- 钻石无上限
        energy_bean = 9999999999, -- 能量豆上限
        sunshine = 9999999999,     -- 阳光上限
        gold_coin = 9999999999   -- 金币上限
    },

    -- 获取途径配置
    ACQUISITION_METHODS = {
        diamond = {
            {source = "recharge", desc = "充值获得"},
            {source = "vip_daily", desc = "VIP每日奖励"},
            {source = "achievement", desc = "特殊成就奖励"},
            {source = "event", desc = "限时活动奖励"}
        },
        energy_bean = {
            {source = "quest", desc = "任务奖励"},
            {source = "monster", desc = "怪物掉落"},
            {source = "achievement", desc = "成就系统"},
            {source = "daily", desc = "每日活动"},
            {source = "exchange", desc = "钻石兑换"}
        },
        sunshine = {
            {source = "login", desc = "每日登录"},
            {source = "harvest", desc = "资源收集"},
            {source = "time_reward", desc = "在线奖励"},
            {source = "exchange", desc = "钻石兑换"}
        },
        gold_coin = {
            {source = "monster", desc = "怪物掉落"},
            {source = "sell", desc = "出售物品"},
            {source = "quest", desc = "基础任务"},
            {source = "exchange", desc = "钻石兑换"}
        }
    },

    -- 货币兑换比率配置 (钻石兑换其他货币)
    EXCHANGE_RATES = {
        -- 钻石兑换其他货币的比率
        diamond_to_energy_bean = 100,  -- 1钻石 = 100能量豆
        diamond_to_sunshine = 50,      -- 1钻石 = 50阳光
        diamond_to_gold_coin = 500     -- 1钻石 = 500金币
    },

    -- 兑换限制配置
    EXCHANGE_LIMITS = {
        -- 每日兑换上限 (0表示无限制)
        daily_diamond_to_energy_bean = 5000,  -- 每日最多用钻石兑换5000能量豆
        daily_diamond_to_sunshine = 2000,     -- 每日最多用钻石兑换2000阳光
        daily_diamond_to_gold_coin = 20000    -- 每日最多用钻石兑换20000金币
    },

    -- 每日获取上限配置 (0表示无限制)
    DAILY_ACQUISITION_CAPS = {
        diamond = 0,         -- 钻石无每日获取上限
        energy_bean = 0,     -- 能量豆无每日获取上限
        sunshine = 2000,     -- 阳光每日获取上限2000
        gold_coin = 0        -- 金币无每日获取上限
    },

    -- 货币获取加成系统配置
    ACQUISITION_BONUS = {
        -- VIP等级对应的货币获取加成百分比
        vip = {
            -- [VIP等级] = {货币类型 = 加成百分比}
            [1] = {energy_bean = 5, sunshine = 10, gold_coin = 10},
            [2] = {energy_bean = 10, sunshine = 15, gold_coin = 15},
            [3] = {energy_bean = 15, sunshine = 20, gold_coin = 20},
            [4] = {energy_bean = 20, sunshine = 25, gold_coin = 25},
            [5] = {energy_bean = 25, sunshine = 30, gold_coin = 30}
        },
        
        -- 节日活动加成百分比
        festival = {
            -- 活动ID对应的加成
            ["spring_festival"] = {energy_bean = 50, sunshine = 100, gold_coin = 100},
            ["anniversary"] = {energy_bean = 100, sunshine = 50, gold_coin = 200}
        }
    },

    -- 货币消耗场景配置
    CONSUMPTION_SCENES = {
        diamond = {
            {scene = "shop_premium", desc = "高级商城"},
            {scene = "gacha", desc = "抽奖系统"},
            {scene = "vip", desc = "VIP特权"},
            {scene = "exchange", desc = "兑换其他货币"}
        },
        energy_bean = {
            {scene = "skill_upgrade", desc = "技能升级"},
            {scene = "equipment", desc = "特殊装备"},
            {scene = "task_unlock", desc = "高级任务解锁"}
        },
        sunshine = {
            {scene = "character_growth", desc = "角色培养"},
            {scene = "plant", desc = "种植系统"},
            {scene = "energy_recovery", desc = "能量恢复"}
        },
        gold_coin = {
            {scene = "basic_equipment", desc = "基础装备"},
            {scene = "consumable", desc = "消耗品购买"},
            {scene = "trade_tax", desc = "交易税"}
        }
    },

    -- 充值档位配置（以人民币为例）
    RECHARGE_TIERS = {
        {id = "recharge_6", price = 6, diamonds = 60, first_bonus = 60},
        {id = "recharge_30", price = 30, diamonds = 300, first_bonus = 300},
        {id = "recharge_98", price = 98, diamonds = 980, first_bonus = 980},
        {id = "recharge_198", price = 198, diamonds = 1980, first_bonus = 1980},
        {id = "recharge_328", price = 328, diamonds = 3280, first_bonus = 3280},
        {id = "recharge_648", price = 648, diamonds = 6480, first_bonus = 6480}
    }
}

-- 创建货币类型与索引的映射关系
MCurrencyConfig.CURRENCY_TYPE_TO_INDEX = {}
local types = MCurrencyConfig.CURRENCY_TYPES
for name, value in pairs(types) do
    MCurrencyConfig.CURRENCY_TYPE_TO_INDEX[value] = name
end

-- 返回是否为有效的货币类型
function MCurrencyConfig:isValidCurrencyType(currencyType)
    return self.CURRENCY_TYPE_TO_INDEX[currencyType] ~= nil
end

-- 获取货币名称
function MCurrencyConfig:getCurrencyName(currencyType)
    return self.CURRENCY_NAMES[currencyType] or "未知货币"
end

-- 获取货币图标
function MCurrencyConfig:getCurrencyIcon(currencyType)
    return self.CURRENCY_ICONS[currencyType] or ""
end

-- 获取货币上限
function MCurrencyConfig:getCurrencyCap(currencyType)
    return self.CURRENCY_CAPS[currencyType] or 0
end

-- 获取货币兑换比率
function MCurrencyConfig:getExchangeRate(fromCurrency, toCurrency)
    if fromCurrency == self.CURRENCY_TYPES.DIAMOND then
        if toCurrency == self.CURRENCY_TYPES.ENERGY_BEAN then
            return self.EXCHANGE_RATES.diamond_to_energy_bean
        elseif toCurrency == self.CURRENCY_TYPES.SUNSHINE then
            return self.EXCHANGE_RATES.diamond_to_sunshine
        elseif toCurrency == self.CURRENCY_TYPES.GOLD_COIN then
            return self.EXCHANGE_RATES.diamond_to_gold_coin
        end
    end
    return 0 -- 不支持的兑换
end

-- 获取每日兑换上限
function MCurrencyConfig:getDailyExchangeLimit(fromCurrency, toCurrency)
    if fromCurrency == self.CURRENCY_TYPES.DIAMOND then
        if toCurrency == self.CURRENCY_TYPES.ENERGY_BEAN then
            return self.EXCHANGE_LIMITS.daily_diamond_to_energy_bean
        elseif toCurrency == self.CURRENCY_TYPES.SUNSHINE then
            return self.EXCHANGE_LIMITS.daily_diamond_to_sunshine
        elseif toCurrency == self.CURRENCY_TYPES.GOLD_COIN then
            return self.EXCHANGE_LIMITS.daily_diamond_to_gold_coin
        end
    end
    return 0 -- 不支持的兑换或无限制
end

-- 获取每日获取上限
function MCurrencyConfig:getDailyAcquisitionCap(currencyType)
    return self.DAILY_ACQUISITION_CAPS[currencyType] or 0
end

-- 获取VIP等级对应的货币获取加成
function MCurrencyConfig:getVipAcquisitionBonus(vipLevel, currencyType)
    if self.ACQUISITION_BONUS.vip[vipLevel] then
        return self.ACQUISITION_BONUS.vip[vipLevel][currencyType] or 0
    end
    return 0
end

return MCurrencyConfig