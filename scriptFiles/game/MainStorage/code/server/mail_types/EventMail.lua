--- V109 miniw-haima
--- 活动邮件类，继承自MailBase，用于游戏活动相关的邮件

local game = game
local pairs = pairs
local ipairs = ipairs
local table = table
local string = string
local os = os
local math = math

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig)   ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst)   ---@type MMailConst
local MMailUtils = require(MainStorage.code.common.MMail.MMailUtils)   ---@type MMailUtils
local MailBase = require(MainStorage.code.server.mail_types.MailBase)   ---@type MailBase
local CommonModule = require(MainStorage.code.common.CommonModule)   ---@type CommonModule

---@class EventMail: MailBase
local EventMail = CommonModule.Class("EventMail", MailBase)

-- 初始化活动邮件
function EventMail:OnInit(params)
    -- 调用父类初始化
    MailBase.OnInit(self, params)
    
    -- 设置默认类型为活动邮件
    self.type = MMailConfig.MAIL_TYPES.EVENT
    
    -- 活动邮件特有属性
    self.event_id = params.event_id or ""  -- 关联的活动ID
    self.event_name = params.event_name or ""  -- 活动名称
    self.template_id = params.template_id or ""  -- 模板ID
    self.stage_id = params.stage_id or ""  -- 活动阶段ID
    self.reward_type = params.reward_type or "participation"  -- 奖励类型（参与奖、排名奖、成就奖等）
    self.reward_rank = params.reward_rank or 0  -- 奖励排名
    self.reward_score = params.reward_score or 0  -- 奖励积分
    
    -- 活动时间属性
    self.event_start_time = params.event_start_time or 0
    self.event_end_time = params.event_end_time or 0
    
    -- 活动特殊内容
    self.special_content = params.special_content or {}  -- 特殊内容（活动详情、排行榜等）
    self.content_template = params.content_template or ""  -- 内容模板
    self.content_variables = params.content_variables or {}  -- 内容变量
    
    -- 活动邮件高级属性
    self.auto_claim = params.auto_claim or false  -- 是否自动领取附件
    self.limited_time = params.limited_time or false  -- 是否限时领取
    self.required_level = params.required_level or 0  -- 领取所需等级
    
    -- 发送者默认为活动系统
    if not self.sender or self.sender == "" then
        self.sender = MMailConst.PREDEFINED_SENDER.EVENT
    end
    
    -- 验证活动邮件特定参数
    self:ValidateEventMailParams()
    
    -- 如果有内容模板，生成内容
    if self.content_template ~= "" and next(self.content_variables) then
        self:GenerateContent()
    end
end

-- 验证活动邮件特定参数
function EventMail:ValidateEventMailParams()
    -- 验证活动ID
    if not self.event_id or self.event_id == "" then
        self.event_id = "unknown_event"
    end
    
    -- 验证奖励类型
    local validRewardTypes = {
        "participation", "achievement", "ranking", "milestone", "special"
    }
    
    local isValidType = false
    for _, rewardType in ipairs(validRewardTypes) do
        if self.reward_type == rewardType then
            isValidType = true
            break
        end
    end
    
    if not isValidType then
        self.reward_type = "participation"
    end
    
    -- 验证排名
    if self.reward_rank < 0 then
        self.reward_rank = 0
    end
    
    -- 验证时间
    local now = MMailUtils.getCurrentTimestamp()
    if self.event_start_time <= 0 then
        self.event_start_time = now
    end
    
    if self.event_end_time <= 0 or self.event_end_time < self.event_start_time then
        self.event_end_time = self.event_start_time + 7 * 24 * 3600  -- 默认活动持续7天
    end
    
    -- 验证所需等级
    if self.required_level < 0 then
        self.required_level = 0
    end
end

-- 生成邮件内容（根据模板和变量）
function EventMail:GenerateContent()
    if self.content_template == "" then
        return false
    end
    
    -- 替换模板变量
    self.content = MMailUtils.replaceTemplateVariables(self.content_template, self.content_variables)
    
    return true
end

-- 设置活动信息
function EventMail:SetEventInfo(eventId, eventName, startTime, endTime)
    self.event_id = eventId
    self.event_name = eventName
    
    if startTime and startTime > 0 then
        self.event_start_time = startTime
    end
    
    if endTime and endTime > 0 and endTime >= startTime then
        self.event_end_time = endTime
    end
    
    return true
end

-- 设置奖励信息
function EventMail:SetRewardInfo(rewardType, rank, score)
    local validRewardTypes = {
        "participation", "achievement", "ranking", "milestone", "special"
    }
    
    local isValidType = false
    for _, type in ipairs(validRewardTypes) do
        if rewardType == type then
            isValidType = true
            break
        end
    end
    
    if not isValidType then
        return false, "无效的奖励类型"
    end
    
    self.reward_type = rewardType
    
    if rank and rank >= 0 then
        self.reward_rank = rank
    end
    
    if score and score >= 0 then
        self.reward_score = score
    end
    
    return true
end

-- 设置特殊内容
function EventMail:SetSpecialContent(contentType, content)
    if not contentType or contentType == "" then
        return false, "内容类型不能为空"
    end
    
    self.special_content[contentType] = content
    return true
end

-- 获取特殊内容
function EventMail:GetSpecialContent(contentType)
    if not contentType or not self.special_content then
        return nil
    end
    
    return self.special_content[contentType]
end

-- 设置内容模板
function EventMail:SetContentTemplate(template, variables)
    if not template or template == "" then
        return false, "模板不能为空"
    end
    
    self.content_template = template
    
    if variables then
        self.content_variables = variables
    end
    
    -- 生成内容
    self:GenerateContent()
    
    return true
end

-- 添加内容变量
function EventMail:AddContentVariable(key, value)
    if not key or key == "" then
        return false, "变量名不能为空"
    end
    
    self.content_variables[key] = value
    
    -- 重新生成内容
    self:GenerateContent()
    
    return true
end

-- 检查玩家是否满足领取条件
function EventMail:CheckClaimRequirements(player)
    -- 检查等级要求
    if self.required_level > 0 and player.level < self.required_level then
        return false, "等级不足"
    end
    
    -- 检查限时领取
    if self.limited_time and MMailUtils.isExpired(self.event_end_time) then
        return false, "活动已结束，无法领取"
    end
    
    -- 检查活动状态
    if self:GetEventStatus() == "not_started" then
        return false, "活动尚未开始"
    end
    
    return true
end

-- 设置自动领取
function EventMail:SetAutoClaim(autoClaim)
    self.auto_claim = autoClaim == nil and true or autoClaim
    return true
end

-- 设置限时领取
function EventMail:SetLimitedTime(limitedTime)
    self.limited_time = limitedTime == nil and true or limitedTime
    return true
end

-- 设置领取所需等级
function EventMail:SetRequiredLevel(level)
    if level and level >= 0 then
        self.required_level = level
        return true
    end
    
    return false, "等级必须大于等于0"
end

-- 获取活动状态
function EventMail:GetEventStatus()
    local now = MMailUtils.getCurrentTimestamp()
    
    if now < self.event_start_time then
        return "not_started"
    elseif now >= self.event_start_time and now <= self.event_end_time then
        return "ongoing"
    else
        return "ended"
    end
end

-- 获取活动状态文本
function EventMail:GetEventStatusText()
    local status = self:GetEventStatus()
    
    local statusTexts = {
        not_started = "未开始",
        ongoing = "进行中",
        ended = "已结束"
    }
    
    return statusTexts[status] or "未知状态"
end

-- 获取奖励类型文本
function EventMail:GetRewardTypeText()
    local rewardTypeTexts = {
        participation = "参与奖励",
        achievement = "成就奖励",
        ranking = "排名奖励",
        milestone = "里程碑奖励",
        special = "特殊奖励"
    }
    
    return rewardTypeTexts[self.reward_type] or "未知类型"
end

-- 获取活动持续时间文本
function EventMail:GetEventDurationText()
    local startTime = MMailUtils.formatTime(self.event_start_time)
    local endTime = MMailUtils.formatTime(self.event_end_time)
    
    return startTime .. " 至 " .. endTime
end

-- 重写获取邮件摘要信息，添加活动邮件特有信息
function EventMail:GetSummary()
    local summary = MailBase.GetSummary(self)
    
    -- 添加活动邮件特有信息
    summary.event_id = self.event_id
    summary.event_name = self.event_name
    summary.event_status = self:GetEventStatus()
    summary.event_status_text = self:GetEventStatusText()
    summary.reward_type = self.reward_type
    summary.reward_type_text = self:GetRewardTypeText()
    summary.reward_rank = self.reward_rank
    summary.reward_score = self.reward_score
    summary.event_duration = self:GetEventDurationText()
    summary.required_level = self.required_level
    summary.auto_claim = self.auto_claim
    summary.limited_time = self.limited_time
    
    return summary
end

-- 重写序列化方法，添加活动邮件特有字段
function EventMail:Serialize()
    local mailData = MailBase.Serialize(self)
    
    -- 添加活动邮件特有字段
    mailData.event_id = self.event_id
    mailData.event_name = self.event_name
    mailData.template_id = self.template_id
    mailData.stage_id = self.stage_id
    mailData.reward_type = self.reward_type
    mailData.reward_rank = self.reward_rank
    mailData.reward_score = self.reward_score
    mailData.event_start_time = self.event_start_time
    mailData.event_end_time = self.event_end_time
    mailData.special_content = self.special_content
    mailData.content_template = self.content_template
    mailData.content_variables = self.content_variables
    mailData.auto_claim = self.auto_claim
    mailData.limited_time = self.limited_time
    mailData.required_level = self.required_level
    
    return mailData
end

return EventMail