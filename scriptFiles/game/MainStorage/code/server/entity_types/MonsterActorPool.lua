local MainStorage = game:GetService('MainStorage')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr

-- ---@class PlayerRanking
-- ---@field uin integer
-- ---@field name string
-- ---@field amount number

-- ---@class Ranking
-- ---@field players PlayerRanking[]
-- ---@field uinIndex table<integer, integer> Key=玩家UIN Value=玩家排名
-- ---@field lastAmount number

-- 一般思路是，用迷你那个存table的功能记录一个Ranking
-- 每次有玩家的变量变更时：
--     if 不在表内：
--         if 大于Ranking的最小值：
--             从后往前挨个players[顺位]，找到应插入的地方，将新玩家插入，并将最后一名移除。最后更新lastAmount
--     else
--         从当前顺位往前挨个players[顺位]，找到应插入的地方，将新玩家插入。若玩家是最后一名，则更新lastAmount


---@class MonsterActorPool
local MonsterActorPool = {}
local pools = {}

--- 从对象池获取Actor
---@param modelName string 模型名称
---@param scene Scene 场景对象
---@return Actor|nil 获取到的Actor对象
function MonsterActorPool.GetActor(modelName, scene)
    if not pools[modelName] then
        pools[modelName] = {}
    end
    
    local pool = pools[modelName]
    
    -- 从池中查找可用的Actor
    for i = #pool, 1, -1 do
        local actor = pool[i]
        if actor and actor.Parent then
            -- 移除池中的引用
            table.remove(pool, i)
            
            -- 重新启用Actor
            actor.Enabled = true
            actor.Visible = true
            
            return actor
        else
            -- 清理无效的引用
            table.remove(pool, i)
        end
    end
    
    -- 池中没有可用的Actor，创建新的
    return MonsterActorPool.CreateNewActor(modelName, scene)
end

--- 创建新的Actor
---@param modelName string 模型名称
---@param scene Scene 场景对象
---@return Actor|nil 新创建的Actor对象
function MonsterActorPool.CreateNewActor(modelName, scene)
    local container = game.WorkSpace["Ground"][scene.name]["怪物"]
    local actor_monster = gg.GetChild(MainStorage["怪物模型"], modelName) ---@type Actor
    
    if not actor_monster then
        gg.log("Error: 找不到怪物模型", modelName)
        return nil
    end
    
    actor_monster = actor_monster:Clone()
    actor_monster:SetParent(container)
    actor_monster.Enabled = true
    actor_monster.Visible = true
    actor_monster.SyncMode = Enum.NodeSyncMode.NORMAL
    actor_monster.CollideGroupID = 3 -- MOB_COLLIDE_GROUP
    
    return actor_monster
end

--- 将Actor归还到对象池
---@param actor Actor Actor对象
---@param modelName string 模型名称
function MonsterActorPool.ReturnActor(actor, modelName)
    if not actor or not actor.Parent then
        return
    end
    
    -- 禁用Actor但保留在场景中
    actor.Enabled = false
    actor.Visible = false
    
    -- 重置Actor状态
    actor.Name = "PooledMonster"
    
    -- 添加到对应的池中
    if not pools[modelName] then
        pools[modelName] = {}
    end
    
    table.insert(pools[modelName], actor)
end

--- 清理对象池中的无效引用
function MonsterActorPool.CleanupPool()
    for modelName, pool in pairs(pools) do
        for i = #pool, 1, -1 do
            local actor = pool[i]
            if not actor or not actor.Parent then
                table.remove(pool, i)
            end
        end
    end
end

--- 获取池状态信息（用于调试）
---@return table 池状态信息
function MonsterActorPool.GetPoolStats()
    local stats = {}
    for modelName, pool in pairs(pools) do
        stats[modelName] = #pool
    end
    return stats
end

return MonsterActorPool