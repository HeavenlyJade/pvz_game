local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class ViewList : ViewComponent
---@field node UIList
---@field childrens ViewComponent[] 子元素列表
---@field childNameTemplate string|nil 子元素名称模板
---@field onAddElementCb fun(child: SandboxNode): ViewComponent 添加元素时的回调函数
---@field New fun(node: UIComponent|ViewComponent, ui: ViewBase, path: string, onAddElementCb: fun(child: SandboxNode): ViewComponent): ViewList
local ViewList = ClassMgr.Class("ViewList", ViewComponent)

---@param node SandboxNode
---@param ui SandboxNode
---@param onAddElementCb fun(child: SandboxNode): ViewComponent
function ViewList:OnInit(node, ui, path, onAddElementCb)
    ViewComponent.OnInit(self, node, ui, path)
    self.childrens = {} ---@type ViewComponent[]
    self.childNameTemplate = nil
    self.onAddElementCb = onAddElementCb
    for _, child in pairs(self.node.Children) do
        local childName = child.Name
        local num = childName:match("_([0-9]+)")
        if num then
            if not self.childNameTemplate then
                local pos = childName:find("_") -- 找到 _ 的位置
                self.childNameTemplate = childName:sub(1, pos)
            end
            local button = self.onAddElementCb(child)
            if button then
                print("ViewList", ui.Name, self.path, child.Name)
                button.path = self.path .. "/" .. child.Name
                local idx = tonumber(num)
                if idx then
                    self.childrens[idx] = button
                    button.index = idx
                end
            end
        end
    end
end

function ViewList:GetToStringParams()
    local d = ViewComponent.GetToStringParams(self)
    d["Child"] = self.childrens
    return d
end

---@param index number
---@return ViewComponent
function ViewList:GetChild(index)
    return self.childrens[index]
end

---@return number
function ViewList:GetChildCount()
    return #self.childrens
end

---@param size number
function ViewList:SetElementSize(size)
    for i = 1, size do
        if not self.childrens[i] then
            local child = self.node[1]:Clone()
            child:SetParent(self.node)
            child.Name = self.childNameTemplate .. i
            if self.onAddElementCb then
                local button = self.onAddElementCb(child)
                if button then
                    button.path = self.path .. "/" .. child.Name
                    child.index = i
                    self.childrens[i] = button
                end
            end
        end
        self.childrens[i]:SetVisible(true)
    end
    if #self.childrens > size then
        for i = size + 1, #self.childrens do
            self.childrens[i]:SetVisible(false)
        end
    end
end

return ViewList
