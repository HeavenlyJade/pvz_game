--- 玩家属性相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)  ---@type MCloudDataMgr

---@class PlayerCommands
local PlayerCommands = {}

-- 命令执行器工厂
local CommandExecutors = {}

-- 设置玩家属性执行器
function CommandExecutors.SetPlayerAttribute(params, player)
    if params.category == "等级" then
        -- 设置玩家等级
        local level = tonumber(params.value)
        
        -- 限制等级范围
        level = math.max(1, math.min(level, 100))
        
        player.level = level
        player:resetBattleData(true)
        player:rsyncData(1)
        
        -- 保存到云端
        cloudDataMgr.savePlayerData(player.uin, true)
        
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "等级已设置为 " .. level,
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        return true
    elseif params.category == "经验" then
        -- 设置玩家经验值
        local exp = tonumber(params.value)
        player.exp = exp
        player:rsyncData(2)
        
        -- 保存到云端
        cloudDataMgr.savePlayerData(player.uin, true)
        
        return true
    elseif params.category == "声望" then
        -- 设置玩家声望
        local faction = params.subcategory
        local value = tonumber(params.value)
        
        player:SetReputation(faction, value)
        
        return true
    elseif params.category == "属性" then
        -- 设置玩家属性值
        local attrName = params.subcategory
        local value = tonumber(params.value)
        
        if player.battle_data[attrName] ~= nil then
            player.battle_data[attrName] = value
            player:rsyncData(1)
            return true
        else
            gg.log("未知属性名: " .. attrName)
            return false
        end
    end
    
    return false
end

-- 增加玩家属性执行器
function CommandExecutors.AddPlayerAttribute(params, player)
    if params.category == "经验" then
        -- 增加经验值
        local exp = tonumber(params.value)
        player:addExp(exp)
        
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获得经验值 +" .. exp,
            color = ColorQuad.new(0, 255, 0, 255)
        })
        
        return true
    elseif params.category == "金币" then
        -- 增加金币
        local gold = tonumber(params.value)
        player:AddGold(gold)
        
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获得金币 +" .. gold,
            color = ColorQuad.new(255, 215, 0, 255)
        })
        
        return true
    end
    
    return false
end

-- 修改玩家属性执行器
function CommandExecutors.ModifyPlayerAttribute(params, player)
    if params.category == "属性" then
        local attrName = params.subcategory
        local value = params.value
        
        -- 支持增加/减少语法
        if string.sub(value, 1, 1) == "+" then
            local amount = tonumber(string.sub(value, 2))
            if player.battle_data[attrName] ~= nil then
                player.battle_data[attrName] = player.battle_data[attrName] + amount
                player:rsyncData(1)
                
                -- 通知客户端
                gg.network_channel:fireClient(player.uin, {
                    cmd = "cmd_client_show_msg",
                    txt = attrName .. " +" .. amount,
                    color = ColorQuad.new(0, 255, 0, 255)
                })
                
                return true
            end
        elseif string.sub(value, 1, 1) == "-" then
            local amount = tonumber(string.sub(value, 2))
            if player.battle_data[attrName] ~= nil then
                player.battle_data[attrName] = player.battle_data[attrName] - amount
                player:rsyncData(1)
                
                -- 通知客户端
                gg.network_channel:fireClient(player.uin, {
                    cmd = "cmd_client_show_msg",
                    txt = attrName .. " -" .. amount,
                    color = ColorQuad.new(255, 0, 0, 255)
                })
                
                return true
            end
        else
            -- 设置为特定值
            local amount = tonumber(value)
            if player.battle_data[attrName] ~= nil then
                player.battle_data[attrName] = amount
                player:rsyncData(1)
                return true
            end
        end
        
        gg.log("未知属性名: " .. attrName)
        return false
    end
    
    return false
end

-- 命令映射表
local CommandMapping = {
    ["设置"] = CommandExecutors.SetPlayerAttribute,
    ["增加"] = CommandExecutors.AddPlayerAttribute,
    ["修改"] = CommandExecutors.ModifyPlayerAttribute,
}

-- 命令执行函数
function PlayerCommands.Execute(command, params, player)
    local executor = CommandMapping[command]
    if not executor then
        gg.log("未知玩家命令: " .. command)
        return false
    end
    
    return executor(params, player)
end

-- 兼容旧版接口
PlayerCommands.handlers = {}
for command, executor in pairs(CommandMapping) do
    PlayerCommands.handlers[command] = executor
end

return PlayerCommands