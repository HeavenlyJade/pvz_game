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
    
    -- 监听怪物死亡事件
    ServerEventManager.Subscribe("MobDeadEvent", function(data)
        if data.mob and self.activeMobs[data.mob.uuid] then
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
                
                -- 找出造成伤害最高的玩家
                for entityUuid, damage in pairs(data.damageRecords) do
                    -- 检查是否是玩家造成的伤害
                    local player = self.players[entityUuid]
                    if player and damage > maxDamage then
                        topDamager = player
                        maxDamage = damage
                    end
                end
                if topDamager then
                    if self.levelType.dropItems and #self.levelType.dropItems > 0 then
                        -- 计算总比重
                        local totalWeight = 0
                        for _, item in ipairs(self.levelType.dropItems) do
                            totalWeight = totalWeight + (tonumber(item["比重"]) or 1)
                        end
                        
                        -- 随机选择掉落物
                        local randomWeight = math.random() * totalWeight
                        local currentWeight = 0
                        local selectedItem = nil
                        
                        for _, item in ipairs(self.levelType.dropItems) do
                            currentWeight = currentWeight + (tonumber(item["比重"]) or 1)
                            if randomWeight <= currentWeight then
                                selectedItem = item
                                break
                            end
                        end
                        
                        if selectedItem then
                            -- 计算基础数量
                            local baseCount = gg.eval(selectedItem["数量"]:gsub("LVL", tostring(data.mob.level)))
                            if self.levelType.dropModifier then
                                local castParam = self.levelType.dropModifier:Check(topDamager, topDamager)
                                if castParam.cancelled then
                                    baseCount = 0
                                else
                                    baseCount = baseCount * castParam.power
                                end
                            end
                            if baseCount > 0 then
                                -- 如果没有修改器，直接发放基础数量
                                topDamager.bag:GiveItem(ItemTypeConfig.Get(selectedItem["物品"]):ToItem(baseCount))
                            end
                        end
                    end
                end
            end
            
            self.activeMobs[data.mob.uuid] = nil
            
            -- 检查波次是否结束
            if self.remainingMobCount == 0 and #self.spawningWaves == 0 and #self.notSpawningWaves == 0 then
                self:OnWaveEnd()
            end
        end
    end)
end

---开始关卡
function Level:Start()
    gg.log("[Level] Starting level", self.levelType.levelId)
    if self.isActive then 
        gg.log("[Level] Level is already active, returning", self.levelType.levelId)
        return 
    end
    self.isActive = true
    self.startTime = os.time()
    self.currentStars = 0

    -- 将关卡添加到活跃关卡列表
    activeLevels[self.scene] = self
    gg.log("[Level] Added to active levels", self.levelType.levelId, "Total active levels:", #activeLevels)

    -- 计算所有波次的怪物数量
    local waveMobCounts = {} ---@type table<number, number>
    local totalMobCount = 0
    for _, wave in ipairs(self.levelType.waves) do
        local mobCount = wave:CalculateMobCount()
        table.insert(waveMobCounts, mobCount)
        totalMobCount = totalMobCount + mobCount
    end
    gg.log("[Level] Wave mob counts calculated", self.levelType.levelId, "Total mobs:", totalMobCount)

    -- 将玩家传送到进入点
    local playerIndex = 1
    for _, player in pairs(self.players) do
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
            player:SetCameraView(entryPoint.Euler)
            local oldGrav = player.actor.Gravity
            player.actor.Gravity = 0
            ServerScheduler.add(function ()
                player.actor.Gravity = oldGrav
                player.actor.Position = entryPoint.Position
                player:EnterBattle()
                player:SetMoveable(false)
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
    gg.log("[Level] Initializing waves", self.levelType.levelId)
    self:InitializeWaves()
    gg.log("[Level] Starting first wave", self.levelType.levelId)
    self:StartWave()
    gg.log("[Level] Starting update task", self.levelType.levelId)
    self:StartUpdateTask()
end

---初始化波次
function Level:InitializeWaves()
    gg.log("[Level] InitializeWaves called", self.levelType.levelId, #self.levelType.waves)
    self.allWaves = {}
    for _, wave in ipairs(self.levelType.waves) do
        table.insert(self.allWaves, wave)
    end
    self.waveCount = 0
    self.mobCount = {}
    gg.log("[Level] Waves initialized", self.levelType.levelId, "Total waves:", #self.allWaves)
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
    gg.log("[Level] StartWave called", self.levelType.levelId)
    if #self.allWaves == 0 then
        gg.log("[Level] No more waves, completing level", self.levelType.levelId)
        self:OnLevelComplete()
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

    gg.log("[Level] Wave started", self.levelType.levelId, "Wave:", self.waveCount, "Mob count:", self.currentWaveMobCount, "Player count:", self.playerCount)

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
            healthPercent = 1.0
        })
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
    local newTimeElapsed = os.time() - self.waveStartTime

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
        -- 计算基于玩家数量的属性倍率
        local monsterLevel = self:GetAveragePlayerLevel()
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
            for attrName, baseMultiplier in pairs(self.levelType.playerAttributeMultiplier) do
                local mult = baseMultiplier * (self.playerCount - 1)
                mob:AddStat(attrName, mult * mob:GetStat(attrName), "BASE", true)
            end
            
            -- 随机选择一个玩家作为目标
            local players = {}
            for _, player in pairs(self.players) do
                table.insert(players, player)
            end
            if #players > 0 then
                local randomPlayer = players[math.random(1, #players)]
                mob:SetTarget(randomPlayer)
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
    gg.log("[Level] Cleanup called", self.levelType.levelId)
    
    -- 清理所有怪物
    for _, mob in pairs(self.activeMobs) do
        if mob and mob.isEntity then
            gg.log("[Level] Destroying mob", mob.uuid)
            mob:DestroyObject()
        end
    end
    self.activeMobs = {}
    
    -- 重置关卡状态
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
    
    -- 清理掉落物
    -- TODO: 实现掉落物清理
    
    gg.log("[Level] Cleanup completed", self.levelType.levelId)
end

---结束关卡
---@param success boolean 是否成功完成
function Level:End(success)
    gg.log("[Level] End called", self.levelType.levelId, "Success:", success)
    if not self.isActive then 
        gg.log("[Level] Level is not active, returning", self.levelType.levelId)
        return 
    end
    self.isActive = false
    self.endTime = os.time()
    
    -- 从活跃关卡列表中移除
    activeLevels[self.scene] = nil
    gg.log("[Level] Removed from active levels", self.levelType.levelId, "Remaining active levels:", #activeLevels)
    
    if self.updateTask then
        ServerScheduler.cancel(self.updateTask)
        self.updateTask = nil
    end

    -- 传送玩家回原始位置
    for _, player in pairs(self.players) do
        local originalPos = self.playerOriginalPositions[player.uin]
        if player.actor and originalPos then
            player:ProcessQuestEvent("level_".. self.levelType.levelId, 1)
            player.actor.Position = originalPos.position
            player.actor.Euler = originalPos.euler
            player:SetCameraView(originalPos.euler)
            player:ExitBattle()
            player:SendChatText("已传送回原位置")
        end
    end

    -- 清理场景
    self:Cleanup()

    -- 通知玩家
    for _, player in pairs(self.players) do
        player:SendEvent("BattleEndEvent", {
            levelId = self.levelType.levelId,
            success = success,
            stars = self.currentStars,
            duration = self.endTime - self.startTime
        })
        player:SendChatText(success and "Level completed!" or "Level failed!")
    end
    gg.log("[Level] End completed", self.levelType.levelId)
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
function Level:RemovePlayer(player)
    if self.players[player.uin] then
        self.players[player.uin] = nil
        self.playerCount = self.playerCount - 1
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