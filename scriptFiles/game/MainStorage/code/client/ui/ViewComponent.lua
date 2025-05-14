local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr



---@class ViewComponent:Class
---@field node UIComponent
---@field New fun(node: SandboxNode, ui: ViewBase, path:string,  ...): ViewComponent
---@field path string 组件的绝对路径
local  ViewComponent = ClassMgr.Class("ViewComponent")


function ViewComponent:OnInit(node, ui, path)
    if node.className then
        self.node = node.node
    else
        self.node = node
    end
    self.defaultPos = self.node.Position
    self.defaultSize = self.node.Size
    self.defaultRotation = self.node.Rotation
    self.currentTween = nil
    self.ui = ui ---@type ViewBase
    self.index = 0
    self.path = path
end

---@override
function ViewComponent:GetToStringParams()
    return {
        node = self.path
    }
end

---@generic T : ViewComponent
---@param path string 相对路径
---@param type? T 组件类型
---@param ... any 额外参数
---@return T
function ViewComponent:Get(path, type, ...)
    return self.ui:Get(self.path .. "/" .. path, type, ...)
end


---@param color Vector4
function ViewComponent:SetColor(color)
    local c
    if color.x <= 1 and color.y <= 1 and color.z <= 1 and color.w <= 1 then
        c = ColorQuad.New(color.x * 255, color.y * 255, color.z * 255, color.w * 255)
    else
        c = ColorQuad.New(color.x, color.y, color.z, color.w)
    end
    if self.node:IsA("UIImage") then
        self.node.FillColor = c
    elseif self.node:IsA("UITextLabel") then
        local node = self.node ---@cast node UITextLabel
        node.TitleColor = c
    end
end


function ViewComponent:SetVisible(visible)
    self.node.Visible = visible
    self.node.Enabled = visible
end

---@param tween Tween 要添加的补间动画对象
---@description 为UI组件添加补间动画。补间动画可以通过Tween:AddTween添加多个，它们会同时执行。
---@example
--- -- 创建一个位置补间动画，从当前位置移动到新位置
--- local tween = Tweens.TweenPosition.New(1, card.node.Position, newPos)
--- -- 添加旋转补间动画，从当前角度旋转到0度
--- tween:AddTween(Tweens.TweenRotation.New(1, card.node.Rotation, 0))
--- -- 添加颜色补间动画，从灰色渐变到白色
--- tween:AddTween(Tweens.TweenColor.New(1, Vector4.New(0.9, 0.9, 0.9, 1), Vector4.New(1,1,1, 1)))
--- -- 将补间动画添加到组件。 如果组件已经存在补间动画，会自动添加到下一个补间动画。
--- card:AddTween(tween)
---@example
--- -- 重置卡牌位置和状态的补间动画
--- local tween = Tweens.TweenPosition.New(1, card.node.Position, card.defaultPos)
--- tween:AddTween(Tweens.TweenRotation.New(1, card.node.Rotation, card.defaultRotation))
--- tween:AddTween(Tweens.TweenColor.New(1, Vector4.New(1,1,1, 1), Vector4.New(0.9, 0.9, 0.9, 1)))
--- card:AddTween(tween)
function ViewComponent:AddTween(tween)
    tween:SetComponent(self)
    if self.currentTween then
        self.currentTween:SetNextTween(tween)
    else
        self.currentTween = tween
    end
    self.ui:RegisterTween(self)
end

return ViewComponent
