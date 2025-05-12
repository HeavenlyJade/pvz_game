--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local bagMgr = require(MainStorage.code.server.bag.BagMgr)  ---@type BagMgr
local common_const = require(MainStorage.code.common.MConst)  ---@type common_const
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)  ---@type MCloudDataMgr

---@class MiscCommand
local MiscCommand = {}

function MiscCommand.title(params, player)
    player:SendChatText(params["信息"])
    return true
end

return MiscCommand