local RunService = game:GetService("RunService")
local WorldService = game:GetService("WorldService")
local Workspace = game:GetService("Workspace")

local M = {}
M.explosionItems = {}
M.explosionItemCount = 0
M.effectID = 0
M.simulateExplosionIns = nil

function M.GenerateId()
    M.effectID = M.effectID + 1
    return M.effectID
end

function M.SimulateExplosion(dt)
    local needRemoveNodes = {}
    for id, item in pairs(M.explosionItems) do
        item.effectTime = item.effectTime - dt
        local convertNormalTime = item.effectTime / item.totalTime
        convertNormalTime = 1 - convertNormalTime
        local interpolatePosScale = math.pow(4 - (4 * convertNormalTime), 2) / 16
        interpolatePosScale = 1 - interpolatePosScale
        local destX = item.startX + interpolatePosScale * item.moveX
        local destY = item.startY + interpolatePosScale * item.moveY
        local destZ = item.startZ + interpolatePosScale * item.moveZ
        local isCanMove = true
        local ret = WorldService:OverlapSphere(item.colliderSize, Vector3.New(destX, destY + item.colliderSize, destZ), true, {1})
        for k, v in pairs(ret) do
            if v.obj.Visible then
                -- print("hit object", v.obj)
                isCanMove = false
                break
            end
        end
        if isCanMove then
            item.x = destX
            item.y = destY
            item.z = destZ
            item.node.Position = Vector3.new(item.x, item.y, item.z)
        else
            item.effectTime = 0
        end
        if item.effectTime <= 0 then
            item.node.EnablePhysics = true
            needRemoveNodes[#needRemoveNodes+1] = id
            if item.endFunc ~= nil then
                item.endFunc(item.node)
            end
        end
    end
    for i,v in ipairs(needRemoveNodes) do
        M.explosionItemCount = M.explosionItemCount - 1
        M.explosionItems[v] = nil
    end

    if M.explosionItemCount == 0 then
        -- print("Disconnect")
        M.simulateExplosionIns:Disconnect()
        M.simulateExplosionIns = nil
    end
end

function M.AddExplosion(explosionWorldPos, explosionFullSize, nodes, endFunc)
    local ret = {}
    for _, node in ipairs(nodes) do
        node.EnablePhysics = false
        local distanceVec = node.Position - explosionWorldPos
        local distance = distanceVec.Length
        local direction
        local explosionSize
        if distance >= explosionFullSize then
        elseif distance >= 30 then
            direction = distanceVec:Normalize()
            -- explosionSize = direction * (math.random(10, 15) / 15 * explosionFullSize * 30 / distance)
            explosionSize = direction * explosionFullSize * (1.0 - distance / explosionFullSize)
        else
            direction = Vector3.new(0, 1, 0)
            explosionSize = direction * explosionFullSize
        end
        -- print(explosionSize)
        if explosionSize ~= nil then
            local effectTime = math.random(45, 50) / 100.0
            local item = {}
            local nodePos = node.Position
            local id = M.GenerateId()
            local xPos = nodePos.X
            local yPos = nodePos.Y
            local zPos = nodePos.Z
            item.startX = xPos
            item.startY = yPos
            item.startZ = zPos
            item.moveX = explosionSize.X
            item.moveY = explosionSize.Y / 2
            item.moveZ = explosionSize.Z
            item.node = node
            item.colliderSize = node.Size.Y / 2
            item.effectTime = effectTime
            item.totalTime = effectTime
            item.endFunc = endFunc
            M.explosionItems[id] = item
            M.explosionItemCount = M.explosionItemCount + 1
            -- print(effectTime, item.moveX, item.moveY, item.moveZ)
            if M.simulateExplosionIns == nil then
                M.simulateExplosionIns = RunService.RenderStepped:Connect(M.SimulateExplosion)
            end
            ret[#ret+1] = item
        end
    end
    return ret
end

function M.AddRain()
    if M.rainNode == nil then
        M.rainNode = script.Rain
        --M.rainNode.SyncMode = Enum.NodeSyncMode.DISABLE
        M.rainNode.LocalSyncFlag = Enum.NodeSyncLocalFlag.ENABLE
    end
    M.rainNode.Parent = Workspace
    if M.updateRainIns ~= nil then
        M.updateRainIns:Disconnect()
    end
    print("rain add Rain")
    -- local isFirst = true
    M.updateRainIns = RunService.RenderStepped:Connect(function()
        local cameraPos = Workspace.Camera.LocalPosition
        M.rainNode.LocalPosition = Vector3.New(cameraPos.X, cameraPos.Y, cameraPos.Z)
        -- if isFirst then
        --     isFirst = false
        --     print("rain update pos")
        -- end
    end)
end

function M.RemoveRain()
    if M.rainNode then
        M.rainNode.Parent = script
    end
    if M.updateRainIns then
        M.updateRainIns:Disconnect()
        M.updateRainIns = nil
    end
    print("rain remote pos")
end

function M.AddFrozenEffect(zombie, alpha)
    local mat = zombie:GetMaterialInstance({0},0)
    -- print("frozen", mat, zombie, alpha)
    local key = "ENABLE_DIAMOND"
    local enable = false
    if alpha >= 1.0 or alpha < 0 then
        zombie.Animator.Speed = 1.0
        if zombie.Frozen then
            zombie.Frozen:Destroy()
        end
    else
        zombie.Animator.Speed = alpha
        enable = true
        if M.frozenNode == nil then
            M.frozenNode = script.Frozen
        end
        local frozenNode = M.frozenNode:Clone()
        frozenNode.Parent = zombie
        frozenNode.LocalPosition = Vector3.New(0,0,0)
    end
    mat:SetKey(key, enable)
end

function M.test()
    local ws = game:GetService("Workspace")
    local Zombie = ws.Zombie
    local Target = ws.Target
    local widthNum = 6
    local heightNum = 4
    -- local widthNum = 1
    -- local heightNum = 1
    local startPosX = Target.Position.X
    local startPosY = Target.Position.Y
    local startPosZ = Target.Position.Z
    local zombieWidth = Zombie.Size.X
    local zombieHeight = Zombie.Size.Y
    local zombies = {}
    for i = 1, widthNum do
        for j = 1, widthNum do
            for k = 1, heightNum do
                local newZombie = Zombie:Clone()
                newZombie.Parent = ws
                local posX = startPosX + (i - 1) * zombieWidth - (widthNum - 1) / 2 * zombieWidth
                local posZ = startPosZ + (j - 1) * zombieWidth - (widthNum - 1) / 2 * zombieWidth
                local posY = startPosY + (k - 1) * zombieHeight - (heightNum -1) / 2 * zombieHeight
                newZombie.Position = Vector3.new(posX, posY, posZ)
                zombies[#zombies + 1] = newZombie
            end
        end
    end
    Wait(3)
    M.AddExplosion(Target.Position, 500, zombies, function(node)
        -- print("node Destroy")
        -- node:Destroy()
    end)
end

return M
