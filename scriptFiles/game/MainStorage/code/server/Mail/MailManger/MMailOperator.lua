--- V109 miniw-haima
--- 邮件操作实现，提供邮件系统的具体操作实现

local game = game
local pairs = pairs
local ipairs = ipairs
local table = table
local string = string
local os = os
local math = math
local type = type

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig)   ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst)   ---@type MMailConst
local MMailUtils = require(MainStorage.code.common.MMail.MMailUtils)   ---@type MMailUtils
local MMailDataMgr = require(MainStorage.code.server.MDataStorage.MMailDataMgr)   ---@type MMailDataMgr
local MMailManager = require(MainStorage.code.server.mail.MMailManager)   ---@type MMailManager
local bagMgr = require(MainStorage.code.server.bag.BagMgr)   ---@type BagMgr

---@class MMailOperator
local MMailOperator = {
    -- 操作权限缓存
    permissionCache = {},
    
    -- 操作锁缓存
    operationLocks = {},
    
    -- 操作计数器
    operationCounter = {},
    
    -- 最大并发操作数
    MAX_CONCURRENT_OPERATIONS = 5,
    
    -- 操作超时时间（秒）
    OPERATION_TIMEOUT = 30,
    
    -- 最大重试次数
    MAX_RETRY_COUNT = 3
}

-- 初始化邮件操作器
function MMailOperator:Init()
    -- 注册命令处理器
    self:RegisterCommandHandlers()
    
    -- 启动操作锁清理
    local function cleanupLocksTask()
        self:CleanupOperationLocks()
        wait(60) -- 每分钟清理一次
        cleanupLocksTask()
    end
    
    gg.thread_call(cleanupLocksTask)
    
    gg.log("邮件操作器初始化完成")
    return self
end

-- 注册命令处理器
function MMailOperator:RegisterCommandHandlers()
    -- 可以在这里注册处理网络命令的函数
    local function handleMailCommand(uin_, args)
        -- 根据命令类型分发处理
        if args.cmd == "cmd_mail_get_list" then
            self:HandleGetMailList(uin_, args)
        elseif args.cmd == "cmd_mail_get_detail" then
            self:HandleGetMailDetail(uin_, args)
        elseif args.cmd == "cmd_mail_claim_attachment" then
            self:HandleClaimAttachment(uin_, args)
        elseif args.cmd == "cmd_mail_delete" then
            self:HandleDeleteMail(uin_, args)
        elseif args.cmd == "cmd_mail_batch_operation" then
            self:HandleBatchOperation(uin_, args)
        elseif args.cmd == "cmd_mail_send" then
            self:HandleSendMail(uin_, args)
        end
    end
    -- 将处理函数添加到网络通道监听
    if gg.network_channel then
        gg.network_channel.OnServerNotify:Connect(function(uin_, args)
            if args and args.cmd and string.find(args.cmd, "^cmd_mail_") then
                handleMailCommand(uin_, args)
            end
        end)
    end
end

---------------------------
-- 命令处理函数
---------------------------

-- 处理获取邮件列表请求
function MMailOperator:HandleGetMailList(playerUin, args)
    -- 检查操作权限
    if not self:CheckOperationPermission(playerUin, MMailConst.OPERATION_TYPE.READ, "mail_list") then
        self:SendResponse(playerUin, "cmd_mail_get_list_response", {
            success = false,
            message = "没有权限执行此操作"
        })
        return
    end
    
    -- 获取过滤选项
    local filterOptions = {
        page = args.page or 1,
        pageSize = args.page_size,
        sortBy = args.sort_by,
        unreadOnly = args.unread_only,
        attachmentOnly = args.attachment_only,
        unclaimedOnly = args.unclaimed_only,
        type = args.mail_type,
        startTime = args.start_time,
        endTime = args.end_time,
        excludeDeleted = true,
        excludeExpired = args.exclude_expired ~= false
    }
    
    -- 调用邮件管理器获取邮件列表
    local result = MMailManager:GetPlayerMailList(playerUin, filterOptions)
    
    -- 发送响应给客户端
    self:SendResponse(playerUin, "cmd_mail_get_list_response", {
        success = result.success,
        message = result.message,
        mails = result.data and result.data.mails or {},
        total = result.data and result.data.total or 0,
        page = result.data and result.data.page or 1,
        page_size = result.data and result.data.pageSize or 10,
        total_pages = result.data and result.data.totalPages or 1,
        stats = result.data and result.data.stats or {}
    })
end

-- 处理获取邮件详情请求
function MMailOperator:HandleGetMailDetail(playerUin, args)
    -- 检查参数
    if not args.mail_id then
        self:SendResponse(playerUin, "cmd_mail_get_detail_response", {
            success = false,
            message = "邮件ID不能为空"
        })
        return
    end
    
    -- 检查操作权限
    if not self:CheckOperationPermission(playerUin, MMailConst.OPERATION_TYPE.READ, args.mail_id) then
        self:SendResponse(playerUin, "cmd_mail_get_detail_response", {
            success = false,
            message = "没有权限查看此邮件"
        })
        return
    end
    
    -- 调用邮件管理器获取邮件详情
    local result = MMailManager:GetMailDetail(playerUin, args.mail_id)
    
    -- 发送响应给客户端
    self:SendResponse(playerUin, "cmd_mail_get_detail_response", {
        success = result.success,
        message = result.message,
        mail = result.data and result.data.mail or nil
    })
end

-- 处理领取附件请求
function MMailOperator:HandleClaimAttachment(playerUin, args)
    -- 检查参数
    if not args.mail_id then
        self:SendResponse(playerUin, "cmd_mail_claim_attachment_response", {
            success = false,
            message = "邮件ID不能为空"
        })
        return
    end
    
    -- 检查操作锁
    local lockKey = "claim_" .. playerUin .. "_" .. args.mail_id
    if not self:AcquireOperationLock(lockKey) then
        self:SendResponse(playerUin, "cmd_mail_claim_attachment_response", {
            success = false,
            message = "操作太频繁，请稍后再试"
        })
        return
    end
    
    -- 检查操作权限
    if not self:CheckOperationPermission(playerUin, MMailConst.OPERATION_TYPE.CLAIM, args.mail_id) then
        self:ReleaseOperationLock(lockKey)
        self:SendResponse(playerUin, "cmd_mail_claim_attachment_response", {
            success = false,
            message = "没有权限执行此操作"
        })
        return
    end
    
    -- 使用事务机制
    local function executeTransaction()
        -- 调用邮件管理器领取附件
        local result = MMailManager:ClaimMailAttachments(playerUin, args.mail_id)
        
        -- 发送响应给客户端
        self:SendResponse(playerUin, "cmd_mail_claim_attachment_response", {
            success = result.success,
            message = result.message,
            claim_result = result.data and result.data.claim_result or nil,
            details = result.data and result.data.details or nil
        })
        
        -- 解锁操作
        self:ReleaseOperationLock(lockKey)
        
        return result.success
    end
    
    -- 执行事务，失败时重试
    self:ExecuteWithRetry(executeTransaction, self.MAX_RETRY_COUNT)
end

-- 处理删除邮件请求
function MMailOperator:HandleDeleteMail(playerUin, args)
    -- 检查参数
    if not args.mail_id then
        self:SendResponse(playerUin, "cmd_mail_delete_response", {
            success = false,
            message = "邮件ID不能为空"
        })
        return
    end
    
    -- 检查操作锁
    local lockKey = "delete_" .. playerUin .. "_" .. args.mail_id
    if not self:AcquireOperationLock(lockKey) then
        self:SendResponse(playerUin, "cmd_mail_delete_response", {
            success = false,
            message = "操作太频繁，请稍后再试"
        })
        return
    end
    
    -- 检查操作权限
    if not self:CheckOperationPermission(playerUin, MMailConst.OPERATION_TYPE.DELETE, args.mail_id) then
        self:ReleaseOperationLock(lockKey)
        self:SendResponse(playerUin, "cmd_mail_delete_response", {
            success = false,
            message = "没有权限执行此操作"
        })
        return
    end
    
    -- 调用邮件管理器删除邮件
    local result = MMailManager:DeleteMail(playerUin, args.mail_id)
    
    -- 发送响应给客户端
    self:SendResponse(playerUin, "cmd_mail_delete_response", {
        success = result.success,
        message = result.message
    })
    
    -- 解锁操作
    self:ReleaseOperationLock(lockKey)
end

-- 处理批量操作请求
function MMailOperator:HandleBatchOperation(playerUin, args)
    -- 检查参数
    if not args.operation or not args.mail_ids or #args.mail_ids == 0 then
        self:SendResponse(playerUin, "cmd_mail_batch_operation_response", {
            success = false,
            message = "参数错误"
        })
        return
    end
    
    -- 检查操作锁
    local lockKey = "batch_" .. playerUin .. "_" .. args.operation
    if not self:AcquireOperationLock(lockKey) then
        self:SendResponse(playerUin, "cmd_mail_batch_operation_response", {
            success = false,
            message = "操作太频繁，请稍后再试"
        })
        return
    end
    
    -- 检查操作权限
    local operationType
    if args.operation == MMailConst.BATCH_OPERATION.READ_ALL then
        operationType = MMailConst.OPERATION_TYPE.READ
    elseif args.operation == MMailConst.BATCH_OPERATION.CLAIM_ALL then
        operationType = MMailConst.OPERATION_TYPE.CLAIM
    elseif args.operation == MMailConst.BATCH_OPERATION.DELETE_ALL then
        operationType = MMailConst.OPERATION_TYPE.DELETE
    end
    
    if not operationType or not self:CheckOperationPermission(playerUin, operationType, "batch") then
        self:ReleaseOperationLock(lockKey)
        self:SendResponse(playerUin, "cmd_mail_batch_operation_response", {
            success = false,
            message = "没有权限执行此操作"
        })
        return
    end
    
    -- 使用事务机制
    local function executeTransaction()
        -- 调用邮件管理器执行批量操作
        local result = MMailManager:BatchOperateMails(playerUin, args.operation, args.mail_ids)
        
        -- 发送响应给客户端
        self:SendResponse(playerUin, "cmd_mail_batch_operation_response", {
            success = result.success,
            message = result.message,
            total = result.data and result.data.total or 0,
            success_count = result.data and result.data.success_count or 0,
            failed_count = result.data and result.data.failed_count or 0
        })
        
        -- 解锁操作
        self:ReleaseOperationLock(lockKey)
        
        return result.success
    end
    
    -- 执行事务，失败时重试
    self:ExecuteWithRetry(executeTransaction, self.MAX_RETRY_COUNT)
end

-- 处理发送邮件请求
function MMailOperator:HandleSendMail(playerUin, args)
    -- 检查参数
    if not args.receiver_id or not args.title or not args.content then
        self:SendResponse(playerUin, "cmd_mail_send_response", {
            success = false,
            message = "参数错误"
        })
        return
    end
    
    -- 检查发送权限（玩家间通讯可能需要特殊权限）
    if not self:CheckOperationPermission(playerUin, MMailConst.OPERATION_TYPE.SEND, "player_mail") then
        self:SendResponse(playerUin, "cmd_mail_send_response", {
            success = false,
            message = "没有权限发送邮件"
        })
        return
    end
    
    -- 获取附件
    local attachments = args.attachments
    
    -- 验证附件内容（防止恶意附件）
    if attachments and #attachments > 0 then
        local isValid, errorMsg = self:ValidateAttachments(playerUin, attachments)
        if not isValid then
            self:SendResponse(playerUin, "cmd_mail_send_response", {
                success = false,
                message = errorMsg
            })
            return
        end
    end
    
    -- 获取发送者名称
    local player = gg.getPlayerByUin(playerUin)
    local senderName = player and player.info and player.info.nickname or "未知玩家"
    
    -- 使用邮件管理器发送邮件
    local result = MMailManager:SendMailToPlayer(
        senderName,
        args.receiver_id,
        args.title,
        args.content,
        attachments,
        {
            mailType = MMailConfig.MAIL_TYPES.PLAYER,
            senderType = MMailConst.SENDER_TYPE.PLAYER
        }
    )
    
    -- 发送响应给客户端
    self:SendResponse(playerUin, "cmd_mail_send_response", {
        success = result.success,
        message = result.message,
        mail_id = result.data and result.data.mail_id
    })
end

---------------------------
-- 管理员操作处理函数
---------------------------

-- 处理系统邮件发送请求（仅管理员）
function MMailOperator:HandleSendSystemMail(playerUin, args)
    -- 检查是否有管理员权限
    if not self:CheckAdminPermission(playerUin) then
        self:SendResponse(playerUin, "cmd_admin_send_system_mail_response", {
            success = false,
            message = "没有管理员权限"
        })
        return
    end
    
    -- 检查参数
    if not args.title or not args.content then
        self:SendResponse(playerUin, "cmd_admin_send_system_mail_response", {
            success = false,
            message = "参数错误"
        })
        return
    end
    
    -- 处理接收者
    local targetType = args.target_type or MMailConst.TARGET_TYPE.ALL
    local recipients = args.recipients
    
    -- 创建系统邮件
    local result = MMailManager:CreateSystemMail(
        args.title,
        args.content,
        args.attachments,
        {
            sender = args.sender or MMailConst.PREDEFINED_SENDER.SYSTEM,
            senderType = MMailConst.SENDER_TYPE.ADMIN,
            importance = args.importance,
            targetType = targetType,
            recipients = recipients,
            condition = args.condition,
            expire_time = args.expire_time
        }
    )
    
    if not result.success then
        self:SendResponse(playerUin, "cmd_admin_send_system_mail_response", {
            success = false,
            message = result.message
        })
        return
    end
    
    local mailId = result.data.mail_id
    
    -- 发送邮件
    local sendResult
    if targetType == MMailConst.TARGET_TYPE.ALL then
        sendResult = MMailManager:SendSystemMailToAll(mailId)
    else
        sendResult = MMailManager:SendSystemMailToPlayers(mailId, recipients)
    end
    
    -- 发送响应给客户端
    self:SendResponse(playerUin, "cmd_admin_send_system_mail_response", {
        success = sendResult.success,
        message = sendResult.message,
        mail_id = mailId,
        recipients_count = sendResult.data and sendResult.data.total_recipients or 0
    })
end

-- 处理活动邮件创建请求（仅管理员）
function MMailOperator:HandleCreateEventMail(playerUin, args)
    -- 检查是否有管理员权限
    if not self:CheckAdminPermission(playerUin) then
        self:SendResponse(playerUin, "cmd_admin_create_event_mail_response", {
            success = false,
            message = "没有管理员权限"
        })
        return
    end
    
    -- 检查参数
    if not args.event_id or not args.template then
        self:SendResponse(playerUin, "cmd_admin_create_event_mail_response", {
            success = false,
            message = "参数错误"
        })
        return
    end
    
    -- 创建活动邮件模板
    local result = MMailManager:CreateEventMailTemplate(args.event_id, args.template)
    
    -- 如果需要立即发送
    if result.success and args.send_now then
        local sendResult = MMailManager:StartEventMailDelivery(args.event_id, result.data.template_id)
        result.data.delivery_started = sendResult.success
    end
    
    -- 发送响应给客户端
    self:SendResponse(playerUin, "cmd_admin_create_event_mail_response", {
        success = result.success,
        message = result.message,
        template_id = result.data and result.data.template_id,
        delivery_started = result.data and result.data.delivery_started
    })
end

---------------------------
-- 辅助方法
---------------------------

-- 发送响应给客户端
function MMailOperator:SendResponse(playerUin, cmd, data)
    if not gg.network_channel then return end
    
    -- 添加命令标识
    data.cmd = cmd
    
    -- 发送给客户端
    gg.network_channel:fireClient(playerUin, data)
end

-- 检查操作权限
function MMailOperator:CheckOperationPermission(playerUin, operationType, targetId)
    -- 实际项目中可能需要更复杂的权限检查逻辑
    -- 例如，检查玩家是否是邮件的发送者或接收者
    
    -- 缓存权限结果
    local cacheKey = playerUin .. "_" .. operationType .. "_" .. tostring(targetId)
    if self.permissionCache[cacheKey] ~= nil then
        -- 缓存过期时间为1分钟
        if MMailUtils.getCurrentTimestamp() - self.permissionCache[cacheKey].time < 60 then
            return self.permissionCache[cacheKey].result
        end
    end
    
    -- 默认允许玩家操作自己的邮件
    local result = true
    
    -- 检查操作计数，防止短时间内操作过多
    local counterKey = playerUin .. "_" .. operationType
    self.operationCounter[counterKey] = (self.operationCounter[counterKey] or 0) + 1
    
    -- 时间衰减
    local now = MMailUtils.getCurrentTimestamp()
    if self.operationCounter[counterKey .. "_time"] then
        local elapsed = now - self.operationCounter[counterKey .. "_time"]
        self.operationCounter[counterKey] = math.max(1, self.operationCounter[counterKey] - math.floor(elapsed / 10))
    end
    self.operationCounter[counterKey .. "_time"] = now
    
    -- 如果短时间内操作过多，拒绝权限
    if self.operationCounter[counterKey] > 50 then -- 10秒内最多50次操作
        result = false
    end
    
    -- 缓存结果
    self.permissionCache[cacheKey] = {
        result = result,
        time = now
    }
    
    return result
end

-- 检查管理员权限
function MMailOperator:CheckAdminPermission(playerUin)
    -- 这里实现管理员权限检查逻辑
    -- 可以检查玩家是否在管理员列表中，或者是否有特定标记
    
    -- 示例：检查玩家对象是否有admin标记
    local player = gg.getPlayerByUin(playerUin)
    if player and player.is_admin then
        return true
    end
    
    -- 示例：硬编码的管理员列表
    local adminList = {10001, 10002} -- 管理员ID列表
    for _, adminUin in ipairs(adminList) do
        if tonumber(playerUin) == adminUin then
            return true
        end
    end
    
    return false
end

-- 验证附件内容
function MMailOperator:ValidateAttachments(playerUin, attachments)
    -- 检查附件数量限制
    if #attachments > MMailConst.MAX_ATTACHMENTS then
        return false, "附件数量超过限制"
    end
    
    -- 检查每个附件的有效性
    for _, attachment in ipairs(attachments) do
        -- 检查必要字段
        if not attachment.type or not attachment.id or not attachment.quantity then
            return false, "附件数据格式错误"
        end
        
        -- 检查数量是否为正数
        if attachment.quantity <= 0 then
            return false, "附件数量必须大于0"
        end
        
        -- 检查是否是允许的附件类型
        local validType = false
        for _, typeValue in pairs(MMailConfig.ATTACHMENT_TYPES) do
            if attachment.type == typeValue then
                validType = true
                break
            end
        end
        
        if not validType then
            return false, "无效的附件类型"
        end
        
        -- 检查玩家是否拥有足够的物品（如果是发送物品的情况）
        if attachment.type ~= MMailConfig.ATTACHMENT_TYPES.CURRENCY then
            -- 非货币类物品需要检查玩家是否拥有
            local hasItem = bagMgr.checkItemCount(playerUin, attachment.type, attachment.id, attachment.quantity)
            if not hasItem then
                return false, "物品数量不足"
            end
        end
    end
    
    return true
end

-- 获取操作锁
function MMailOperator:AcquireOperationLock(lockKey)
    -- 检查是否已经有锁
    if self.operationLocks[lockKey] then
        -- 检查锁是否过期
        local now = MMailUtils.getCurrentTimestamp()
        if now - self.operationLocks[lockKey] < self.OPERATION_TIMEOUT then
            -- 锁仍然有效，不能获取
            return false
        end
    end
    
    -- 获取锁
    self.operationLocks[lockKey] = MMailUtils.getCurrentTimestamp()
    return true
end

-- 释放操作锁
function MMailOperator:ReleaseOperationLock(lockKey)
    self.operationLocks[lockKey] = nil
    return true
end

-- 清理过期的操作锁
function MMailOperator:CleanupOperationLocks()
    local now = MMailUtils.getCurrentTimestamp()
    for key, time in pairs(self.operationLocks) do
        if now - time >= self.OPERATION_TIMEOUT then
            self.operationLocks[key] = nil
        end
    end
end

-- 带重试的事务执行
function MMailOperator:ExecuteWithRetry(transaction, maxRetries)
    local retryCount = 0
    local success = false
    
    while not success and retryCount < maxRetries do
        local ok, result = pcall(transaction)
        
        if ok and result then
            success = true
        else
            retryCount = retryCount + 1
            wait(0.5 * retryCount) -- 重试延迟，随重试次数增加
        end
    end
    
    return success
end

-- 导出接口
return MMailOperator:Init()