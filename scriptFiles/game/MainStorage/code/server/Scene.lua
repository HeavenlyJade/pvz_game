local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local common_const = require(MainStorage.code.common.MConst) ---@type common_const
local NpcConfig = require(MainStorage.config.NpcConfig) ---@type NpcConfig
local AfkSpotConfig = require(MainStorage.config.AfkSpotConfig) ---@type AfkSpotConfig
local TriggerZoneConfig = require(MainStorage.config.TriggerZoneConfig) ---@type TriggerZoneConfig
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local Monster = require(MainStorage.code.server.entity_types.Monster) ---@type Monster
local Npc = require(MainStorage.code.server.entity_types.Npc) ---@type Npc
local AfkSpot = require(MainStorage.code.server.entity_types.AfkSpot) ---@type AfkSpot
local TriggerZone = require(MainStorage.code.server.entity_types.TriggerZone) ---@type TriggerZone
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler


local BagMgr = require(MainStorage.code.server.bag.BagMgr) ---@type BagMgr

---@class Scene:Class
---@field sceneId number 场景ID
---@field info table 场景信息
---@field name string 场景名称
---@field players table<number, Player> 玩家列表
---@field monsters table<string, Monster> 怪物列表
---@field npcs table<string, Npc> NPC列表
---@field monster_spawns table<string, {count: number, config: table}> 刷怪点管理
---@field drop_boxs table<string, any> 掉落物品列表
---@field scene_config table 当前地图的节点scene刷怪配置
---@field npc_spawn_config table 当前地图的NPC刷新点
---@field tick number 总tick值(递增)
---@field node SandboxNode
local _M = ClassMgr.Class("Scene")
_M.sceneId = 1
_M.spawnScene = nil
local maxSlotRad = 2
local unusedSlots = {} ---@type table[int, int]
local occupiedSlot = {} ---@type Scene[][]


---@return Scene
function _M:Clone()
    if #unusedSlots == 0 then
        maxSlotRad = maxSlotRad + 1
        -- 生成新的方形环坐标
        for x = -maxSlotRad, maxSlotRad do
            for y = -maxSlotRad, maxSlotRad do
                -- 只添加方形环上的点（不包括内部点）
                if math.abs(x) == maxSlotRad or math.abs(y) == maxSlotRad then
                    -- 将坐标转换为单个数字（使用位运算）
                    local slot = {x, y}
                    table.insert(unusedSlots, slot)
                end
            end
        end
    end

    if #unusedSlots == 0 then
        error("No available slots for scene cloning")
    end

    local slot = unusedSlots[#unusedSlots]
    unusedSlots[#unusedSlots] = nil
    local node = self.node:Clone()
    node.Position = Vector3.New(10000 * slot[1], 0, 10000 * slot[2])
    if node["副本隐藏"] then
        node["副本隐藏"].Visible = true
        for _, child in ipairs(node["副本隐藏"].Children) do
            child.EnablePhysics = true
        end
    end
    node.Parent = self.node.Parent
    node.Name = self.name .. string.format("_%s_%s", slot[1], slot[2])
    return _M.New(node)
end

---初始化场景中的NPC
function _M:initNpcs()
    local all_npcs = NpcConfig.GetAll()
    for npc_name, npc_data in pairs(all_npcs) do
        if npc_data["场景"] == self.name then
            local sceneNode = self.node["NPC"]
            gg.log("初始化NPC：", npc_name, "场景：", npc_data["场景"], "节点名：", npc_data["节点名"])

            if not sceneNode then
                gg.log("错误：场景中没有NPC节点容器")
            else
                local actor = gg.GetChild(sceneNode, npc_data["节点名"])
                if not actor then
                    gg.log("错误：找不到NPC节点：", npc_name, "节点名：", npc_data["节点名"])
                    -- 安全地获取子节点信息
                    local children = {}
                    if sceneNode.Children then
                        for _, child in ipairs(sceneNode.Children) do
                            if child and child.Name then
                                table.insert(children, child.Name)
                            end
                        end
                    end
                    gg.log("可用的NPC节点：", table.concat(children, ", "))
                else
                    gg.log("找到NPC节点：", npc_name, "节点名：", actor.Name)

                    local npc = Npc.New(npc_data, actor)
                    self.uuid2Entity[actor] = npc
                    self.npcs[npc.uuid] = npc
                    npc:ChangeScene(self)

                    gg.log("NPC创建成功：", npc_name, "UUID：", npc.uuid)
                end
            end
        end
    end
end

function _M:PlaySound(soundAssetId, boundTo, volume, pitch, range)
    if soundAssetId == "" then
        return
    end
    for _, player in pairs(self.players) do
        player:PlaySound(soundAssetId, boundTo, volume, pitch, range)
    end
end

---@return SandboxNode
function _M:Get(path)
    local node = self.node
    local lastPart = ""
    for part in path:gmatch("[^/]+") do -- 用/分割字符串
        if part ~= "" then
            lastPart = part
            if not node then
                gg.log(string.format("场景[%s]获取路径[%s]失败: 在[%s]处节点不存在", self.name, path, lastPart))
                return nil
            end
            node = node[part]
        end
    end
    return node
end

---初始化场景中的挂机点
function _M:initAfkSpots()
    local all_afk_spots = AfkSpotConfig.GetAll()
    for afk_name, afk_data in pairs(all_afk_spots) do
        if afk_data["场景"] == self.name then
            local sceneNode = self.node["挂机点"]
            if not sceneNode then
                gg.log("错误：场景中没有挂机点节点容器")
            else
                for _, node_name in ipairs(afk_data["节点名"]) do
                    local actor = gg.GetChild(sceneNode, node_name)
                    if not actor then
                        gg.log("错误：找不到挂机点节点：", afk_name, "节点名：", node_name)
                        -- 安全地获取子节点信息
                        local children = {}
                        if sceneNode.Children then
                            for _, child in ipairs(sceneNode.Children) do
                                if child and child.Name then
                                    table.insert(children, child.Name)
                                end
                            end
                        end
                        gg.log("可用的挂机点节点：", table.concat(children, ", "))
                    else
                        local afk_spot = AfkSpot.New(afk_data, actor)
                        afk_spot.scene = self
                        self.uuid2Entity[actor] = afk_spot
                        self.npcs[afk_spot.uuid] = afk_spot
                        afk_spot:ChangeScene(self)
                    end
                end
            end
        end
    end
    local all_afk_spots = TriggerZoneConfig.GetAll()
    for afk_name, afk_data in pairs(all_afk_spots) do
        if afk_data["场景"] == self.name then
            local sceneNode = self.node["挂机点"]
            if not sceneNode then
                gg.log("错误：场景中没有挂机点节点容器")
            else
                for _, node_name in ipairs(afk_data["节点名"]) do
                    local actor = sceneNode[node_name]
                    if not actor then
                        gg.log("错误：找不到挂机点节点：", afk_name, "节点名：", node_name)
                        local children = {}
                        if sceneNode.Children then
                            for _, child in ipairs(sceneNode.Children) do
                                if child and child.Name then
                                    table.insert(children, child.Name)
                                end
                            end
                        end
                        gg.log("可用的挂机点节点：", table.concat(children, ", "))
                    else
                        local afk_spot = TriggerZone.New(afk_data, actor)
                        afk_spot.scene = self
                        self.uuid2Entity[actor] = afk_spot
                        self.npcs[afk_spot.uuid] = afk_spot
                        afk_spot:ChangeScene(self)
                    end
                end
            end
        end
    end
end

---创建新的场景实例
---@param info_ table 场景信息
function _M:OnInit(node)
    self.name = node.Name
    self.sceneId = _M.sceneId
    _M.sceneId = _M.sceneId + 1
    self.players = {} -- 玩家列表  [uin  = Player]
    self.monsters = {} -- 怪物列表  [uuid = Monster]
    self.level = nil --使用本场景的关卡
    self.npcs = {} -- NPC列表
    self.monster_spawns = {} -- 刷怪点管理   [ spawn_name = { count, config } ]
    self.entities = {} ---@type table<number, Entity[]>
    self.npc_spawns = {}
    self.drop_boxs = {} -- 掉落物品列表
    self.uuid2Entity = {}
    self.tick = 0 -- 总tick值(递增)

    self.scene_config = nil -- 当前地图的节点scene刷怪配置,
    self.npc_spawn_config = {} -- 当前地图的NPC刷新点
    self.node = node
    self.sceneZone = self.node["场景区域"] ---@type TriggerBox
    if self.sceneZone then
        self.sceneZone.Touched:Connect(function (node)
            if node then
                local entity = Entity.node2Entity[node] ---@type Entity
                if entity and entity.isPlayer then
                    ---@cast entity Player
                    -- 如果玩家正在关卡传送中，跳过场景切换
                    if entity._levelTeleporting then
                        return
                    end

                    -- 检查是否在活跃关卡中
                    local Level = require(MainStorage.code.server.Scene.Level)
                    local currentLevel = Level.GetCurrentLevel(entity)
                    if currentLevel and currentLevel.isActive then
                        return
                    end

                    entity:ChangeScene(self)
                elseif entity then
                    -- 非玩家实体直接切换
                    entity:ChangeScene(self)
                end
            end
        end)
    end
    gg.server_scene_list[ self.name ] = self

    self:initNpcs() -- Initialize NPCs after scene creation
    self:initAfkSpots() -- Initialize AfkSpots after scene creation

    -- 创建NPC更新定时任务
    self.npcUpdateTaskId = ServerScheduler.add(function()
        self:update_npcs()
    end, 0, 0.1) -- 立即开始，每秒执行一次
    self.isSpawnScene = node:GetAttribute("是出生场景") or false
    self.bgmSound = node:GetAttribute("背景音乐")
    if self.isSpawnScene then
        _M.spawnScene = self
    end
end

---更新所有NPC
function _M:update_npcs()
    for _, npc in pairs(self.npcs) do
        npc:update_npc()
    end
end

function _M:OverlapSphere(center, radius, filterGroup, filterFunc)
    local results = game:GetService('WorldService'):OverlapSphere(radius,
        Vector3.New(center.x, center.y, center.z), false, filterGroup)
    local retActors = {}
    for _, v in ipairs(results) do
        local obj = v.obj
        table.insert(retActors, obj)
        if filterFunc then
            filterFunc(obj)
        end
    end
    return retActors
end

---@return Entity[]
function _M:OverlapSphereEntity(center, radius, filterGroup, filterFunc)
    local retEntities = {}
    local radiusSq = radius * radius
    
    -- 遍历指定ColliderGroup中的所有实体
    if filterGroup then
        for _, groupId in ipairs(filterGroup) do
            if self.entities[groupId] then
                for _, entity in ipairs(self.entities[groupId]) do
                    if entity and entity.actor and not entity.isDead then
                        local entityPos = entity:GetPosition()
                        local distanceSq = gg.vec.DistanceSq3(center, entityPos)
                        
                        if distanceSq <= radiusSq then
                            if not filterFunc or filterFunc(entity.actor) then
                                table.insert(retEntities, entity)
                            end
                        end
                    end
                end
            end
        end
    else
        -- 如果没有指定filterGroup，遍历所有ColliderGroup
        for groupId, entities in pairs(self.entities) do
            for _, entity in ipairs(entities) do
                if entity and entity.actor and not entity.isDead then
                    local entityPos = entity:GetPosition()
                    local distanceSq = gg.vec.DistanceSq3(center, entityPos)
                    
                    if distanceSq <= radiusSq then
                        if not filterFunc or filterFunc(entity.actor) then
                            table.insert(retEntities, entity)
                        end
                    end
                end
            end
        end
    end
    
    return retEntities
end

function _M:OverlapBox(center, extent, angle, filterGroup, filterFunc)
    local results = game:GetService('WorldService'):OverlapBox(Vector3.New(extent.x, extent.y, extent.z),
        Vector3.New(center.x, center.y, center.z), Vector3.New(angle.x, angle.y, angle.z), false, filterGroup)
    local retActors = {}
    for _, v in ipairs(results) do
        local obj = v.obj
        table.insert(retActors, obj)
        if filterFunc then
            filterFunc(obj)
        end
    end
    return retActors
end

function _M:OverlapBoxEntity(center, extent, angle, filterGroup, filterFunc)
    local nodes = self:OverlapBox(center, extent, angle, filterGroup, filterFunc)
    local retEntities = {}
    for _, node in ipairs(nodes) do
        local entity = Entity.node2Entity[node]
        if entity then
            table.insert(retEntities, entity)
        end
    end
    return retEntities
end

-- 获取指定ColliderGroup中的所有实体
---@param filterGroup number[]|nil 要搜索的ColliderGroup列表，nil表示搜索所有
---@return Entity[]
function _M:GetEntitiesByGroup(filterGroup)
    local retEntities = {}
    
    if filterGroup then
        for _, groupId in ipairs(filterGroup) do
            if self.entities[groupId] then
                for _, entity in ipairs(self.entities[groupId]) do
                    if entity and entity.actor and not entity.isDead then
                        table.insert(retEntities, entity)
                    end
                end
            end
        end
    else
        -- 如果没有指定filterGroup，遍历所有ColliderGroup
        for groupId, entities in pairs(self.entities) do
            for _, entity in ipairs(entities) do
                if entity and entity.actor and not entity.isDead then
                    table.insert(retEntities, entity)
                end
            end
        end
    end
    
    return retEntities
end

-- 在指定范围内查找最近的实体
---@param center Vector3 中心点
---@param maxDistance number 最大距离
---@param filterGroup number[]|nil ColliderGroup筛选
---@param filterFunc fun(entity: Entity): boolean|nil 额外筛选函数
---@return Entity|nil, number 最近的实体和距离
function _M:FindNearestEntity(center, maxDistance, filterGroup, filterFunc)
    local nearestEntity = nil
    local nearestDistanceSq = maxDistance * maxDistance
    
    if filterGroup then
        for _, groupId in ipairs(filterGroup) do
            if self.entities[groupId] then
                for _, entity in ipairs(self.entities[groupId]) do
                    if entity and entity.actor and not entity.isDead then
                        if not filterFunc or filterFunc(entity) then
                            local entityPos = entity:GetPosition()
                            local distanceSq = gg.vec.DistanceSq3(center, entityPos)
                            
                            if distanceSq < nearestDistanceSq then
                                nearestEntity = entity
                                nearestDistanceSq = distanceSq
                            end
                        end
                    end
                end
            end
        end
    else
        -- 如果没有指定filterGroup，遍历所有ColliderGroup
        for groupId, entities in pairs(self.entities) do
            for _, entity in ipairs(entities) do
                if entity and entity.actor and not entity.isDead then
                    if not filterFunc or filterFunc(entity) then
                        local entityPos = entity:GetPosition()
                        local distanceSq = gg.vec.DistanceSq3(center, entityPos)
                        
                        if distanceSq < nearestDistanceSq then
                            nearestEntity = entity
                            nearestDistanceSq = distanceSq
                        end
                    end
                end
            end
        end
    end
    
    return nearestEntity, nearestEntity and math.sqrt(nearestDistanceSq) or nil
end

-- function _M:SelectCylinderTargets(center, radius, height, filterGroup, filterFunc)
--     if radius == 0 or height == 0 then
--         return {}
--     end
--     local cylinderFilter = function(entity)
--         -- 判断是否在半径内，忽略y坐标
--         local centerPos = center
--         print("target", entity)
--         local targetPos = entity:GetPosition()
--         centerPos.y = 0
--         targetPos.y = 0
--         local distance = (centerPos - targetPos).length
--         if distance > radius then
--             return false
--         end
--         if filterFunc then
--             return filterFunc(entity)
--         end
--         return true
--     end
--     local halfHeight = height / 2
--     local results = self:OverlapBoxEntity(Vector3.New(center.x, center.y + halfHeight, center.z),
--         Vector3.New(radius, halfHeight, radius), Vector3.New(0, 0, 0), filterGroup, cylinderFilter)
--     return results
-- end

---初始化地形
function _M:initTerrain()
    local ground_name_ = self.name

    local workspace = game:GetWorkSpace(self.sceneId)
    -- gg.log( 'GetWorkSpace1', workspace )

    if self.sceneId == 0 then
        -- game.WorkSpace
    else
        local environment_ = workspace:WaitForChild('Environment')
        -- gg.log( 'environment_1', environment_ )
        workspace.Environment:Destroy() -- 删除旧地形

        -- 克隆新地形
        local workspace0 = game:GetWorkSpace(0)
        environment_ = workspace0:WaitForChild('Environment'):Clone()
        environment_.Parent = workspace

        if not workspace.Ground then
            local ground_ = SandboxNode.new('SandboxNode', workspace)
            ground_.Name = 'Ground'

            gg.log('GetWorkSpace2', ground_)
        end
    end

    local gx_ = workspace.Ground[ground_name_]
    if not gx_ then
        -- 移动 ground
        if MainStorage.Ground[ground_name_] then
            MainStorage.Ground[ground_name_].Parent = workspace.Ground
            gx_ = workspace.Ground[ground_name_]
        end
    end

    if gx_ then
        if gx_.Visible == false then
            gx_.Visible = true
        end
        -- gx_.Position = Vector3.New(0,0,0)    --坐标改到中心点
    else
        gg.log('scene not exist:', ground_name_)
    end
end

---玩家离开场景
---@param player Player 玩家对象
function _M:player_leave(player)
    if not player or not player.uin then return end

    if self.players[player.uin] then
        -- 从所有NPC中移除玩家
        for _, npc in pairs(self.npcs) do
            -- 检查是否是触发区域
            if npc.playersInZone then
                npc.playersInZone[player.uuid] = nil
                -- 执行离开指令
                if npc.leaveCommands then
                    player:ExecuteCommands(npc.leaveCommands)
                end
            end

            -- 检查是否是挂机点
            if npc.occupiedByPlayer == player then
                npc:OnPlayerExit(player)
            end
        end

        -- 从场景玩家列表中移除
        self.players[player.uin] = nil
    end
    -- 发布玩家离开场景事件
    ServerEventManager.Publish("PlayerLeaveSceneEvent", { player = player, scene = self })
end

---玩家进入场景
---@param uin_ number 玩家ID
function _M:player_enter(uin_)
    if self.players[uin_] then
        -- 已经存在
    else
        local player_ = gg.server_players_list[uin_]
        if player_ then
            self.players[uin_] = player_
        end
    end
end

---获得本场景的workspace
---@return Workspace 工作空间
function _M:GetWorkSpace()
    return game:GetWorkSpace(self.sceneId)
end

---获得场景里的主建筑物gx
-- ---@return SandboxNode|nil 主建筑物节点
-- function _M:getGX()
--     if not self.sceneId then
--         gg.log('no sceneId:', self)
--         return
--     end

--     local ws_ = game:GetWorkSpace(self.sceneId)
--     if ws_ then
--         return ws_.Ground[self.name]
--     end
--     return nil
-- end

---增加一个掉落物箱
---@param item_ table 物品信息
function _M:addDrop(item_)
    item_.tick = gg.tick -- 记录tick
    self.drop_boxs[item_.uuid] = item_
end

---判断物品是否被拾取
function _M:check_drop()
    if not next(self.drop_boxs) then
        return
    end
    -- OwnerUin
    for box_uuid_, box_info_ in pairs(self.drop_boxs) do
        local pos1_ = box_info_.model.Position
        for uin_, player_ in pairs(self.players) do
            local pos2_ = player_:GetPosition()
            if not gg.fast_out_distance(pos1_, pos2_, 200) and box_info_.player_uin == uin_ then
                local player_data_ = BagMgr.GetPlayerBag(uin_)
                local drop_re = player_data_:GiveItem(box_info_)
                gg.log("玩家拾取物品和结果", box_info_, drop_re, uin_)

                if drop_re == 0 then
                    BagMgr.s2c_PlayerBagItems(uin_, {}) -- 刷新玩家背包数据
                    self.drop_boxs[box_uuid_] = nil
                    box_info_.model:Destroy()
                    break
                end
            end
        end
    end
end


---查找附近的一个目标
---@param pos2_ Vector3 目标位置
---@return Player|nil 找到的玩家
function _M:tryGetTarget(pos2_)
    for _, player_ in pairs(self.players) do
        local pos1_ = player_:GetPosition()
        if gg.fast_out_distance(pos1_, pos2_, 2400) == false then
            return player_
        end
    end
    return nil
end

---每一帧更新
function _M:update()
    if next(self.players) == nil then
        return -- 场景内没有玩家
    end
    self.tick = self.tick + 1

    -- 更新每一个玩家
    for _, player_ in pairs(self.players) do
        player_:update_player()
    end
    -- 更新每一个怪物
    for _, monster_ in pairs(self.monsters) do
        monster_:update_monster()
    end
end

---向指定玩家周围半径内的所有玩家广播事件
---@param eventName string 事件名称
---@param eventBody table 事件数据
---@param player? Player 中心玩家
---@param radius? number 广播半径，0表示向场景内所有玩家广播
function _M:BroadcastEventAround(eventName, eventBody, player, radius)
    if not eventName or not eventBody then
        gg.log("BroadcastEventAround参数错误")
        return
    end
    
    if player==nil or radius == 0 then
        -- 向场景内所有玩家广播
        for _, scenePlayer in pairs(self.players) do
            scenePlayer:SendEvent(eventName, eventBody)
        end
    else
        -- 向指定半径内的玩家广播
        local centerPos = player:GetPosition()
        local radiusSq = radius * radius
        
        for _, scenePlayer in pairs(self.players) do
            local playerPos = scenePlayer:GetPosition()
            local distanceSq = gg.vec.DistanceSq3(centerPos, playerPos)
            
            if distanceSq <= radiusSq then
                scenePlayer:SendEvent(eventName, eventBody)
            end
        end
    end
end

---场景销毁时清理
function _M:OnDestroy()
    -- 取消NPC更新定时任务
    if self.npcUpdateTaskId then
        ServerScheduler.cancel(self.npcUpdateTaskId)
        self.npcUpdateTaskId = nil
    end
end

return _M
