
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg

--- TriggerZone配置文件
---@class TriggerZoneConfig
local TriggerZoneConfig = {}
local loaded = false

local function LoadConfig()
    TriggerZoneConfig.config ={
    ["领取初始任务区域"] = {
        ["名字"] = "领取初始任务区域",
        ["场景"] = "g0",
        ["节点名"] = {
            "领取初始任务区域"
        },
        ["定时间隔"] = 0,
        ["进入指令"] = {
            [[cast {"魔法名":"新玩家进入","复杂魔法":{}} ]],
            [[cast {"魔法名":"旧玩家补足豌豆射手","复杂魔法":{}} ]]
        }
    }
}loaded = true
end

---@param Name string
function TriggerZoneConfig.Get(Name)
    if not loaded then
        LoadConfig()
    end
    return TriggerZoneConfig.config[Name]
end

function TriggerZoneConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return TriggerZoneConfig.config
end
return TriggerZoneConfig
