local MainStorage = game:GetService('MainStorage')
local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule
local EquipingTag     = require(MainStorage.code.common.config_type.tags.EquipingTag)    ---@type EquipingTag

local tagHandlers = {
    DamageTagHandler = require(MainStorage.code.common.config_type.tags.DamageTagHandler),
    AttributeTagHandler = require(MainStorage.code.common.config_type.tags.AttributeTagHandler),
    -- SpellTagHandler = require(MainStorage.code.common.config_type.tags.SpellTagHandler),
}

-- 词条类型定义
---@class TagType
---@field New fun( data:table ):TagType
local TagType = CommonModule.Class("TagType")
function TagType:OnInit(data)
    self.data = data
    self.id = data["名字"]
    self.maxLevel = data["最高等级"]
    self.description = data["描述"]
    self.functions = {}
    for _, tagHandler in ipairs(data["功能"]) do
        local tagHandlerClass = tagHandlers[tagHandler["类型"]]
        table.insert(self.functions, tagHandlerClass.New(tagHandler))
    end
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