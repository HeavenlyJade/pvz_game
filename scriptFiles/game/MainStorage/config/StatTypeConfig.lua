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
    self.valuePerLevel = data["玩家每级成长"]
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
    StatTypeConfig.config ={
    ["仇恨"] = StatType.New({
        ["属性名"] = "仇恨",
        ["显示名"] = "仇恨",
        ["以百分数结尾"] = false,
        ["战力倍率"] = 1,
        ["优先级"] = 1,
        ["玩家基础值"] = 0,
        ["玩家每级成长"] = "0",
        ["图标"] = "fight_active"
    }),
    ["攻击"] = StatType.New({
        ["属性名"] = "攻击",
        ["显示名"] = "攻击",
        ["以百分数结尾"] = false,
        ["战力倍率"] = 1,
        ["优先级"] = 1,
        ["玩家基础值"] = 10,
        ["玩家每级成长"] = "(100+LVL*30+max(0,(LVL-5000)*30)+max(0,(LVL-12000)*60)+max(0,(LVL-16000)*80)+max(0,(LVL-24000)*150)+max(0,(LVL-30000)*300)+max(0,(LVL-35000)*500))/4.5",
        ["图标"] = "fight_active"
    }),
    ["暴伤"] = StatType.New({
        ["属性名"] = "暴伤",
        ["显示名"] = "暴伤",
        ["以百分数结尾"] = true,
        ["战力倍率"] = 0,
        ["优先级"] = 3,
        ["玩家基础值"] = 0,
        ["玩家每级成长"] = nil,
        ["图标"] = nil
    }),
    ["暴率"] = StatType.New({
        ["属性名"] = "暴率",
        ["显示名"] = "暴率",
        ["以百分数结尾"] = true,
        ["战力倍率"] = 0,
        ["优先级"] = 4,
        ["玩家基础值"] = 0,
        ["玩家每级成长"] = nil,
        ["图标"] = nil
    }),
    ["生命"] = StatType.New({
        ["属性名"] = "生命",
        ["显示名"] = "生命",
        ["以百分数结尾"] = false,
        ["战力倍率"] = 0.05,
        ["优先级"] = 0,
        ["玩家基础值"] = 50,
        ["玩家每级成长"] = "(100+LVL*30+max(0,(LVL-5000)*30)+max(0,(LVL-12000)*60)+max(0,(LVL-16000)*80)+max(0,(LVL-24000)*150)+max(0,(LVL-30000)*300)+max(0,(LVL-35000)*500))",
        ["图标"] = "zijin"
    }),
    ["速度"] = StatType.New({
        ["属性名"] = "速度",
        ["显示名"] = "速度",
        ["以百分数结尾"] = false,
        ["战力倍率"] = 0,
        ["优先级"] = 5,
        ["玩家基础值"] = 400,
        ["图标"] = nil
    }),
    ["防御"] = StatType.New({
        ["属性名"] = "防御",
        ["显示名"] = "防御",
        ["以百分数结尾"] = false,
        ["战力倍率"] = 0.8,
        ["优先级"] = 2,
        ["玩家基础值"] = 0,
        ["玩家每级成长"] = nil,
        ["图标"] = "fight_deactive"
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
