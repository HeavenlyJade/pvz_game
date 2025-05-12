local MainStorage = game:GetService('MainStorage')
local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule

-- StatType 类
---@class StatType
local StatType = CommonModule.Class("StatType")
function StatType:OnInit(data)
    self.statName = data["属性名"]
    self.displayName = data["显示名"]
    self.isPercentage = data["以百分数结尾"]
    self.powerRate = data["战力倍率"]
    self.priority = data["优先级"]
    self.baseValue = data["基础值"]
    self.icon = data["图标"]
end

function StatType:ToString()
    return self.statName
end

return StatType