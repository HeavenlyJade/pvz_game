local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr

---@class WeightedRandomSelector
---@field New fun( items:table, weightPredicate:fun(item:any):number ):WeightedRandomSelector
local WeightedRandomSelector = ClassMgr.Class("WeightedRandomSelector")

---@param items table 要选择的项目列表
---@param weightPredicate fun(item:any):number 获取项目权重的函数
function WeightedRandomSelector:OnInit(items, weightPredicate)
    if not items or #items == 0 then
        error("列表不能为空")
    end

    self.weightPredicate = weightPredicate
    self.items = items
    self.totalWeight = 0
    for _, item in ipairs(items) do
        self.totalWeight = self.totalWeight + weightPredicate(item)
    end
end

---根据权重随机选择一个元素
---@return any 选中的元素
function WeightedRandomSelector:Next()
    -- 生成 [0, totalWeight) 之间的随机数
    local r = math.random() * self.totalWeight
    local sum = 0

    for _, item in ipairs(self.items) do
        sum = sum + self.weightPredicate(item)
        if r < sum then
            return item
        end
    end

    -- 理论上不会到达这里，除非权重为 0 或误差
    return nil
end

return WeightedRandomSelector 