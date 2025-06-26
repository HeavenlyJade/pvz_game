local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const
local ClassMgr  = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
-- local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem) ---@type TaskSystem
local Entity      = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
-- local skillMgr     = require(MainStorage.code.server.skill.MSkillMgr) ---@type SkillMgr
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr) ---@type MCloudDataMgr
local ServerEventManager      = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local TagTypeConfig = require(MainStorage.code.common.config.TagTypeConfig) ---@type TagTypeConfig
local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
local cloudService      = game:GetService("CloudService")     --- @type CloudService
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local Level = require(MainStorage.code.server.Scene.Level) ---@type Level
local MiscConfig = require(MainStorage.code.common.config.MiscConfig) ---@type MiscConfig




---@class Player : Entity    --玩家类  (单个玩家) (管理玩家状态)
---@field daily_tasks table 每日任务数据
---@field buff_instance table Buff实例
---@field player_net_stat PLAYER_NET_STAT 玩家网络状态
---@field auto_attack number 自动攻击技能ID
---@field auto_attack_tick number 攻击间隔
---@field auto_wait_tick number 攻击等待计时
---@field nearbyNpcs table<Npc> 附近的NPC列表
---@field actor MiniPlayer
---@field New fun( info_:table ):   Player
local _M = ClassMgr.Class('Player', Entity)

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

-- 初始化玩家
function _M:OnInit(info_)
    self.inited = false
    self.name = info_.nickname
    self.isPlayer = true
    self.bag = nil ---@type Bag
    self.mail = nil ---@type PlayerMailBundle
    self.auto_attack      = 0                                   -- 自动攻击技能ID
    self.auto_attack_tick = 10                                  -- 攻击间隔
    self.auto_wait_tick   = 0                                   -- 等待计时
    self.daily_tasks      = {}                                  -- 每日任务
    self.buff_instance    = {}                                  -- Buff实例
    self.player_net_stat  = common_const.PLAYER_NET_STAT.INITING -- 网络状态
    self.nearbyNpcs       = {}                                  -- 附近的NPC列表
    self.quests = {} ---@type AcceptedQuest[]
    self.acceptedQuestIds = {} ---@type table<string, number> --值=0: 已领取, 未完成 =1: 已完成
    self.news = {} ---@type table<string, table> --红点路径
    self.skills = {} ---@type table<string, Skill>
    self.equippedSkills = {} ---@type table<number, string>
    self.skillCastabilityTask = nil ---@type number 技能可释放状态检查任务ID
    self._moveMethod = nil
    self.focusOnCommandsCb = nil
    self.afkingCount = 0 --副卡挂机数
    self.lastDailyRefresh = 0 -- 上次每日刷新时间
    self.lastWeeklyRefresh = 0 -- 上次每周刷新时间
    self.lastMonthlyRefresh = 0 -- 上次每月刷新时间

    self:SubscribeEvent("FinishFocusUI", function (evt)
        if self.focusOnCommandsCb then
            self:ExecuteCommands(self.focusOnCommandsCb)
            self.focusOnCommandsCb = nil
        end
    end)

    self:SubscribeEvent("ClickQuest", function (evt)
        local quest = self.quests[evt.name]
        if not quest then
            self:SendHoverText("不存在的任务 %s", evt.name)
            return
        end
        if quest:IsCompleted() then
            quest:Finish()
        else
            quest.quest:OnClick(self)
        end
    end)

    self:SubscribeEvent("NavigateReached", function()
        print("NavigateReached", self.navigateCb)
        if self.navigateCb then
            self.navigateCb()
            self.navigateCb = nil
        end
    end)

    self:SubscribeEvent("CastSpell", function (evt)
        if evt.player == self then
            local skill = self.skills[evt.skill]
            if not skill then
                gg.log("不存在的技能", evt.skill)
                return
            end
            if skill and skill.equipSlot > 0 and skill.skillType.activeSpell then
                local param = CastParam.New()
                if evt.targetPos then
                    param.lookDirection = (evt.targetPos - self:GetCenterPosition()):Normalize()
                else
                    param.lookDirection = evt.direction
                end
                local target = nil
                if skill.skillType.targetMode == "位置" then
                    target = gg.Vec3.new(evt.targetPos)
                end
                if skill.skillType.activeSpell:Cast(self, target, param) then
                    -- 获取技能冷却时间
                    local cooldown = self:GetCooldown(skill.skillType.activeSpell.spellName)
                    if cooldown > 0 then
                        -- 发送冷却更新到客户端
                        gg.network_channel:fireClient(self.uin, {
                            cmd = "EquipSkillCooldownUpdate",
                            skillId = evt.skill,
                            cooldown = cooldown
                        })
                    end
                    self:_updateCastability()
                end
            end
        end
    end)

    -- 启动技能可释放状态检查任务
    self:StartSkillCastabilityCheck()
    self.loginTime = os.time()
end

_M.GenerateUUID = function(self)
    self.uuid = gg.create_uuid('u_Pl')
end

function _M:RefreshNewDay()
    local currentTime = os.time()
    local currentDate = os.date("*t", currentTime)

    -- 获取上次刷新的时间
    local lastDailyRefresh = self:GetVariable("day_refresh", 0)
    local lastWeeklyRefresh = self:GetVariable("week_refresh", 0)
    local lastMonthlyRefresh = self:GetVariable("month_refresh", 0)

    -- 检查是否需要每日刷新
    local lastDailyDate = os.date("*t", lastDailyRefresh)
    if lastDailyDate.year ~= currentDate.year or
       lastDailyDate.month ~= currentDate.month or
       lastDailyDate.day ~= currentDate.day then
        self:RemoveVariable("daily_")
        local dailyCommands = MiscConfig.Get("总控")["每日刷新指令"]
        if dailyCommands then
            self:ExecuteCommands(dailyCommands)
        end
        self:SetVariable("day_refresh", currentTime)

        -- 检查是否需要每周刷新
        local lastWeeklyDate = os.date("*t", lastWeeklyRefresh)
        local daysSinceLastWeekly = math.floor((currentTime - lastWeeklyRefresh) / (24 * 3600))
        if daysSinceLastWeekly >= 7 then
            self:RemoveVariable("weekly_")
            local weeklyCommands = MiscConfig.Get("总控")["每周刷新指令"]
            if weeklyCommands then
                self:ExecuteCommands(weeklyCommands)
            end
            self:SetVariable("week_refresh", currentTime)
        end

        -- 检查是否需要每月刷新
        local lastMonthlyDate = os.date("*t", lastMonthlyRefresh)
        if lastMonthlyDate.year ~= currentDate.year or
           lastMonthlyDate.month ~= currentDate.month then
            self:RemoveVariable("monthly_")
            local monthlyCommands = MiscConfig.Get("总控")["每月刷新指令"]
            if monthlyCommands then
                self:ExecuteCommands(monthlyCommands)
            end
            self:SetVariable("month_refresh", currentTime)
        end
    end
end

---标记红点
---@param path string 以/分割的路径
---@param mark boolean true=标记, false=取消标记
function _M:MarkNew(path, mark)
    if not path then return end

    -- 初始化news表（如果不存在）
    if not self.news then
        self.news = {}
    end

    -- 分割路径
    local current = self.news
    local parts = {}
    local parentTables = {} -- 存储所有父级表
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    -- 创建或删除嵌套表结构
    for i, part in ipairs(parts) do
        if i == #parts then
            -- 最后一个部分
            if mark then
                current[part] = true
            else
                current[part] = nil
            end
        else
            -- 中间部分
            if mark then
                current[part] = current[part] or {}
            elseif not current[part] then
                return -- 如果是要取消标记但路径不存在，直接返回
            end
            table.insert(parentTables, {table = current, key = part})
            current = current[part]
        end
    end

    -- 递归清理空表
    if not mark then
        for i = #parentTables, 1, -1 do
            local parent = parentTables[i]
            if next(parent.table[parent.key]) == nil then
                parent.table[parent.key] = nil
            else
                break -- 如果遇到非空表，停止清理
            end
        end
    end
end

---检查路径是否被标记为新
---@param path string 以/分割的路径
---@return boolean
function _M:IsNew(path)
    if not path or not self.news then return false end

    local current = self.news
    for part in path:gmatch("[^/]+") do
        if not current[part] then
            return false
        end
        current = current[part]
    end

    return true
end

function _M:GetOnlineTime()
    return self:GetVariable("daily_onlinetime") + os.time() - self.loginTime
end

function _M:NavigateTo(position, stopRange, cb)
    self.navigateCb = cb
    self:SendEvent("NavigateTo", {
        pos = {position.x, position.y, position.z},
        range = stopRange,
    })
end

function _M:RefreshQuest(key)
    --若key=每日, 每周, 每月: 重置quests和acceptedQuestIds中 刷新类型==key的
    --否则: 重置任务名中包含key的
    local questsToRemove = {}
    local refreshedQuestNames = {}

    -- 处理当前正在进行的任务
    for questId, quest in pairs(self.quests) do
        local shouldRefresh = false

        -- 检查刷新类型
        if key == "每日" or key == "每周" or key == "每月" then
            shouldRefresh = quest.quest.refreshType == key
        else
            shouldRefresh = string.find(quest.quest.name, key) ~= nil
        end

        if shouldRefresh then
            table.insert(questsToRemove, questId)
            table.insert(refreshedQuestNames, quest.quest.name)
        end
    end

    -- 移除需要刷新的任务
    for _, questId in ipairs(questsToRemove) do
        self.quests[questId] = nil
    end

    -- 处理历史领取记录
    for questId, _ in pairs(self.acceptedQuestIds) do
        local shouldRefresh = false
        -- 检查刷新类型
        if key == "每日" or key == "每周" or key == "每月" then
            -- 从任务配置中获取刷新类型
            local questConfig = require(MainStorage.code.common.config.QuestConfig).Get(questId)
            shouldRefresh = questConfig and questConfig.refreshType == key
        else
            shouldRefresh = string.find(questId, key) ~= nil
        end

        if shouldRefresh then
            self.acceptedQuestIds[questId] = nil
        end
    end

    -- 同步到客户端
    self:UpdateQuestsData()

    -- 发送刷新消息
    if #refreshedQuestNames > 0 then
        local message = string.format("已刷新以下任务：\n%s", table.concat(refreshedQuestNames, "\n"))
        self:SendChatText(message)
    else
        self:SendChatText("没有需要刷新的任务")
    end
end

-- 设置玩家网络状态
function _M:setPlayerNetStat(player_net_stat_)
    gg.log('设置玩家网络状态:', self.uin, player_net_stat_)
    self.player_net_stat = player_net_stat_
end



function _M:DisplayCollectItem(imgIcon, text, position, from)
    local data = {
        loc = { position.x, position.y, position.z }
    }
    if text then
        data.text = text
    end
    if imgIcon then
        data.icon = imgIcon
    end
    if from then
        data.from = { from.x, from.y, from.z }
    end
    self:SendEvent("DropItemAnim", data)
end

function _M:SetLevel(level)
    Entity.SetLevel(self,level)
    self:RefreshStats()
    self:SetVariable("level", level)
    self:SendEvent("UpdateHud", {
        level = self.level
    })
end


function _M:EnterBattle()
    self:showReviveEffect(self:GetPosition())
    local skillId = self.equippedSkills[1]
    if skillId then
        local skill = self.skills[skillId]
        if skill.skillType.battleModel then
            if skill.skillType.freezesMove then
                self:SetMoveable(false)
            end
            self:SetModel(skill.skillType.battleModel, skill.skillType.battleAnimator, skill.skillType.battleStateMachine)
            self.actor.LocalScale = Vector3.New(skill.skillType.battlePlayerSize, skill.skillType.battlePlayerSize, skill.skillType.battlePlayerSize)
        end
    end

    -- 清理所有召唤物
    local SummonSpell = require(MainStorage.code.server.spells.spell_types.SummonSpell) ---@type SummonSpell
    if SummonSpell.summonerSummons[self] then
        for _, summoned in ipairs(SummonSpell.summonerSummons[self]) do
            if summoned and summoned.isEntity then
                summoned:DestroyObject()
            end
        end
        SummonSpell.summonerSummons[self] = nil
    end
end

function _M:ExitBattle()
    self:showReviveEffect(self:GetPosition())
    self:SetModel("sandboxSysId://ministudio/entity/player/defaultplayer/body.prefab",
    "sandboxSysId&restype=12://ministudio/entity/player/player12/Animation/OfficialController.controller",
    nil)
    self.actor.LocalScale = Vector3.New(1, 1, 1)
    self:RefreshStats()

    -- 清理所有召唤物
    local SummonSpell = require(MainStorage.code.server.spells.spell_types.SummonSpell) ---@type SummonSpell
    if SummonSpell.summonerSummons[self] then
        for summoned, spell in pairs(SummonSpell.summonerSummons[self]) do
            if summoned and summoned.isEntity then
                summoned:DestroyObject()
            end
        end
        SummonSpell.summonerSummons[self] = nil
    end
end


---@override
function _M:Die()
    if self.isDead then return end
    self:StopSkillCastabilityCheck()
    -- 发布死亡事件
    local evt = { player = self, viewDeath=true }
    ServerEventManager.Publish("PlayerDeadEvent", evt)
    Entity.Die(self)
    if evt.viewDeath then
        self:SendEvent("ViewDeath", {}, function ()
            self:CompleteRespawn()
        end)
    end
end

function _M:CompleteRespawn()
    self.isDead = false
    -- 重置属性
    self:resetBattleData(true)
    -- 重置目标
    if self.isPlayer then
        self.target = nil
    end
    self:RefreshStats()
    self:SetHealth(self.maxHealth)
    -- 重置战斗时间
    self.combatTime = 0
    if self.modelPlayer then
        self.modelPlayer:SwitchState("idle")
    end
    local Scene = require(MainStorage.code.server.Scene)         ---@type Scene
    self.actor.Position = Scene.spawnScene.node.Position
    self:SendEvent("ViewDeath", {
        respawn = true
    })
end

---@protected
function _M:DestroyObject()
    print("Destroy Player")
    print(debug.traceback())
    -- if self.scene then
    --     self.scene.players[self.uin] = nil
    -- end
    -- Entity.DestroyObject(self)
end

function _M:OnLeaveGame()
    -- 发布玩家退出游戏事件
    ServerEventManager.Publish("PlayerLeaveGameEvent", { player = self })
    self:SetVariable("daily_onlinetime", os.time() - self.loginTime)
    Entity.DestroyObject(self)
end

--------------------------------------------------
-- Buff 系统方法
--------------------------------------------------

-- 创建Buff实例
function _M:buffer_create(buffId, duration, params)
    -- 在这里实现Buff创建逻辑
end

-- 销毁玩家的所有Buff
function _M:buffer_destory()
    if not self.buff_instance then return end

    for key, buff in pairs(self.buff_instance) do
        if buff.DestroyBuff then
            buff:DestroyBuff()
        end
    end
    self.buff_instance = {}
end

function _M:RefreshStats()
    -- 先重置装备属性
    self:ResetStats("EQUIP")
    self:RemoveTagHandler("EQUIP-")
    self:RemoveTagHandler("SKILL-")

    -- 遍历所有技能
    for skillId, skill in pairs(self.skills) do
        -- 检查技能是否应该生效
        local shouldBeEffective = skill.equipSlot > 0 or skill.skillType.effectiveWithoutEquip

        if shouldBeEffective then
            -- 添加被动词条
            for _, tagType in ipairs(skill.skillType.passiveTags) do
                local tag = tagType:FactoryEquipingTag("SKILL-" .. skillId, skill.level)
                self:AddTagHandler(tag)
				--gg.log(string.format("添加技能词条: %s (等级 %d)", tagType.name, skill.level))
            end
        end
    end

    -- 添加所有属性的基础值
    local StatTypeConfig = require(MainStorage.code.common.config.StatTypeConfig) ---@type StatTypeConfig
    for statName, statType in pairs(StatTypeConfig.GetAll()) do
        self:AddStat(statName, statType.baseValue + self.level * statType.valuePerLevel,"EQUIP", false)

    end

    -- 直接遍历bag_items，跳过c =0
    if  self.bag then
        for category, items in pairs(self.bag.bag_items) do
            if category > 0 then
                for slot, item in pairs(items) do
                    if item and item.itemType then
                        -- 遍历装备的所有属性
                        for statName, amount in pairs(item:GetStat()) do
                            self:AddStat(statName, amount, "EQUIP", false)
                        end
                        for _, tag in ipairs(item.itemType.boundTags) do
                            self:AddTagHandler(TagTypeConfig.Get(tag):FactoryEquipingTag("EQUIP-", 1.0))
                        end
                    end
                end
            end
        end
    end

    for statName, triggerFunc in pairs(Entity.TRIGGER_STAT_TYPES) do
        local value = self:GetStat(statName)
        triggerFunc(self, value)
    end
end

function _M:SendEvent(eventName, data, callback)
    if not data then
        data = {}
    end
    if not eventName then
        print("发送事件时未传入事件: ".. debug.traceback())
    end
    data.cmd = eventName
    ServerEventManager.SendToClient(self.uin, eventName, data, callback)
end

--------------------------------------------------
-- 技能系统方法
--------------------------------------------------
-- 初始化技能数据
function _M:initSkillData()
    -- 从云数据读取
    local ret1_, cloud_data_ = cloudDataMgr.ReadSkillData(self.uin)
    gg.log("initSkillData", ret1_, cloud_data_)
    if ret1_ == 0 and cloud_data_ and cloud_data_.skills then
        -- 加载已保存的技能
        for skillId, skillData in pairs(cloud_data_.skills) do
            local skill = Skill.New(self, skillData)
            if not skill.skillType then
                gg.log(self.name .. "的技能不存在： " .. skillData["skill"])
            else
                self.skills[skillId] = skill
            end
        end
    end
end

-- 保存技能配置
function _M:saveSkillConfig()
    cloudDataMgr.SaveSkillConfig(self)
end

-- 同步技能数据到客户端
function _M:syncSkillData()
    local skillData = {
        skills = {}
    }

    -- 收集技能数据
    for skillId, skill in pairs(self.skills) do
        skillData.skills[skillId] = {
            skill = skill.skillType.name,
            level = skill.level,
            slot = skill.equipSlot,
            growth = skill.growth,
            star_level = skill.star_level,
        }

        -- 记录已装备的技能
        if skill.equipSlot > 0 then
            self.equippedSkills[skill.equipSlot] = skillId
        end
    end

    -- 发送到客户端
    gg.network_channel:fireClient(self.uin, {
        cmd = 'SyncPlayerSkills',
        uin = self.uin,
        skillData = skillData
    })
end


function _M:ChangeScene(new_scene)
    if new_scene.bgmSound then
        self:PlaySound(new_scene.bgmSound, nil, 0.2, nil, nil, "bgm")
    end
    Entity.ChangeScene(self, new_scene)
end


-- 修改装备技能函数，添加词条更新
function _M:EquipSkill(skillId, slot)
    local skill = self.skills[skillId]
    if not skill then return false end

    -- 如果目标槽位已有技能，先卸下
    local existingSkillId = self.equippedSkills[slot]
    if existingSkillId then
        local existingSkill = self.skills[existingSkillId]
        if existingSkill then
            existingSkill.equipSlot = 0
        end
    end

    -- 装备新技能
    skill.equipSlot = slot
    self.equippedSkills[slot] = skillId

    -- 刷新属性
    self:RefreshStats()
    self:saveSkillConfig()
    self:syncSkillData()
    return true
end

-- 修改卸下技能函数，添加词条更新
function _M:UnequipSkill(slot)
    local skillId = self.equippedSkills[slot]
    if not skillId then return false end

    local skill = self.skills[skillId]
    if skill then
        skill.equipSlot = 0
        self.equippedSkills[slot] = nil

        -- 刷新属性
        self:RefreshStats()

        -- 保存配置
        self:saveSkillConfig()
        return true
    end
    return false
end

function _M:LearnSkill(skillType)
    local skillId = skillType.name
    local foundSkill = self.skills[skillType.name]
    -- 如果技能不存在
    if not foundSkill then
        -- 创建新技能
        self.skills[skillId] = Skill.New(self, {
            skill = skillType.name,
            level = 1,
            slot = 0,
            star_level = 1
        })
        self:saveSkillConfig()
        return true
    end
    return false
end

-- 修改升级技能函数，添加词条更新
function _M:UpgradeSkill(skillType)
    -- 查找玩家是否已拥有该技能
    local foundSkill = self.skills[skillType.name]
    -- 如果技能不存在
    if not foundSkill then
        -- 创建新技能
        local skillSlot = 0

        -- 根据技能类型从配置获取槽位范围
        local common_config = require(MainStorage.code.common.MConfig)
        local slotsToCheck = {}

        if skillType.category == 0 then
            -- 主卡技能：从主卡配置获取槽位
            local mainCardConfig = common_config.EquipmentSlot["主卡"]
            if mainCardConfig then
                for slotId, _ in pairs(mainCardConfig) do
                    table.insert(slotsToCheck, slotId)
                end
            end
        elseif skillType.category == 1 then
            -- 副卡技能：从副卡配置获取槽位
            local subCardConfig = common_config.EquipmentSlot["副卡"]
            if subCardConfig then
                for slotId, _ in pairs(subCardConfig) do
                    table.insert(slotsToCheck, slotId)
                end
            end
        end

        -- 按槽位ID排序（优先使用较小的槽位）
        table.sort(slotsToCheck)

        -- 查找第一个空的槽位
        for _, slotId in ipairs(slotsToCheck) do
            if not self.equippedSkills[slotId] then
                skillSlot = slotId
                break
            end
        end

        local skillId = skillType.name
        self.skills[skillId] = Skill.New(self, {
            skill = skillType.name,
            level = 1,
            slot = skillSlot,
            star_level = 1
        })
        self:SetLevel(self.level + skillType.levelUpPlayer)
        self:saveSkillConfig()
        return true
    end

    -- 如果技能已存在，检查是否可以升级
    if foundSkill.level >= skillType.maxLevel then
        return false
    end

    -- 升级技能
    foundSkill.level = foundSkill.level + 1
    self:SetLevel(self.level + foundSkill.skillType.levelUpPlayer)
    self:SetVariable("skill_".. foundSkill.skillName, foundSkill.level)
    self:SetVariable("skill_enhance_".. foundSkill.skillType.category, foundSkill.level)
    self:RefreshStats()

    -- 保存配置
    self:saveSkillConfig()
    return true
end

--------------------------------------------------
-- 玩家同步与更新方法
--------------------------------------------------

-- 同步玩家数据到客户端
-- op: 1=初始化同步所有数据   2=只同步exp
function _M:rsyncData(op_)
    local ret_ = {
        level     = self.level,
        exp       = self.exp,
        user_name = self.name,
        uin       = self.uin,
    }

    if op_ == 1 then
        ret_.battle_data = self.battle_data
    end

    gg.network_channel:fireClient(self.uin, {
        cmd = "cmd_rsync_player_data",
        v = ret_
    })
end

-- 设置自动攻击
function _M:setAutoAttack(id_, speed_time_)
    if self.auto_attack ~= id_ then
        self.auto_attack = id_
        if id_ > 0 then
            self.auto_attack_tick = speed_time_ * 10
        end
    end
end

-- 玩家离开游戏
function _M:Save()
    cloudDataMgr.SavePlayerData(self.uin, true)
    cloudDataMgr.SaveGameTaskData(self)
    cloudDataMgr.SaveSkillConfig(self)
    self.bag:Save()
end

-- 更新玩家状态
function _M:update_player()
    -- 调用父类更新
    self:update()

    -- 更新Buff
    self:updateBuffs()
end


-- 更新Buff状态
function _M:updateBuffs()
    if not self.buff_instance then return end

    local current_time = os.time()
    local keys_to_remove = {}

    -- 检查所有Buff
    for key, buff_instance in pairs(self.buff_instance) do
        local buff_create_time = buff_instance.create_time or 0
        local duration_time = buff_instance.duration_time or 60

        -- 检查Buff是否过期
        if current_time > buff_create_time + duration_time then
            table.insert(keys_to_remove, key)

            -- 调用销毁方法
            if buff_instance.DestroyBuff then
                buff_instance:DestroyBuff()
            end
        end
    end

    -- 移除过期Buff
    for _, key in ipairs(keys_to_remove) do
        self.buff_instance[key] = nil
    end
end

function _M:SendChatText( text, ... )
    if ... then
        text = string.format(text, ...)
    end
    self:SendHoverText(text)
    print(text)
end

function _M:SetHealth(health)
    Entity.SetHealth(self, health)
    self:SendEvent("UpdateHealth", {
        h = self.health,
        mh = self.maxHealth
    })
end

function _M:SetMaxHealth(health)
    Entity.SetMaxHealth(self, health)
    self:SendEvent("UpdateHealth", {
        h = self.health,
        mh = self.maxHealth
    })
end

function _M:SendHoverText( text, ... )
    if ... then
        text = string.format(text, ...)
    end
    self:SendEvent("SendHoverText", { txt=text })
end

-- 添加附近的NPC
---@param npc Npc
function _M:AddNearbyNpc(npc)
    if not self.nearbyNpcs[npc.uuid] then
        self.nearbyNpcs[npc.uuid] = npc
        self:UpdateNearbyNpcsToClient()
    end
end

function _M:SetMoveable(moveable)
    if moveable then
        self:RefreshStats()
    else
        self.actor.Movespeed = 0
    end
end

-- 移除附近的NPC
---@param npc Npc
function _M:RemoveNearbyNpc(npc)
    if self.nearbyNpcs[npc.uuid] then
        self.nearbyNpcs[npc.uuid] = nil
        self:UpdateNearbyNpcsToClient()
    end
end

-- 更新附近的NPC列表到客户端
function _M:UpdateNearbyNpcsToClient()
    local interactOptions = {}
    local npcList = {}

    -- 收集NPC信息并计算距离
    for _, npc in pairs(self.nearbyNpcs) do
        local distance = gg.vec.Distance3(npc.actor.LocalPosition, self.actor.LocalPosition)
        table.insert(npcList, {
            npc = npc,
            distance = distance
        })
    end

    -- 按距离排序
    table.sort(npcList, function(a, b)
        return a.distance < b.distance
    end)

    -- 构建排序后的交互选项列表
    for _, data in ipairs(npcList) do
        table.insert(interactOptions, {
            npcName = data.npc:GetInteractName(self),
            npcId = data.npc.uuid,
            icon = data.npc.interactIcon
        })
    end

    gg.network_channel:fireClient(self.uin, {
        cmd = "NPCInteractionUpdate",
        interactOptions = interactOptions
    })
end

function _M:ProcessQuestEvent(event, amount)
    for _, quest in pairs(self.quests) do
        if quest.quest.questType == "事件" and string.find(quest.quest.eventName, event) then
            quest:AddProgress(amount)
        end
    end
end

function _M:UpdateHud()
    self:RefreshNewDay()
    self:UpdateQuestsData()
    self:syncSkillData()
    self.bag:SyncToClient()

    self.level = self:GetVariable("level", 1)
    self:SetMoveable(true)
    self:SendEvent("UpdateHud", {
        level = self.level
    })
end

-- 同步任务数据到客户端
function _M:UpdateQuestsData()
    -- 构建任务数据
    local quests = {}

    -- 添加进行中的任务
    for questId, quest in pairs(self.quests) do
        table.insert(quests, quest:GetQuestDesc())
    end

    -- 发送到客户端
    gg.network_channel:fireClient(self.uin, {
        cmd = 'UpdateQuestsData',
        quests = quests
    })
end

---@private
function _M:_updateCastability()
    local castabilityData = {}

    -- 遍历所有装备的技能
    for skillId, skill in pairs(self.skills) do
        if skill.equipSlot > 0 and skill.skillType.activeSpell then
            -- 检查技能是否可以释放
            local canCast = skill.skillType.activeSpell:CanCast(self, nil, nil, nil, false)
            castabilityData[skillId] = canCast
        end
    end

    -- 发送到客户端
    gg.network_channel:fireClient(self.uin, {
        cmd = "UpdateSkillCastability",
        castabilityData = castabilityData
    })
end

-- 启动技能可释放状态检查任务
function _M:StartSkillCastabilityCheck()
    -- 如果已有任务在运行，先停止它
    if self.skillCastabilityTask then
        ServerScheduler.cancel(self.skillCastabilityTask)
    end

    -- 创建新的定时任务，每秒检查一次
    self.skillCastabilityTask = ServerScheduler.add(function ()
        self:_updateCastability()
    end, 0, 1.0) -- 立即开始，每秒执行一次
end

-- 停止技能可释放状态检查任务
function _M:StopSkillCastabilityCheck()
    if self.skillCastabilityTask then
        ServerScheduler.cancel(self.skillCastabilityTask)
        self.skillCastabilityTask = nil
    end
end

---播放音效
---@param soundAssetId string 音效资源ID
---@param boundTo? SandboxNode|Vec3 音效绑定目标(实体或位置)
---@param volume? number 音量大小(0-1)
---@param pitch? number 音调大小(0-2)
---@param range? number 音效范围
---@param key? string
function _M:PlaySound(soundAssetId, boundTo, volume, pitch, range, key)
    local data = {
        soundAssetId = soundAssetId,
        volume = volume or 1.0,
        pitch = pitch or 1.0,
        range = range or 6000,
        key = key
    }

    if not boundTo then
        local pos = self:GetPosition()
        data.position = {pos.x, pos.y, pos.z}
    elseif type(boundTo) == "userdata" then
        if boundTo.IsA then
            ---@cast boundTo SandboxNode
            data.boundTo = gg.GetFullPath(boundTo)
        else
            ---@cast boundTo Vector3
            data.position = {boundTo.x, boundTo.y, boundTo.z}
        end
    elseif type(boundTo) == "table" and boundTo.x then
        -- 如果是Vec3，直接使用位置
        data.position = {boundTo.x, boundTo.y, boundTo.z}
    end

    self:SendEvent("PlaySound", data)
end

---设置玩家视角
---@param euler Vector3 旋转角度
function _M:SetCameraView(euler)
    gg.network_channel:fireClient(self.uin, {
        cmd = "UpdateCameraView",
        x = euler.x,
        y = euler.y,
        z = euler.z,
    })
end

return _M
