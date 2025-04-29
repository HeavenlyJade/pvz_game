--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local Enum         = Enum
local math         = math
local Vector2      = Vector2
local ColorQuad    = ColorQuad
local wait         = wait
local game         = game
local pairs        = pairs
local next         = next


local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const

local CMonster      = require(MainStorage.code.server.entity_types.CMonster) ---@type CMonster
local CLNpc         = require(MainStorage.code.server.entity_types.CLNpc) ---@type CLNpc

local bagMgr        = require(MainStorage.code.server.bag.MBagMgr) ---@type BagMgr


-- 场景类：单个场景实例  g0(入口大厅)
---@class CScene
---@field sceneid number
---@field info any
---@field name string
---@field players    CPlayer[]
---@field monsters   CMonster[]
---@field npcs       CLNpc[]
---@field monster_spawns any[]
---@field scene_config any[]
---@field drop_boxs any[]
---@field npc_spawn_config any[]
---@field npc_spawns any[]
local _M = {}
local mt = { __index = _M }


function _M:new(info_)
    local ins_ = {
        info             = info_, --{ name='g0' }
        name             = info_.name, --场景名字 g0 g10 g20

        sceneid          = info_.sceneid, --场景id

        players          = {},   --玩家列表  [uin  = CPlayer]
        monsters         = {},   --怪物列表  [uuid = CMonster]
        npcs             = {},   -- NPC列表
        monster_spawns   = {},   --刷怪点管理   [ spawn_name = { count, config } ]
        npc_spawns       = {},
        drop_boxs        = {},   --掉落物品列表

        tick             = 0,    --总tick值(递增)

        scene_config     = nil,  --当前地图的节点scene刷怪配置,
        npc_spawn_config = {},   -- 当前地图的NPC刷新点
    }


    if common_config.scene_config[info_.name] then
        ins_.scene_config = common_config.scene_config[info_.name]   --当前地图地图节点刷怪点
    end

    if common_config.npc_spawn_config[info_.name] then
        ins_.npc_spawn_config = common_config.npc_spawn_config[info_.name] --当前地图地图节点NPC刷怪点
    end

    local ret_ = setmetatable(ins_, mt);
    return ret_
end

--克隆地形
function _M:initTerrain()
    local ground_name_ = self.name

    local workspace = game:GetWorkSpace(self.sceneid)
    --gg.log( 'GetWorkSpace1', workspace )

    if self.sceneid == 0 then
        --game.WorkSpace
    else
        local environment_ = workspace:WaitForChild('Environment')
        --gg.log( 'environment_1', environment_ )
        workspace.Environment:Destroy() --删除旧地形

        --克隆新地形
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
        --移动 ground
        if MainStorage.Ground[ground_name_] then
            MainStorage.Ground[ground_name_].Parent = workspace.Ground
            gx_ = workspace.Ground[ground_name_]
        end
    end

    if gx_ then
        if gx_.Visible == false then
            gx_.Visible = true
        end
        --gx_.Position = Vector3.new(0,0,0)    --坐标改到中心点
    else
        gg.log('scene not exist:', ground_name_)
    end
end

--玩家离开场景
function _M:player_leave(uin_)
    if self.players[uin_] then
        self.players[uin_] = nil
    end
end

--玩家进入场景
function _M:player_enter(uin_)
    if self.players[uin_] then
        --已经存在
    else
        local player_ = gg.server_players_list[uin_]
        if player_ then
            self.players[uin_] = player_
        end
    end
end

--获得本场景的workspace
function _M:GetWorkSpace()
    return game:GetWorkSpace(self.sceneid)
end

--获得场景里的主建筑物gx
function _M:getGX()
    if not self.sceneid then
        gg.log('no sceneid:', self)
        return
    end

    local ws_ = game:GetWorkSpace(self.sceneid)
    if ws_ then
        return ws_.Ground[self.name]
    end
    return nil
end

--按照名字获得功能点的坐标  传送点:'tp0'  怪物出生点:'monster_spawn'
function _M:getFunctionPosXYZByName(node_name_)
    local gx_node_ = self:getGX()
    if gx_node_ then
        local node_ = gx_node_[node_name_]
        if node_ then
            return node_.Position.x, node_.Position.y, node_.Position.z
        end
    end
    return 0, 0, 0
end

--直接获得坐标
function _M:getFunctionPosByName(node_name_)
    local gx_node_ = self:getGX()
    if gx_node_ then
        local node_ = gx_node_[node_name_]
        if node_ then
            return node_.Position
        end
    end
    return nil
end

-- (测试) 本场景内的所有怪物都播放同一个动作
-- function _M:debug_play_animation( anim_id_ )
--     for _, monster_ in pairs( self.monsters ) do
--         monster_:play_animation( anim_id_, 1, 0 )
--         monster_.bb_title.Title = anim_id_;
--     end
-- end



-- 当一个怪物目标血量变化的时候，更新所有关注它的生物的目标血条
function _M:updateTargetHPMPBar(uuid_)
    for uin_, player_ in pairs(self.players) do
        if player_.target and player_.target.uuid == uuid_ then
            local tar_ = player_.target.battle_data
            local info_ = {
                cmd = 'cmd_sync_target_info',
                show = 1,
                hp = tar_.hp,
                mp = tar_.mp,
                hp_max = tar_.hp_max,
                mp_max = tar_.mp_max,
            }
            gg.network_channel:fireClient(uin_, info_)
        end
    end
end

--通知目标丢失
function _M:infoTargetLost(uuid_)
    for uin_, player_ in pairs(self.players) do
        if player_.target and player_.target.uuid == uuid_ then
            local info_ = { cmd = 'cmd_sync_target_info', show = 0, v = 'lost' }
            gg.network_channel:fireClient(uin_, info_)
        end
    end
end

-- 遍历刷怪点 进行刷怪
function _M:check_monster_spawn()
    local gx_node_ = self:getGX()
    if gx_node_ then
        for k, v in pairs(self.scene_config) do
            if self.name then
                self:check_monster_spawn_by_name(k, self.name)
            end
        end
    end
end

function _M:check_npc_spawn()
    local gx_node_ = self:getGX()
    if gx_node_ then
        for k, v in pairs(self.npc_spawn_config) do
            if self.name then
                self:check_npc_spawn_by_name(k, v, self.name)
            end
        end
    end
end

function _M:check_npc_spawn_by_name(npc_id, npc_spawn_config, map_name)
    -- 检查npc的刷点
    if not self.npc_spawns[npc_id] then
        if npc_spawn_config and not self.npcs[npc_id] then
            local npc_args = { 
                position = npc_spawn_config.position,
                scene_name = self.name,
                nickname = npc_spawn_config.name,
                npc_type   = common_const.NPC_TYPE.NPC,
                uin = npc_id,
                lv = npc_spawn_config.lv,
                model_id = npc_spawn_config.model,
                profession = npc_spawn_config.profession,
                rotation = npc_spawn_config.rotation,
                id = npc_id,
                plot = npc_spawn_config.plot
                }
       
            local npc_entity = CLNpc.New(npc_args)
            npc_entity:InitModel()
            -- npc_entity.scene = self
            self.npcs[npc_id] = npc_entity
            self.npc_spawns[npc_id] = npc_spawn_config

        end
    end
end

--每一个刷新点  monster_spawn1  monster_spawn2  monster_spawn3
function _M:check_monster_spawn_by_name(spawn_name_, map_name)
    --- spawn_name_：刷怪点 map_name,地图名字
    if not self.monster_spawns[spawn_name_] then
        self.monster_spawns[spawn_name_] = { count = 0 }

        local monster_spawn_config_ = self.scene_config[spawn_name_]
        if not monster_spawn_config_ then
            monster_spawn_config_ = self.scene_config[spawn_name_].monster_spawn1
        end

        self.monster_spawns[spawn_name_].config = monster_spawn_config_
    end
    local spawn_ = self.monster_spawns[spawn_name_]
    if spawn_.count < spawn_.config.monster_count then
        -- gg.log( self.name, spawn_name_, 'new monster:', spawn_.config.monster_count )
        local xx, yy, zz = self:getFunctionPosXYZByName(spawn_name_)
        spawn_.count    = spawn_.count + 1

        local rand_id_  = (gg.rand_int(10000) % #common_config.monster_config) + 1   --随机选一个怪物
        local mon_id_   = common_config.monster_config[rand_id_].id                  --怪物id   100063
        local nickname_ = common_config.monster_config[rand_id_].name                --怪物名字

        local range_    = spawn_.config.range

        --每次扫描只刷新一只怪物
        local monster_  = CMonster.New({
            x          = xx + gg.rand_int_both(range_),
            y          = yy + 150,
            z          = zz + gg.rand_int_both(range_),
            scene_name = self.name,
            nickname   = nickname_,
            npc_type   = common_const.NPC_TYPE.MONSTER,
            uin        = 0,
            level      = gg.rand_int_between(spawn_.config.level, spawn_.config.level2),
            id         = mon_id_,
            drop_items = spawn_.config.drop_items,

        })
        monster_:createModel()
        monster_:spawnRandomPos(500, 100, 500)
        monster_.scene = self
        self.monsters[monster_.uuid] = monster_
    end
end

--增加一个掉落物箱
function _M:addDrop(item_)
    item_.tick = gg.tick --记录tick
    self.drop_boxs[item_.uuid] = item_
end

--判断物品是否被拾取
function _M:check_drop()
    if not next(self.drop_boxs) then
        return
    end
    -- OwnerUin
    for box_uuid_, box_info_ in pairs(self.drop_boxs) do
        local pos1_ = box_info_.model.Position
        for uin_, player_ in pairs(self.players) do
            local pos2_ = player_:getPosition()
            if not gg.fast_out_distance(pos1_, pos2_, 200) and box_info_.player_uin == uin_ then
                --拾取物品
                local drop_re = bagMgr.tryGetItem(uin_, box_info_)
                gg.log("玩家拾取物品和结果", box_info_, drop_re, uin_)

                if drop_re == 0 then
                    bagMgr.s2c_PlayerBagItems(uin_, {})   --刷新玩家背包数据
                    self.drop_boxs[box_uuid_] = nil
                    box_info_.model:Destroy()
                    break
                end
            end
        end
    end
end

--检查怪物是否离开自己的刷新点太远
function _M:check_monster_alive()
    for _, monster_ in pairs(self.monsters) do
        monster_:checkHPMP() --回红回蓝

        if monster_.target then
            --gg.log( '====check_monster_alive target:', monster_.uuid, monster_.level, monster_.target.uuid )
        else
            --gg.log( '====check_monster_alive no target:', monster_.uuid, monster_.level )
            if monster_.level >= 50 then
                monster_:tryGetTargetPlayer()
            end
        end
        monster_:checkTooFarFromPos()
    end
end

--检查玩家是否离开太远
function _M:check_player_alive()
    for _, player_ in pairs(self.players) do
        player_:checkHPMP() --回红回蓝

        local gx_node_ = self:getGX()
        local pos1_ = gx_node_.Position
        local pos2_ = player_:getPosition()
        if gg.fast_out_distance(pos1_, pos2_, 12800) then
            gg.log('player out range', self.name)
            player_.actor.Position = Vector3.new(pos1_.x + gg.rand_int_both(200), pos1_.y + 200 + gg.rand_int(200),
                pos1_.z + gg.rand_int_both(200))
        end
    end
end

--查找附近的一个目标
function _M:tryGetTarget(pos2_)
    for _, player_ in pairs(self.players) do
        local pos1_ = player_:getPosition()
        if gg.fast_out_distance(pos1_, pos2_, 2400) == false then
            return player_
        end
    end
    return nil
end

--每一帧更新
function _M:update()
    if next(self.players) == nil then
        return --场景内没有玩家
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
    for _, npc_ in pairs(self.npcs) do
        npc_:update_npc()
    end

    --慢update
    local mod_ = self.tick % 11
    if mod_ == 1 then
        self:check_monster_spawn()
    elseif mod_ == 2 then
        self:check_monster_alive()
    elseif mod_ == 3 then
        self:check_player_alive()
    elseif mod_ == 4 then
        self:check_npc_spawn()
        self:check_drop()
    else

    end
end

return _M
