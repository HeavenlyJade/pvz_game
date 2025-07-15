--- TransmitEvent.lua
--- 负责处理通用的客户端传送事件

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

---@class TransmitEvent
local TransmitEvent = {}

--- 初始化传送事件管理器
function TransmitEvent.Init()
    TransmitEvent.RegisterEventHandlers()
end

--- 注册事件处理器
function TransmitEvent.RegisterEventHandlers()
    -- 监听客户端发来的传送请求
    ServerEventManager.Subscribe("RequestPlayerTeleport", TransmitEvent.HandlePlayerTeleport)
    gg.log("客户端传送事件处理函数注册完成")
end

--- 处理客户端的传送请求
---@param evt table 事件数据 { player }
function TransmitEvent.HandlePlayerTeleport(evt)
    if not evt.player or not evt.player.uin then
        gg.log("传送事件错误: 缺少玩家或UIN参数")
        return
    end

    local player = gg.getPlayerByUin(evt.player.uin)
    if not player then
        gg.log("传送事件错误: 找不到玩家对象, uin: " .. tostring(evt.player.uin))
        return
    end

    gg.log("收到玩家 " .. player.name .. " 的传送请求 (脱离卡死)")

    local Level = require(MainStorage.code.server.Scene.Level)
    local MConfig = require(MainStorage.code.common.MConfig)

    local currentLevel = Level.GetCurrentLevel(player)
    if currentLevel and currentLevel.isActive then
        -- 场景一：玩家在关卡中，执行离开关卡的操作
        currentLevel:RemovePlayer(player, false, "脱离卡死")
        player:SendChatText("已成功将您脱离当前关卡。")
        gg.log("玩家 " .. player.name .. " 在关卡中，已执行离开关卡操作。")
    else
        -- 场景二：玩家不在关卡中，执行标准的安全点传送
        local teleportPointId = "g0"
        local teleportPath = MConfig.TeleportPoints[teleportPointId]
        player:SendEvent("AfkSpotUpdate", {enter = false})
        player:ExitBattle()
        if not teleportPath then
            gg.log("错误: 在MConfig中未找到传送点配置: " .. teleportPointId)
            player:SendChatText("错误: 未找到安全传送点，请联系管理员。")
            return
        end

        -- 移除路径开头的 "/"
        if teleportPath:sub(1, 1) == "/" then
            teleportPath = teleportPath:sub(2)
        end

        local teleportNode = gg.GetChild(game.WorkSpace, teleportPath)

        if not teleportNode then
            gg.log("错误: 在场景中未找到传送节点: " .. teleportPath)
            player:SendChatText("错误: 未找到安全传送点，请联系管理员。")
            return
        end

        if player.actor then
            local TeleportService = game:GetService('TeleportService')
            gg.log("正在尝试将玩家 " .. player.name .. " 传送到: ", teleportNode.Position)
            TeleportService:Teleport(player.actor, teleportNode.Position)
            player:SendChatText("已将您传送至安全区域。")
        else
            gg.log("错误: 找不到玩家 " .. player.name .. " 的实体，无法传送。")
        end
    end
end

return TransmitEvent