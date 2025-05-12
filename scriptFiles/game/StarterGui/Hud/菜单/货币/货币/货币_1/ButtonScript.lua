
local img = script.Parent ---@type UIImage

local clickImg = img:GetAttribute("图片-点击") ---@type string
local hoverImg = img:GetAttribute("图片-悬浮") or clickImg ---@type string
local normalImg = img.Icon

local hoverColor = img:GetAttribute("悬浮颜色") ---@type ColorQuad
local clickColor = img:GetAttribute("点击颜色") ---@type ColorQuad
local normalColor = img.FillColor

local soundPress = img:GetAttribute("音效-点击") ---@type string
local soundHover = img:GetAttribute("音效-悬浮") ---@type string
local soundRelease = img:GetAttribute("音效-抬起") ---@type string

local soundPlayer = game:GetService("StarterGui")["UISound"] ---@type Sound
local isHover = false

img.RollOver:Connect(function(node, isOver, vector2)
    if isOver then
        isHover = true
        img.Icon = hoverImg
        img.FillColor = hoverColor
        if soundHover then
            soundPlayer.SoundPath = soundHover
            soundPlayer:PlaySound()
        end
    end
end)

img.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
    if isTouchBegin then
        img.Icon = clickImg
        img.FillColor = clickColor
        if soundPress then
            soundPlayer.SoundPath = soundPress
            soundPlayer:PlaySound()
        end
    end
end)


img.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
    if isTouchEnd then
        if isHover then
            img.Icon = hoverImg
            img.FillColor = hoverColor
        else
            img.Icon = normalImg
            img.FillColor = normalColor
        end
        if soundRelease then
            soundPlayer.SoundPath = soundRelease
            soundPlayer:PlaySound()
        end
    end
end)

img.RollOut:Connect(function(node, isOver, vector2)
    if not isOver then
        isHover = false
        img.Icon = normalImg
        img.FillColor = normalColor
    end
end)

