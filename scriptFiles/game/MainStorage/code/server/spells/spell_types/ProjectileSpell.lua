local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local RunService = game.RunService
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local Graphics = require(MainStorage.code.server.graphic.Graphics) ---@type Graphics

---@class ProjectileSpell:Spell
---@field projectileModel string 飞弹模型名称
---@field speed number 飞行速度
---@field canHitSameTarget boolean 可重复击中同一目标
---@field hitInterval number 击中间隔
---@field maxHits number 最大命中次数
---@field scatterCount number 散射次数
---@field scatterAngle number 散射角度
---@field scatterDelay number 散射延迟
---@field spawnAtCaster boolean 是否在施法者位置生成
---@field activeProjectiles table<number, ProjectileItem> 正在活动的飞弹
---@field projectileCount number 飞弹数量
---@field projectileID number 飞弹ID
---@field duration number 飞弹持续时间
---@field canPassThroughTerrain boolean 是否可以穿过地形
---@field startTime number 飞弹生成时间
---@field projectilePool table<Actor> 飞弹对象池
---@field maxPoolSize number 对象池最大大小
---@field updateCount number 更新计数
---@field destroyCount number 销毁计数
local ProjectileSpell = ClassMgr.Class("ProjectileSpell", Spell)

---@class ProjectileItem
---@field actor Actor 飞弹Actor
---@field caster Entity 施法者
---@field direction Vector3 飞行方向
---@field baseDirection Vector3 基础方向
---@field param CastParam 参数
---@field hitTargets table<Entity, boolean> 已命中目标
---@field lastHitTimes table<Entity, number> 上次命中时间
---@field remainingHits number 剩余命中次数
---@field moveConnection SBXConnection 移动更新连接
local ProjectileItem = {}

function ProjectileSpell:OnInit(data)
    Spell.OnInit(self, data)
    self.projectileModel = data["飞弹模型"] or "飞弹"
    self.canHitSameTarget = data["可重复碰撞同一目标"] or false
    self.hitInterval = data["对同一目标生效间隔"] or -1
    self.maxHits = data["生效次数"] or -1
    self.scatterCount = data["散射次数"] or 1
    self.scatterAngle = data["散射角度"] or 0
    self.scatterDelay = data["散射延迟"] or 0
    self.spawnAtCaster = data["生成于自己位置"] or false
    self.duration = data["持续时间"] or 5
    self.canPassThroughTerrain = data["穿过地形"]
    self.projectileEffects = Graphics.Load(data["特效_飞弹"])
    self.activeProjectiles = {}
    self.projectileCount = 0
    self.projectileID = 0
    self.projectilePool = {}
    self.maxPoolSize = data["对象池大小"] or 20
end

--- 生成唯一ID
---@return number
function ProjectileSpell:GenerateId()
    self.projectileID = self.projectileID + 1
    return self.projectileID
end

--- 从对象池获取飞弹Actor
---@return Actor
function ProjectileSpell:GetProjectileFromPool()
    if #self.projectilePool > 0 then
        return table.remove(self.projectilePool)
    end
    return nil
end

--- 将飞弹Actor返回对象池
---@param actor Actor
function ProjectileSpell:ReturnProjectileToPool(actor)
    if #self.projectilePool < self.maxPoolSize then
        actor.Visible = false
        actor.Enabled = false
        table.insert(self.projectilePool, actor)
    else
        actor:Destroy()
    end
end

--- 生成飞弹
---@param position Vector3 生成位置
---@param direction Vector3 飞行方向
---@param baseDirection Vector3 基础方向
---@param caster Entity 施法者
---@param param CastParam 参数
---@param delay number 延迟时间
function ProjectileSpell:SpawnProjectile(position, direction, baseDirection, caster, param, delay)
    if delay and delay > 0 then
        ServerScheduler.add(function()
            self:CreateProjectile(position, direction, baseDirection, caster, param)
        end, delay)
    else
        self:CreateProjectile(position, direction, baseDirection, caster, param)
    end
end

--- 创建飞弹
---@param position Vector3 生成位置
---@param direction Vector3 飞行方向
---@param baseDirection Vector3 基础方向
---@param caster Entity 施法者
---@param param CastParam 参数
function ProjectileSpell:CreateProjectile(position, direction, baseDirection, caster, param)
    -- 从对象池获取或创建新的飞弹Actor
    local actor = self:GetProjectileFromPool()
    if not actor then
        local originalActor = MainStorage["飞弹"][self.projectileModel] ---@type Actor
        if not originalActor then
            originalActor = game.WorkSpace["飞弹"][self.projectileModel] ---@type Actor
        end
        actor = originalActor:Clone()
    end
    
    actor.Parent = caster.scene.node["世界特效"]
    actor.Enabled = true
    actor.Visible = false  -- 初始设置为不可见
    actor.CollideGroupID = 9
    
    -- 创建飞弹项
    local item = {
        actor = actor,
        caster = caster,
        direction = direction,
        baseDirection = baseDirection,
        param = param,
        hitTargets = {},
        lastHitTimes = {},
        remainingHits = param:GetValue(self, "生效次数", self.maxHits),
        startTime = os.time(),
        size = gg.vec.Multiply3(actor.Size, actor.LocalScale),
        updateCount = 0  -- 添加更新计数器
    }
    local pos = gg.vec.Add3(position, 0, -item.size.y/2, 0)
    actor.Position = pos


    -- 注册飞弹
    local id = self:GenerateId()
    self.activeProjectiles[id] = item
    self.projectileCount = self.projectileCount + 1
    
    -- 设置移动更新
    item.moveConnection = RunService.Stepped:Connect(function()
        self:UpdateProjectile(id)
    end)
end

--- 更新飞弹
---@param id number 飞弹ID
---@param dt number 帧间隔时间
function ProjectileSpell:UpdateProjectile(id)
    local item = self.activeProjectiles[id] ---@type ProjectileItem
    if not item then return end
    
    local newPosition = item.actor.Position + item.direction * item.actor.Movespeed / 10.0
    item.actor.Position = newPosition
    
    -- 延迟两次更新后设置为可见
    item.updateCount = item.updateCount + 1
    if item.updateCount >= 5 then
        item.actor.Visible = true
    end
    
    -- 如果设置了销毁计数，则递减计数并在计数为0时销毁
    if item.destroyCount then
        item.destroyCount = item.destroyCount - 1
        if item.destroyCount <= 0 then
            self:DestroyProjectile(id)
        end
        return
    end
    
    -- 检查碰撞
    local hitTargets = item.caster.scene:OverlapBox(gg.vec.Add3(newPosition, 0, item.size.y / 2, 0), item.size, item.actor.LocalEuler, item.caster:GetEnemyGroup())
    if hitTargets and #hitTargets > 0 then
        -- 遍历所有碰撞到的目标
        for _, target in ipairs(hitTargets) do
            -- 跳过施法者自身
            if target ~= item.caster then
                self:HandleProjectileHit(id, target)
            end
        end
    end
    
    -- 检查地形碰撞
    if not self.canPassThroughTerrain then
        local hitGround = item.caster.scene:OverlapBox(gg.vec.Add3(newPosition, 0, item.size.y / 2, 0), Vector3.New(20, 20, 20), item.actor.LocalEuler, {1})
        if hitGround and #hitGround > 0 then
            item.destroyCount = 5  -- 地形碰撞也延迟三次更新后销毁
        end
    end
    
    -- 检查持续时间
    if self.duration > 0 then
        if item.startTime and os.time() - item.startTime >= self.duration then
            item.destroyCount = 5  -- 超时也延迟三次更新后销毁
        end
    end
end

--- 处理飞弹碰撞
---@param id number 飞弹ID
---@param target Entity 碰撞目标
function ProjectileSpell:HandleProjectileHit(id, target)
    local item = self.activeProjectiles[id]
    if not item then return end
    
    -- 检查是否可以命中目标
    if not self:CanHitTarget(item, target) then
        return
    end
    
    -- 执行子魔法
    if #self.subSpells > 0 then
        for _, subSpell in ipairs(self.subSpells) do
            subSpell:Cast(item.caster, target, item.param)
        end
    end
    
    -- 更新命中记录
    item.hitTargets[target] = true
    item.lastHitTimes[target] = os.time()
    
    -- 检查是否需要销毁飞弹
    if item.remainingHits > 0 then
        item.remainingHits = item.remainingHits - 1
        if item.remainingHits == 0 then
            item.destroyCount = 5  -- 设置需要三次更新后再销毁
        end
    end
end

--- 检查是否可以命中目标
---@param item ProjectileItem 飞弹项
---@param target Entity 目标
---@return boolean 是否可以命中
function ProjectileSpell:CanHitTarget(item, target)
    -- 检查是否已经击中过这个目标
    if not self.canHitSameTarget and item.hitTargets[target] then
        -- 如果有设置生效间隔，检查是否已经过了间隔时间
        if self.hitInterval > 0 then
            local lastHitTime = item.lastHitTimes[target]
            if lastHitTime and os.time() - lastHitTime >= self.hitInterval then
                return true
            end
        end
        return false
    end
    return true
end

--- 销毁飞弹
---@param id number 飞弹ID
function ProjectileSpell:DestroyProjectile(id)
    local item = self.activeProjectiles[id]
    if not item then return end
    if item.moveConnection then
        item.moveConnection:Disconnect()
    end
    if item.actor then
        self:ReturnProjectileToPool(item.actor)
    end
    self.activeProjectiles[id] = nil
    self.projectileCount = self.projectileCount - 1
end

--- 实际执行魔法
---@param caster Entity 施法者
---@param target Entity 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function ProjectileSpell:CastReal(caster, target, param)
    -- 确定生成位置
    local position
    if self.spawnAtCaster then
        position = caster:GetCenterPosition()
    else
        if not target then
            return false
        end
        position = target:GetCenterPosition()
    end

    local baseDirection
    if not target then
        if param.lookDirection then
            baseDirection = param.lookDirection
        else
            baseDirection = caster:GetDirection()
        end
    else
        baseDirection = (self:GetPosition(target) - caster:GetPosition()):Normalize()
    end
    
    -- 获取散射参数
    local shootCount = param:GetValue(self, "散射次数", self.scatterCount)
    local shootAngle = param:GetValue(self, "散射角度", self.scatterAngle)
    local shootDelay = param:GetValue(self, "散射延迟", self.scatterDelay)
    
    -- 如果只有一发，直接生成
    if shootCount <= 1 then
        self:SpawnProjectile(position, baseDirection, baseDirection, caster, param, 0)
        return true
    end
    
    -- 计算散射角度
    local totalAngle = shootAngle
    local angleStep
    local startAngle
    
    if shootCount % 2 == 0 and shootAngle > 0 then
        -- 偶数情况：从中心向两边散开
        angleStep = totalAngle / (shootCount - 1)
        startAngle = -totalAngle / 2
    else
        -- 奇数情况：中心对齐
        angleStep = totalAngle / math.max(1, shootCount - 1)
        startAngle = -totalAngle / 2
    end
    
    -- 生成所有散射
    for i = 1, shootCount do
        local currentAngle = startAngle + (angleStep * (i - 1))
        local currentDirection = Vector3.New(
            baseDirection.x * math.cos(currentAngle) - baseDirection.y * math.sin(currentAngle),
            baseDirection.x * math.sin(currentAngle) + baseDirection.y * math.cos(currentAngle),
            baseDirection.z
        )
        local delay = shootDelay * (i - 1)
        self:SpawnProjectile(position, currentDirection, baseDirection, caster, param, delay)
    end
    
    -- 播放释放特效
    self:PlayEffect(self.projectileEffects, caster, target, param)
    
    return true
end

return ProjectileSpell 