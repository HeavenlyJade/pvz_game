--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig)  ---@type MobTypeConfig


---@class MobCommand
local MobCommand = {}

---@param player CPlayer
function MobCommand.spawnMob(params, player)
    local mobType = MobTypeConfig.Get(params["怪物ID"])
    if not mobType then
        player:SendChatText("不存在的怪物", params["怪物ID"])
        return false
    end
    local level = tonumber(params["等级"] or "1")
    mobType:Spawn(player:GetLocation(), level, player.scene)
    return true
end

return MobCommand