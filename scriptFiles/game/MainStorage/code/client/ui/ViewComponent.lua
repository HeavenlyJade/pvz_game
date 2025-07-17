local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr



---@class ViewComponent:Class
---@field node UIComponent
---@field New fun(node: SandboxNode, ui: ViewBase, path?:string,  ...): ViewComponent
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
    self.ui = ui ---@type ViewBase
    self.index = 0
    self.path = path or ""
    self.extraParams = {} -- 可在此存储任意与该按钮相关的数据
end

---@return Vector2
function ViewComponent:GetGlobalPos()
    return self.node:GetGlobalPos()
end

function ViewComponent:SetGray(isGray)
    self.node.Grayed = isGray
end

---@override
function ViewComponent:GetToStringParams()
    return {
        node = self.path
    }
end

---@return ViewComponent
function ViewComponent:GetComponent(path)
    return self:Get(path)
end

---@return ViewItem
function ViewComponent:GetItem(path)
    local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
    return self:Get(path, ViewItem)
end

---@return ViewToggle
function ViewComponent:GetToggle(path)
    local ViewToggle = require(MainStorage.code.client.ui.ViewToggle) ---@type ViewToggle
    return self:Get(path, ViewToggle)
end

---@return ViewList
function ViewComponent:GetList(path, onAddElementCb)
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    return self:Get(path, ViewList, onAddElementCb)
end

---@return ViewButton
function ViewComponent:GetButton(path)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    return self:Get(path, ViewButton)
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

---@param visible boolean
function ViewComponent:SetVisible(visible)
    self.node.Visible = visible
    self.node.Enabled = visible
end

return ViewComponent
