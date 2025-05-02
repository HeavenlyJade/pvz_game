--- V109 miniw-haima
--- 系统邮件类，继承自MailBase，用于系统发送的邮件

local game = game
local pairs = pairs
local ipairs = ipairs
local table = table
local string = string
local os = os

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig)   ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst)   ---@type MMailConst
local MMailUtils = require(MainStorage.code.common.MMail.MMailUtils)   ---@type MMailUtils
local MailBase = require(MainStorage.code.server.mail_types.MailBase)   ---@type MailBase
local CommonModule = require(MainStorage.code.common.CommonModule)   ---@type CommonModule

---@class SystemMail: MailBase
local SystemMail = CommonModule.Class("SystemMail", MailBase)

-- 初始化系统邮件
function SystemMail:OnInit(params)
    -- 调用父类初始化
    MailBase.OnInit(self, params)
    
    -- 设置默认类型为系统邮件
    self.type = MMailConfig.MAIL_TYPES.SYSTEM
    
    -- 系统邮件特有属性
    self.target_type = params.target_type or MMailConst.TARGET_TYPE.ALL
    self.recipients = params.recipients or {}
    self.condition = params.condition or nil
    
    -- 发送状态追踪
    self.delivery_status = params.delivery_status or "pending"  -- pending, processing, completed, failed
    self.delivery_start_time = params.delivery_start_time or 0
    self.delivery_complete_time = params.delivery_complete_time or 0
    self.delivery_count = params.delivery_count or 0
    self.delivery_failed_count = params.delivery_failed_count or 0
    
    -- 系统邮件额外选项
    self.auto_delete = params.auto_delete or false  -- 是否在系统维护时自动删除
    self.pinned = params.pinned or false  -- 是否置顶
    self.can_reply = params.can_reply or false  -- 是否允许回复
    
    -- 邮件发送者可能是特殊系统名称
    if not self.sender or self.sender == "" then
        self.sender = MMailConst.PREDEFINED_SENDER.SYSTEM
    end
    
    -- 验证系统邮件特定参数
    self:ValidateSystemMailParams()
end

-- 验证系统邮件特定参数
function SystemMail:ValidateSystemMailParams()
    -- 验证发送目标类型
    local validTargetType = false
    for _, typeValue in pairs(MMailConst.TARGET_TYPE) do
        if self.target_type == typeValue then
            validTargetType = true
            break
        end
    end
    
    if not validTargetType then
        self.target_type = MMailConst.TARGET_TYPE.ALL  -- 默认发给所有人
    end
    
    -- 确保接收者列表是表格
    if self.target_type == MMailConst.TARGET_TYPE.MULTIPLE and type(self.recipients) ~= "table" then
        self.recipients = {}
    end
    
    -- 限制接收者数量
    if self.target_type == MMailConst.TARGET_TYPE.MULTIPLE and #self.recipients > MMailConst.MAX_RECIPIENTS then
        -- 截取前MAX_RECIPIENTS个接收者
        local tempRecipients = {}
        for i = 1, MMailConst.MAX_RECIPIENTS do
            tempRecipients[i] = self.recipients[i]
        end
        self.recipients = tempRecipients
    end
end

-- 更新发送状态
function SystemMail:UpdateDeliveryStatus(status, count, failedCount)
    self.delivery_status = status
    
    if status == "processing" and self.delivery_start_time == 0 then
        self.delivery_start_time = MMailUtils.getCurrentTimestamp()
    elseif status == "completed" or status == "failed" then
        self.delivery_complete_time = MMailUtils.getCurrentTimestamp()
    end
    
    if count then
        self.delivery_count = count
    end
    
    if failedCount then
        self.delivery_failed_count = failedCount
    end
    
    return true
end

-- 添加接收者
function SystemMail:AddRecipient(playerUin)
    if self.target_type ~= MMailConst.TARGET_TYPE.MULTIPLE and 
       self.target_type ~= MMailConst.TARGET_TYPE.SINGLE then
        -- 转换为多接收者类型
        self.target_type = MMailConst.TARGET_TYPE.MULTIPLE
        self.recipients = {}
    end
    
    -- 检查接收者数量限制
    if #self.recipients >= MMailConst.MAX_RECIPIENTS then
        return false, "接收者数量超过限制"
    end
    
    -- 检查接收者是否已存在
    for _, uin in ipairs(self.recipients) do
        if uin == playerUin then
            return false, "接收者已存在"
        end
    end
    
    -- 添加接收者
    table.insert(self.recipients, playerUin)
    return true
end

-- 移除接收者
function SystemMail:RemoveRecipient(playerUin)
    if self.target_type ~= MMailConst.TARGET_TYPE.MULTIPLE and 
       self.target_type ~= MMailConst.TARGET_TYPE.SINGLE then
        return false, "不是多接收者类型邮件"
    end
    
    for i, uin in ipairs(self.recipients) do
        if uin == playerUin then
            table.remove(self.recipients, i)
            return true
        end
    end
    
    return false, "接收者不存在"
end

-- 设置发送条件
function SystemMail:SetCondition(condition)
    if type(condition) ~= "table" then
        return false, "条件格式错误"
    end
    
    self.condition = condition
    self.target_type = MMailConst.TARGET_TYPE.CONDITION
    
    return true
end

-- 检查玩家是否满足发送条件
function SystemMail:CheckPlayerCondition(player)
    if not self.condition then
        return true
    end
    
    -- 根据具体游戏逻辑实现条件检查
    -- 例如检查玩家等级、VIP状态等
    
    -- 示例：检查玩家等级条件
    if self.condition.min_level and player.level < self.condition.min_level then
        return false
    end
    
    -- 示例：检查玩家VIP条件
    if self.condition.vip_level and (not player.vip_level or player.vip_level < self.condition.vip_level) then
        return false
    end
    
    -- 默认满足条件
    return true
end

-- 获取预估的接收者数量
function SystemMail:GetEstimatedRecipientCount()
    if self.target_type == MMailConst.TARGET_TYPE.ALL then
        -- 可以从玩家管理器获取总玩家数
        local playerCount = 0
        for _, _ in pairs(gg.server_players_list) do
            playerCount = playerCount + 1
        end
        return playerCount
    elseif self.target_type == MMailConst.TARGET_TYPE.MULTIPLE or 
           self.target_type == MMailConst.TARGET_TYPE.SINGLE then
        return #self.recipients
    elseif self.target_type == MMailConst.TARGET_TYPE.CONDITION then
        -- 可以根据条件估算玩家数量
        -- 这里简化处理，返回一个默认值
        return 100
    elseif self.target_type == MMailConst.TARGET_TYPE.GUILD and self.guild_id then
        -- 可以从公会管理器获取公会成员数
        -- 这里简化处理，返回一个默认值
        return 50
    end
    
    return 0
end

-- 置顶邮件
function SystemMail:Pin(isPinned)
    self.pinned = isPinned == nil and true or isPinned
    return true
end

-- 设置是否允许回复
function SystemMail:AllowReply(canReply)
    self.can_reply = canReply == nil and true or canReply
    return true
end

-- 获取发送状态文本
function SystemMail:GetDeliveryStatusText()
    local statusTexts = {
        pending = "等待发送",
        processing = "发送中",
        completed = "发送完成",
        failed = "发送失败"
    }
    
    return statusTexts[self.delivery_status] or "未知状态"
end

-- 获取发送进度百分比
function SystemMail:GetDeliveryProgressPercent()
    if self.delivery_status == "pending" then
        return 0
    elseif self.delivery_status == "completed" then
        return 100
    elseif self.delivery_status == "processing" then
        local estimatedTotal = self:GetEstimatedRecipientCount()
        if estimatedTotal <= 0 then
            return 50 -- 默认进度
        end
        
        return math.min(100, math.floor(self.delivery_count / estimatedTotal * 100))
    end
    
    return 0
end

-- 重写获取邮件摘要信息，添加系统邮件特有信息
function SystemMail:GetSummary()
    local summary = MailBase.GetSummary(self)
    
    -- 添加系统邮件特有信息
    summary.target_type = self.target_type
    summary.recipient_count = #self.recipients
    summary.delivery_status = self.delivery_status
    summary.delivery_status_text = self:GetDeliveryStatusText()
    summary.delivery_progress = self:GetDeliveryProgressPercent()
    summary.pinned = self.pinned
    
    return summary
end

-- 重写序列化方法，添加系统邮件特有字段
function SystemMail:Serialize()
    local mailData = MailBase.Serialize(self)
    
    -- 添加系统邮件特有字段
    mailData.target_type = self.target_type
    mailData.recipients = self.recipients
    mailData.condition = self.condition
    mailData.delivery_status = self.delivery_status
    mailData.delivery_start_time = self.delivery_start_time
    mailData.delivery_complete_time = self.delivery_complete_time
    mailData.delivery_count = self.delivery_count
    mailData.delivery_failed_count = self.delivery_failed_count
    mailData.auto_delete = self.auto_delete
    mailData.pinned = self.pinned
    mailData.can_reply = self.can_reply
    
    return mailData
end

return SystemMail