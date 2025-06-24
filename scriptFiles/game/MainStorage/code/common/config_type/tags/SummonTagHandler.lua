local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local TagHandler = require(MainStorage.code.common.config_type.tags.TagHandler) ---@type TagHandler
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class SummonTag : TagHandler
local SummonTag = ClassMgr.Class("SummonTag", TagHandler)

function SummonTag:OnInit(data)
    -- 条件相关
    self["影响怪物"] = data["影响怪物"] or {} ---@type string[]
    self["影响关键字"] = data["影响关键字"] or "" ---@type string

    -- 修改相关
    self["额外增加属性"] = data["额外增加属性"] ---@type table<string, string>
    self["属性乘以百分比"] = data["属性乘以百分比"] ---@type table<string, string>
    self["额外添加词条"] = data["额外添加词条"] ---@type table
    self["额外属性倍率"] = data["额外属性倍率"] or 1.0 ---@type number
    self["额外词条等级"] = data["额外词条等级"] or 1.0 ---@type number
end

function SummonTag:CanTriggerReal(caster, target, castParam, param, log)
    local monster = param ---@type Monster
    
    if self["影响关键字"] ~= "" then
        if not string.find(monster.mobType.id, self["影响关键字"]) then
            if self.printMessage then 
                table.insert(log, string.format("%s.%s触发失败：怪物ID%s不包含关键字%s", 
                    self.m_tagType.id, self.m_tagIndex, monster.mobType.id, self["影响关键字"]))
            end
            return false
        end
    end
    
    if #self["影响怪物"] > 0 then
        local matchFound = false
        for _, monsterId in ipairs(self["影响怪物"]) do
            if monsterId == monster.mobType.id then
                matchFound = true
                break
            end
        end
        
        if not matchFound then
            local monsterIds = {}
            for _, monsterId in ipairs(self["影响怪物"]) do
                table.insert(monsterIds, monsterId)
            end
            
            if self.printMessage then 
                table.insert(log, string.format("%s.%s触发失败：怪物ID%s不匹配目标怪物%s", 
                    self.m_tagType.id, self.m_tagIndex, monster.mobType.id, table.concat(monsterIds, ", ")))
            end
            return false
        end
    end
    
    return true
end

function SummonTag:TriggerReal(caster, target, castParam, param, log)
    local monster = param[1] ---@type Monster
    
    -- 处理额外增加属性
    if self["额外增加属性"] then
        local mult = self:GetUpgradeValue("额外属性倍率", castParam.power)
        for attr, val in pairs(self["额外增加属性"]) do
            local evaluated = gg.eval(val) * mult
            monster:AddStat(attr, evaluated)
            if self.printMessage then 
                table.insert(log, string.format("%s.%s：增加%s=%.1f", 
                    self.m_tagType.id, self.m_tagIndex, attr, evaluated))
            end
        end
    end
    
    -- 处理属性乘以百分比
    if self["属性乘以百分比"] then
        local mult = self:GetUpgradeValue("额外属性倍率", castParam.power)
        for attr, val in pairs(self["属性乘以百分比"]) do
            local evaluated = gg.eval(val) * mult / 100.0
            local currentValue = monster:GetStat(attr)
            monster:AddStat(attr, currentValue * (1 + evaluated))
            if self.printMessage then 
                table.insert(log, string.format("%s.%s：乘以%s=%.1f", 
                    self.m_tagType.id, self.m_tagIndex, attr, 1+evaluated))
            end
        end
    end
    
    -- 处理额外添加词条
    if self["额外添加词条"] then
        local level = self:GetUpgradeValue("额外词条等级", castParam.power)
        local TagTypeConfig = require(MainStorage.code.common.config.TagTypeConfig) ---@type TagTypeConfig
        for _, tagId in ipairs(self["额外添加词条"]) do
            local tagType = TagTypeConfig.Get(tagId)
            if tagType then
                monster:AddTagHandler(tagType:FactoryEquipingTag("SUMMON-", level))
                if self.printMessage then 
                    table.insert(log, string.format("%s.%s：添加词条%s", 
                        self.m_tagType.id, self.m_tagIndex, tagId))
                end
            end
        end
    end
    
    return true
end

return SummonTag
