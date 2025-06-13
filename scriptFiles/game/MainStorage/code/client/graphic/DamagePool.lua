local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

local pool = game:GetService("WorkSpace")["伤害数字"] ---@type SandboxNode
local template = MainStorage["特效"]["伤害数字"] ---@type UIRoot3D

local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local TweenService = game:GetService('TweenService')

-- 数字图片配置
local DIGIT_WIDTH = 60  -- 每个数字的宽度
local CRIT_LANE = 1  -- 暴击数字的行
local NORMAL_LANE = 0  -- 普通数字的行

-- 动画配置
local tweenInfo = TweenInfo.New(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- 对象池配置
local POOL_SIZE = 20  -- 对象池大小
local activeNodes = {}  -- 正在使用的节点
local inactiveNodes = {}  -- 未使用的节点

-- 初始化对象池
local function InitPool()
    -- 只创建模板节点
    for j = 1, 5 do
        local digit = SandboxNode.new('UIImage', template)
        digit.Name = "digit_"..j
        digit.Icon = "sandboxId://textures/ui/伤害数字/piece_0_0.png"  -- 默认使用普通数字0
        digit.Position = Vector2.New(-100 + j * 50, 0)
        digit.Size = Vector2.New(60, 100)
    end
    template.Visible = false
    table.insert(inactiveNodes, template)
end

-- 从对象池获取节点
local function GetNode()
    local node
    if #inactiveNodes > 0 then
        node = table.remove(inactiveNodes)
    else
        -- 如果对象池为空，创建新节点
        node = template:Clone()
        node.Parent = pool
    end
    node.Visible = true
    table.insert(activeNodes, node)
    return node
end

-- 回收节点到对象池
local function RecycleNode(node)
    -- 从活动节点列表中移除
    for i, activeNode in ipairs(activeNodes) do
        if activeNode == node then
            table.remove(activeNodes, i)
            break
        end
    end
    
    -- 重置节点状态
    -- node.Visible = false
    node.LocalScale = Vector3.New(1, 1, 1)
    node.LocalPosition = Vector3.New(0, 0, 0)
    
    -- 隐藏所有数字
    for i = 1, 5 do
        local digit = node["digit_"..i]
        if digit then
            digit.Visible = false
        end
    end
    
    -- 添加到未使用节点列表
    table.insert(inactiveNodes, node)
end

-- 显示伤害数字
---comment
---@param node UIRoot3D
---@param amount number
---@param isCrit boolean
---@param position Vector3
local function ShowDamage(node, amount, isCrit, position)
    -- 确保amount是有效的数字
    amount = tonumber(amount) or 0
    -- 将数字转换为字符串
    local amountStr = tostring(math.floor(amount))
    local digitCount = #amountStr
    
    -- 计算起始位置，使数字居中显示
    local startIndex = math.floor((5 - digitCount) / 2) + 1
    
    -- 设置每个数字的位置和图片
    for i = 1, 5 do
        local damageImg = node["digit_"..i]
        if i >= startIndex and i < startIndex + digitCount then
            -- 显示数字
            local digit = tonumber(string.sub(amountStr, i - startIndex + 1, i - startIndex + 1))
            if digit then
                local lane = isCrit and CRIT_LANE or NORMAL_LANE
                damageImg.Icon = string.format("sandboxId://textures/ui/伤害数字/piece_%d_%d.png", lane, digit)
                damageImg.Visible = true
            else
                damageImg.Visible = false
            end
        else
            -- 隐藏多余的数字位
            damageImg.Visible = false
        end
    end
    node.LocalScale = isCrit and Vector3.New(1.5, 1.5, 1.5) or Vector3.New(1, 1, 1)
    -- 添加随机偏移
    local xx = math.random(-10, 10)
    local yy = math.random(-10, 10)
    
    -- 设置初始位置
    node.Position = Vector3.New(position.x + xx, position.y + yy, position.z)
    
    -- 创建动画
    local positionTween = TweenService:Create(node, tweenInfo, {
        Position = Vector3.New(position.x + xx, position.y + yy + 50, position.z)
    })
    positionTween:Play()
    positionTween.Completed:Connect(function()
        RecycleNode(node)
    end)
end

-- 处理伤害事件
local function OnDamageEvent(evt)
    if not evt or not evt.amount then return end
    
    local damageNode = GetNode()
    -- 显示伤害数字
    local position = Vector3.New(evt.position.x, evt.position.y, evt.position.z)
    ShowDamage(damageNode, evt.amount, evt.isCrit or false, position)
end

-- 初始化对象池
InitPool()

-- 注册事件监听
ClientEventManager.Subscribe("ShowDamage", OnDamageEvent)

return {
    ShowDamage = ShowDamage,
    GetNode = GetNode,
    RecycleNode = RecycleNode
}