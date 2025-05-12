local MainStorage = game:GetService("MainStorage")
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule

---@class Tween:Class
---@field duration number
---@field easeFunction EasingFunction
local Tween = CommonModule.Class("Tween")

function Tween:OnInit(duration)
    self.component = nil ---@type ViewComponent
    self.duration = duration * 10
    self.timeElapsed = 0
    self.progress = 0
    self.easeFunction = nil
    self.grouped = {}
    self.nextTween = nil
end

---@return boolean
function Tween:Update()
    self.timeElapsed = self.timeElapsed + 1
    if self.timeElapsed >= self.duration then
        return true
    else
        --TODO: 处理EaseFunction
        self.progress = self.timeElapsed / self.duration
        self:OnUpdate()
        return false
    end
end

function Tween:OnUpdate()
end

function Tween:AddTween(tween)
    table.insert(self.grouped, tween)
end

function Tween:SetNextTween(tween)
    self.nextTween = tween
end

---@class TweenPosition:Tween
---@field New fun(duration: number, from: Vector2, to: Vector2): TweenPosition
local TweenPosition = CommonModule.Class("TweenPosition", Tween)

function TweenPosition:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

function TweenPosition:OnUpdate()
    self.component.Position = self.from + (self.to - self.from) * self.progress
end



---@class TweenRotation:Tween
---@field New fun(duration: number, from: number, to: number): TweenRotation
local TweenRotation = CommonModule.Class("TweenRotation", Tween)

function TweenRotation:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

function TweenRotation:OnUpdate()
    self.component.Rotation = self.from + (self.to - self.from) * self.progress
end


---@class TweenScale:Tween
---@field New fun(duration: number, from: Vector2, to: Vector2): TweenScale
local TweenScale = CommonModule.Class("TweenScale", Tween)

function TweenScale:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

function TweenScale:OnUpdate()
    self.component.Scale = self.from + (self.to - self.from) * self.progress
end

---@class TweenColor:Tween
---@field New fun(duration: number, from: ColorQuad, to: ColorQuad): TweenColor
local TweenColor = CommonModule.Class("TweenColor", Tween)

function TweenColor:OnInit(duration, from, to)
    Tween.OnInit(self, duration)
    self.from = from
    self.to = to
end

function TweenColor:OnUpdate()
    local color = self.from + (self.to - self.from) * self.progress
    self.component:SetColor(color)
end



return {
    TweenPosition = TweenPosition,
    TweenRotation = TweenRotation,
    TweenScale = TweenScale,
    TweenColor = TweenColor,
}