--- V109 miniw-haima

local game     = game
local pairs    = pairs

local MainStorage = game:GetService("MainStorage")
local gg              = require(MainStorage.code.common.MGlobal)   ---@type gg
local itemOperator    = require(MainStorage.code.server.bag.MItemOperator)   ---@type ItemOperator

-- 所有玩家的背包装备管理，服务器侧
---@class BagMgr
local BagMgr = {}

--刷新玩家的背包数据 （ 服务器 to 客户端 ）
function BagMgr.s2c_PlayerBagItems(uin_, args1_)
    itemOperator:syncBagToClient(uin_, args1_.bag_ver)
end

--使用物品
function BagMgr.handleBtnUseItem(uin_, args1_)
    gg.log('玩家使用物品', uin_, args1_)
    itemOperator:useItem(uin_, args1_.bag_id)
end

--分解装备
function BagMgr.handleBtnDecompose(uin_, args1_)
    gg.log('分解装备', uin_, args1_)
    itemOperator:decomposeItem(uin_, args1_.bag_id)
end

--合成随机装备
function BagMgr.handleBtnCompose(uin_, args1_)
    gg.log('handleBtnCompose', uin_, args1_)
    itemOperator:composeItem(uin_)
end

--玩家交换背包数据 cmd_player_items_change
function BagMgr.handlePlayerItemsChange(uin_, args1_)
    gg.log('call handlePlayerItemsChange', uin_, args1_)
    itemOperator:swapItems(uin_, args1_.pos1, args1_.pos2)
end

--打开所有宝箱
function BagMgr.handleUseAllBox(uin_, args1_)
    gg.log('handleUseAllBox', uin_, args1_)
    itemOperator:useAllBoxes(uin_)
end

--分解所有指定类型装备
function BagMgr.handleDpAllLowEq(uin_, args1_)
    gg.log('handleDpAllLowEq', uin_, args1_)
    itemOperator:decomposeAllLowEquipment(uin_)
end

--获得指定uin玩家的背包数据
function BagMgr.getPlayerBagData(uin_)
    return itemOperator:getPlayerBagData(uin_)
end

-- 云读取数据后，设置给玩家
function BagMgr.setPlayerBagData(uin_, data_)
    itemOperator:setPlayerBagData(uin_, data_)
end

--生成随机数据
function BagMgr.genPlayerBagFirstData(uin_)
    itemOperator:generateInitialEquipment(uin_)
end

--玩家获得一个物品
function BagMgr.tryGetItem(uin_, item_info_)
    return itemOperator:pickupItem(uin_, item_info_)
end

--测试获得箱子
function BagMgr.debugGenBox(uin_, box_num_)
    itemOperator:debugGenerateBoxes(uin_, box_num_)
end

return BagMgr