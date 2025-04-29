--- 命令解析器 - 负责解析指令字符串
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class CommandParser
local CommandParser = {}

-- 解析指令字符串
function CommandParser:ParseCommand(commandStr, player)
    -- 新的命令格式为: "类别 操作 参数1 参数2 ..."
    local pattern = "(%w+)%s+(%w+)%s+(.*)"
    local category, operation, restParams = commandStr:match(pattern)
    
    if not category or not operation then
        return nil, nil, nil
    end
    
    -- 解析剩余参数
    local params = self:ParseParams(restParams)
    
    return category, operation, params
end

-- 解析参数字符串为表
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

return CommandParser