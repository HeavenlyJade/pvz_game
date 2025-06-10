local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class RoulettePrize
---@field itemType string|nil 物品类型
---@field weight number 权重
---@field itemCountMin number 最小数量
---@field itemCountMax number 最大数量

---@class ItemStack
---@field itemType string 物品类型
---@field amount number 数量

---@class Lottery:Class
---@field poolName string 奖池名称
---@field normalRate number 普通品级概率
---@field rareRate number 稀有品级概率
---@field epicRate number 史诗品级概率
---@field legendaryRate number 传说品级概率
---@field mythicRate number 神话品级概率
---@field rarePity number 稀有保底次数
---@field epicPity number 史诗保底次数
---@field legendaryPity number 传说保底次数
---@field mythicPity number 神话保底次数
---@field normalPrizes RoulettePrize[] 普通品级奖品列表
---@field rarePrizes RoulettePrize[] 稀有品级奖品列表
---@field epicPrizes RoulettePrize[] 史诗品级奖品列表
---@field legendaryPrizes RoulettePrize[] 传说品级奖品列表
---@field mythicPrizes RoulettePrize[] 神话品级奖品列表
local Lottery = ClassMgr.Class("Lottery")

---@param data table
function Lottery:OnInit(data)
    self.poolName = data["奖池名"]
    
    -- 概率设置
    self.normalRate = data["普通品级概率"] or 0
    self.rareRate = data["稀有品级概率"] or 0
    self.epicRate = data["史诗品级概率"] or 0
    self.legendaryRate = data["传说品级概率"] or 0
    self.mythicRate = data["神话品级概率"] or 0
    
    -- 保底设置
    self.rarePity = data["稀有保底次数"] or 0
    self.epicPity = data["史诗保底次数"] or 0
    self.legendaryPity = data["传说保底次数"] or 0
    self.mythicPity = data["神话保底次数"] or 0
    
    -- 奖池内容
    self.normalPrizes = data["普通品级"] or {}
    self.rarePrizes = data["稀有品级"] or {}
    self.epicPrizes = data["史诗品级"] or {}
    self.legendaryPrizes = data["传说品级"] or {}
    self.mythicPrizes = data["神话品级"] or {}
end

---抽奖
---@param count number 抽奖次数
---@param isFree boolean 是否免费
function Lottery:DrawRoulette(count, isFree)
    gg.log("DrawRoulette: " .. self.poolName .. " " .. count .. " " .. tostring(isFree))
    gg.server.Call("shop", "draw", {
        roulette = self.poolName,
        count = count,
        isFree = isFree
    })
end

---执行单次抽奖
---@param player Player 玩家对象
---@return ItemStack|nil 抽中的奖品
function Lottery:Draw(player)
    -- 获取保底计数
    local pityCounts = {
        rare = player:GetVariable("pity_" .. self.poolName .. "_rare"),
        epic = player:GetVariable("pity_" .. self.poolName .. "_epic"),
        legendary = player:GetVariable("pity_" .. self.poolName .. "_legendary"),
        mythic = player:GetVariable("pity_" .. self.poolName .. "_mythic")
    }

    -- 计算当前抽奖的品级
    local rarity = self:CalculateRarity(pityCounts)
    -- 根据品级选择奖励
    local rewards = self:SelectRewards(rarity)
    -- 更新保底计数
    self:UpdatePityCounts(player, rarity, pityCounts)
    
    if rewards then
        gg.log(player.uid .. "抽中了" .. rarity .. "品级，获得了" .. rewards.itemType .. "x" .. rewards.amount)
    end
    
    return rewards
end

---计算抽中的品级
---@param pityCounts table 保底计数
---@return string 品级
function Lottery:CalculateRarity(pityCounts)
    -- 检查保底
    if self.mythicPity > 0 and pityCounts.mythic >= self.mythicPity then return "mythic" end
    if self.legendaryPity > 0 and pityCounts.legendary >= self.legendaryPity then return "legendary" end
    if self.epicPity > 0 and pityCounts.epic >= self.epicPity then return "epic" end
    if self.rarePity > 0 and pityCounts.rare >= self.rarePity then return "rare" end

    -- 计算总权重
    local totalWeight = self.normalRate + self.rareRate + self.epicRate + self.legendaryRate + self.mythicRate

    -- 随机抽取
    local rand = math.random() * totalWeight
    local sum = 0

    -- 按概率从高到低检查
    if (sum + self.mythicRate) > rand then return "mythic" end
    sum = sum + self.mythicRate
    if (sum + self.legendaryRate) > rand then return "legendary" end
    sum = sum + self.legendaryRate
    if (sum + self.epicRate) > rand then return "epic" end
    sum = sum + self.epicRate
    if (sum + self.rareRate) > rand then return "rare" end
    
    return "common"
end

---根据品级选择奖励
---@param rarity string 品级
---@return ItemStack|nil 选中的奖励
function Lottery:SelectRewards(rarity)
    local rewardPool
    
    -- 根据品级选择对应的奖池
    if rarity == "mythic" then
        rewardPool = self.mythicPrizes
    elseif rarity == "legendary" then
        rewardPool = self.legendaryPrizes
    elseif rarity == "epic" then
        rewardPool = self.epicPrizes
    elseif rarity == "rare" then
        rewardPool = self.rarePrizes
    else
        rewardPool = self.normalPrizes
    end

    if not rewardPool or #rewardPool == 0 then
        gg.log("Empty reward pool for rarity: " .. rarity)
        return nil
    end

    -- 计算总权重
    local totalWeight = 0
    for _, reward in ipairs(rewardPool) do
        totalWeight = totalWeight + (reward.weight or 1)
    end
    
    -- 生成随机数
    local random = math.random() * totalWeight
    
    -- 根据权重选择奖品
    local currentWeight = 0
    for _, reward in ipairs(rewardPool) do
        currentWeight = currentWeight + (reward.weight or 1)
        if random <= currentWeight then
            -- 生成随机数量
            local minAmount = reward.itemCountMin or 1
            local maxAmount = reward.itemCountMax or minAmount
            local amount = math.random(minAmount, maxAmount)
            
            if reward.itemType then
                return {
                    itemType = reward.itemType,
                    amount = amount
                }
            end
        end
    end
    
    -- 如果因为浮点数精度问题没有选中任何奖品，返回最后一个奖品
    local lastReward = rewardPool[#rewardPool]
    local minAmount = lastReward.itemCountMin or 1
    local maxAmount = lastReward.itemCountMax or minAmount
    local amount = math.random(minAmount, maxAmount)
    
    if lastReward.itemType then
        return {
            itemType = lastReward.itemType,
            amount = amount
        }
    end
    
    return nil
end

---更新保底计数
---@param player Player 玩家对象
---@param rarity string 抽中的品级
---@param currentCounts table 当前保底计数
function Lottery:UpdatePityCounts(player, rarity, currentCounts)
    -- 重置保底计数
    if rarity == "mythic" then
        player:SetVariable("pity_" .. self.poolName .. "_mythic", 0)
        player:SetVariable("pity_" .. self.poolName .. "_legendary", 0)
        player:SetVariable("pity_" .. self.poolName .. "_epic", 0)
        player:SetVariable("pity_" .. self.poolName .. "_rare", 0)
    elseif rarity == "legendary" then
        player:SetVariable("pity_" .. self.poolName .. "_legendary", 0)
        player:SetVariable("pity_" .. self.poolName .. "_epic", 0)
        player:SetVariable("pity_" .. self.poolName .. "_rare", 0)
    elseif rarity == "epic" then
        player:SetVariable("pity_" .. self.poolName .. "_epic", 0)
        player:SetVariable("pity_" .. self.poolName .. "_rare", 0)
    elseif rarity == "rare" then
        player:SetVariable("pity_" .. self.poolName .. "_rare", 0)
    end

    -- 增加保底计数
    if rarity == "common" then
        player:SetVariable("pity_" .. self.poolName .. "_rare", currentCounts.rare + 1)
        player:SetVariable("pity_" .. self.poolName .. "_epic", currentCounts.epic + 1)
        player:SetVariable("pity_" .. self.poolName .. "_legendary", currentCounts.legendary + 1)
        player:SetVariable("pity_" .. self.poolName .. "_mythic", currentCounts.mythic + 1)
    end
end

return Lottery
