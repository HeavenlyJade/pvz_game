local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Npc = require(MainStorage.code.server.entity_types.Npc) ---@type Npc
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell
local Entity             = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class AfkSpot:Npc
---@field interval number 间隔时间
---@field spells table 定时释放魔法列表
---@field lastCastTime number 上次释放时间
---@field activePlayers table<Player, number> 当前激活的玩家及其定时器ID
---@field owner Player|nil 当前占用的玩家
---@field occupiedEntity Actor|nil 占用的实体
local AfkSpot = ClassMgr.Class("AfkSpot", Npc)

---@param player Player
local function GetPlayerAfkCount(player)
    local count = 0
    for _, skillId in pairs(player.equippedSkills) do
        local skill = player.skills[skillId]
        if skill.afking then
            count = count + 1
        end
    end
    return count
end

function AfkSpot:CreateTitle(name)
    if self.mode == "副卡" then
        if self.owner then
            local skill = self.owner.skills[self.selectedSkill]
            self.name = skill.skillType.name
            local maxGrowth = skill.skillType:GetMaxGrowthAtLevel(skill.level)
            local growth = skill.growth
            self.showHealthBar = true
            self.maxHealth = maxGrowth
            self.health = growth
            self.level = skill.level
            self:SetVariable("level", skill.level)
            Entity.CreateTitle(self, name, self.nameSize, "AfkSpot")
            if not self._titleRankStar and self.name_level_billboard["星级"] then
                local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
                self._titleRankStar = ViewList.New(self.name_level_billboard["星级"]["星级"])
            end
            self._titleRankStar:SetElementSize(skill.star_level)
            for key, value in pairs(self.name_level_billboard.Children) do
                value.Visible = true
            end
        else
            self.showHealthBar = false
            self.bb_title.Title = ""
            for key, value in pairs(self.name_level_billboard.Children) do
                value.Visible = false
            end
        end
    else
        self.showHealthBar = false
        Entity.CreateTitle(self, name, self.nameSize)
    end
end

function AfkSpot:OnInit(data, actor)
    self.autoInteract = data["自动互动"] or false
    self.interval = data["间隔时间"] or 10
    self.enterCommands     = data["进入指令"]
    self.leaveCommands     = data["离开指令"]
    self.periodicCommands  = data["定时指令"]
    self.mode = data["模式"] or "副卡"
    self.growthPerSecond = data["成长速度"] or 0
    self.growthMultVar = data["额外成长倍率变量"] or nil
    self.lastCastTime = 0
    self.activePlayers = {}
    self.selectedSkill = nil ---@type string
    self.occupiedEntity = nil ---@type Actor|nil

    self:SubscribeEvent("ExitAfkSpot", function (evt)
        if evt.player and self.mode ~= "副卡" then
            self:OnPlayerExit(evt.player)
        end
    end)

    self:SubscribeEvent("PlayerLeaveGameEvent", function (evt)
        if evt.player == self.owner or self.activePlayers[evt.player] then
            self:OnPlayerExit(evt.player)
        end
    end)

    self:SubscribeEvent("AfkSelectSkill", function (evt)
        if evt.npcId == self.uuid then
            local player = evt.player ---@type Player
            if self.owner or self.occupiedEntity then
                player:SendHoverText("此位置已有别人在挂机,换一个吧!")
                return
            end
            -- 检查挂机数量上限
            if GetPlayerAfkCount(player) >= (player:GetVariable("最大副卡挂机数")+1) then
                player:SendHoverText("副卡挂机已达上限!")
                return
            end
            --玩家副卡挂机
            local skill = evt.player.skills[evt.skillName] ---@type Skill
            skill.afking = true
            if self.enterCommands then
                player:ExecuteCommands(self.enterCommands)
            end
            if skill.skillType.battleModel then
                self.occupiedEntity = SandboxNode.New("Actor", self.actor) ---@type Actor
                self.occupiedEntity.EnablePhysics = false
                self.occupiedEntity.ModelId = skill.skillType.battleModel
                self.occupiedEntity["Animator"].ControllerAsset = skill.skillType.battleAnimator
                self.occupiedEntity.LocalScale = skill.skillType.afkScale
                -- local ModelPlayer = require(MainStorage.code.server.graphic.ModelPlayer) ---@type ModelPlayer
                -- ModelPlayer.FetchModelSize(self.occupiedEntity, function (modelSize)
                --     local selfSize = self:GetSize()
                --     self.occupiedEntity.LocalScale = Vector3.New(selfSize.x / modelSize[1], selfSize.y / modelSize[2], selfSize.z / modelSize[3])
                -- end)
            end
            self.owner = player
            self.selectedSkill = skill.skillType.name
            self:StartSpellTimer(player)
            self:CreateTitle()
            player:UpdateNearbyNpcsToClient()
        end
    end)

    self:SubscribeEvent("PlayerLeaveSceneEvent", function (evt)
        if self.mode ~= "副卡" and evt.player and self.activePlayers[evt.player] then
            self:OnPlayerExit(evt.player)
        end
    end)
end


--- 检查是否可以进入挂机点
---@param player Player 玩家
---@return boolean 是否可以进入
function AfkSpot:CanEnter(player)
    if self.mode == "副卡" then
        if self.owner then
            return self.owner == player
        end
        if GetPlayerAfkCount(player) >= (player:GetVariable("最大副卡挂机数")+1) then
            player:SendHoverText("副卡挂机已达上限!")
            return false
        end
    end
    if not self.interactCondition then return true end
    local param = self.interactCondition:Check(player, self)
    return not param.cancelled
end

--- 玩家进入挂机点
---@param player Player 玩家
function AfkSpot:OnPlayerEnter(player)
    if self.mode == "副卡" then
        if self.owner then
            if self.owner == player then
                self:OnPlayerExit(player)
            end
        else
            local skills = {}
            for _, skill in pairs(player.skills) do
                if skill:IsEquipped() and skill:CanAfk() and skill.skillType.category == 1 and not skill.afking then
                    table.insert(skills, skill.equipSlot)
                end
            end
            player:SendEvent("AfkSpotSelectCard", {
                skills = skills,
                npcId = self.uuid
            })
        end
    else
        if self.enterCommands then
            player:ExecuteCommands(self.enterCommands)
        end
        self.owner = nil -- 非副卡模式下始终为nil
        player:SetMoveable(false)
        self:StartSpellTimer(player)
    end
end

---@param player Player
function AfkSpot:GetInteractName(player)
    if self.mode == "副卡" then
        if self.owner then
            --已有玩家在挂机
            if player == self.owner then
                local skill = self.owner.skills[self.selectedSkill]
                return string.format("取消:%s", skill.skillType.displayName)
            else
                return nil
            end
        else
            if GetPlayerAfkCount(player) < (player:GetVariable("最大副卡挂机数")+1) then
                return "选择副卡挂机"
            else
                return "副卡挂机已达上限"
            end
        end
    else
        return self.name
    end
end

--- 玩家退出挂机点
---@param player Player 玩家
function AfkSpot:OnPlayerExit(player)
    -- 停止该玩家的定时器
    local timerId = self.activePlayers[player]
    if timerId then
        ServerScheduler.cancel(timerId)
        self.activePlayers[player] = nil

        -- 如果退出的玩家是占用了该位置的玩家（副卡模式），则清理占用状态
        if self.owner == player then
            local skill = self.owner.skills[self.selectedSkill]
            if skill then
                skill.afking = false
            end
            self.owner = nil

            if self.occupiedEntity then
                self.occupiedEntity:Destroy()
                self.occupiedEntity = nil
            end
            self:CreateTitle("")
            player:UpdateNearbyNpcsToClient()
        end

        if self.leaveCommands then
            player:ExecuteCommands(self.leaveCommands)
        end
    end
end

--- 开始定时释放魔法
---@param player Player 玩家
function AfkSpot:StartSpellTimer(player)
    -- 停止之前的定时器
    local oldTimerId = self.activePlayers[player]
    if oldTimerId then
        ServerScheduler.cancel(oldTimerId)
    end

    -- 创建新的定时器
    local timerId = ServerScheduler.add(function()
        self:CastSpells(player)
    end, self.interval, self.interval) -- 立即开始，每隔interval秒执行一次

    -- 保存定时器ID
    self.activePlayers[player] = timerId
end

--- 释放魔法
---@param player Player 玩家
function AfkSpot:CastSpells(player)
    if self.mode == "副卡" then
        if not self.owner or self.owner.isDestroyed then
            if self.owner then
                self:OnPlayerExit(self.owner)
            end
            return
        end
        local skill = self.owner.skills[self.selectedSkill]
        if skill.equipSlot == 0 then
            self:OnPlayerExit(self.owner)
            return
        end
        local maxGrowth = skill.skillType:GetMaxGrowthAtLevel(skill.level)
        if skill.growth >= maxGrowth and player:GetVariable("成长可溢出") == 0 then
            return
        end
        local mult = 0
        if self.growthMultVar then
            mult = self.owner:GetVariable(self.growthMultVar)
        end
        local amount = (1+mult) * self.growthPerSecond
        skill.growth = amount + skill.growth 
        if player:GetVariable("成长可溢出") == 0 then
            skill.growth = math.min(skill.growth, maxGrowth)
        end
        self:CreateTitle()
        
        if player:IsNear(self:GetPosition(), 1000) then
            local loc = self:GetPosition()
            player:SendEvent("DropItemAnim", {
                loc = { loc.x, loc.y + 100, loc.z },
                text = "+"..tostring(amount)
            })
            local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig
            self.owner:SendEvent(SkillEventConfig.RESPONSE.SET_LEVEL, {
                data = {
                    skillName = skill.skillName,
                    level = skill.level,
                    growth = skill.growth,
                    slot = skill.equipSlot,
                    removed = false
                }
            })
        end
    else
        self.owner = nil -- 非副卡模式下始终为nil
        player:ExecuteCommands(self.periodicCommands)
    end
end

--- 处理NPC交互
---@param player Player 玩家
function AfkSpot:HandleInteraction(player)
    -- 先调用父类的交互处理
    -- 执行交互指令
    if self:CanEnter(player) then
        self:OnPlayerEnter(player)
        if self.interactCommands then
            player:ExecuteCommands(self.interactCommands)
        end
    
        ServerEventManager.Publish("NpcInteractionEvent", {
            player = player,
            npc = self
        })
    end
end

--- 更新NPC状态
function AfkSpot:update_npc()
end

function AfkSpot:DestroyObject()
    Entity.DestroyObject(self)
    if self.periodicTaskKey then
        ServerScheduler.cancel(self.periodicTaskKey)
        self.periodicTaskKey = nil
    end
end

return AfkSpot
