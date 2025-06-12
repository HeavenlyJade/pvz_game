local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local soundPlayer = game:GetService("StarterGui")["UISound"] ---@type Sound
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
---@class ViewButton:ViewComponent
---@field New fun(node: SandboxNode, ui: ViewBase, path?: string, realButtonPath?: string): ViewButton
local  ViewButton = ClassMgr.Class("ViewButton", ViewComponent)


---@param enable boolean
---@param updateGray? boolean
function ViewButton:SetTouchEnable(enable, updateGray)
    self.enabled = enable
    if updateGray == nil then
        self.img.Grayed = not enable
    end
end

function ViewButton:OnTouchOut()
    if self.isHover then
        if self.hoverImg then
            self.img.Icon = self.hoverImg
        end
        if self.hoverColor then
            self.img.FillColor = self.hoverColor
        end
    else
        self.img.Icon = self.normalImg
        self.img.FillColor = self.normalColor
    end
    if not self.enabled then return end
    if self.soundRelease and soundPlayer then
        soundPlayer.SoundPath = self.soundRelease
        soundPlayer:PlaySound()
    end

    -- Handle child images
    for child, props in pairs(self.childClickImgs) do
        if self.isHover then
            if props.hoverImg then
                child.Icon = props.hoverImg
            end
            if props.hoverColor then
                child.FillColor = props.hoverColor
            end
        else
            child.Icon = props.normalImg
            child.FillColor = props.normalColor
        end
    end

    if self.touchEndCb then
        self.touchEndCb(self.ui, self)
    end
end

function ViewButton:OnTouchIn(vector2)
    if not self.enabled then return end
    self.normalImg = self.img.Icon
    if not self.isHover then
        if self.clickImg then
            self.img.Icon = self.clickImg
        end
    end
    if self.clickColor then
        self.img.FillColor = self.clickColor
    end
    if self.soundPress and soundPlayer then
        soundPlayer.SoundPath = self.soundPress
        soundPlayer:PlaySound()
    end

    -- Handle child images
    for child, props in pairs(self.childClickImgs) do
        if not self.isHover then
            props.normalImg = child.Icon
        end
        if props.clickImg then
            child.Icon = props.clickImg
        end
        if props.clickColor then
            child.FillColor = props.clickColor
        end
    end
    if self.enabled then
        ClientEventManager.Publish("ButtonTouchIn", {
            button = self
        })
    end
    if self.touchBeginCb then
        self.touchBeginCb(self.ui, self, vector2)
    end
end

function ViewButton:OnTouchMove(node, isTouchMove, vector2, int)
    if not self.enabled then return end
    if self.touchMoveCb then
        self.touchMoveCb(self.ui, self, vector2)
    end
end

function ViewButton:OnHoverOut()
    self.isHover = false
    self.img.Icon = self.normalImg
    self.img.FillColor = self.normalColor
    for child, props in pairs(self.childClickImgs) do
        child.Icon = props.normalImg
        child.FillColor = props.normalColor
    end
end

function ViewButton:OnHoverIn()
    if not self.enabled then return end
    self.isHover = true
    self.normalImg = self.img.Icon
    if self.hoverImg then
        self.img.Icon = self.hoverImg
    end
    if self.hoverColor then
        self.img.FillColor = self.hoverColor
    end
    if self.soundHover and soundPlayer then
        soundPlayer.SoundPath = self.soundHover
        soundPlayer:PlaySound()
    end

    -- Handle child images
    for child, props in pairs(self.childClickImgs) do
        props.normalImg = child.Icon
        if props.hoverImg then
            child.Icon = props.hoverImg
        end
        if props.hoverColor then
            child.FillColor = props.hoverColor
        end
    end
end

function ViewButton:OnClick()
    if not self.enabled then return end
    if self.clickCb then
        self.clickCb(self.ui, self)
    end
end

function ViewButton:OnInit(node, ui, path, realButtonPath)
    self.childClickImgs = {    }
    self.enabled = true
    self.img = node ---@type UIImage
    if realButtonPath then
        self.img = self.img[realButtonPath]
    end
    local img = self.img
    self.img.ClickPass = false
    self.clickCb = nil ---@type fun(ui:ViewBase, button:ViewButton)
    self.touchBeginCb = nil
    self.touchMoveCb = nil
    self.touchEndCb = nil
    self.clickImg = img:GetAttribute("图片-点击") ---@type string
    if self.clickImg == "" then
        self.clickImg = nil
    end
    self.hoverImg = img:GetAttribute("图片-悬浮") ---@type string
    self.defaultImg = img:GetAttribute("图片-默认") ---@type string
    if self.hoverImg == "" then
        self.hoverImg = self.clickImg
    end
    self.normalImg = img.Icon

    self.hoverColor = img:GetAttribute("悬浮颜色") ---@type ColorQuad
    self.clickColor = img:GetAttribute("点击颜色") ---@type ColorQuad
    self.normalColor = img.FillColor

    -- === 新增：单个按钮的选中状态管理（不涉及其他按钮） ===
    self.isSelected = false              -- 是否处于选中状态
    self.selectedImg = self.clickImg     -- 选中状态图片（默认使用点击图片）
    self.selectedColor = self.clickColor -- 选中状态颜色（默认使用点击颜色）

    self.soundPress = img:GetAttribute("音效-点击") ---@type string
    if self.soundPress == "" then
        self.soundPress = nil
    end
    self.soundHover = img:GetAttribute("音效-悬浮") ---@type string
    if self.soundHover == "" then
        self.soundHover = nil
    end
    self.soundRelease = img:GetAttribute("音效-抬起") ---@type string
    if self.soundRelease == "" then
        self.soundRelease = nil
    end

    self.isHover = false

    img.RollOver:Connect(function(node, isOver, vector2)
        self:OnHoverIn()
    end)

    img.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
        self:OnTouchIn(vector2)
    end)

    img.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
        self:OnTouchOut()
    end)

    img.TouchMove:Connect(function(node, isTouchMove, vector2, number)
        self:OnTouchMove(node, isTouchMove, vector2, number)
    end)

    img.RollOut:Connect(function(node, isOver, vector2)
        self:OnHoverOut()
    end)

    img.Click:Connect(function(node, isClick, vector2, number)
        self:OnClick()
    end)

    for _, child in ipairs(img.Children) do ---@type UIComponent
        if child:IsA("UIImage") and child:GetAttribute("继承按钮") then
            local clickImg = child:GetAttribute("图片-点击")---@type string|nil
            local hoverImg = child:GetAttribute("图片-悬浮") ---@type string|nil
            if clickImg == "" then
                clickImg = nil
            end
            if hoverImg == "" then
                hoverImg = clickImg
            end
            self.childClickImgs[child] = {
                normalImg = child.Icon,---@type string
                clickImg = clickImg,
                hoverImg = hoverImg,

                hoverColor = child:GetAttribute("悬浮颜色"), ---@type ColorQuad
                clickColor = child:GetAttribute("点击颜色"), ---@type ColorQuad
                normalColor = child.FillColor,
            }
            child.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
                self:OnTouchIn(vector2)
            end)
            child.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
                self:OnTouchOut()
            end)
            child.TouchMove:Connect(function(node, isTouchMove, vector2, number)
                self:OnTouchMove(node, isTouchMove, vector2, number)
            end)
            child.Click:Connect(function(node, isClick, vector2, number)
                self:OnClick()
            end)
        end
    end
end

-- 设置按钮的选中状态（仅管理自身，不涉及其他按钮）
---@param selected boolean 是否选中
---@param targetNodePath? string 目标节点路径（可选，用于自定义节点）
function ViewButton:SetSelected(selected, targetNodePath)
    if self.isSelected == selected then return end -- 状态没有变化，直接返回
    self.isSelected = selected
    -- 获取目标节点
    local targetNode = self.img
    if targetNodePath then
        -- 解析自定义节点路径
        local pathParts = {}
        for part in string.gmatch(targetNodePath, "[^/]+") do
            table.insert(pathParts, part)
        end

        targetNode = self.node
        for _, part in ipairs(pathParts) do
            targetNode = targetNode[part]
            if not targetNode then
                return
            end
        end
    end

    if selected then
        -- 设置为选中状态
        local selectedImg = targetNode:GetAttribute("图片-点击") or self.selectedImg
        if selectedImg and selectedImg ~= "" and targetNode.Icon ~= selectedImg then
            targetNode.Icon = selectedImg
        end
        if self.selectedColor and targetNode.FillColor ~= self.selectedColor then
            targetNode.FillColor = self.selectedColor
        end
    else
        -- 恢复为默认状态
        local defaultImg = targetNode:GetAttribute("图片-默认") or self.normalImg
        if defaultImg and defaultImg ~= "" and targetNode.Icon ~= defaultImg then
            targetNode.Icon = defaultImg
        end
        if targetNode.FillColor ~= self.normalColor then
            targetNode.FillColor = self.normalColor
        end
    end
end

-- 检查是否选中
---@return boolean
function ViewButton:IsSelected()
    return self.isSelected
end

-- === 新增：重新绑定到新的UI节点 ===
-- 用于在按钮复用时重新绑定到新的UI节点，重新设置所有事件监听器和属性
---@param newNode SandboxNode 新的UI节点
---@param realButtonPath? string 真实按钮路径（与初始化时相同）
function ViewButton:RebindToNewNode(newNode, realButtonPath)
    if not newNode then return end

    -- 清理旧的childClickImgs（避免内存泄漏）
    self.childClickImgs = {}

    -- 更新节点引用
    self.node = newNode
    local oldImg = self.img
    self.img = newNode
    if realButtonPath then
        self.img = self.img[realButtonPath]
    end

    local img = self.img
    if not img then
        return
    end

    -- 重新设置基本属性
    img.ClickPass = false

    -- 重新绑定所有事件监听器
    img.RollOver:Connect(function(node, isOver, vector2)
        self:OnHoverIn()
    end)

    img.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
        self:OnTouchIn(vector2)
    end)

    img.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
        self:OnTouchOut()
    end)

    img.TouchMove:Connect(function(node, isTouchMove, vector2, number)
        self:OnTouchMove(node, isTouchMove, vector2, number)
    end)

    img.RollOut:Connect(function(node, isOver, vector2)
        self:OnHoverOut()
    end)

    img.Click:Connect(function(node, isClick, vector2, number)
        self:OnClick()
    end)

    -- 重新获取图片属性
    self.clickImg = img:GetAttribute("图片-点击")
    self.hoverImg = img:GetAttribute("图片-悬浮")
    self.defaultImg = img:GetAttribute("图片-默认")
    if self.hoverImg == "" then
        self.hoverImg = self.clickImg
    end
    self.normalImg = img.Icon

    -- 重新获取颜色属性
    self.hoverColor = img:GetAttribute("悬浮颜色")
    self.clickColor = img:GetAttribute("点击颜色")
    self.normalColor = img.FillColor

    -- 更新选中状态相关属性
    self.selectedImg = self.clickImg
    self.selectedColor = self.clickColor

    -- 重新获取音效属性
    self.soundPress = img:GetAttribute("音效-点击")
    if self.soundPress == "" then
        self.soundPress = nil
    end
    self.soundHover = img:GetAttribute("音效-悬浮")
    if self.soundHover == "" then
        self.soundHover = nil
    end
    self.soundRelease = img:GetAttribute("音效-抬起")
    if self.soundRelease == "" then
        self.soundRelease = nil
    end

    -- 重新处理子节点的继承按钮
    for _, child in ipairs(img.Children) do
        if child:IsA("UIImage") and child:GetAttribute("继承按钮") then
            local clickImg = child:GetAttribute("图片-点击")
            local hoverImg = child:GetAttribute("图片-悬浮")
            if clickImg == "" then
                clickImg = nil
            end
            if hoverImg == "" then
                hoverImg = clickImg
            end
            self.childClickImgs[child] = {
                normalImg = child.Icon,
                clickImg = clickImg,
                hoverImg = hoverImg,
                hoverColor = child:GetAttribute("悬浮颜色"),
                clickColor = child:GetAttribute("点击颜色"),
                normalColor = child.FillColor,
            }

            -- 为子节点重新绑定事件
            child.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
                self:OnTouchIn(vector2)
            end)
            child.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
                self:OnTouchOut()
            end)
            child.TouchMove:Connect(function(node, isTouchMove, vector2, number)
                self:OnTouchMove(node, isTouchMove, vector2, number)
            end)
            child.Click:Connect(function(node, isClick, vector2, number)
                self:OnClick()
            end)
        end
    end

end

return ViewButton
