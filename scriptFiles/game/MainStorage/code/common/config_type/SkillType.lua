local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local TagTypeConfig = require(MainStorage.code.common.config.TagTypeConfig) ---@type TagTypeConfig
local SpellConfig = require(MainStorage.code.common.config.SpellConfig)  ---@type SpellConfig

---@class SkillType:Class
---@field name string 技能名
---@field maxLevel number 最大等级
---@field description string 技能描述
---@field icon string 技能图标
---@field effectiveWithoutEquip boolean 无需装备也可生效
---@field passiveTags TagType[] 被动词条
---@field activeSpell Spell 主动释放魔法
---@field New fun( data:table ):SkillType
local SkillType = ClassMgr.Class("SkillType")

function SkillType:OnInit(data)
    -- 从配置中读取基础属性
    self.name = data["技能名"] or ""
    self.maxLevel = data["最大等级"] or 1
    self.description = data["技能描述"] or ""
    self.icon = data["技能图标"] or ""
    self.effectiveWithoutEquip = data["无需装备也可生效"] or false

    ---客户端
    self.isEntrySkill = data["是入口技能"] or false
    self.nextSkills = data["下一技能"]
    
    -- 加载被动词条
    self.passiveTags = {}
    if data["被动词条"] then
        for _, tagData in ipairs(data["被动词条"]) do
            local tag = TagTypeConfig.Get(tagData)
            table.insert(self.passiveTags, tag)
        end
    end
    
    self.cooldown = 0
    -- 加载主动释放魔法
    if data["主动释放魔法"] then
        self.activeSpell = SpellConfig.Get(data["主动释放魔法"]) ---@type Spell
        self.cooldown = self.activeSpell.cooldown
    end
end

return SkillType