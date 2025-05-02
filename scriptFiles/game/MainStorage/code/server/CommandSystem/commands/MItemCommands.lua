--- 物品相关命令处理器
--- 

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local bagMgr = require(MainStorage.code.server.bag.MBagMgr)  ---@type BagMgr
local common_const = require(MainStorage.code.common.MConst)  ---@type common_const
local battleMgr = require(MainStorage.code.server.BattleMgr)  ---@type BattleMgr

---@class ItemCommands
local ItemCommands = {}

-- 命令执行函数
local function addItem(params, player)
    if params.category == "物品" then
        if params.subcategory == "随机装备" then
            -- 添加随机装备
            local quality = params.id
            local level = tonumber(params.action)
            local count = tonumber(params.value)
            
            for i = 1, count do
                local itemId = bagMgr.GenerateRandomEquipment(quality, level)
                player:AddItem("装备", itemId, 1)
            end
            
            -- 通知客户端
            gg.network_channel:fireClient(player.uin, {
                cmd = "cmd_client_show_msg",
                txt = "获得 " .. quality .. " 级别装备 x" .. count,
            })
            
            return true
        else
            -- 添加指定物品
            local itemType = params.subcategory  -- 装备, 消耗品, 材料, 任务物品
            local itemId = tonumber(params.id)
            local count = tonumber(params.value)
            
            local success = player:AddItem(itemType, itemId, count)
            
            if success then
                -- 获取物品名称
                local itemName = bagMgr.GetItemName(itemType, itemId)
                
                -- 通知客户端
                gg.network_channel:fireClient(player.uin, {
                    cmd = "cmd_client_show_msg",
                    txt = "获得 " .. itemName .. " x" .. count,
                })
                
                -- 刷新客户端背包
                bagMgr.s2c_PlayerBagItems(player.uin, {})
            end
            
            return success
        end
    end
    
    return false
end

local function reduceItem(params, player)
    if params.category == "物品" then
        local itemType = params.subcategory  -- 装备, 消耗品, 材料, 任务物品
        local itemId = tonumber(params.id)
        
        if params.value == "全部" then
            -- 移除所有指定ID的物品
            local count = player:GetItemCount(itemType, itemId)
            player:RemoveItem(itemType, itemId, count)
        else
            -- 移除指定数量的物品
            local count = tonumber(params.value)
            local success = player:RemoveItem(itemType, itemId, count)
            
            if not success then
                -- 物品数量不足
                gg.network_channel:fireClient(player.uin, {
                    cmd = "cmd_client_show_msg",
                    txt = "物品数量不足",
                })
                return false
            end
        end
        
        -- 刷新客户端背包
        bagMgr.s2c_PlayerBagItems(player.uin, {})
        return true
    end
    
    return false
end

local function setItem(params, player)
    if params.category == "物品" then
        local itemType = params.subcategory  -- 装备, 消耗品, 材料, 任务物品
        local itemId = tonumber(params.id)
        
        if params.action == "数量" then
            local targetCount = tonumber(params.value)
            return player:SetItemCount(itemType, itemId, targetCount)
        end
    end
    
    return false
end

local function equipItem(params, player)
    if params.category == "物品" then
        local itemId = tonumber(params.subcategory)
        local slot = params.param  -- 武器, 头盔, 胸甲等
        
        -- 转换部位名称为系统内部的位置ID
        local posId = bagMgr.GetEquipSlotId(slot)
        if not posId then
            gg.log("未知装备位置: " .. slot)
            return false
        end
        
        -- 尝试装备物品
        local success = player:EquipItem(itemId, posId)
        
        if success then
            -- 刷新客户端背包
            bagMgr.s2c_PlayerBagItems(player.uin, {})
            
            -- 重新计算玩家属性
            battleMgr.refreshPlayerAttr(player.uin)
            player:rsyncData(1)
        else
            gg.network_channel:fireClient(player.uin, {
                cmd = "cmd_client_show_msg", 
                txt = "无法装备该物品",
            })
        end
        
        return success
    end
    
    return false
end

local function unequipItem(params, player)
    if params.category == "装备" and params.subcategory == "位置" then
        local slot = params.id  -- 武器, 头盔, 胸甲等
        
        -- 转换部位名称为系统内部的位置ID
        local posId = bagMgr.GetEquipSlotId(slot)
        if not posId then
            gg.log("未知装备位置: " .. slot)
            return false
        end
        
        -- 尝试卸下装备
        local success = player:UnequipItem(posId)
        
        if success then
            -- 刷新客户端背包
            bagMgr.s2c_PlayerBagItems(player.uin, {})
            
            -- 重新计算玩家属性
            battleMgr.refreshPlayerAttr(player.uin)
            player:rsyncData(1)
        end
        
        return success
    end
    
    return false
end

local function enhanceItem(params, player)
    if params.category == "装备" then
        local itemId = tonumber(params.subcategory)
        local levelChange = params.value
        
        if string.sub(levelChange, 1, 1) == "+" then
            -- 提升等级
            local levels = tonumber(string.sub(levelChange, 2))
            local success = player:EnhanceEquipment(itemId, levels)
            
            if success then
                -- 获取装备名称
                local itemName = bagMgr.GetItemNameById(itemId)
                
                -- 通知客户端
                gg.network_channel:fireClient(player.uin, {
                    cmd = "cmd_client_show_msg",
                    txt = itemName .. " 强化成功，提升" .. levels .. "级",
                })
                
                -- 刷新客户端背包
                bagMgr.s2c_PlayerBagItems(player.uin, {})
                
                -- 如果是已装备的装备，重新计算玩家属性
                if player:IsEquipped(itemId) then
                    battleMgr.refreshPlayerAttr(player.uin)
                    player:rsyncData(1)
                end
            else
                gg.network_channel:fireClient(player.uin, {
                    cmd = "cmd_client_show_msg",
                    txt = "强化失败",
                })
            end
            
            return success
        end
    end
    
    return false
end

-- 命令处理器
ItemCommands.handlers = {
    ["添加"] = addItem,
    ["减少"] = reduceItem,
    ["设置"] = setItem,
    ["装备"] = equipItem,
    ["卸下"] = unequipItem,
    ["强化"] = enhanceItem,
}

return ItemCommands