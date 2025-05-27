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
        ["技能分类"] = 0,
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
        ["技能分类"] = 0,
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
        ["技能分类"] = 0,
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
        ["技能分类"] = 0,
        ["下一技能"] = {
            "射速1_豌豆",
            "攻击1_豌豆",
            "生命1_豌豆"
        },
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "豌豆射手_入口",
        ["目标模式"] = "敌人",
        ["启用后坐力"] = true,
        ["后坐力"] = {
            ["垂直后坐力"] = 0,
            ["最大垂直后坐力"] = 0,
            ["垂直后坐力恢复"] = 0,
            ["水平后坐力"] = 0,
            ["最大水平后坐力"] = 0,
            ["水平后坐力恢复"] = 0,
            ["后坐力冷却时间"] = 0
        }
    }),
    ["副-樱桃炸弹"] = SkillType.New({
        ["技能名"] = "副-樱桃炸弹",
        ["显示名"] = "樱桃炸弹",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆射手可谓你的第一道防线，他们朝来犯的僵尸射击豌豆。",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_豌豆射手",
        ["目标模式"] = "位置",
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
    }),
    ["副-豌豆射手"] = SkillType.New({
        ["技能名"] = "副-豌豆射手",
        ["显示名"] = "豌豆射手",
        ["最大等级"] = 1,
        ["技能描述"] = "豌豆射手可谓你的第一道防线，他们朝来犯的僵尸射击豌豆。",
        ["是入口技能"] = true,
        ["技能分类"] = 1,
        ["无需装备也可生效"] = false,
        ["主动释放魔法"] = "副_召唤_豌豆射手",
        ["目标模式"] = "自己",
        ["位置偏移"] = {
            200,
            0,
            0
        },
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
}loaded = true

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
                -- 将当前技能添加到下一技能的prerequisite列表中
                table.insert(nextSkill.prerequisite, skillType)
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

return SkillTypeConfig
