local MainStorage = game:GetService("MainStorage")
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local soundPlayer = game:GetService("StarterGui")["UISound"] ---@type Sound

---@class ViewButton:ViewComponent
---@field New fun(node: SandboxNode): ViewButton
local  ViewButton = CommonModule.Class("ViewButton", ViewComponent)

function ViewButton:OnTouchOut()
    if self.isHover then
        self.img.Icon = self.hoverImg
        self.img.FillColor = self.hoverColor
    else
        self.img.Icon = self.normalImg
        self.img.FillColor = self.normalColor
    end
    if self.soundRelease then
        soundPlayer.SoundPath = self.soundRelease
        soundPlayer:PlaySound()
    end
end

function ViewButton:OnTouchIn()
    self.img.Icon = self.clickImg
    self.img.FillColor = self.clickColor
    if self.soundPress then
        soundPlayer.SoundPath = self.soundPress
        soundPlayer:PlaySound()
    end
end

function ViewButton:OnHoverOut()
    self.isHover = false
    self.img.Icon = self.normalImg
    self.img.FillColor = self.normalColor
end

function ViewButton:OnHoverIn()
    self.isHover = true
    self.img.Icon = self.hoverImg
    self.img.FillColor = self.hoverColor
    if self.soundHover then
        soundPlayer.SoundPath = self.soundHover
        soundPlayer:PlaySound()
    end
end

function ViewButton:OnClick()
    if self.clickCb then
        self.clickCb()
    end
end

function ViewButton:OnInit(node)
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

    for _, child in ipairs(img.Children) do
        if child:IsA("UIImage") and child.GetAttribute("继承按钮") then
            local clickImg = child:GetAttribute("图片-点击") ---@type string
            local hoverImg = child:GetAttribute("图片-悬浮") ---@type string
            child.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
                child.Icon = clickImg
                child.FillColor = hoverImg
                self:OnTouchIn()
            end)
            child.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
                child.Icon = clickImg
                child.FillColor = hoverImg
                self:OnTouchOut()
            end)
            child.Click:Connect(function(node, isClick, vector2, number)
                self:OnClick()
            end)
        end
    end

end





return ViewButton