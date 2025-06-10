--- 背包事件管理器
--- 负责处理所有背包相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig
local BagMgr = require(MainStorage.code.server.bag.BagMgr) ---@type BagMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig

---@class BagEventManager
local BagEventManager = {}

-- 将配置导入到当前模块
BagEventManager.REQUEST = BagEventConfig.REQUEST
BagEventManager.RESPONSE = BagEventConfig.RESPONSE
BagEventManager.NOTIFY = BagEventConfig.NOTIFY

--- 初始化背包事件管理器
function BagEventManager.Init()
    gg.log("初始化背包事件管理器...")
    BagEventManager.RegisterEventHandlers()
    gg.log("背包事件管理器初始化完成")
end

--- 注册所有事件处理器
function BagEventManager.RegisterEventHandlers()
    -- 获取背包物品
    ServerEventManager.Subscribe(BagEventManager.REQUEST.GET_BAG_ITEMS, BagEventManager.HandleGetBagItems)
    
    -- 使用物品
    ServerEventManager.Subscribe(BagEventManager.REQUEST.USE_ITEM, BagEventManager.HandleUseItem)
    
    -- 分解装备
    ServerEventManager.Subscribe(BagEventManager.REQUEST.DECOMPOSE_ITEM, BagEventManager.HandleDecomposeItem)
    
    -- 交换物品位置
    ServerEventManager.Subscribe(BagEventManager.REQUEST.SWAP_ITEMS, BagEventManager.HandleSwapItems)
    
    -- 打开所有宝箱
    ServerEventManager.Subscribe(BagEventManager.REQUEST.USE_ALL_BOXES, BagEventManager.HandleUseAllBoxes)
    
    -- 分解所有低质量装备
    ServerEventManager.Subscribe(BagEventManager.REQUEST.DECOMPOSE_ALL_LOW_EQ, BagEventManager.HandleDecomposeAllLowEq)

    gg.log("已注册 " .. 6 .. " 个背包事件处理器")
end

--- 验证玩家
---@param evt table 事件参数
---@return Player|nil 玩家对象
function BagEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        gg.log("背包事件缺少玩家UIN参数")
        return nil
    end

    local player = gg.getPlayerByUin(uin)
    if not player then
        gg.log("背包事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 获取玩家背包
---@param uin number 玩家ID
---@return Bag|nil 背包对象
function BagEventManager.GetPlayerBag(uin)
    return BagMgr.GetPlayerBag(uin)
end

--- 处理获取背包物品请求
---@param evt table 事件数据
function BagEventManager.HandleGetBagItems(evt)
    local player = BagEventManager.ValidatePlayer(evt)
    if not player then return end

    local bag = BagEventManager.GetPlayerBag(player.uin)
    if bag then
        bag:MarkDirty(true) -- 标记需要同步所有数据
    end
end

--- 处理使用物品请求
---@param evt table 事件数据 {slot}
function BagEventManager.HandleUseItem(evt)
    local player = BagEventManager.ValidatePlayer(evt)
    if not player then return end

    local bag = BagEventManager.GetPlayerBag(player.uin)
    if bag and evt.slot then
        bag:UseItem(evt.slot)
    end
end

--- 处理分解装备请求
---@param evt table 事件数据 {slot}
function BagEventManager.HandleDecomposeItem(evt)
    local player = BagEventManager.ValidatePlayer(evt)
    if not player then return end

    local bag = BagEventManager.GetPlayerBag(player.uin)
    if bag and evt.slot then
        bag:DecomposeItem(evt.slot)
    end
end

--- 处理交换物品位置请求
---@param evt table 事件数据 {pos1, pos2}
function BagEventManager.HandleSwapItems(evt)
    local player = BagEventManager.ValidatePlayer(evt)
    if not player then return end

    local bag = BagEventManager.GetPlayerBag(player.uin)
    if bag and evt.pos1 and evt.pos2 then
        bag:SwapItem(evt.pos1, evt.pos2)
    end
end

--- 处理打开所有宝箱请求
---@param evt table 事件数据
function BagEventManager.HandleUseAllBoxes(evt)
    local player = BagEventManager.ValidatePlayer(evt)
    if not player then return end

    local bag = BagEventManager.GetPlayerBag(player.uin)
    if bag then
        bag:UseAllBoxes()
    end
end

--- 处理分解所有低质量装备请求
---@param evt table 事件数据 {rank}
function BagEventManager.HandleDecomposeAllLowEq(evt)
    local player = BagEventManager.ValidatePlayer(evt)
    if not player then return end

    local bag = BagEventManager.GetPlayerBag(player.uin)
    if bag and evt.rank then
        local rank = ItemRankConfig.Get(evt.rank)
        if rank then
            bag:DecomposeAllLowQualityItems(rank)
        end
    end
end

return BagEventManager 