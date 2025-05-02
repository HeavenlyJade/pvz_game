--- 邮件相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MMailManager = require(MainStorage.code.server.mail.MMailManager)   ---@type MMailManager
local MMailUtils = require(MainStorage.code.common.MMail.MMailUtils)   ---@type MMailUtils
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig)   ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst)   ---@type MMailConst

---@class MailCommands
local MailCommands = {}

-- 命令执行器工厂
local CommandExecutors = {}

-- 获取邮件列表执行器
function CommandExecutors.GetMailList(params, player)
    if params.category ~= "邮件" then return false end
    
    -- 获取过滤选项
    local filterOptions = {
        page = tonumber(params.param1) or 1,
        pageSize = tonumber(params.param2) or 10,
        unreadOnly = params.value == "未读",
        attachmentOnly = params.value == "附件",
        type = params.subcategory ~= "全部" and params.subcategory or nil
    }
    
    -- 调用邮件管理器获取邮件列表
    local result = MMailManager:GetPlayerMailList(player.uin, filterOptions)
    
    if result.success then
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_mail_list_response",
            mails = result.data.mails,
            total = result.data.total,
            page = result.data.page,
            page_size = result.data.pageSize,
            total_pages = result.data.totalPages,
            stats = result.data.stats
        })
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获取邮件列表失败: " .. (result.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- 获取邮件详情执行器
function CommandExecutors.GetMailDetail(params, player)
    if params.category ~= "邮件" then return false end
    
    local mailId = params.id
    if not mailId then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "邮件ID不能为空",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 调用邮件管理器获取邮件详情
    local result = MMailManager:GetMailDetail(player.uin, mailId)
    
    if result.success then
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_mail_detail_response",
            mail = result.data.mail
        })
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获取邮件详情失败: " .. (result.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- 领取附件执行器
function CommandExecutors.ClaimAttachment(params, player)
    if params.category ~= "邮件" then return false end
    
    local mailId = params.id
    if not mailId then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "邮件ID不能为空",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 调用邮件管理器领取附件
    local result = MMailManager:ClaimMailAttachments(player.uin, mailId)
    
    if result.success then
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "成功领取附件",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        -- 更新邮件列表
        CommandExecutors.GetMailList({category = "邮件", param1 = "1"}, player)
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "领取附件失败: " .. (result.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- 删除邮件执行器
function CommandExecutors.DeleteMail(params, player)
    if params.category ~= "邮件" then return false end
    
    local mailId = params.id
    if not mailId then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "邮件ID不能为空",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 调用邮件管理器删除邮件
    local result = MMailManager:DeleteMail(player.uin, mailId)
    
    if result.success then
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "成功删除邮件",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        -- 更新邮件列表
        CommandExecutors.GetMailList({category = "邮件", param1 = "1"}, player)
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "删除邮件失败: " .. (result.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- 批量操作执行器
function CommandExecutors.BatchOperation(params, player)
    if params.category ~= "邮件" then return false end
    
    -- 解析操作类型
    local operationType
    if params.action == "全部已读" then
        operationType = MMailConst.BATCH_OPERATION.READ_ALL
    elseif params.action == "领取全部" then
        operationType = MMailConst.BATCH_OPERATION.CLAIM_ALL
    elseif params.action == "删除全部" then
        operationType = MMailConst.BATCH_OPERATION.DELETE_ALL
    else
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "未知的批量操作类型",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 获取邮件列表
    local filterOptions = {
        unreadOnly = operationType == MMailConst.BATCH_OPERATION.READ_ALL,
        attachmentOnly = operationType == MMailConst.BATCH_OPERATION.CLAIM_ALL,
        excludeDeleted = true,
        excludeExpired = true
    }
    
    local listResult = MMailManager:GetPlayerMailList(player.uin, filterOptions)
    if not listResult.success then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获取邮件列表失败",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 准备邮件ID列表
    local mailIds = {}
    for _, mail in ipairs(listResult.data.mails) do
        table.insert(mailIds, mail.uuid)
    end
    
    if #mailIds == 0 then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "没有可操作的邮件",
            color = ColorQuad.new(255, 255, 0, 255)
        })
        return true
    end
    
    -- 执行批量操作
    local result = MMailManager:BatchOperateMails(player.uin, operationType, mailIds)
    
    if result.success then
        -- 通知客户端
        local operationText
        if operationType == MMailConst.BATCH_OPERATION.READ_ALL then
            operationText = "标记已读"
        elseif operationType == MMailConst.BATCH_OPERATION.CLAIM_ALL then
            operationText = "领取附件"
        elseif operationType == MMailConst.BATCH_OPERATION.DELETE_ALL then
            operationText = "删除"
        end
        
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = string.format("成功%s %d/%d 封邮件", operationText, result.data.success_count, result.data.total),
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        -- 更新邮件列表
        CommandExecutors.GetMailList({category = "邮件", param1 = "1"}, player)
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "批量操作失败: " .. (result.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- 发送邮件执行器
function CommandExecutors.SendMail(params, player)
    if params.category ~= "邮件" then return false end
    
    -- 检查参数
    local receiverId = tonumber(params.id)
    local title = params.param1
    local content = params.param2
    
    if not receiverId or not title or not content then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "发送邮件参数不完整",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 检查是否有附件
    local attachments = nil
    if params.value and params.value ~= "" then
        -- 格式: 类型:ID:数量,类型:ID:数量
        local attachmentList = {}
        for attachmentStr in string.gmatch(params.value, "[^,]+") do
            local attType, attId, attQuantity = string.match(attachmentStr, "(%d+):(%d+):(%d+)")
            if attType and attId and attQuantity then
                table.insert(attachmentList, {
                    type = tonumber(attType),
                    id = tonumber(attId),
                    quantity = tonumber(attQuantity)
                })
            end
        end
        
        if #attachmentList > 0 then
            attachments = attachmentList
        end
    end
    
    -- 获取发送者名字
    local senderName = player.info.nickname or "未知玩家"
    
    -- 调用邮件管理器发送邮件
    local result = MMailManager:SendMailToPlayer(
        senderName,
        receiverId,
        title,
        content,
        attachments,
        {
            mailType = MMailConfig.MAIL_TYPES.PLAYER,
            senderType = MMailConst.SENDER_TYPE.PLAYER
        }
    )
    
    if result.success then
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "邮件发送成功",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "发送邮件失败: " .. (result.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- GM发送系统邮件执行器 (仅管理员)
function CommandExecutors.SendSystemMail(params, player)
    if params.category ~= "邮件" or params.subcategory ~= "系统" then return false end
    
    -- 检查是否有管理员权限
    if not player.is_admin then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "没有管理员权限",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 检查参数
    local title = params.param1
    local content = params.param2
    
    if not title or not content then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "发送系统邮件参数不完整",
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 检查是否有附件
    local attachments = nil
    if params.value and params.value ~= "" then
        -- 格式: 类型:ID:数量,类型:ID:数量
        local attachmentList = {}
        for attachmentStr in string.gmatch(params.value, "[^,]+") do
            local attType, attId, attQuantity = string.match(attachmentStr, "(%d+):(%d+):(%d+)")
            if attType and attId and attQuantity then
                table.insert(attachmentList, {
                    type = tonumber(attType),
                    id = tonumber(attId),
                    quantity = tonumber(attQuantity),
                    name = "奖励物品" -- 实际应该根据ID获取物品名称
                })
            end
        end
        
        if #attachmentList > 0 then
            attachments = attachmentList
        end
    end
    
    -- 设置接收目标类型
    local targetType = MMailConst.TARGET_TYPE.ALL
    local recipients = nil
    
    if params.id and params.id ~= "" then
        local targetId = tonumber(params.id)
        if targetId then
            targetType = MMailConst.TARGET_TYPE.SINGLE
            recipients = {targetId}
        else
            -- 多个接收者，格式: 玩家ID1,玩家ID2,...
            recipients = {}
            for recipientId in string.gmatch(params.id, "[^,]+") do
                table.insert(recipients, tonumber(recipientId))
            end
            targetType = MMailConst.TARGET_TYPE.MULTIPLE
        end
    end
    
    -- 创建系统邮件
    local createResult = MMailManager:CreateSystemMail(
        title,
        content,
        attachments,
        {
            sender = MMailConst.PREDEFINED_SENDER.ADMIN,
            senderType = MMailConst.SENDER_TYPE.ADMIN,
            importance = MMailConfig.IMPORTANCE_LEVEL.HIGH,
            targetType = targetType,
            recipients = recipients
        }
    )
    
    if not createResult.success then
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "创建系统邮件失败: " .. (createResult.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
    
    -- 发送邮件
    local mailId = createResult.data.mail_id
    local sendResult
    
    if targetType == MMailConst.TARGET_TYPE.ALL then
        sendResult = MMailManager:SendSystemMailToAll(mailId)
    else
        sendResult = MMailManager:SendSystemMailToPlayers(mailId, recipients)
    end
    
    if sendResult.success then
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "系统邮件发送成功",
            color = ColorQuad.new(0, 255, 0, 255)
        })
        return true
    else
        -- 通知失败
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "发送系统邮件失败: " .. (sendResult.message or "未知错误"),
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

-- 命令映射表
local CommandMapping = {
    ["列表"] = CommandExecutors.GetMailList,
    ["查看"] = CommandExecutors.GetMailDetail,
    ["领取"] = CommandExecutors.ClaimAttachment,
    ["删除"] = CommandExecutors.DeleteMail,
    ["批量"] = CommandExecutors.BatchOperation,
    ["发送"] = CommandExecutors.SendMail,
    ["系统发送"] = CommandExecutors.SendSystemMail,
}

-- 命令执行函数
function MailCommands.Execute(command, params, player)
    local executor = CommandMapping[command]
    if not executor then
        gg.log("未知邮件命令: " .. command)
        return false
    end
    
    return executor(params, player)
end

-- 兼容旧版接口
MailCommands.handlers = {}
for command, executor in pairs(CommandMapping) do
    MailCommands.handlers[command] = executor
end

return MailCommands