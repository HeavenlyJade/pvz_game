local MainStorage = game:GetService("MainStorage")
local CommandParser = require(MainStorage.code.server.CommandSystem.parsers.MCommandParser) ---@type CommandParser
local gg=require(MainStorage.code.common.MGlobal) ---@type gg
-- 测试命令列表
local commands = {
    "玩家 等级 设置 %p 10"   ,               
"玩家 经验 增加 %p 100"   ,               
"玩家 经验 设置 %p 500"   ,               
"玩家 力量 增加 %p 5"  ,                
"玩家 敏捷 设置 %p 20"  ,
}
local parts = {}


-- 批量执行测试
for i, cmdStr in ipairs(commands) do

    print("\n测试 " .. i .. ": " .. cmdStr)
    local parts = {}
    -- for part in cmdStr:gmatch("%S+") do
    --     table.insert(parts, part)
    -- end

    local plaery,parts,params = CommandParser:ParsePlayerCommand(cmdStr)
    gg.log(plaery,parts,params)
    print("----------")
end