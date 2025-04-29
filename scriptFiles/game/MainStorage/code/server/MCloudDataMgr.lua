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


--- 判断物品类型并返回对应的容器名称
function MCloudDataMgr.getContainerNameByType(itemType)
    local typeToContainer = {
        [common_const.ITEM_TYPE.EQUIPMENT] = "bag_equ_items",
        [common_const.ITEM_TYPE.CONSUMABLE] = "bag_consum_items",
        [common_const.ITEM_TYPE.BOX] = "bag_consum_items", -- 宝箱也放在消耗品容器
        [common_const.ITEM_TYPE.MAT] = "bag_mater_items",
        [common_const.ITEM_TYPE.CARD] = "bag_card_items"
    }
    return typeToContainer[itemType] or "bag_equ_items" -- 默认放在装备容器
end

--- 迁移背包数据到新格式
function MCloudDataMgr.migrateBagDataToNewFormat(bagData)
    -- 只处理有旧格式数据的情况
    if not bagData.bag_items then
        return bagData
    end
    
    -- 初始化新容器
    bagData.bag_equ_items = bagData.bag_equ_items or {}
    bagData.bag_consum_items = bagData.bag_consum_items or {}
    bagData.bag_mater_items = bagData.bag_mater_items or {}
    bagData.bag_card_items = bagData.bag_card_items or {}
    
    -- 迁移物品数据
    for uuid, item in pairs(bagData.bag_items) do
        local containerName = MCloudDataMgr.getContainerNameByType(item.itype)
        bagData[containerName][uuid] = item
        
        -- 更新索引中的类型信息
        for bagId, index in pairs(bagData.bag_index) do
            if index.uuid == uuid then
                index.type = item.itype
            end
        end
    end
    
    -- 增加版本号
    bagData.bag_ver = bagData.bag_ver + 1
    
    return bagData
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
    
    -- 处理旧数据格式迁移
    if bagData.bag_items and not bagData.bag_equ_items then
        -- 初始化新容器
        bagData.bag_equ_items = {}
        bagData.bag_consum_items = {}
        bagData.bag_mater_items = {}
        bagData.bag_card_items = {}
        
        -- 迁移物品数据
        for uuid, item in pairs(bagData.bag_items) do
            local containerName = MCloudDataMgr.getContainerNameByType(item.itype)
            bagData[containerName][uuid] = item
            
            -- 更新索引中的类型信息
            for bagId, index in pairs(bagData.bag_index) do
                if index.uuid == uuid then
                    index.type = item.itype
                end
            end
        end
        
        -- 增加版本号
        bagData.bag_ver = (bagData.bag_ver or 1000) + 1
        
        -- 不删除旧数据，保留兼容性
    end
    
    -- 确保索引中有类型信息
    if bagData.bag_index then
        for bagId, index in pairs(bagData.bag_index) do
            if index.uuid and not index.type then
                -- 尝试确定物品类型
                local item = nil
                for _, containerName in ipairs({"bag_equ_items", "bag_consum_items", "bag_mater_items", "bag_card_items", "bag_items"}) do
                    if bagData[containerName] and bagData[containerName][index.uuid] then
                        item = bagData[containerName][index.uuid]
                        break
                    end
                end
                
                if item then
                    index.type = item.itype
                else
                    -- 如果找不到物品，默认为装备类型
                    index.type = common_const.ITEM_TYPE.EQUIPMENT
                end
            end
        end
    end
    
    -- 开始清理无效数据
    -- 1. 收集有效物品索引
    local validUUIDToBagID = {}
    local invalidBagIDs = {}
    
    for bagID, indexData in pairs(bagData.bag_index) do
        local isValid = false
        if indexData.uuid and indexData.type then
            local containerName = MCloudDataMgr.getContainerNameByType(indexData.type)
            if bagData[containerName] and bagData[containerName][indexData.uuid] then
                validUUIDToBagID[indexData.uuid] = bagID
                isValid = true
            end
        end
        
        if not isValid then
            table.insert(invalidBagIDs, bagID)
        end
    end
    
    -- 2. 清理无效索引
    for _, bagID in ipairs(invalidBagIDs) do
        bagData.bag_index[bagID] = nil
    end
    
    -- 3. 清理无引用的物品
    local containerNames = {"bag_equ_items", "bag_consum_items", "bag_mater_items", "bag_card_items", "bag_items"}
    for _, containerName in ipairs(containerNames) do
        if bagData[containerName] then
            local orphanedUUIDs = {}
            for uuid in pairs(bagData[containerName]) do
                if not validUUIDToBagID[uuid] then
                    table.insert(orphanedUUIDs, uuid)
                end
            end
            
            for _, uuid in ipairs(orphanedUUIDs) do
                bagData[containerName][uuid] = nil
            end
        end
    end
    
    -- 恢复物品资源信息
    bagData = MCloudDataMgr.restoreFilteredItemFields(bagData)
    
    gg.log("读取并处理背包数据", 'bag' .. uin_, bagData.bag_ver)
    return 0, bagData
end

function MCloudDataMgr.restoreFilteredItemFields(bagData)
    -- 容器列表
    local containerNames = {"bag_equ_items", "bag_consum_items", "bag_mater_items", "bag_card_items", "bag_items"}
    
    -- 处理每个容器
    for _, containerName in ipairs(containerNames) do
        if bagData[containerName] then
            for uuid, item in pairs(bagData[containerName]) do
                -- 恢复资源路径(asset)
                local re_item = MCloudDataMgr.restoreItemAsset(item)
                bagData[containerName][uuid] = re_item
            end
        end
    end
    
    return bagData
end


-- 恢复物品的资源路径
function MCloudDataMgr.restoreItemAsset(item)
    if item.asset then return item end
    
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

--- 创建兼容旧格式的背包数据（用于同步到客户端）
function MCloudDataMgr.createCompatibleBagData(playerData)
    -- 如果已经有旧格式数据，直接返回
    if playerData.bag_items then
        return playerData
    end
    
    -- 创建兼容数据
    local compatibleData = {
        bag_index = playerData.bag_index,
        bag_ver = playerData.bag_ver,
        bag_size = playerData.bag_size,
        bag_items = {}
    }
    
    -- 容器列表
    local containerNames = {"bag_equ_items", "bag_consum_items", "bag_mater_items", "bag_card_items"}
    
    -- 合并所有容器的物品
    for _, containerName in ipairs(containerNames) do
        if playerData[containerName] then
            for uuid, item in pairs(playerData[containerName]) do
                compatibleData.bag_items[uuid] = item
            end
        end
    end
    
    return compatibleData
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
        -- 创建清理过的数据副本
        local cleanedData = {
            uin = uin_,
            bag_index = player_bag_.bag_index,
            bag_ver = player_bag_.bag_ver,
            bag_size = player_bag_.bag_size,
            bag_equ_items = {},
            bag_consum_items = {},
            bag_mater_items = {},
            bag_card_items = {}
        }
        
        -- 容器列表
        local containerNames = {"bag_equ_items", "bag_consum_items", "bag_mater_items", "bag_card_items"}
        
        -- 清理每个容器的物品数据
        for _, containerName in ipairs(containerNames) do
            if player_bag_[containerName] then
                for uuid, item in pairs(player_bag_[containerName]) do
                    local cleaned_item = {}
                    for k, v in pairs(item) do
                        -- 过滤掉不需要保存的字段
                        if k ~= "asset" and k ~= "attrs" then
                            cleaned_item[k] = v
                        end
                    end
                    cleanedData[containerName][uuid] = cleaned_item
                end
            end
        end
        
        -- 保存到云端
        cloudService:SetTableAsync('bag' .. uin_, cleanedData, function(ret_)
            if not ret_ then
                gg.log("保存背包数据失败", 'bag' .. uin_, cleanedData.bag_ver)
            else
                gg.log("保存背包数据成功", 'bag' .. uin_, cleanedData.bag_ver)
            end
        end)
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
