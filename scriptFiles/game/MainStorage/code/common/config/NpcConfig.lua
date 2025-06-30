local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers


---@class NpcData
---@field 名字 string
---@field 场景 string
---@field 节点 string
---@field 互动条件 table
---@field 互动指令 string[]

--- NPC配置文件
---@class NpcConfig
local NpcConfig = {}
local loaded = false

local function LoadConfig()
    NpcConfig.config ={
    ["抵御僵尸（1级+）"] = {
        ["名字"] = "抵御僵尸（1级+）",
        ["场景"] = "g0",
        ["节点名"] = "抵御僵尸1",
        ["互动指令"] = {
            [[ viewUI {"界面ID":"第一章"} ]]
        },
        ["额外互动距离"] = {
            0,
            400,
            0
        },
        ["看向附近玩家"] = false,
        ["名字尺寸"] = 2
    }
}loaded = true
end

---@param npcName string
---@return Npc
function NpcConfig.Get(npcName)
    if not loaded then
        LoadConfig()
    end
    return NpcConfig.config[npcName]
end

---@return Npc[]
function NpcConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return NpcConfig.config
end
return NpcConfig
