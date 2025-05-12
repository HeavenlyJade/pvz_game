
    
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifier      = require(MainStorage.code.common.config_type.modifier.Modifier)    ---@type Modifier

--- NPC配置文件
---@class NpcConfig
local NpcConfig= { config = {
    ["铁匠铺"] = Npc.New({
        ["名字"] = "铁匠铺"
    })
}}

---@param npcName string
---@return Npc
function NpcConfig.Get(npcName)
    return NpcConfig.config[npcName]
end

---@return Npc[]
function NpcConfig.GetAll()
    return NpcConfig.config
end
return NpcConfig
