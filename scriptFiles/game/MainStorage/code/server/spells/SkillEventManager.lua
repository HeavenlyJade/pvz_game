--- 技能事件管理器
--- 负责处理所有技能相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig

---@class SkillEventManager
local SkillEventManager = {}

-- 将配置从event_skill.lua导入到当前模块
SkillEventManager.REQUEST = SkillEventConfig.REQUEST
SkillEventManager.RESPONSE = SkillEventConfig.RESPONSE
SkillEventManager.NOTIFY = SkillEventConfig.NOTIFY
SkillEventManager.ERROR_CODES = SkillEventConfig.ERROR_CODES
SkillEventManager.ERROR_MESSAGES = SkillEventConfig.ERROR_MESSAGES

--[[
===================================
初始化和基础功能
===================================
]]

--- 初始化技能事件管理器
function SkillEventManager.Init()
    gg.log("初始化技能事件管理器...")

    -- 注册所有事件监听器
    SkillEventManager.RegisterEventHandlers()

    gg.log("技能事件管理器初始化完成")
end

--- 注册所有事件处理器
function SkillEventManager.RegisterEventHandlers()
    -- 学习技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.LEARN, SkillEventManager.HandleLearnSkill)

    -- 升级技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UPGRADE, SkillEventManager.HandleUpgradeSkill)

    -- 装备技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.EQUIP, SkillEventManager.HandleEquipSkill)

    -- 卸下技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UNEQUIP, SkillEventManager.HandleUnequipSkill)

    gg.log("已注册 " .. 4 .. " 个技能事件处理器")
end

--- 验证玩家和基础参数
---@param evt table 事件参数
---@param eventName string 事件名称
---@return Player|nil, number 玩家对象和错误码
function SkillEventManager.ValidatePlayer(evt, eventName)
    local env_player = evt.player
    local uin = env_player.uin
    gg.log("env_player",env_player,uin)
    if not uin then
        gg.log("事件 " .. eventName .. " 缺少玩家UIN参数")
        return nil, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS
    end

    local player = gg.getPlayerByUin(uin)
    if not player then
        gg.log("事件 " .. eventName .. " 找不到玩家: " .. uin)
        return nil, SkillEventManager.ERROR_CODES.PLAYER_NOT_FOUND
    end

    return player, SkillEventManager.ERROR_CODES.SUCCESS
end

--[[
===================================
服务器响应部分 - 发送数据到客户端
===================================
]]

--- 发送成功响应给客户端
---@param evt table 事件参数
---@param eventName string 响应事件名称
---@param data table 响应数据
function SkillEventManager.SendSuccessResponse(evt, eventName, data)
    local uin = evt.player.uin

    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = data
    })
end

--- 发送错误响应给客户端
---@param evt table 事件参数
---@param errorCode number 错误码
function SkillEventManager.SendErrorResponse(evt, errorCode)
    local uin = evt.player.uin
    local errorMessage = SkillEventConfig.GetErrorMessage(errorCode)

    gg.network_channel:fireClient(uin, {
        cmd = SkillEventManager.RESPONSE.ERROR,
        data = {
            errorCode = errorCode,
            errorMessage = errorMessage
        }
    })
end

--[[
===================================
客户端请求处理部分 - 处理客户端事件
===================================
]]

--- 处理技能学习请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleLearnSkill(evt)
    gg.log("处理学习技能请求",evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "LearnSkill")
    if not player then
        return
    end

    -- 从evt中获取技能名称
    local skillName = evt.skillName
    if not skillName then
        gg.log("技能名称不能为空")
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end

    -- 验证技能是否存在
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_FOUND)
        return
    end

    -- 检查玩家是否已拥有该技能
    local existingSkill = player.skills and player.skills[skillName]
    if existingSkill then
        gg.log("玩家已拥有该技能: " .. skillName)
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_ALREADY_LEARNED)
        return
    end

    -- TODO: 检查学习条件（前置技能、资源等）

    -- 创建并学习新技能
    local success = player:LearnSkill(skillType)
    if not success then
        gg.log("技能学习失败: " .. skillName)
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.UPGRADE_FAILED)
        return
    end

    local newSkill = player.skills[skillName]
    player:saveSkillConfig()

    gg.log("技能学习成功", skillName, "等级:", newSkill.level, "装备槽:", newSkill.equipSlot)

    local responseData = {
        skillName = skillName,
        level = newSkill.level,
        slot = newSkill.equipSlot,
        isNewSkill = true
    }

    gg.log("发送技能学习响应", responseData)
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.LEARN, responseData)
end

--- 处理技能升级请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleUpgradeSkill(evt)
    gg.log("处理升级技能请求", evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UpgradeSkill")
    if not player then
        return
    end

    -- 从evt中获取技能名称
    local skillName = evt.skillName
    if not skillName then
        gg.log("技能名称不能为空")
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end

    -- 验证技能是否存在于配置中
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_FOUND)
        return
    end

    -- 根据技能类型进行不同的检查
    if skillType.skillType == 0 then
        -- 主卡技能：检查父类技能是否存在
        local prerequisite = skillType.prerequisite or {}
        for i, preSkillType in ipairs(prerequisite) do
            if not (player.skills and player.skills[preSkillType.name]) then
                gg.log("父类技能不存在，无法升级: " .. skillName .. " 缺少前置技能: " .. preSkillType.name)
                SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_AVAILABLE)
                return
            end
        end
        -- 检查玩家是否已拥有该技能
        local existingSkill = player.skills and player.skills[skillName]
        -- 检查是否已达到最大等级
        if existingSkill and existingSkill.level >= skillType.maxLevel then
            gg.log("技能已达到最大等级: " .. skillName .. " 当前等级: " .. existingSkill.level)
            SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.MAX_LEVEL_REACHED)
            return
        end

    elseif skillType.skillType == 1 then
        -- 副卡技能：只检查技能是否存在
        local existingSkill = player.skills and player.skills[skillName]
        if not existingSkill then
            gg.log("副卡技能不存在，无法升级: " .. skillName)
            SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_OWNED)
            return
        end

        -- 检查是否已达到最大等级
        if existingSkill.level >= skillType.maxLevel then
            gg.log("副卡技能已达到最大等级: " .. skillName .. " 当前等级: " .. existingSkill.level)
            SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.MAX_LEVEL_REACHED)
            return
        end
    else
        gg.log("未知的技能类型: " .. skillName .. " 类型: " .. (skillType.skillType or "nil"))
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_FOUND)
        return
    end

    -- TODO: 检查升级条件（资源、前置技能等级等）

    -- 执行技能升级
    local success = player:UpgradeSkill(skillType)
    if not success then
        gg.log("技能升级失败: " .. skillName)
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.UPGRADE_FAILED)
        return
    end

    local upgradedSkill = player.skills[skillName]
    player:saveSkillConfig()

    gg.log("技能升级成功", skillName, "新等级:", upgradedSkill.level, "装备槽:", upgradedSkill.equipSlot)

    local responseData = {
        skillName = skillName,
        level = upgradedSkill.level,
        slot = upgradedSkill.equipSlot,
        maxLevel = skillType.maxLevel
    }

    gg.log("发送技能升级响应", responseData)
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE, responseData)
end

--- 处理装备技能请求
---@param evt table 事件数据 {uin, skillName, slot}
function SkillEventManager.HandleEquipSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "EquipSkill")
    if not player then
        return
    end

    -- 从evt中提取参数
    local skillName = evt.skillName or evt.skill
    local slot = evt.slot or evt.slotIndex

    if not skillName or not slot or slot < 1 or slot > 6 then -- 假设最多6个技能槽
        return
    end

    -- 检查技能是否存在
    local skill = player.skills and player.skills[skillName]
    if not skill then
        return
    end

    -- 执行装备
    local success = player:EquipSkill(skillName, slot)
    if success then
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.EQUIP, {
            skillName = skillName,
            slot = slot
        })
    else
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.ERROR, {
            errorCode = SkillEventManager.ERROR_CODES.SLOT_OCCUPIED
        })
    end
end

--- 处理卸下技能请求
---@param evt table 事件数据 {uin, slot}
function SkillEventManager.HandleUnequipSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UnequipSkill")
    if not player then
        return
    end

    -- 从evt中提取参数
    local slot = evt.slot or evt.slotIndex
    if not slot or slot < 1 or slot > 6 then
        return
    end

    -- 获取当前装备的技能
    local equippedSkill = player.equippedSkills and player.equippedSkills[slot]
    if not equippedSkill then
        return
    end

    local skillName = equippedSkill.skillType.skillName

    -- 执行卸下
    local success = player:UnequipSkill(slot)
    if success then
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UNEQUIP, {
            skillName = skillName,
            slot = slot
        })
    else
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.ERROR, {
            errorCode = SkillEventManager.ERROR_CODES.INVALID_SLOT
        })
    end
end

return SkillEventManager
