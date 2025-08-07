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
    if not params["界面ID"] then
        gg.log("不存在的界面ID", params["界面ID"])
        return
    end
    local CustomUIConfig = require(MainStorage.config.CustomUIConfig) ---@type CustomUIConfig
    local customUI = CustomUIConfig.Get(params["界面ID"])
    if not customUI then
        gg.log("找不到界面配置", params["界面ID"])
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
        newState = 1
    elseif operation == "关闭" then
        newState = 0
    else -- "切换" 或其他情况
        local currentState = player:GetVariable("autofighting", 0)
        newState = currentState == 0 and 1 or 0
    end
    
    player:SetVariable("autofighting", newState)
    local status = newState == 1 and "开启" or "关闭"
    player:SendChatText(string.format("自动战斗已%s", status))
    player:SendEvent("ToggleAutoBattleFromServer", {
        autoBattle = newState == 1
    })
    return true
end

---@param player Player
function MiscCommand.debug(params, player)
    if params["客户端执行"] then
        params["客户端执行"] = false
        player:SendEvent("Debug", params)
    else
        gg.Debug(params, player)
    end
    return true
end


return MiscCommand