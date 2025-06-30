--- 技能相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)  ---@type MCloudDataMgr
local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig
local SkillCommon = require(MainStorage.code.server.spells.SkillCommon) ---@type SkillCommon
---@class SkillCommands
local SkillCommands = {}


---@param params table
---@param player Player
function SkillCommands.unlock(params, player)
    local skillName = params["skillName"]
    local level = params["level"] or 1

    -- 使用SkillCommon的验证方法
    local skillType, errorCode = SkillCommon.ValidateSkillLearn(player, skillName)

    if errorCode ~= SkillEventConfig.ERROR_CODES.SUCCESS then
        local errorMsg = SkillCommon.FormatErrorMessage(
            "技能解锁失败: " .. SkillEventConfig.GetErrorMessage(errorCode),
            player,
            skillName
        )
        SkillCommon.SendMessageAndLog(player, errorMsg, true)
        return
    end

    -- 创建技能实例
    local skill = SkillCommon.CreateSkillInstance(player, skillName, level)
    if not skill then
        local errorMsg = SkillCommon.FormatErrorMessage("技能创建失败", player, skillName)
        SkillCommon.SendMessageAndLog(player, errorMsg, true)
        return
    end

    -- 成功消息
    local successMsg = SkillCommon.FormatSuccessMessage("技能解锁成功", player, skillName)
    SkillCommon.SendMessageAndLog(player, successMsg, false)
    -- 同步最新的技能数据到客户端，确保UI正确更新
    player:syncSkillData()
end

---@param params table
---@param player Player
function SkillCommands.destroy(params, player)
    local skillName = params["skillName"]

    -- 使用SkillCommon的验证方法
    local skillType, skillInstance, errorCode = SkillCommon.ValidateSkillAndPlayer(player, skillName)

    if errorCode ~= SkillEventConfig.ERROR_CODES.SUCCESS then
        local errorMsg = SkillCommon.FormatErrorMessage(
            "销毁技能失败: " .. SkillEventConfig.GetErrorMessage(errorCode),
            player,
            skillName
        )
        SkillCommon.SendMessageAndLog(player, errorMsg, true)
        return
    end

    gg.log("开始销毁技能: " .. skillName .. "，玩家:" .. player.name)

    -- 执行销毁逻辑
    local destroyResult = SkillCommon.PerformSkillDestroy(player, skillName)

    if destroyResult.success then
        -- 保存玩家数据
        player:saveSkillConfig()
        -- 同步最新的技能数据到客户端
        player:syncSkillData()

        local successMsg = SkillCommon.FormatSuccessMessage(
            "技能销毁成功，同时销毁的技能: " .. table.concat(destroyResult.destroyedSkills, ", "),
            player,
            skillName
        )
        SkillCommon.SendMessageAndLog(player, successMsg, false)
    else
        local errorMsg = SkillCommon.FormatErrorMessage(
            "技能销毁失败: " .. SkillEventConfig.GetErrorMessage(destroyResult.errorCode),
            player,
            skillName
        )
        SkillCommon.SendMessageAndLog(player, errorMsg, true)
    end
end

---@param params table
---@param player Player
function SkillCommands.setLevel(params, player)
    local skillName = params["skillName"]
    local level = params["level"] or -1
    local growth = params["growth"] or -1

    -- 使用SkillCommon的公共方法设置技能等级和经验
    local result = SkillCommon.SetSkillLevelAndGrowth(player, skillName, level, growth)

    if not result.success then
        local errorMsg = SkillCommon.FormatErrorMessage(
            "设置技能等级失败: " .. SkillEventConfig.GetErrorMessage(result.errorCode),
            player,
            skillName
        )
        SkillCommon.SendMessageAndLog(player, errorMsg, true)
        return
    end

    local skillData = result.skillData

    -- 生成成功消息
    local successMsg

    successMsg = SkillCommon.FormatSuccessMessage(
        string.format("技能等级和经验设置成功：%d级→%d级，经验 %d→%d",
            skillData.originalLevel, skillData.level, skillData.originalGrowth, skillData.growth),
        player,
        skillName
    )
    SkillCommon.SendMessageAndLog(player, successMsg, false)

    -- 发送响应到客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = SkillEventConfig.RESPONSE.SET_LEVEL,
        data = skillData
    })
end

---@param params table
---@param player Player
function SkillCommands.destroyAll(params, player)
    gg.log("开始销毁所有技能，玩家:" .. player.name)

    if not player.skills or next(player.skills) == nil then
        local warningMsg = SkillCommon.FormatErrorMessage("玩家没有任何技能需要销毁", player, "所有技能")
        SkillCommon.SendMessageAndLog(player, warningMsg, false)
        return
    end

    local destroyedSkills = {}
    local failedSkills = {}
    local skillCount = 0

    -- 获取所有技能名称的副本，避免在遍历过程中修改原表
    local skillNames = {}
    for skillName, _ in pairs(player.skills) do
        table.insert(skillNames, skillName)
        skillCount = skillCount + 1
    end

    gg.log("找到 " .. skillCount .. " 个技能需要销毁")

    -- 遍历销毁所有技能
    for _, skillName in ipairs(skillNames) do
        local destroyResult = SkillCommon.PerformSkillDestroy(player, skillName)

        if destroyResult.success then
            table.insert(destroyedSkills, skillName)
            -- 将destroyResult中的其他被销毁的技能也加入列表
            if destroyResult.destroyedSkills then
                for _, additionalSkill in ipairs(destroyResult.destroyedSkills) do
                    if additionalSkill ~= skillName then
                        table.insert(destroyedSkills, additionalSkill)
                    end
                end
            end
        else
            table.insert(failedSkills, skillName)
            gg.log("销毁技能失败: " .. skillName .. ", 错误: " .. (destroyResult.errorCode or "未知错误"))
        end
    end

    -- 强制清空玩家技能表（确保完全清空）
    player.skills = {}

    -- 保存玩家数据
    player:saveSkillConfig()
    -- 同步最新的技能数据到客户端
    player:syncSkillData()

    -- 生成结果消息
    local resultMsg
    if #failedSkills == 0 then
        resultMsg = SkillCommon.FormatSuccessMessage(
            "成功销毁所有技能 (" .. #destroyedSkills .. " 个): " .. table.concat(destroyedSkills, ", "),
            player,
            "所有技能"
        )
        SkillCommon.SendMessageAndLog(player, resultMsg, false)
    else
        resultMsg = SkillCommon.FormatErrorMessage(
            "部分技能销毁失败。成功销毁 (" .. #destroyedSkills .. " 个): " .. table.concat(destroyedSkills, ", ") ..
            "；失败 (" .. #failedSkills .. " 个): " .. table.concat(failedSkills, ", "),
            player,
            "所有技能"
        )
        SkillCommon.SendMessageAndLog(player, resultMsg, true)
    end

    -- 发送响应到客户端
    local responseData = {
        destroyedSkills = destroyedSkills,
        failedSkills = failedSkills,
        totalDestroyed = #destroyedSkills,
        totalFailed = #failedSkills
    }
    gg.network_channel:fireClient(player.uin, {
        cmd = SkillEventConfig.RESPONSE.DESTROY_ALL,
        data = responseData
    })
end


function SkillCommands.afk(params, player)
    local action = params["操作"] or "进入挂机"

    -- 检查玩家是否在关卡中
    local Level = require(MainStorage.code.server.Scene.Level)
    local currentLevel = Level.GetCurrentLevel(player)

    if action == "进入挂机" then
        -- 如果玩家在关卡中，不执行挂机操作
        if currentLevel and currentLevel.isActive then
            gg.log("玩家在关卡中，跳过进入挂机操作 - 玩家:", player.name, "关卡:", currentLevel.levelType.levelId)
            return
        end
        player:SendEvent("AfkSpotUpdate", {enter = true})
        player:EnterBattle()
    elseif action == "离开挂机" then
        -- 如果玩家在关卡中，不执行离开挂机操作
        if currentLevel and currentLevel.isActive then
            gg.log("玩家在关卡中，跳过离开挂机操作 - 玩家:", player.name, "关卡:", currentLevel.levelType.levelId)
            return
        end
        player:SendEvent("AfkSpotUpdate", {enter = false})
        player:ExitBattle()
    end
end

-- --装载配置的文件的技能
function SkillCommands.main(params, player)
    gg.log("技能命令处理",params)
    local uin = params["ID"]
    local player = gg.getPlayerByUin(uin)
    local skillName = params["技能"]
    local level = params["等级"]
    local growth = params["经验"]
    local optype = params["类型"]

    if not player then
        gg.log("玩家不存在: " .. uin)
        return false
    end

    if optype == "解锁" then
        local args = {skillName = skillName, level = level}
        SkillCommands.unlock(args, player)
    elseif optype == "销毁" then
        local args = {skillName = skillName}
        SkillCommands.destroy(args, player)
    elseif optype == "销毁所有" then
        local args = {}
        SkillCommands.destroyAll(args, player)
    elseif optype == "设置等级" then
        local args = {skillName = skillName, level = level, growth = growth}
        SkillCommands.setLevel(args, player)
    -- elseif optype == "装载" then
    --     player:LoadingConfSkills(args)
    end
    return true
end



return SkillCommands
