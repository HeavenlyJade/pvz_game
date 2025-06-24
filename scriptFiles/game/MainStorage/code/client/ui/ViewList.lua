local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class ViewList : ViewComponent
---@field node UIList
---@field childrens ViewComponent[] 子元素列表
---@field childNameTemplate string|nil 子元素名称模板
---@field onAddElementCb fun(child: SandboxNode): ViewComponent 添加元素时的回调函数
---@field New fun(node: UIComponent|ViewComponent, ui: ViewBase, path: string, onAddElementCb: fun(child: SandboxNode): ViewComponent): ViewList
local ViewList = ClassMgr.Class("ViewList", ViewComponent)


---@param node SandboxNode
---@param ui ViewBase
---@param onAddElementCb fun(child: SandboxNode): ViewComponent
function ViewList:OnInit(node, ui, path, onAddElementCb)
    self.childrens = {} ---@type ViewComponent[]
    self.childNameTemplate = nil
    self.onAddElementCb = onAddElementCb or function(child, childPath)
        return ViewComponent.New(child, ui, childPath)
    end
    for _, child in pairs(self.node.Children) do
        local childName = child.Name
        local num = childName:match("_([0-9]+)")
        -- print("Init ViewList", path, ui.className, num)
        if num then
            if not self.childNameTemplate then
                local pos = childName:find("_") -- 找到 _ 的位置
                self.childNameTemplate = childName:sub(1, pos)
            end
            local childPath = self.path .. "/" .. child.Name
            local button = self.onAddElementCb(child, childPath)
            if button then
                button.path = childPath
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
    local child = self.childrens[index]
    if not child then
        self:SetElementSize(index)
        child = self.childrens[index]
    end
    child.node.Visible = true
    return child
end

function ViewList:HideChildrenFrom(index)
    if #self.childrens > index then
        for i = index + 1, #self.childrens do
            self.childrens[i]:SetVisible(false)
        end
    end
end

---@return number
function ViewList:GetChildCount()
    return #self.childrens
end

---@param size number
function ViewList:SetElementSize(size)
    if size < 0 then
        size = 0
    end
    for i = 1, size do
        if not self.childrens[i] then
            local child = self.childrens[1].node:Clone()
            child:SetParent(self.node)
            child.Name = self.childNameTemplate .. i
            if self.onAddElementCb then
                local button = self.onAddElementCb(child)
                if button then
                    button.path = self.path .. "/" .. child.Name
                    button.index = i
                    self.childrens[i] = button
                end
            end
        end
        self.childrens[i]:SetVisible(true)
    end
    if #self.childrens > size then
        for i = size + 1, #self.childrens do
			if self.childrens[i] then
				self.childrens[i]:SetVisible(false)
			end
        end
    end
end

---@param visible boolean
function ViewList:SetGray(visible)
    self.node.Grayed = visible
end

---@param visible boolean
function ViewList:SetVisible(visible)
    self.node.Visible = visible
    self.node.Enabled = visible
end

---私有方法：根据childrens数组刷新UI布局
function ViewList:_refreshLayout()
    -- 步骤 1: 完全卸载 (Detach)
    -- 创建一个临时表来持有子节点，避免在迭代时修改集合
    local childrenToDetach = {}
    for _, child in pairs(self.node.Children) do
        table.insert(childrenToDetach, child)
    end
    for _, child in ipairs(childrenToDetach) do
        child:SetParent(nil)
    end

    -- 步骤 2: 重新装载 (Re-attach) 并更新元数据
    for i, comp in ipairs(self.childrens) do
        -- 重新设置父节点，按新顺序装载
        comp.node:SetParent(self.node)
        -- 更新元数据
        comp.index = i
        comp.path = self.path .. "/" .. comp.node.Name
    end
end


---私有方法：将一个ViewComponent|ViewButton插入到childrens数组中
---@param Component ViewComponent|ViewButton 要插入的组件
---@param index number 目标索引
function ViewList:insertIntoChildrens(Component, index)
    -- 安全地插入到 self.childrens 数组
    local targetIndex = index
    if not targetIndex or targetIndex > #self.childrens + 1 or targetIndex < 1 then
        targetIndex = #self.childrens + 1 -- 如果index无效或越界，则插入到末尾
    end
    Component.node:SetParent(self.node)
    table.insert(self.childrens, targetIndex, Component)
end


---在指定位置插入子节点
---@param childNode SandboxNode 要添加的子节点
---@param index number 要插入的位置
---@param shouldRefresh boolean|nil 是否在插入后立即刷新UI布局，默认为false
function ViewList:InsertChild(childNode, index, shouldRefresh)
    -- 步骤 1: 创建逻辑包装器
    local viewComponent = self.onAddElementCb(childNode)
    if not viewComponent then
        return -- 如果创建失败，则直接返回
    end
    -- 步骤 2: 插入到childrens数组
    self:insertIntoChildrens(viewComponent, index)
    -- 步骤 3: 如果需要，则刷新布局
    if shouldRefresh then
        self:_refreshLayout()
    end
end

---@param childNode SandboxNode 要添加的子节点
function ViewList:AppendChild(childNode)
    -- AppendChild 默认立即刷新UI
    self:InsertChild(childNode, #self.childrens + 1, false)
end

--- 通过名称获取子节点实例
---@param childName string 要查找的子节点名称
---@return ViewComponent|nil
function ViewList:GetChildByName(childName)
    for _, child in ipairs(self.childrens) do
        if child.node and child.node.Name == childName then
            return child
        end
    end
    return nil
end

--- 通过名称移除子节点
---@param childName string 要移除的子节点的名称
---@return boolean true|false
function ViewList:RemoveChildByName(childName)
    local indexToRemove
    for i, child in ipairs(self.childrens) do
        if child.node and child.node.Name == childName then
            indexToRemove = i
            break
        end
    end

    if indexToRemove then
        local removedComponent = table.remove(self.childrens, indexToRemove)
        if removedComponent and removedComponent.node  then
            removedComponent.node:Destroy()
        end

        -- 更新后续元素的索引以保持一致性
        for i = indexToRemove, #self.childrens do
            self.childrens[i].index = i
        end
        return true
    end

    return false
end

---清空所有子元素
function ViewList:ClearChildren()
    for _, child in ipairs(self.childrens) do
        if child.node  then
            child.node:Destroy()
        end
    end
    self.childrens = {}
end

return ViewList
