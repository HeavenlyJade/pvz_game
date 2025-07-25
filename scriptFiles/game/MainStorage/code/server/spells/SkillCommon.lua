--- 技能系统公共工具类
--- 包含SkillEventManager和MSkillCommands的公共代码
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local SkillTypeConfig = require(MainStorage.config.SkillTypeConfig) ---@type SkillTypeConfig
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig

---@class SkillCommon
local SkillCommon = {}

--[[
===================================
技能验证相关公共方法
===================================
]]

--- 验证技能配置是否存在
---@param skillName string 技能名称
---@return SkillType|nil, SkillType 技能配置和错误码
function SkillCommon.ValidateSkillConfig(skillName)
    if not skillName or skillName == "" then
        return nil, SkillEventConfig.ERROR_CODES.INVALID_PARAMETERS
    end

    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置不存在: " .. skillName)
        return nil, SkillEventConfig.ERROR_CODES.SKILL_NOT_FOUND
    end

    return skillType, SkillEventConfig.ERROR_CODES.SUCCESS
end

--- 验证玩家是否拥有指定技能
---@param player Player 玩家对象
---@param skillName string 技能名称
---@return table|nil, number 技能实例和错误码
function SkillCommon.ValidatePlayerSkill(player, skillName)
    if not player or not player.skills then
        return nil, SkillEventConfig.ERROR_CODES.PLAYER_NOT_FOUND
    end

    local skillInstance = player.skills[skillName]
    if not skillInstance then
        gg.log("玩家不拥有该技能: " .. skillName .. " 玩家: " .. (player.name or "unknown"))
        return nil, SkillEventConfig.ERROR_CODES.SKILL_NOT_OWNED
    end

    return skillInstance, SkillEventConfig.ERROR_CODES.SUCCESS
end

--- 组合验证技能配置和玩家拥有权
---@param player Player 玩家对象
---@param skillName string 技能名称
---@return SkillType|nil, table|nil, number 技能配置、技能实例、错误码
function SkillCommon.ValidateSkillAndPlayer(player, skillName)
    -- 验证技能配置
    local skillType, configError = SkillCommon.ValidateSkillConfig(skillName)
    if not skillType then
        return nil, nil, configError
    end

    -- 验证玩家拥有权
    local skillInstance, playerError = SkillCommon.ValidatePlayerSkill(player, skillName)
    if not skillInstance then
        return skillType, nil, playerError
    end

    return skillType, skillInstance, SkillEventConfig.ERROR_CODES.SUCCESS
end

--[[
===================================
技能销毁相关公共方法
===================================
]]

--- 查找要销毁的技能及其所有子技能
---@param player Player 玩家对象
---@param rootSkillName string 根技能名称
---@return string[] 需要销毁的技能列表
function SkillCommon.FindSkillsToDestroy(player, rootSkillName)
    local skillsToDestroy = {}
    local visited = {}

    -- 深度优先搜索，找到所有子技能
    local function dfsCollectSkills(skillName)
        if visited[skillName] or not player.skills[skillName] then
            return
        end

        visited[skillName] = true
        table.insert(skillsToDestroy, skillName)

        -- 获取技能配置
        local skillType = SkillTypeConfig.Get(skillName)
        if skillType and skillType.nextSkills then
            for _, nextSkill in ipairs(skillType.nextSkills) do
                dfsCollectSkills(nextSkill.name)
            end
        end
    end

    dfsCollectSkills(rootSkillName)
    return skillsToDestroy
end

--- 销毁玩家的单个技能
---@param player Player 玩家对象
---@param skillName string 技能名称
---@return boolean 是否成功
function SkillCommon.DestroyPlayerSkill(player, skillName)
    if not player.skills or not player.skills[skillName] then
        return false
    end

    local skill = player.skills[skillName]

    -- 如果技能已装备，先卸下
    if skill.equipSlot and skill.equipSlot > 0 then
        gg.log("技能已装备，先自动卸下:", skillName, "槽位:", skill.equipSlot)
        player:UnequipSkill(skill.equipSlot)
    end

    -- 从玩家技能列表中移除
    player.skills[skillName] = nil

    gg.log("技能已从玩家技能列表中移除:", skillName)
    return true
end

--- 执行完整的技能销毁逻辑
---@param player Player 玩家对象
---@param skillName string 要销毁的技能名称
---@return table 销毁结果 {success, destroyedSkills, errorCode}
function SkillCommon.PerformSkillDestroy(player, skillName)
    gg.log("执行技能销毁逻辑:", skillName)

    -- 查找要销毁的技能及其所有子技能
    local skillsToDestroy = SkillCommon.FindSkillsToDestroy(player, skillName)
    if not skillsToDestroy or #skillsToDestroy == 0 then
        return {
            success = false,
            errorCode = SkillEventConfig.ERROR_CODES.SKILL_NOT_OWNED,
            destroyedSkills = {}
        }
    end

    gg.log("找到需要销毁的技能:", table.concat(skillsToDestroy, ", "))

    -- 执行销毁操作
    local destroyedSkills = {}
    for _, skillToDestroy in ipairs(skillsToDestroy) do
        local success = SkillCommon.DestroyPlayerSkill(player, skillToDestroy)
        if success then
            table.insert(destroyedSkills, skillToDestroy)
            gg.log("成功销毁技能:", skillToDestroy)
        else
            gg.log("销毁技能失败:", skillToDestroy)
        end
    end

    return {
        success = #destroyedSkills > 0,
        errorCode = SkillEventConfig.ERROR_CODES.SUCCESS,
        destroyedSkills = destroyedSkills
    }
end

--[[
===================================
技能学习相关公共方法
===================================
]]

--- 验证技能学习条件
---@param player Player 玩家对象
---@param skillName string 技能名称
---@return SkillType|nil, number 技能配置和错误码
function SkillCommon.ValidateSkillLearn(player, skillName)
    -- 验证技能配置
    local skillType, configError = SkillCommon.ValidateSkillConfig(skillName)
    if not skillType then
        return nil, configError
    end

    -- 检查玩家是否已拥有该技能
    local existingSkill = player.skills and player.skills[skillName]
    if existingSkill then
        gg.log("玩家已拥有该技能: " .. skillName .. " 玩家: " .. (player.name or "unknown"))
        return nil, SkillEventConfig.ERROR_CODES.SKILL_ALREADY_LEARNED
    end

    return skillType, SkillEventConfig.ERROR_CODES.SUCCESS
end

--- 创建新技能实例
---@param player Player 玩家对象
---@param skillName string 技能名称
---@param level number|nil 技能等级（可选，默认为1）
---@return table|nil 技能实例
function SkillCommon.CreateSkillInstance(player, skillName, level)
    -- 获取技能类型配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置不存在: " .. skillName)
        return nil
    end

    -- 使用 Player 的 LearnSkill 方法创建技能
    local success = player:LearnSkill(skillType)
    if not success then
        gg.log("技能创建失败（可能已存在）: " .. skillName .. " 玩家: " .. player.name)
        return nil
    end

    -- 获取刚创建的技能实例
    local skill = player.skills[skillName]

    player:saveSkillConfig()


    gg.log("技能创建成功:", skillName, "等级:", skill and skill.level or 1, "玩家:", player.name)
    return skill
end

--[[
===================================
错误处理和消息相关公共方法
===================================
]]

--- 格式化错误消息（包含玩家信息）
---@param message string 基础错误消息
---@param player Player 玩家对象
---@param skillName string|nil 技能名称（可选）
---@return string 格式化后的错误消息
function SkillCommon.FormatErrorMessage(message, player, skillName)
    local playerName = player and player.name or "unknown"
    local skillInfo = skillName and (" 技能: " .. skillName) or ""
    return message .. "，玩家: " .. playerName .. skillInfo
end

--- 格式化成功消息（包含玩家信息）
---@param message string 基础成功消息
---@param player Player 玩家对象
---@param skillName string|nil 技能名称（可选）
---@return string 格式化后的成功消息
function SkillCommon.FormatSuccessMessage(message, player, skillName)
    local playerName = player and player.name or "unknown"
    local skillInfo = skillName and (" 技能: " .. skillName) or ""
    return message .. "，玩家: " .. playerName .. skillInfo
end

--- 发送聊天消息并记录日志
---@param player Player 玩家对象
---@param message string 消息内容
---@param isError boolean|nil 是否为错误消息（默认false）
function SkillCommon.SendMessageAndLog(player, message, isError)
    if isError then
        gg.log("错误: " .. message)
    else
        gg.log("信息: " .. message)
    end

    if player and player.SendChatText then
        player:SendChatText(message)
    end
end

--[[
===================================
技能数据更新相关公共方法
===================================
]]

--- 设置技能等级和经验（管理员指令用）
---@param player Player 玩家对象
---@param skillName string 技能名称
---@param level number 目标等级
---@param growth number|nil 目标经验值（可选，默认为0）
---@param star number|nil 目标星级（可选，默认为不变）
---@return table 操作结果 {success, errorCode, skillData}
function SkillCommon.SetSkillLevelAndGrowth(player, skillName, level, growth, star)
    growth = growth or 0

    -- 验证技能配置
    local skillType, configError = SkillCommon.ValidateSkillConfig(skillName)
    if not skillType then
        return {
            success = false,
            errorCode = configError,
            skillData = nil
        }
    end

    -- 检查等级是否有效
    local maxLevel = skillType.maxLevel or 1
    if level and  level > maxLevel then
        return {
            success = false,
            errorCode = SkillEventConfig.ERROR_CODES.INVALID_PARAMETERS,
            skillData = nil
        }
    end

    -- 检查玩家是否拥有该技能
    local existingSkill = player.skills[skillName]
    if not existingSkill then
        return {
            success = false,
            errorCode = SkillEventConfig.ERROR_CODES.SKILL_NOT_OWNED,
            skillData = nil
        }
    end

    -- 记录原始数据
    local originalLevel = existingSkill.level
    local originalGrowth = existingSkill.growth
    local originalStar = existingSkill.star_level 
    -- 设置新的等级、经验和星级
    if level and level > 0 then
        existingSkill.level = level
    end
    if growth and growth > 0 then
        existingSkill.growth = growth
    end
    if star and star >= 0 then
        existingSkill.star_level = star
    end

    -- 保存玩家数据
    player:saveSkillConfig()

    return {
        success = true,
        errorCode = SkillEventConfig.ERROR_CODES.SUCCESS,
        skillData = {
            skillName = skillName,
            level = existingSkill and existingSkill.level or 0,
            growth = existingSkill and existingSkill.growth or 0,
            slot = existingSkill and existingSkill.equipSlot or 0,
            maxLevel = maxLevel,
            originalLevel = originalLevel,
            originalGrowth = originalGrowth,
            star_level = existingSkill and existingSkill.star_level or 0,
            originalStar = originalStar
        }
    }
end

return SkillCommon
