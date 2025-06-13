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
    self.path = path
    self.extraParams = {} -- 可在此存储任意与该按钮相关的数据
end

function ViewComponent:GetGlobalPos()
    
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
    -- === 新增：调试日志，追踪副卡强化按钮的可见性变化 ===
    if self.node and self.node.Name and (string.find(self.node.Name, "副卡_强化") or string.find(self.node.Name, "副卡一键强化")) then
        local gg = require(game:GetService("MainStorage").code.common.MGlobal)
        gg.log("👁️ SetVisible:", self.node.Name, "visible:", visible, "路径:", self.path or "unknown")
    end
    
    self.node.Visible = visible
    self.node.Enabled = visible
end

return ViewComponent
