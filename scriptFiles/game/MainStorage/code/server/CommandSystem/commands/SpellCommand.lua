--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local SpellConfig = require(MainStorage.code.common.config.SpellConfig)  ---@type SpellConfig


---@class SpellCommand
local SpellCommand = {}

---@param player Player
function SpellCommand.cast(params, player)
    local spell = SpellConfig.Get(params["魔法名"])
    if not spell then
        player:SendChatText("不存在的魔法", params["魔法名"])
        return false
    end
    spell:Cast(player, nil)
    return true
end

return SpellCommand