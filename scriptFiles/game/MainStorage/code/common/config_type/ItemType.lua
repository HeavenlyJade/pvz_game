local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg

-- ItemType class
---@class ItemType:Class
---@field data table<string, any> 原始配置数据
---@field name string 物品名称
---@field description string 物品描述
---@field icon string 物品图标
---@field quality ItemRank 物品品质
---@field extraPower number 额外战力
---@field enhanceRate number 强化倍率
---@field enhanceMaterials table<string, number> 强化素材，key为素材ID，value为数量
---@field enhanceMaterialRate number 强化材料增加倍率
---@field maxEnhanceLevel number 最大强化等级
---@field attributes table<string, number> 属性，key为属性ID，value为属性值
---@field tags table<string, boolean> 标签，key为标签ID，value为是否拥有
---@field collectionReward string 图鉴完成奖励ID
---@field collectionRewardAmount number 图鉴完成奖励数量
---@field collectionAdvancedRewardAmount number 图鉴高级完成奖励数量
---@field equipmentSlot number 装备格子ID
---@field evolveTo string 可进阶为的物品ID
---@field evolveMaterials table<string, number> 进阶材料，key为材料ID，value为数量
---@field modifiers table<string, number> 获得词条，key为词条ID，value为词条值
---@field sellableTo string 可售出为的物品ID
---@field sellPrice number 售出价格
---@field New fun( data:table ):ItemType
local ItemType = ClassMgr.Class("ItemType")

function ItemType:OnInit(data)
    self.name = data["名字"] or ""
    self.description = data["描述"] or ""
    self.detail = data["详细属性"] or ""
    self.icon = data["图标"]
    self.rank = ItemRankConfig.Get(data["品级"] or "普通")
    self.extraPower = data["额外战力"] or 0
    
    -- 强化
    self.enhanceRate = data["强化倍率"] or 0
    self.enhanceMaterials = data["强化素材"] or {}
    self.enhanceMaterialRate = data["强化材料增加倍率"] or 0
    self.maxEnhanceLevel = data["最大强化等级"] or 0
    
    -- Attributes
    self.attributes = data["属性"] or {}
    
    -- 使用
    self.canAutoUse = data["可自动使用"] or true
    self.useCommands = data["使用指令"]
    self.useCooldown = data["使用冷却"] or -1
    self.useConsume = data["使用消耗"] or 1
    -- 词条ID
    self.tags = data["标签"] or {}
    
    -- Collection rewards
    self.collectionReward = data["图鉴完成奖励"]
    self.collectionRewardAmount = data["图鉴完成奖励数量"] or 0
    self.collectionAdvancedRewardAmount = data["图鉴高级完成奖励数量"] or 0
    
    -- Equipment slot
    self.equipmentSlot = data["装备格子"] or -1
    
    -- Evolution properties
    self.evolveTo = data["可进阶为"]
    self.evolveMaterials = data["进阶材料"] or {}
    
    -- 词条
    self.boundTags = data["获得词条"] or {}
    -- 售出
    self.sellableTo = data["可售出为"]
    self.sellPrice = data["售出价格"] or 0
    self.gainSound = data["获得音效"]
    -- 货币
    self.showInBag = data["在背包里显示"] or true
    self.isMoney = data["是货币"]
    self.moneyIndex = data["货币序号"] or -1
    if self.isMoney then
        local Bag = require(MainStorage.code.server.bag.Bag) ---@type Bag
        Bag.MoneyType[self.moneyIndex] = self
    end
end

function ItemType:GetToStringParams()
    return {
        name = self.name
    }
end

function ItemType:ToItem(count)
    local Item = require(MainStorage.code.server.bag.Item) ---@type Item
    local item = Item.New()
    item:Load({
        uuid = gg.create_uuid('item'),
        itype = self,
        amount = count,
        el = 0,
        quality = ""
    })
    return item
end

return ItemType