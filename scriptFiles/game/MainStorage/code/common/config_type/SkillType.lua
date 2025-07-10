local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local TagTypeConfig = require(MainStorage.config.TagTypeConfig) ---@type TagTypeConfig
local SpellConfig = require(MainStorage.config.SpellConfig)  ---@type SpellConfig

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
    self.description = data["实际描述"] or ""
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
    self.oneKeyUpgradeCosts = data["一键强化素材"]
    self.quality = data["技能品级"] or "R"
    self.battleModel = data["更改模型"]
    self.battleAnimator = data["更改动画"]
    self.battleStateMachine = data["更改状态机"]
    self.battlePlayerSize = data["更改玩家尺寸"]
    self.afkScale = gg.Vec3.new(data["副卡挂机尺寸"]):ToVector3()
    self.freezesMove = data["禁止移动"]
    self.maxGrowthFormula = data["最大经验"] or "10+(20*LVL)"
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

function SkillType:GetDescription(level)
    return self.description
    -- if not self.description or self.description == "" then
    --     return ""
    -- end

    -- local result = self.description

    -- -- 处理 [数字:每级增加倍率] 格式
    -- result = string.gsub(result, "%[(%d+):([%d%.]+)%]", function(baseValue, perLevel)
    --     baseValue = tonumber(baseValue)
    --     perLevel = tonumber(perLevel)
    --     local finalValue = baseValue * (1 + (level - 1) * perLevel)
    --     return string.format("%.1f", finalValue)
    -- end)

    -- -- 处理 [魔法名.属性.数组索引] 格式
    -- result = string.gsub(result, "%[([^%.%[%]:]+)%.([^%.]+)%.(%d+)%]", function(spellName, fieldName, arrayIndex)
    --     arrayIndex = tonumber(arrayIndex)
    --     local spell = SpellConfig.Get(spellName)
    --     if spell then
    --         if fieldName == "属性增伤" and spell.damageAmplifier and spell.damageAmplifier[arrayIndex] then
    --             local element = spell.damageAmplifier[arrayIndex]
    --             if element then
    --                 local finalRate = element.multiplier
    --                 if element.statType then
    --                     return string.format("%.0f", finalRate*100) .. "%" .. (element.statType or "")
    --                 else
    --                     return string.format("%.1f", finalRate)
    --                 end
    --             end
    --         end
    --     end
    --     return string.format("[%s.%s.%d]", spellName, fieldName, arrayIndex)
    -- end)

    -- -- 处理 [魔法名.属性] 格式
    -- gg.log("result", result)
    -- result = string.gsub(result, "%[([^%.%[%]:]+)%.([^%.]+)%]", function(spellName, fieldName)
    --     local spell = SpellConfig.Get(spellName)
    --     gg.log("spellName", spellName, fieldName, spell)
    --     if spell then
    --         local field = spell[fieldName]
    --         gg.log("field", spellName, fieldName, field,  type(field))
    --         if field then
    --             if type(field) == "number" then
    --                 return string.format("%.1f", field)
    --             elseif type(field) == "string" then
    --                 return field
    --             elseif type(field) == "table" then
    --                 -- 如果是数组，尝试获取第一个元素
    --                 if #field > 0 and field[1] then
    --                     local value = field[1]
    --                     if type(value) == "table" and value["倍率"] then
    --                         return string.format("%.1f", value["倍率"])
    --                     elseif type(value) == "number" then
    --                         return string.format("%.1f", value)
    --                     else
    --                         return tostring(value)
    --                     end
    --                 end
    --             end
    --         end
    --     end
    --     return string.format("[%s.%s]", spellName, fieldName)
    -- end)

    -- return result
end

function SkillType:GetMaxGrowthAtLevel(level)
    -- 检查是否存在最大经验公式
    if not self.maxGrowthFormula or self.maxGrowthFormula == "" then
        gg.log("警告: 技能", self.name, "没有设置最大经验公式，使用默认值100")
        return 100000000  -- 返回默认值
    end

    local expr = self.maxGrowthFormula:gsub("LVL", tostring(level))
    local result = self:_evaluateExpression(expr)
    return result or 100000000  -- 如果计算失败，返回默认值
end

-- 内部方法：处理包含数学函数的表达式
---@param expr string 要计算的表达式
---@return number|nil 计算结果，失败时返回nil
function SkillType:_evaluateExpression(expr)
    -- 递归处理数学函数：min, max
    local function processFunction(str, funcName)
        local hasMatch = false
        local result = str
        
        -- 手动查找函数调用并处理括号平衡
        local searchPos = 1
        while true do
            local startPos = string.find(result, funcName .. "%s*%(", searchPos)
            if not startPos then
                break
            end
            
            -- 找到函数名和开括号的位置
            local funcStart = startPos
            local parenStart = string.find(result, "%(", startPos)
            if not parenStart then
                break
            end
            
            -- 使用括号计数器找到匹配的右括号
            local parenCount = 1
            local pos = parenStart + 1
            local parenEnd = nil
            
            while pos <= #result and parenCount > 0 do
                local char = string.sub(result, pos, pos)
                if char == "(" then
                    parenCount = parenCount + 1
                elseif char == ")" then
                    parenCount = parenCount - 1
                    if parenCount == 0 then
                        parenEnd = pos
                        break
                    end
                end
                pos = pos + 1
            end
            
            if not parenEnd then
                gg.log("警告: 找不到匹配的右括号，表达式:", result)
                break
            end
            
            -- 提取函数参数
            local args = string.sub(result, parenStart + 1, parenEnd - 1)
            hasMatch = true
            
            -- 分割参数（处理嵌套括号）
            local params = {}
            local depth = 0
            local currentParam = ""
            
            for i = 1, #args do
                local char = args:sub(i, i)
                if char == "(" then
                    depth = depth + 1
                    currentParam = currentParam .. char
                elseif char == ")" then
                    depth = depth - 1
                    currentParam = currentParam .. char
                elseif char == "," and depth == 0 then
                    table.insert(params, currentParam:match("^%s*(.-)%s*$")) -- 去除首尾空格
                    currentParam = ""
                else
                    currentParam = currentParam .. char
                end
            end
            if currentParam ~= "" then
                table.insert(params, currentParam:match("^%s*(.-)%s*$"))
            end
            
            -- 计算每个参数的值（递归处理可能包含的数学函数）
            local values = {}
            for _, param in ipairs(params) do
                -- 递归调用_evaluateExpression处理参数中可能包含的函数
                local value = nil
                if param:find("min%s*%(") or param:find("max%s*%(") then
                    -- 参数中包含函数，递归处理
                    value = self:_evaluateExpression(param)
                else
                    -- 简单表达式，直接计算
                    value = gg.eval(param)
                end
                
                if value then
                    table.insert(values, value)
                else
                    gg.log("警告: 无法计算参数:", param)
                    values = {0}
                    break
                end
            end
            
            -- 根据函数名计算结果
            local funcResult = 0
            if funcName == "min" then
                funcResult = values[1] or 0
                for i = 2, #values do
                    funcResult = math.min(funcResult, values[i])
                end
            elseif funcName == "max" then
                funcResult = values[1] or 0
                for i = 2, #values do
                    funcResult = math.max(funcResult, values[i])
                end
            end
            
            -- 替换原字符串中的函数调用
            local funcCall = string.sub(result, funcStart, parenEnd)
            result = string.sub(result, 1, funcStart - 1) .. tostring(funcResult) .. string.sub(result, parenEnd + 1)
            
            -- 从替换后的位置继续搜索
            searchPos = funcStart + string.len(tostring(funcResult))
        end
        
        return result, hasMatch
    end
    
    -- 处理嵌套的min和max函数（从内向外处理）
    local maxIterations = 10  -- 防止无限循环
    local iteration = 0
    
    while iteration < maxIterations do
        iteration = iteration + 1
        local originalExpr = expr
        local hasMinMatch, hasMaxMatch = false, false
        
        -- 处理最内层的函数
        expr, hasMaxMatch = processFunction(expr, "max")
        expr, hasMinMatch = processFunction(expr, "min")
        
        -- 如果没有更多的函数需要处理，退出循环
        if not hasMinMatch and not hasMaxMatch then
            break
        end
        
        -- 如果表达式没有变化，也退出循环（防止死循环）
        if expr == originalExpr then
            gg.log("警告: 数学函数处理可能陷入死循环，表达式:", expr)
            break
        end
    end
    
    if iteration >= maxIterations then
        gg.log("警告: 数学函数处理达到最大迭代次数，表达式:", expr)
    end
    
    return gg.eval(expr)
end

function SkillType:GetOneKeyUpgradeCostsAtLevel(level)
    if not self.oneKeyUpgradeCosts then
        return {}
    end
    local costs = {}
    for resourceType, costExpr in pairs(self.oneKeyUpgradeCosts) do
        local expr = costExpr:gsub("LVL", tostring(level))
        local result = self:_evaluateExpression(expr)
        costs[resourceType] = result
    end
    return costs
end

function SkillType:GetCostAtLevel(level)
    if not self.upgradeCosts then
        return {}
    end

    local costs = {}
    for resourceType, costExpr in pairs(self.upgradeCosts) do
        local expr = costExpr:gsub("LVL", tostring(level))
        local result = self:_evaluateExpression(expr)
        if result and result > 0 then
            costs[resourceType] = math.floor(result)  -- 只保留正数结果
        end
    end
    return costs
end

-- 获取指定等级下的提升玩家等级数值
---@param level number 技能等级
---@return number 提升玩家等级的数值
function SkillType:GetLevelUpPlayerAtLevel(level)
    if not self.levelUpPlayer then
        return 0
    end

    -- 如果是数字类型，直接返回
    if type(self.levelUpPlayer) == "number" then
        return self.levelUpPlayer
    end

    -- 如果是字符串类型，当作公式解析
    if type(self.levelUpPlayer) == "string" then
        local expr = self.levelUpPlayer:gsub("LVL", tostring(level))
        local result = self:_evaluateExpression(expr)
        if result then
            return math.floor(result)
        else
            gg.log("警告: 无法计算提升玩家等级公式:", self.levelUpPlayer)
            return 0
        end
    end

    -- 其他类型返回0
    return 0
end

function SkillType:GetToStringParams()
    return {
        name = self.name
    }
end

return SkillType
