--- 邮件相关命令处理器

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

-- 使用示例:
-- 发送邮件: mail {"操作":"发送","收件人":10001,"标题":"问候","内容":"你好！","附件":{"金币":1000}}
-- 发送系统邮件: mail {"操作":"系统邮件","收件人":10001,"标题":"通知","内容":"系统维护","附件":{"金币":5000}}
-- 发送全服邮件: mail {"操作":"系统邮件","全服":true,"标题":"活动开启","内容":"参与活动","附件":{"金币":1000},"过期天数":7}
-- 阅读邮件: mail {"操作":"阅读","邮件ID":"mail_p_1234567890"}
-- 领取附件: mail {"操作":"领取","邮件ID":"mail_p_1234567890"}
-- 删除邮件: mail {"操作":"删除","邮件ID":"mail_p_1234567890"}
-- 刷新邮件列表: mail {"操作":"刷新"}


---@class MailCommand
local MailCommand = {}

--- 发送邮件指令处理
---@param params table 参数
---@param sender Player 发送邮件的玩家
---@return boolean 是否成功
function MailCommand.send(params, sender)
    local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
    
    -- 解析收件人
    local recipientUin = params["玩家"] -- 玩家ID
    
    -- 检查收件人是否存在
    if not recipientUin then
        sender:SendHoverText("找不到收件人")
        return false
    end
    
    -- 获取邮件内容
    local title = params["标题"] or "无标题邮件"
    local content = params["内容"] or ""
    
    -- 处理附件
    local attachments = {}
    if params["附件"] then
        if type(params["附件"]) == "table" then
            for itemType, amount in pairs(params["附件"]) do
                table.insert(attachments, {
                    type = itemType,
                    amount = tonumber(amount) or 1
                })
            end
        end
    end
    
    -- 发送邮件
    local mailId = MailManager:SendPersonalMail(
        recipientUin,
        title,
        content,
        attachments,
        {
            name = sender.name,
            type = MailManager.MAIL_TYPE.PLAYER,
            id = sender.uin
        }
    )
    
    if mailId then
        sender:SendHoverText("邮件发送成功")
        return true
    else
        sender:SendHoverText("邮件发送失败")
        return false
    end
end

--- 发送系统邮件给玩家
---@param params table 参数
---@param sender Player 发送邮件的玩家
---@return boolean 是否成功
function MailCommand.sendSystem(params, sender)
    -- 检查权限
    if not sender.isAdmin and not params["忽略权限"] then
        sender:SendHoverText("没有权限发送系统邮件")
        return false
    end
    
    local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
    
    -- 获取邮件内容
    local title = params["标题"] or "系统通知"
    local content = params["内容"] or ""
    
    -- 处理附件
    local attachments = {}
    if params["附件"] then
        if type(params["附件"]) == "table" then
            for itemType, amount in pairs(params["附件"]) do
                table.insert(attachments, {
                    type = itemType,
                    amount = tonumber(amount) or 1
                })
            end
        end
    end
    
    -- 判断是个人邮件还是全服邮件
    if params["全服"] then
        -- 发送全服邮件
        local expireDays = tonumber(params["过期天数"]) or 30
        local mailId = MailManager:SendGlobalMail(title, content, attachments, expireDays)
        
        if mailId then
            sender:SendHoverText("全服邮件发送成功")
            return true
        else
            sender:SendHoverText("全服邮件发送失败")
            return false
        end
    else
        -- 发送给指定玩家
        local recipientUin = tonumber(params["收件人"])
        
        -- 检查收件人是否存在
        if not recipientUin then
            sender:SendHoverText("请指定有效的收件人UIN")
            return false
        end
        
        -- 验证UIN是否有效（可选）
        local recipient = gg.getPlayerByUin(recipientUin)
        if not recipient and not params["忽略检查"] then
            sender:SendHoverText("找不到UIN为"..recipientUin.."的玩家")
            return false
        end
        
        -- 发送系统邮件
        local mailId = MailManager:SendPersonalMail(
            recipientUin,
            title,
            content,
            attachments,
            {
                name = "系统",
                type = MailManager.MAIL_TYPE.SYSTEM,
                id = 0
            }
        )
        
        if mailId then
            sender:SendHoverText("系统邮件发送成功")
            return true
        else
            sender:SendHoverText("系统邮件发送失败")
            return false
        end
    end
end

--- 查看邮件
---@param params table 参数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.read(params, player)
    local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
    
    local mailId = params["邮件ID"]
    local isGlobal = params["是全服"] and true or false
    
    if not mailId then
        player:SendHoverText("请指定邮件ID")
        return false
    end
    
    -- 构造事件数据
    local eventData = {
        uin = player.uin,
        mail_id = mailId,
        is_global = isGlobal
    }
    
    -- 调用阅读邮件处理
    MailManager:HandleReadMail(eventData)
    return true
end

--- 领取附件
---@param params table 参数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.claim(params, player)
    local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
    
    local mailId = params["邮件ID"]
    local isGlobal = params["是全服"] and true or false
    
    if not mailId then
        player:SendHoverText("请指定邮件ID")
        return false
    end
    
    -- 构造事件数据
    local eventData = {
        uin = player.uin,
        mail_id = mailId,
        is_global = isGlobal
    }
    
    -- 调用领取附件处理
    MailManager:HandleClaimAttachment(eventData)
    return true
end

--- 删除邮件
---@param params table 参数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.delete(params, player)
    local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
    
    local mailId = params["邮件ID"]
    local isGlobal = params["是全服"] and true or false
    
    if not mailId then
        player:SendHoverText("请指定邮件ID")
        return false
    end
    
    -- 构造事件数据
    local eventData = {
        uin = player.uin,
        mail_id = mailId,
        is_global = isGlobal
    }
    
    -- 调用删除邮件处理
    MailManager:HandleDeleteMail(eventData)
    return true
end

--- 刷新邮件列表
---@param params table 参数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.refresh(params, player)
    local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
    
    -- 构造事件数据
    local eventData = {
        uin = player.uin
    }
    
    -- 调用获取邮件列表处理
    MailManager:HandleGetMailList(eventData)
    return true
end

--- 邮件系统指令入口
---@param params table 参数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.main(params, player)
    -- 根据操作类型调用相应的处理函数
    local operation = params["操作"]
    
    if operation == "发送" then
        return MailCommand.send(params, player)
    elseif operation == "系统邮件" then
        return MailCommand.sendSystem(params, player)
    elseif operation == "阅读" then
        return MailCommand.read(params, player)
    elseif operation == "领取" then
        return MailCommand.claim(params, player)
    elseif operation == "删除" then
        return MailCommand.delete(params, player)
    elseif operation == "刷新" then
        return MailCommand.refresh(params, player)
    else
        player:SendHoverText("未知的邮件操作: " .. (operation or "nil"))
        return false
    end
end

return MailCommand