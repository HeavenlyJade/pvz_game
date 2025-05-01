--- V109
--- 货币系统工具类函数

local game = game
local math = math
local string = string
local tonumber = tonumber
local tostring = tostring
local os = os

local MainStorage = game:GetService("MainStorage")
local MCurrencyConfig = require(MainStorage.code.common.MCurrency.MCurrencyConfig) ---@type MCurrencyConfig
local MCurrencyConst = require(MainStorage.code.common.MCurrency.MCurrencyConst) ---@type MCurrencyConst

---@class MCurrencyUtils
local MCurrencyUtils = {}

-- 判断金额是否有效
-- @param amount 金额
-- @return boolean 是否有效
function MCurrencyUtils.isValidAmount(amount)
    -- 检查是否为数字
    if type(amount) ~= "number" then
        return false
    end
    
    -- 检查是否为正数
    if amount < 0 then
        return false
    end
    
    -- 检查是否为整数
    if math.floor(amount) ~= amount then
        return false
    end
    
    return true
end

-- 检查货币数额是否超过上限
-- @param currencyType 货币类型
-- @param currentAmount 当前金额
-- @param addAmount 要增加的金额
-- @return boolean 是否超过上限
function MCurrencyUtils.isExceedsCap(currencyType, currentAmount, addAmount)
    local cap = MCurrencyConfig:getCurrencyCap(currencyType)
    
    -- 如果上限为0，表示无上限
    if cap == 0 then
        return false
    end
    
    -- 检查增加后是否超过上限
    return (currentAmount + addAmount) > cap
end

-- 检查是否达到每日获取上限
-- @param currencyType 货币类型
-- @param dailyGained 今日已获取金额
-- @param addAmount 要增加的金额
-- @return boolean 是否超过每日获取上限
function MCurrencyUtils.isDailyCapReached(currencyType, dailyGained, addAmount)
    local dailyCap = MCurrencyConfig:getDailyAcquisitionCap(currencyType)
    
    -- 如果每日上限为0，表示无限制
    if dailyCap == 0 then
        return false
    end
    
    -- 检查增加后是否超过每日上限
    return (dailyGained + addAmount) > dailyCap
end

-- 检查是否达到每日兑换上限
-- @param fromCurrency 源货币类型
-- @param toCurrency 目标货币类型
-- @param dailyExchanged 今日已兑换金额
-- @param exchangeAmount 要兑换的金额
-- @return boolean 是否超过每日兑换上限
function MCurrencyUtils.isDailyExchangeLimitReached(fromCurrency, toCurrency, dailyExchanged, exchangeAmount)
    local dailyLimit = MCurrencyConfig:getDailyExchangeLimit(fromCurrency, toCurrency)
    
    -- 如果每日限制为0，表示无限制
    if dailyLimit == 0 then
        return false
    end
    
    -- 检查兑换后是否超过每日限制
    return (dailyExchanged + exchangeAmount) > dailyLimit
end

-- 计算实际可获取的货币数量（考虑上限）
-- @param currencyType 货币类型
-- @param currentAmount 当前金额
-- @param addAmount 要增加的金额
-- @return number 实际可获取的金额
function MCurrencyUtils.calculateActualGainAmount(currencyType, currentAmount, addAmount)
    local cap = MCurrencyConfig:getCurrencyCap(currencyType)
    
    -- 如果无上限或不会超过上限，直接返回增加金额
    if cap == 0 or (currentAmount + addAmount) <= cap then
        return addAmount
    end
    
    -- 计算实际可增加的金额
    return cap - currentAmount
end

-- 计算实际可兑换的货币数量（考虑上限和每日限制）
-- @param fromCurrency 源货币类型
-- @param toCurrency 目标货币类型
-- @param currentAmount 当前目标货币金额
-- @param dailyExchanged 今日已兑换目标货币金额
-- @param exchangeAmount 要兑换的源货币金额
-- @return number 实际可兑换的目标货币金额
function MCurrencyUtils.calculateActualExchangeAmount(fromCurrency, toCurrency, currentAmount, dailyExchanged, exchangeAmount)
    -- 计算兑换比率
    local rate = MCurrencyConfig:getExchangeRate(fromCurrency, toCurrency)
    if rate == 0 then
        return 0 -- 不支持的兑换
    end
    
    -- 计算兑换后的目标货币金额
    local resultAmount = exchangeAmount * rate
    
    -- 检查是否超过每日兑换上限
    local dailyLimit = MCurrencyConfig:getDailyExchangeLimit(fromCurrency, toCurrency)
    if dailyLimit > 0 then
        local remainingDaily = dailyLimit - dailyExchanged
        if remainingDaily <= 0 then
            return 0 -- 已达到每日上限
        end
        
        if resultAmount > remainingDaily then
            resultAmount = remainingDaily
        end
    end
    
    -- 检查是否超过目标货币上限
    local cap = MCurrencyConfig:getCurrencyCap(toCurrency)
    if cap > 0 then
        local remainingCap = cap - currentAmount
        if remainingCap <= 0 then
            return 0 -- 已达到上限
        end
        
        if resultAmount > remainingCap then
            resultAmount = remainingCap
        end
    end
    
    return resultAmount
end

-- 计算兑换所需的源货币数量
-- @param fromCurrency 源货币类型
-- @param toCurrency 目标货币类型
-- @param targetAmount 目标货币金额
-- @return number 所需的源货币金额
function MCurrencyUtils.calculateRequiredSourceAmount(fromCurrency, toCurrency, targetAmount)
    local rate = MCurrencyConfig:getExchangeRate(fromCurrency, toCurrency)
    if rate == 0 then
        return 0 -- 不支持的兑换
    end
    
    -- 计算所需的源货币金额（向上取整，确保兑换后不少于目标金额）
    return math.ceil(targetAmount / rate)
end

-- 应用VIP加成到获取的货币金额
-- @param currencyType 货币类型
-- @param baseAmount 基础金额
-- @param vipLevel VIP等级
-- @return number 加成后的金额
function MCurrencyUtils.applyVipBonus(currencyType, baseAmount, vipLevel)
    if vipLevel <= 0 then
        return baseAmount
    end
    
    local bonusPercent = MCurrencyConfig:getVipAcquisitionBonus(vipLevel, currencyType)
    if bonusPercent <= 0 then
        return baseAmount
    end
    
    -- 计算加成后的金额（向下取整）
    return math.floor(baseAmount * (1 + bonusPercent / 100))
end

-- 应用节日活动加成到获取的货币金额
-- @param currencyType 货币类型
-- @param baseAmount 基础金额
-- @param festivalId 节日活动ID
-- @return number 加成后的金额
function MCurrencyUtils.applyFestivalBonus(currencyType, baseAmount, festivalId)
    if not festivalId or festivalId == "" then
        return baseAmount
    end
    
    local bonusPercent = MCurrencyConfig:getFestivalAcquisitionBonus(festivalId, currencyType)
    if bonusPercent <= 0 then
        return baseAmount
    end
    
    -- 计算加成后的金额（向下取整）
    return math.floor(baseAmount * (1 + bonusPercent / 100))
end

-- 格式化货币数量显示
-- @param amount 货币金额
-- @param format 显示格式
-- @return string 格式化后的字符串
function MCurrencyUtils.formatCurrencyAmount(amount, format)
    -- 处理超过显示上限的情况
    if amount > MCurrencyConst.MAX_DISPLAY_VALUE then
        amount = MCurrencyConst.MAX_DISPLAY_VALUE
    end
    
    -- 根据不同格式进行处理
    if format == MCurrencyConst.DISPLAY_FORMAT.NORMAL then
        -- 普通显示
        return tostring(amount)
        
    elseif format == MCurrencyConst.DISPLAY_FORMAT.THOUSAND then
        -- 千分位显示
        local formatted = tostring(amount)
        local k = #formatted % 3
        if k == 0 then k = 3 end
        local result = string.sub(formatted, 1, k)
        for i = k + 1, #formatted, 3 do
            result = result .. MCurrencyConst.REGION_SETTINGS.THOUSAND_SEPARATOR .. string.sub(formatted, i, i + 2)
        end
        return result
        
    elseif format == MCurrencyConst.DISPLAY_FORMAT.ABBREVIATED then
        -- 简写显示
        local abbr = ""
        local value = amount
        
        if amount >= 1000000000000 then
            value = amount / 1000000000000
            abbr = MCurrencyConst.REGION_SETTINGS.ABBREVIATIONS[12]
        elseif amount >= 1000000000 then
            value = amount / 1000000000
            abbr = MCurrencyConst.REGION_SETTINGS.ABBREVIATIONS[9]
        elseif amount >= 1000000 then
            value = amount / 1000000
            abbr = MCurrencyConst.REGION_SETTINGS.ABBREVIATIONS[6]
        elseif amount >= 1000 then
            value = amount / 1000
            abbr = MCurrencyConst.REGION_SETTINGS.ABBREVIATIONS[3]
        end
        
        -- 保留一位小数
        if value ~= amount then
            return string.format("%.1f%s", value, abbr)
        else
            return tostring(amount)
        end
    end
    
    -- 默认返回普通格式
    return tostring(amount)
end

-- 生成唯一的交易ID
-- @return string 交易ID
function MCurrencyUtils.generateTransactionId()
    local time = os.time()
    local random = math.random(10000, 99999)
    return string.format("TX_%d_%d", time, random)
end

-- 获取当前日期（用于日期重置）
-- @return string YYYY-MM-DD格式的日期
function MCurrencyUtils.getCurrentDate()
    local time = os.date("*t")
    return string.format("%04d-%02d-%02d", time.year, time.month, time.day)
end

-- 检查是否需要每日重置
-- @param lastResetDate 上次重置日期
-- @return boolean 是否需要重置
function MCurrencyUtils.shouldResetDaily(lastResetDate)
    -- 获取当前日期
    local currentDate = MCurrencyUtils.getCurrentDate()
    
    -- 如果上次重置日期为空或与当前日期不同，则需要重置
    return lastResetDate == nil or lastResetDate ~= currentDate
end

-- 安全地增加货币数量（考虑上限）
-- @param currentValue 当前值
-- @param addValue 要增加的值
-- @param maxValue 最大值（0表示无上限）
-- @return number 增加后的值
function MCurrencyUtils.safeAdd(currentValue, addValue, maxValue)
    local result = currentValue + addValue
    
    -- 如果有上限且结果超过上限，则返回上限值
    if maxValue > 0 and result > maxValue then
        return maxValue
    end
    
    return result
end

-- 安全地减少货币数量（不会小于0）
-- @param currentValue 当前值
-- @param subValue 要减少的值
-- @return number 减少后的值
function MCurrencyUtils.safeSub(currentValue, subValue)
    local result = currentValue - subValue
    
    -- 结果不能小于0
    if result < 0 then
        return 0
    end
    
    return result
end

-- 检查兑换是否合法
-- @param fromCurrency 源货币类型
-- @param toCurrency 目标货币类型
-- @return boolean 是否合法
function MCurrencyUtils.isExchangeValid(fromCurrency, toCurrency)
    -- 检查货币类型是否有效
    if not MCurrencyConfig:isValidCurrencyType(fromCurrency) or 
       not MCurrencyConfig:isValidCurrencyType(toCurrency) then
        return false
    end
    
    -- 检查是否支持兑换
    local rate = MCurrencyConfig:getExchangeRate(fromCurrency, toCurrency)
    if rate <= 0 then
        return false
    end
    
    -- 检查目标货币是否可以被兑换获得
    if not MCurrencyConfig:isExchangeableFrom(toCurrency) then
        return false
    end
    
    return true
end

-- 创建货币操作结果
-- @param success 是否成功
-- @param code 结果状态码
-- @param actualAmount 实际操作的金额
-- @param message 附加消息
-- @return table 结果表
function MCurrencyUtils.createOperationResult(success, code, actualAmount, message)
    return {
        success = success,
        code = code,
        actualAmount = actualAmount or 0,
        message = message or ""
    }
end

-- 获取货币操作结果的错误消息
-- @param resultCode 结果状态码
-- @param currencyType 货币类型
-- @return string 错误消息
function MCurrencyUtils.getErrorMessage(resultCode, currencyType)
    local currencyName = MCurrencyConfig:getCurrencyName(currencyType)
    
    if resultCode == MCurrencyConst.RESULT_CODE.INVALID_CURRENCY then
        return "无效的货币类型"
    elseif resultCode == MCurrencyConst.RESULT_CODE.INSUFFICIENT_AMOUNT then
        return currencyName .. "不足"
    elseif resultCode == MCurrencyConst.RESULT_CODE.EXCEEDS_CAP then
        return currencyName .. "已达到上限"
    elseif resultCode == MCurrencyConst.RESULT_CODE.INVALID_AMOUNT then
        return "无效的"..currencyName.."数量"
    elseif resultCode == MCurrencyConst.RESULT_CODE.EXCHANGE_NOT_SUPPORTED then
        return "不支持的货币兑换"
    elseif resultCode == MCurrencyConst.RESULT_CODE.DAILY_LIMIT_REACHED then
        return currencyName .. "已达到每日获取上限"
    elseif resultCode == MCurrencyConst.RESULT_CODE.SYSTEM_ERROR then
        return "系统错误"
    elseif resultCode == MCurrencyConst.RESULT_CODE.PERMISSION_DENIED then
        return "权限不足"
    end
    
    return "未知错误"
end

return MCurrencyUtils