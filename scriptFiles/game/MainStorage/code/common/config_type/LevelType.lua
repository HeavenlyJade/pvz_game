local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig)  ---@type MobTypeConfig
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
local WeightedRandomSelector = require(MainStorage.code.common.WeightedRandomSelector) ---@type WeightedRandomSelector
local LevelConfig = require(MainStorage.code.common.config.LevelConfig)  ---@type LevelConfig
local Item = require(MainStorage.code.server.bag.Item) ---@type Item
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig


---@class DropItemInfo
---@field 物品 string
---@field 数量 string
---@field 几率 string

---@class RankRewardInfo
---@field 名次 number
---@field 物品 table<string, number>

---@class SpawningMob:Class
---@field mobType MobType
---@field weight number
local SpawningMob = ClassMgr.Class("SpawningMob")

function SpawningMob:OnInit(data)
    self.mobType = MobTypeConfig.Get(data["怪物类型"])
    self.weight = data["比重"] or 1
end

---@class TempSkill:Class
---@field skillType SkillType
---@field level number
---@field slot number
local TempSkill = ClassMgr.Class("TempSkill")

function TempSkill:OnInit(data)
    self.skillType = SkillTypeConfig.Get(data["技能类型"])
    self.level = data["等级"] or 1
    self.slot = data["装备槽位"]
end

---@class SpawningWave:Class
---@field mobs SpawningMob[]
---@field duration number
---@field count number
---@field maxCount number
---@field startTime number
---@field selector WeightedRandomSelector
local SpawningWave = ClassMgr.Class("SpawningWave")

function SpawningWave:OnInit(data)
    self.mobs = {}
    for _, mobData in ipairs(data["刷新怪物"] or {}) do
        table.insert(self.mobs, SpawningMob.New(mobData))
    end
    self.duration = data["持续时间"] or 0
    self.count = data["数量"] or 0
    self.maxCount = data["最大数量"] or 0
    self.startTime = data["开始时间"] or 0

    self.selector = WeightedRandomSelector.New(self.mobs, function(mob) return mob.weight end)
    
    -- 计算实际要刷新的怪物数量
    if self.maxCount > 0 then
        self.actualCount = math.floor(self.count + (self.maxCount - self.count) * math.random())
    else
        self.actualCount = self.count
    end
    
    -- 计算每秒刷新的怪物数量
    self.spawnsPerSecond = self.actualCount / self.duration
end

---@return MobType
function SpawningWave:GetRandomMobType()
    local selected = self.selector:Next()
    if not selected then
        print("Warning: No mob type selected from selector")
        return nil
    end
    return selected.mobType
end

---尝试生成怪物
---@param deltaTime number 距离上次更新的时间间隔
---@param level number 怪物等级
---@param levelInst Level 刷怪点列表
---@param spawnedCount number 已经生成的怪物数量
---@return boolean 是否完成生成
---@return Monster[] 生成的怪物实例列表
---@return number 更新后的生成数量
function SpawningWave:TrySpawn(deltaTime, level, levelInst, spawnedCount)
    -- 计算这次要生成的怪物数量
    local spawnCountF = deltaTime * self.spawnsPerSecond
    local spawnCount = math.floor(spawnCountF)
    if math.random() < spawnCountF - spawnCount then
        spawnCount = spawnCount + 1
    end
    
    -- 确保不超过剩余数量
    spawnCount = math.min(spawnCount, self.actualCount - spawnedCount)
    
    -- 生成怪物
    local spawnedMobs = {} ---@type Mob[]
    for i = 1, spawnCount do
        local mobType = self:GetRandomMobType()
        if mobType then
            -- 随机选择一个刷怪点
            local spawnLoc
            local spawnPoints = levelInst.spawnPoints
            if spawnPoints and #spawnPoints > 0 then
                spawnLoc = spawnPoints[math.random(1, #spawnPoints)].Position
            else
                spawnLoc = Vector3.New(0, 0, 0)
                print("Warning: No spawn points available, using default position")
            end
            local mob = mobType:Spawn(spawnLoc, level, levelInst.scene)
            if mob then
                table.insert(spawnedMobs, mob)
                spawnedCount = spawnedCount + 1
            end
        end
    end
    
    -- 返回是否完成生成、生成的怪物列表和更新后的生成数量
    return spawnedCount >= self.actualCount, spawnedMobs, spawnedCount
end

---@class Wave:Class
---@field spawningWaves SpawningWave[]
---@field spaceChance number
---@field spaceSize number
---@field attributeMultiplier number
---@field spiritReward number
---@field totalExp number
---@field healthSum number
---@field waveHealths table<number, number> 每个波次的血量
---@field startCommands string[] 开始时执行的指令
---@field monsterLevelStart number 波次开始时怪物等级
---@field monsterLevelEnd number 波次结束时怪物等级
---@field dropItems DropItemInfo[] 掉落物配置
local Wave = ClassMgr.Class("Wave")

function Wave:OnInit(data)
    self.spawningWaves = {}
    for _, waveData in ipairs(data["刷新波次"] or {}) do
        table.insert(self.spawningWaves, SpawningWave.New(waveData))
    end
    self.attributeMultiplier = data["属性倍率"] or 1
    self.totalExp = data["总计经验"] or 0
    self.startCommands = data["开始时执行指令"]
    self.healthSum = 0
    self.waveHealths = {} ---@type table<number, number>
    
    -- 加载怪物等级配置（数组格式：开始等级，结束等级）
    local monsterLevelData = data["怪物等级"] or {1, 1}
    if type(monsterLevelData) == "table" then
        self.monsterLevelStart = monsterLevelData[1] or 1
        self.monsterLevelEnd = monsterLevelData[2] or self.monsterLevelStart
    else
        self.monsterLevelStart = monsterLevelData
        self.monsterLevelEnd = monsterLevelData
    end
    
    -- 加载掉落物配置
    self.dropItems = data["掉落物"] or {} ---@type DropItemInfo[]
    self.waveImg = data["转波次文字"]
    self.waveSound = data["转波次音效"]
end

---执行波次开始时的指令
---@param level Level 关卡实例
function Wave:ExecuteStartCommands(level)
    if self.startCommands then
        -- 对关卡中的所有玩家执行指令
        for _, player in pairs(level.players) do
            player:ExecuteCommands(self.startCommands)
        end
    end
end

---计算波次中的怪物总数
---@return number 怪物总数
function Wave:CalculateMobCount()
    local totalCount = 0
    for _, wave in ipairs(self.spawningWaves) do
        totalCount = totalCount + wave.actualCount
    end
    return totalCount
end

function Wave:CalculateHealthSum(level)
    if self.healthSum > 0 then
        return -- 已经计算过，直接返回
    end

    self.healthSum = 0
    self.waveHealths = {}

    -- 计算每个波次的血量
    for waveIndex, wave in ipairs(self.spawningWaves) do
        local waveHealth = 0
        local weightSum = 0
        
        -- 计算权重总和
        for _, mob in ipairs(wave.mobs) do
            weightSum = weightSum + mob.weight
        end
        
        -- 计算每个怪物的血量贡献
        for _, mob in ipairs(wave.mobs) do
            local mobHealth = mob.mobType:GetStatAtLevel("生命", level)
            local healthContribution = mobHealth * self.attributeMultiplier * wave.count * mob.weight / weightSum
            waveHealth = waveHealth + healthContribution
        end
        
        -- 缓存这个波次的血量
        self.waveHealths[waveIndex] = waveHealth
        self.healthSum = self.healthSum + waveHealth
    end
end

---获取指定波次的血量
---@param waveIndex number 波次索引
---@return number 波次血量
function Wave:GetWaveHealth(waveIndex)
    if not self.waveHealths[waveIndex] then
        return 0
    end
    return self.waveHealths[waveIndex]
end

---获取当前时间点的怪物等级
---@param waveProgress number 波次进度（0-1）
---@return number 当前怪物等级
function Wave:GetCurrentMonsterLevel(waveProgress)
    -- 使用线性插值计算当前等级
    return self.monsterLevelStart + (self.monsterLevelEnd - self.monsterLevelStart) * waveProgress
end

---@class LevelType:Class
---@field New fun( data:table ):LevelType
local LevelType = ClassMgr.Class("LevelType")

function LevelType:OnInit(data)
    self.levelId = data["关卡ID"] ---@type string
    self.description = data["描述"] or "" ---@type string
    self.category = data["分类"] or "" ---@type string
    self.prerequisiteLevel = data["前置关卡"] ---@type LevelType
    self.prerequisiteVars = data["前置变量"] or {} ---@type table<string, number>
    self.deductVars = data["扣除变量"] or {} ---@type table<string, number>
    self.entryPoints = data["进入位置"] or {} ---@type string[]
    self.spawnPoints = data["刷怪点"] or {} ---@type string[]
    self.maxPlayers = data["最大玩家数"] or 1 ---@type number
    self.startPlayers = data["开始玩家"] or self.maxPlayers ---@type number
    self.extraPlayerTime = data["增加额外玩家时间"] or 10 ---@type number
    self.entryConditions = data["进入条件"] or Modifiers.New({}) ---@type Modifiers
    self.twoStarDescription = data["描述_2星"] or "" ---@type string
    self.threeStarDescription = data["描述_3星"] or "" ---@type string
    self.twoStarConditions = data["条件_2星"] or Modifiers.New({}) ---@type Modifiers
    self.threeStarConditions = data["条件_3星"] or Modifiers.New({}) ---@type Modifiers
    self.monsterLevel = data["怪物等级"] or 1 ---@type number
    self.level = data["等级"] or 1 ---@type number
    self.dropModifier = Modifiers.New(data["掉落物数量修改"]) ---@type Modifiers
    self.disableCompleteView = data["关闭结算界面"]
    
    self.tempSkill = {} ---@type TempSkill[]
    if data["临时装备技能"] then
        for _, skillData in ipairs(data["临时装备技能"]) do
            table.insert(self.tempSkill, TempSkill.New(skillData))
        end
    end
    -- 加载排名掉落物配置
    self.rankRewards = data["排名掉落物"] or {} ---@type RankRewardInfo[]

    -- 玩家数量倍率配置
    self.playerCountMultiplier = data["每个玩家增加数量倍率"] or 0 ---@type number
    self.playerAttributeMultiplier = data["每个玩家增加属性倍率"] or {} ---@type table<string, number>
    self.winSound = data["胜利音效"]
    self.loseSound = data["失败音效"]
    self.firstClearReward = Item.LoadStack(data["首通奖励"])

    -- 初始化匹配相关属性
    self.matchQueue = {} ---@type table<string, Player>
    self.playerCount = 0 ---@type number
    self.remainingTime = 0 ---@type number
    self.lastUpdateTime = 0 ---@type number

    -- 加载波次数据
    self.waves = {} ---@type Wave[]
    for _, waveData in ipairs(data["关卡波次"] or {}) do
        table.insert(self.waves, Wave.New(waveData))
    end

    -- 加载奖励数据
    self.rewards = {
        oneStar = data["完成奖励_1星"] or {},
        twoStar = data["完成奖励_2星"] or {},
        threeStar = data["完成奖励_3星"] or {}
    }

    -- 创建关卡实例
    self.levels = {} ---@type Level[]
    local Level = require(MainStorage.code.server.Scene.Level) ---@type Level
    local scene = gg.server_scene_list[data["场景"]]
    if scene then
        table.insert(self.levels, Level.New(self, scene, #self.levels + 1))
    else
        print(string.format("Warning: Failed to find scene node at %s", data["场景"]))
    end

    -- 注册事件处理器
    ServerEventManager.Subscribe("LeaveQueue", function(evt)
        local player = evt.player
        if player then
            self:LeaveQueue(player)
        end
    end)

    -- 订阅玩家退出事件
    ServerEventManager.Subscribe("PlayerLeaveGameEvent", function(event)
        local player = event.player
        if player then
            -- 如果玩家在匹配队列中，将其移除
            if self.matchQueue[player.uin] then
                self:LeaveQueue(player)
            end
        end
    end)
end

--------------------------------------------------
-- 匹配系统相关方法
--------------------------------------------------

---检查是否可以开始游戏
---@return boolean
function LevelType:CanStartGame()
    return self.remainingTime <= 0
end

---更新匹配时间
function LevelType:UpdateMatchTime()
    local currentTime = os.time()
    local deltaTime = currentTime - self.lastUpdateTime
    self.lastUpdateTime = currentTime
    
    if self.remainingTime > 0 then
        self.remainingTime = math.max(0, self.remainingTime - deltaTime)
        
        -- 通知队列中的玩家当前匹配进度
        for _, player in pairs(self.matchQueue) do
            player:SendEvent("MatchProgressUpdate", {
                currentCount = self.playerCount,
                totalCount = self.maxPlayers,
                levelName = self.levelId,
                remainingTime = self.remainingTime
            })
        end
        
        -- 检查是否可以开始游戏
        if self:CanStartGame() then
            self:StartLevel()
        end
    end
end

-- 新增：判断玩家是否可以加入关卡/匹配队列
---@param player Player
---@return boolean, string? #是否可加入,失败原因
function LevelType:CanJoin(player)
    -- 检查是否已在队列
    if self.matchQueue[player.uin] then
        return false, "你已经在匹配队列中"
    end

    -- 检查进入条件
    local enterParam = self.entryConditions:Check(player, player)
    if enterParam.cancelled then
        return false, "不满足进入条件"
    end

    -- 检查前置关卡
    if self.prerequisiteLevel then
        -- TODO: 检查前置关卡是否完成
        -- 这里需要实现前置关卡的检查逻辑
    end

    -- 检查前置变量
    for varName, requiredValue in pairs(self.prerequisiteVars) do
        local currentValue = player:GetVariable(varName) or 0
        if currentValue < requiredValue then
            return false, string.format("不满足前置条件: %s 需要 %d", varName, requiredValue)
        end
    end

    -- 检查扣除变量
    for varName, deductValue in pairs(self.deductVars) do
        local currentValue = player:GetVariable(varName) or 0
        if currentValue < deductValue then
            return false, string.format("资源不足: %s 需要 %d", varName, deductValue)
        end
    end

    return true
end

---加入匹配队列
---@param player Player
---@return boolean 成功进入
function LevelType:Queue(player)
    -- 使用CanJoin统一判断
    local canJoin, reason = self:CanJoin(player)
    if not canJoin then
        player:SendChatText(reason or "无法加入匹配队列")
        return false
    end

    -- 让玩家退出所有正在进行的匹配
    for _, levelType in pairs(LevelConfig.GetAll()) do
        if levelType ~= self and levelType.matchQueue[player.uin] then
            levelType:LeaveQueue(player)
        end
    end

    -- 扣除变量（已通过CanJoin检查，这里直接扣除）
    for varName, deductValue in pairs(self.deductVars) do
        player:AddVariable(varName, -deductValue)
    end

    -- 首先检查是否有可用的关卡实例
    for _, level in ipairs(self.levels) do
        if level.isActive and level.playerCount < level.levelType.maxPlayers then
            -- 找到有位置的关卡，直接加入
            if level:AddPlayer(player) then
                player:SendChatText("已加入进行中的关卡")
                player:SendEvent("MatchStart")
                return true
            end
        end
    end

    -- 如果没有可用的关卡实例，加入匹配队列
    self.matchQueue[player.uin] = player
    self.playerCount = self.playerCount + 1
    player:SendChatText("已加入匹配队列")
    
    -- 如果是第一个玩家，初始化匹配时间
    if self.playerCount == 1 then
        self.remainingTime = (self.maxPlayers - 1) * self.extraPlayerTime
        self.lastUpdateTime = os.time()
    else
        -- 每加入一个玩家，减少匹配时间
        self.remainingTime = math.max(0, self.remainingTime - self.extraPlayerTime)
    end

    -- 通知所有玩家当前匹配进度
    for _, p in pairs(self.matchQueue) do
        p:SendEvent("MatchProgressUpdate", {
            currentCount = self.playerCount,
            totalCount = self.maxPlayers,
            levelName = self.levelId,
            remainingTime = self.remainingTime
        })
    end

    -- 检查是否可以开始游戏
    if self:CanStartGame() then
        self:StartLevel()
        return true
    end
    return false
end

---开始关卡
function LevelType:StartLevel()
    -- 找到一个可用的关卡实例
    local availableLevel = nil
    
    -- 遍历所有关卡实例，找到没有玩家的场景
    for _, level in ipairs(self.levels) do
        if not level.isActive then
            -- 检查场景中是否有玩家
            if level.playerCount == 0 then
                availableLevel = level
                break
            end
        end
    end
    
    -- 如果没有找到可用的关卡实例，创建新的
    if not availableLevel then
        local newScene = self.levels[1].scene:Clone()
        local Level = require(MainStorage.code.server.Scene.Level) ---@type Level
        availableLevel = Level.New(self, newScene, #self.levels + 1)
        table.insert(self.levels, availableLevel)
        gg.log("Created new level instance with scene:", newScene.name)
    end

    -- 将队列中的玩家添加到关卡
    for _, player in pairs(self.matchQueue) do
        availableLevel.players[player.uin] = player
    end
    -- 清空匹配队列
    self.matchQueue = {}
    self.playerCount = 0

    -- 开始关卡
    availableLevel:Start()

    -- 通知所有玩家
    for _, player in pairs(availableLevel.players) do
        player:SendChatText("匹配成功，关卡开始！")
        player:SendEvent("MatchStart")
    end
end

---从匹配队列中移除
---@param player Player
function LevelType:LeaveQueue(player)
    if self.matchQueue[player.uin] then
        self.matchQueue[player.uin] = nil
        self.playerCount = self.playerCount - 1
        player:SendChatText("已离开匹配队列")
        player:SendEvent("MatchCancel")
        
        -- 玩家退出时，增加匹配时间
        self.remainingTime = self.remainingTime + self.extraPlayerTime

        -- 通知剩余玩家当前匹配进度
        for _, p in pairs(self.matchQueue) do
            p:SendEvent("MatchProgressUpdate", {
                currentCount = self.playerCount,
                totalCount = self.maxPlayers,
                levelName = self.levelId,
                remainingTime = self.remainingTime
            })
        end
    end
end

-- 创建定时器更新所有关卡类型的匹配时间
ServerScheduler.add(function()
    for _, levelType in pairs(LevelConfig.GetAll()) do
        levelType:UpdateMatchTime()
    end
end, 1, 1)

---获取基于玩家数量的属性倍率
---@param baseMultiplier number 基础倍率
---@param playerCount number 玩家数量
---@return number 计算后的倍率
function LevelType:GetScaledMultiplier(baseMultiplier, playerCount)
    if playerCount <= 1 then
        return baseMultiplier
    end
    return baseMultiplier * (1 + self.playerCountMultiplier * (playerCount - 1))
end

---获取基于玩家数量的属性倍率
---@param attributeName string 属性名称
---@param playerCount number 玩家数量
---@return number 计算后的倍率
function LevelType:GetScaledAttributeMultiplier(attributeName, playerCount)
    if playerCount <= 1 then
        return 1
    end
    local baseMultiplier = self.playerAttributeMultiplier[attributeName] or 0
    return 1 + baseMultiplier * (playerCount - 1)
end

---获取关卡掉落物列表
---@return Item[] 掉落物列表
function LevelType:GetDrops()
    local drops = {} ---@type Item[]
    local seenItems = {} ---@type table<string, boolean>  -- 用于去重
    
    -- 处理所有波次的掉落物
    for _, wave in ipairs(self.waves) do
        for _, dropInfo in ipairs(wave.dropItems) do
            if not seenItems[dropInfo["物品"]] then
                local itemType = ItemTypeConfig.Get(dropInfo["物品"])
                if itemType then
                    local item = itemType:ToItem(1)
                    if item then
                        table.insert(drops, item)
                        seenItems[dropInfo["物品"]] = true  -- 标记为已添加
                    end
                end
            end
        end
    end
    
    -- 处理排名掉落物
    for _, rankReward in ipairs(self.rankRewards) do
        for itemTypeId, _ in pairs(rankReward["物品"] or {}) do
            if not seenItems[itemTypeId] then
                local itemType = ItemTypeConfig.Get(itemTypeId)
                if itemType then
                    local item = itemType:ToItem(1)
                    table.insert(drops, item)
                    seenItems[itemTypeId] = true  -- 标记为已添加
                end
            end
        end
    end
    
    return drops
end

return LevelType 