--- nnpc

local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local ColorQuad    = ColorQuad
local game         = game


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local ClassMgr      = require(MainStorage.code.common.ClassMgr)    ---@type ClassMgr
local Modifiers      = require(MainStorage.code.common.config_type.modifier.Modifiers)    ---@type Modifiers
local Entity   = require(MainStorage.code.server.entity_types.Entity)    ---@type Entity

---@class Npc:Entity    --NPC类 (单个Npc) (管理NPC状态)
---@field New fun(npcData: NpcData, actor: SandboxNode) Npc
---@field npc_config any
local _M = ClassMgr.Class('Npc', Entity)        --父类Entity


---@param npcData NpcData
---@param actor Actor
function _M:OnInit(npcData, actor)
    Entity:OnInit(npcData)    --父类初始化
    self.spawnPos = actor.LocalPosition
    self.actor = actor
    self.name = npcData["名字"]
    self.interactCondition = Modifiers.New(npcData["互动条件"])
    self.interactCommands = npcData["互动指令"]
    self.interactIcon = npcData["互动图标"]
    self.uuid = gg.create_uuid('npc')
    self.target = nil
    
    -- 创建交互触发器
    local trigger = SandboxNode.new('TriggerBox', actor) ---@type TriggerBox
    -- 获取NPC模型尺寸
    local npcSize = actor.Size
    
    -- 设置触发器尺寸，在NPC模型周围扩展一定范围
    trigger.LocalPosition = actor.Center
    trigger.Size = Vector3.New(400 + math.max(npcSize.x, npcSize.z), 200, 400 + math.max(npcSize.x, npcSize.z)) -- 扩展范围
    trigger.KinematicAble = false -- 不需要运动能力
    trigger.GravityAble = false -- 不需要重力
    
    -- 监听触发器被触碰
    trigger.Touched:Connect(function(node)
        print("Touched", self.name, node.Name)

        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                self:SetTarget(player)
                -- 将NPC添加到玩家的附近NPC列表中
                player:AddNearbyNpc(self)
            end
        end
    end)
    
    -- 监听触发器触碰结束
    trigger.TouchEnded:Connect(function(node)
        if node and node.UserId then
            local player = gg.getPlayerByUin(node.UserId)
            if player then
                if self.target == player then
                    self:SetTarget(nil)
                end
                -- 从玩家的附近NPC列表中移除
                player:RemoveNearbyNpc(self)
            end
        end
    end)
    
    -- 创建NPC头顶标题
    self:createTitle(npcSize[1])
end

---设置NPC的目标
---@param target Player|nil
function _M:SetTarget(target)
    self.target = target
end

---更新NPC状态
function _M:update_npc()
    -- 如果有目标，持续看向目标
    if self.target then
        self.actor:LookAtObject(self.target.actor)
    end
end

return _M;