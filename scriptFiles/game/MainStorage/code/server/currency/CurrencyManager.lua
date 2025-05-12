--- V109 miniw-haima
--- 货币管理器，负责处理玩家货币系统

local game = game
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local math = math
local table = table

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MCurrencyConfig = require(MainStorage.code.common.MCurrency.MCurrencyConfig)   ---@type MCurrencyConfig
local MCurrencyConst = require(MainStorage.code.common.MCurrency.MCurrencyConst)   ---@type MCurrencyConst
local MCurrencyUtils = require(MainStorage.code.common.MCurrency.MCurrencyUtils)   ---@type MCurrencyUtils

---@class CurrencyManager
local CurrencyManager = {
    -- 玩家货币数据缓存
    playerCurrencyCache = {},
    
    
    -- 货币变化事件监听器
    changeListeners = {},
    
    -- 每日获取统计
    dailyAcquisitionStats = {},
    
    -- 上次保存时间
    lastSaveTime = 0,
    
    -- 自动保存间隔（秒）
    SAVE_INTERVAL = 60
}



--- 设置自动保存定时器
function CurrencyManager:SetupAutoSave()
    
end

--- 处理客户端货币操作请求
---@param uin number 玩家ID
---@param args table 请求参数
function CurrencyManager:HandleClientRequest(uin, args)
    local currencyType = args.currency_type
    local amount = tonumber(args.amount) or 0
    local operation = args.operation
    local source = args.source or MCurrencyConst.SOURCE_TYPE.OTHER
    
    -- 验证请求参数
    if not MCurrencyConfig:isValidCurrencyType(currencyType) or 
       not MCurrencyUtils.isValidAmount(amount) then
        self:SendResponseToClient(uin, {
            success = false,
            code = MCurrencyConst.RESULT_CODE.INVALID_CURRENCY,
            message = "无效的货币类型或金额"
        })
        return
    end
    
    -- 执行对应操作
    local result
    if operation == MCurrencyConst.OPERATION_TYPE.GAIN then
        result = self:AddCurrency(uin, currencyType, amount, source)
    elseif operation == MCurrencyConst.OPERATION_TYPE.CONSUME then
        result = self:SubtractCurrency(uin, currencyType, amount, source)
    else
        result = {
            success = false,
            code = MCurrencyConst.RESULT_CODE.INVALID_AMOUNT,
            message = "无效的操作类型"
        }
    end
    
    -- 发送结果给客户端
    self:SendResponseToClient(uin, result)
end

--- 处理货币兑换请求
---@param uin number 玩家ID
---@param args table 请求参数
function CurrencyManager:HandleExchangeRequest(uin, args)
    local fromCurrency = args.from_currency
    local toCurrency = args.to_currency
    local amount = tonumber(args.amount) or 0
    
    -- 验证兑换参数
    if not MCurrencyConfig:isValidCurrencyType(fromCurrency) or 
       not MCurrencyConfig:isValidCurrencyType(toCurrency) or
       not MCurrencyUtils.isValidAmount(amount) then
        self:SendResponseToClient(uin, {
            success = false,
            code = MCurrencyConst.RESULT_CODE.INVALID_CURRENCY,
            message = "无效的货币类型或金额"
        })
        return
    end
    
    -- 执行兑换操作
    local result = self:ExchangeCurrency(uin, fromCurrency, toCurrency, amount)
    
    -- 发送结果给客户端
    self:SendResponseToClient(uin, result)
end

--- 发送响应到客户端
---@param uin number 玩家ID
---@param result table 结果数据
function CurrencyManager:SendResponseToClient(uin, result)
    gg.network_channel:fireClient(uin, {
        cmd = "cmd_currency_response",
        result = result
    })
    
    -- 如果操作成功且有货币变动，发送更新通知
    if result.success and result.actualAmount > 0 then
        self:SyncCurrencyToClient(uin)
    end
end

--- 获取玩家货币数据
---@param uin number 玩家ID
---@return table 玩家货币数据
function CurrencyManager:GetPlayerCurrencyData(uin)
    if not self.playerCurrencyCache[uin] then
        -- 从存储加载数据
        local success, data = CurrencyStorage:LoadPlayerCurrencyData(uin)
        
        if success and data then
            self.playerCurrencyCache[uin] = data
        else
            -- 创建新的货币数据
            self.playerCurrencyCache[uin] = self:CreateDefaultCurrencyData(uin)
        end
    end
    
    return self.playerCurrencyCache[uin]
end

--- 创建默认货币数据
---@param uin number 玩家ID
---@return table 默认货币数据
function CurrencyManager:CreateDefaultCurrencyData(uin)
    local data = {
        uin = uin,
        currencies = {},
        lastResetDate = MCurrencyUtils.getCurrentDate(),
    }
    -- 初始化所有货币类型
    for currencyType, amount in pairs(MCurrencyConfig.INITIAL_CURRENCY) do
        data.currencies[currencyType] = amount
    end
    return data
end



---@param uin number 玩家ID
---@param cloudCurrencyData table 服务器的玩家货币
function CurrencyManager:InitCurrencyData(uin,cloudCurrencyData)
    if next(cloudCurrencyData) == nil then
        self.playerCurrencyCache[uin] =self:CreateDefaultCurrencyData(uin)
    else
        cloudCurrencyData.lastResetDate = MCurrencyUtils.getCurrentDate()
        self.playerCurrencyCache[uin] =cloudCurrencyData
    end
end

--- 添加货币
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param amount number 金额
---@param source number 来源类型
---@return table 操作结果
function CurrencyManager:AddCurrency(uin, currencyType, amount, source)
    if not MCurrencyConfig:isValidCurrencyType(currencyType) or not MCurrencyUtils.isValidAmount(amount) then
        return MCurrencyUtils.createOperationResult(false, MCurrencyConst.RESULT_CODE.INVALID_CURRENCY, 0)
    end
    
    -- 获取玩家货币数据
    local currencyData = self:GetPlayerCurrencyData(uin)

    
    -- 当前货币数量
    local currentAmount = currencyData.currencies[currencyType] or 0
    -- -- 检查是否达到每日获取上限
    -- if MCurrencyUtils.isDailyCapReached(currencyType, currencyData.dailyStats[currencyType].gained, amount) then
    --     return MCurrencyUtils.createOperationResult(
    --         false, 
    --         MCurrencyConst.RESULT_CODE.DAILY_LIMIT_REACHED, 
    --         0, 
    --         MCurrencyUtils.getErrorMessage(MCurrencyConst.RESULT_CODE.DAILY_LIMIT_REACHED, currencyType)
    --     )
    -- end
    
    -- 检查是否超过上限
    if MCurrencyUtils.isExceedsCap(currencyType, currentAmount, amount) then
        -- 计算实际可获取的金额
        local actualAmount = MCurrencyUtils.calculateActualGainAmount(currencyType, currentAmount, amount)
        
        -- 更新货币数量
        currencyData.currencies[currencyType] = currentAmount + actualAmount
        
        -- 更新每日统计
        currencyData.dailyStats[currencyType].gained = currencyData.dailyStats[currencyType].gained + actualAmount
        
        -- 记录交易
        self:LogTransaction(uin, currencyType, MCurrencyConst.OPERATION_TYPE.GAIN, actualAmount, source)
        
        -- 保存数据
        self:SavePlayerData(uin, false)
        
        return MCurrencyUtils.createOperationResult(
            true, 
            MCurrencyConst.RESULT_CODE.EXCEEDS_CAP, 
            actualAmount, 
            "已达到货币上限，获得部分金额"
        )
    end
    
    -- 正常添加货币
    currencyData.currencies[currencyType] = currentAmount + amount
    
    -- 更新每日统计
    currencyData.dailyStats[currencyType].gained = currencyData.dailyStats[currencyType].gained + amount
    
    -- 记录交易
    self:LogTransaction(uin, currencyType, MCurrencyConst.OPERATION_TYPE.GAIN, amount, source)
    
    -- 保存数据
    self:SavePlayerData(uin, false)
    
    -- 触发事件
    self:TriggerCurrencyChanged(uin, currencyType, amount, MCurrencyConst.OPERATION_TYPE.GAIN)
    
    return MCurrencyUtils.createOperationResult(true, MCurrencyConst.RESULT_CODE.SUCCESS, amount)
end

--- 扣除货币
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param amount number 金额
---@param source number 消费场景
---@return table 操作结果
function CurrencyManager:SubtractCurrency(uin, currencyType, amount, source)
    if not MCurrencyConfig:isValidCurrencyType(currencyType) or not MCurrencyUtils.isValidAmount(amount) then
        return MCurrencyUtils.createOperationResult(false, MCurrencyConst.RESULT_CODE.INVALID_CURRENCY, 0)
    end
    
    -- 获取玩家货币数据
    local currencyData = self:GetPlayerCurrencyData(uin)
    
    -- 当前货币数量
    local currentAmount = currencyData.currencies[currencyType] or 0
    
    -- 检查是否足够
    if currentAmount < amount then
        return MCurrencyUtils.createOperationResult(
            false, 
            MCurrencyConst.RESULT_CODE.INSUFFICIENT_AMOUNT, 
            0, 
            MCurrencyUtils.getErrorMessage(MCurrencyConst.RESULT_CODE.INSUFFICIENT_AMOUNT, currencyType)
        )
    end
    
    -- 扣除货币
    currencyData.currencies[currencyType] = currentAmount - amount
    
    -- 更新每日统计
    currencyData.dailyStats[currencyType].consumed = currencyData.dailyStats[currencyType].consumed + amount
    
    -- 记录交易
    self:LogTransaction(uin, currencyType, MCurrencyConst.OPERATION_TYPE.CONSUME, amount, source)
    
    -- 保存数据
    self:SavePlayerData(uin, false)
    
    -- 触发事件
    self:TriggerCurrencyChanged(uin, currencyType, -amount, MCurrencyConst.OPERATION_TYPE.CONSUME)
    
    return MCurrencyUtils.createOperationResult(true, MCurrencyConst.RESULT_CODE.SUCCESS, amount)
end

--- 货币兑换
---@param uin number 玩家ID
---@param fromCurrency string 源货币类型
---@param toCurrency string 目标货币类型
---@param amount number 源货币金额
---@return table 操作结果
function CurrencyManager:ExchangeCurrency(uin, fromCurrency, toCurrency, amount)
    -- 检查兑换有效性
    if not MCurrencyUtils.isExchangeValid(fromCurrency, toCurrency) then
        return MCurrencyUtils.createOperationResult(
            false, 
            MCurrencyConst.RESULT_CODE.EXCHANGE_NOT_SUPPORTED, 
            0, 
            "不支持的货币兑换"
        )
    end
    
    -- 获取玩家货币数据
    local currencyData = self:GetPlayerCurrencyData(uin)
    
    
    -- 检查源货币是否足够
    local currentFromAmount = currencyData.currencies[fromCurrency] or 0
    if currentFromAmount < amount then
        return MCurrencyUtils.createOperationResult(
            false, 
            MCurrencyConst.RESULT_CODE.INSUFFICIENT_AMOUNT, 
            0, 
            MCurrencyUtils.getErrorMessage(MCurrencyConst.RESULT_CODE.INSUFFICIENT_AMOUNT, fromCurrency)
        )
    end
    
    -- 计算兑换比率
    local exchangeRate = MCurrencyConfig:getExchangeRate(fromCurrency, toCurrency)
    local resultAmount = amount * exchangeRate
    
    -- 检查目标货币是否会超过上限
    local currentToAmount = currencyData.currencies[toCurrency] or 0
    if MCurrencyUtils.isExceedsCap(toCurrency, currentToAmount, resultAmount) then
        resultAmount = MCurrencyUtils.calculateActualGainAmount(toCurrency, currentToAmount, resultAmount)
        amount = math.floor(resultAmount / exchangeRate)
    end
    
    -- 检查是否达到每日兑换上限
    local dailyExchanged = currencyData.dailyStats[toCurrency].exchanged or 0
    local dailyLimit = MCurrencyConfig:getDailyExchangeLimit(fromCurrency, toCurrency)
    
    if dailyLimit > 0 and dailyExchanged + resultAmount > dailyLimit then
        local remaining = dailyLimit - dailyExchanged
        if remaining <= 0 then
            return MCurrencyUtils.createOperationResult(
                false, 
                MCurrencyConst.RESULT_CODE.DAILY_LIMIT_REACHED, 
                0, 
                "已达到每日兑换上限"
            )
        end
        
        resultAmount = remaining
        amount = math.floor(remaining / exchangeRate)
    end
    
    -- 执行兑换
    currencyData.currencies[fromCurrency] = currentFromAmount - amount
    currencyData.currencies[toCurrency] = currentToAmount + resultAmount
    
    -- 更新每日统计
    currencyData.dailyStats[toCurrency].exchanged = dailyExchanged + resultAmount
    
    -- 记录兑换交易
    local transactionId = MCurrencyUtils.generateTransactionId()
    table.insert(currencyData.exchangeRecord, {
        id = transactionId,
        time = os.time(),
        fromCurrency = fromCurrency,
        toCurrency = toCurrency,
        fromAmount = amount,
        toAmount = resultAmount,
        rate = exchangeRate
    })
    
    -- 记录交易日志
    self:LogTransaction(
        uin, 
        fromCurrency, 
        MCurrencyConst.OPERATION_TYPE.EXCHANGE, 
        -amount, 
        MCurrencyConst.CONSUME_SCENE.EXCHANGE
    )
    self:LogTransaction(
        uin, 
        toCurrency, 
        MCurrencyConst.OPERATION_TYPE.EXCHANGE, 
        resultAmount, 
        MCurrencyConst.SOURCE_TYPE.EXCHANGE
    )
    
    -- 保存数据
    self:SavePlayerData(uin, true)
    
    -- 触发事件
    self:TriggerCurrencyChanged(uin, fromCurrency, -amount, MCurrencyConst.OPERATION_TYPE.EXCHANGE)
    self:TriggerCurrencyChanged(uin, toCurrency, resultAmount, MCurrencyConst.OPERATION_TYPE.EXCHANGE)
    
    return MCurrencyUtils.createOperationResult(true, MCurrencyConst.RESULT_CODE.SUCCESS, resultAmount)
end

--- 记录交易日志
-- ---@param uin number 玩家ID
-- ---@param currencyType string 货币类型
-- ---@param operation number 操作类型
-- ---@param amount number 金额
-- ---@param source number 来源/场景
-- function CurrencyManager:LogTransaction(uin, currencyType, operation, amount, source)
--     if not self.transactionLogs[uin] then
--         self.transactionLogs[uin] = {}
--     end
    
--     table.insert(self.transactionLogs[uin], {
--         time = os.time(),
--         currency = currencyType,
--         operation = operation,
--         amount = amount,
--         source = source,
--         id = MCurrencyUtils.generateTransactionId()
--     })
    
--     -- 如果日志太多，清理旧的记录
--     if #self.transactionLogs[uin] > 100 then
--         table.remove(self.transactionLogs[uin], 1)
--     end
-- end

--- 触发货币变化事件
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param amount number 变化金额（正加负减）
---@param operation number 操作类型
function CurrencyManager:TriggerCurrencyChanged(uin, currencyType, amount, operation)
    if not self.changeListeners[uin] then return end
    
    for _, listener in pairs(self.changeListeners[uin]) do
        listener(currencyType, amount, operation)
    end
end


--- 同步货币数据到客户端
---@param uin number 玩家ID
function CurrencyManager:SyncCurrencyToClient(uin)
    local currencyData = self:GetPlayerCurrencyData(uin)
    
    -- 只发送必要的数据
    local syncData = {
        currencies = currencyData.currencies,
        dailyStats = currencyData.dailyStats
    }
    
    gg.network_channel:fireClient(uin, {
        cmd = "cmd_sync_currency_data",
        data = syncData
    })
end

--- 获取玩家货币数量
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@return number 货币数量
function CurrencyManager:GetCurrencyAmount(uin, currencyType)
    local currencyData = self:GetPlayerCurrencyData(uin)
    return currencyData.currencies[currencyType] or 0
end

--- 获取玩家所有货币数据
---@param uin number 玩家ID
---@return table 所有货币数据
function CurrencyManager:GetAllCurrencies(uin)
    local currencyData = self:GetPlayerCurrencyData(uin)
    return currencyData.currencies
end


-- --- 获取玩家交易记录
-- ---@param uin number 玩家ID
-- ---@param count number 记录数量
-- ---@return table 交易记录
-- function CurrencyManager:GetTransactionHistory(uin, count)
--     if not self.transactionLogs[uin] then return {} end
    
--     local count = count or 10
--     local result = {}
--     local total = #self.transactionLogs[uin]
    
--     -- 获取最近的记录
--     for i = total, math.max(1, total - count + 1), -1 do
--         table.insert(result, self.transactionLogs[uin][i])
--     end
    
--     return result
-- end


--- 保存玩家货币数据
---@param uin number 玩家ID
---@param force boolean 是否强制保存
function CurrencyManager:SavePlayerData(uin, force)
    -- 检查是否需要保存
    local now = os.time()
    local currencyData = self.playerCurrencyCache[uin]
    if not currencyData then return end
    -- 调用存储服务保存数据
    CurrencyStorage:SavePlayerCurrencyData(uin, currencyData)
    self.lastSaveTime = now
end

--- 保存所有玩家数据
---@param force boolean 是否强制保存
function CurrencyManager:SaveAllPlayerData(force)
    for uin, _ in pairs(self.playerCurrencyCache) do
        self:SavePlayerData(uin, force)
    end
end

--- 玩家离开游戏时保存数据
-- ---@param uin number 玩家ID
-- function CurrencyManager:PlayerLeaveGame(uin)
--     self:SavePlayerData(uin, true)
--     self.changeListeners[uin] = nil
--     -- 保留transactionLogs以便后续分析
-- end

return CurrencyManager