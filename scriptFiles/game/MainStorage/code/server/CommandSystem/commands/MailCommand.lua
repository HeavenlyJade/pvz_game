--- 邮件相关命令处理器

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager

--- 邮件命令参数格式说明：
--[[
新的邮件命令格式（基于发件人类型分类）：

1. 系统全服邮件:
mail {"投递方式":"全服", "发件人":"系统", "标题":"活动开启", "内容":"参与活动", "过期天数":7, "附件":{"金币":100}}

2. 系统给指定玩家的邮件:
mail {"投递方式":"个人", "收件人":123, "发件人":"系统", "标题":"封禁通知", "内容":"您因违规被禁言", "过期天数":3, "附件":{}}

3. 玩家给玩家的邮件:
mail {"投递方式":"个人", "收件人":456, "发件人":"玩家", "发件人ID":789, "标题":"你好", "内容":"交个朋友", "附件":{"仙人掌碎片":10}}

说明：
- 发件人为"系统"的邮件在客户端显示为系统邮件
- 发件人为"玩家"的邮件在客户端显示为玩家邮件
- 全服邮件只能由系统发送
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

--- 发送全服邮件
function MailCommand.sendGlobalMail(params, sender)
    local title = params["标题"] or "系统通知"
    local content = params["内容"] or ""
    local expireDays = tonumber(params["过期天数"]) or MailEventConfig.DEFAULT_EXPIRE_DAYS
    local attachments = parseAttachments(params)

    local mailId = MailManager:SendGlobalMail(title, content, attachments, expireDays)
    if mailId then
        sender:SendHoverText("全服邮件发送成功")
        gg.log("全服邮件发送成功", "发件人:", params["发件人"], "标题:", title)
    else
        sender:SendHoverText("全服邮件发送失败")
    end
    return mailId ~= nil
end

--- 发送个人邮件
function MailCommand.sendPersonalMail(params, sender)
    local recipientUin = tonumber(params["收件人"])
    if not recipientUin then
        sender:SendHoverText("缺少'收件人'字段")
        return false
    end

    local senderType = params["发件人"]
    local title = params["标题"] or "无标题邮件"
    local content = params["内容"] or ""
    local expireDays = tonumber(params["过期天数"])
    local attachments = parseAttachments(params)
    local senderInfo

    -- 根据发件人类型设置发件人信息
    if senderType == "系统" then
        senderInfo = { name = "系统", id = 0 }
    elseif senderType == "玩家" then
        local senderUin = tonumber(params["发件人ID"])
        if not senderUin then
            sender:SendHoverText("玩家邮件缺少'发件人ID'字段")
            return false
        end

        -- 验证发件人权限
        if senderUin ~= sender.uin then
            sender:SendHoverText("只能以自己的身份发送邮件")
            return false
        end

        senderInfo = { name = sender.name, id = sender.uin }
    else
        sender:SendHoverText("未知的发件人类型: " .. (senderType or "nil") .. "。有效类型: '系统', '玩家'")
        return false
    end

    local mailId = MailManager:SendPersonalMail(recipientUin, title, content, attachments, senderInfo, expireDays)
    if mailId then
        local typeText = senderType == "系统" and "系统邮件" or "玩家邮件"
        sender:SendHoverText(typeText .. "已成功发送给 " .. recipientUin)
        gg.log("个人邮件发送成功", "发件人类型:", senderType, "收件人:", recipientUin, "标题:", title)
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
    local deliveryMethod = params["投递方式"]
    local senderType = params["发件人"]

    -- 参数验证
    if not deliveryMethod then
        player:SendHoverText("缺少'投递方式'字段。有效方式: '全服', '个人'")
        return false
    end

    if not senderType then
        player:SendHoverText("缺少'发件人'字段。有效类型: '系统', '玩家'")
        return false
    end

    gg.log("邮件命令执行", "投递方式:", deliveryMethod, "发件人:", senderType)

    if deliveryMethod == "全服" then
        -- 全服邮件只能由系统发送
        if senderType ~= "系统" then
            player:SendHoverText("全服邮件只能由系统发送")
            return false
        end
        return MailCommand.sendGlobalMail(params, player)

    elseif deliveryMethod == "个人" then
        return MailCommand.sendPersonalMail(params, player)

    else
        player:SendHoverText("未知的投递方式: " .. deliveryMethod .. "。有效方式: '全服', '个人'")
        return false
    end
end

return MailCommand
