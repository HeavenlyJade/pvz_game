--- 命令解析器 - 负责解析指令字符串
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class CommandParser
local CommandParser = {}

-- 定义命令解析模式
local ParseModes = {
    ["玩家"] = "PLAYER_FORMAT",   -- 玩家相关命令格式
    ["物品"] = "ITEM_FORMAT",     -- 物品相关命令格式
    ["任务"] = "QUEST_FORMAT",    -- 任务相关命令格式
}

-- 玩家命令格式解析器
function CommandParser:ParsePlayerCommand(commandStr)
    -- 使用多个空格分隔
    local parts = {}
    for part in commandStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 确保至少有三个部分："玩家"、subcategory 和 operation
    if #parts < 3 then
        return nil, nil, nil
    end
    
    local subcategory = parts[2]
    local operation = parts[3]
    
    -- 解析剩余参数
    local restParamsStr = table.concat(parts, " ", 4)
    local params = self:ParseValueParams(restParamsStr)
    params.subcategory = subcategory
    
    return "玩家", operation, params
end

-- 物品命令格式解析器
function CommandParser:ParseItemCommand(commandStr)
    -- 使用多个空格分隔
    local parts = {}
    for part in commandStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 确保至少有四个部分："物品"、itemType、itemId 和 operation
    if #parts < 4 then
        return nil, nil, nil
    end
    
    local itemType = parts[2]
    local itemId = parts[3]
    local operation = parts[4]
    
    -- 解析剩余参数
    local restParamsStr = table.concat(parts, " ", 5)
    local params = self:ParseValueParams(restParamsStr)
    params.subcategory = itemType
    params.id = itemId
    
    return "物品", operation, params
end

-- 任务命令格式解析器
function CommandParser:ParseQuestCommand(commandStr)
    -- 使用多个空格分隔
    local parts = {}
    for part in commandStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 确保至少有四个部分："任务"、questType、operation 和 questId
    if #parts < 4 then
        return nil, nil, nil
    end
    
    local questType = parts[2]
    local operation = parts[3]
    local questId = parts[4]
    
    -- 解析剩余参数
    local restParamsStr = table.concat(parts, " ", 5)
    local params = self:ParseQuestParams(restParamsStr)
    params.subcategory = questType
    params.id = questId
    
    return "任务", operation, params
end

-- 通用命令格式解析器（向后兼容）
function CommandParser:ParseGenericCommand(commandStr)
    -- 格式: "类别 操作 参数..."
    local pattern = "(%w+)%s+(%w+)%s+(.*)"
    local category, operation, restParams = commandStr:match(pattern)
    
    if not category or not operation then
        return nil, nil, nil
    end
    
    -- 解析剩余参数
    local params = self:ParseParams(restParams)
    
    return category, operation, params
end

-- 解析带有 = 符号的值参数
function CommandParser:ParseValueParams(paramsStr)
    local params = {}
    
    -- 解析 "参数 = 值" 格式
    local paramPart, value = paramsStr:match("(.-)%s*=%s*(.*)")
    
    if paramPart and value then
        -- 替换玩家占位符
        value = value:gsub("%%p", "")
        params.value = value
        
        -- 可能还有额外参数，继续解析
        local paramParts = {}
        for part in paramPart:gmatch("%S+") do
            table.insert(paramParts, part)
        end
        
        params.id = paramParts[1] or ""
        params.action = paramParts[2] or ""
        params.param = paramParts[3] or ""
    else
        params.id = paramsStr
        params.value = ""
    end
    
    return params
end

-- 解析任务特定参数
function CommandParser:ParseQuestParams(paramsStr)
    local params = {}
    
    -- 任务命令可能的格式：
    -- "目标 1 进度 = 5"
    -- "状态 = 进行中"
    -- "对话 进度 = 2"
    
    local targetPart, rest = paramsStr:match("目标%s+(%d+)%s+(.*)")
    if targetPart and rest then
        params.action = "目标"
        params.param = targetPart
        
        local progressPart, progressValue = rest:match("进度%s*=%s*(.*)")
        if progressPart and progressValue then
            params.value = progressValue:gsub("%%p", "")
        end
    else
        -- 其他格式
        local action, value = paramsStr:match("(%w+)%s*=%s*(.*)")
        if action and value then
            params.action = action
            params.value = value:gsub("%%p", "")
        else
            -- 解析其他可能的参数
            local parts = {}
            for part in paramsStr:gmatch("%S+") do
                table.insert(parts, part)
            end
            
            params.action = parts[1] or ""
            params.param = parts[2] or ""
            params.value = parts[3] or ""
        end
    end
    
    return params
end

-- 通用参数解析器（向后兼容）
function CommandParser:ParseParams(paramsStr)
    local params = {}
    local parts = {}
    
    -- 分割参数
    for part in paramsStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 参数结构根据需要调整
    params.target = parts[1] or ""
    params.subtype = parts[2] or ""
    params.id = parts[3] or ""
    params.action = parts[4] or ""
    params.value = parts[5] or ""
    
    return params
end

-- 解析指令字符串 - 主入口
function CommandParser:ParseCommand(commandStr, player)
    -- 获取命令开头的字符
    local firstWord = commandStr:match("^(%w+)")
    
    if not firstWord then
        return nil, nil, nil
    end
    
    -- 根据命令开头选择解析模式
    local parseMode = ParseModes[firstWord]
    
    if parseMode == "PLAYER_FORMAT" then
        return self:ParsePlayerCommand(commandStr)
    elseif parseMode == "ITEM_FORMAT" then
        return self:ParseItemCommand(commandStr)
    elseif parseMode == "QUEST_FORMAT" then
        return self:ParseQuestCommand(commandStr)
    else
        -- 使用通用格式解析器（向后兼容）
        return self:ParseGenericCommand(commandStr)
    end
end

return CommandParser