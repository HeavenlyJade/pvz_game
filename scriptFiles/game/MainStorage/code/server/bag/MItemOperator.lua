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
local ItemOperator = {
    
}

---获取玩家背包数据
---@param uin number 玩家ID
---@return table 玩家背包数据
function ItemOperator:getPlayerBagData(uin)
    if not gg.server_player_bag_data[uin]  then
        -- 如果缓存中没有，则初始化空背包
        gg.server_player_bag_data[uin] = {
            bag_index = {},
            bag_items = {},
            bag_ver = 1001,
            bag_size = 36
        }
    end
    return gg.server_player_bag_data[uin]
end

---设置玩家背包数据
---@param uin number 玩家ID
---@param data table 背包数据
function ItemOperator:setPlayerBagData(uin, data)
    local bag_data = {
        bag_index = data.bag_index or {},
        bag_items = data.bag_items or {},
        bag_ver = data.bag_ver,
        bag_size = data.bag_size or 36
    }
    
    gg.server_player_bag_data[uin] = bag_data
end

---同步背包数据到客户端
---@param uin number 玩家ID
---@param clientBagVer number 客户端背包版本
function ItemOperator:syncBagToClient(uin, clientBagVer)
    local playerData = self:getPlayerBagData(uin)
    local ret = { 
        cmd = 'cmd_player_items_ret', 
        index = playerData.bag_index, 
        bag_ver = playerData.bag_ver,
        bag_size = playerData.bag_size 
    }
    
    -- 只有当客户端版本与服务器不一致时，才发送完整物品数据
    if not clientBagVer or clientBagVer ~= playerData.bag_ver then
        ret.items = playerData.bag_items
    end
    
    gg.network_channel:fireClient(uin, ret)
end

---使用物品
---@param uin number 玩家ID
---@param bagId number 背包格子ID
---@return boolean 是否成功
function ItemOperator:useItem(uin, bagId)
    local playerData = self:getPlayerBagData(uin)
    local index = playerData.bag_index[bagId]
    
    if not index or not index.uuid then
        return false
    end
    
    local itemData = playerData.bag_items[index.uuid]
    if not itemData then
        return false
    end
    
    -- 创建物品对象
    local itype = itemData.itype
    -- 根据分类创建不同的物品对象
    gg.log("itemData",itemData)
    local item = nil
    if itype == common_const.ITEM_TYPE.EQUIPMENT then
        item = EquipmentItem.fromData(itemData)
    elseif itype == common_const.ITEM_TYPE.CONSUMABLE or itype == common_const.ITEM_TYPE.BOX then
        item = ConsumableItem.fromData(itemData)
    elseif itype == common_const.ITEM_TYPE.MAT then
        item= MaterialItem.fromData(itemData)
    elseif itype == common_const.ITEM_TYPE.CARD then
        item= CardItem.fromData(itemData)
    else
        item = ItemBase.fromData(itemData)
    end
    
    -- 检查物品是否可使用
    if not item:canUse() then
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
    local success, message = item:onUse(player)
    
    if success then
        -- 处理使用后的物品状态
        --- and not item.is_reusable
        if item.itype == common_const.ITEM_TYPE.BOX or 
           (item.itype == common_const.ITEM_TYPE.CONSUMABLE ) then
            -- 消耗型物品使用后消失
            if item.num and item.num > 1 then
                -- 堆叠物品减少数量
                item.num = item.num - 1
                playerData.bag_items[index.uuid] = item:serialize()
            else
                -- 移除物品
                playerData.bag_items[index.uuid] = nil
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
            color = item:getQualityColor() 
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
    local index = playerData.bag_index[bagId]
    
    if not index or not index.uuid then
        return false
    end
    
    local item = playerData.bag_items[index.uuid]
    if not item or item.itype ~= common_const.ITEM_TYPE.EQUIPMENT then
        gg.network_channel:fireClient(uin, { 
            cmd = "cmd_client_show_msg", 
            txt = '这件物品无法被分解' 
        })
        return false
    end
    
    -- 执行分解
    playerData.bag_index[bagId] = nil
    playerData.bag_items[index.uuid] = nil
    
    -- 计算获得的材料数量
    local matQuality = 1         -- 1=魔力碎片  2=神力碎片
    local matNum = item.quality * item.level
    
    -- 尝试合并到已有材料
    local materialUpdated = false
    local baseId = 10000
    for i = 0, playerData.bag_size - 1 do
        local currBagId = baseId + i
        local tmpItem = playerData.bag_index[currBagId]
        if tmpItem and tmpItem.uuid then
            local tmpItemDetail = playerData.bag_items[tmpItem.uuid]
            
            if tmpItemDetail and 
               tmpItemDetail.itype == common_const.ITEM_TYPE.MAT and
               tmpItemDetail.mat_id == common_const.MAT_ID.FRAGMENT and
               tmpItemDetail.quality == matQuality then
                -- 增加已有材料的数量
                tmpItemDetail.num = tmpItemDetail.num + matNum
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
        playerData.bag_items[material.uuid] = material
        playerData.bag_index[bagId] = { uuid = material.uuid }
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
        if playerData.bag_index[bagId] then
            local tmpItem = playerData.bag_index[bagId]
            local tmpUuid = tmpItem.uuid
            local tmpItemDetail = playerData.bag_items[tmpUuid]
            
            if tmpItemDetail and
               tmpItemDetail.itype == common_const.ITEM_TYPE.MAT and
               tmpItemDetail.mat_id == common_const.MAT_ID.FRAGMENT and
               tmpItemDetail.quality == matQuality then
                
                if tmpItemDetail.num < 800 then
                    num = tmpItemDetail.num
                    gg.network_channel:fireClient(uin, { 
                        cmd = "cmd_btn_compose_ret", 
                        msg = "no_enough", 
                        num = num 
                    })
                    return false, "材料不足"
                else
                    -- 扣除材料
                    tmpItemDetail.num = tmpItemDetail.num - 800
                    num = tmpItemDetail.num
                    matBagId = bagId
                    
                    if tmpItemDetail.num == 0 then
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
    
    playerData.bag_items[box.uuid] = box
    playerData.bag_index[emptyBagId] = { uuid = box.uuid }
    
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

---交换物品位置
---@param uin number 玩家ID
---@param pos1 number 位置1
---@param pos2 number 位置2
---@return boolean 是否成功
function ItemOperator:swapItems(uin, pos1, pos2)
    local playerData = self:getPlayerBagData(uin)
    
    local pos1Data = playerData.bag_index[pos1]
    local pos2Data = playerData.bag_index[pos2]
    
    -- 检查装备位置匹配
    if gg.isWearPos(pos2) and pos1Data and pos1Data.uuid then
        local item = playerData.bag_items[pos1Data.uuid]
        if item and item.pos ~= pos2 then
            gg.network_channel:fireClient(uin, { 
                cmd = "cmd_client_show_msg", 
                txt = '该物品不能穿戴在这里', 
                color = ColorQuad.new(255, 0, 0, 255) 
            })
            return false
        end
    end
    
    -- 交换位置
    playerData.bag_index[pos1] = pos2Data
    playerData.bag_index[pos2] = pos1Data
    
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

---批量使用所有宝箱
---@param uin number 玩家ID
---@return boolean 是否成功
function ItemOperator:useAllBoxes(uin)
    local playerData = self:getPlayerBagData(uin)
    local count = 0
    
    for bagId, v in pairs(playerData.bag_index) do
        local uuid = v.uuid
        local item = playerData.bag_items[uuid]
        
        if item and item.itype == common_const.ITEM_TYPE.BOX then
            -- 删除宝箱
            playerData.bag_items[uuid] = nil
            count = count + 1
            
            -- 创建随机装备替换宝箱
            local eq = eqGen.createRandEquipment({ 
                quality = item.quality, 
                level = item.level 
            })
            
            playerData.bag_items[eq.uuid] = eq
            playerData.bag_index[bagId] = { uuid = eq.uuid }
            
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
    for bagId, v in pairs(playerData.bag_index) do
        if bagId >= 10000 then
            local uuid = v.uuid
            local item = playerData.bag_items[uuid]
            
            if item and item.itype == common_const.ITEM_TYPE.EQUIPMENT and item.quality < 4 then
                -- 删除装备
                playerData.bag_index[bagId] = nil
                playerData.bag_items[uuid] = nil
                
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
            playerData.bag_items[matItem.uuid] = matItem
            playerData.bag_index[firstBagId] = { uuid = matItem.uuid }
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
            gg.log("背包物品数据",item)
            -- 加入背包
            playerData.bag_items[item.uuid] = item
            playerData.bag_index[bagId] = { uuid = item.uuid }
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