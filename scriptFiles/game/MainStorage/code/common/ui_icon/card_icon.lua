---@class CardIcon
-- 卡片图标配置
local CardIcon = {}

-- 品质默认图标
CardIcon.qualityDefIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏绿.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏蓝.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏紫.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏橙.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏彩.png",
}

-- 品质点击图标
CardIcon.qualityClickIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏绿_1.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏蓝_1.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏紫_1.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏橙_1.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏彩_1.png",
}

-- 品质底图默认图标
CardIcon.qualityBaseMapDefIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏绿_底图.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏蓝_底图.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏紫_底图.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏橙_底图.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏彩_底图.png",
}

-- 品质底图点击图标
CardIcon.qualityBaseMapClickIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏绿_底图1.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏蓝_底图1.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏紫_底图1.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏橙_底图1.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏彩_底图1.png",
}


CardIcon.qualityBaseMapboxIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/绿卡.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/蓝卡.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/紫卡.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/橙卡.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/彩卡.png",
}

CardIcon.qualityBaseMapboxClickIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/蓝卡_1.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/绿卡_1.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/紫卡_1.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/橙卡_1.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/彩卡_1.png",
}
-- 品质优先级配置
CardIcon.qualityPriority = {
    ["UR"] = 5,
    ["SSR"] = 4,
    ["SR"] = 3,
    ["R"] = 2,
    ["N"] = 1
}

-- 品质列表配置
CardIcon.qualityList = {"UR", "SSR", "SR", "R", "N", "ALL"}

-- 品质映射配置
CardIcon.qualityListMap = {
    ["品质_5"] = "N",
    ["品质_4"] = "R",
    ["品质_3"] = "SR",
    ["品质_2"] = "SSR",
    ["品质_1"] = "UR",
    ["品质_6"] = "ALL"
}

return CardIcon
