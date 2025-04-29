--- 管理云数据存储部分
--- V109 miniw-haima


local print        = print
local setmetatable = setmetatable
local math         = math
local game         = game
local pairs        = pairs


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const

local cloudService      = game:GetService("CloudService")     -- 云数据


local  CONST_CLOUD_SAVE_TIME = 30    --每60秒存盘一次

---@class MCloudDataMgr
local MCloudDataMgr = {
    last_time_player = 0,     --最后一次玩家存盘时间
    last_time_bag    = 0,     --最后一次背包存盘时间
}



--读取玩家技能数据
function MCloudDataMgr.readSkillData( uin_ )
    local ret_, ret2_ = cloudService:GetTableOrEmpty( 'sk' .. uin_ )
    gg.log( '获取玩家技能数据信息', 'pd' .. uin_, ret_, ret2_ )
    if  ret_ then
        if  ret2_ and ret2_.uin == uin_ then
            return 0, ret2_
        end
        return 0, {}
    else
        return 1, {}       --数据失败，踢玩家下线，不然数据洗白了
    end
end



-- 保存玩家技能设置
-- force_:  立即存储，不检查时间间隔
function MCloudDataMgr.saveSkillData( uin_ )
    local player_ = gg.server_players_list[ uin_ ]
    if  player_ then
        local data_ = {
            uin   = uin_,
            skill = player_.dict_btn_skill
        }

        cloudService:SetTableAsync( 'sk' .. uin_, data_, function ( ret_ )
            if  not ret_ then
                gg.log("保存玩家技能失败", 'sk' .. uin_, data_ )
            else
                gg.log("保存玩家技能成功", 'sk' .. uin_, data_ )
            end
        end )
    end
end


-- 读取玩家数据 等级 经验值
function MCloudDataMgr.readPlayerData( uin_ )
    local ret_, ret2_ = cloudService:GetTableOrEmpty( 'pd' .. uin_ )

    gg.log( '获取与玩家当前的经验和等级', 'pd' .. uin_, ret_, ret2_ )
    if  ret_ then
        if  ret2_ and ret2_.uin == uin_ then
            return 0, ret2_
        end
        return 0, {}
    else
        return 1, {}       --数据失败，踢玩家下线，不然数据洗白了
    end
end




-- 保存玩家数据 等级 经验值
-- force_:  立即存储，不检查时间间隔
function MCloudDataMgr.savePlayerData( uin_,  force_ )

    if  force_ == false then
        local now_ = os.time()
        if  now_ - MCloudDataMgr.last_time_player < CONST_CLOUD_SAVE_TIME then
            return
        else
            MCloudDataMgr.last_time_player = now_
        end
    end


    local player_ = gg.server_players_list[ uin_ ]
    if  player_ then
        local data_ = {
            uin   = uin_,
            exp   = player_.exp,
            level = player_.level,
        }
        cloudService:SetTableAsync( 'pd' .. uin_, data_, function ( ret_ )
            if  not ret_ then
                gg.log("保持玩家当前等级和经验失败", 'pd' .. uin_, data_ )
            else
                gg.log("保持玩家当前等级和经验", 'pd' .. uin_, data_ )
            end
        end )
    end
end


-- 读取玩家的背包数据
function MCloudDataMgr.readPlayerBag(uin_)
    local success, bagData = cloudService:GetTableOrEmpty('bag' .. uin_)
    
    -- 读取失败或数据为空
    if not success then
        return 1, {}  -- 数据失败，踢玩家下线，防止数据洗白
    end
    
    -- 验证玩家ID
    if not bagData or bagData.uin ~= uin_ then
        return 0, {}
    end
    
    -- 开始清理无效数据
    -- 1. 收集有效物品索引
    local validUUIDToBagID = {}
    local invalidBagIDs = {}
    
    for bagID, indexData in pairs(bagData.bag_index) do
        if indexData.uuid and bagData.bag_items[indexData.uuid] then
            if bagData.bag_items[indexData.uuid].quality then
                validUUIDToBagID[indexData.uuid] = bagID
            end
        else
            table.insert(invalidBagIDs, bagID)
        end
    end
    
    -- 2. 收集无引用的物品UUID
    local orphanedUUIDs = {}
    for uuid in pairs(bagData.bag_items) do
        if not validUUIDToBagID[uuid] then
            table.insert(orphanedUUIDs, uuid)
        end
    end
    
    -- 3. 清理无效索引和物品
    for _, bagID in ipairs(invalidBagIDs) do
        bagData.bag_index[bagID] = nil
    end
    
    for _, uuid in ipairs(orphanedUUIDs) do
        bagData.bag_items[uuid] = nil
    end
    local re_bagData = MCloudDataMgr.restoreFilteredItemFields(bagData)
    gg.log("恢复背包数据", 'bag' .. uin_, re_bagData)
    return 0, re_bagData
end

function MCloudDataMgr.restoreFilteredItemFields(bagData)
    if not bagData.bag_items then return end
    
    for uuid, item in pairs(bagData.bag_items) do
        -- 恢复资源路径(asset)
        local re_item = MCloudDataMgr.restoreItemAsset(item)
        bagData.bag_items[uuid] = re_item
    end
    return bagData
end


-- 恢复物品的资源路径
function MCloudDataMgr.restoreItemAsset(item)
    if item.asset then return end
    
    if item.itype == common_const.ITEM_TYPE.EQUIPMENT then
        -- 装备类物品
        local equipment_config = common_config.equipment_config
        local weapon_config = common_config.weapon_config
        local eqconfig = equipment_config.equipment_def[item.id]
        local weapon_config = weapon_config.weapon_def[item.id]
        if eqconfig then
            item.asset = eqconfig.asset
            item.attrs = eqconfig.attrs
        elseif weapon_config then
            item.asset = weapon_config.asset
            item.attrs = weapon_config.attrs
        else
            item.asset = "sandboxSysId://items/icon12005.png"
            item.attrs = {}
        end
    elseif item.itype == common_const.ITEM_TYPE.MAT then
        -- 材料类物品
        if item.mat_id == common_const.MAT_ID.FRAGMENT then
            item.asset = common_config.assets_dict.icon_mat1
        else
            -- 其他类型材料的默认图标
            item.asset = "sandboxSysId://items/icon11618.png"
        end
    elseif item.itype == common_const.ITEM_TYPE.BOX then
        -- 宝箱类物品
        item.asset = common_config.assets_dict.icon_box
    else
        -- 其他类型物品的默认图标
        item.asset = "sandboxSysId://items/icon12000.png"
    end
    return item
end

-- 保存玩家的背包数据
-- force_:  立即存储，不检查时间间隔
function MCloudDataMgr.savePlayerBag( uin_, force_ )
    if force_ == false then
        local now_ = os.time()
        if now_ - MCloudDataMgr.last_time_bag < CONST_CLOUD_SAVE_TIME then
            return
        else
            MCloudDataMgr.last_time_bag = now_
        end
    end

    local player_bag_ = gg.server_player_bag_data[ uin_ ]
    if player_bag_ then
        -- 创建数据的深拷贝，以便不影响原始数据
        local cleaned_items = {}
        
        -- 清理不必要的字段
        for uuid, item in pairs(player_bag_.bag_items) do
            local cleaned_item = {}
            for k, v in pairs(item) do
                -- 过滤掉不需要保存的字段
                if k ~= "asset" and k ~= "attrs" then
                    cleaned_item[k] = v
                end
            end
            cleaned_items[uuid] = cleaned_item
        end
        
        local data_ = {
            uin       = uin_,
            bag_index = player_bag_.bag_index,
            bag_items = cleaned_items,
            bag_ver   = player_bag_.bag_ver,
            bag_size  = player_bag_.bag_size
        }
        
        cloudService:SetTableAsync( 'bag' .. uin_, data_, function ( ret_ )
            if not ret_ then
                gg.log("保存背包数据失败", 'bag' .. uin_,data_)
            else
                gg.log("保存背包数据成功", 'bag' .. uin_,data_)
            end
        end )
    end
end


-- 读取玩家的任务配置
function MCloudDataMgr.readGameTaskData(uin_)
    local ret_, ret2_ = cloudService:GetTableOrEmpty( 'game_task' .. uin_ )
    if  ret_ then
        if ret2_ and ret2_.uin == uin_ then
            return 0, ret2_
        else
            return 0, {}
        end
    else
        return 1 ,{}
    end
    
end

function MCloudDataMgr.saveGameTaskData(uin_)
    local player_ = gg.server_players_list[ uin_ ]
    if  player_ then
        local data_ = {
            uin   = uin_,
            dict_game_task = player_.dict_game_task,
            daily_tasks =player_.daily_tasks 
        }

        cloudService:SetTableAsync( 'game_task' .. uin_, data_, function ( ret_ )
            if  not ret_ then
                gg.log("保存玩家任务失败", 'game_task' .. uin_, data_ )
            else
                gg.log("保存玩家任务成功", 'game_task' .. uin_, data_ )
            end
        end )
    end
    
end

return MCloudDataMgr
