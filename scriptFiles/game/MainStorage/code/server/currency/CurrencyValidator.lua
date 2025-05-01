--- V109 miniw-haima
--- 货币验证器，负责验证货币操作的合法性

local game = game
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local type = type
local math = math

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MCurrencyConfig = require(MainStorage.code.common.MCurrency.MCurrencyConfig)   ---@type MCurrencyConfig
local MCurrencyConst = require(MainStorage.code.common.MCurrency.MCurrencyConst)   ---@type MCurrencyConst
local MCurrencyUtils = require(MainStorage.code.common.MCurrency.MCurrencyUtils)   ---@type MCurrencyUtils

---@class CurrencyValidator
local CurrencyValidator = {
    -- 安全限制配置
    SECURITY_LIMITS = {
        -- 单次交易最大金额
        MAX_TRANSACTION_AMOUNT = 1000000,
        
        -- 短时间内最大交易次数
        MAX_TRANSACTIONS_PER_MINUTE = 60,
        
        -- 短时间内最大金额变动
        MAX_AMOUNT_CHANGE_PER_MINUTE = 5000000,
        
        -- 异常次数阈值
        ANOMALY_THRESHOLD = 5
    },
    
    -- 操作统计
    operationStats = {},
    
    -- 异常记录
    anomalyRecords = {},
    
    -- 最后清理统计的时间
    lastStatsCleanupTime = 0,
    
    -- 统计清理间隔（秒）
    STATS_CLEANUP_INTERVAL = 300
}

--- 初始化验证器
function CurrencyValidator:Init()
    -- 设置定时清理统计数据
    self:SetupStatsCleaner()
    
    gg.log("货币验证器初始化完成")
    return self
end

--- 设置定时清理统计数据
function CurrencyValidator:SetupStatsCleaner()
    local function cleanStats()
        local now = os.time()
        
        -- 如果距离上次清理已经过了指定间隔
        if now - self.lastStatsCleanupTime >= self.STATS_CLEANUP_INTERVAL then
            -- 清理过期统计
            for uin, stats in pairs(self.operationStats) do
                local newStats = {}
                
                -- 只保留最近5分钟的记录
                for time, stat in pairs(stats) do
                    if now - time < 300 then
                        newStats[time] = stat
                    end
                end
                
                if next(newStats) then
                    self.operationStats[uin] = newStats
                else
                    self.operationStats[uin] = nil
                end
            end
            
            self.lastStatsCleanupTime = now
            gg.log("已清理货币操作统计数据")
        end
        
        -- 每分钟检查一次
        wait(60)
        cleanStats()
    end
    
    coroutine.wrap(cleanStats)()
end

--- 验证货币操作
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param operationType number 操作类型
---@param amount number 金额
---@param source number 来源/场景
---@param currentBalance number 当前余额
---@return boolean 是否有效
---@return number 结果代码
---@return string 错误信息
function CurrencyValidator:ValidateOperation(uin, currencyType, operationType, amount, source, currentBalance)
    -- 验证货币类型
    if not self:ValidateCurrencyType(currencyType) then
        return false, MCurrencyConst.RESULT_CODE.INVALID_CURRENCY, "无效的货币类型"
    end
    
    -- 验证金额
    if not self:ValidateAmount(amount) then
        return false, MCurrencyConst.RESULT_CODE.INVALID_AMOUNT, "无效的金额"
    end
    
    -- 验证操作类型
    if not self:ValidateOperationType(operationType) then
        return false, MCurrencyConst.RESULT_CODE.SYSTEM_ERROR, "无效的操作类型"
    end
    
    -- 特殊验证：消费时检查余额
    if operationType == MCurrencyConst.OPERATION_TYPE.CONSUME and currentBalance < amount then
        return false, MCurrencyConst.RESULT_CODE.INSUFFICIENT_AMOUNT, "货币不足"
    end
    
    -- 安全验证
    local safetyCheck, safetyCode, safetyMessage = self:PerformSafetyCheck(uin, currencyType, operationType, amount, source)
    if not safetyCheck then
        return false, safetyCode, safetyMessage
    end
    
    -- 记录操作统计
    self:RecordOperationStat(uin, currencyType, operationType, amount)
    
    -- 通过所有验证
    return true, MCurrencyConst.RESULT_CODE.SUCCESS, ""
end

--- 验证货币类型
---@param currencyType string 货币类型
---@return boolean 是否有效
function CurrencyValidator:ValidateCurrencyType(currencyType)
    return MCurrencyConfig:isValidCurrencyType(currencyType)
end

--- 验证金额
---@param amount number 金额
---@return boolean 是否有效
function CurrencyValidator:ValidateAmount(amount)
    -- 检查类型
    if type(amount) ~= "number" then
        return false
    end
    
    -- 检查是否为非负数
    if amount < 0 then
        return false
    end
    
    -- 检查是否为整数
    if math.floor(amount) ~= amount then
        return false
    end
    
    -- 检查是否超过单次交易限额
    if amount > self.SECURITY_LIMITS.MAX_TRANSACTION_AMOUNT then
        return false
    end
    
    return true
end

--- 验证操作类型
---@param operationType number 操作类型
---@return boolean 是否有效
function CurrencyValidator:ValidateOperationType(operationType)
    local validTypes = {
        [MCurrencyConst.OPERATION_TYPE.GAIN] = true,
        [MCurrencyConst.OPERATION_TYPE.CONSUME] = true,
        [MCurrencyConst.OPERATION_TYPE.EXCHANGE] = true,
        [MCurrencyConst.OPERATION_TYPE.SYSTEM_ADJUST] = true,
        [MCurrencyConst.OPERATION_TYPE.RESET] = true,
        [MCurrencyConst.OPERATION_TYPE.REFUND] = true
    }
    
    return validTypes[operationType] or false
end

--- 验证来源/场景
---@param sourceType number 来源/场景ID
---@param operationType number 操作类型
---@return boolean 是否有效
function CurrencyValidator:ValidateSourceType(sourceType, operationType)
    -- 根据操作类型验证来源/场景
    if operationType == MCurrencyConst.OPERATION_TYPE.GAIN then
        -- 验证收入来源
        local validSources = {
            [MCurrencyConst.SOURCE_TYPE.QUEST] = true,
            [MCurrencyConst.SOURCE_TYPE.ACHIEVEMENT] = true,
            [MCurrencyConst.SOURCE_TYPE.EVENT] = true,
            [MCurrencyConst.SOURCE_TYPE.DAILY_LOGIN] = true,
            [MCurrencyConst.SOURCE_TYPE.MAIL] = true,
            [MCurrencyConst.SOURCE_TYPE.MONSTER] = true,
            [MCurrencyConst.SOURCE_TYPE.BOSS] = true,
            [MCurrencyConst.SOURCE_TYPE.DUNGEON] = true,
            [MCurrencyConst.SOURCE_TYPE.SELL_ITEM] = true,
            [MCurrencyConst.SOURCE_TYPE.TRADE] = true,
            [MCurrencyConst.SOURCE_TYPE.RECHARGE] = true,
            [MCurrencyConst.SOURCE_TYPE.VIP_REWARD] = true,
            [MCurrencyConst.SOURCE_TYPE.FIRST_RECHARGE] = true,
            [MCurrencyConst.SOURCE_TYPE.ADMIN] = true,
            [MCurrencyConst.SOURCE_TYPE.COMPENSATION] = true,
            [MCurrencyConst.SOURCE_TYPE.EXCHANGE] = true,
            [MCurrencyConst.SOURCE_TYPE.SYSTEM] = true,
            [MCurrencyConst.SOURCE_TYPE.OTHER] = true
        }
        
        return validSources[sourceType] or false
    elseif operationType == MCurrencyConst.OPERATION_TYPE.CONSUME then
        -- 验证消费场景
        local validScenes = {
            [MCurrencyConst.CONSUME_SCENE.SHOP] = true,
            [MCurrencyConst.CONSUME_SCENE.PREMIUM_SHOP] = true,
            [MCurrencyConst.CONSUME_SCENE.BLACK_MARKET] = true,
            [MCurrencyConst.CONSUME_SCENE.SKILL_UPGRADE] = true,
            [MCurrencyConst.CONSUME_SCENE.LEVEL_UP] = true,
            [MCurrencyConst.CONSUME_SCENE.EQUIPMENT] = true,
            [MCurrencyConst.CONSUME_SCENE.GIFT] = true,
            [MCurrencyConst.CONSUME_SCENE.TRADE_TAX] = true,
            [MCurrencyConst.CONSUME_SCENE.DUNGEON_ENTRY] = true,
            [MCurrencyConst.CONSUME_SCENE.REVIVE] = true,
            [MCurrencyConst.CONSUME_SCENE.ENERGY_RESTORE] = true,
            [MCurrencyConst.CONSUME_SCENE.GACHA] = true,
            [MCurrencyConst.CONSUME_SCENE.SKIP_COOLDOWN] = true,
            [MCurrencyConst.CONSUME_SCENE.EXCHANGE] = true,
            [MCurrencyConst.CONSUME_SCENE.OTHER] = true
        }
        
        return validScenes[sourceType] or false
    end
    
    -- 其他操作类型默认通过
    return true
end

--- 执行安全检查
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param operationType number 操作类型
---@param amount number 金额
---@param source number 来源/场景
---@return boolean 是否通过
---@return number 结果代码
---@return string 消息
function CurrencyValidator:PerformSafetyCheck(uin, currencyType, operationType, amount, source)
    -- 检查操作频率
    local frequencyCheck = self:CheckOperationFrequency(uin)
    if not frequencyCheck then
        -- 记录异常
        self:RecordAnomaly(uin, "操作频率过高", {
            currencyType = currencyType,
            operationType = operationType,
            amount = amount,
            source = source
        })
        
        return false, MCurrencyConst.RESULT_CODE.SYSTEM_ERROR, "操作频率过高，请稍后再试"
    end
    
    -- 检查金额变动
    local amountCheck = self:CheckAmountChange(uin, amount)
    if not amountCheck then
        -- 记录异常
        self:RecordAnomaly(uin, "短时间内金额变动过大", {
            currencyType = currencyType,
            operationType = operationType,
            amount = amount,
            source = source
        })
        
        return false, MCurrencyConst.RESULT_CODE.SYSTEM_ERROR, "操作金额异常，请稍后再试"
    end
    
    -- 检查来源/场景有效性
    if not self:ValidateSourceType(source, operationType) then
        -- 记录异常
        self:RecordAnomaly(uin, "无效的来源/场景", {
            currencyType = currencyType,
            operationType = operationType,
            amount = amount,
            source = source
        })
        
        return false, MCurrencyConst.RESULT_CODE.SYSTEM_ERROR, "操作来源异常"
    end
    
    -- 检查异常次数
    if self:GetAnomalyCount(uin) >= self.SECURITY_LIMITS.ANOMALY_THRESHOLD then
        -- 触发安全策略
        self:TriggerSecurityPolicy(uin)
        
        return false, MCurrencyConst.RESULT_CODE.PERMISSION_DENIED, "检测到异常操作，账号已被临时限制"
    end
    
    return true, MCurrencyConst.RESULT_CODE.SUCCESS, ""
end

--- 检查操作频率
---@param uin number 玩家ID
---@return boolean 是否通过
function CurrencyValidator:CheckOperationFrequency(uin)
    local now = os.time()
    local count = 0
    
    -- 获取玩家统计数据
    local stats = self.operationStats[uin]
    if not stats then
        return true
    end
    
    -- 统计最近一分钟的操作次数
    for time, stat in pairs(stats) do
        if now - time <= 60 then
            count = count + 1
        end
    end
    
    -- 检查是否超过限制
    return count < self.SECURITY_LIMITS.MAX_TRANSACTIONS_PER_MINUTE
end

--- 检查金额变动
---@param uin number 玩家ID
---@param amount number 当前操作金额
---@return boolean 是否通过
function CurrencyValidator:CheckAmountChange(uin, amount)
    local now = os.time()
    local totalAmount = amount
    
    -- 获取玩家统计数据
    local stats = self.operationStats[uin]
    if not stats then
        return true
    end
    
    -- 统计最近一分钟的金额变动
    for time, stat in pairs(stats) do
        if now - time <= 60 then
            totalAmount = totalAmount + stat.amount
        end
    end
    
    -- 检查是否超过限制
    return totalAmount < self.SECURITY_LIMITS.MAX_AMOUNT_CHANGE_PER_MINUTE
end

--- 记录操作统计
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param operationType number 操作类型
---@param amount number 金额
function CurrencyValidator:RecordOperationStat(uin, currencyType, operationType, amount)
    -- 初始化玩家统计数据
    if not self.operationStats[uin] then
        self.operationStats[uin] = {}
    end
    
    -- 记录当前操作
    local now = os.time()
    self.operationStats[uin][now] = {
        currencyType = currencyType,
        operationType = operationType,
        amount = amount,
        time = now
    }
end

--- 记录异常
---@param uin number 玩家ID
---@param reason string 异常原因
---@param data table 相关数据
function CurrencyValidator:RecordAnomaly(uin, reason, data)
    -- 初始化玩家异常记录
    if not self.anomalyRecords[uin] then
        self.anomalyRecords[uin] = {}
    end
    
    -- 记录异常
    table.insert(self.anomalyRecords[uin], {
        time = os.time(),
        reason = reason,
        data = data
    })
    
    -- 限制异常记录数量
    if #self.anomalyRecords[uin] > 100 then
        table.remove(self.anomalyRecords[uin], 1)
    end
    
    -- 记录日志
    gg.log("货币操作异常", uin, reason, data)
end

--- 获取玩家异常次数
---@param uin number 玩家ID
---@return number 异常次数
function CurrencyValidator:GetAnomalyCount(uin)
    local records = self.anomalyRecords[uin]
    if not records then
        return 0
    end
    
    local now = os.time()
    local count = 0
    
    -- 统计最近一小时的异常次数
    for _, record in ipairs(records) do
        if now - record.time <= 3600 then
            count = count + 1
        end
    end
    
    return count
end

--- 触发安全策略
---@param uin number 玩家ID
function CurrencyValidator:TriggerSecurityPolicy(uin)
    -- 记录严重异常
    gg.log("触发货币安全策略", uin, self.anomalyRecords[uin])
    
    -- 这里可以添加安全策略，如：
    -- 1. 临时禁止货币操作
    -- 2. 发送警报给管理员
    -- 3. 要求玩家进行验证
    -- 4. 自动回滚可疑交易
    
    -- 禁止货币操作示例：
    -- local player = gg.getPlayerByUin(uin)
    -- if player then
    --     player:SetAttribute("currency_restricted", true)
    --     player:SetAttribute("currency_restriction_end", os.time() + 3600) -- 1小时后解除
    -- end
    
    -- 通知客户端
    gg.network_channel:fireClient(uin, {
        cmd = "cmd_currency_security",
        message = "检测到异常操作，部分功能已被临时限制，请联系客服"
    })
end

--- 检查玩家是否被限制货币操作
---@param uin number 玩家ID
---@return boolean 是否被限制
function CurrencyValidator:IsPlayerRestricted(uin)
    local player = gg.getPlayerByUin(uin)
    if not player then
        return false
    end
    
    local restricted = player:GetAttribute("currency_restricted")
    if not restricted then
        return false
    end
    
    -- 检查限制是否已过期
    local restrictionEnd = player:GetAttribute("currency_restriction_end") or 0
    if os.time() > restrictionEnd then
        -- 解除限制
        player:SetAttribute("currency_restricted", nil)
        player:SetAttribute("currency_restriction_end", nil)
        return false
    end
    
    return true
end

--- 手动解除玩家限制
---@param uin number 玩家ID
function CurrencyValidator:RemovePlayerRestriction(uin)
    local player = gg.getPlayerByUin(uin)
    if not player then
        return
    end
    
    player:SetAttribute("currency_restricted", nil)
    player:SetAttribute("currency_restriction_end", nil)
    
    gg.log("手动解除玩家货币操作限制", uin)
    
    -- 通知客户端
    gg.network_channel:fireClient(uin, {
        cmd = "cmd_currency_security",
        message = "您的账号已解除限制，现在可以正常使用所有功能"
    })
end

--- 验证兑换操作
---@param uin number 玩家ID
---@param fromCurrency string 源货币类型
---@param toCurrency string 目标货币类型
---@param amount number 源货币金额
---@param dailyExchanged number 今日已兑换金额
---@return boolean 是否有效
---@return number 结果代码
---@return string 错误信息
function CurrencyValidator:ValidateExchange(uin, fromCurrency, toCurrency, amount, dailyExchanged)
    -- 检查兑换是否支持
    if not MCurrencyUtils.isExchangeValid(fromCurrency, toCurrency) then
        return false, MCurrencyConst.RESULT_CODE.EXCHANGE_NOT_SUPPORTED, "不支持的货币兑换"
    end
    
    -- 验证货币类型
    if not self:ValidateCurrencyType(fromCurrency) or not self:ValidateCurrencyType(toCurrency) then
        return false, MCurrencyConst.RESULT_CODE.INVALID_CURRENCY, "无效的货币类型"
    end
    
    -- 验证金额
    if not self:ValidateAmount(amount) then
        return false, MCurrencyConst.RESULT_CODE.INVALID_AMOUNT, "无效的金额"
    end
    
    -- 检查是否达到每日兑换上限
    local exchangeRate = MCurrencyConfig:getExchangeRate(fromCurrency, toCurrency)
    local resultAmount = amount * exchangeRate
    
    local dailyLimit = MCurrencyConfig:getDailyExchangeLimit(fromCurrency, toCurrency)
    if dailyLimit > 0 and dailyExchanged + resultAmount > dailyLimit then
        return false, MCurrencyConst.RESULT_CODE.DAILY_LIMIT_REACHED, "已达到每日兑换上限"
    end
    
    -- 执行安全检查
    local safetyCheck, safetyCode, safetyMessage = self:PerformSafetyCheck(
        uin, 
        fromCurrency, 
        MCurrencyConst.OPERATION_TYPE.EXCHANGE, 
        amount, 
        MCurrencyConst.CONSUME_SCENE.EXCHANGE
    )
    
    if not safetyCheck then
        return false, safetyCode, safetyMessage
    end
    
    -- 记录操作统计
    self:RecordOperationStat(
        uin, 
        fromCurrency, 
        MCurrencyConst.OPERATION_TYPE.EXCHANGE, 
        amount
    )
    
    return true, MCurrencyConst.RESULT_CODE.SUCCESS, ""
end

--- 获取玩家异常记录
---@param uin number 玩家ID
---@param count number 记录数量
---@return table 异常记录
function CurrencyValidator:GetPlayerAnomalies(uin, count)
    local records = self.anomalyRecords[uin]
    if not records then
        return {}
    end
    
    local result = {}
    local limit = count or 10
    
    -- 获取最近的异常记录
    for i = #records, math.max(1, #records - limit + 1), -1 do
        table.insert(result, records[i])
    end
    
    return result
end

return CurrencyValidator:Init()