
local MainStorage = game:GetService('MainStorage')
local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule

---@class Modifier
local _M = CommonModule.Class("Modifier")

function _M:OnInit(data)
    -- 处理条件
    if data["条件"] then
        local conditionType = data["条件类型"] or "Variable"
        local conditionClass = CommonModule.GetRegisterClass(conditionType)
        if conditionClass then
            self.condition = conditionClass.New(data["条件"])
        end
    end
    
    -- 设置其他属性
    self.invert = data["反转"] or false
    self.action = data["动作"] or "必须"
    self.amount = data["数量"] or nil
    self.subSpell = data["魔法"] or nil
    self.overrideParams = data["复写参数"] or {}
    self.modifyValues = data["修改数值"] or {}
end

function _M:Check(caster, target, param)
    local success = true
    if self.condition ~= nil then
        success = self.condition:Check(self, caster, target)
    end
    local stop = false
    if self.invert then success = not success end
    
    if self.action == "必须" then
        if not success then param.cancelled = true end
    elseif self.action == "拒绝" then
        if success then param.cancelled = true end
    elseif self.action == "停止" then
        if success then stop = true end
    elseif self.action == "继续" then
        if not success then stop = true end
    elseif self.action == "增加威力" then
        if success then param.power = param.power + tonumber(self.amount) end
    elseif self.action == "乘以威力" then
        if success then param.power = param.power * tonumber(self.amount) end
    elseif self.action == "释放" then
        if success and self.subSpell ~= nil then
            self.subSpell:Cast(caster, target, param)
        end
    elseif self.action == "改为释放" then
        if success and self.subSpell ~= nil then
            self.subSpell:Cast(caster, target, param)
            param.cancelled = true
        end
    end
    return stop
end

return _M