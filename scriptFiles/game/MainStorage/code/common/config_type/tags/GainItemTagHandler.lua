local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local TagHandler = require(MainStorage.code.common.config_type.tags.TagHandler) ---@type TagHandler

---@class GainItemTagHandler : TagHandler
local GainItemTagHandler = ClassMgr.Class("GainItemTagHandler", TagHandler)

function GainItemTagHandler:OnInit(data)
    self["渠道"] = data["渠道"] ---@type string[]|nil
    self["影响物品"] = data["影响物品"] or {} ---@type string[]
    self["影响关键字"] = data["影响关键字"] or "" ---@type string
    self["取消获得"] = data["取消获得"] or false ---@type boolean
    self["数量增加百分比"] = data["数量增加百分比"] or 0 ---@type number
    self["数量增加百分比表达式"] = data["数量增加百分比表达式"] or "" ---@type string
    self["额外数量倍率"] = data["额外数量倍率"] or 1 ---@type number
    self["释放魔法"] = data["释放魔法"] or nil ---@type SubSpell[]
    self["释放魔法继承威力"] = data["释放魔法继承威力"] or false ---@type boolean
end

function GainItemTagHandler:CanTriggerReal(caster, target, castParam, param, log)
    local item = param[1] ---@type Item
    local source = param[2]
    local amount = param.power
    if self["渠道"] and #self["渠道"] > 0 then
        local found = false
        for _, keyword in ipairs(self["渠道"]) do
            if source and string.find(source, keyword, 1, true) then
                found = true
                break
            end
        end
        if not found then
            if self.printMessage then
                table.insert(log, string.format("%s.%s触发失败：source(%s)不包含渠道关键词(%s)",
                    self.m_tagType.id, self.m_tagIndex, tostring(source), table.concat(self["渠道"], ", ")))
            end
            return false
        end
    end

    if self["影响关键字"] ~= "" then
        if not string.find(item.name, self["影响关键字"]) then
            if self.printMessage then 
                table.insert(log, string.format("%s.%s触发失败：怪物ID%s不包含关键字%s", 
                    self.m_tagType.id, self.m_tagIndex, item.name, self["影响关键字"]))
            end
            return false
        end
    end
    
    if #self["影响物品"] > 0 then
        local matchFound = false
        for _, monsterId in ipairs(self["影响物品"]) do
            if monsterId == item.name then
                matchFound = true
                break
            end
        end
        
        if not matchFound then
            local monsterIds = {}
            for _, monsterId in ipairs(self["影响物品"]) do
                table.insert(monsterIds, monsterId)
            end
            
            if self.printMessage then 
                table.insert(log, string.format("%s.%s触发失败：物品ID%s不匹配目标物品%s", 
                    self.m_tagType.id, self.m_tagIndex, item.name, table.concat(monsterIds, ", ")))
            end
            return false
        end
    end
    
    return true
end

function GainItemTagHandler:TriggerReal(caster, target, castParam, param, log)
    local amount = castParam.power
    -- 处理取消获得
    if self["取消获得"] then
        castParam.cancelled = true
        if self.printMessage then
            table.insert(log, string.format("%s.%s：取消获得物品", self.m_tagType.id, self.m_tagIndex))
        end
        return false
    end

    -- 处理数量增加百分比
    if self["数量增加百分比"] and self["数量增加百分比"] ~= 0 then
        amount = amount * (1 + self["数量增加百分比"] / 100)
        if self.printMessage then
            table.insert(log, string.format("%s.%s：数量增加百分比=%.1f%%", self.m_tagType.id, self.m_tagIndex, self["数量增加百分比"]))
        end
    end
    -- 处理数量增加百分比表达式
    if self["数量增加百分比表达式"] and self["数量增加百分比表达式"] ~= "" then
        local gg = require(MainStorage.code.common.MGlobal)
        local exprValue = gg.eval(self["数量增加百分比表达式"])
        amount = amount * (1 + exprValue / 100)
        if self.printMessage then
            table.insert(log, string.format("%s.%s：数量增加百分比表达式=%.1f%%", self.m_tagType.id, self.m_tagIndex, exprValue))
        end
    end
    -- 处理额外数量倍率
    if self["额外数量倍率"] and self["额外数量倍率"] ~= 1 then
        amount = amount * self["额外数量倍率"]
        if self.printMessage then
            table.insert(log, string.format("%s.%s：额外数量倍率=%.2f", self.m_tagType.id, self.m_tagIndex, self["额外数量倍率"]))
        end
    end
    -- 最终数量向下取整
    amount = math.floor(amount)
    castParam.power = amount
    if self.printMessage then
        table.insert(log, string.format("%s.%s：最终获得数量=%.0f", self.m_tagType.id, self.m_tagIndex, amount))
    end

    -- 处理释放魔法
    if self["释放魔法"] and #self["释放魔法"] > 0 then
        local SubSpell = require(MainStorage.code.server.spells.SubSpell)
        local subParam = require(MainStorage.code.server.spells.CastParam).New({
            skipTags = {self.m_tagType.id},
            power = 1.0
        })
        if self["释放魔法继承威力"] then
            subParam.power = amount
        end
        for _, subSpell in ipairs(self["释放魔法"]) do
            if type(subSpell) == "table" and subSpell.Cast == nil then
                -- 兼容配置为table的情况
                subSpell = SubSpell.New(subSpell, self.m_tagType)
            end
            subSpell:Cast(caster, target, subParam)
            if self.printMessage then
                table.insert(log, string.format("%s.%s：释放子魔法%s", self.m_tagType.id, self.m_tagIndex, subSpell.spellName or "?"))
            end
        end
    end
    return true
end
return GainItemTagHandler