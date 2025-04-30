--- V109 miniw-haima
--- 物品操作类，负责处理背包物品的各种操作

-- local game = game           -- 未使用，可删除
-- local pairs = pairs         -- 未使用，可删除
-- local type = type           -- 未使用，可删除

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config = require(MainStorage.code.common.MConfig)   ---@type common_config
local common_const = require(MainStorage.code.common.MConst)    ---@type common_const
local eqGen = require(MainStorage.code.server.equipment.MEqGen)   ---@type EqGen
local battleMgr = require(MainStorage.code.server.BattleMgr)        ---@type BattleMgr
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)    ---@type MCloudDataMgr
local ItemBase = require(MainStorage.code.server.item_types.ItemBase)   ---@type ItemBase
local EquipmentItem = require(MainStorage.code.server.item_types.EquipmentItem) ---@type EquipmentItem
local ConsumableItem = require(MainStorage.code.server.item_types.ConsumableItem) ---@type ConsumableItem
local MaterialItem = require(MainStorage.code.server.item_types.MaterialItem) ---@type MaterialItem
local CardItem = require(MainStorage.code.server.item_types.CardItem) ---@type CardItem
---@class ItemOperator
local ItemOperator = {}

---获取玩家背包数据
---@param uin number 玩家ID
---@return table 玩家背包数据
function ItemOperator:getPlayerBagData(uin)
    return gg.server_player_bag_data[uin]
end

-- 根据物品类型获取对应的容器名称

-- 根据物品获取容器
function ItemOperator:getContainerByItem(item)
    return common_const:getContainerNameByType(item.itype)
end

-- 根据物品UUID和类型获取物品
function ItemOperator:getItemByUUID(playerData, uuid, itemType)
    local containerName = common_const:getContainerNameByType(itemType)
    return playerData[containerName] and playerData[containerName][uuid]
end

-- 根据背包ID获取物品
function ItemOperator:getItemByBagId(playerData, bagId)
    local index = playerData.bag_index[bagId]
    if not index or not index.uuid or not index.type then
        return nil
    end
    
    return self:getItemByUUID(playerData, index.uuid, index.type)
end

-- 添加物品到背包
function ItemOperator:addItemToBag(playerData, item, bagId)
    local containerName = self:getContainerByItem(item)
    
    -- 添加物品到对应容器
    playerData[containerName][item.uuid] = item
    
    -- 更新索引，包含类型信息
    playerData.bag_index[bagId] = {
        uuid = item.uuid,
        type = item.itype
    }
    
    -- 增加版本号
    playerData.bag_ver = playerData.bag_ver + 1
    
    return true
end



---设置玩家背包数据
---@param uin number 玩家ID
---@param data table 背包数据
function ItemOperator:setPlayerBagData(uin, data)
    -- 如果是旧格式数据，先迁移
    if data.bag_items then
        -- 转换为新格式
        local newData = {
            bag_index = data.bag_index or {},
            bag_equ_items = {},
            bag_consum_items = {},
            bag_mater_items = {},
            bag_card_items = {},
            bag_ver = data.bag_ver,
            bag_size = data.bag_size or 36
        }
        
        -- 迁移物品数据
        for uuid, item in pairs(data.bag_items) do
            local containerName = common_const:getContainerNameByType(item.itype)
            newData[containerName][uuid] = item
            
            -- 更新索引中的类型信息
            for bagId, index in pairs(newData.bag_index) do
                if index.uuid == uuid then
                    index.type = item.itype
                end
            end
        end
        
        gg.server_player_bag_data[uin] = newData
    else
        -- 已经是新格式，直接设置
        gg.server_player_bag_data[uin] = data
    end
end

---同步背包数据到客户端
---@param uin number 玩家ID
---@param clientBagVer number 客户端背包版本
function ItemOperator:syncBagToClient(uin, clientBagVer)
    local playerData = self:getPlayerBagData(uin)
    
    -- 准备发送数据
    local ret = { 
        cmd = 'cmd_player_items_ret', 
        bag_data = playerData
    }
    gg.network_channel:fireClient(uin, ret)
end

---使用物品
---@param uin number 玩家ID
---@param bagId number 背包格子ID
---@return boolean 是否成功
function ItemOperator:useItem(uin, bagId)
    local playerData = self:getPlayerBagData(uin)
    local item = self:getItemByBagId(playerData, bagId)
    
    if not item then
        return false
    end
    
    -- 创建物品对象
    local itemObject = nil
    if item.itype == common_const.ITEM_TYPE.EQUIPMENT then
        itemObject = EquipmentItem.fromData(item)
    elseif item.itype == common_const.ITEM_TYPE.CONSUMABLE or item.itype == common_const.ITEM_TYPE.BOX then
        itemObject = ConsumableItem.fromData(item)
    elseif item.itype == common_const.ITEM_TYPE.MAT then
        itemObject = MaterialItem.fromData(item)
    elseif item.itype == common_const.ITEM_TYPE.CARD then
        itemObject = CardItem.fromData(item)
    else
        itemObject = ItemBase.fromData(item)
    end
    
    -- 检查物品是否可使用
    if not itemObject:canUse() then
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '该物品不能使用' 
        })
        return false
    end
    
    -- 获取玩家对象
    local player = gg.server_players_list[uin]
    if not player then
        return false
    end
    
    -- 调用物品的onUse方法执行具体效果
    local success, message = itemObject:onUse(player)
    
    if success then
        -- 物品使用后的处理
        local index = playerData.bag_index[bagId]
        local containerName = common_const:getContainerNameByType(item.itype)
        
        if (item.itype == common_const.ITEM_TYPE.BOX or 
            item.itype == common_const.ITEM_TYPE.CONSUMABLE) then
            if item.num and item.num > 1 then
                -- 堆叠物品减少数量
                item.num = item.num - 1
                playerData[containerName][index.uuid] = item
            else
                -- 移除物品
                playerData[containerName][index.uuid] = nil
                playerData.bag_index[bagId] = nil
            end
            
            -- 更新版本和保存
            playerData.bag_ver = playerData.bag_ver + 1
            cloudDataMgr.savePlayerBag(uin, false)
        elseif item.itype == common_const.ITEM_TYPE.EQUIPMENT and item.pos > 0 then
            -- 装备类物品处理
            return self:swapItems(uin, bagId, item.pos)
        end
        
        -- 通知客户端
        self:syncBagToClient(uin, nil)
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = message or ('成功使用 ' .. item.name), 
            color = itemObject:getQualityColor() 
        })
        
        return true
    else
        -- 使用失败
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = message or '使用失败',
            color = ColorQuad.new(255, 0, 0, 255)
        })
        return false
    end
end

---分解物品
---@param uin number 玩家ID
---@param bagId number 背包格子ID
---@return boolean 是否成功
function ItemOperator:decomposeItem(uin, bagId)
    -- 检查是否是装备位置
    if gg.isWearPos(bagId) then
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '不能分解已穿戴的装备' 
        })
        return false
    end
    
    local playerData = self:getPlayerBagData(uin)
    local item = self:getItemByBagId(playerData, bagId)
    
    if not item or item.itype ~= common_const.ITEM_TYPE.EQUIPMENT then
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '这件物品无法被分解' 
        })
        return false
    end
    
    local index = playerData.bag_index[bagId]
    
    -- 执行分解
    playerData.bag_index[bagId] = nil
    playerData.bag_equ_items[index.uuid] = nil
    
    -- 计算获得的材料数量
    local matQuality = 1         -- 1=魔力碎片  2=神力碎片
    local matNum = item.quality * item.level
    
    -- 尝试合并到已有材料
    local materialUpdated = false
    local baseId = 10000
    for i = 0, playerData.bag_size - 1 do
        local currBagId = baseId + i
        local tmpIndex = playerData.bag_index[currBagId]
        if tmpIndex and tmpIndex.uuid and tmpIndex.type == common_const.ITEM_TYPE.MAT then
            local tmpItem = self:getItemByUUID(playerData, tmpIndex.uuid, common_const.ITEM_TYPE.MAT)
            
            if tmpItem and 
               tmpItem.mat_id == common_const.MAT_ID.FRAGMENT and
               tmpItem.quality == matQuality then
                -- 增加已有材料的数量
                tmpItem.num = tmpItem.num + matNum
                materialUpdated = true
                break
            end
        end
    end
    
    -- 如果没有找到可合并的材料，则创建新材料
    if not materialUpdated then
        local material = eqGen.createMat({ 
            uuid = gg.create_uuid('mat'), 
            quality = matQuality, 
            num = matNum 
        })
        playerData.bag_mater_items[material.uuid] = material
        playerData.bag_index[bagId] = { 
            uuid = material.uuid,
            type = common_const.ITEM_TYPE.MAT
        }
    end
    
    -- 更新版本并保存
    playerData.bag_ver = playerData.bag_ver + 1
    cloudDataMgr.savePlayerBag(uin, false)
    
    -- 通知客户端
    self:syncBagToClient(uin, nil)
    gg.network_channel:fireClient(uin, { 
        cmd = "cmd_client_show_msg", 
        txt = '分解成功，获得魔力碎片 x ' .. matNum 
    })
    
    return true
end

---交换物品位置
---@param uin number 玩家ID
---@param pos1 number 位置1
---@param pos2 number 位置2
---@return boolean 是否成功
function ItemOperator:swapItems(uin, pos1, pos2)
    local playerData = self:getPlayerBagData(uin)
    
    local index1 = playerData.bag_index[pos1]
    local index2 = playerData.bag_index[pos2]
    
    -- 检查装备位置匹配
    if gg.isWearPos(pos2) and index1 then
        local item = self:getItemByBagId(playerData, pos1)
        if item and item.pos ~= pos2 then
            gg.network_channel:fireClient(uin, { 
                cmd = "cmd_client_show_msg", 
                txt = '该物品不能穿戴在这里', 
                color = ColorQuad.new(255, 0, 0, 255) 
            })
            return false
        end
    end
    
    -- 交换索引
    playerData.bag_index[pos1] = index2
    playerData.bag_index[pos2] = index1
    
    -- 同步到客户端
    self:syncBagToClient(uin, nil)
    
    -- 如果涉及装备位置，重新计算属性
    if gg.isWearPos(pos1) or gg.isWearPos(pos2) then
        battleMgr.refreshPlayerAttr(uin)
        local player = gg.server_players_list[uin]
        if player then
            player:rsyncData(1)
        end
    end
    
    return true
end

---合成物品
---@param uin number 玩家ID
---@return boolean 是否成功，消息
function ItemOperator:composeItem(uin)
    local playerData = self:getPlayerBagData(uin)
    
    -- 检查背包是否有空位
    local emptyBagId
    local baseId = 10000
    for i = 0, playerData.bag_size - 1 do
        local bagId = baseId + i
        if not playerData.bag_index[bagId] then
            emptyBagId = bagId
            break
        end
    end
    
    if not emptyBagId then
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_btn_compose_ret", 
            msg = "full" 
        })
        return false, "背包已满"
    end
    
    -- 查找并扣除材料
    local matQuality = 1
    local num = 0
    local matBagId
    
    for i = 0, playerData.bag_size - 1 do
        local bagId = baseId + i
        if playerData.bag_index[bagId] and playerData.bag_index[bagId].type == common_const.ITEM_TYPE.MAT then
            local tmpIndex = playerData.bag_index[bagId]
            local tmpItem = self:getItemByUUID(playerData, tmpIndex.uuid, common_const.ITEM_TYPE.MAT)
            
            if tmpItem and
               tmpItem.mat_id == common_const.MAT_ID.FRAGMENT and
               tmpItem.quality == matQuality then
                
                if tmpItem.num < 800 then
                    num = tmpItem.num
                    gg.network_channel:fireClient(uin, { 
                        cmd = "cmd_btn_compose_ret", 
                        msg = "no_enough", 
                        num = num 
                    })
                    return false, "材料不足"
                else
                    -- 扣除材料
                    tmpItem.num = tmpItem.num - 800
                    num = tmpItem.num
                    matBagId = bagId
                    
                    if tmpItem.num == 0 then
                        playerData.bag_mater_items[tmpIndex.uuid] = nil
                        playerData.bag_index[bagId] = nil
                        emptyBagId = bagId
                    end
                    
                    break
                end
            end
        end
    end
    
    if not matBagId then
        return false, "未找到材料"
    end
    
    -- 生成宝箱
    local quality = 4
    if gg.rand_int_between(1, 100) < 15 then
        quality = 5
    end
    
    local box = eqGen.createBox({ 
        uuid = gg.create_uuid('box'), 
        quality = quality, 
        level = gg.rand_int_between(1, 99) 
    })
    
    playerData.bag_consum_items[box.uuid] = box
    playerData.bag_index[emptyBagId] = { 
        uuid = box.uuid,
        type = common_const.ITEM_TYPE.BOX
    }
    
    -- 更新版本并保存
    playerData.bag_ver = playerData.bag_ver + 1
    cloudDataMgr.savePlayerBag(uin, false)
    
    -- 通知客户端
    self:syncBagToClient(uin, nil)
    gg.network_channel:fireClient(uin, { 
        cmd = "cmd_btn_compose_ret", 
        msg = "ok", 
        name = box.name, 
        quality = box.quality, 
        num = num 
    })
    gg.network_channel:fireClient(uin, { 
        cmd = "cmd_client_show_msg", 
        txt = '你获得了 ' .. box.name, 
        color = gg.getQualityColor(quality) 
    })
    
    return true, "合成成功"
end

---批量使用所有宝箱
---@param uin number 玩家ID
---@return boolean 是否成功
function ItemOperator:useAllBoxes(uin)
    local playerData = self:getPlayerBagData(uin)
    local count = 0
    
    for bagId, index in pairs(playerData.bag_index) do
        local item = self:getItemByBagId(playerData, bagId)
        
        if item and item.itype == common_const.ITEM_TYPE.BOX then
            -- 删除宝箱
            playerData.bag_consum_items[index.uuid] = nil
            count = count + 1
            
            -- 创建随机装备替换宝箱
            local eq = eqGen.createRandEquipment({ 
                quality = item.quality, 
                level = item.level 
            })
            
            playerData.bag_equ_items[eq.uuid] = eq
            playerData.bag_index[bagId] = { 
                uuid = eq.uuid,
                type = common_const.ITEM_TYPE.EQUIPMENT
            }
            
            -- 通知客户端
            gg.network_channel:fireClient(uin, { 
                cmd = "cmd_client_show_msg", 
                txt = '你获得了 ' .. eq.name, 
                color = gg.getQualityColor(item.quality) 
            })
        end
    end
    
    if count > 0 then
        playerData.bag_ver = playerData.bag_ver + 1
        cloudDataMgr.savePlayerBag(uin, false)
        self:syncBagToClient(uin, nil)
        return true
    else
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '你的背包里没有宝箱' 
        })
        return false
    end
end

---批量分解低级装备
---@param uin number 玩家ID
---@return boolean 是否成功
function ItemOperator:decomposeAllLowEquipment(uin)
    local playerData = self:getPlayerBagData(uin)
    local matQuality = 1
    local matNum = 0
    local firstBagId
    local matItem
    
    -- 遍历查找并分解低级装备
    for bagId, index in pairs(playerData.bag_index) do
        if bagId >= 10000 then
            local item = self:getItemByBagId(playerData, bagId)
            
            if item and item.itype == common_const.ITEM_TYPE.EQUIPMENT and item.quality < 4 then
                -- 删除装备
                playerData.bag_index[bagId] = nil
                playerData.bag_equ_items[index.uuid] = nil
                
                if not firstBagId then 
                    firstBagId = bagId 
                end
                
                matNum = matNum + item.quality * item.level
            elseif item and
                   item.itype == common_const.ITEM_TYPE.MAT and
                   item.mat_id == common_const.MAT_ID.FRAGMENT and
                   item.quality == matQuality then
                matItem = item
            end
        end
    end
    
    if matNum > 0 then
        -- 处理获得的材料
        if matItem then
            -- 已有材料，增加数量
            matItem.num = matItem.num + matNum
        else
            -- 创建新材料
            matItem = eqGen.createMat({ 
                uuid = gg.create_uuid('mat'), 
                quality = matQuality, 
                num = matNum 
            })
            playerData.bag_mater_items[matItem.uuid] = matItem
            playerData.bag_index[firstBagId] = { 
                uuid = matItem.uuid,
                type = common_const.ITEM_TYPE.MAT
            }
        end
        
        playerData.bag_ver = playerData.bag_ver + 1
        cloudDataMgr.savePlayerBag(uin, false)
        
        self:syncBagToClient(uin, nil)
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '你获得了 ' .. matItem.name .. ' x ' .. matNum 
        })
        
        return true
    else
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '没有发现可被分解的装备' 
        })
        return false
    end
end

---玩家拾取物品
---@param uin number 玩家ID
---@param itemInfo table 物品信息
---@return number 0成功，1失败
function ItemOperator:pickupItem(uin, itemInfo)
    local playerData = self:getPlayerBagData(uin)
    -- 查找空背包格子
    local baseId = 10000
    for i = 0, playerData.bag_size - 1 do
        local bagId = baseId + i
        if not playerData.bag_index[bagId] then
            -- 创建物品
            local item = eqGen.pickup_create_item(itemInfo)
            if not item then
                return 0
            end
            
            -- 加入背包
            local containerName = self:getContainerByItem(item)
            playerData[containerName][item.uuid] = item
            playerData.bag_index[bagId] = { 
                uuid = item.uuid,
                type = item.itype
            }
            playerData.bag_ver = playerData.bag_ver + 1
            
            -- 保存并通知客户端
            cloudDataMgr.savePlayerBag(uin, false)
            gg.network_channel:fireClient(uin, { 
                cmd = "cmd_client_show_msg", 
                txt = '你获得了 ' .. item.name, 
                color = gg.getQualityColor(item.quality) 
            })
            
            return 0
        end
    end
    
    -- 背包已满
    local player = gg.server_players_list[uin]
    if player then
        player:showDamage(0, { bag_full = 1 })
    end
    
    return 1
end

---创建初始装备
---@param uin number 玩家ID
function ItemOperator:generateInitialEquipment(uin)
    -- 这个方法可能需要根据新的数据结构进行调整
    -- 现在直接使用旧方法，数据结构会在setPlayerBagData中自动迁移
    local data = eqGen.debug_createRandEquipment()
    self:setPlayerBagData(uin, data)
    cloudDataMgr.savePlayerBag(uin, true)
end

---调试用：生成测试宝箱
---@param uin number 玩家ID
---@param boxCount number 宝箱数量
function ItemOperator:debugGenerateBoxes(uin, boxCount)
    if uin ~= 917263508 and uin ~= 12345 then
        return
    end
    
    local count = tonumber(boxCount) or 1
    for i = 1, count do
        local dropBox = { 
            uuid = gg.create_uuid('box'), 
            itype = common_const.ITEM_TYPE.BOX,
            level = gg.rand_int_between(1, 99), 
            quality = gg.rand_qulity() 
        }
        self:pickupItem(uin, dropBox)
    end
end

return ItemOperator