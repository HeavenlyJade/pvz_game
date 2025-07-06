--- nnpc

local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local ColorQuad    = ColorQuad
local game         = game


local MainStorage        = game:GetService("MainStorage")
local gg                 = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config      = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const       = require(MainStorage.code.common.MConst) ---@type common_const
local ClassMgr           = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Modifiers          = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
local Entity             = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler    = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler

---@class TriggerZone:Entity    --NPC类 (单个Npc) (管理NPC状态)
---@field New fun(TriggerZone: TriggerZone, actor: SandboxNode):TriggerZone
---@field npc_config any
local _M = ClassMgr.Class('TriggerZone', Entity) --父类Entity

-- 存储未初始化玩家的触发区域
local pendingTriggerZones = {}

---@param TriggerZone TriggerZone
---@param actor Actor
function _M:OnInit(TriggerZone, actor)
    self.spawnPos          = actor.LocalPosition
    self.actor             = actor ---@type TriggerBox
    local trigger = actor
    self.name              = TriggerZone["名字"]
    self.interactCondition = Modifiers.New(TriggerZone["触发条件"])
    self.pendingLeavePlayers = {} -- 存储待移除的玩家
    
    -- 处理指令字符串，将单引号替换为双引号
    local function processCommands(commands)
        if not commands then return nil end
        local processed = {}
        for i, cmd in ipairs(commands) do
            if type(cmd) == "string" then
                processed[i] = cmd:gsub("'", '"')
            else
                processed[i] = cmd
            end
        end
        return processed
    end
    
    self.enterCommands     = processCommands(TriggerZone["进入指令"])
    self.leaveCommands     = processCommands(TriggerZone["离开指令"])
    self.periodicCommands  = processCommands(TriggerZone["定时指令"])
    self.periodicInterval  = TriggerZone["定时间隔"] or 1  -- 默认1秒
    self.periodicTaskKey   = nil  -- 存储定时任务的key
    self.target            = nil
    self.playersInZone     = {}  -- 记录在区域内的玩家
    self.enterLeaveCooldown = TriggerZone["进入离开冷却"] or 0.5 -- 新增：进入/离开指令冷却，默认0.5秒
    self.enterLeaveCooldownMap = {} -- 新增：每个玩家的冷却到期时间

    -- 如果有定时指令，创建定时任务
    if self.periodicCommands then
        self.periodicTaskKey = ServerScheduler.add(function()
            for _, player in pairs(self.playersInZone) do
                player:ExecuteCommands(self.periodicCommands)
            end
        end, self.periodicInterval, self.periodicInterval)
    end

    -- 监听触发器被触碰
    trigger.Touched:Connect(function(node)
        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                -- 如果玩家未初始化完成，缓存触发区域
                if not player.inited then
                    if not pendingTriggerZones[player.uuid] then
                        pendingTriggerZones[player.uuid] = {}
                    end
                    pendingTriggerZones[player.uuid][self.uuid] = self
                    -- print(string.format("[TriggerZone] 玩家 %s 未初始化完成，缓存触发区域 %s", player.name or player.uuid, self.name or self.uuid))
                    return
                end

                -- 如果玩家在待移除列表中，不做任何事
                if self.pendingLeavePlayers[player.uuid] then
                    self.pendingLeavePlayers[player.uuid] = nil
                    -- print(string.format("[TriggerZone] 玩家 %s 在待移除列表中，取消离开处理", player.name or player.uuid))
                    return
                end
                -- 只有当玩家不在区域内时才执行进入逻辑
                if not self.playersInZone[player.uuid] then
                    -- print(string.format("[TriggerZone] 玩家 %s 进入触发区域 %s", player.name or player.uuid, self.name or self.uuid))
                    -- 冷却判定
                    local cd_key = "TriggerZone:" .. self.uuid .. ":enter"
                    if self.enterCommands and player:GetCooldown(cd_key) <= 0 then
                        player:ExecuteCommands(self.enterCommands)
                        player:SetCooldown(cd_key, self.enterLeaveCooldown)
                    end
                    -- 记录玩家进入
                    self.playersInZone[player.uuid] = player
                    -- print(string.format("[TriggerZone] 玩家 %s 已记录进入触发区域", player.name or player.uuid))
                else
                    -- print(string.format("[TriggerZone] 玩家 %s 已在触发区域 %s 内", player.name or player.uuid, self.name or self.uuid))
                end
            end
        end
    end)

    -- 监听触发器触碰结束
    trigger.TouchEnded:Connect(function(node)
        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                -- 如果玩家未初始化完成，不做任何处理
                if not player.inited then
                    -- print(string.format("[TriggerZone] 玩家 %s 未初始化完成，跳过离开处理", player.name or player.uuid))
                    return
                end
                if self.pendingLeavePlayers[player.uuid] then
                    return
                end
                self.pendingLeavePlayers[player.uuid] = player
                -- print(string.format("[TriggerZone] 玩家 %s 离开触发区域 %s，加入待移除列表", player.name or player.uuid, self.name))
                ServerScheduler.add(function()
                    -- 如果玩家仍在待移除列表中（说明期间没有重新触发Touched）
                    if self.pendingLeavePlayers[player.uuid] then
                        -- print(string.format("[TriggerZone] 确认玩家 %s 离开触发区域 %s，执行离开指令", player.name or player.uuid, self.name or self.uuid))
                        -- 冷却判定
                        local cd_key = "TriggerZone:" .. self.uuid .. ":leave"
                        if self.leaveCommands and player:GetCooldown(cd_key) <= 0 then
                            player:ExecuteCommands(self.leaveCommands)
                            player:SetCooldown(cd_key, self.enterLeaveCooldown)
                        end
                        -- 移除玩家记录
                        self.playersInZone[player.uuid] = nil
                        self.pendingLeavePlayers[player.uuid] = nil
                        -- print(string.format("[TriggerZone] 玩家 %s 已从触发区域移除", player.name or player.uuid))
                    else
                        -- print(string.format("[TriggerZone] 玩家 %s 在延迟期间重新进入，取消离开处理", player.name or player.uuid))
                    end
                end, 0.1)
            end
        end
    end)

    -- 监听玩家初始化完成事件
    ServerEventManager.Subscribe("PlayerInited", function(evt)
        local player = evt.player
        if pendingTriggerZones[player.uuid] then
            for _, zone in pairs(pendingTriggerZones[player.uuid]) do
                -- 执行进入指令
                if zone.enterCommands then
                    player:ExecuteCommands(zone.enterCommands, nil, true)
                end
                -- 记录玩家进入
                zone.playersInZone[player.uuid] = player
            end
            -- 清除缓存的触发区域
            pendingTriggerZones[player.uuid] = nil
        end
    end)

    self:createTitle()
end

_M.GenerateUUID = function(self)
    self.uuid = gg.create_uuid('u_Zone')
end

---更新NPC状态
function _M:update_npc()
    -- 不再需要在这里处理定时指令
end

function _M:DestroyObject()
    Entity.DestroyObject(self)
    if self.periodicTaskKey then
        ServerScheduler.cancel(self.periodicTaskKey)
        self.periodicTaskKey = nil
    end
end

return _M;
