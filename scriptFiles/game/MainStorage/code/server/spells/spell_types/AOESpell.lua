local MainStorage = game:GetService('MainStorage')
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local CastParam = require(MainStorage.code.common.spell.CastParam) ---@type CastParam
local Timer = require(MainStorage.code.common.Timer) ---@type Timer
local RunService = game:GetService("RunService")
local WorldService = game:GetService("WorldService")

---@enum CollisionType
local CollisionType = {
    CIRCLE = "圆形",
    RECTANGLE = "方形",
    ELLIPSE = "椭圆形"
}

---@class AOESpell:Spell
---@field duration number 持续时间
---@field canHitSameTarget boolean 可重复击中同一目标
---@field hitInterval number 击中间隔
---@field persistentEffects any[] 特效_持续
---@field collisionType CollisionType 范围形状
---@field circleRadius number 圆形半径
---@field rectangleSize Vector3 方形长宽旋转
---@field ellipseMajorAxis number 椭圆长轴
---@field ellipseMinorAxis number 椭圆短轴
---@field ellipseRotation number 椭圆旋转
---@field offset Vector3 偏移
---@field aoeItems table<number, AOEItem> 正在生效的AOE效果
---@field aoeItemCount number AOE效果数量
---@field effectID number 效果ID
---@field simulateAOEIns RBXScriptConnection|nil 模拟AOE效果的连接
local AOESpell = CommonModule.Class("AOESpell", Spell)

---@class AOEItem
---@field effectTime number 效果剩余时间
---@field totalTime number 效果总时间
---@field startPos Vector3 起始位置
---@field moveVec Vector3 移动向量
---@field node Instance 效果节点
---@field colliderSize number 碰撞体大小
---@field endFunc function|nil 结束回调
local AOEItem = {}

function AOESpell:OnInit(data)
    Spell.OnInit(self, data)
    self.duration = data.duration or 0
    self.canHitSameTarget = data.canHitSameTarget or false
    self.hitInterval = data.hitInterval or 1
    self.persistentEffects = data.persistentEffects or {}
    self.collisionType = data.collisionType or CollisionType.CIRCLE
    self.circleRadius = data.circleRadius or 0
    self.rectangleSize = data.rectangleSize or Vector3.zero
    self.ellipseMajorAxis = data.ellipseMajorAxis or 0
    self.ellipseMinorAxis = data.ellipseMinorAxis or 0
    self.ellipseRotation = data.ellipseRotation or 0
    self.offset = data.offset or Vector3.zero
    
    self.aoeItems = {}
    self.aoeItemCount = 0
    self.effectID = 0
    self.simulateAOEIns = nil
end

--- 生成唯一ID
---@return number
function AOESpell:GenerateId()
    self.effectID = self.effectID + 1
    return self.effectID
end

--- 模拟AOE效果
---@param dt number 帧间隔时间
function AOESpell:SimulateAOE(dt)
    local needRemoveNodes = {}
    for id, item in pairs(self.aoeItems) do
        item.effectTime = item.effectTime - dt
        local convertNormalTime = item.effectTime / item.totalTime
        convertNormalTime = 1 - convertNormalTime
        local interpolatePosScale = math.pow(4 - (4 * convertNormalTime), 2) / 16
        interpolatePosScale = 1 - interpolatePosScale
        
        local destPos = item.startPos + item.moveVec * interpolatePosScale
        local isCanMove = true
        
        -- 检查碰撞
        local ret = WorldService:OverlapSphere(item.colliderSize, destPos + Vector3.New(0, item.colliderSize, 0), true, {1})
        for _, v in pairs(ret) do
            if v.obj.Visible then
                isCanMove = false
                break
            end
        end
        
        if isCanMove then
            item.node.Position = destPos
        else
            item.effectTime = 0
        end
        
        if item.effectTime <= 0 then
            item.node.EnablePhysics = true
            table.insert(needRemoveNodes, id)
            if item.endFunc then
                item.endFunc(item.node)
            end
        end
    end
    
    for _, id in ipairs(needRemoveNodes) do
        self.aoeItemCount = self.aoeItemCount - 1
        self.aoeItems[id] = nil
    end
    
    if self.aoeItemCount == 0 and self.simulateAOEIns then
        self.simulateAOEIns:Disconnect()
        self.simulateAOEIns = nil
    end
end

--- 添加AOE效果
---@param centerPos Vector3 中心位置
---@param fullSize number 完整大小
---@param nodes Instance[] 效果节点
---@param endFunc function|nil 结束回调
---@return AOEItem[]
function AOESpell:AddAOE(centerPos, fullSize, nodes, endFunc)
    local ret = {}
    for _, node in ipairs(nodes) do
        node.EnablePhysics = false
        local distanceVec = node.Position - centerPos
        local distance = distanceVec.Length
        local direction
        local effectSize
        
        if distance >= fullSize then
            -- 超出范围，不产生效果
        elseif distance >= 30 then
            -- 在范围内但距离较远
            direction = distanceVec:Normalize()
            effectSize = direction * fullSize * (1.0 - distance / fullSize)
        else
            -- 在中心区域
            direction = Vector3.new(0, 1, 0)
            effectSize = direction * fullSize
        end
        
        if effectSize then
            local effectTime = math.random(45, 50) / 100.0
            local item = {
                effectTime = effectTime,
                totalTime = effectTime,
                startPos = node.Position,
                moveVec = effectSize,
                node = node,
                colliderSize = node.Size.Y / 2,
                endFunc = endFunc
            }
            
            local id = self:GenerateId()
            self.aoeItems[id] = item
            self.aoeItemCount = self.aoeItemCount + 1
            
            if not self.simulateAOEIns then
                self.simulateAOEIns = RunService.RenderStepped:Connect(function(dt)
                    self:SimulateAOE(dt)
                end)
            end
            
            table.insert(ret, item)
        end
    end
    return ret
end

--- 获取命中目标
---@param loc Vector3 位置
---@param caster CLiving 施法者
---@param param CastParam 参数
---@return CLiving|nil 命中的目标
function AOESpell:GetHitTargets(loc, caster, param)
    local sizeScale = param:GetValue(self, "sizeScale", 1)
    local widthScale = param:GetValue(self, "widthScale", 1)
    local heightScale = param:GetValue(self, "heightScale", 1)
    
    if self.collisionType == CollisionType.CIRCLE then
        local radius = self.circleRadius * widthScale * sizeScale
        if radius == 0 then
            -- 点检测
            return WorldService:OverlapSphere(0.1, loc, true, {1})
        else
            return WorldService:OverlapSphere(radius, loc, true, {1})
        end
    elseif self.collisionType == CollisionType.RECTANGLE then
        local scaleX = self.rectangleSize.X * widthScale * sizeScale
        local scaleY = self.rectangleSize.Y * heightScale * sizeScale
        local scaleZ = self.rectangleSize.Z * sizeScale
        return WorldService:OverlapBox(Vector3.New(scaleX, scaleY, scaleZ), loc, true, {1})
    elseif self.collisionType == CollisionType.ELLIPSE then
        local maxRadius = math.max(self.ellipseMajorAxis, self.ellipseMinorAxis) * widthScale * sizeScale
        local hitTarget = WorldService:OverlapSphere(maxRadius, loc, true, {1})
        if hitTarget and self:IsPointInEllipse(hitTarget.Position, loc,
            self.ellipseMajorAxis * widthScale * sizeScale,
            self.ellipseMinorAxis * heightScale * sizeScale,
            self.ellipseRotation) then
            return hitTarget
        end
    end
    return nil
end

--- 实际执行魔法
---@param caster CLiving 施法者
---@param target CLiving 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function AOESpell:CastReal(caster, target, param)
    local loc = target:GetLocation()
    if self.offset ~= Vector3.zero then
        local direction = (param.realTarget:GetLocation() - caster:GetPosition()):Normalize()
        local right = Vector3.right
        loc = loc + direction * self.offset.x + right * self.offset.y
    end
    
    -- 创建AOE效果
    local effectNodes = self:CreateEffectNodes(loc)
    local fullSize = self:GetFullSize(param)
    self:AddAOE(loc, fullSize, effectNodes, function(node)
        -- 效果结束时的回调
        node:Destroy()
    end)
    
    if self.duration > 0 then
        local aoe = PulsingAOE.New(self, caster, target, loc, param)
        aoe:Start()
        return true
    end
    
    -- 单次执行的情况
    local hitTarget = self:GetHitTargets(loc, caster, param)
    if hitTarget then
        local anySucceed = false
        if #self.subSpells > 0 then
            for _, subSpell in ipairs(self.subSpells) do
                local castSuccessed = subSpell:Cast(caster, target, param)
                anySucceed = anySucceed or castSuccessed
            end
        end
        return anySucceed
    end
    return false
end

--- 创建效果节点
---@param loc Vector3 位置
---@return Instance[]
function AOESpell:CreateEffectNodes(loc)
    -- TODO: 根据实际需求创建效果节点
    return {}
end

--- 获取完整大小
---@param param CastParam 参数
---@return number
function AOESpell:GetFullSize(param)
    local sizeScale = param:GetValue(self, "sizeScale", 1)
    if self.collisionType == CollisionType.CIRCLE then
        return self.circleRadius * sizeScale
    elseif self.collisionType == CollisionType.RECTANGLE then
        return math.max(self.rectangleSize.X, self.rectangleSize.Y, self.rectangleSize.Z) * sizeScale
    elseif self.collisionType == CollisionType.ELLIPSE then
        return math.max(self.ellipseMajorAxis, self.ellipseMinorAxis) * sizeScale
    end
    return 0
end

--- 检查点是否在椭圆内
---@param point Vector3 要检查的点
---@param center Vector3 椭圆中心
---@param a number 长轴
---@param b number 短轴
---@param angle number 旋转角度（度）
---@return boolean 是否在椭圆内
function AOESpell:IsPointInEllipse(point, center, a, b, angle)
    -- 将点转换到椭圆的局部坐标系
    local angleRad = angle * math.pi / 180
    local cosAngle = math.cos(angleRad)
    local sinAngle = math.sin(angleRad)
    
    -- 将点转换到椭圆中心坐标系
    local translated = point - center
    
    -- 旋转到椭圆的主轴方向
    local x = translated.x * cosAngle + translated.y * sinAngle
    local y = -translated.x * sinAngle + translated.y * cosAngle
    
    -- 检查点是否在椭圆内
    return (x * x) / (a * a) + (y * y) / (b * b) <= 1
end

---@class PulsingAOE
---@field spell AOESpell
---@field caster CLiving
---@field target CLiving
---@field location Vector3
---@field param CastParam
---@field hitCreatures table<CLiving, boolean>
---@field lastPulseTime number
---@field timer Timer
---@field actions function[]
local PulsingAOE = CommonModule.Class("PulsingAOE")

function PulsingAOE:OnInit(spell, caster, target, location, param)
    self.spell = spell
    self.caster = caster
    self.target = target
    self.location = location
    self.param = param
    self.lastPulseTime = 0
    self.hitCreatures = {}
    
    -- 生成持续特效
    if #self.spell.persistentEffects > 0 then
        self.actions = self.spell:PlayEffect(self.spell.persistentEffects, caster, target, param)
    end
end

function PulsingAOE:Start()
    -- 立即执行一次
    self:ExecutePulse()
    
    -- 设置定时器进行周期性检测
    self.timer = Timer.Register(
        self.spell.duration, -- 总持续时间
        function() self:OnComplete() end, -- 完成时的回调
        function(elapsedTime) self:OnTimerTick(elapsedTime) end,
        false, -- 不循环，让Timer自然结束
        false -- 使用游戏时间
    )
end

function PulsingAOE:OnComplete()
    -- 清理特效
    if self.actions then
        for _, action in ipairs(self.actions) do
            if action then
                action()
            end
        end
    end
end

function PulsingAOE:OnTimerTick(elapsedTime)
    -- 检查是否应该停止
    if not self.caster then
        self:OnComplete() -- 确保在施法者消失时也清理特效
        self.timer:Cancel()
        return
    end

    -- 检查是否应该执行脉冲
    if elapsedTime - self.lastPulseTime >= self.spell.hitInterval then
        self:ExecutePulse()
        self.lastPulseTime = elapsedTime
    end
end

function PulsingAOE:ExecutePulse()
    if not self.caster then return end

    local hitTarget = self.spell:GetHitTargets(self.location, self.caster, self.param)
    if hitTarget then
        -- 如果不允许重复击中且已经击中过，则跳过
        if not self.spell.canHitSameTarget and self.hitCreatures[hitTarget] then
            return
        end
        
        -- 记录击中目标
        self.hitCreatures[hitTarget] = true
        
        -- 执行子魔法
        if #self.spell.subSpells > 0 then
            for _, subSpell in ipairs(self.spell.subSpells) do
                subSpell:Cast(self.caster, self.target, self.param)
            end
        end
    end
end

return AOESpell