--- 邮件相关命令处理器

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager

--- 邮件命令参数格式说明：
--[[
1. 系统全服邮件:
mail {"类型":"系统", "标题":"活动开启", "内容":"参与活动", "过期天数":7, "附件":{"金币":100}}

2. 系统对指定玩家邮件:
mail {"收件人类型":"玩家", "收件人ID":123, "发件人类型":"系统", "标题":"封禁通知", "内容":"您因违规被禁言", "过期天数":3, "附件":{}}

3. 玩家对玩家邮件:
mail {"收件人类型":"玩家", "收件人ID":456, "发件人类型":"玩家", "发件人ID":"789", "标题":"你好", "内容":"交个朋友", "附件":{"仙人掌碎片":10}}
]]


---@class MailCommand
local MailCommand = {}

--- 内部辅助函数：从params中解析附件
---@param params table
---@return table
local function parseAttachments(params)
    local attachments = {}
    if params["附件"] and type(params["附件"]) == "table" then
            for itemType, amount in pairs(params["附件"]) do
                table.insert(attachments, {
                    type = itemType,
                    amount = tonumber(amount) or 1
                })
            end
        end
    return attachments
end

--- 发送系统全服邮件
function MailCommand.sendSystemGlobal(params, sender)
    local title = params["标题"] or "系统通知"
    local content = params["内容"] or ""
    local expireDays = tonumber(params["过期天数"]) or MailEventConfig.DEFAULT_EXPIRE_DAYS
    local attachments = parseAttachments(params)

    local mailId = select(1, MailManager:SendGlobalMail(title, content, attachments, expireDays))
    if mailId then
        sender:SendHoverText("全服邮件发送成功")
    else
        sender:SendHoverText("全服邮件发送失败")
    end
    return mailId ~= nil
end

--- 发送系统邮件给指定玩家
function MailCommand.sendSystemToPlayer(params, sender)
    local recipientUin = tonumber(params["收件人ID"])
    if not recipientUin then
        sender:SendHoverText("缺少'收件人ID'字段")
        return false
    end

    local title = params["标题"] or "系统通知"
    local content = params["内容"] or ""
    local expireDays = tonumber(params["过期天数"])
    local attachments = parseAttachments(params)
    local senderInfo = { name = "系统", id = 0 }

    local mailId = select(1, MailManager:SendPersonalMail(recipientUin, title, content, attachments, senderInfo, expireDays))
    if mailId then
        sender:SendHoverText("系统邮件发送给 " .. recipientUin .. " 成功")
    else
        sender:SendHoverText("系统邮件发送给 " .. recipientUin .. " 失败")
    end
    return mailId ~= nil
end

--- 发送玩家邮件给指定玩家
function MailCommand.sendPlayerToPlayer(params, sender)
    local recipientUin = tonumber(params["收件人ID"])
    if not recipientUin then
        sender:SendHoverText("缺少'收件人ID'字段")
            return false
        end

    local senderUin = tonumber(params["发件人ID"])
    if not senderUin then
        sender:SendHoverText("缺少'发件人ID'字段，无法确定发件人")
            return false
        end

    -- 在实际应用中，这里可能需要从一个玩家管理器中根据senderUin获取玩家名字
    -- 为简化示例，我们假设执行指令的sender就是发件人
    if senderUin ~= sender.uin then
        sender:SendHoverText("警告：指令中的发件人ID与执行者不符。")
        return false
    end

    local senderInfo = { name = sender.name, id = sender.uin }
    local title = params["标题"] or "无标题邮件"
    local content = params["内容"] or ""
    local expireDays = tonumber(params["过期天数"])
    local attachments = parseAttachments(params)

    local mailId = select(1, MailManager:SendPersonalMail(recipientUin, title, content, attachments, senderInfo, expireDays))
        if mailId then
        sender:SendHoverText("邮件已成功发送给 " .. recipientUin)
        else
        sender:SendHoverText("邮件发送失败")
    end
    return mailId ~= nil
end


--- 邮件系统指令入口
---@param params table 邮件命令参数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.main(params, player)
    gg.log("params",params)
    local mailType = params["收件人类型"]

    if mailType == "系统" then
        return MailCommand.sendSystemGlobal(params, player)

    elseif mailType == "玩家" then
        local senderType = params["发件人类型"]
        if senderType == "系统" then
            return MailCommand.sendSystemToPlayer(params, player)
        elseif senderType == "玩家" then
            return MailCommand.sendPlayerToPlayer(params, player)
        else
            player:SendHoverText("类型为'玩家'的邮件缺少或发件人类型无效: " .. (senderType or "nil"))
            return false
        end
    else
        player:SendHoverText("未知的邮件类型: " .. (mailType or "nil") .. "。有效类型: '系统', '玩家'")
        return false
    end
end

return MailCommand
