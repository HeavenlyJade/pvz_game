--- V109 miniw-haima
--- 货币交易处理器，负责记录和管理货币交易

local game = game
local pairs = pairs
local table = table
local os = os
local math = math

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MCurrencyConfig = require(MainStorage.code.common.MCurrency.MCurrencyConfig)   ---@type MCurrencyConfig
local MCurrencyConst = require(MainStorage.code.common.MCurrency.MCurrencyConst)   ---@type MCurrencyConst
local MCurrencyUtils = require(MainStorage.code.common.MCurrency.MCurrencyUtils)   ---@type MCurrencyUtils

---核心职责
-- 交易记录管理：记录所有货币操作的详细信息
-- 事务管理：支持复杂交易的原子性操作
-- 交易验证：验证交易的合法性
---@class CurrencyTransaction
local CurrencyTransaction = {
    -- 交易记录缓存
    transactionCache = {},
    
    -- 进行中的事务
    pendingTransactions = {},
    
    -- 事务计数器
    transactionCounter = 0,
    
    -- 日志级别
    logLevel = MCurrencyConst.LOG_LEVEL.ALL,
    
    -- 存储交易记录的最大数量
    MAX_TRANSACTION_RECORDS = 100,
    
    -- 事务超时时间（秒）
    TRANSACTION_TIMEOUT = 30
}

--- 初始化交易处理器
function CurrencyTransaction:Init()

    
    gg.log("货币交易系统初始化完成")
    return self
end


--- 记录交易
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param operationType number 操作类型
---@param amount number 金额
---@param source number 来源/场景
---@param note string? 备注
---@return string 交易ID
function CurrencyTransaction:RecordTransaction(uin, currencyType, operationType, amount, source, note)
    -- 如果日志级别不足，不记录
    if self.logLevel < MCurrencyConst.LOG_LEVEL.ALL and 
      (self.logLevel < MCurrencyConst.LOG_LEVEL.CRITICAL or operationType ~= MCurrencyConst.OPERATION_TYPE.EXCHANGE) and
      (self.logLevel < MCurrencyConst.LOG_LEVEL.ERROR or amount >= 0) then
        return ""
    end
    
    -- 生成交易ID
    local transactionId = MCurrencyUtils.generateTransactionId()
    
    -- 创建交易记录
    local transaction = {
        id = transactionId,
        uin = uin,
        time = os.time(),
        currencyType = currencyType,
        operationType = operationType,
        amount = amount,
        source = source,
        note = note or ""
    }
    
    -- 将交易记录加入缓存
    if not self.transactionCache[uin] then
        self.transactionCache[uin] = {}
    end
    
    table.insert(self.transactionCache[uin], 1, transaction)
    
    -- 限制玩家交易记录数量
    if #self.transactionCache[uin] > self.MAX_TRANSACTION_RECORDS then
        table.remove(self.transactionCache[uin])
    end
    
    return transactionId
end

--- 记录交易错误
---@param uin number 玩家ID
---@param errorMessage string 错误信息
---@param data table? 相关数据
function CurrencyTransaction:LogTransactionError(uin, errorMessage, data)
    -- 低于错误级别则不记录
    if self.logLevel < MCurrencyConst.LOG_LEVEL.ERROR then
        return
    end
    
    -- 记录错误信息
    gg.log("货币交易错误", uin, errorMessage, data or {})
    
    -- 生成错误记录
    local errorRecord = {
        uin = uin,
        time = os.time(),
        message = errorMessage,
        data = data
    }
    
    -- 将错误记录保存到特定位置
    -- 这里可以添加错误上报或存储代码
end

--- 获取玩家交易历史
---@param uin number 玩家ID
---@param count number? 记录数量
---@param filter table? 过滤条件
---@return table 交易记录
function CurrencyTransaction:GetTransactionHistory(uin, count, filter)
    -- 获取交易缓存
    local transactions = self.transactionCache[uin] or {}
    local result = {}
    local countLimit = count or 10
    
    -- 应用过滤条件
    if filter then
        for _, transaction in ipairs(transactions) do
            local matches = true
            
            -- 检查所有过滤条件
            for key, value in pairs(filter) do
                if transaction[key] ~= value then
                    matches = false
                    break
                end
            end
            
            if matches then
                table.insert(result, transaction)
                if #result >= countLimit then
                    break
                end
            end
        end
    else
        -- 不过滤，直接返回指定数量的记录
        for i = 1, math.min(countLimit, #transactions) do
            table.insert(result, transactions[i])
        end
    end
    
    return result
end

--- 开始一个事务
---@param uin number 玩家ID
---@param description string 事务描述
---@return string 事务ID
function CurrencyTransaction:BeginTransaction(uin, description)
    -- 生成事务ID
    self.transactionCounter = self.transactionCounter + 1
    local transactionId = "TX_" .. os.time() .. "_" .. self.transactionCounter
    
    -- 创建事务对象
    self.pendingTransactions[transactionId] = {
        id = transactionId,
        uin = uin,
        startTime = os.time(),
        description = description,
        operations = {},
        status = "pending"
    }
    
    return transactionId
end

--- 添加操作到事务
---@param transactionId string 事务ID
---@param currencyType string 货币类型
---@param operationType number 操作类型
---@param amount number 金额
---@param source number 来源/场景
---@return boolean 是否成功
function CurrencyTransaction:AddOperation(transactionId, currencyType, operationType, amount, source)
    local transaction = self.pendingTransactions[transactionId]
    if not transaction then
        self:LogTransactionError(0, "事务不存在：" .. transactionId)
        return false
    end
    
    -- 添加操作
    table.insert(transaction.operations, {
        currencyType = currencyType,
        operationType = operationType,
        amount = amount,
        source = source
    })
    
    return true
end

--- 提交事务
---@param transactionId string 事务ID
---@param currencyManager CurrencyManager 货币管理器
---@return boolean 是否成功
---@return string 错误信息
function CurrencyTransaction:CommitTransaction(transactionId, currencyManager)
    local transaction = self.pendingTransactions[transactionId]
    if not transaction then
        return false, "事务不存在：" .. transactionId
    end
    
    -- 验证事务中的所有操作
    for _, operation in ipairs(transaction.operations) do
        local valid, message = self:ValidateOperation(
            transaction.uin, 
            operation.currencyType,
            operation.operationType,
            operation.amount,
            currencyManager
        )
        
        if not valid then
            -- 事务验证失败，标记为失败
            transaction.status = "failed"
            transaction.failReason = message
            
            self:LogTransactionError(
                transaction.uin,
                "事务验证失败：" .. transactionId,
                {operation = operation, reason = message}
            )
            
            return false, message
        end
    end
    
    -- 执行所有操作
    local results = {}
    local success = true
    
    for _, operation in ipairs(transaction.operations) do
        local result
        
        if operation.operationType == MCurrencyConst.OPERATION_TYPE.GAIN then
            result = currencyManager:AddCurrency(
                transaction.uin,
                operation.currencyType,
                operation.amount,
                operation.source
            )
        elseif operation.operationType == MCurrencyConst.OPERATION_TYPE.CONSUME then
            result = currencyManager:SubtractCurrency(
                transaction.uin,
                operation.currencyType,
                operation.amount,
                operation.source
            )
        end
        
        table.insert(results, result)
        
        if not result.success then
            success = false
            break
        end
    end
    
    -- 如果有操作失败，尝试回滚
    if not success then
        -- 记录原始结果
        transaction.results = results
        transaction.status = "failed"
        
        -- 尝试回滚已执行的操作
        self:RollbackTransaction(transactionId, currencyManager, #results)
        
        return false, "事务执行失败，已回滚：" .. transactionId
    end
    
    -- 所有操作成功，标记事务为完成
    transaction.status = "completed"
    transaction.results = results
    transaction.completeTime = os.time()
    
    -- 记录交易
    self:RecordTransaction(
        transaction.uin,
        "transaction",
        MCurrencyConst.OPERATION_TYPE.SYSTEM_ADJUST,
        0,
        0,
        "事务完成：" .. transaction.description
    )
    
    -- 从待处理事务中移除
    self.pendingTransactions[transactionId] = nil
    
    return true, "事务成功完成"
end

--- 回滚事务
---@param transactionId string 事务ID
---@param currencyManager CurrencyManager 货币管理器
---@param executedCount number? 已执行的操作数量
---@return boolean 是否成功回滚
function CurrencyTransaction:RollbackTransaction(transactionId, currencyManager, executedCount)
    local transaction = self.pendingTransactions[transactionId]
    if not transaction then
        return false
    end
    
    -- 记录回滚尝试
    self:LogTransactionError(
        transaction.uin,
        "尝试回滚事务：" .. transactionId,
        {executedCount = executedCount}
    )
    
    -- 确定需要回滚的操作数量
    local count = executedCount or #transaction.operations
    
    -- 反向执行已执行的操作
    for i = count, 1, -1 do
        local operation = transaction.operations[i]
        
        -- 执行反向操作
        if operation.operationType == MCurrencyConst.OPERATION_TYPE.GAIN then
            -- 获得操作的回滚是减少
            currencyManager:SubtractCurrency(
                transaction.uin,
                operation.currencyType,
                operation.amount,
                MCurrencyConst.SOURCE_TYPE.SYSTEM
            )
        elseif operation.operationType == MCurrencyConst.OPERATION_TYPE.CONSUME then
            -- 消费操作的回滚是增加
            currencyManager:AddCurrency(
                transaction.uin,
                operation.currencyType,
                operation.amount,
                MCurrencyConst.SOURCE_TYPE.SYSTEM
            )
        end
    end
    
    -- 标记事务为已回滚
    transaction.status = "rolled_back"
    transaction.rollbackTime = os.time()
    
    -- 记录回滚交易
    self:RecordTransaction(
        transaction.uin,
        "transaction",
        MCurrencyConst.OPERATION_TYPE.REFUND,
        0,
        0,
        "事务回滚：" .. transaction.description
    )
    
    -- 从待处理事务中移除
    self.pendingTransactions[transactionId] = nil
    
    return true
end

--- 验证货币操作
---@param uin number 玩家ID
---@param currencyType string 货币类型
---@param operationType number 操作类型
---@param amount number 金额
---@param currencyManager CurrencyManager 货币管理器
---@return boolean 是否有效
---@return string 错误信息
function CurrencyTransaction:ValidateOperation(uin, currencyType, operationType, amount, currencyManager)
    -- 检查货币类型是否有效
    if not MCurrencyConfig:isValidCurrencyType(currencyType) then
        return false, "无效的货币类型：" .. tostring(currencyType)
    end
    
    -- 检查金额是否有效
    if not MCurrencyUtils.isValidAmount(amount) then
        return false, "无效的金额：" .. tostring(amount)
    end
    
    -- 特殊情况：消费时检查余额是否足够
    if operationType == MCurrencyConst.OPERATION_TYPE.CONSUME then
        local currentAmount = currencyManager:GetCurrencyAmount(uin, currencyType)
        if currentAmount < amount then
            return false, "货币不足：" .. tostring(currencyType) .. "，余额：" .. tostring(currentAmount) .. "，需要：" .. tostring(amount)
        end
    end
    
    -- 检查每日限额（如果是获取操作）
    if operationType == MCurrencyConst.OPERATION_TYPE.GAIN then
        local dailyStats = currencyManager:GetDailyStats(uin, currencyType)
        if dailyStats and MCurrencyUtils.isDailyCapReached(currencyType, dailyStats.gained, amount) then
            return false, "已达到每日获取上限：" .. tostring(currencyType)
        end
    end
    
    return true, ""
end

--- 清理过期交易记录
---@param days number 保留天数
function CurrencyTransaction:CleanupOldTransactions(days)
    local cutoffTime = os.time() - (days * 86400)  -- 86400秒 = 1天
    
    for uin, transactions in pairs(self.transactionCache) do
        local newList = {}
        
        for _, transaction in ipairs(transactions) do
            if transaction.time >= cutoffTime then
                table.insert(newList, transaction)
            end
        end
        
        self.transactionCache[uin] = newList
    end
    
    gg.log("已清理" .. days .. "天前的交易记录")
end


return CurrencyTransaction:Init()
