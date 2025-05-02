--- V109 miniw-haima
--- 玩家邮件类，继承自MailBase，用于玩家之间的邮件通信

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

---@class PlayerMail: MailBase
local PlayerMail = CommonModule.Class("PlayerMail", MailBase)

-- 初始化玩家邮件
function PlayerMail:OnInit(params)
    -- 调用父类初始化
    MailBase.OnInit(self, params)
    
    -- 设置默认类型为玩家邮件
    self.type = MMailConfig.MAIL_TYPES.PLAYER
    
    -- 玩家邮件特有属性
    self.sender_name = params.sender_name or ""  -- 发送者名称
    self.sender_level = params.sender_level or 0  -- 发送者等级
    self.relation = params.relation or "none"  -- 与发送者的关系（好友、公会成员等）
    
    -- 物品交易相关属性
    self.trade_related = params.trade_related or false  -- 是否为交易相关邮件
    self.trade_id = params.trade_id  -- 关联的交易ID
    self.trade_status = params.trade_status  -- 交易状态
    self.gold_amount = params.gold_amount or 0  -- 附带的金币数量
    self.item_cost = params.item_cost or 0  -- 物品价格（如果是购买物品）
    
    -- 社交功能相关属性
    self.can_forward = params.can_forward or false  -- 是否可以转发
    self.can_reply = params.can_reply or true  -- 是否可以回复
    self.is_reply = params.is_reply or false  -- 是否是回复邮件
    self.reply_to = params.reply_to  -- 回复的邮件ID
    self.forward_count = params.forward_count or 0  -- 转发次数
    
    -- 额外社交功能
    self.emotions = params.emotions or {}  -- 情感标签（喜欢、生气等）
    self.is_read_receipt = params.is_read_receipt or false  -- 是否为已读回执
    
    -- 防刷保护
    self.cool_down_key = "player_mail_" .. (params.sender or "unknown")
    
    -- 验证玩家邮件特定参数
    self:ValidatePlayerMailParams()
end

-- 验证玩家邮件特定参数
function PlayerMail:ValidatePlayerMailParams()
    -- 验证金币数量
    if self.gold_amount < 0 then
        self.gold_amount = 0
    end
    
    -- 限制情感标签数量
    if #self.emotions > 5 then
        local limitedEmotions = {}
        for i = 1, 5 do
            limitedEmotions[i] = self.emotions[i]
        end
        self.emotions = limitedEmotions
    end
    
    -- 验证转发次数不为负
    if self.forward_count < 0 then
        self.forward_count = 0
    end
    
    -- 交易相关验证
    if self.trade_related and not self.trade_id then
        self.trade_related = false
    end
end

-- 回复邮件
function PlayerMail:CreateReply(content, attachments)
    -- 验证参数
    if not content or content == "" then
        return nil, "回复内容不能为空"
    end
    
    -- 检查冷却时间
    if not self:CheckSendCoolDown() then
        return nil, "发送过于频繁，请稍后再试"
    end
    
    -- 创建回复邮件
    local replyParams = {
        uuid = MMailUtils.generateMailUUID(),
        sender = self.receiver,  -- 当前接收者作为回复的发送者
        sender_type = MMailConst.SENDER_TYPE.PLAYER,
        receiver = self.sender,  -- 当前发送者作为回复的接收者
        title = "回复: " .. self.title,
        content = content,
        create_time = MMailUtils.getCurrentTimestamp(),
        attachments = attachments or {},
        type = MMailConfig.MAIL_TYPES.PLAYER,
        importance = MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        
        -- 玩家邮件特有属性
        sender_name = self.sender_name,  -- 需要在实际使用时替换为真实玩家名
        is_reply = true,
        reply_to = self.uuid
    }
    
    -- 获取当前玩家信息
    local player = gg.getPlayerByUin(self.receiver)
    if player then
        replyParams.sender_name = player.info.nickname
        replyParams.sender_level = player.level
    end
    
    -- 创建回复邮件实例
    local replyMail = PlayerMail.New(replyParams)
    
    -- 更新冷却时间
    self:UpdateSendCoolDown()
    
    return replyMail
end

-- 转发邮件
function PlayerMail:CreateForward(receiverUin, newContent, keepAttachments)
    -- 验证参数
    if not receiverUin then
        return nil, "接收者不能为空"
    end
    
    -- 检查是否允许转发
    if not self.can_forward then
        return nil, "该邮件不允许转发"
    end
    
    -- 检查冷却时间
    if not self:CheckSendCoolDown() then
        return nil, "发送过于频繁，请稍后再试"
    end
    
    -- 准备附件
    local forwardAttachments = {}
    if keepAttachments and self.attachments and not self.claimed then
        forwardAttachments = gg.table_value_copy(self.attachments)
    end
    
    -- 创建转发邮件内容
    local forwardContent = newContent or ""
    if forwardContent ~= "" then
        forwardContent = forwardContent .. "\n\n"
    end
    forwardContent = forwardContent .. "---------- 转发邮件 ----------\n"
    forwardContent = forwardContent .. "发送者: " .. self.sender_name .. "\n"
    forwardContent = forwardContent .. "时间: " .. MMailUtils.formatTime(self.create_time) .. "\n"
    forwardContent = forwardContent .. "内容:\n" .. self.content
    
    -- 创建转发邮件
    local forwardParams = {
        uuid = MMailUtils.generateMailUUID(),
        sender = self.receiver,  -- 当前接收者作为转发的发送者
        sender_type = MMailConst.SENDER_TYPE.PLAYER,
        receiver = receiverUin,
        title = "转发: " .. self.title,
        content = forwardContent,
        create_time = MMailUtils.getCurrentTimestamp(),
        attachments = forwardAttachments,
        type = MMailConfig.MAIL_TYPES.PLAYER,
        importance = self.importance,
        
        -- 玩家邮件特有属性
        sender_name = "",  -- 需要在实际使用时替换为真实玩家名
        can_forward = true,
        forward_count = self.forward_count + 1
    }
    
    -- 获取当前玩家信息
    local player = gg.getPlayerByUin(self.receiver)
    if player then
        forwardParams.sender_name = player.info.nickname
        forwardParams.sender_level = player.level
    end
    
    -- 创建转发邮件实例
    local forwardMail = PlayerMail.New(forwardParams)
    
    -- 更新冷却时间
    self:UpdateSendCoolDown()
    
    return forwardMail
end

-- 添加情感标签
function PlayerMail:AddEmotion(emotion)
    if not emotion or emotion == "" then
        return false, "情感标签不能为空"
    end
    
    -- 检查是否已存在
    for _, existingEmotion in ipairs(self.emotions) do
        if existingEmotion.type == emotion then
            return false, "情感标签已存在"
        end
    end
    
    -- 检查标签数量限制
    if #self.emotions >= 5 then
        return false, "情感标签数量已达上限"
    end
    
    -- 添加情感标签
    table.insert(self.emotions, {
        type = emotion,
        time = MMailUtils.getCurrentTimestamp(),
        player = self.receiver
    })
    
    return true
end

-- 移除情感标签
function PlayerMail:RemoveEmotion(emotion)
    if not emotion or emotion == "" or not self.emotions or #self.emotions == 0 then
        return false, "情感标签不存在"
    end
    
    for i, existingEmotion in ipairs(self.emotions) do
        if existingEmotion.type == emotion and existingEmotion.player == self.receiver then
            table.remove(self.emotions, i)
            return true
        end
    end
    
    return false, "情感标签不存在"
end

-- 获取情感标签统计
function PlayerMail:GetEmotionStats()
    local stats = {}
    
    if not self.emotions or #self.emotions == 0 then
        return stats
    end
    
    for _, emotion in ipairs(self.emotions) do
        stats[emotion.type] = (stats[emotion.type] or 0) + 1
    end
    
    return stats
end

-- 设置交易相关信息
function PlayerMail:SetTradeInfo(tradeId, status, goldAmount, itemCost)
    self.trade_related = true
    self.trade_id = tradeId
    self.trade_status = status
    
    if goldAmount then
        self.gold_amount = goldAmount
    end
    
    if itemCost then
        self.item_cost = itemCost
    end
    
    return true
end

-- 检查发送冷却时间
function PlayerMail:CheckSendCoolDown()
    local cooldownTime = MMailConst.SEND_COOLDOWN.PLAYER
    local now = MMailUtils.getCurrentTimestamp()
    
    -- 检查冷却时间
    local lastSendTime = gg.server_data and gg.server_data.mail_cooldowns and gg.server_data.mail_cooldowns[self.cool_down_key] or 0
    
    if now - lastSendTime < cooldownTime then
        return false
    end
    
    return true
end

-- 更新发送冷却时间
function PlayerMail:UpdateSendCoolDown()
    local now = MMailUtils.getCurrentTimestamp()
    
    -- 初始化冷却时间存储
    if not gg.server_data then gg.server_data = {} end
    if not gg.server_data.mail_cooldowns then gg.server_data.mail_cooldowns = {} end
    
    -- 更新冷却时间
    gg.server_data.mail_cooldowns[self.cool_down_key] = now
    
    return true
end

-- 创建已读回执
function PlayerMail:CreateReadReceipt()
    -- 检查是否需要已读回执
    if not self.request_read_receipt then
        return nil
    end
    
    -- 创建回执邮件
    local receiptParams = {
        uuid = MMailUtils.generateMailUUID(),
        sender = self.receiver,
        sender_type = MMailConst.SENDER_TYPE.PLAYER,
        receiver = self.sender,
        title = "已读回执: " .. self.title,
        content = "您发送给 " .. self.receiver .. " 的邮件已被阅读。\n\n邮件标题: " .. self.title .. "\n阅读时间: " .. MMailUtils.formatTime(MMailUtils.getCurrentTimestamp()),
        create_time = MMailUtils.getCurrentTimestamp(),
        type = MMailConfig.MAIL_TYPES.PLAYER,
        importance = MMailConfig.IMPORTANCE_LEVEL.LOW,
        
        -- 玩家邮件特有属性
        is_read_receipt = true,
        can_reply = false,
        can_forward = false
    }
    
    -- 获取当前玩家信息
    local player = gg.getPlayerByUin(self.receiver)
    if player then
        receiptParams.sender_name = player.info.nickname
    end
    
    -- 创建回执邮件实例
    local receiptMail = PlayerMail.New(receiptParams)
    
    return receiptMail
end

-- 重写获取邮件摘要信息，添加玩家邮件特有信息
function PlayerMail:GetSummary()
    local summary = MailBase.GetSummary(self)
    
    -- 添加玩家邮件特有信息
    summary.sender_name = self.sender_name
    summary.sender_level = self.sender_level
    summary.relation = self.relation
    summary.is_reply = self.is_reply
    summary.trade_related = self.trade_related
    summary.emotions = self:GetEmotionStats()
    summary.can_reply = self.can_reply
    summary.can_forward = self.can_forward
    
    return summary
end

-- 重写序列化方法，添加玩家邮件特有字段
function PlayerMail:Serialize()
    local mailData = MailBase.Serialize(self)
    
    -- 添加玩家邮件特有字段
    mailData.sender_name = self.sender_name
    mailData.sender_level = self.sender_level
    mailData.relation = self.relation
    mailData.trade_related = self.trade_related
    mailData.trade_id = self.trade_id
    mailData.trade_status = self.trade_status
    mailData.gold_amount = self.gold_amount
    mailData.item_cost = self.item_cost
    mailData.can_forward = self.can_forward
    mailData.can_reply = self.can_reply
    mailData.is_reply = self.is_reply
    mailData.reply_to = self.reply_to
    mailData.forward_count = self.forward_count
    mailData.emotions = self.emotions
    mailData.is_read_receipt = self.is_read_receipt
    
    return mailData
end

return PlayerMail