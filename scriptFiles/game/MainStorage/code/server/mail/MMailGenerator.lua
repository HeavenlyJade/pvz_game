--- V109 miniw-haima
--- 邮件生成器，负责生成各类邮件内容和模板

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

---@class MMailGenerator
local MMailGenerator = {
    -- 注册的模板生成器
    templateGenerators = {},
    
    -- 内置模板缓存
    templateCache = {},
    
    -- 变量处理器
    variableProcessors = {},
    
    -- 上下文变量
    contextVariables = {}
}

-- 初始化邮件生成器
function MMailGenerator:Init()
    -- 注册内置模板生成器
    self:RegisterBuiltinTemplates()
    
    -- 注册变量处理器
    self:RegisterVariableProcessors()
    
    gg.log("邮件生成器初始化完成")
    return self
end

---------------------------
-- 模板注册与管理
---------------------------

-- 注册内置模板
function MMailGenerator:RegisterBuiltinTemplates()
    -- 注册欢迎邮件模板生成器
    self:RegisterTemplateGenerator("welcome", function(variables)
        return {
            title = "欢迎来到游戏",
            content = self:GenerateWelcomeContent(variables),
            attachments = self:GenerateWelcomeAttachments(variables),
            importance = MMailConfig.IMPORTANCE_LEVEL.HIGH
        }
    end)
    
    -- 注册维护公告模板生成器
    self:RegisterTemplateGenerator("maintenance", function(variables)
        return {
            title = "服务器维护通知",
            content = self:GenerateMaintenanceContent(variables),
            attachments = self:GenerateMaintenanceAttachments(variables),
            importance = MMailConfig.IMPORTANCE_LEVEL.URGENT
        }
    end)
    
    -- 注册等级奖励模板生成器
    self:RegisterTemplateGenerator("level_reward", function(variables)
        return {
            title = "等级提升奖励",
            content = self:GenerateLevelRewardContent(variables),
            attachments = self:GenerateLevelRewardAttachments(variables),
            importance = MMailConfig.IMPORTANCE_LEVEL.NORMAL
        }
    end)
    
    -- 注册活动奖励模板生成器
    self:RegisterTemplateGenerator("event_reward", function(variables)
        return {
            title = variables.event_name .. "活动奖励",
            content = self:GenerateEventRewardContent(variables),
            attachments = variables.rewards,
            importance = MMailConfig.IMPORTANCE_LEVEL.HIGH
        }
    end)
    
    -- 注册系统公告模板生成器
    self:RegisterTemplateGenerator("system_notice", function(variables)
        return {
            title = variables.title or "系统公告",
            content = variables.content or "这是一条系统公告。",
            attachments = variables.attachments or {},
            importance = variables.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL
        }
    end)
    
    -- 注册节日祝福模板生成器
    self:RegisterTemplateGenerator("festival_greeting", function(variables)
        return {
            title = variables.festival_name .. "节日祝福",
            content = self:GenerateFestivalContent(variables),
            attachments = self:GenerateFestivalAttachments(variables),
            importance = MMailConfig.IMPORTANCE_LEVEL.NORMAL
        }
    end)
    
    -- 注册版本更新模板生成器
    self:RegisterTemplateGenerator("version_update", function(variables)
        return {
            title = "游戏更新公告：v" .. variables.version,
            content = self:GenerateVersionUpdateContent(variables),
            attachments = self:GenerateVersionUpdateAttachments(variables),
            importance = MMailConfig.IMPORTANCE_LEVEL.HIGH
        }
    end)
    
    -- 注册任务奖励模板生成器
    self:RegisterTemplateGenerator("quest_reward", function(variables)
        return {
            title = "任务奖励：" .. variables.quest_name,
            content = self:GenerateQuestRewardContent(variables),
            attachments = variables.rewards,
            importance = MMailConfig.IMPORTANCE_LEVEL.NORMAL
        }
    end)
    
    -- 注册成就奖励模板生成器
    self:RegisterTemplateGenerator("achievement_reward", function(variables)
        return {
            title = "成就达成：" .. variables.achievement_name,
            content = self:GenerateAchievementContent(variables),
            attachments = variables.rewards,
            importance = MMailConfig.IMPORTANCE_LEVEL.HIGH
        }
    end)
    
    -- 注册补偿邮件模板生成器
    self:RegisterTemplateGenerator("compensation", function(variables)
        return {
            title = variables.title or "游戏补偿",
            content = self:GenerateCompensationContent(variables),
            attachments = variables.items,
            importance = MMailConfig.IMPORTANCE_LEVEL.HIGH
        }
    end)
end

-- 注册变量处理器
function MMailGenerator:RegisterVariableProcessors()
    -- 玩家名称处理器
    self:RegisterVariableProcessor("player_name", function(value, context)
        if not value or value == "" then
            local player = gg.getPlayerByUin(context.player_uin)
            return player and player.info and player.info.nickname or "冒险者"
        end
        return value
    end)
    
    -- 当前日期处理器
    self:RegisterVariableProcessor("current_date", function(value, context)
        return os.date("%Y年%m月%d日")
    end)
    
    -- 游戏时间处理器
    self:RegisterVariableProcessor("game_time", function(value, context)
        -- 可以实现游戏内时间的处理逻辑
        return "游戏时间"
    end)
    
    -- 服务器名称处理器
    self:RegisterVariableProcessor("server_name", function(value, context)
        -- 可以获取服务器名称
        return value or "主服务器"
    end)
    
    -- 金币格式化处理器
    self:RegisterVariableProcessor("format_gold", function(value, context)
        local gold = tonumber(value) or 0
        return self:FormatNumber(gold) .. " 金币"
    end)
    
    -- 时间格式化处理器
    self:RegisterVariableProcessor("format_time", function(value, context)
        local timestamp = tonumber(value) or os.time()
        return os.date("%Y-%m-%d %H:%M:%S", timestamp)
    end)
    
    -- 倒计时格式化处理器
    self:RegisterVariableProcessor("format_countdown", function(value, context)
        local seconds = tonumber(value) or 0
        return self:FormatTimeInterval(seconds)
    end)
end

-- 注册模板生成器
function MMailGenerator:RegisterTemplateGenerator(templateId, generatorFunc)
    if not templateId or not generatorFunc then
        gg.log("注册模板生成器失败：参数错误")
        return false
    end
    
    self.templateGenerators[templateId] = generatorFunc
    return true
end

-- 注册变量处理器
function MMailGenerator:RegisterVariableProcessor(variableName, processorFunc)
    if not variableName or not processorFunc then
        gg.log("注册变量处理器失败：参数错误")
        return false
    end
    
    self.variableProcessors[variableName] = processorFunc
    return true
end

---------------------------
-- 模板生成方法
---------------------------

-- 生成邮件
function MMailGenerator:GenerateMail(templateId, variables, options)
    -- 检查模板是否存在
    local generator = self.templateGenerators[templateId]
    if not generator then
        gg.log("生成邮件失败：模板不存在: " .. tostring(templateId))
        return nil
    end
    
    -- 合并上下文变量
    local context = self:CreateContext(variables, options)
    
    -- 处理变量
    local processedVariables = self:ProcessVariables(variables, context)
    
    -- 生成邮件内容
    local template = generator(processedVariables)
    if not template then
        gg.log("生成邮件失败：模板生成返回空")
        return nil
    end
    
    -- 处理选项
    options = options or {}
    
    -- 创建邮件对象
    local mail = {
        uuid = MMailUtils.generateMailUUID(),
        sender = options.sender or MMailConst.PREDEFINED_SENDER.SYSTEM,
        sender_type = options.senderType or MMailConst.SENDER_TYPE.SYSTEM,
        title = template.title,
        content = template.content,
        create_time = MMailUtils.getCurrentTimestamp(),
        expire_time = options.expire_time or MMailUtils.calculateExpiryTime(
            options.mailType or MMailConfig.MAIL_TYPES.SYSTEM, 
            template.attachments and #template.attachments > 0, 
            false
        ),
        attachments = template.attachments or {},
        type = options.mailType or MMailConfig.MAIL_TYPES.SYSTEM,
        category = options.category or options.mailType or MMailConfig.MAIL_TYPES.SYSTEM,
        importance = template.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        target_type = options.targetType or MMailConst.TARGET_TYPE.SINGLE,
        recipients = options.recipients,
        template_id = templateId,
        variables = variables
    }
    
    -- 如果有接收者，设置接收者
    if options.receiver then
        mail.receiver = options.receiver
    end
    
    return mail
end

-- 创建上下文
function MMailGenerator:CreateContext(variables, options)
    local context = {}
    
    -- 合并上下文变量
    for key, value in pairs(self.contextVariables) do
        context[key] = value
    end
    
    -- 合并传入的变量
    if variables then
        for key, value in pairs(variables) do
            context[key] = value
        end
    end
    
    -- 合并选项
    if options then
        for key, value in pairs(options) do
            if context[key] == nil then
                context[key] = value
            end
        end
    end
    
    return context
end

-- 处理变量
function MMailGenerator:ProcessVariables(variables, context)
    if not variables then return {} end
    
    local result = {}
    
    for key, value in pairs(variables) do
        -- 检查是否有对应的处理器
        local processor = self.variableProcessors[key]
        if processor then
            result[key] = processor(value, context)
        else
            result[key] = value
        end
    end
    
    return result
end

---------------------------
-- 模板内容生成方法
---------------------------

-- 生成欢迎邮件内容
function MMailGenerator:GenerateWelcomeContent(variables)
    local playerName = variables.player_name or "冒险者"
    
    local content = string.format([[
亲爱的%s：

欢迎来到我们的游戏世界！

在这里，你将开启一段充满冒险与挑战的旅程。作为对你加入的感谢，我们为你准备了一些初始道具，希望能对你的冒险之旅有所帮助。

祝你游戏愉快！

——游戏团队
]], playerName)

    return content
end

-- 生成欢迎邮件附件
function MMailGenerator:GenerateWelcomeAttachments(variables)
    return {
        { type = 2, id = 1001, quantity = 100, name = "魔力碎片" },  -- 魔力碎片
        { type = 4, id = "gold_coin", quantity = 1000, name = "金币" }  -- 金币
    }
end

-- 生成维护公告内容
function MMailGenerator:GenerateMaintenanceContent(variables)
    local time = variables.time or "近期"
    local duration = variables.duration or "数小时"
    
    local content = string.format([[
亲爱的玩家：

我们将于%s进行服务器维护，预计持续%s。维护期间无法登录游戏，请您提前做好准备。

维护内容：
1. 修复游戏中的已知问题
2. 优化游戏性能
3. 更新部分游戏内容

为了感谢您的理解与支持，我们在维护结束后为您准备了一些补偿物品，请注意查收。

——游戏运营团队
]], time, duration)

    return content
end

-- 生成维护公告附件
function MMailGenerator:GenerateMaintenanceAttachments(variables)
    local duration = tonumber(string.match(variables.duration or "0", "%d+")) or 0
    local compensationAmount = math.max(50, duration * 10)  -- 根据维护时长计算补偿
    
    return {
        { type = 4, id = "gold_coin", quantity = compensationAmount * 10, name = "金币" },  -- 金币
        { type = 3, id = 2001, quantity = 5, name = "恢复药剂" }  -- 恢复药剂
    }
end

-- 生成等级奖励内容
function MMailGenerator:GenerateLevelRewardContent(variables)
    local playerName = variables.player_name or "冒险者"
    local level = variables.level or 0
    
    local content = string.format([[
恭喜%s达到%d级！

随着等级的提升，你将解锁更多游戏功能和挑战。作为达到这一里程碑的奖励，特别为你准备了一些道具。

继续努力，更多精彩等着你！

——游戏团队
]], playerName, level)

    return content
end

-- 生成等级奖励附件
function MMailGenerator:GenerateLevelRewardAttachments(variables)
    local level = variables.level or 0
    
    local attachments = {
        { type = 4, id = "gold_coin", quantity = level * 100, name = "金币" },  -- 金币
        { type = 2, id = 1001, quantity = level * 10, name = "魔力碎片" }  -- 魔力碎片
    }
    
    -- 特殊等级额外奖励
    if level >= 10 and level % 10 == 0 then
        table.insert(attachments, { type = 3, id = 2001, quantity = level / 10, name = "恢复药剂" })  -- 恢复药剂
    end
    
    -- 重要等级里程碑奖励
    if level == 20 then
        table.insert(attachments, { type = 1, id = "eq_5", quantity = 1, name = "星海神秘头盔" })  -- 装备
    elseif level == 30 then
        table.insert(attachments, { type = 1, id = "we_1", quantity = 1, name = "星海神秘之刃" })  -- 武器
    end
    
    return attachments
end

-- 生成活动奖励内容
function MMailGenerator:GenerateEventRewardContent(variables)
    local playerName = variables.player_name or "冒险者"
    local eventName = variables.event_name or "游戏活动"
    local rank = variables.rank or "参与者"
    
    local content = string.format([[
亲爱的%s：

感谢你参与"%s"活动！

根据你在活动中的表现，你获得了"%s"评级。以下是你的活动奖励，请查收。

期待你在下次活动中的精彩表现！

——活动组委会
]], playerName, eventName, rank)

    return content
end

-- 生成节日内容
function MMailGenerator:GenerateFestivalContent(variables)
    local playerName = variables.player_name or "冒险者"
    local festivalName = variables.festival_name or "春节"
    
    local content = string.format([[
亲爱的%s：

值此%s来临之际，游戏团队向您致以诚挚的节日祝福！

为庆祝这个特殊的日子，我们为您准备了一份节日礼物，希望能为您的游戏体验增添一份欢乐。

祝您节日快乐，游戏愉快！

——游戏团队
]], playerName, festivalName)

    return content
end

-- 生成节日附件
function MMailGenerator:GenerateFestivalAttachments(variables)
    local festivalName = variables.festival_name or "春节"
    
    local attachments = {
        { type = 4, id = "gold_coin", quantity = 888, name = "金币" }  -- 金币
    }
    
    -- 不同节日不同奖励
    if festivalName == "春节" then
        table.insert(attachments, { type = 2, id = 1001, quantity = 88, name = "魔力碎片" })  -- 魔力碎片
    elseif festivalName == "中秋节" then
        table.insert(attachments, { type = 3, id = 2001, quantity = 8, name = "恢复药剂" })  -- 恢复药剂
    end
    
    return attachments
end

-- 生成版本更新内容
function MMailGenerator:GenerateVersionUpdateContent(variables)
    local version = variables.version or "1.0.0"
    local updateDesc = variables.update_desc or "修复了一些已知问题。"
    
    local content = string.format([[
亲爱的玩家：

游戏已更新至v%s版本！

更新内容：
%s

为感谢您对游戏的支持，我们准备了一些更新补偿礼包，请查收。

——游戏开发团队
]], version, updateDesc)

    return content
end

-- 生成版本更新附件
function MMailGenerator:GenerateVersionUpdateAttachments(variables)
    local version = variables.version or "1.0.0"
    
    -- 提取版本号主要部分
    local major, minor = string.match(version, "(%d+)%.(%d+)")
    major, minor = tonumber(major) or 1, tonumber(minor) or 0
    
    local attachments = {}
    
    -- 主版本更新奖励更丰厚
    if minor == 0 then
        table.insert(attachments, { type = 4, id = "gold_coin", quantity = 5000, name = "金币" })  -- 金币
        table.insert(attachments, { type = 2, id = 1001, quantity = 500, name = "魔力碎片" })  -- 魔力碎片
    else
        table.insert(attachments, { type = 4, id = "gold_coin", quantity = 1000, name = "金币" })  -- 金币
        table.insert(attachments, { type = 2, id = 1001, quantity = 100, name = "魔力碎片" })  -- 魔力碎片
    end
    
    return attachments
end

-- 生成任务奖励内容
function MMailGenerator:GenerateQuestRewardContent(variables)
    local playerName = variables.player_name or "冒险者"
    local questName = variables.quest_name or "每日任务"
    
    local content = string.format([[
亲爱的%s：

恭喜你完成了"%s"任务！

以下是你的任务奖励，请查收。

——任务系统
]], playerName, questName)

    return content
end

-- 生成成就内容
function MMailGenerator:GenerateAchievementContent(variables)
    local playerName = variables.player_name or "冒险者"
    local achievementName = variables.achievement_name or "游戏成就"
    local achievementDesc = variables.achievement_desc or "一项珍贵的成就"
    
    local content = string.format([[
亲爱的%s：

恭喜你达成了"%s"成就！

%s

这是一项值得纪念的成就，为了表彰你的努力，特送上以下奖励：

——成就系统
]], playerName, achievementName, achievementDesc)

    return content
end

-- 生成补偿内容
function MMailGenerator:GenerateCompensationContent(variables)
    local reason = variables.reason or "游戏异常"
    local dateStr = variables.date or os.date("%Y年%m月%d日")
    
    local content = string.format([[
亲爱的玩家：

关于%s在%s期间出现的%s问题，我们已经修复。为表歉意，特向您发放以下补偿物品，感谢您的理解与支持。

——游戏团队
]], variables.game_name or "游戏", dateStr, reason)

    return content
end

---------------------------
-- 辅助方法
---------------------------

-- 设置上下文变量
function MMailGenerator:SetContextVariable(key, value)
    self.contextVariables[key] = value
end

-- 获取上下文变量
function MMailGenerator:GetContextVariable(key)
    return self.contextVariables[key]
end

-- 清除上下文变量
function MMailGenerator:ClearContextVariables()
    self.contextVariables = {}
end

-- 格式化数字（千分位分隔）
function MMailGenerator:FormatNumber(number)
    local formatted = tostring(number)
    local k = #formatted % 3
    
    if k == 0 then k = 3 end
    
    local result = string.sub(formatted, 1, k)
    for i = k + 1, #formatted, 3 do
        result = result .. "," .. string.sub(formatted, i, i + 2)
    end
    
    return result
end

-- 格式化时间间隔
function MMailGenerator:FormatTimeInterval(seconds)
    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    
    local result = ""
    
    if days > 0 then
        result = days .. "天"
    end
    
    if hours > 0 or days > 0 then
        result = result .. hours .. "小时"
    end
    
    if minutes > 0 or hours > 0 or days > 0 then
        result = result .. minutes .. "分钟"
    end
    
    result = result .. seconds .. "秒"
    
    return result
end

-- 获取可用的模板ID列表
function MMailGenerator:GetAvailableTemplates()
    local templates = {}
    
    for templateId, _ in pairs(self.templateGenerators) do
        table.insert(templates, templateId)
    end
    
    return templates
end

-- 检查模板是否存在
function MMailGenerator:IsTemplateExists(templateId)
    return self.templateGenerators[templateId] ~= nil
end

-- 导出接口
return MMailGenerator:Init()