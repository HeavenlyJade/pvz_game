local game     = game
local pairs    = pairs
local ipairs   = ipairs
local type     = type
local require = require

local MainStorage = game:GetService("MainStorage")
local gg              = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_const    = require(MainStorage.code.common.MConst)    ---@type common_const
local cloudDataMgr    = require(MainStorage.code.server.MCloudDataMgr)    ---@type MCloudDataMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
-- 所有玩家的背包装备管理，服务器侧
---@class BagMgr
local BagMgr = {
    server_player_bag_data = {}, ---@type table<number, Bag>
    need_sync_bag = {} ---@type table<Bag, boolean>
}

function SyncAll()
    if #BagMgr.need_sync_bag == 0 then
        return
    end
    for bag, _ in pairs(BagMgr.need_sync_bag) do
        print('SyncAll', bag)
        bag:SyncToClient()
    end
    BagMgr.need_sync_bag = {}
end

local timer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
timer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
timer.Name = 'SYNC_ALL'
timer.Delay = 0.1
timer.Loop = true      -- 是否循环
timer.Interval = 1   -- 循环间隔多少秒 (1秒=10帧)
timer.Callback = SyncAll
timer:Start()

---刷新玩家的背包数据（服务器 to 客户端）
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.s2c_PlayerBagItems( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    BagMgr.returnBagInfoByVer( uin_, player_data_ )
end

---使用物品
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.handleBtnUseItem( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:UseItem(param.slot)
end

---分解装备
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.handleBtnDecompose( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:DecomposeItem(param.slot)
end

---玩家交换背包数据
---@param uin_ number 玩家ID
---@param param table 参数
function BagMgr.handlePlayerItemsChange( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:SwapItem(param.pos1, param.pos2)
end

---打开所有宝箱
---@param uin_ number 玩家ID
function BagMgr.handleUseAllBox( uin_, param )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:UseAllBoxes()
end

---分解所有低质量装备
---@param uin_ number 玩家ID
---@param args1_ table 参数
function BagMgr.HandleDpAllLowEq( uin_, args1_ )
    local player_data_ = BagMgr.GetPlayerBag( uin_ )
    player_data_:DecomposeAllLowQualityItems(ItemRankConfig.Get(args1_.rank))
end

---获得指定uin玩家的背包数据
---@param uin_ number 玩家ID
---@return Bag 玩家背包数据
function BagMgr.GetPlayerBag( uin_ )
    return  BagMgr.server_player_bag_data[ uin_ ]
end

---云读取数据后，设置给玩家
---@param uin_ number 玩家ID
---@param bag Bag 背包数据
function BagMgr.setPlayerBagData( uin_, bag )
    BagMgr.server_player_bag_data[ uin_ ] = bag
end

return BagMgr
