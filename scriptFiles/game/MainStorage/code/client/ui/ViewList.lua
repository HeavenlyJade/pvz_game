local MainStorage = game:GetService("MainStorage")
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent


---@generic T : ViewComponent
---@class ViewList:ViewComponent
---@field New fun(node: SandboxNode): ViewList
---@field childrens table<number, T>
local  ViewList = CommonModule.Class("ViewList", ViewComponent)

function ViewList:OnInit(node)
    self.node = node ---@type UIList
    self.childrens = {} ---@type table<number, T>
    self.childNameTemplate = nil
    self.onAddElementCb = nil ---@type function
    for _, child in ipairs(self.node.Children) do
        local childName = child.Name
        local num = childName:match("_([0-9]+)")
        if num then
            if not self.childNameTemplate then
                local pos = childName:find("_")  -- 找到 _ 的位置
                self.childNameTemplate = childName:sub(1, pos)
            end
            self.childrens[tonumber(num)] = child
        end
    end
end

function ViewList:SetAddElementCb(cb)
    self.onAddElementCb = cb
    for idx, child in ipairs(self.childrens) do
        local button = self.onAddElementCb(child)
        if button then
            self.childrens[idx] = button
        end
    end
end

---@return T
function ViewList:GetChild(index)
    return self.childrens[index]
end

function ViewList:GetChildCount()
    return #self.childrens
end

function ViewList:SetElementSize(size)
    for i = 1, size do
        if not self.childrens[i] then
            local child = self.node[1]:Clone()
            child:SetParent(self.node)
            child.Name = self.childNameTemplate .. i
            self.childrens[i] = child
            if self.onAddElementCb then
                local button = self.onAddElementCb(child)
                if button then
                    self.childrens[i] = button
                end
            end
        end
        self.childrens[i].Visible = true
        self.childrens[i].Enabled = true
    end
    if #self.childrens > size then
        for i = size + 1, #self.childrens do
            self.childrens[i].Enabled = false
            self.childrens[i].Visible = false
        end
    end
    
end


return ViewList