local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local LevelType = require(MainStorage.code.common.config_type.LevelType) ---@type LevelType
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
---@class Level
---@field New fun( levelType:LevelType, scene:Scene, index:number ):Level
local Level = ClassMgr.Class("Level")

-- 存储所有活跃的关卡实例
local activeLevels = {} ---@type table<string, Level>

--- 获取玩家当前所在的关卡
---@param player Player 玩家对象
---@return Level|nil 玩家所在的关卡，如果不在任何关卡中则返回nil
function Level.GetCurrentLevel(player)
    if not player or not player.uin then return nil end

    -- 遍历所有活跃关卡
    for _, level in pairs(activeLevels) do
        if level.players[player.uin] then
            return level
        end
    end
    return nil
end

---@param levelType LevelType
function Level:OnInit(levelType, scene, index)
    self.scene = scene ---@type Scene
    local sceneNode = scene.node
    self.levelType = levelType

    -- 玩家进入点
    self.entries = {} ---@type Transform[]
    for _, node in pairs(sceneNode["出生点"].Children) do
        table.insert(self.entries, node)
    end
    self.spawnPoints = {} ---@type Transform[]
    for _, node in pairs(sceneNode["刷怪点"].Children) do
        table.insert(self.spawnPoints, node)
    end

    -- 运行时状态
    self.players = {} ---@type table<string, Player>
    self.playerCount = 0 ---@type number
    self.playerOriginalPositions = {} ---@type table<string, {position:Vector3, euler:Vector3}>
    self.isActive = false
    self.startTime = 0
    self.endTime = 0
    self.currentStars = 0

    -- 波次相关
    self.currentWave = nil ---@type Wave
    self.allWaves = {} ---@type Wave[]
    self.spawningWaves = {} ---@type SpawningWave[]
    self.notSpawningWaves = {} ---@type SpawningWave[]
    self.waveStartTime = 0
    self.timeElapsed = 0
    self.waveCount = 0
    self.mobCount = {} ---@type table<string, number>
    self.waveSpawnedCounts = {} ---@type table<SpawningWave, number>
    self.updateTask = nil ---@type number

    -- 怪物相关
    self.activeMobs = {} ---@type table<string, Monster>
    self.currentWaveMobCount = 0 ---@type number
    self.remainingMobCount = 0 ---@type number

    -- 新增
    self.playerStats = {} ---@type table<string, {kills: table<string, number>, rewards: table<string, number>}>

    -- 监听怪物死亡事件
    ServerEventManager.Subscribe("MobDeadEvent", function(data)
        if self.isActive and data.mob and self.activeMobs[data.mob.uuid] then

            -- 减少剩余怪物数量
            self.remainingMobCount = math.max(0, self.remainingMobCount - 1)

            -- 计算并同步剩余怪物百分比
            local mobPercent = self.currentWaveMobCount > 0 and (self.remainingMobCount / self.currentWaveMobCount) or 0
            for _, player in pairs(self.players) do
                player:SendEvent("WaveHealthUpdate", {
                    waveIndex = self.waveCount,
                    healthPercent = mobPercent
                })
            end

            -- 处理击杀奖励
            if data.damageRecords then
                local topDamager = nil
                local maxDamage = 0
                for entityUuid, damage in pairs(data.damageRecords) do
                    local player = self.players[entityUuid]
                    if player and damage > maxDamage then
                        topDamager = player
                        maxDamage = damage
                    end
                end
                if topDamager then
                    -- 记录击杀
                    local uin = topDamager.uin
                    self.playerStats[uin] = self.playerStats[uin] or {kills = {}, rewards = {}}
                    local mobName = data.mob.name or tostring(data.mob.uuid)
                    self.playerStats[uin].kills[mobName] = (self.playerStats[uin].kills[mobName] or 0) + 1

                    -- 优先使用波次级别的掉落物配置
                    local dropItems = self.currentWave and self.currentWave.dropItems
                    if dropItems and #dropItems > 0 then
                        for _, item in ipairs(dropItems) do
                            local chance = tonumber(item["几率"]) or 0
                            if math.random(0, 99) < chance then
                                local baseCount = gg.ProcessFormula(item["数量"]:gsub("LVL", tostring(data.mob.level)), topDamager, topDamager)
                                if self.levelType.dropModifier then
                                    local castParam = self.levelType.dropModifier:Check(topDamager, topDamager)
                                    if castParam.cancelled then
                                        baseCount = 0
                                    else
                                        baseCount = baseCount * castParam.power
                                    end
                                end
                                if baseCount > 0 then
                                    local itemName = item["物品"]
                                    self.playerStats[uin].rewards[itemName] = (self.playerStats[uin].rewards[itemName] or 0) + baseCount
                                    topDamager.bag:GiveItem(ItemTypeConfig.Get(itemName):ToItem(baseCount))
                                end
                            end
                        end
                    end
                end
            end

            self.activeMobs[data.mob.uuid] = nil
            -- 正确计算activeMobs数量
            local activeMobCount = 0
            for _ in pairs(self.activeMobs) do
                activeMobCount = activeMobCount + 1
            end

            -- 检查波次是否结束
            if self.remainingMobCount == 0 and #self.spawningWaves == 0 and #self.notSpawningWaves == 0 then
                self:OnWaveEnd()
            end
        elseif data.mob then
        end
    end)

    -- 监听玩家死亡事件
    ServerEventManager.Subscribe("PlayerDeadEvent", function(data)
        if self.isActive and data.player and self.players[data.player.uin] then

            -- 播放失败音效
            if self.levelType.loseSound then
                data.player:PlaySound(self.levelType.loseSound)
            end

            -- 注意：这里不减少playerCount，因为死亡的玩家仍然在关卡中

            -- 通知其他玩家
            for _, player in pairs(self.players) do
                if player.uin ~= data.player.uin then
                    player:SendChatText(string.format("玩家 %s 已阵亡", data.player.name))
                end
            end
            -- 检查是否所有玩家都死亡
            local alivePlayerCount = 0
            for _, player in pairs(self.players) do
                if not player.isDead then
                    alivePlayerCount = alivePlayerCount + 1
                end
            end

            if alivePlayerCount == 0 then
                -- 所有玩家都死亡，结束关卡
                self:End(false)
            end
        end
    end)

    -- 订阅玩家退出事件
    ServerEventManager.Subscribe("PlayerLeaveGameEvent", function(event)
        local player = event.player
        if player then
            -- 如果玩家在副本中，将其移除
            if self.players[player.uin] then
                self:RemovePlayer(player)
            end
        end
    end)

    -- 监听玩家离开场景事件
    ServerEventManager.Subscribe("PlayerLeaveSceneEvent", function(event)
        local player = event.player
        local scene = event.scene
        if player and scene == self.scene then
            if self.players[player.uin] then
                self:RemovePlayer(player)
            end
        end
    end)
end

---开始关卡
function Level:Start()
    if self.isActive then
        return
    end
    self.isActive = true
    self.startTime = os.time()
    self.currentStars = 0

    -- 将关卡添加到活跃关卡列表
    activeLevels[self.scene] = self

    -- 计算所有波次的怪物数量
    local waveMobCounts = {} ---@type table<number, number>
    local totalMobCount = 0
    for _, wave in ipairs(self.levelType.waves) do
        local mobCount = wave:CalculateMobCount()
        table.insert(waveMobCounts, mobCount)
        totalMobCount = totalMobCount + mobCount
    end

    -- 将玩家传送到进入点
    local playerIndex = 1
    gg.log("关卡开始: 传送", self.playerCount, "个玩家到进入点")
    for _, player in pairs(self.players) do
        gg.log("处理玩家:", player.name, "UIN:", player.uin, "索引:", playerIndex)
        -- 保存玩家原始位置
        if player.actor then
            self.playerOriginalPositions[player.uin] = {
                position = player.actor.Position,
                euler = player.actor.Euler
            }
        end

        -- 获取进入点位置
        local entryPoint = self.entries[playerIndex]
        if not entryPoint then
            playerIndex = 1
            -- 如果没有足够的进入点，循环使用
            entryPoint = self.entries[playerIndex]
        end

        -- 传送玩家
        if player.actor and entryPoint then
            player.actor.Position = entryPoint.Position
            player.actor.Euler = Vector3.New(0, entryPoint.Euler.y, 0)
            player:SetCameraView(player.actor.Euler)
            local oldGrav = player.actor.Gravity
            player.actor.Gravity = 0
            -- 为每个玩家创建独立的定时器，避免闭包问题
            local currentPlayer = player  -- 创建局部变量副本
            local currentEntryPoint = entryPoint  -- 创建局部变量副本
            ServerScheduler.add(function ()
                if currentPlayer.actor then
                    currentPlayer.actor.Gravity = oldGrav
                    currentPlayer.actor.Position = currentEntryPoint.Position
                    currentPlayer:EnterBattle()
                    currentPlayer:SetMoveable(false)
                end
            end, 3)
        end

        -- 发送战斗开始事件
        player:SendEvent("BattleStartEvent", {
            levelId = self.levelType.levelId,
            waveMobCounts = waveMobCounts,
            totalMobCount = totalMobCount
        })

        playerIndex = playerIndex + 1
    end

    -- 确保重新初始化波次
    self:InitializeWaves()
    self:StartWave()
    self:StartUpdateTask()
end

---初始化波次
function Level:InitializeWaves()
    self.allWaves = {}
    for _, wave in ipairs(self.levelType.waves) do
        table.insert(self.allWaves, wave)
    end
    self.waveCount = 0
    self.mobCount = {}
end

---计算玩家平均等级
---@return number 平均等级
function Level:GetAveragePlayerLevel()
    local totalLevel = 0
    local playerCount = 0
    for _, player in pairs(self.players) do
        totalLevel = totalLevel + player.level
        playerCount = playerCount + 1
    end
    return playerCount > 0 and math.floor(totalLevel / playerCount) or self.levelType.monsterLevel
end

---开始波次
function Level:StartWave()
    if #self.allWaves == 0 then
        -- 延迟一段时间再完成关卡，确保所有玩家都已经变身
        ServerScheduler.add(function()
            self:OnLevelComplete()
        end, 5)  -- 延迟5秒，确保玩家变身完成
        return
    end

    self.waveStartTime = os.time()
    self.timeElapsed = self.waveStartTime
    self.currentWave = table.remove(self.allWaves, 1)
    self.waveCount = self.waveCount + 1

    -- 计算当前波次的怪物总数，考虑玩家数量倍率
    local baseMobCount = self.currentWave:CalculateMobCount()
    self.currentWaveMobCount = math.floor(baseMobCount * self.levelType:GetScaledMultiplier(1, self.playerCount))
    self.remainingMobCount = self.currentWaveMobCount


    -- 初始化未开始的刷怪波次
    self.notSpawningWaves = {}
    for _, wave in ipairs(self.currentWave.spawningWaves) do
        table.insert(self.notSpawningWaves, wave)
    end

    -- 执行波次开始时的指令
    if self.currentWave.startCommands then
        for _, player in pairs(self.players) do
            player:ExecuteCommands(self.currentWave.startCommands)
        end
    end

    -- 通知玩家波次开始和初始怪物数量
    for _, player in pairs(self.players) do
        player:SendEvent("WaveHealthUpdate", {
            waveIndex = self.waveCount,
            healthPercent = 1.0,
            waveImg = self.currentWave.waveImg
        })
        player:PlaySound(self.currentWave.waveSound)
    end
end

---启动更新任务
function Level:StartUpdateTask()
    if self.updateTask then
        ServerScheduler.cancel(self.updateTask)
    end

    self.updateTask = ServerScheduler.add(function()
        self:Update()
    end, 0, 1.0) -- 立即开始，每秒执行一次
end

---更新关卡状态
function Level:Update()
    if not self.isActive or not self.currentWave then return end

    -- 检查是否还有存活的玩家
    local alivePlayerCount = 0
    for _, player in pairs(self.players) do
        if not player.isDead then
            alivePlayerCount = alivePlayerCount + 1
        end
    end

    -- 如果没有存活玩家，停止生成怪物并结束关卡
    if alivePlayerCount == 0 then
        self:End(false)
        return
    end

    local newTimeElapsed = os.time() - self.waveStartTime

    -- 计算波次进度（0-1）
    local waveProgress = 0
    if self.currentWave then
        -- 计算波次的总持续时间
        local totalDuration = 0
        for _, wave in ipairs(self.currentWave.spawningWaves) do
            totalDuration = math.max(totalDuration, wave.startTime + wave.duration)
        end
        if totalDuration > 0 then
            waveProgress = math.min(1.0, newTimeElapsed / totalDuration)
        end
    end

    -- 检查是否需要开始新的刷怪波次
    for i = #self.notSpawningWaves, 1, -1 do
        local wave = self.notSpawningWaves[i]
        if wave.startTime < newTimeElapsed then
            table.insert(self.spawningWaves, wave)
            table.remove(self.notSpawningWaves, i)
            -- 初始化新波次的生成计数
            self.waveSpawnedCounts[wave] = 0
        end
    end

    -- 更新所有正在进行的刷怪波次
    for i = #self.spawningWaves, 1, -1 do
        local wave = self.spawningWaves[i]
        -- 根据波次进度动态计算怪物等级
        local monsterLevel = self.currentWave:GetCurrentMonsterLevel(waveProgress)
        local spawnedCount = self.waveSpawnedCounts[wave] or 0
        local isComplete, spawnedMobs, newSpawnedCount = wave:TrySpawn(
            newTimeElapsed - self.timeElapsed,
            monsterLevel,
            self,
            spawnedCount
        )
        -- 更新生成计数
        self.waveSpawnedCounts[wave] = newSpawnedCount
        -- 处理生成的怪物
        for _, mob in ipairs(spawnedMobs) do
            -- 缓存怪物实例
            self.activeMobs[mob.uuid] = mob
            -- 正确计算activeMobs数量
            local activeMobCount = 0
            for _ in pairs(self.activeMobs) do
                activeMobCount = activeMobCount + 1
            end

            for attrName, baseMultiplier in pairs(self.levelType.playerAttributeMultiplier) do
                local mult = baseMultiplier * (self.playerCount - 1)
                mob:AddStat(attrName, mult * mob:GetStat(attrName), "BASE", true)
            end

            -- 随机选择一个活着的玩家作为目标
            local alivePlayers = {}
            for _, player in pairs(self.players) do
                if not player.isDead then
                    table.insert(alivePlayers, player)
                end
            end
            if #alivePlayers > 0 then
                local randomPlayer = alivePlayers[math.random(1, #alivePlayers)]
                mob:SetTarget(randomPlayer)
            else
            end
        end

        if isComplete then
            table.remove(self.spawningWaves, i)
            self.waveSpawnedCounts[wave] = nil
        end
    end

    -- 检查当前波次是否结束
    if #self.spawningWaves == 0 and #self.notSpawningWaves == 0 and self.remainingMobCount == 0 then
        self:OnWaveEnd()
    end

    self.timeElapsed = newTimeElapsed
end

---波次结束
function Level:OnWaveEnd()
    -- 清理当前波次的所有刷怪波次
    self.spawningWaves = {}
    self.notSpawningWaves = {}
    -- 开始下一波
    self:StartWave()
end

---关卡完成
function Level:OnLevelComplete()
    -- 计算星级
    local star = 1
    -- if self.levelType.twoStarConditions then
    --     local param = self.levelType.twoStarConditions:Check()
    --     if param.cancelled then star = star + 1 end
    -- else
    --     star = star + 1
    -- end

    -- if self.levelType.threeStarConditions then
    --     local param = CastParam.New()
    --     for _, condition in ipairs(self.levelType.threeStarConditions) do
    --         local stop = condition:Check(self.players[1], self.players[1], param)
    --         if stop then break end
    --     end
    --     if param.cancelled then star = star + 1 end
    -- else
    --     star = star + 1
    -- end

    -- -- 通知服务器
    -- gg.network_channel:fireServer("level", "finish", {
    --     id = self.levelType.levelId,
    --     stars = star,
    --     mobCount = self.mobCount
    -- })

    -- 结束关卡
    self:End(true)
end

---清理场景
function Level:Cleanup()
    -- 正确计算activeMobs数量
    local activeMobCount = 0
    for _ in pairs(self.activeMobs) do
        activeMobCount = activeMobCount + 1
    end
    self.isActive = false
    self.startTime = 0
    self.endTime = 0
    self.currentStars = 0
    self.currentWave = nil
    self.allWaves = {}
    self.spawningWaves = {}
    self.notSpawningWaves = {}
    self.waveStartTime = 0
    self.timeElapsed = 0
    self.waveCount = 0
    self.mobCount = {}
    self.currentWaveMobCount = 0
    self.remainingMobCount = 0
    self.waveSpawnedCounts = {}

    local destroyedCount = 0
    local failedCount = 0

    for uuid, mob in pairs(self.activeMobs) do
        if mob and mob.isEntity then
            local success, err = pcall(function()
                mob:DestroyObject()
            end)
            if success then
                destroyedCount = destroyedCount + 1
            else
                failedCount = failedCount + 1
            end
        else
            failedCount = failedCount + 1
        end
    end

    self.activeMobs = {}
end

---结束关卡
---@param success boolean 是否成功完成
function Level:End(success)
    if not self.isActive then
        return
    end
    self.isActive = false
    self.endTime = os.time()

    -- 从活跃关卡列表中移除
    activeLevels[self.scene] = nil

    if self.updateTask then
        ServerScheduler.cancel(self.updateTask)
        self.updateTask = nil
    end

    -- 处理排名掉落物
    if success and self.levelType.rankRewards and #self.levelType.rankRewards > 0 then
        -- 计算玩家排名（基于击杀数量）
        local playerRankings = {}
        for uin, stats in pairs(self.playerStats) do
            local totalKills = 0
            for _, killCount in pairs(stats.kills) do
                totalKills = totalKills + killCount
            end
            table.insert(playerRankings, {
                uin = uin,
                kills = totalKills,
                player = self.players[uin]
            })
        end

        -- 按击杀数量排序
        table.sort(playerRankings, function(a, b) return a.kills > b.kills end)

        -- 发放排名奖励
        for rankIndex, ranking in ipairs(playerRankings) do
            for _, rankReward in ipairs(self.levelType.rankRewards) do
                local rankNumber = rankReward["名次"]
                -- 处理名次字段可能是数组格式的情况
                if type(rankNumber) == "table" then
                    if rankNumber.y then
                        -- 如果是Vector3对象，使用y值
                        rankNumber = rankNumber.y
                    elseif #rankNumber > 0 then
                        -- 如果是数组，使用第一个值
                        rankNumber = rankNumber[1]
                    end
                end
                if rankIndex == rankNumber then
                    local player = ranking.player
                    if player then
                        for itemName, count in pairs(rankReward["物品"]) do
                            player.bag:GiveItem(ItemTypeConfig.Get(itemName):ToItem(count))
                            -- 记录排名奖励
                            self.playerStats[player.uin] = self.playerStats[player.uin] or {kills = {}, rewards = {}}
                            self.playerStats[player.uin].rewards[itemName] = (self.playerStats[player.uin].rewards[itemName] or 0) + count
                        end
                    end
                    break
                end
            end
        end
    end

    for _, player in pairs(self.players) do
        -- 复活死亡的玩家
        if player.isDead then
            player:CompleteRespawn()
        end

        if success then
            player:PlaySound(self.levelType.winSound)
        end
        local originalPos = self.playerOriginalPositions[player.uin]
        if player.actor and originalPos then
            player:ProcessQuestEvent("level_".. self.levelType.levelId, 1)
            player.actor.Position = originalPos.position
            player.actor.Euler = originalPos.euler
            player:SetCameraView(originalPos.euler)
            player:SendChatText("已传送回原位置")
        end
        local stats = self.playerStats[player.uin] or {kills = {}, rewards = {}}
        player:SendEvent("DungeonClearedStats", {
            text = success and "关卡完成！" or "关卡失败！",
            kills = stats.kills,
            rewards = stats.rewards
        })
        player:SendEvent("BattleEndEvent", {
            levelId = self.levelType.levelId,
            success = success,
            stars = self.currentStars,
            duration = self.endTime - self.startTime
        })
        player:SendChatText(success and "Level completed!" or "Level failed!")
        player:ExitBattle()
    end

    -- 清理场景
    self:Cleanup()
end

---添加玩家
---@param player Player
function Level:AddPlayer(player)
    if self.playerCount >= self.levelType.maxPlayers then
        return false
    end
    self.players[player.uin] = player
    self.playerCount = self.playerCount + 1
    return true
end

---移除玩家
---@param player Player
function Level:RemovePlayer(player, success)
    if self.players[player.uin] then
        self.players[player.uin] = nil
        self.playerCount = math.max(0, self.playerCount - 1)

        local originalPos = self.playerOriginalPositions[player.uin]
        if player.actor and originalPos then
            player.actor.Position = originalPos.position
            player.actor.Euler = originalPos.euler
            player:SetCameraView(originalPos.euler)
        end
        local stats = self.playerStats[player.uin] or {kills = {}, rewards = {}}
        player:SendEvent("DungeonClearedStats", {
            text = string.format("成功完成第%d波", self.waveCount),
            kills = stats.kills,
            rewards = stats.rewards
        })
        player:SendEvent("BattleEndEvent", {
            levelId = self.levelType.levelId,
            success = false,
            stars = self.currentStars,
            duration = self.endTime - self.startTime
        })
        player:ExitBattle()
    end
    if self.playerCount == 0 then
        self:End(false)
    end
end

---检查是否满足进入条件
---@param player Player
---@return boolean
function Level:CheckEntryConditions(player)
    local castParam = self.levelType.entryConditions:Check(player, player)
    return not castParam.cancelled
end

---检查是否满足星级条件
---@param starLevel number 1-3星
---@return boolean
function Level:CheckStarConditions(starLevel)
    -- TODO: 实现星级条件检查
    return false
end

---暂停关卡
function Level:Pause()
    if not self.isActive then return end

    -- 取消更新任务
    if self.updateTask then
        ServerScheduler.cancel(self.updateTask)
        self.updateTask = nil
    end

    -- 记录暂停时间
    self.pauseTime = os.time()

    -- 通知所有玩家
    for _, player in pairs(self.players) do
        player:SendChatText("关卡已暂停")
    end
end

---恢复关卡
function Level:Resume()
    if not self.isActive then return end

    -- 计算暂停时长
    local pauseDuration = os.time() - (self.pauseTime or os.time())

    -- 调整时间相关变量
    self.waveStartTime = self.waveStartTime + pauseDuration
    self.timeElapsed = self.timeElapsed + pauseDuration

    -- 重新启动更新任务
    self:StartUpdateTask()

    -- 通知所有玩家
    for _, player in pairs(self.players) do
        player:SendChatText("关卡已继续")
    end
end

return Level
