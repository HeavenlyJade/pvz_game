local MainStorage = game:GetService('MainStorage')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr      = require(MainStorage.code.common.ClassMgr)    ---@type ClassMgr
local EquipingTag     = require(MainStorage.code.common.config_type.tags.EquipingTag)    ---@type EquipingTag



-- 词条类型定义
---@class TagType
---@field New fun( data:table ):TagType
local TagType = ClassMgr.Class("TagType")
function TagType:OnInit(data)
    self.data = data
    self.id = data["名字"]
    self.maxLevel = data["最高等级"]
    -- self.description = data["描述"]
    self.description = data["详细属性"]
    self.level2Description = data["各级描述"]
    self.functions = {}
    for _, tagHandler in ipairs(data["功能"]) do
        local tagHandlerClass = require(MainStorage.code.common.config_type.tags[tagHandler["类型"]])
        table.insert(self.functions, tagHandlerClass.New(tagHandler))
    end
end

function TagType:GetDescription(level)
    if self.level2Description and self.level2Description[level] then
        return self.level2Description[level]
    end
    if not self.description or self.description == "" then
        return ""
    end

    local result = self.description

    -- 处理 [数字:每级增加倍率] 格式
    result = string.gsub(result, "%[(%d+):([%d%.]+)%]", function(baseValue, perLevel)
        baseValue = tonumber(baseValue)
        perLevel = tonumber(perLevel)
        local finalValue = baseValue * (1 + (level - 1) * perLevel)
        return string.format("%.1f", finalValue)
    end)

    -- 处理 [词条序号.属性.数组索引] 格式
    result = string.gsub(result, "%[(%d+)%.([^%.]+)%.(%d+)%]", function(index, fieldName, arrayIndex)
        index = tonumber(index)
        arrayIndex = tonumber(arrayIndex) -- Convert to 0-based index
        if index > 0 and index <= #self.functions then
            local handler = self.functions[index]

            -- 处理修改数值
            if fieldName == "修改数值" and handler["修改数值"] and handler["修改数值"][arrayIndex] then
                local modifier = handler["修改数值"][arrayIndex]
                if modifier and modifier.paramValue then
                    local finalRate = modifier.paramValue["倍率"] * handler:GetUpgradeValue("修改数值倍率", level, 1)
                    if modifier.paramValue.attributeType and modifier.paramValue.attributeType.name then
                        return string.format("%.1f", finalRate) .. (modifier.paramValue.attributeType.name or "")
                    else
                        return string.format("%.1f", finalRate)
                    end
                end
            end

            -- 处理属性增伤
            if fieldName == "属性增伤" and handler["属性增伤"] and handler["属性增伤"][arrayIndex] then
                local element = handler["属性增伤"][arrayIndex]
                if element then
                    local finalRate = element.multiplier * handler:GetUpgradeValue("属性增伤倍率", level, 1)
                    if element.statType then
                        return string.format("%d", finalRate*100) .. "%" .. (element.statType or "")
                    else
                        return string.format("%d", finalRate)
                    end
                end
            end
        end
        return ""
    end)

    -- 处理 [词条序号.属性] 格式
    result = string.gsub(result, "%[(%d+)%.([^%]]+)%]", function(index, fieldName)
        index = tonumber(index)
        if index > 0 and index <= #self.functions then
            local handler = self.functions[index]
            local value = handler[fieldName]
            if type(value) == "number" then
                -- 应用升级值增加
                local finalValue = handler:GetUpgradeValue(fieldName, level)
                if fieldName == "威力增加" then
                    finalValue = finalValue * 100
                end
                return string.format("%.0f", finalValue)
            end
            if type(value) == "table" then
                if fieldName == "属性乘以百分比" or fieldName == "额外增加属性" then
                    local mult = handler:GetUpgradeValue("额外属性倍率", level, 1)
                    local result = {}
                    for attr, val in pairs(value) do
                        local evaluated = gg.eval(val) * mult
                        if fieldName == "属性乘以百分比" then
                            -- 修复：避免属性名中的%字符导致format错误
                            table.insert(result, (attr or "") .. ": +" .. string.format("%.1f", evaluated) .. "%")
                        else
                            -- 修复：避免属性名中的%字符导致format错误
                            table.insert(result, (attr or "") .. ": " .. string.format("%.1f", evaluated))
                        end
                    end
                    return table.concat(result, "\n")
                end
            end
            return tostring(value or "")
        end
        return ""
    end)

    return result
end

function TagType:FactoryEquipingTag(prefix, level)
    prefix = prefix or "MISC-"
    level = level or 1.0

    local equipingTag = EquipingTag.New()
    equipingTag.level = level
    equipingTag.id = prefix .. self.id
    equipingTag.tagType = self
    equipingTag.handlers = {}

    for _, tagHandler in ipairs(self.functions) do
        tagHandler.m_tagType = self
        local key = tagHandler.m_trigger
        if not equipingTag.handlers[key] then
            equipingTag.handlers[key] = {}
        end
        table.insert(equipingTag.handlers[key], tagHandler)
    end

    return equipingTag
end

return TagType
