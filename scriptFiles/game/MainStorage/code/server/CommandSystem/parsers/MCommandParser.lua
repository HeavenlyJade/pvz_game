--- 命令解析器 - 负责解析指令字符串
--- V109 miniw-haima


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
    -- "玩家 等级 设置 %p 10"    
    local parts = {}
    for part in commandStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 确保至少有三个部分："玩家"、subcategory 和 operation
    if #parts < 3 then
        return nil, nil, nil
    end
    
    local params = {}
    params.cmd_type = parts[1]
    params.subcategory =  parts[2]
    params.operation =  parts[3]
    params.obj = parts[4]
    params.num = parts[5]
    return "玩家",parts[3], params
end

-- 物品命令格式解析器
function CommandParser:ParseItemCommand(commandStr)
    -- 使用多个空格分隔
    -- "物品 装备 增加 1001 数量 %p 1"           
    local parts = {}
    for part in commandStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 确保至少有基本的部分："物品"和物品类型
    if #parts < 2 then
        return nil, nil, nil
    end
    
    local params = {}
    params.cmd_type = parts[1]    -- "物品"
    params.subcategory = parts[2]  -- 物品类型(装备/消耗品/材料/任务物品)
    
    -- 根据命令格式解析剩余参数
    if #parts >= 3 then
        params.operation = parts[3]  -- 操作(增加/减少/设置/强化)
    end
    -- 获取物品ID (可能在不同位置)
    if #parts >= 4 then
        params.id = parts[4]  -- 物品ID
    end
    params.attr_type = parts[5]
    params.obj = parts[6]
    params.num = parts[7]
    return "物品",parts[3], params
end

-- 任务命令格式解析器
function CommandParser:ParseQuestCommand(commandStr)
    -- 使用多个空格分隔
    -- "任务 主线 设置 1001 状态 %p 进行中"
    local parts = {}
    for part in commandStr:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    -- 确保至少有四个部分："任务"、questType、operation 和 questId
    if #parts < 4 then
        return nil, nil, nil
    end
    
    local params = {}
    params.cmd_type = parts[1]      -- "任务"
    params.subcategory = parts[2]   -- 任务类型(主线/支线等)
    params.operation = parts[3]     -- 操作(设置/增加/完成/解锁等)
    params.id = parts[4]            -- 任务ID
    
    -- 处理额外的参数
    if #parts >= 5 then
        params.attr_type = parts[5]  -- 属性类型(状态/目标/追踪/步骤/对话)
        
        -- 处理目标编号
        if params.attr_type == "目标" and #parts >= 6 then
            params.target_id = parts[6]
            -- 处理进度参数
            if #parts >= 7 and parts[7] == "进度" then
                params.progress_type = parts[7]
                params.obj = parts[8]
                params.num = parts[9]
            else
                params.obj = parts[7]
                params.num = parts[8]
            end
        -- 处理对话进度
        elseif params.attr_type == "对话" and #parts >= 6 and parts[6] == "进度" then
            params.progress_type = parts[6]
            params.obj = parts[7]
            params.num = parts[8]
        -- 处理其他情况
        else
            params.obj = parts[6]
            params.num = parts[7]
        end
    end
    
    return "任务",parts[3], params
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
        return nil, nil,nil
    end
end

return CommandParser