local MainStorage = game:GetService("MainStorage")
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule



---@class ViewComponent:Class
---@field New fun(node: SandboxNode): ViewComponent
local  ViewComponent = CommonModule.Class("ViewComponent")


function ViewComponent:OnInit(node, ui)
    self.node = node ---@type UIComponent
    self.defaultPos = self.node.Position
    self.defaultSize = self.node.Size
    self.defaultRotation = self.node.Rotation
    self.currentTween = nil
    self.ui = ui ---@type ViewBase
end

function ViewComponent:SetColor(color)
    if self.node:IsA("UIImage") then
        self.node.FillColor = color
    elseif self.node:IsA("UITextLabel") then
        self.node.TitleColor = color
    end
end


function ViewComponent:AddTween(tween)
    if self.currentTween then
        self.currentTween:SetNextTween(tween)
    else
        self.currentTween = tween
    end
    self.ui:RegisterTween(self)
end

return ViewComponent