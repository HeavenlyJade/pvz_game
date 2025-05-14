
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
-- local CommandParser = require(MainStorage.code.server.CommandSystem.parsers.MCommandParser)  ---@type CommandParser
-- local ConditionParser = require(MainStorage.code.server.CommandSystem.parsers.MConditionParser) ---@type ConditionParser
local ItemCommands = require(MainStorage.code.server.CommandSystem.commands.MItemCommands)   ---@type ItemCommands
local MiscCommands = require(MainStorage.code.server.CommandSystem.commands.MiscCommand)   ---@type MiscCommand
local MobCommand = require(MainStorage.code.server.CommandSystem.commands.MobCommand)   ---@type MobCommand
local SpellCommand = require(MainStorage.code.server.CommandSystem.commands.SpellCommand)   ---@type SpellCommand
-- local QuestCommands = require(MainStorage.code.server.CommandSystem.commands.MQuestCommands)     ---@type QuestCommands
-- local PlayerCommands = require(MainStorage.code.server.CommandSystem.commands.MPlayerCommands)   ---@type PlayerCommands
-- local SkillCommands = require(MainStorage.code.server.CommandSystem.commands.MSkillCommands)     ---@type SkillCommands
-- local SystemCommands = require(MainStorage.code.server.CommandSystem.commands.MSystemCommands)   ---@type SystemCommands
local json = require(MainStorage.code.common.json)
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager


---@class CommandManager
local CommandManager = {}

-- 所有指令处理器 (使用多级嵌套结构)
CommandManager.handlers = {
    -- 物品相关
    ["give"] = ItemCommands.give,
    ["invsee"] = ItemCommands.invsee,
    ["clear"] = ItemCommands.clear,
    ["title"] = MiscCommands.title,
    ["spawnMob"] = MobCommand.spawnMob,
    ["cast"] = SpellCommand.cast,
    -- ["装备"] = {},

    -- -- 玩家属性相关
    -- ["等级"] = {},
    -- ["经验"] = {},
    -- ["属性"] = {},
    -- ["金币"] = {},
    -- ["声望"] = {},

    -- -- 任务相关
    -- ["任务"] = {},

    -- -- 技能相关
    -- ["技能"] = {},
    -- ["武魂"] = {},

    -- -- 系统相关
    -- ["事件"] = {},
    -- ["地图"] = {}
}

ServerEventManager.Subscribe("ClientExecuteCommand", function(evt)
    CommandManager.ExecuteCommand(evt.command, evt.player)
end)

function CommandManager.ExecuteCommand(commandStr, player)
    if not commandStr then return false end

    -- 1. 分割命令和参数
    local command, jsonStr = commandStr:match("^(%S+)%s+(.+)$")
    if not command then
        gg.log("命令格式错误: " .. commandStr)
        return false
    end

    -- 2. 查找命令处理器
    local handler = CommandManager.handlers[command]
    if not handler then
        gg.log("未知命令: " .. command)
        return false
    end

    -- 3. 解析JSON参数
    local params = json.decode(jsonStr)
    if params["玩家"] then
        player = gg.getLivingByName(params["玩家"])
        if not player then
            gg.log("玩家不存在: " .. params["玩家"])
            return false
        end
    end
    gg.log("执行指令", command, params)
    -- 5. 调用处理器
    local success, result = pcall(handler, params, player)
    if not success then
        gg.log("命令执行错误: " .. command .. ", " .. tostring(result))
        return false
    end

    return result
end

-- 命令模块映射
-- CommandManager.moduleMap = {
--     -- 物品相关指令映射到物品命令模块
--     ["物品"] = ItemCommands,
--     ["装备"] = ItemCommands,

--     -- 玩家属性相关指令映射到玩家命令模块
--     ["等级"] = PlayerCommands,
--     ["经验"] = PlayerCommands,
--     ["属性"] = PlayerCommands,
--     ["金币"] = PlayerCommands,
--     ["声望"] = PlayerCommands,

--     -- 任务相关指令映射到任务命令模块
--     ["任务"] = QuestCommands,

--     -- 技能相关指令映射到技能命令模块
--     ["技能"] = SkillCommands,
--     ["武魂"] = SkillCommands,

--     -- 系统相关指令映射到系统命令模块
--     ["事件"] = SystemCommands,
--     ["地图"] = SystemCommands
-- }

-- 初始化命令管理器
-- function CommandManager:Init()
--     -- 遍历所有模块映射，注册对应的处理器
--     for category, module in pairs(self.moduleMap) do
--         if module.handlers then
--             self:RegisterHandlers(category, module.handlers)
--         end
--     end

--     -- 注册条件解析器
--     self.conditionParser = ConditionParser

--     gg.log("命令系统初始化完成")
--     return self
-- end

-- -- 注册命令处理器
-- function CommandManager:RegisterHandlers(category, handlers)
--     if not self.handlers[category] then
--         self.handlers[category] = {}
--     end

--     for operation, handler in pairs(handlers) do
--         if self.handlers[category][operation] then
--             gg.log("警告: 操作'" .. category .. "." .. operation .. "'已存在，将被覆盖")
--         end
--         self.handlers[category][operation] = handler
--     end
-- end

-- 执行命令
-- function CommandManager:ExecuteCommand(commandStr, player)
--     -- 检查条件命令
--     if string.find(commandStr, "如果") then
--         local condition, command = commandStr:match("如果%s+(.-)%s+则%s+(.*)")
--         if condition and command then
--             local conditionResult = self.conditionParser:EvaluateCondition(condition, player)
--             if conditionResult then
--                 return self:ExecuteCommand(command, player)
--             else
--                 return true -- 条件不满足，命令视为执行成功但无效果
--             end
--         else
--             gg.log("条件命令格式错误: " .. commandStr)
--             return false
--         end
--     end

--     -- 解析普通命令
--     local category, operation, params = CommandParser:ParseCommand(commandStr, player)
--     if not category or not operation then
--         gg.log("命令解析失败: " .. commandStr)
--         return false
--     end

--     -- 执行对应的处理器
--     if self.handlers[category] and self.handlers[category][operation] then
--         local handler = self.handlers[category][operation]
--         local success, result = pcall(handler, params, player)
--         if not success then
--             gg.log("命令执行错误: " .. category .. "." .. operation .. ", " .. tostring(result))
--             return false
--         end
--         return result
--     else
--         -- 尝试使用模块映射找到处理器
--         local module = self.moduleMap[category]
--         if module and module.Execute then
--             local success, result = pcall(module.Execute, operation, params, player)
--             if not success then
--                 gg.log("命令执行错误: " .. category .. "." .. operation .. ", " .. tostring(result))
--                 return false
--             end
--             return result
--         else
--             gg.log("未知操作: " .. category .. "." .. operation)
--             return false
--         end
--     end
-- end

-- -- 批量执行命令
-- function CommandManager:ProcessCommands(commands, player)
--     if not commands then return true end

--     local allSuccess = true
--     for _, command in ipairs(commands) do
--         -- 替换%p为玩家ID
--         command = command:gsub("%%p", player.uin or "")

--         local success = self:ExecuteCommand(command, player)
--         if not success then
--             allSuccess = false
--             gg.log("命令执行失败: " .. command)
--         end
--     end

--     return allSuccess
-- end

-- -- 处理任务奖励
-- function CommandManager:ProcessRewards(rewards, player)
--     return self:ProcessCommands(rewards, player)
-- end

return CommandManager
