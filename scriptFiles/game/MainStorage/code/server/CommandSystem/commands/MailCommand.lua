--- 邮件相关命令处理器

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MailEventConfig = require(MainStorage.code.common.event_conf.event_maill) ---@type MailEventConfig
local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
--[[
邮件命令参数格式说明：

1. 个人邮件格式：
{
    ["类型"] = "个人",
    ["收件人"] = 10001,  -- 玩家UIN
    ["标题"] = "问候",
    ["内容"] = "你好！",
    ["附件"] = {["金币"] = 1000}  -- 可选
}

2. 系统邮件给指定玩家格式：
{
    ["类型"] = "系统",
    ["收件人"] = 10001,  -- 玩家UIN
    ["标题"] = "通知",
    ["内容"] = "系统维护",
    ["附件"] = {["金币"] = 5000},  -- 可选
    ["忽略检查"] = true  -- 可选，如果玩家不在线是否依然发送
}

3. 全服邮件格式：
{
    ["类型"] = "系统",
    ["标题"] = "活动开启",
    ["内容"] = "参与活动",
    ["过期天数"] = 7,  -- 可选，默认30天
    ["附件"] = {["金币"] = 1000, ["仙人掌碎片"] = 200}  -- 可选
}
]]

-- 使用示例:
-- 发送个人邮件: mail {"类型":"个人","收件人":10001,"标题":"问候","内容":"你好！","附件":{"金币":1000}}
-- 发送系统邮件给指定玩家: mail {"类型":"系统","收件人":10001,"标题":"通知","内容":"系统维护","附件":{"金币":5000}}
-- 发送全服邮件: mail {"类型":"系统","标题":"活动开启","内容":"参与活动","过期天数":7,"附件":{"金币":1000,"仙人掌碎片":200}}


---@class MailCommand
local MailCommand = {}

--- 发送个人邮件
---@param params table 个人邮件参数，包含：类型、收件人、标题、内容、附件(可选)
---@param sender Player 发送邮件的玩家
---@return boolean 是否成功
function MailCommand.sendPersonal(params, sender)


    -- 解析收件人
    local recipientUin = tonumber(params["玩家ID"])

    -- 检查收件人是否存在
    if not recipientUin then
        sender:SendHoverText("找不到收件人，请指定'玩家ID'字段")
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

--- 发送系统邮件
---@param params table 系统邮件参数，包含：类型、标题、内容、收件人(可选)、过期天数(可选)、附件(可选)
---@param sender Player 发送邮件的玩家
---@return boolean 是否成功
function MailCommand.sendSystem(params, sender)
    -- 检查权限

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

    -- 判断是发送给指定玩家还是全服
    local recipientUin = tonumber(params["收件人"])
    if not recipientUin then
        -- 发送全服邮件
        local expireDays = tonumber(params["过期天数"]) or MailEventConfig.DEFAULT_EXPIRE_DAYS
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
        -- 验证UIN是否有效（可选）
        local recipient = gg.getPlayerByUin(recipientUin)
        if not recipient and not params["忽略检查"] then
            sender:SendHoverText("找不到UIN为" .. recipientUin .. "的玩家")
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

--- 邮件系统指令入口
---@param params table 邮件命令参数，根据"类型"字段分发到不同处理函数
---@param player Player 玩家
---@return boolean 是否成功
function MailCommand.main(params, player)
    -- 根据类型调用相应的处理函数
    local mailType = params["类型"]

    if mailType == "玩家" then
        return MailCommand.sendPersonal(params, player)
    elseif mailType == "系统" then
        return MailCommand.sendSystem(params, player)
    else
        player:SendHoverText("未知的邮件类型: " .. (mailType or "nil") .. "。有效类型: '玩家', '系统'")
        return false
    end
end

return MailCommand
