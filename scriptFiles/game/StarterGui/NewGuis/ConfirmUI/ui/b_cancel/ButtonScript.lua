
local img = script.Parent ---@type UIImage

local clickImg = img:GetAttribute("点击图片") ---@type string
local hoverImg = img:GetAttribute("悬浮图片") or clickImg ---@type string
local normalImg = img.Icon

local hoverColor = img:GetAttribute("悬浮颜色") ---@type ColorQuad
local clickColor = img:GetAttribute("点击颜色") ---@type ColorQuad
local normalColor = img.FillColor

local isHover = false

img.RollOver:Connect(function(node, isOver, vector2)
    if isOver then
        isHover = true
        img.Icon = hoverImg
        img.FillColor = hoverColor
    end
end)

img.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
    if isTouchBegin then
        img.Icon = clickImg
        img.FillColor = clickColor
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
    end
end)

img.RollOut:Connect(function(node, isOver, vector2)
    if not isOver then
        self.isHover = false
        img.Icon = normalImg
        img.FillColor = normalColor
    end
end)

