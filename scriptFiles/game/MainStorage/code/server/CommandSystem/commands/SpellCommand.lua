--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local SpellConfig = require(MainStorage.code.common.config.SpellConfig)  ---@type SpellConfig
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell


---@class SpellCommand
local SpellCommand = {}

---@param player Player
function SpellCommand.cast(params, player)
    if params["复杂魔法"] and params["魔法"] ~= "null" then
        local spell = SubSpell.New(params["复杂魔法"])
        spell:Cast(player, nil)
    else
        local spell = SpellConfig.Get(params["魔法名"])
        if not spell then
            player:SendChatText("不存在的魔法", params["魔法名"])
            return false
        end
        spell:Cast(player, nil)
    end
    return true
end

return SpellCommand