local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifier      = require(MainStorage.code.common.config_type.modifier.Modifier)    ---@type Modifier
local CommonModule = require(MainStorage.code.common.CommonModule)    ---@type CommonModule


---@class ItemRank:Class
---@field name string 品级名称
---@field color ColorQuad 品级颜色
---@field priority number 品级优先级
---@field New fun( data:table ):ItemRank
local ItemRank= CommonModule.Class("ItemRank")

function ItemRank:onInit(data)
    self.name = data["名字"]
    self.color = ColorQuad.New(data["颜色"])
    self.priority = data["优先级"] ---@type number
end

--- 物品品级配置文件
---@class ItemRankConfig
---@field Get fun(itemRank: string):ItemRank 获取品级
---@field GetAll fun():ItemRank[] 获取所有品级

--默认数值模板
local ItemRankConfig = { config = {
    ["传说"] = ItemRank.New({
        ["名字"] = "传说",
        ["颜色"] = {
            0.9339623,
            0.7265788,
            0.18943575,
            0.7607843
        },
        ["优先级"] = 5
    }),
    ["史诗"] = ItemRank.New({
        ["名字"] = "史诗",
        ["颜色"] = {
            0.7924528,
            0.15325737,
            0.6434369,
            0.7607843
        },
        ["优先级"] = 4
    }),
    ["普通"] = ItemRank.New({
        ["名字"] = "普通",
        ["颜色"] = {
            0.6886792,
            0.6886792,
            0.6886792,
            0.7607843
        },
        ["优先级"] = 1
    }),
    ["稀有"] = ItemRank.New({
        ["名字"] = "稀有",
        ["颜色"] = {
            0.592464566,
            0.9339623,
            0.365655035,
            0.7607843
        },
        ["优先级"] = 2
    }),
    ["精良"] = ItemRank.New({
        ["名字"] = "精良",
        ["颜色"] = {
            0.186231777,
            0.849731743,
            0.8773585,
            0.7607843
        },
        ["优先级"] = 3
    })
}}


---@param itemRank string
---@return ItemRank
function ItemRankConfig.Get(itemRank)
    return ItemRankConfig.config[itemRank]
end

---@return ItemType[]
function ItemRankConfig.GetAll()
    return ItemRankConfig.config
end
return ItemRankConfig
