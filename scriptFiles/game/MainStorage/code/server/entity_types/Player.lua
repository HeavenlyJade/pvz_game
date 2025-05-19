local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const
local ClassMgr  = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
-- local TaskSystem = require(MainStorage.code.server.TaskSystem.MTaskSystem) ---@type TaskSystem
local Entity      = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
-- local skillMgr     = require(MainStorage.code.server.skill.MSkillMgr) ---@type SkillMgr
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr) ---@type MCloudDataMgr
local ServerEventManager      = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local TagTypeConfig = require(MainStorage.code.common.config.TagTypeConfig) ---@type TagTypeConfig




---@class Player : Entity    --玩家类  (单个玩家) (管理玩家状态)
---@field dict_btn_skill table 技能按钮映射
---@field daily_tasks table 每日任务数据
---@field buff_instance table Buff实例
---@field player_net_stat PLAYER_NET_STAT 玩家网络状态
---@field auto_attack number 自动攻击技能ID
---@field auto_attack_tick number 攻击间隔
---@field auto_wait_tick number 攻击等待计时
---@field nearbyNpcs table<Npc> 附近的NPC列表
---@field New fun( info_:table ):   Player
local _M = ClassMgr.Class('Player', Entity)

--------------------------------------------------
-- 初始化与基础方法
--------------------------------------------------

-- 初始化玩家
function _M:OnInit(info_)
    Entity:OnInit(info_)                                       -- 父类初始化
    self.name = info_.nickname
    self.isPlayer = true
    self.bag = nil ---@type Bag
    self.mail = nil ---@type MailDataStruct
    self.uuid             = gg.create_uuid('u_Pl')                 -- 唯一ID
    self.auto_attack      = 0                                   -- 自动攻击技能ID
    self.auto_attack_tick = 10                                  -- 攻击间隔
    self.auto_wait_tick   = 0                                   -- 等待计时
    self.daily_tasks      = {}                                  -- 每日任务
    self.dict_btn_skill   = {}                                  -- 技能按钮映射
    self.buff_instance    = {}                                  -- Buff实例
    self.player_net_stat  = common_const.PLAYER_NET_STAT.INITING -- 网络状态
    self.nearbyNpcs       = {}                                  -- 附近的NPC列表
    self.quests = {} ---@type AcceptedQuest[]
    self.acceptedQuestIds = {} ---@type table<string, number> --值=0: 已领取, 未完成 =1: 已完成
    self.news = {} ---@type table<string, table> --红点路径
end

---标记红点
function _M:MarkNew(path)
    
end

function _M:RefreshQuest(key)
    --若key=每日, 每周, 每月: 重置quests和acceptedQuestIds中 刷新类型==key的
    --否则: 重置任务名中包含key的
    local questsToRemove = {}
    local refreshedQuestNames = {}
    
    -- 遍历所有已接受的任务
    for questId, quest in pairs(self.quests) do
        local shouldRefresh = false
        
        -- 检查刷新类型
        if key == "每日" or key == "每周" or key == "每月" then
            shouldRefresh = quest.quest.refreshType == key
        else
            -- 检查任务名是否包含key
            shouldRefresh = string.find(quest.quest.name, key) ~= nil
        end
        
        if shouldRefresh then
            table.insert(questsToRemove, questId)
            table.insert(refreshedQuestNames, quest.quest.name)
            -- 从acceptedQuestIds中移除
            self.acceptedQuestIds[questId] = nil
        end
    end
    
    -- 移除需要刷新的任务
    for _, questId in ipairs(questsToRemove) do
        self.quests[questId] = nil
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

function _M:ExecuteCommands(commands, castParam)
    for _, command in ipairs(commands) do
        self:ExecuteCommand(command, castParam)
    end
end

---@override
function _M:Die()
    -- 发布死亡事件
    local debug_traceback = debug.traceback()
    gg.log("Player died, stack trace:", debug_traceback)
    ServerEventManager.Publish("PlayerDeadEvent", { player = self })
    Entity.Die(self)
end

function _M:ExecuteCommand(command, castParam)
    local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)  ---@type CommandManager
    command = command:gsub("%%p", tostring(self.uin))
    CommandManager.ExecuteCommand(command, self)
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

    -- 添加所有属性的基础值
    local StatTypeConfig = require(MainStorage.code.common.config.StatTypeConfig) ---@type StatTypeConfig
    for statName, statType in pairs(StatTypeConfig.GetAll()) do
        self:AddStat(statName, statType.baseValue, {source = "EQUIP", refresh = false})
    end

    -- 直接遍历bag_items，跳过c =0
    for category, items in pairs(self.bag.bag_items) do
        if category > 0 then
            for slot, item in pairs(items) do
                if item and item.itemType then
                    -- 遍历装备的所有属性
                    for statName, amount in pairs(item:GetStat()) do
                        self:AddStat(statName, amount, {source = "EQUIP", refresh = false})
                    end
                    for _, tag in ipairs(item.itemType.boundTags) do
                        self:AddTagHandler(TagTypeConfig.Get(tag):FactoryEquipingTag("EQUIP-", 1.0))
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

--------------------------------------------------
-- 技能系统方法
--------------------------------------------------

-- 初始化技能数据
function _M:initSkillData()
    -- 从云数据读取
    local ret1_, cloud_data_ = cloudDataMgr.ReadSkillData(self.uin)
    if ret1_ == 0 and cloud_data_ and cloud_data_.skill then
        self.dict_btn_skill = cloud_data_.skill
    else
        -- 使用默认技能配置
        self.dict_btn_skill = {
            [1] = 1001,
            [2] = 0,
        }

        -- 从玩家配置加载技能
        local player_config = common_config.dict_player_config[1]
        if player_config and player_config.skills then
            for i = 1, #player_config.skills do
                self.dict_btn_skill[i] = player_config.skills[i]
            end
        end
    end

    -- 同步到客户端
    self:syncSkillData()
end

-- 保存技能配置
function _M:saveSkillConfig()
    cloudDataMgr.SaveSkillData(self.uin)
    self:syncSkillData()
end

-- 同步技能数据到客户端
function _M:syncSkillData()
    if not self.dict_btn_skill then return end

    gg.network_channel:fireClient(self.uin, {
        cmd = 'cmd_sync_player_skill',
        uin = self.uin,
        skill = self.dict_btn_skill
    })
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
end

function _M:SendHoverText( text, ... )
    if ... then
        text = string.format(text, ...)
    end
    gg.network_channel:fireClient(self.uin, { cmd="cmd_client_show_msg", txt=text })
end

-- 添加附近的NPC
---@param npc Npc
function _M:AddNearbyNpc(npc)
    gg.log("AddNearbyNpc", npc, npc.uuid)
    if not self.nearbyNpcs[npc.uuid] then
        self.nearbyNpcs[npc.uuid] = npc
        self:UpdateNearbyNpcsToClient()
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
        local distance = gg.vec.Distance(npc.actor.LocalPosition, self.actor.LocalPosition)
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
            npcName = data.npc.name,
            npcId = data.npc.uuid,
            icon = data.npc.interactIcon
        })
    end

    gg.network_channel:fireClient(self.uin, {
        cmd = "NPCInteractionUpdate",
        interactOptions = interactOptions
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

return _M
