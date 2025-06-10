local MainStorage = game:GetService("MainStorage")

local pool = game:GetService("WorkSpace")["伤害数字"] ---@type SandboxNode
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local TweenService = game:GetService('TweenService')

-- 对象池配置
local activeNodes = {}  -- 正在使用的节点
local inactiveNodes = {}  -- 未使用的节点

-- 动画配置
local tweenInfo = TweenInfo.New(1, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-- 从对象池获取节点
local function GetNode()
    local node
    if #inactiveNodes > 0 then
        node = table.remove(inactiveNodes)
    else
        -- 如果对象池为空，创建新节点
        node = SandboxNode.new('UIRoot3D', pool) ---@type UIRoot3D
        node.Mode = Enum.Mode.Billboard
        
        -- 创建文本标签
        local textLabel = gg.createTextLabel(node, "")
        textLabel.Name = "textLabel"
        textLabel.ShadowEnable = true
        textLabel.ShadowOffset = Vector2.New(3, 3)
        textLabel.TitleColor = ColorQuad.New(255, 255, 0, 255)
        textLabel.ShadowColor = ColorQuad.New(0, 0, 0, 255)
        textLabel.FontSize = 64
    end
    node.Visible = true
    table.insert(activeNodes, node)
    print("GetNode", node)
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
    -- -- 重置节点状态
    node.LocalScale = Vector3.New(0,0,0)
    -- node.LocalPosition = Vector3.New(0, 0, 0)
    table.insert(inactiveNodes, node)
end

-- 显示世界文本动画
---@param text string 显示的文本
---@param startPos Vector3 起始位置
---@param endPos Vector3 目标位置
local function ShowWorldText(text, startPos, endPos)
    local node = GetNode()
    
    -- 设置文本
    node.textLabel.Title = text
    node.LocalScale = Vector3.New(0.6, 0.6, 0.6)
    
    -- 设置初始位置
    node.Position = startPos
    
    -- 创建动画
    local tween = TweenService:Create(node, tweenInfo, {
        Position = endPos,
        LocalScale = Vector3.New(0.6, 0.6, 0.6)
    })
    tween:Play()
    tween.Completed:Connect(function()
        RecycleNode(node)
    end)
end

-- 处理掉落物品动画事件
local function OnDropItemAnim(evt)
    local player = game:GetService("Players").LocalPlayer.Character ---@type Actor
    local endPos = Vector3.New(evt.loc[1], evt.loc[2], evt.loc[3])  -- 目标位置
    local dir = gg.Vec3.new(player.Position + player.Center - endPos) ---@type Vec3
    local length = dir:Length()
    dir = dir:rotateAroundY(math.random(-45, 45))
    dir.y = dir.y + math.random(-20, 50)
    
    -- 计算最终方向和距离
    dir = dir / length * math.max(300, length / 5)
    local startPos = endPos + dir:ToVector3()
    
    ShowWorldText(evt.text, startPos, endPos)
end

-- 注册事件监听
ClientEventManager.Subscribe("DropItemAnim", OnDropItemAnim)