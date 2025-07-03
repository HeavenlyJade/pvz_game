local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg

local ClassMgr = require(MainStorage.code.common.ClassMgr)    ---@type ClassMgr


---@class ItemRank:Class
---@field name string 品级名称
---@field color ColorQuad 品级颜色
---@field priority number 品级优先级
---@field New fun( data:table ):ItemRank
local ItemRank= ClassMgr.Class("ItemRank")

function ItemRank:OnInit(data)
    self.name = data["名字"]
    self.color = ColorQuad.New(data["颜色"])
    self.priority = data["优先级"] ---@type number
    self.normalImgFrame = data["物品框_默认图"]
    self.hoverImgFrame = data["物品框_悬浮图"]
    self.normalImgBg = data["物品框_默认底图"]
    self.hoverImgBg = data["物品框_悬浮底图"]
end

function ItemRank:GetToStringParams()
    return {
        name = self.name, img = self.normalImgBg
    }
end

--- 物品品级配置文件
---@class ItemRankConfig
---@field Get fun(itemRank: string):ItemRank 获取品级
---@field GetAll fun():ItemRank[] 获取所有品级

local ItemRankConfig = {}
local loaded = false

function LoadConfig()
    ItemRankConfig.config ={
    ["传说"] = ItemRank.New({
        ["名字"] = "传说",
        ["颜色"] = {
            0.9245283,
            0.755436957,
            0.318351716,
            0.7607843
        },
        ["优先级"] = 5,
        ["物品框_默认图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏橙.png",
        ["物品框_悬浮图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏橙_1.png",
        ["物品框_默认底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏橙_底图.png",
        ["物品框_悬浮底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏橙_底图1.png"
    }),
    ["史诗"] = ItemRank.New({
        ["名字"] = "史诗",
        ["颜色"] = {
            0.7735849,
            0.3539516,
            0.7672324,
            0.7607843
        },
        ["优先级"] = 4,
        ["物品框_默认图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏紫.png",
        ["物品框_悬浮图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏紫_1.png",
        ["物品框_默认底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏紫_底图.png",
        ["物品框_悬浮底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏紫_底图1.png"
    }),
    ["彩虹"] = ItemRank.New({
        ["名字"] = "彩虹",
        ["颜色"] = {
            0.9245283,
            0.440459251,
            0.677443862,
            0.7607843
        },
        ["优先级"] = 6,
        ["物品框_默认图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏彩.png",
        ["物品框_悬浮图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏彩_1.png",
        ["物品框_默认底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏彩_底图.png",
        ["物品框_悬浮底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏彩_底图1.png"
    }),
    ["普通"] = ItemRank.New({
        ["名字"] = "普通",
        ["颜色"] = {
            0.6037736,
            0.6037736,
            0.6037736,
            0.7607843
        },
        ["优先级"] = 1,
        ["物品框_默认图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏白.png",
        ["物品框_悬浮图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏白_1.png",
        ["物品框_默认底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏白_底图.png",
        ["物品框_悬浮底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏白_底图1.png"
    }),
    ["稀有"] = ItemRank.New({
        ["名字"] = "稀有",
        ["颜色"] = {
            0.6621966,
            0.933333337,
            0.364705831,
            0.7607843
        },
        ["优先级"] = 2,
        ["物品框_默认图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏绿.png",
        ["物品框_悬浮图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏绿_1.png",
        ["物品框_默认底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏绿_底图.png",
        ["物品框_悬浮底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏绿_底图1"
    }),
    ["精良"] = ItemRank.New({
        ["名字"] = "精良",
        ["颜色"] = {
            0.340423644,
            0.727606237,
            0.9622642,
            0.7607843
        },
        ["优先级"] = 3,
        ["物品框_默认图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏蓝.png",
        ["物品框_悬浮图"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏蓝_1.png",
        ["物品框_默认底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏蓝_底图.png",
        ["物品框_悬浮底图"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏蓝_底图1.png"
    })
}loaded = true
end

---@param itemRank string
---@return ItemRank
function ItemRankConfig.Get(itemRank)
    if not loaded then
        LoadConfig()
    end
    return ItemRankConfig.config[itemRank]
end

---@return ItemType[]
function ItemRankConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return ItemRankConfig.config
end
return ItemRankConfig
