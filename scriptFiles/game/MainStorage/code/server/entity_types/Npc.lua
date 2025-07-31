local MainStorage        = game:GetService("MainStorage")
local gg                 = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr           = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Modifiers          = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
local Entity             = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler    = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler

---@class Npc:Entity    --NPC类 (单个Npc) (管理NPC状态)
---@field New fun(npcData: NpcData, actor: SandboxNode) Npc
---@field npc_config any
local _M                 = ClassMgr.Class('Npc', Entity) --父类Entity

---处理玩家进入触发器
---@param player Player 玩家
function _M:OnPlayerTouched(player)
    self:SetTarget(player)
    if self.className ~= "Npc" or (self.interactCommands and #self.interactCommands >0) then
        player:AddNearbyNpc(self)
    end
    -- 将玩家添加到附近玩家列表
    self.nearbyPlayers[player.uuid] = player
    
    -- 为该玩家更新NPC节点变量
    self:UpdateNodeVariablesForPlayer(player)
end

---@param npcData NpcData
---@param actor Actor
function _M:OnInit(npcData, actor)
    self.spawnPos          = actor.LocalPosition
    self:setGameActor(actor)
    self.name              = npcData["名字"]
    self.displayName              = npcData["显示名"] or self.name
    self.interactCondition = npcData["互动条件"]
    self.interactCommands  = npcData["互动指令"]
    self.interactIcon      = npcData["互动图标"]
    self.extraSize      = gg.Vec3.new(npcData["额外互动距离"]) or gg.Vec3.new(0,0)
    self.lookAtNearbyPlayer = npcData["看向附近玩家"] or false
    self.nameSize = npcData["名字尺寸"]
    self.target = nil
    self.actor = actor
    self.nearbyPlayers = {} -- 存储附近玩家的列表
    
    -- 实体节点变量修改配置
    self.nodeVariables = npcData["实体节点变量修改"] or {}
    
    local npcSize = Vector3.New(0,0,0)
    if actor:IsA("Actor") then
        actor.CollideGroupID   = 1
        if npcData["状态机"] then
            self:SetAnimationController(npcData["状态机"])
        end
        npcSize = actor.Size
        self:CreateTitle()
        -- local startPos = actor:GetAttribute("初始位置")
        -- if startPos then
        --     actor.Position = startPos
        --     gg.log("SetStartPos", self.name, startPos)
        -- end
    end
    local trigger         = SandboxNode.new('TriggerBox', actor) ---@type TriggerBox
    trigger.LocalPosition = self.actor.Center
    trigger.Size = Vector3.New(self.extraSize.x + npcSize.x, self.extraSize.y + npcSize.y, self.extraSize.z + npcSize.z)                                                               -- 扩展范围
    trigger.Touched:Connect(function(node)
        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                self:OnPlayerTouched(player)
            end
        end
    end)

    trigger.TouchEnded:Connect(function(node)
        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                if self.target == player then
                    self:SetTarget(nil)
                end
                -- 从玩家的附近NPC列表中移除·
                player:RemoveNearbyNpc(self)
                -- 从NPC的附近玩家列表中移除
                self.nearbyPlayers[player.uuid] = nil
            end
        end
    end)

    -- 添加定时任务，每秒检查玩家是否还在交互区域内·
    self.checkTaskId = ServerScheduler.add(function()
        self:CheckNearbyPlayers()
    end, 1, 1, "npc_check_" .. self.uuid)

    -- 注册NPC交互事件处理器
    ServerEventManager.Subscribe("InteractWithNpc", function(evt)
        local player = evt.player
        local npcId = evt.npcId
        -- 查找NPC
        if self.uuid == npcId then
            -- 检查玩家是否在NPC附近
            if player.nearbyNpcs[npcId] then
                self:HandleInteraction(player)
            else
                player:SendHoverText("距离太远，无法交互")
            end
        end
    end)
end

function _M:GetInteractName(player)
    return self.name
end

_M.GenerateUUID = function(self)
    self.uuid = gg.create_uuid('u_Npc')
end

---设置NPC的目标
---@param target Player|nil
function _M:SetTarget(target)
    self.target = target
end

function _M:CreateTitle(name)
    -- 调用父类的CreateTitle方法
    -- 参数：nameOverride, scale, barNameOverride
    Entity.CreateTitle(self, self.displayName, self.nameSize, "Npc")
end

---更新NPC状态
function _M:update_npc()
    -- 如果有目标，持续看向目标
    if self.lookAtNearbyPlayer and self.target then
        self.actor:LookAt(self.target:GetPosition(), true)
    end
end

---为特定玩家更新实体节点变量
---@param player Player 要检查的玩家
function _M:UpdateNodeVariablesForPlayer(player)
    if not self.nodeVariables or not next(self.nodeVariables) then
        return
    end
    
    local variableUpdates = {} -- 收集所有有效的变量更新
    
    -- 遍历所有需要检查的变量
    for variableName, variableConfig in pairs(self.nodeVariables) do
        local condition = variableConfig["值的条件"] ---@type Modifiers
        local variableType = variableConfig["变量类型"]
        
        if condition then
            -- 使用指定玩家检查条件
            local param = condition:Check(player, self)
            local newValue = self:GetVariableValue(param, variableType)
            
            -- 跳过nil值
            if newValue ~= nil then
                variableUpdates[variableName] = {
                    value = newValue,
                    variableType = variableType
                }
            end
        end
    end
    
    -- 如果有变量需要更新，发送批量更新事件
    if next(variableUpdates) then
        self:SendNodeVariablesBatchUpdateToPlayer(player, variableUpdates)
    end
end

---向特定玩家发送节点变量批量更新事件
---@param player Player 目标玩家
---@param variableUpdates table<string, {value: any, variableType: string}> 变量更新数据
function _M:SendNodeVariablesBatchUpdateToPlayer(player, variableUpdates)
    if not self.actor or not next(variableUpdates) then
        return
    end
    
    -- 获取NPC节点的完整路径
    local nodePath = gg.GetFullPath(self.actor)
    
    local eventData = {
        nodePath = nodePath,
        variables = variableUpdates, -- 包含所有变量的键值对
        npcUuid = self.uuid,
        npcName = self.name
    }
    
    -- 只向指定玩家发送事件
    player:SendEvent("UpdateNpcNodeVariables", eventData)
end

---向特定玩家发送节点变量更新事件（单个变量，保留用于向后兼容）
---@param player Player 目标玩家
---@param variableName string 变量名
---@param value any 要设置的值
---@param variableType string 变量类型
function _M:SendNodeVariableUpdateToPlayer(player, variableName, value, variableType)
    if not self.actor then
        return
    end
    
    -- 获取NPC节点的完整路径
    local nodePath = gg.GetFullPath(self.actor)
    
    local eventData = {
        nodePath = nodePath,
        variableName = variableName,
        value = value,
        variableType = variableType,
        npcUuid = self.uuid,
        npcName = self.name
    }
    
    -- 只向指定玩家发送事件
    player:SendEvent("UpdateNpcNodeVariable", eventData)
end

---根据条件结果和变量类型获取应该设置的值
---@param param CastParam 条件是否满足
---@param variableType string 变量类型
---@return any 应该设置的值
function _M:GetVariableValue(param, variableType)
    if variableType == "真假" then
        return not param.cancelled
    elseif variableType == "数字" then
        return param.power
    elseif variableType == "字符串" then
        return param.message
    else
        return nil
    end
end

---检查附近玩家是否还在交互区域内
function _M:CheckNearbyPlayers()
    if not self.actor or not self.actor.Position then
        return
    end

    local npcPos = self.actor.Position
    local interactionRadius = (math.max(self.extraSize.x + self.actor.Size.x, self.extraSize.z + self.actor.Size.z) / 2)^2

    for playerUuid, player in pairs(self.nearbyPlayers) do
        if player and player:GetPosition() then
            local playerPos = player:GetPosition()
            local distance = gg.vec.DistanceSq3(npcPos, playerPos)

            -- 如果玩家距离NPC太远，将其移除
            if distance > interactionRadius then
                if self.target == player then
                    self:SetTarget(nil)
                end
                player:RemoveNearbyNpc(self)
                self.nearbyPlayers[playerUuid] = nil
            end
        else
            -- 如果玩家对象无效，直接移除
            self.nearbyPlayers[playerUuid] = nil
        end
    end
end

---@protected
function _M:DestroyObject()
    -- 取消定时任务
    if self.checkTaskId then
        ServerScheduler.cancel(self.checkTaskId)
        self.checkTaskId = nil
    end
end

-- 处理NPC交互
function _M:HandleInteraction(player)
    -- 检查交互条件
    if self.interactCondition then
        local param = self.interactCondition:Check(player, self)
        if param.cancelled then
            return
        end
    end
    -- 执行交互指令
    if self.interactCommands then
        player:ExecuteCommands(self.interactCommands)
    end

    -- 发布NPC交互事件
    ServerEventManager.Publish("NpcInteractionEvent", {
        player = player,
        npc = self
    })
end

return _M;
