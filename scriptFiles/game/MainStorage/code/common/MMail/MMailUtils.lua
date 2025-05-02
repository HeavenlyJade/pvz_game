--- V109
--- 邮件系统工具函数

local game = game
local math = math
local string = string
local table = table
local os = os
local tonumber = tonumber
local tostring = tostring
local type = type

local MainStorage = game:GetService("MainStorage")
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig) ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst) ---@type MMailConst
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class MMailUtils
local MMailUtils = {}

---------------------------
-- UUID和ID生成相关函数
---------------------------

-- 生成邮件UUID
function MMailUtils.generateMailUUID()
    return gg.create_uuid("mail")
end

-- 生成附件UUID
function MMailUtils.generateAttachmentUUID()
    return gg.create_uuid("att")
end

-- 生成批次ID
function MMailUtils.generateBatchID()
    local time = os.time()
    local random = math.random(1000, 9999)
    return string.format("batch_%d_%d", time, random)
end

---------------------------
-- 时间和日期相关函数
---------------------------

-- 获取当前时间戳
function MMailUtils.getCurrentTimestamp()
    return os.time()
end

-- 计算过期时间
function MMailUtils.calculateExpiryTime(mailType, hasAttachment, isClaimed)
    local now = MMailUtils.getCurrentTimestamp()
    local expiryTime = MMailConfig:getExpirationTime(mailType, hasAttachment, isClaimed)
    return now + expiryTime
end

-- 格式化时间为可读字符串
function MMailUtils.formatTime(timestamp)
    if not timestamp then return "未知时间" end
    return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

-- 检查是否已过期
function MMailUtils.isExpired(expiryTime)
    if not expiryTime then return true end
    return MMailUtils.getCurrentTimestamp() >= expiryTime
end

-- 获取剩余时间（秒）
function MMailUtils.getRemainingTime(expiryTime)
    if not expiryTime then return 0 end
    local now = MMailUtils.getCurrentTimestamp()
    return math.max(0, expiryTime - now)
end

-- 格式化剩余时间为可读字符串
function MMailUtils.formatRemainingTime(expiryTime)
    local seconds = MMailUtils.getRemainingTime(expiryTime)
    if seconds <= 0 then
        return "已过期"
    end
    
    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    
    if days > 0 then
        return string.format("%d天%d小时", days, hours)
    elseif hours > 0 then
        return string.format("%d小时%d分钟", hours, minutes)
    elseif minutes > 0 then
        return string.format("%d分钟%d秒", minutes, seconds)
    else
        return string.format("%d秒", seconds)
    end
end

---------------------------
-- 邮件内容处理函数
---------------------------

-- 验证邮件标题
function MMailUtils.validateTitle(title)
    if not title or title == "" then
        return false, "标题不能为空"
    end
    
    if string.len(title) > MMailConst.MAX_TITLE_LENGTH then
        return false, "标题长度不能超过" .. MMailConst.MAX_TITLE_LENGTH
    end
    
    return true, nil
end

-- 验证邮件内容
function MMailUtils.validateContent(content)
    if not content or content == "" then
        return false, "内容不能为空"
    end
    
    if string.len(content) > MMailConst.MAX_CONTENT_LENGTH then
        return false, "内容长度不能超过" .. MMailConst.MAX_CONTENT_LENGTH
    end
    
    return true, nil
end

-- 替换模板变量
function MMailUtils.replaceTemplateVariables(text, variables)
    if not text or not variables then return text end
    
    local result = text
    for key, value in pairs(variables) do
        local pattern = MMailConst.TEMPLATE_VAR.PREFIX .. key .. MMailConst.TEMPLATE_VAR.SUFFIX
        result = string.gsub(result, pattern, tostring(value))
    end
    
    return result
end

-- 过滤HTML标签
function MMailUtils.stripHtmlTags(text)
    if not text then return "" end
    return string.gsub(text, "<[^>]+>", "")
end

-- 截断文本
function MMailUtils.truncateText(text, maxLength, suffix)
    if not text then return "" end
    suffix = suffix or "..."
    
    if string.len(text) <= maxLength then
        return text
    end
    
    return string.sub(text, 1, maxLength - string.len(suffix)) .. suffix
end

---------------------------
-- 附件处理函数
---------------------------

-- 验证附件列表
function MMailUtils.validateAttachments(attachments)
    if not attachments then return true, nil end
    
    if #attachments > MMailConst.MAX_ATTACHMENTS then
        return false, "附件数量不能超过" .. MMailConst.MAX_ATTACHMENTS
    end
    
    for _, attachment in ipairs(attachments) do
        if not attachment.type then
            return false, "附件类型不能为空"
        end
        
        if not attachment.id then
            return false, "附件ID不能为空"
        end
        
        if not attachment.quantity or attachment.quantity <= 0 then
            return false, "附件数量必须大于0"
        end
    end
    
    return true, nil
end

-- 计算所需背包空间
function MMailUtils.calculateRequiredBagSpace(attachments)
    if not attachments then return 0 end
    
    local uniqueItems = {}
    local totalSpace = 0
    
    for _, attachment in ipairs(attachments) do
        -- 对于可堆叠物品，尝试合并计算
        local itemKey = attachment.type .. "_" .. attachment.id
        if attachment.type == MMailConfig.ATTACHMENT_TYPES.MATERIAL or 
           attachment.type == MMailConfig.ATTACHMENT_TYPES.CONSUMABLE or
           attachment.type == MMailConfig.ATTACHMENT_TYPES.CURRENCY then
            -- 可堆叠物品
            uniqueItems[itemKey] = (uniqueItems[itemKey] or 0) + attachment.quantity
        else
            -- 不可堆叠物品，每个都需要单独空间
            totalSpace = totalSpace + 1
        end
    end
    
    -- 计算可堆叠物品需要的空间
    for _, quantity in pairs(uniqueItems) do
        -- 根据堆叠上限计算需要的格子数
        -- 这里假设堆叠上限为100，实际应根据物品类型确定
        local stackLimit = 100 
        totalSpace = totalSpace + math.ceil(quantity / stackLimit)
    end
    
    return totalSpace
end

-- 生成附件展示信息
function MMailUtils.generateAttachmentDisplayInfo(attachment)
    local itemTypeNames = {
        [MMailConfig.ATTACHMENT_TYPES.EQUIPMENT] = "装备",
        [MMailConfig.ATTACHMENT_TYPES.MATERIAL] = "材料",
        [MMailConfig.ATTACHMENT_TYPES.CONSUMABLE] = "消耗品",
        [MMailConfig.ATTACHMENT_TYPES.CURRENCY] = "货币",
        [MMailConfig.ATTACHMENT_TYPES.CARD] = "卡片",
        [MMailConfig.ATTACHMENT_TYPES.TOKEN] = "代币",
    }
    
    local typeName = itemTypeNames[attachment.type] or "物品"
    return string.format("%s x%d", attachment.name or "未知" .. typeName, attachment.quantity)
end

---------------------------
-- 邮件筛选和排序函数
---------------------------

-- 根据条件筛选邮件
function MMailUtils.filterMails(mailList, filterOptions)
    if not mailList or not filterOptions then return mailList end
    
    local result = {}
    
    for uuid, mail in pairs(mailList) do
        local include = true
        
        -- 按类型筛选
        if filterOptions.type and mail.type ~= filterOptions.type then
            include = false
        end
        
        -- 按读取状态筛选
        if filterOptions.unreadOnly and mail.read then
            include = false
        end
        
        -- 按附件状态筛选
        if filterOptions.attachmentOnly and (not mail.attachments or #mail.attachments == 0) then
            include = false
        end
        
        -- 按未领取附件筛选
        if filterOptions.unclaimedOnly and (mail.claimed or not mail.attachments or #mail.attachments == 0) then
            include = false
        end
        
        -- 按发送者筛选
        if filterOptions.sender and mail.sender ~= filterOptions.sender then
            include = false
        end
        
        -- 按时间范围筛选
        if filterOptions.startTime and mail.create_time < filterOptions.startTime then
            include = false
        end
        
        if filterOptions.endTime and mail.create_time > filterOptions.endTime then
            include = false
        end
        
        -- 排除已删除邮件
        if filterOptions.excludeDeleted and mail.deleted then
            include = false
        end
        
        -- 排除已过期邮件
        if filterOptions.excludeExpired and MMailUtils.isExpired(mail.expire_time) then
            include = false
        end
        
        if include then
            result[uuid] = mail
        end
    end
    
    return result
end

-- 邮件排序
function MMailUtils.sortMails(mailList, sortOption)
    if not mailList then return {} end
    
    local list = {}
    for uuid, mail in pairs(mailList) do
        table.insert(list, mail)
    end
    
    local sortFunctions = {
        -- 按创建时间降序（新到旧）
        time_desc = function(a, b)
            return (a.create_time or 0) > (b.create_time or 0)
        end,
        
        -- 按创建时间升序（旧到新）
        time_asc = function(a, b)
            return (a.create_time or 0) < (b.create_time or 0)
        end,
        
        -- 重要邮件优先
        importance = function(a, b)
            if a.importance ~= b.importance then
                return (a.importance or 0) > (b.importance or 0)
            end
            return (a.create_time or 0) > (b.create_time or 0)
        end,
        
        -- 未读优先
        unread = function(a, b)
            if a.read ~= b.read then
                return not a.read
            end
            return (a.create_time or 0) > (b.create_time or 0)
        end,
        
        -- 有附件优先
        attachment = function(a, b)
            local aHasAttachment = a.attachments and #a.attachments > 0 and not a.claimed
            local bHasAttachment = b.attachments and #b.attachments > 0 and not b.claimed
            if aHasAttachment ~= bHasAttachment then
                return aHasAttachment
            end
            return (a.create_time or 0) > (b.create_time or 0)
        end,
        
        -- 过期时间排序
        expiry = function(a, b)
            return (a.expire_time or 0) < (b.expire_time or 0)
        end
    }
    
    local sortFunc = sortFunctions[sortOption or "time_desc"] or sortFunctions.time_desc
    table.sort(list, sortFunc)
    
    return list
end

---------------------------
-- 分页处理函数
---------------------------

-- 获取分页邮件列表
function MMailUtils.getPagedMails(mailList, page, pageSize)
    if not mailList then return {} end
    
    page = page or 1
    pageSize = pageSize or MMailConst.DEFAULT_PAGE_SIZE
    
    local startIndex = (page - 1) * pageSize + 1
    local endIndex = startIndex + pageSize - 1
    
    local result = {}
    for i = startIndex, endIndex do
        if mailList[i] then
            table.insert(result, mailList[i])
        else
            break
        end
    end
    
    return result
end

-- 计算总页数
function MMailUtils.getTotalPages(totalCount, pageSize)
    pageSize = pageSize or MMailConst.DEFAULT_PAGE_SIZE
    return math.ceil(totalCount / pageSize)
end

---------------------------
-- 安全和验证函数
---------------------------

-- 检查是否为有效的邮件ID
function MMailUtils.isValidMailId(mailId)
    return mailId and string.match(mailId, "^mail_") ~= nil
end

-- 检查是否为有效的玩家ID
function MMailUtils.isValidPlayerId(playerId)
    return playerId and tonumber(playerId) ~= nil
end

-- 检查邮件是否可被指定玩家查看
function MMailUtils.canPlayerViewMail(mail, playerUin)
    if not mail or not playerUin then return false end
    
    -- 如果是该玩家的邮件
    if mail.receiver == playerUin then return true end
    
    -- 如果是全服邮件
    if mail.type == MMailConfig.MAIL_TYPES.SYSTEM and mail.target_type == MMailConst.TARGET_TYPE.ALL then
        return true
    end
    
    -- 如果是指定多个玩家的邮件
    if mail.target_type == MMailConst.TARGET_TYPE.MULTIPLE and mail.recipients then
        for _, recipient in ipairs(mail.recipients) do
            if recipient == playerUin then return true end
        end
    end
    
    return false
end

-- 检查邮件是否可领取附件
function MMailUtils.canClaimAttachments(mail)
    if not mail then return false end
    
    -- 没有附件
    if not mail.attachments or #mail.attachments == 0 then
        return false
    end
    
    -- 已领取
    if mail.claimed then
        return false
    end
    
    -- 已过期
    if MMailUtils.isExpired(mail.expire_time) then
        return false
    end
    
    -- 已删除
    if mail.deleted then
        return false
    end
    
    return true
end

---------------------------
-- 邮件概要和统计函数
---------------------------

-- 获取邮件摘要信息
function MMailUtils.getMailSummary(mail)
    if not mail then
        return {
            uuid = "",
            title = "未知邮件",
            sender = "未知",
            time = "未知时间",
            hasAttachment = false,
            isRead = true
        }
    end
    
    return {
        uuid = mail.uuid,
        title = mail.title,
        sender = mail.sender,
        time = MMailUtils.formatTime(mail.create_time),
        hasAttachment = mail.attachments and #mail.attachments > 0 or false,
        isRead = mail.read or false,
        isClaimed = mail.claimed or false,
        isExpired = MMailUtils.isExpired(mail.expire_time),
        importance = mail.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        type = mail.type
    }
end

-- 获取邮件统计信息
function MMailUtils.getMailStats(mailList)
    if not mailList then
        return {
            total = 0,
            unread = 0,
            withAttachment = 0,
            unclaimed = 0,
            expiringSoon = 0
        }
    end
    
    local stats = {
        total = 0,
        unread = 0,
        withAttachment = 0,
        unclaimed = 0,
        expiringSoon = 0
    }
    
    local now = MMailUtils.getCurrentTimestamp()
    local expiringSoonThreshold = now + 3 * 24 * 3600 -- 3天内过期
    
    for _, mail in pairs(mailList) do
        stats.total = stats.total + 1
        
        if not mail.read then
            stats.unread = stats.unread + 1
        end
        
        if mail.attachments and #mail.attachments > 0 then
            stats.withAttachment = stats.withAttachment + 1
            
            if not mail.claimed then
                stats.unclaimed = stats.unclaimed + 1
            end
        end
        
        if mail.expire_time and mail.expire_time <= expiringSoonThreshold and mail.expire_time > now then
            stats.expiringSoon = stats.expiringSoon + 1
        end
    end
    
    return stats
end

---------------------------
-- 日志和调试函数
---------------------------

-- 记录邮件操作日志
function MMailUtils.logMailOperation(operation, mailId, playerUin, result, details)
    local logData = {
        timestamp = MMailUtils.getCurrentTimestamp(),
        operation = operation,
        mail_id = mailId,
        player_uin = playerUin,
        result = result,
        details = details
    }
    
    -- 这里可以根据实际需求将日志写入存储或输出到控制台
    gg.log("[Mail] " .. MMailConst:getOperationName(operation) .. " " .. 
           mailId .. " by " .. tostring(playerUin) .. ": " .. 
           (result and "SUCCESS" or "FAILED") .. 
           (details and (" (" .. details .. ")") or ""))
    
    return logData
end

-- 创建默认邮件对象
function MMailUtils.createDefaultMail(playerUin, mailType)
    local now = MMailUtils.getCurrentTimestamp()
    mailType = mailType or MMailConfig.MAIL_TYPES.SYSTEM
    
    return {
        uuid = MMailUtils.generateMailUUID(),
        sender = MMailConst.PREDEFINED_SENDER.SYSTEM,
        sender_type = MMailConst.SENDER_TYPE.SYSTEM,
        receiver = playerUin,
        title = "",
        content = "",
        create_time = now,
        expire_time = now + MMailConfig:getExpirationTime(mailType, false, false),
        read = false,
        attachments = {},
        claimed = false,
        type = mailType,
        category = mailType,
        importance = MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        deleted = false
    }
end

return MMailUtils