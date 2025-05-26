--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig)  ---@type MobTypeConfig


---@class MobCommand
local MobCommand = {}

---@param player Player
function MobCommand.spawnMob(params, player)
    local mobType = MobTypeConfig.Get(params["怪物"])
    if not mobType then
        player:SendChatText("不存在的怪物", params["怪物"])
        return false
    end
    local level = tonumber(params["等级"] or "1")
    local mob = mobType:Spawn(player:GetPosition(), level, player.scene)
    -- mob:SetTarget(player)
    return true
end

return MobCommand