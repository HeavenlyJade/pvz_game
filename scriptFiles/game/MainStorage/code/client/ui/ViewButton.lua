local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local soundPlayer = game:GetService("StarterGui")["UISound"] ---@type Sound

---@class ViewButton:ViewComponent
---@field New fun(node: SandboxNode, ui: ViewBase): ViewButton
local  ViewButton = ClassMgr.Class("ViewButton", ViewComponent)

function ViewButton:OnTouchOut()
    if self.isHover then
        self.img.Icon = self.hoverImg
        self.img.FillColor = self.hoverColor
    else
        self.img.Icon = self.normalImg
        self.img.FillColor = self.normalColor
    end
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
end

function ViewButton:OnTouchIn()
    self.img.Icon = self.clickImg
    self.img.FillColor = self.clickColor
    if self.soundPress and soundPlayer then
        soundPlayer.SoundPath = self.soundPress
        soundPlayer:PlaySound()
    end
    
    -- Handle child images
    for child, props in pairs(self.childClickImgs) do
        if props.clickImg then
            child.Icon = props.clickImg
        end
        if props.clickColor then
            child.FillColor = props.clickColor
        end
    end
end

function ViewButton:OnHoverOut()
    self.isHover = false
    self.img.Icon = self.normalImg
    self.img.FillColor = self.normalColor
    
    -- Handle child images
    for child, props in pairs(self.childClickImgs) do
        child.Icon = props.normalImg
        child.FillColor = props.normalColor
    end
end

function ViewButton:OnHoverIn()
    self.isHover = true
    self.img.Icon = self.hoverImg
    self.img.FillColor = self.hoverColor
    if self.soundHover and soundPlayer then
        soundPlayer.SoundPath = self.soundHover
        soundPlayer:PlaySound()
    end
    
    -- Handle child images
    for child, props in pairs(self.childClickImgs) do
        if props.hoverImg then
            child.Icon = props.hoverImg
        end
        if props.hoverColor then
            child.FillColor = props.hoverColor
        end
    end
end

function ViewButton:OnClick()
    if self.clickCb then
        self.clickCb(self.ui, self)
    end
end

function ViewButton:OnInit(node, ui)
    ViewComponent.OnInit(self, node, ui)
    self.childClickImgs = {    }
    local img = node
    self.img = node ---@type UIImage
    self.clickCb = nil
    self.clickImg = img:GetAttribute("图片-点击") ---@type string
    self.hoverImg = img:GetAttribute("图片-悬浮") ---@type string
    if self.hoverImg == "" then
        self.hoverImg = self.clickImg
    end
    self.normalImg = img.Icon
    
    self.hoverColor = img:GetAttribute("悬浮颜色") ---@type ColorQuad
    self.clickColor = img:GetAttribute("点击颜色") ---@type ColorQuad
    self.normalColor = img.FillColor
    
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
        self:OnTouchIn()
    end)

    img.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
        self:OnTouchOut()
    end)

    img.RollOut:Connect(function(node, isOver, vector2)
        self:OnHoverOut()
    end)

    img.Click:Connect(function(node, isClick, vector2, number)
        self:OnClick()
    end)

    for _, child in ipairs(img.Children) do ---@type UIComponent
        if child:IsA("UIImage") and child:GetAttribute("继承按钮") then
            local clickImg = child:GetAttribute("图片-点击")---@type string
            local hoverImg = child:GetAttribute("图片-悬浮") ---@type string
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
                self:OnTouchIn()
            end)
            child.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
                self:OnTouchOut()
            end)
            child.Click:Connect(function(node, isClick, vector2, number)
                self:OnClick()
            end)
        end
    end

end





return ViewButton