--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig) ---@type MobTypeConfig
local StatTypeConfig = require(MainStorage.code.common.config.StatTypeConfig) ---@type StatTypeConfig


---@class StatCommand
local StatCommand = {}

---@param player Player
function StatCommand.showStat(params, player)
    local showDetails = params["显示详细构成"] or false

    local statText = string.format([[
玩家属性:
等级: %d
经验: %d
生命: %d/%d
]],
        player.level,
        player.exp,
        player.health,
        player.maxHealth
    )

    -- 使用排序后的属性列表显示属性
    local sortedStats = StatTypeConfig.GetSortedStatList()
    for _, statName in ipairs(sortedStats) do
        -- 跳过生命值，因为已经显示过了
        if statName ~= "生命" or showDetails then
            local statType = StatTypeConfig.Get(statName)
            local value = player:GetStat(statName)
            if value > 0 then
                if statType.isPercentage then
                    statText = statText .. string.format("%s: %.1f%%\n", statType.displayName, value)
                else
                    statText = statText .. string.format("%s: %d\n", statType.displayName, value)
                end

                -- 如果需要显示详细构成
                if showDetails then
                    statText = statText .. "  来源明细:\n"
                    for source, statMap in pairs(player.stats) do
                        if statMap[statName] and statMap[statName] > 0 then
                            if statType.isPercentage then
                                statText = statText .. string.format("    %s: %.1f%%\n", source, statMap[statName])
                            else
                                statText = statText .. string.format("    %s: %d\n", source, statMap[statName])
                            end
                        end
                    end
                end
            end
        end
    end

    -- 如果需要显示词条分类
    if showDetails then
        statText = statText .. "\n词条分类:\n"
        local triggerGroups = {}
        
        -- 按触发类型分组词条
        for triggerType, handlers in pairs(player.tagHandlers) do
            if not triggerGroups[triggerType] then
                triggerGroups[triggerType] = {}
            end
            for _, equipingTag in ipairs(handlers) do
                table.insert(triggerGroups[triggerType], equipingTag)
            end
        end

        -- 按触发类型显示词条
        for triggerType, tags in pairs(triggerGroups) do
            statText = statText .. string.format("\n[%s]触发:\n", triggerType)
            for _, tag in ipairs(tags) do
                statText = statText .. string.format("  %s (等级:%d)\n", tag.id, tag.level or 1)
            end
        end
    end

    print(statText)
    return true
end

return StatCommand
