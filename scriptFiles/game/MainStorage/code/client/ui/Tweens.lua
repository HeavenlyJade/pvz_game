local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg

---@enum EasingFunction
local EasingFunction = {
    LINEAR = 0,
    EASE_IN = 1,
    EASE_OUT = 2,
    EASE_IN_OUT = 3,
}

---@class Ease
---@field type number 缓动类型，对应EasingFunction中的类型
---@field time number 缓动时间，范围0-1，表示在总动画时间中的缓动时间比例

---@class Tween:Class
---@field duration number 动画持续时间（帧数）
---@field easeFunction EasingFunction 缓动函数类型
local Tween = ClassMgr.Class("Tween")

-- 缓动函数实现
local function linear(t)
    return t
end

local function easeIn(t)
    return t * t
end

local function easeOut(t)
    return t * (2 - t)
end

local function easeInOut(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- 缓动函数查找表
local EASING_FUNCTIONS = {
    [EasingFunction.LINEAR] = linear,
    [EasingFunction.EASE_IN] = easeIn,
    [EasingFunction.EASE_OUT] = easeOut,
    [EasingFunction.EASE_IN_OUT] = easeInOut
}

---初始化补间动画
---@param duration number 动画持续时间（秒）
function Tween:OnInit(duration)
    self.startTime = os.clock()
    self.component = nil ---@type ViewComponent
    self.duration = duration * 16 -- 转换为帧数
    self.timeElapsed = 0
    self.progress = 0
    self.ease = {type = EasingFunction.LINEAR, time = 0} ---@type Ease
    self.grouped = {} -- 存储组合的补间动画
    self.nextTween = nil -- 存储下一个要执行的补间动画
end

---设置缓动类型和缓动时间
---@param easeType EasingFunction 缓动类型
---@param easeTime number 缓动时间，范围0-1，表示在总动画时间中的缓动时间比例
function Tween:SetEase(easeType, easeTime)
    self.ease.type = easeType
    self.ease.time = easeTime
end

---@override
function Tween:GetToStringParams()
    return {
        component = self.component
    }
end

---设置补间动画的目标组件
---@param component ViewComponent 目标UI组件
function Tween:SetComponent(component)
    self.component = component
    for _, grouped in ipairs(self.grouped) do
        grouped.component = component
    end
    if self.nextTween then
        self.nextTween:SetComponent(component)
    end
end

---更新补间动画状态
---@return boolean 返回true表示动画已完成，false表示动画仍在进行中
function Tween:Update()
    for _, tween in ipairs(self.grouped) do
        tween:Update()
    end
    self.timeElapsed = self.timeElapsed + 1
    if self.timeElapsed >= self.duration then
        print("FINISH", os.clock() - self.startTime)
        self.progress = 1
        self:OnUpdate()
        return true
    else
        -- 计算原始进度（0到1）
        local rawProgress = self.timeElapsed / self.duration
        
        -- 根据ease.time计算缓动进度
        local easeTime = self.ease.time
        local easeProgress
        if rawProgress <= easeTime then
            -- 在缓动期间
            local easeRawProgress = rawProgress / easeTime
            local easingFunc = EASING_FUNCTIONS[self.ease.type] or linear
            easeProgress = easingFunc(easeRawProgress)
        else
            -- 缓动期之后，使用线性插值
            local remainingProgress = (rawProgress - easeTime) / (1 - easeTime)
            easeProgress = 1 - (1 - remainingProgress)
        end
        
        self.progress = easeProgress
        self:OnUpdate()
        return false
    end
end

---补间动画更新回调，由子类实现具体逻辑
function Tween:OnUpdate()
end

---添加一个组合补间动画
---@param tween Tween 要添加的补间动画
function Tween:AddTween(tween)
    if self.component then
        tween.component = self.component
    end
    table.insert(self.grouped, tween)
end

---设置下一个要执行的补间动画
---@param tween Tween 下一个补间动画
function Tween:SetNextTween(tween)
    if self.component then
        tween.component = self.component
    end
    self.nextTween = tween
end

---@class TweenPosition:Tween
---@field New fun(duration: number, from: Vector2, to: Vector2): TweenPosition
local TweenPosition = ClassMgr.Class("TweenPosition", Tween)

---初始化位置补间动画
---@param duration number 动画持续时间（秒）
---@param from Vector2 起始位置
---@param to Vector2 目标位置
function TweenPosition:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

---更新位置补间动画状态
function TweenPosition:OnUpdate()
    self.component.node.Position = self.from + (self.to - self.from) * self.progress
end

---@class TweenRotation:Tween
---@field New fun(duration: number, from: number, to: number): TweenRotation
local TweenRotation = ClassMgr.Class("TweenRotation", Tween)

---初始化旋转补间动画
---@param duration number 动画持续时间（秒）
---@param from number 起始角度
---@param to number 目标角度
function TweenRotation:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

---更新旋转补间动画状态
function TweenRotation:OnUpdate()
    self.component.node.Rotation = self.from + (self.to - self.from) * self.progress
end

---@class TweenScale:Tween
---@field New fun(duration: number, from: Vector2, to: Vector2): TweenScale
local TweenScale = ClassMgr.Class("TweenScale", Tween)

---初始化缩放补间动画
---@param duration number 动画持续时间（秒）
---@param from Vector4 起始缩放
---@param to Vector4 目标缩放
function TweenScale:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from ---@type Vector4
    self.to = to ---@type Vector4
end

---更新缩放补间动画状态
function TweenScale:OnUpdate()
    self.component.node.Scale = self.from + (self.to - self.from) * self.progress
end

---@class TweenColor:Tween
---@field New fun(duration: number, from: ColorQuad, to: ColorQuad): TweenColor
local TweenColor = ClassMgr.Class("TweenColor", Tween)

---初始化颜色补间动画
---@param duration number 动画持续时间（秒）
---@param from ColorQuad 起始颜色
---@param to ColorQuad 目标颜色
function TweenColor:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

---更新颜色补间动画状态
function TweenColor:OnUpdate()
    local color = self.from + (self.to - self.from) * self.progress
    self.component:SetColor(color)
end

---@class Tweens
---@field TweenPosition TweenPosition 位置补间动画
---@field TweenColor TweenColor 颜色补间动画
---@field TweenRotation TweenRotation 旋转补间动画
---@field TweenScale TweenScale 缩放补间动画
local Tweens = {
    TweenPosition = TweenPosition,
    TweenRotation = TweenRotation,
    TweenScale = TweenScale,
    TweenColor = TweenColor,
    EasingFunction = EasingFunction,
}

return Tweens