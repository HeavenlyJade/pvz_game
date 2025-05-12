--- V109 miniw-haima
--- 邮件核心管理器，实现邮件系统的核心功能

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
local bagMgr = require(MainStorage.code.server.bag.BagMgr)   ---@type BagMgr

---@class MMailManager
local MMailManager = {
    -- 发送冷却时间记录
    sendCooldowns = {},
    
    -- 邮件缓存（最近处理的邮件）
    recentMailCache = {},
    
    -- 邮件操作日志
    operationLogs = {},
    
    -- 最大日志数量
    MAX_LOGS = 100,
    
    -- 已注册的邮件处理事件
    registeredEvents = {}
}

-- 初始化邮件管理器
function MMailManager:Init()
    -- 注册系统事件
    self:RegisterSystemEvents()
    
    -- 清理缓存任务
    local function cleanupTask()
        self:CleanupCache()
        wait(300) -- 5分钟执行一次
        cleanupTask()
    end
    
    -- 启动清理任务
    gg.thread_call(cleanupTask)
    
    -- gg.log("邮件管理器初始化完成")
    return self
end

-- 注册系统事件
function MMailManager:RegisterSystemEvents()
    -- 示例：注册玩家登录事件
    self:RegisterEvent("PlayerLogin", function(playerUin)
        self:OnPlayerLogin(playerUin)
    end)
    
    -- 示例：注册每日重置事件
    self:RegisterEvent("DailyReset", function()
        self:OnDailyReset()
    end)
    
    -- 示例：注册玩家等级提升事件
    self:RegisterEvent("PlayerLevelUp", function(playerUin, level)
        self:OnPlayerLevelUp(playerUin, level)
    end)
end

-- 注册事件处理函数
function MMailManager:RegisterEvent(eventName, handler)
    if not self.registeredEvents[eventName] then
        self.registeredEvents[eventName] = {}
    end
    
    table.insert(self.registeredEvents[eventName], handler)
    return #self.registeredEvents[eventName]
end

-- 触发事件
function MMailManager:TriggerEvent(eventName, ...)
    local handlers = self.registeredEvents[eventName]
    if not handlers then return end
    
    for _, handler in ipairs(handlers) do
        local success, err = pcall(handler, ...)
        if not success then
            gg.log("邮件事件处理错误: " .. eventName .. ": " .. tostring(err))
        end
    end
end

---------------------------
-- 玩家邮件核心方法
---------------------------

-- 获取玩家邮件列表
function MMailManager:GetPlayerMailList(playerUin, filterOptions)
    -- 验证参数
    if not playerUin then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取所有邮件
    local success, allMails = MMailDataMgr:GetAllPlayerMails(playerUin)
    if not success then
        return MMailConst:createResult(MMailConst.RESULT_CODE.PLAYER_NOT_FOUND)
    end
    
    -- 过滤邮件
    local filteredMails = allMails
    if filterOptions then
        filteredMails = MMailUtils.filterMails(allMails, filterOptions)
    end
    
    -- 排序邮件
    local sortedMails = MMailUtils.sortMails(filteredMails, filterOptions and filterOptions.sortBy or "time_desc")
    
    -- 分页处理
    local pageSize = filterOptions and filterOptions.pageSize or MMailConst.DEFAULT_PAGE_SIZE
    local page = filterOptions and filterOptions.page or 1
    local pagedMails = MMailUtils.getPagedMails(sortedMails, page, pageSize)
    
    -- 准备返回结果
    local mailSummaries = {}
    for _, mail in ipairs(pagedMails) do
        -- 只返回摘要信息
        table.insert(mailSummaries, MMailUtils.getMailSummary(mail))
    end
    
    -- 统计信息
    local stats = MMailUtils.getMailStats(allMails)
    
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
        mails = mailSummaries,
        total = #sortedMails,
        page = page,
        pageSize = pageSize,
        totalPages = MMailUtils.getTotalPages(#sortedMails, pageSize),
        stats = stats
    })
end

-- 获取邮件详情
function MMailManager:GetMailDetail(playerUin, mailId)
    -- 验证参数
    if not playerUin or not mailId then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取邮件
    local success, mail = MMailDataMgr:GetPlayerMail(playerUin, mailId)
    if not success then
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_NOT_FOUND)
    end
    
    -- 检查邮件是否过期
    if MMailUtils.isExpired(mail.expire_time) then
        -- 更新邮件状态
        MMailDataMgr:UpdatePlayerMail(playerUin, mailId, {
            status = MMailConst.MAIL_STATUS.EXPIRED
        })
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_EXPIRED)
    end
    
    -- 如果邮件未读，标记为已读
    if not mail.read then
        MMailDataMgr:UpdatePlayerMail(playerUin, mailId, {
            read = true
        })
        
        -- 检查是否为系统邮件
        if mail.type == MMailConfig.MAIL_TYPES.SYSTEM then
            MMailDataMgr:UpdateSystemMailStatus(playerUin, mailId, {
                read = true
            })
        end
        
        -- 记录操作日志
        self:LogOperation(MMailConst.OPERATION_TYPE.READ, mailId, playerUin)
    end
    
    -- 返回邮件详情
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
        mail = mail
    })
end

-- 发送邮件给玩家
function MMailManager:SendMailToPlayer(sender, receiverUin, title, content, attachments, options)
    -- 验证参数
    if not receiverUin or not title or not content then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 验证标题和内容
    local titleValid, titleError = MMailUtils.validateTitle(title)
    if not titleValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = titleError
        })
    end
    
    local contentValid, contentError = MMailUtils.validateContent(content)
    if not contentValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = contentError
        })
    end
    
    -- 验证附件
    if attachments then
        local attachmentsValid, attachmentsError = MMailUtils.validateAttachments(attachments)
        if not attachmentsValid then
            return MMailConst:createResult(MMailConst.RESULT_CODE.ATTACHMENT_LIMIT_REACHED, {
                message = attachmentsError
            })
        end
    end
    
    -- 设置选项
    options = options or {}
    local mailType = options.mailType or MMailConfig.MAIL_TYPES.PLAYER
    local importance = options.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL
    
    -- 检查发送冷却时间
    local senderType = options.senderType or MMailConst.SENDER_TYPE.PLAYER
    local now = MMailUtils.getCurrentTimestamp()
    local cooldownKey = sender .. "_" .. senderType
    
    if self.sendCooldowns[cooldownKey] then
        local cooldownTime = MMailConst.SEND_COOLDOWN[MMailConfig:getMailTypeName(senderType)] or MMailConst.SEND_COOLDOWN.PLAYER
        if now - self.sendCooldowns[cooldownKey] < cooldownTime then
            return MMailConst:createResult(MMailConst.RESULT_CODE.SEND_TOO_FREQUENTLY)
        end
    end
    
    -- 创建邮件对象
    local mail = {
        uuid = MMailUtils.generateMailUUID(),
        sender = sender,
        sender_type = senderType,
        receiver = receiverUin,
        title = title,
        content = content,
        create_time = now,
        expire_time = options.expire_time or MMailUtils.calculateExpiryTime(mailType, attachments and #attachments > 0, false),
        read = false,
        attachments = attachments or {},
        claimed = false,
        type = mailType,
        category = options.category or mailType,
        importance = importance,
        deleted = false
    }
    
    -- 发送邮件
    local success, mailId = MMailDataMgr:AddMailToPlayer(receiverUin, mail)
    
    if success then
        -- 更新发送冷却时间
        self.sendCooldowns[cooldownKey] = now
        
        -- 记录操作日志
        self:LogOperation(MMailConst.OPERATION_TYPE.SEND, mailId, receiverUin, {
            sender = sender,
            sender_type = senderType
        })
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
            mail_id = mailId
        })
    else
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_LIMIT_REACHED)
    end
end

-- 领取邮件附件
function MMailManager:ClaimMailAttachments(playerUin, mailId)
    -- 验证参数
    if not playerUin or not mailId then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取邮件
    local success, mail = MMailDataMgr:GetPlayerMail(playerUin, mailId)
    if not success then
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_NOT_FOUND)
    end
    
    -- 检查是否已领取
    if mail.claimed then
        return MMailConst:createResult(MMailConst.RESULT_CODE.ATTACHMENT_CLAIMED)
    end
    
    -- 检查是否有附件
    if not mail.attachments or #mail.attachments == 0 then
        return MMailConst:createResult(MMailConst.RESULT_CODE.ATTACHMENT_EMPTY)
    end
    
    -- 检查是否过期
    if MMailUtils.isExpired(mail.expire_time) then
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_EXPIRED)
    end
    
    -- 计算所需背包空间
    local requiredSpace = MMailUtils.calculateRequiredBagSpace(mail.attachments)
    
    -- 检查背包空间
    if not bagMgr.checkBagSpace(playerUin, requiredSpace) then
        return MMailConst:createResult(MMailConst.RESULT_CODE.BAG_FULL)
    end
    
    -- 开始领取附件
    local claimResults = {}
    local allSuccess = true
    
    for _, attachment in ipairs(mail.attachments) do
        -- 创建物品信息
        local itemInfo = {
            uuid = MMailUtils.generateAttachmentUUID(),
            itype = attachment.type,
            id = attachment.id,
            quality = attachment.quality or 1,
            level = attachment.level or 1,
            name = attachment.name,
            num = attachment.quantity
        }
        
        -- 添加到背包
        local addSuccess = bagMgr.tryGetItem(playerUin, itemInfo)
        
        -- 记录结果
        table.insert(claimResults, {
            item = attachment,
            success = addSuccess == 0, -- bagMgr.tryGetItem返回0表示成功
            error = addSuccess ~= 0 and "背包添加失败" or nil
        })
        
        if addSuccess ~= 0 then
            allSuccess = false
        end
    end
    
    -- 更新邮件状态
    if allSuccess then
        -- 标记邮件为已领取
        if mail.type == MMailConfig.MAIL_TYPES.SYSTEM then
            -- 系统邮件
            MMailDataMgr:UpdateSystemMailStatus(playerUin, mailId, {
                claimed = true
            })
        else
            -- 普通邮件
            MMailDataMgr:UpdatePlayerMail(playerUin, mailId, {
                claimed = true
            })
        end
        
        -- 记录操作日志
        self:LogOperation(MMailConst.OPERATION_TYPE.CLAIM, mailId, playerUin)
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
            claim_result = MMailConst.CLAIM_RESULT.ALL_SUCCESS,
            details = claimResults
        })
    else
        -- 部分成功或全部失败
        local result = allSuccess and MMailConst.CLAIM_RESULT.ALL_SUCCESS or 
                      (#claimResults > 0 and MMailConst.CLAIM_RESULT.PARTIAL_SUCCESS or MMailConst.CLAIM_RESULT.ALL_FAILED)
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
            claim_result = result,
            details = claimResults
        })
    end
end

-- 删除邮件
function MMailManager:DeleteMail(playerUin, mailId)
    -- 验证参数
    if not playerUin or not mailId then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取邮件
    local success, mail = MMailDataMgr:GetPlayerMail(playerUin, mailId)
    if not success then
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_NOT_FOUND)
    end
    
    -- 检查是否有未领取的附件
    if mail.attachments and #mail.attachments > 0 and not mail.claimed then
        -- 可以选择拒绝删除有未领取附件的邮件，也可以允许删除
        -- 这里选择允许删除，但给出警告
        local warningMessage = "邮件包含未领取的附件"
        
        -- 可以根据需要调整逻辑，例如：
        -- return MMailConst:createResult(MMailConst.RESULT_CODE.OPERATION_CANCELED, {
        --     message = "无法删除包含未领取附件的邮件"
        -- })
    end
    
    -- 检查邮件类型
    if mail.type == MMailConfig.MAIL_TYPES.SYSTEM then
        -- 系统邮件，只更新玩家的系统邮件状态
        MMailDataMgr:UpdateSystemMailStatus(playerUin, mailId, {
            deleted = true
        })
    else
        -- 普通邮件，直接删除
        MMailDataMgr:DeletePlayerMail(playerUin, mailId)
    end
    
    -- 记录操作日志
    self:LogOperation(MMailConst.OPERATION_TYPE.DELETE, mailId, playerUin)
    
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS)
end

-- 批量操作邮件
function MMailManager:BatchOperateMails(playerUin, operation, mailIds)
    -- 验证参数
    if not playerUin or not operation or not mailIds or #mailIds == 0 then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    local results = {
        success = {},
        failed = {}
    }
    
    -- 处理每个邮件
    for _, mailId in ipairs(mailIds) do
        local result
        
        if operation == MMailConst.BATCH_OPERATION.READ_ALL then
            -- 标记为已读
            local success, mail = MMailDataMgr:GetPlayerMail(playerUin, mailId)
            if success and not mail.read then
                if mail.type == MMailConfig.MAIL_TYPES.SYSTEM then
                    MMailDataMgr:UpdateSystemMailStatus(playerUin, mailId, {
                        read = true
                    })
                else
                    MMailDataMgr:UpdatePlayerMail(playerUin, mailId, {
                        read = true
                    })
                end
                
                table.insert(results.success, mailId)
            else
                table.insert(results.failed, mailId)
            end
            
        elseif operation == MMailConst.BATCH_OPERATION.CLAIM_ALL then
            -- 领取附件
            result = self:ClaimMailAttachments(playerUin, mailId)
            
            if MMailConst:isSuccess(result.code) then
                table.insert(results.success, mailId)
            else
                table.insert(results.failed, {
                    id = mailId,
                    reason = result.message
                })
            end
            
        elseif operation == MMailConst.BATCH_OPERATION.DELETE_ALL then
            -- 删除邮件
            result = self:DeleteMail(playerUin, mailId)
            
            if MMailConst:isSuccess(result.code) then
                table.insert(results.success, mailId)
            else
                table.insert(results.failed, {
                    id = mailId,
                    reason = result.message
                })
            end
        end
    end
    
    -- 记录批量操作日志
    self:LogOperation(MMailConst.OPERATION_TYPE.BATCH_SEND, "batch", playerUin, {
        operation = operation,
        success_count = #results.success,
        failed_count = #results.failed
    })
    
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
        total = #mailIds,
        success_count = #results.success,
        failed_count = #results.failed,
        details = results
    })
end

---------------------------
-- 系统邮件相关方法
---------------------------

-- 创建系统邮件
function MMailManager:CreateSystemMail(title, content, attachments, options)
    -- 验证参数
    if not title or not content then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 验证标题和内容
    local titleValid, titleError = MMailUtils.validateTitle(title)
    if not titleValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = titleError
        })
    end
    
    local contentValid, contentError = MMailUtils.validateContent(content)
    if not contentValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = contentError
        })
    end
    
    -- 验证附件
    if attachments then
        local attachmentsValid, attachmentsError = MMailUtils.validateAttachments(attachments)
        if not attachmentsValid then
            return MMailConst:createResult(MMailConst.RESULT_CODE.ATTACHMENT_LIMIT_REACHED, {
                message = attachmentsError
            })
        end
    end
    
    -- 设置选项
    options = options or {}
    local sender = options.sender or MMailConst.PREDEFINED_SENDER.SYSTEM
    local senderType = options.senderType or MMailConst.SENDER_TYPE.SYSTEM
    local mailType = MMailConfig.MAIL_TYPES.SYSTEM
    local importance = options.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL
    local targetType = options.targetType or MMailConst.TARGET_TYPE.ALL
    local recipients = options.recipients
    
    -- 创建系统邮件对象
    local mail = {
        uuid = MMailUtils.generateMailUUID(),
        sender = sender,
        sender_type = senderType,
        title = title,
        content = content,
        create_time = MMailUtils.getCurrentTimestamp(),
        expire_time = options.expire_time or MMailUtils.calculateExpiryTime(mailType, attachments and #attachments > 0, false),
        attachments = attachments or {},
        type = mailType,
        category = options.category or mailType,
        importance = importance,
        target_type = targetType,
        recipients = recipients,
        condition = options.condition,
        delivery_status = "pending",
        delivery_start_time = 0,
        delivery_complete_time = 0
    }
    
    -- 保存系统邮件
    local success, mailId = MMailDataMgr:AddSystemMail(mail)
    
    if success then
        -- 记录操作日志
        self:LogOperation(MMailConst.OPERATION_TYPE.CREATE, mailId, "system", {
            sender = sender,
            target_type = targetType
        })
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
            mail_id = mailId
        })
    else
        return MMailConst:createResult(MMailConst.RESULT_CODE.SYSTEM_ERROR)
    end
end

-- 发送系统邮件给所有玩家
function MMailManager:SendSystemMailToAll(mailId)
    -- 验证参数
    if not mailId then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取系统邮件
    local success, mail = MMailDataMgr:GetSystemMail(mailId)
    if not success then
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_NOT_FOUND)
    end
    
    -- 检查邮件类型
    if mail.type ~= MMailConfig.MAIL_TYPES.SYSTEM then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = "只能发送系统类型的邮件"
        })
    end
    
    -- 获取所有玩家ID
    local playerList = {}
    
    -- 从邮件索引获取玩家列表
    local mailIndexCache = MMailDataMgr.mailIndexCache
    if mailIndexCache and mailIndexCache.player_index then
        for playerUin, _ in pairs(mailIndexCache.player_index) do
            table.insert(playerList, playerUin)
        end
    end
    
    -- 创建批量发送操作
    local batchOperation = {
        type = "send_system_mail",
        mail_id = mailId,
        recipients = playerList,
        current_batch = 0,
        batch_size = 100 -- 每批处理100名玩家
    }
    
    -- 添加到批处理队列
    MMailDataMgr:AddBatchOperation(batchOperation)
    
    -- 更新邮件状态
    MMailDataMgr:UpdateSystemMail(mailId, {
        delivery_status = "processing",
        delivery_start_time = MMailUtils.getCurrentTimestamp()
    })
    
    -- 记录操作日志
    self:LogOperation(MMailConst.OPERATION_TYPE.BATCH_SEND, mailId, "system", {
        recipient_count = #playerList
    })
    
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
        total_recipients = #playerList
    })
end

-- 发送系统邮件给指定玩家
function MMailManager:SendSystemMailToPlayers(mailId, playerUins)
    -- 验证参数
    if not mailId or not playerUins or #playerUins == 0 then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取系统邮件
    local success, mail = MMailDataMgr:GetSystemMail(mailId)
    if not success then
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_NOT_FOUND)
    end
    
    -- 检查邮件类型
    if mail.type ~= MMailConfig.MAIL_TYPES.SYSTEM then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = "只能发送系统类型的邮件"
        })
    end
    
    -- 更新邮件接收人
    mail.recipients = playerUins
    mail.target_type = MMailConst.TARGET_TYPE.MULTIPLE
    
    -- 保存更新
    MMailDataMgr:UpdateSystemMail(mailId, {
        recipients = mail.recipients,
        target_type = mail.target_type
    })
    
    -- 创建批量发送操作
    local batchOperation = {
        type = "send_system_mail",
        mail_id = mailId,
        recipients = playerUins,
        current_batch = 0,
        batch_size = 100 -- 每批处理100名玩家
    }
    
    -- 添加到批处理队列
    MMailDataMgr:AddBatchOperation(batchOperation)
    
    -- 更新邮件状态
    MMailDataMgr:UpdateSystemMail(mailId, {
        delivery_status = "processing",
        delivery_start_time = MMailUtils.getCurrentTimestamp()
    })
    
    -- 记录操作日志
    self:LogOperation(MMailConst.OPERATION_TYPE.BATCH_SEND, mailId, "system", {
        recipient_count = #playerUins
    })
    
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
        total_recipients = #playerUins
    })
end

---------------------------
-- 活动邮件相关方法
---------------------------

-- 创建活动邮件模板
function MMailManager:CreateEventMailTemplate(eventId, template)
    -- 验证参数
    if not eventId or not template or not template.title or not template.content then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 验证标题和内容
    local titleValid, titleError = MMailUtils.validateTitle(template.title)
    if not titleValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = titleError
        })
    end
    
    local contentValid, contentError = MMailUtils.validateContent(template.content)
    if not contentValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = contentError
        })
    end
    
    -- 验证附件
    if template.attachments then
        local attachmentsValid, attachmentsError = MMailUtils.validateAttachments(template.attachments)
        if not attachmentsValid then
            return MMailConst:createResult(MMailConst.RESULT_CODE.ATTACHMENT_LIMIT_REACHED, {
                message = attachmentsError
            })
        end
    end
    
    -- 设置模板ID
    template.uuid = template.uuid or MMailUtils.generateMailUUID()
    template.event_id = eventId
    template.create_time = MMailUtils.getCurrentTimestamp()
    template.type = MMailConfig.MAIL_TYPES.EVENT
    
    -- 保存模板
    local success, mailId = MMailDataMgr:AddEventMail(eventId, template)
    
    if success then
        -- 记录操作日志
        self:LogOperation(MMailConst.OPERATION_TYPE.CREATE, mailId, "event_template", {
            event_id = eventId
        })
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
            template_id = mailId
        })
    else
        return MMailConst:createResult(MMailConst.RESULT_CODE.SYSTEM_ERROR)
    end
end

-- 开始发送活动邮件
function MMailManager:StartEventMailDelivery(eventId, templateId)
    -- 验证参数
    if not eventId or not templateId then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 创建批量发送操作
    local batchOperation = {
        type = "send_event_mail",
        event_id = eventId,
        template_id = templateId
    }
    
    -- 添加到批处理队列
    MMailDataMgr:AddBatchOperation(batchOperation)
    
    -- 记录操作日志
    self:LogOperation(MMailConst.OPERATION_TYPE.BATCH_SEND, templateId, "event", {
        event_id = eventId
    })
    
    return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS)
end

-- 发送活动奖励邮件
function MMailManager:SendEventRewardMail(playerUin, eventId, title, content, attachments, options)
    -- 验证参数
    if not playerUin or not eventId or not title or not content then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 验证标题和内容
    local titleValid, titleError = MMailUtils.validateTitle(title)
    if not titleValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = titleError
        })
    end
    
    local contentValid, contentError = MMailUtils.validateContent(content)
    if not contentValid then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER, {
            message = contentError
        })
    end
    
    -- 验证附件
    if attachments then
        local attachmentsValid, attachmentsError = MMailUtils.validateAttachments(attachments)
        if not attachmentsValid then
            return MMailConst:createResult(MMailConst.RESULT_CODE.ATTACHMENT_LIMIT_REACHED, {
                message = attachmentsError
            })
        end
    end
    
    -- 设置选项
    options = options or {}
    
    -- 创建邮件对象
    local mail = {
        uuid = MMailUtils.generateMailUUID(),
        sender = options.sender or MMailConst.PREDEFINED_SENDER.EVENT,
        sender_type = options.senderType or MMailConst.SENDER_TYPE.SYSTEM,
        receiver = playerUin,
        title = title,
        content = content,
        create_time = MMailUtils.getCurrentTimestamp(),
        expire_time = options.expire_time or MMailUtils.calculateExpiryTime(MMailConfig.MAIL_TYPES.EVENT, attachments and #attachments > 0, false),
        read = false,
        attachments = attachments or {},
        claimed = false,
        type = MMailConfig.MAIL_TYPES.EVENT,
        category = options.category or MMailConfig.MAIL_TYPES.EVENT,
        importance = options.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        deleted = false,
        event_id = eventId
    }
    
    -- 发送邮件
    local success, mailId = MMailDataMgr:AddMailToPlayer(playerUin, mail)
    
    if success then
        -- 记录操作日志
        self:LogOperation(MMailConst.OPERATION_TYPE.SEND, mailId, playerUin, {
            event_id = eventId
        })
        
        return MMailConst:createResult(MMailConst.RESULT_CODE.SUCCESS, {
            mail_id = mailId
        })
    else
        return MMailConst:createResult(MMailConst.RESULT_CODE.MAIL_LIMIT_REACHED)
    end
end

---------------------------
-- 模板邮件相关方法
---------------------------

-- 使用模板创建邮件
function MMailManager:CreateMailFromTemplate(templateId, variables, options)
    -- 验证参数
    if not templateId then
        return MMailConst:createResult(MMailConst.RESULT_CODE.INVALID_PARAMETER)
    end
    
    -- 获取模板
    local template = MMailConfig:getSystemMailTemplate(templateId)
    if not template then
        return MMailConst:createResult(MMailConst.RESULT_CODE.TEMPLATE_NOT_FOUND)
    end
    
    -- 替换变量
    local title = template.title
    local content = template.content
    
    if variables then
        title = MMailUtils.replaceTemplateVariables(title, variables)
        content = MMailUtils.replaceTemplateVariables(content, variables)
    end
    
    -- 设置选项
    options = options or {}
    
    -- 创建邮件
    local mailOptions = {
        mailType = options.mailType or MMailConfig.MAIL_TYPES.SYSTEM,
        importance = options.importance or template.importance,
        senderType = options.senderType or MMailConst.SENDER_TYPE.SYSTEM,
        category = options.category,
        targetType = options.targetType,
        recipients = options.recipients,
        condition = options.condition,
        expire_time = options.expire_time
    }
    
    -- 处理附件
    local attachments = {}
    if template.attachments then
        for _, attachment in ipairs(template.attachments) do
            -- 复制附件
            local newAttachment = {}
            for k, v in pairs(attachment) do
                newAttachment[k] = v
            end
            
            -- 可以在这里根据变量动态调整附件数量
            if variables and variables.level and attachment.quantity_factor then
                newAttachment.quantity = math.floor(attachment.quantity * tonumber(variables.level) * attachment.quantity_factor)
            end
            
            table.insert(attachments, newAttachment)
        end
    end
    
    -- 调用创建系统邮件方法
    return self:CreateSystemMail(title, content, attachments, mailOptions)
end

-- 发送欢迎邮件
function MMailManager:SendWelcomeMail(playerUin, playerName)
    -- 使用欢迎邮件模板
    local variables = {
        player_name = playerName
    }
    
    local result = self:CreateMailFromTemplate("WELCOME", variables)
    if not MMailConst:isSuccess(result.code) then
        gg.log("创建欢迎邮件失败: " .. result.message)
        return result
    end
    
    -- 直接发送给玩家
    return self:SendSystemMailToPlayers(result.data.mail_id, {playerUin})
end

-- 发送维护补偿邮件
function MMailManager:SendMaintenanceCompensationMail(maintenanceTime, duration)
    -- 使用维护公告模板
    local variables = {
        time = maintenanceTime,
        duration = duration
    }
    
    local result = self:CreateMailFromTemplate("MAINTENANCE", variables)
    if not MMailConst:isSuccess(result.code) then
        gg.log("创建维护邮件失败: " .. result.message)
        return result
    end
    
    -- 发送给所有玩家
    return self:SendSystemMailToAll(result.data.mail_id)
end

-- 发送等级奖励邮件
function MMailManager:SendLevelRewardMail(playerUin, level, playerName)
    -- 使用等级奖励模板
    local variables = {
        player_name = playerName,
        level = level
    }
    
    -- 生成等级对应的奖励
    local attachments = {
        { type = MMailConfig.ATTACHMENT_TYPES.CURRENCY, id = "gold_coin", quantity = level * 1000 },
        { type = MMailConfig.ATTACHMENT_TYPES.MATERIAL, id = common_const.MAT_ID.FRAGMENT, quantity = level * 50 }
    }
    
    -- 高级别额外奖励
    if level >= 10 then
        table.insert(attachments, { 
            type = MMailConfig.ATTACHMENT_TYPES.CONSUMABLE, 
            id = 2001, -- 高级红药水ID
            quantity = math.floor(level / 10)
        })
    end
    
    if level >= 20 then
        -- 可以添加更多高级奖励
    end
    
    -- 创建等级奖励邮件
    local mailOptions = {
        mailType = MMailConfig.MAIL_TYPES.REWARD,
        importance = MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        sender = MMailConst.PREDEFINED_SENDER.REWARD,
        category = MMailConfig.MAIL_TYPES.REWARD
    }
    
    -- 直接发送奖励邮件
    return self:SendMailToPlayer(
        mailOptions.sender,
        playerUin,
        "恭喜达到" .. level .. "级！",
        "亲爱的" .. playerName .. "，恭喜你达到" .. level .. "级！这里有一些奖励来庆祝你的成长。",
        attachments,
        mailOptions
    )
end

---------------------------
-- 系统事件处理方法
---------------------------

-- 玩家登录事件处理
function MMailManager:OnPlayerLogin(playerUin)
    -- 检查是否需要发送欢迎邮件（新玩家）
    local success, playerMailData = MMailDataMgr:LoadPlayerMailData(playerUin)
    if success then
        -- 检查是否首次登录（无邮件记录）
        if not playerMailData.mail_list or not next(playerMailData.mail_list) then
            -- 获取玩家名称
            local player = gg.getPlayerByUin(playerUin)
            local playerName = player and player.info and player.info.nickname or "冒险者"
            
            -- 发送欢迎邮件
            self:SendWelcomeMail(playerUin, playerName)
        end
        
        -- 检查重要邮件通知
        local stats = MMailUtils.getMailStats(playerMailData.mail_list)
        
        -- 未读邮件通知
        if stats.unread > 0 and MMailConfig.NOTIFICATION.UNREAD_REMINDER then
            -- 发送客户端通知
            gg.network_channel:fireClient(playerUin, {
                cmd = "cmd_mail_notification",
                type = "unread",
                count = stats.unread
            })
        end
        
        -- 未领取附件通知
        if stats.unclaimed > 0 and MMailConfig.NOTIFICATION.ATTACHMENT_REMINDER then
            -- 发送客户端通知
            gg.network_channel:fireClient(playerUin, {
                cmd = "cmd_mail_notification",
                type = "unclaimed",
                count = stats.unclaimed
            })
        end
        
        -- 即将过期邮件通知
        if stats.expiringSoon > 0 and MMailConfig.NOTIFICATION.EXPIRY_REMINDER then
            -- 发送客户端通知
            gg.network_channel:fireClient(playerUin, {
                cmd = "cmd_mail_notification",
                type = "expiring",
                count = stats.expiringSoon
            })
        end
    end
end

-- 每日重置事件处理
function MMailManager:OnDailyReset()
    -- 启动邮件清理
    MMailDataMgr:StartMailCleanup()
    
    -- 可以添加每日邮件发送逻辑
    -- 例如每日登录奖励等
end

-- 玩家等级提升事件处理
function MMailManager:OnPlayerLevelUp(playerUin, level)
    -- 检查是否是特殊等级（5级倍数）
    if level % 5 == 0 then
        -- 获取玩家名称
        local player = gg.getPlayerByUin(playerUin)
        local playerName = player and player.info and player.info.nickname or "冒险者"
        
        -- 发送等级奖励
        self:SendLevelRewardMail(playerUin, level, playerName)
    end
end

---------------------------
-- 日志和维护方法
---------------------------

-- 记录操作日志
function MMailManager:LogOperation(operationType, mailId, playerUin, details)
    local logData = MMailUtils.logMailOperation(operationType, mailId, playerUin, true, details)
    
    -- 添加到日志
    table.insert(self.operationLogs, 1, logData)
    
    -- 限制日志数量
    if #self.operationLogs > self.MAX_LOGS then
        table.remove(self.operationLogs)
    end
    
    return logData
end

-- 获取操作日志
function MMailManager:GetOperationLogs(count)
    count = count or 10
    
    local logs = {}
    for i = 1, math.min(count, #self.operationLogs) do
        table.insert(logs, self.operationLogs[i])
    end
    
    return logs
end

-- 清理缓存
function MMailManager:CleanupCache()
    -- 清理最近邮件缓存
    self.recentMailCache = {}
    
    -- 清理发送冷却记录（保留最近1小时的）
    local now = MMailUtils.getCurrentTimestamp()
    for key, time in pairs(self.sendCooldowns) do
        if now - time > 3600 then -- 1小时
            self.sendCooldowns[key] = nil
        end
    end
end

-- 导出接口
return MMailManager:Init()