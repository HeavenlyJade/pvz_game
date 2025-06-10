--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig)  ---@type MobTypeConfig
local LevelConfig = require(MainStorage.code.common.config.LevelConfig)  ---@type LevelConfig

---@class LevelCommand
local LevelCommand = {}

---@param player Player
function LevelCommand.enter(params, player)
    -- 获取关卡类型
    local levelType = LevelConfig.Get(params["关卡"])
    if not levelType then
        player:SendChatText("不存在的关卡类型")
        return false
    end

    -- 根据是否需要匹配来决定进入方式
    if params["无需匹配直接开始"] then
        levelType.matchQueue[player.uin] = player
        levelType.playerCount = levelType.playerCount + 1
        levelType:StartLevel()
    else
        -- 加入匹配队列
        levelType:Queue(player)
    end

    return true
end

return LevelCommand