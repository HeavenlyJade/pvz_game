--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local MobTypeConfig = require(MainStorage.code.common.config.MobTypeConfig) ---@type MobTypeConfig
local StatTypeConfig = require(MainStorage.code.common.config.StatTypeConfig) ---@type StatTypeConfig


---@class StatCommand
local StatCommand = {}

---@param player Player
function StatCommand.showStat(params, player)
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
        if statName ~= "生命" then
            local statType = StatTypeConfig.Get(statName)
            local value = player:GetStat(statName)
            if value > 0 then
                if statType.isPercentage then
                    statText = statText .. string.format("%s: %.1f%%\n", statType.displayName, value)
                else
                    statText = statText .. string.format("%s: %d\n", statType.displayName, value)
                end
            end
        end
    end

    print(statText)
    return true
end

return StatCommand
