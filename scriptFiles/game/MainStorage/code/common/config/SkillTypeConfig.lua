local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local SkillType      = require(MainStorage.code.common.config_type.SkillType)    ---@type SkillType

--- 技能配置文件
---@class SkillTypeConfig
local SkillTypeConfig = {}
local entrySkills = {} ---@type SkillType[]
local loaded = false

local function LoadConfig()
    SkillTypeConfig.config ={
    ["射速1_豌豆"] = SkillType.New({
        ["技能名"] = "射速1_豌豆",
        ["显示名"] = "射速提升",
        ["最大等级"] = 3,
        ["技能描述"] = "所有豌豆射手射速+20%",
        ["是入口技能"] = false,
        ["无需装备也可生效"] = false,
        ["被动词条"] = {
            "射速1_词条_豌豆射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["攻击1_豌豆"] = SkillType.New({
        ["技能名"] = "攻击1_豌豆",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 3,
        ["技能描述"] = "[被动词条.1]",
        ["是入口技能"] = false,
        ["无需装备也可生效"] = false,
        ["被动词条"] = {
            "攻击1_词条_豌豆射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["生命1_豌豆"] = SkillType.New({
        ["技能名"] = "生命1_豌豆",
        ["显示名"] = "攻击提升",
        ["最大等级"] = 3,
        ["技能描述"] = "[被动词条.1]",
        ["是入口技能"] = false,
        ["无需装备也可生效"] = false,
        ["被动词条"] = {
            "生命1_词条_豌豆射手"
        },
        ["目标模式"] = "敌人",
        ["启用后坐力"] = false
    }),
    ["豌豆射手"] = SkillType.New({
        ["技能名"] = "豌豆射手",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆射手可谓你的第一道防线，他们朝来犯的僵尸射击豌豆。",
        ["是入口技能"] = true,
        ["下一技能"] = {
            "射速1_豌豆",
            "攻击1_豌豆"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "豌豆射手",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 3,
            ["最大垂直后坐力"] = 8,
            ["垂直后坐力恢复"] = 5,
            ["水平后坐力"] = 3,
            ["最大水平后坐力"] = 6,
            ["水平后坐力恢复"] = 2,
            ["后坐力冷却时间"] = 0.5
        }
    })
}

loaded = true

--将SkillType的"下一技能"转换为SkillType
for _, skillType in pairs(SkillTypeConfig.config) do
    -- 收集入口技能
    if skillType.isEntrySkill then
        table.insert(entrySkills, skillType)
    end
    
    if skillType.nextSkills then
        local nextSkills = {}
        for _, skillName in ipairs(skillType.nextSkills) do
            local nextSkill = SkillTypeConfig.config[skillName]
            if nextSkill then
                table.insert(nextSkills, nextSkill)
            else
                gg.log("技能配置错误：找不到下一技能 " .. skillName)
            end
        end
        skillType.nextSkills = nextSkills
    end
end
end

---@param name string
---@return SkillType
function SkillTypeConfig.Get(name)
    if not loaded then
        LoadConfig()
    end
    return SkillTypeConfig.config[name]
end

---@return SkillType[]
function SkillTypeConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return SkillTypeConfig.config
end

---@return SkillType[]
function SkillTypeConfig.GetEntrySkills()
    if not loaded then
        LoadConfig()
    end
    return entrySkills
end

--- 将 SkillType 实例配置转换为纯 table 数据
---@return table<string, table> 
function SkillTypeConfig.ConvertFromSkillTypeInstances()
    local tableConfig = {}
    local allSkills = SkillTypeConfig.GetAll()
    for skillName, skillType in pairs(allSkills) do
        -- 创建基础 table 结构
        local skillData = {}
        -- 提取 SkillType 实例的所有属性
        if type(skillType) == "table" then
            -- 复制所有基础属性
            -- for key, value in pairs(skillType) do
            --     -- 跳过方法和元表相关属性
            --     if type(value) ~= "function" and key ~= "__index" and key ~= "className" then
            --         skillData[key] = value
            --     end
            -- end
            skillData.name = skillType.name
            skillData.maxLevel =  skillType.maxLevel
            skillData.description = skillType.description
            skillData.icon =  skillType.icon 
            skillData.isEntrySkill =  skillType.isEntrySkill 
            skillData.effectiveWithoutEquip = skillType.effectiveWithoutEquip 
            skillData.nextSkills = skillType.nextSkills 
            skillData.targetMode =  skillType.targetMode 
            skillData.passiveTags =skillType.passiveTags
            skillData.activeSpell = skillType.activeSpell
            skillData.recoil = skillType.recoil
            
            -- 处理下一技能列表
            local nextSkills = {}
            local nextSkillsSource =  skillType["下一技能"]
            if nextSkillsSource and type(nextSkillsSource) == "table" then
                for _, nextSkill in ipairs(nextSkillsSource) do
                    if type(nextSkill) == "string" then
                        -- 已经是字符串
                        table.insert(nextSkills, nextSkill)
                    elseif type(nextSkill) == "table" then
                        -- 如果是 SkillType 实例，提取技能名
                        local nextSkillName = nextSkill["技能名"]
                        if nextSkillName then
                            table.insert(nextSkills, nextSkillName)
                        end
                    end
                end
            end
            if #nextSkills > 0 then
                skillData["下一技能"] = nextSkills
            end
        end
    
        tableConfig[skillName] = skillData
    end
    
    return tableConfig
end

return SkillTypeConfig
