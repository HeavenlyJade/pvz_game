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
    self.displayName = data["显示名"] or self.name
    self.shortName = data["简短名"] or self.displayName:gsub("增加", ""):gsub("延长", ""):gsub("提升", ""):gsub("额外", "")
    self.maxLevel = data["最大等级"] or 1
    self.description = data["技能描述"] or ""
    self.icon = data["技能图标"] or ""
    self.levelUpPlayer = data["提升玩家等级"] or 0
    self.miniIcon = data["技能小角标"] or ""
    self.effectiveWithoutEquip = data["无需装备也可生效"] or false
    ---客户端
    self.isEntrySkill = data["是入口技能"] or false
    self.nextSkills = data["下一技能"]
    self.prerequisite = {} ---@type SkillType[]
    self.targetMode = data["目标模式"]
    self.category = data["技能分类"]
    self.upgradeCosts = data["升级需求素材"]
    self.maxGrowthFormula = data["最大经验"]
    self.oneKeyUpgradeCosts = data["一键强化素材"]
    self.quality = data["技能品级"] or "R"
    self.battleModel = data["更改模型"]
    self.battleAnimator = data["更改动画"]
    self.battleStateMachine = data["更改状态机"]
    self.afkScale = gg.Vec3.new(data["副卡挂机尺寸"]):ToVector3()
    self.freezesMove = data["禁止移动"]

    local is = (data["指示器半径"] or 3) * 2
    self.indicatorScale = Vector3.New(is, is, is)
    self.indicatorRange = data["最大施法距离"] or 3000
    self.isEquipable = data["主动释放魔法"] or nil

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
        if self.activeSpell then
            self.cooldown = self.activeSpell.cooldown
        end
    end

    if data["后坐力"] then
        local recoil = data["后坐力"]
        self.recoil = {
            vertical_recoil = recoil["垂直后坐力"] or 3,
            vertical_recoil_max = recoil["最大垂直后坐力"] or 8,
            vertical_recoil_correct = recoil["垂直后坐力恢复"] or 5,
            horizontal_recoil = recoil["水平后坐力"] or 3,
            horizontal_recoil_max = recoil["最大水平后坐力"] or 6,
            horizontal_recoil_correct = recoil["水平后坐力恢复"] or 2,
            recoil_cooling_time = recoil["后坐力冷却时间"] or 0.5
        }
    end
end

function SkillType:GetMaxGrowthAtLevel(level)
    -- 检查是否存在最大经验公式
    if not self.maxGrowthFormula or self.maxGrowthFormula == "" then
        gg.log("警告: 技能", self.name, "没有设置最大经验公式，使用默认值100")
        return 100  -- 返回默认值
    end
    
    local expr = self.maxGrowthFormula:gsub("LVL", tostring(level))
    if not expr:match("^[%d%+%-%*%/%%%^%(%)(%.)%s]+$") then
        print(string.format("技能%s的成长上限包含非法字符: %s", self.name, expr))
        return 100  -- 返回默认值而不是0
    end

    local result = gg.eval(expr)
    return result or 100  -- 如果计算失败，返回默认值
end

function SkillType:GetOneKeyUpgradeCostsAtLevel(level)
    if not self.oneKeyUpgradeCosts then
        return {}
    end
    local costs = {}
    for resourceType, costExpr in pairs(self.oneKeyUpgradeCosts) do
        local expr = costExpr:gsub("LVL", tostring(level))
        if not expr:match("^[%d%+%-%*%/%%%^%(%).%s]+$") then
            print(string.format("技能%s的一键强化消耗%s包含非法字符: %s", self.name, resourceType, expr))
        else
            local result = gg.eval(expr)
            costs[resourceType] = result
        end
    end
    return costs
end

function SkillType:GetCostAtLevel(level)
    local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
    if not self.upgradeCosts then
        return {}
    end

    local costs = {}
    for resourceType, costExpr in pairs(self.upgradeCosts) do
        local expr = costExpr:gsub("LVL", tostring(level))
        if not expr:match("^[%d%+%-%*%/%%%^%(%)(%.)%s]+$") then
            print(string.format("技能%s的升级消耗%s包含非法字符: %s", self.name, resourceType, expr))
        else
            local result = gg.eval(expr)
            costs[resourceType] = result
        end
    end
    return costs
end

function SkillType:GetToStringParams()
    return {
        name = self.name
    }
end

return SkillType
