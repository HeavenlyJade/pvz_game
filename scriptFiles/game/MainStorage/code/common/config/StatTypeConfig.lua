local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg

-- StatType 类
---@class StatType
local StatType = ClassMgr.Class("StatType")
function StatType:OnInit(data)
    self.statName = data["属性名"]
    self.displayName = data["显示名"]
    self.isPercentage = data["以百分数结尾"]
    self.powerRate = data["战力倍率"]
    self.priority = data["优先级"]
    self.baseValue = data["玩家基础值"]
    self.valuePerLevel = data["玩家每级成长"] or 0
    self.icon = data["图标"]
end

function StatType:ToString()
    return self.statName
end


--- 属性类型配置文件
---@class StatTypeConfig
local StatTypeConfig = {}
local loaded = false

local function LoadConfig()
    StatTypeConfig.config = {
        ["生命"] = StatType.New({
            ["属性名"] = "生命",
            ["显示名"] = "生命",
            ["以百分数结尾"] = false,
            ["战力倍率"] = 1.0,
            ["优先级"] = 1,
            ["玩家基础值"] = 100,
            ["玩家每级成长"] = 5,
            ["图标"] = "icon_hp"
        }),
        ["攻击"] = StatType.New({
            ["属性名"] = "攻击",
            ["显示名"] = "攻击",
            ["以百分数结尾"] = false,
            ["战力倍率"] = 1.2,
            ["优先级"] = 3,
            ["玩家基础值"] = 10,
            ["玩家每级成长"] = 3,
            ["图标"] = "icon_atk"
        }),
        ["防御"] = StatType.New({
            ["属性名"] = "防御",
            ["显示名"] = "防御",
            ["以百分数结尾"] = false,
            ["战力倍率"] = 1.0,
            ["优先级"] = 4,
            ["玩家基础值"] = 5,
            ["图标"] = "icon_def"
        }),
        ["暴击率"] = StatType.New({
            ["属性名"] = "暴击率",
            ["显示名"] = "暴击率",
            ["以百分数结尾"] = true,
            ["战力倍率"] = 1.5,
            ["优先级"] = 5,
            ["玩家基础值"] = 5,
            ["图标"] = "icon_crit"
        }),
        ["暴击伤害"] = StatType.New({
            ["属性名"] = "暴击伤害",
            ["显示名"] = "暴击伤害",
            ["以百分数结尾"] = true,
            ["战力倍率"] = 1.3,
            ["优先级"] = 6,
            ["玩家基础值"] = 150,
            ["图标"] = "icon_crit_dmg"
        }),
        ["速度"] = StatType.New({
            ["属性名"] = "速度",
            ["显示名"] = "速度",
            ["以百分数结尾"] = false,
            ["战力倍率"] = 0.5,
            ["优先级"] = 7,
            ["玩家基础值"] = 400,
            ["图标"] = "icon_speed"
        }),
        ["冷却缩减"] = StatType.New({
            ["属性名"] = "冷却缩减",
            ["显示名"] = "冷却缩减",
            ["以百分数结尾"] = true,
            ["战力倍率"] = 1.2,
            ["优先级"] = 8,
            ["玩家基础值"] = 0,
            ["图标"] = "icon_cdr"
        })
    }loaded = true
    
    -- 创建按优先级排序的属性列表
    local statArray = {}
    for statName, statType in pairs(StatTypeConfig.config) do
        table.insert(statArray, {
            name = statName,
            priority = statType.priority
        })
    end
    
    -- 按优先级排序
    table.sort(statArray, function(a, b)
        return a.priority < b.priority
    end)
    
    -- 提取排序后的属性名列表
    StatTypeConfig.sortedStatList = {}
    for _, stat in ipairs(statArray) do
        table.insert(StatTypeConfig.sortedStatList, stat.name)
    end
    
    loaded = true
end

---@param statType string
---@return StatType
function StatTypeConfig.Get(statType)
    if not loaded then
        LoadConfig()
    end
    return StatTypeConfig.config[statType]
end

---@return table<string, StatType>
function StatTypeConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return StatTypeConfig.config
end

---@return string[]
function StatTypeConfig.GetSortedStatList()
    if not loaded then
        LoadConfig()
    end
    return StatTypeConfig.sortedStatList
end

return StatTypeConfig
