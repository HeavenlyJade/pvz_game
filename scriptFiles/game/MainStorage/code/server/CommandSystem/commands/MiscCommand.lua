--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class MiscCommand
local MiscCommand = {}

function MiscCommand.title(params, player)
    player:SendHoverText(params["信息"])
    return true
end

return MiscCommand