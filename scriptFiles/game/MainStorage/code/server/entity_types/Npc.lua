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

---@class Npc:Entity    --NPC类 (单个Npc) (管理NPC状态)
---@field New fun(npcData: NpcData, actor: SandboxNode) Npc
---@field npc_config any
local _M                 = ClassMgr.Class('Npc', Entity) --父类Entity


---@param npcData NpcData
---@param actor Actor
function _M:OnInit(npcData, actor)
    Entity:OnInit(npcData) --父类初始化
    self.spawnPos          = actor.LocalPosition
    self.actor             = actor
    self.name              = npcData["名字"]
    self.interactCondition = Modifiers.New(npcData["互动条件"])
    self.interactCommands  = npcData["互动指令"]
    self.interactIcon      = npcData["互动图标"]
    self.uuid              = gg.create_uuid('npc')
    self.target            = nil
    actor.Size             = Vector3.new(120, 160, 120) --touch盒子的大小
    actor.Center           = Vector3.new(0, 80, 0)     --盒子中心位置
    actor.CubeBorderEnable = true                      --debug显示碰撞方块
    
    -- 初始化gg.npcs如果不存在
    if not gg.npcs then
        gg.npcs = {}
    end
    
    -- 将当前NPC实例存储到全局表中
    gg.npcs[self.uuid] = self
    
    gg.log("Npc初始化", self.name, self.uuid)
    gg.log("Npc对象", actor)
    actor.Size    = Vector3.new(120, 160, 120)         --touch盒子的大小
    actor.Center  = Vector3.new(0, 80, 0)              --盒子中心位置
    local npcSize = actor.Size
    -- 创建交互触发器
    -- local trigger         = SandboxNode.new('TriggerBox', actor) ---@type TriggerBox
    -- -- 获取NPC模型尺寸
    -- local npcSize         = actor.Size

    -- -- 设置触发器尺寸，在NPC模型周围扩展一定范围
    -- trigger.LocalPosition = actor.Center
    -- trigger.Size          = Vector3.New(400 + math.max(npcSize.x, npcSize.z), 200,
    --     400 + math.max(npcSize.x, npcSize.z))                                                               -- 扩展范围

    -- -- 监听触发器被触碰
    -- trigger.Touched:Connect(function(node)
    --     print("Touched", self.name, node.Name)

    --     if node and node.UserId then
    --         local player = gg.getPlayerByUin(node.UserId)
    --         if player then
    --             self:SetTarget(player)
    --             -- 将NPC添加到玩家的附近NPC列表中
    --             player:AddNearbyNpc(self)
    --         end
    --     end
    -- end)

    -- -- 监听触发器触碰结束
    -- trigger.TouchEnded:Connect(function(node)
    --     print("TouchEnded", self.name, node.Name)
    --     if node and node.UserId then
    --         local player = gg.getPlayerByUin(node.UserId)
    --         if player then
    --             if self.target == player then
    --                 self:SetTarget(nil)
    --             end
    --             -- 从玩家的附近NPC列表中移除
    --             player:RemoveNearbyNpc(self)
    --         end
    --     end
    -- end)
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
    self:createTitle(npcSize[1])


end

function _M:setupNpcInteraction(actor,npcInstance)
    local npc_name = self.name
    gg.log('NP区域', npc_name, actor)
    actor.CubeBorderEnable = true --debug显示碰撞方块
    -- 获取区域和模型属性
    local interactArea = SandboxNode.new('Area', actor)
    local npcSize = actor.Size
    local centerPos = actor.Position
    local expand = Vector3.new(150, 100, 150)
    -- 设置区域范围
    interactArea.Beg = centerPos - (npcSize / 2 + expand)
    interactArea.End = centerPos + (npcSize / 2 + expand)
    -- 区域外观（调试用）
    interactArea.Show = true -- 正式环境设为false
    interactArea.Color = ColorQuad.new(0, 255, 0, 50)
    interactArea.EffectWidth = 1

    -- 创建客户端事件处理
    gg.log("NPC实例", npcInstance)
    local function handlePlayerInteraction(node, isEntering)
        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                -- 详细的日志输出，用于调试
                
                if isEntering then
                    npcInstance:SetTarget(player)
                    -- 将NPC添加到玩家的附近NPC列表中
                    player:AddNearbyNpc(npcInstance)
                else
                    if npcInstance.target == player then
                        npcInstance:SetTarget(nil)
                    end
                    player:RemoveNearbyNpc(npcInstance)
                end
            end
        end
    end

    -- 注册区域事件
    interactArea.EnterNode:connect(function(node)
        handlePlayerInteraction(node, true) -- 玩家进入
    end)

    interactArea.LeaveNode:connect(function(node)
        handlePlayerInteraction(node, false) -- 玩家离开
    end)

    return interactArea
end

---设置NPC的目标
---@param target Player|nil
function _M:SetTarget(target)
    -- gg.log("NPC设置目标", self.name, self.uuid, target and target.name or "nil")
    self.target = target
end

---更新NPC状态
function _M:update_npc()
    -- 如果有目标，持续看向目标
    if self.target then
        -- gg.log("NPC看向目标", self.name, self.target.name,self.target.actor,self.target.position)
        -- self.actor:LookAtObject(self.target.position)
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
        for _, command in ipairs(self.interactCommands) do
            player:ExecuteCommand(command)
        end
    end

    -- 发布NPC交互事件
    ServerEventManager.Publish("NpcInteractionEvent", {
        player = player,
        npc = self
    })
end

return _M;
