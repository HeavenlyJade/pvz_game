local MainStorage = game:GetService('MainStorage')
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule


---@class TagHandler:Class
local TagHandler = CommonModule.Class("TagHandler")
function TagHandler:OnInit( data )
    self.printMessage = data["打印信息"] ---@type boolean
    self.m_tagType = data["m_tagType"] ---@type TagType
    self.m_tagIndex = data["m_tagIndex"] ---@type number
    self.m_trigger = data["m_trigger"] ---@type string
    self.priority = data["优先级"] ---@type number
    self.coolDown = data["冷却"] ---@type number
    self.power = data["每级增强"] ---@type number
    self.chance = data["几率"] ---@type number
    self.selfCondition = data["自身条件"] ---@type Modifiers
    self.targetCondition = data["目标条件"] ---@type Modifiers
end


function TagHandler:CanTriggerReal(caster, target, castParam, param, log)
    return true
end

function TagHandler:CanTrigger(caster, target, param, log)
    if self.chance > 0 and math.random() > (self.chance / 100.0) then
        if self.printMessage then 
            table.insert(log, string.format("%s.%s触发失败：几率检定失败 设定=%d%%", self.m_tagType.id, self.m_tagIndex, self.chance))
        end
        return false
    end
    
    if param.skipTags and param.skipTags[self.m_tagType.id] then
        if self.printMessage then 
            table.insert(log, string.format("%s.%s已触发过", self.m_tagType.id, self.m_tagIndex))
        end
        return false
    end
    
    if self.coolDown > 0 and caster:IsCoolingdown(self.m_tagType.id .. "." .. self.m_tagIndex) then
        if self.printMessage then 
            table.insert(log, string.format("%s.%s触发失败：冷却中 冷却时间=%d秒", self.m_tagType.id, self.m_tagIndex, self.coolDown))
        end
        return false
    end
    
    if #self.selfCondition.modifiers > 0 then
        for i, item in ipairs(self.selfCondition.modifiers) do
            local stop = item:Check(caster, caster, param)
            if stop then break end
            if param.cancelled then
                if self.printMessage then 
                    table.insert(log, string.format("%s.%s触发失败：第%d个自身条件不满足 条件=%s", self.m_tagType.id, self.m_tagIndex, i+1, item.condition.condition))
                end
                break
            end
        end
    end
    
    if param.cancelled then
        if self.printMessage then 
            table.insert(log, string.format("%s.%s触发失败：自身条件检查后被取消",                 self.m_tagType.id, self.m_tagIndex))
        end
        return false
    end
    
    if #self.targetCondition.modifiers > 0 then
        for i, item in ipairs(self.targetCondition.modifiers) do
            local stop = item:Check(caster, target, param)
            if stop then break end
            if param.cancelled then
                table.insert(log, string.format("%s.%s触发失败：第%d个目标条件不满足 条件=%s", self.m_tagType.id, self.m_tagIndex, i+1, item.condition.condition))
                break
            end
        end
    end
    
    if param.cancelled then
        return false
    end
    
    return true
end

function TagHandler:Trigger(caster, target, tag, param)
    local log = {}
    local result = self:TriggerIn(caster, target, tag, param, log)
    if self.printMessage and #log > 0 then
        print(table.concat(log, "\n"))
    end
    return result
end

function TagHandler:TriggerIn(caster, target, tag, param, log)
    local castParam = {
        skipTags = {},
        power = 1.0,
        cancelled = false
    }
    
    if #param > 1 and param[2].skipTags then
        local prevCastParam = param[2] ---@type CastParam
        if prevCastParam.skipTags[self.m_tagType.id] then
            return false
        end
    end
    
    if not self:CanTriggerReal(caster, target, castParam, param, log) then
        return false
    end
    
    if not self:CanTrigger(caster, target, castParam, log) then
        return false
    end
    
    table.insert(castParam.skipTags, self.m_tagType.id)
    castParam.power = castParam.power * (1 + (tag.level - 1) * self.power)
    
    if self.coolDown > 0 then
        caster:SetCooldown(self.m_tagType.id .. "." .. self.m_tagIndex, self.coolDown)
    end
    
    if not self:TriggerReal(caster, target, castParam, param, log) then
        if self.printMessage then
            table.insert(log, "触发失败：实际效果未能生效")
        end
        return false
    end
    
    if self.printMessage then
        table.insert(log, string.format("%s.%s触发成功：等级=%.1f 威力=%.2f", self.m_tagType.id, self.m_tagIndex, tag.level, castParam.power))
    end
    
    return true
end

function TagHandler:TriggerReal(caster, target, castParam, param, log)
    return true
end

return TagHandler