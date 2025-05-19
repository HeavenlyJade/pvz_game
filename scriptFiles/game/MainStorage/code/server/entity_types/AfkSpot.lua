local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Npc = require(MainStorage.code.server.entity_types.Npc) ---@type Npc
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class AfkSpot:Npc
---@field interval number 间隔时间
---@field spells table 定时释放魔法列表
---@field lastCastTime number 上次释放时间
---@field activePlayer Player|nil 当前激活的玩家
---@field timerId number|nil 定时器ID
local AfkSpot = ClassMgr.Class("AfkSpot", Npc)

function AfkSpot:OnInit(data, actor)
    Npc.OnInit(self, data, actor)
    self.interval = data["间隔时间"] or 10
    self.subSpells = {}
    if data["定时释放魔法"] then
        for _, subSpellData in ipairs(data["定时释放魔法"]) do
            local subSpell = SubSpell.New(subSpellData)
            table.insert(self.subSpells, subSpell)
        end
    end
    self.lastCastTime = 0
    self.activePlayer = nil
    self.timerId = nil
end

--- 检查是否可以进入挂机点
---@param player Player 玩家
---@return boolean 是否可以进入
function AfkSpot:CanEnter(player)
    if not self.interactCondition then return true end
    local param = self.interactCondition:Check(player, self)
    return not param.cancelled
end

--- 玩家进入挂机点
---@param player Player 玩家
function AfkSpot:OnPlayerEnter(player)
    -- 传送玩家到挂机点位置
    local pos = self.actor.Position
    player:SetPosition(pos)
    
    -- 开始定时释放魔法
    self:StartSpellTimer(player)
end

--- 开始定时释放魔法
---@param player Player 玩家
function AfkSpot:StartSpellTimer(player)
    -- 停止之前的定时器
    if self.timerId then
        ServerScheduler.cancel(self.timerId)
        self.timerId = nil
    end
    
    -- 创建新的定时器
    self.timerId = ServerScheduler.add(function()
        self:CastSpells(player)
    end, 0, self.interval, true) -- 立即开始，每隔interval秒执行一次
end

--- 释放魔法
---@param player Player 玩家
function AfkSpot:CastSpells(player)
    for _, subSpell in ipairs(self.subSpells) do
        subSpell:Cast(player, player)
    end
end

--- 处理NPC交互
---@param player Player 玩家
function AfkSpot:HandleInteraction(player)
    -- 先调用父类的交互处理
    Npc.HandleInteraction(self, player)
    
    -- 检查是否可以进入挂机点
    if self:CanEnter(player) then
        self.activePlayer = player
        self:OnPlayerEnter(player)
    end
end

--- 更新NPC状态
function AfkSpot:update_npc()
    -- 如果有激活的玩家，检查是否离开范围
    if self.activePlayer then
        local pos = self.actor.Position
        local playerPos = self.activePlayer:GetPosition()
        if gg.fast_out_distance(pos, playerPos, 200) then
            -- 玩家离开范围，停止定时器
            if self.timerId then
                ServerScheduler.cancel(self.timerId)
                self.timerId = nil
            end
            self.activePlayer = nil
        end
    end
    
    -- 调用父类的更新
    -- Npc.update_npc(self)
end

return AfkSpot 