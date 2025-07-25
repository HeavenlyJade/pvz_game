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
    local item_name = ''
    if params['参数'] and params['参数']['商品名'] then
        item_name = params['参数']['商品名']
    end
    customUI:S_Open(player,item_name)
    return true
end

function MiscCommand.toggleAutoBattle(params, player)
    local operation = params["开启"] or "切换"
    local newState
    
    if operation == "开启" then
        newState = true
    elseif operation == "关闭" then
        newState = false
    else -- "切换" 或其他情况
        newState = not (player.isAutoFighting or false)
    end
    
    player.isAutoFighting = newState
    local status = player.isAutoFighting and "开启" or "关闭"
    player:SendChatText(string.format("自动战斗已%s", status))
    player:SendEvent("ToggleAutoBattleFromServer", {
        autoBattle = player.isAutoFighting
    })
    return true
end

return MiscCommand