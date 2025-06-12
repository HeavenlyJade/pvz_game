--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig)  ---@type MobTypeConfig
local LevelConfig = require(MainStorage.code.common.config.LevelConfig)  ---@type LevelConfig
local Level = require(MainStorage.code.server.Scene.Level)  ---@type Level

---@class LevelCommand
local LevelCommand = {}

---@param player Player
function LevelCommand.enter(params, player)
    -- 获取操作类型
    local action = params["操作"] or "进入"
    if not action then
        player:SendChatText("缺少操作参数")
        return false
    end

    -- 根据操作类型执行不同的逻辑
    if action == "进入" then
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
    elseif action == "暂停" then
        -- 获取玩家当前所在的关卡
        local currentLevel = Level.GetCurrentLevel(player)
        if not currentLevel then
            player:SendChatText("你当前不在任何关卡中")
            return false
        end
        currentLevel:Pause()
        player:SendChatText("关卡已暂停")
    elseif action == "继续" then
        -- 获取玩家当前所在的关卡
        local currentLevel = Level.GetCurrentLevel(player)
        if not currentLevel then
            player:SendChatText("你当前不在任何关卡中")
            return false
        end
        currentLevel:Resume()
        player:SendChatText("关卡已继续")
    else
        player:SendChatText("不支持的操作类型")
        return false
    end

    return true
end

return LevelCommand