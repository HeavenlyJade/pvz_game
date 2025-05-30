
    
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg


--- 关卡配置文件
---@class LevelConfig
local LevelConfig= { config = {
}}

---@param level string
---@return Level
function LevelConfig.Get(level)
    return LevelConfig.config[level]
end

---@return ItemType[]
function LevelConfig.GetAll()
    return LevelConfig.config
end
return LevelConfig