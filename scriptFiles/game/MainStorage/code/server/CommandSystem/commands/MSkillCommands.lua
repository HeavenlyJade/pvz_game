--- 技能相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)  ---@type MCloudDataMgr

---@class SkillCommands
local SkillCommands = {}

-- --装载配置的文件的技能
function SkillCommands.LoadDefSkill(params, player)
    local player = gg.getPlayerByUin(params.uin)
    if not player then
        gg.log("玩家不存在: " .. params.uin)
        return false
    end
    player:LoadingConfSkills()
    return true
end


return SkillCommands