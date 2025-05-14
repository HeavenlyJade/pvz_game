local ZManager = {}

local RunService = game:GetService("RunService")

local FROZEN_TIME = 5000
local FROZEN_SPEED = 0.3
local BURNING_TIME = 5000
local BURNING_SPEED = 0.3
local JUMP_GRAVITY = 980
local JUMP_INTERVAL = 0.1

function ZManager:Init()
    self.zombies = {}
    ZManager.levelDeadZombieCount = 0
    ZManager.waveDeadZombieCount = 0

    self.sunflowerHealth = 100
    self.attackSunflowerZombieCount = 0
    self.attackSunflowerTimer =
        MS.Timer.CreateTimer(
        1,
        1,
        true,
        function()
            if _G.GameMode.levelManager.currentLevel.levelState.isLevelEnd then
                return
            end

            self.sunflowerHealth = self.sunflowerHealth - self.attackSunflowerZombieCount * 2
            if self.sunflowerHealth <= 0 then
                self.sunflowerHealth = 0
                _G.GameMode.levelManager.eventObject:FireEvent("OnLevelEnd", false)
                _G.PlayerController.eventObject:FireEvent("OnLevelEnd", false)
            else
                _G.PlayerController.eventObject:FireEvent("OnSunflowerHit", self.sunflowerHealth)
            end
        end
    )
    self.attackSunflowerTimer:Start()
end

function ZManager:CreateZombie(ActorName, Parent, LocalPosition, LocalEuler, startNode)
    local configNode = MS.Config.GetCustomConfigNode(ActorName)

    if not configNode then
        print("zombie " .. ActorName .. " doesn't exist")
        return
    end

    local path = _G.GameMode.navigationSystem:FindPath(startNode)
    if not path or not path[1] then
        print("zombie " .. ActorName .. " can't find path", startNode)
        return
    end

    local zombieNode = ZombieMgr.CreateZombieByName(ActorName)

    zombieNode.Name = ActorName
    zombieNode.Parent = Parent
    zombieNode.LocalPosition = LocalPosition
    zombieNode.LocalEuler = LocalEuler
    zombieNode.CollideGroupID = 3

    local configData = require(configNode.Data)

    local health = configData.Attributes.health or 100
    local damage = configData.Attributes.damage
    local armor = configData.Attributes.armor

    local zombie = {
        bindActor = zombieNode,
        tween = nil,
        path = path,
        currentPathIndex = 1,
        health = health,
        damage = damage,
        armor = armor,
        moveSpeed = 0,
        transferMode = "",
        isDead = false,
        randX = math.random() * 100 - 50,
        randZ = math.random() * 100 - 50
    }
    zombie.bindActor.Position = self:GetPointRandomPosition(zombie, zombie.path[1])
    self.zombies[zombieNode.ID] = zombie
    self:FollowPath(zombie)
    return zombie
end

function ZManager:FollowPath(zombie)
    if zombie.currentPathIndex < #zombie.path then
        local targetNode = zombie.path[zombie.currentPathIndex + 1]
        self:MoveTowards(zombie, targetNode)
    end
end

function ZManager:MoveTowards(zombie, targetNode)
    -- 决定移动方式
    local transferMode =
        _G.GameMode.levelManager.currentLevel.navigationMesh.navEdges[
        zombie.path[zombie.currentPathIndex].bindObject.Name ..
            "-" .. zombie.path[zombie.currentPathIndex + 1].bindObject.Name
    ].transferMode

    zombie.transferMode = transferMode
    zombie.currentTarget = self:GetPointRandomPosition(zombie, targetNode)

    if transferMode == "run" then
        zombie.speed = 150
        ZombieMgr.ZombieRun(zombie.bindActor, false)
    elseif transferMode == "crawlfast" then
        zombie.speed = 150
        ZombieMgr.ZombieRun(zombie.bindActor, true)
    elseif transferMode == "walk" then
        zombie.speed = 100
        ZombieMgr.ZombieWalk(zombie.bindActor, false)
    elseif transferMode == "crawlslow" then
        zombie.speed = 100
        ZombieMgr.ZombieWalk(zombie.bindActor, true)
    elseif transferMode == "climb" then
        zombie.speed = 100
        ZombieMgr.ZombieClimb(zombie.bindActor)
    elseif transferMode == "jump" then
        -- elseif transferMode == "fall" then
        --     zombie.speed = 50
        zombie.speed = 300
        local height = zombie.bindActor.Position.Y - zombie.currentTarget.Y
        ZombieMgr.ZombieFallStart(zombie.bindActor, height)
    elseif transferMode == "attack" then
        zombie.speed = 0
        self.attackSunflowerZombieCount = self.attackSunflowerZombieCount + 1
        ZombieMgr.ZombieAttack(zombie.bindActor)
        zombie.isAttack = true
    end

    if zombie.speed <= 0 then
        zombie.currentTarget = nil
        return
    end

    zombie.speed = zombie.speed * (1.1 - math.random() * 0.2)

    zombie.currentTarget = self:GetPointRandomPosition(zombie, targetNode)
    if zombie.transferMode == "jump" then
        self:StartJump(zombie)
    else
        self:StartMove(zombie)
    end
end

function ZManager:GetPointRandomPosition(zombie, targetNode)
    -- 开始移动
    local posX = 0
    local posZ = 0
    local size = targetNode.bindObject.LocalScale
    if size.X > 1 then
        posX = zombie.randX * (size.X - 1)
    end
    if size.Z > 1 then
        posZ = zombie.randZ * (size.Z - 1)
    end

    local d = targetNode.bindObject.Euler.Y * math.pi / 180
    return targetNode.bindObject.Position +
        Vector3.new(posX * math.cos(d) + posZ * math.sin(d), 0, posZ * math.cos(d) - posX * math.sin(d))
end

function ZManager:TakeDamage(zombie, damage, damageType)
    if zombie.isDead then
        return
    end
    zombie.health = zombie.health - damage
    if zombie.health <= 0 then
        self:ZombieDead(zombie)
    else
        _G.PlayerController.eventObject:FireEvent("OnFireHit")
    end
    if damageType == "frozen" then
        ZManager:StartFrozen(zombie)
    elseif damageType == "burning" then
        ZManager:StartBurning(zombie)
    end
    return zombie.health
end

function ZManager:StartFrozen(zombie)
    local isFrozen = zombie.frozen_time ~= nil
    zombie.frozen_time = RunService:CurrentSteadyTimeStampMS() + FROZEN_TIME
    if not isFrozen then
        EffectManager.AddFrozenEffect(zombie.bindActor, FROZEN_SPEED)
        if (not zombie.isDead) and zombie.currentTarget and zombie.transferMode ~= "jump" then
            self:StartMove(zombie, zombie.currentTarget)
        end
    end
end

function ZManager:StartBurning(zombie)
    local isBurning = zombie.burning_time ~= nil
    zombie.burning_time = RunService:CurrentSteadyTimeStampMS() + BURNING_TIME
    if not isBurning then
        -- EffecNodetPool.ActivateEffectNode(
        --     burningEffectAssetID,
        --     zombie.bindActor,
        --     zombie.bindActor.LocalPosition,
        --     zombie.bindActor.Euler,
        --     zombie.bindActor.LocalScale
        -- )
        -- 创建燃烧伤害计时器
        zombie.burning_timer =
            MS.Timer.CreateTimer(
            0.5,
            0.5,
            true,
            function()
                -- 检查燃烧时间是否结束
                if RunService:CurrentSteadyTimeStampMS() > zombie.burning_time then
                    -- 停止燃烧效果
                    --EffectManager.AddBurningEffect(zombie, false)
                    -- 销毁计时器
                    if zombie.burning_timer then
                        zombie.burning_timer:Destroy()
                        zombie.burning_timer = nil
                    end
                    zombie.burning_time = nil
                    return
                end
                -- 造成燃烧伤害
                zombie.health = zombie.health - 5
                print("burning zombie health " .. zombie.health)
                if zombie.health <= 0 then
                    zombie.health = 0
                    zombie.isDead = true
                    self:ZombieDead(zombie)
                end
            end
        )
        zombie.burning_timer:Start()
    end
end

local function DestroyZombieTween(zombie, type)
    -- print("remove zombie tween", zombie, zombie.bindActor, zombie.tween, type)
    if zombie.tween then
        zombie.tween:Destroy()
        zombie.tween.Parent = nil
        -- print("remove zombie tween", zombie.bindActor, zombie.tween.Parent)
        zombie.tween = nil
    end
    -- print(debug.traceback())
end

function ZManager:StartMove(zombie)
    -- if zombie.tween then
    --     zombie.tween:Destroy()
    --     zombie.tween = nil
    -- end

    DestroyZombieTween(zombie, "startMove")
    if zombie.speed <= 0 then
        return
    end
    local pos = zombie.currentTarget
    local dirV = pos - zombie.bindActor.Position
    local time = dirV.Length / zombie.speed
    local finish = true
    if zombie.frozen_time then
        local rest_frozen = (zombie.frozen_time - RunService:CurrentSteadyTimeStampMS()) / 1000
        if rest_frozen <= 0 then
            zombie.frozen_time = nil
            EffectManager.AddFrozenEffect(zombie.bindActor, 1)
        elseif rest_frozen >= time / FROZEN_SPEED then
            time = time / FROZEN_SPEED
        else
            pos = zombie.bindActor.Position + dirV * (rest_frozen / time * FROZEN_SPEED)
            time = rest_frozen
            finish = false
        end
    end
    local tweenInfo = TweenInfo.New(time, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, 0, false)
    local dir = dirV:Normalize()
    zombie.bindActor.Euler = Vector3.new(0, math.atan2(-dir.X, -dir.Z) * 180 / math.pi, 0)
    local tween = MS.TweenService:Create(zombie.bindActor, tweenInfo, {Position = pos})
    zombie.tween = tween
    tween.Completed:Connect(
        function(status)
            if status ~= Enum.TweenStatus.Completed then
                return
            end
            -- if zombie.tween == tween then
            --     zombie.tween = nil
            -- end
            -- tween:Destroy()
            if finish then
                zombie.currentPathIndex = zombie.currentPathIndex + 1
                self:FollowPath(zombie)
            else
                self:StartMove(zombie)
            end
        end
    )
    tween:Play()
end

function ZManager:ZombieDead(zombie)
    DestroyZombieTween(zombie, "dead")
    zombie.health = 0

    if zombie.isDead then
        return
    end

    zombie.isDead = true
    -- if zombie.tween then
    --     zombie.tween:Destroy()
    --     zombie.tween = nil
    -- end
    -- zombie.tween = nil

    -- 删除僵尸table
    zombie.bindActor.CollideGroupID = 10
    self.zombies[zombie.bindActor.ID] = nil

    ZManager.waveDeadZombieCount = ZManager.waveDeadZombieCount + 1
    ZManager.levelDeadZombieCount = ZManager.levelDeadZombieCount + 1

    print("zombie dead", ZManager.levelDeadZombieCount)
    print("wave dead", ZManager.waveDeadZombieCount)

    _G.PlayerController.eventObject:FireEvent("OnZombieDead", ZManager.levelDeadZombieCount)

    if zombie.burning_timer then
        zombie.burning_timer:Destroy()
        zombie.burning_timer = nil
    end

    if zombie.isAttack then
        self.attackSunflowerZombieCount = self.attackSunflowerZombieCount - 1
    end
end

function ZManager:StartJump(zombie)
    local initPos = zombie.bindActor.Position
    local dirV = zombie.currentTarget - initPos
    if dirV.Y >= 0 then
        print("Can't jump up!")
        return self:StartMove(zombie)
    end
    local dir = (zombie.currentTarget - initPos):Normalize()
    zombie.bindActor.Euler = Vector3.new(0, math.atan2(-dir.X, -dir.Z) * 180 / math.pi, 0)
    local total_time = math.sqrt(-2 * dirV.Y / JUMP_GRAVITY)
    -- print("total_time", dirV.Y, total_time)
    local time = 0
    local function jump_next()
        -- if zombie.tween then
        --     zombie.tween:Destroy()
        --     zombie.tween = nil
        -- end
        DestroyZombieTween(zombie)
        local finish = false
        local last_time = time
        time = time + JUMP_INTERVAL
        if time >= total_time then
            time = total_time
            finish = true
        end
        local pos = initPos + dirV * time / total_time
        pos.Y = initPos.Y - 0.5 * JUMP_GRAVITY * time * time
        local tweenInfo = TweenInfo.New(time - last_time, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, 0, false)
        local tween = MS.TweenService:Create(zombie.bindActor, tweenInfo, {Position = pos})
        zombie.tween = tween
        tween.Completed:Connect(
            function(status)
                if status ~= Enum.TweenStatus.Completed then
                    return
                end
                -- if zombie.tween == tween then
                --     zombie.tween = nil
                -- end
                -- tween:Destroy()
                if finish then
                    zombie.currentPathIndex = zombie.currentPathIndex + 1
                    self:FollowPath(zombie)
                else
                    jump_next()
                end
            end
        )
        tween:Play()
    end
    jump_next()
end

return ZManager
