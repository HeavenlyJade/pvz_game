--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class MiscCommand
local MiscCommand = {}

function MiscCommand.title(params, player)
    player:SendHoverText(params["信息"])
    return true
end

function MiscCommand.viewUI(params, player)
    local CustomUIConfig = require(MainStorage.config.CustomUIConfig) ---@type CustomUIConfig
    local customUI = CustomUIConfig.Get(params["界面ID"])
    if not params["界面ID"] then
        gg.log("不存在的界面ID", params["界面ID"])
        return
    end
    customUI:S_Open(player)
    return true
end

return MiscCommand