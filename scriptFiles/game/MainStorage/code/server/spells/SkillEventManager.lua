--- 技能事件管理器
--- 负责处理所有技能相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill

---@class SkillEventManager
local SkillEventManager = {}

--[[
===================================
事件定义部分
===================================
]]

-- 客户端请求事件
SkillEventManager.REQUEST = {
    GET_LIST = "SkillRequest_GetList",
    LEARN = "SkillRequest_Learn",
    UPGRADE = "SkillRequest_Upgrade",
    EQUIP = "SkillRequest_Equip",
    UNEQUIP = "SkillRequest_Unequip",
    GET_DETAIL = "SkillRequest_GetDetail",
    GET_AVAILABLE = "SkillRequest_GetAvailable"
}

-- 服务器响应事件
SkillEventManager.RESPONSE = {
    LIST = "SkillResponse_List",
    LEARN = "SkillResponse_Learn",
    UPGRADE = "SkillResponse_Upgrade",
    EQUIP = "SkillResponse_Equip",
    UNEQUIP = "SkillResponse_Unequip",
    DETAIL = "SkillResponse_Detail",
    AVAILABLE = "SkillResponse_Available",
    ERROR = "SkillResponse_Error"
}

-- 服务器通知事件
SkillEventManager.NOTIFY = {
    SKILL_CHANGED = "SkillNotify_Changed",
    SKILL_UNLOCKED = "SkillNotify_Unlocked"
}

-- 兼容旧版事件名称（用于过渡）
SkillEventManager.EVENTS = {
    -- 客户端请求事件
    REQUEST_GET_LIST = SkillEventManager.REQUEST.GET_LIST,
    REQUEST_LEARN = SkillEventManager.REQUEST.LEARN,
    REQUEST_UPGRADE = SkillEventManager.REQUEST.UPGRADE,
    REQUEST_EQUIP = SkillEventManager.REQUEST.EQUIP,
    REQUEST_UNEQUIP = SkillEventManager.REQUEST.UNEQUIP,
    REQUEST_GET_DETAIL = SkillEventManager.REQUEST.GET_DETAIL,
    REQUEST_GET_AVAILABLE = SkillEventManager.REQUEST.GET_AVAILABLE,
    
    -- 服务器响应事件
    RESPONSE_LIST = SkillEventManager.RESPONSE.LIST,
    RESPONSE_LEARN = SkillEventManager.RESPONSE.LEARN,
    RESPONSE_UPGRADE = SkillEventManager.RESPONSE.UPGRADE,
    RESPONSE_EQUIP = SkillEventManager.RESPONSE.EQUIP,
    RESPONSE_UNEQUIP = SkillEventManager.RESPONSE.UNEQUIP,
    RESPONSE_DETAIL = SkillEventManager.RESPONSE.DETAIL,
    RESPONSE_AVAILABLE = SkillEventManager.RESPONSE.AVAILABLE,
    RESPONSE_ERROR = SkillEventManager.RESPONSE.ERROR,
    
    -- 服务器通知事件
    NOTIFY_SKILL_CHANGED = SkillEventManager.NOTIFY.SKILL_CHANGED,
    NOTIFY_SKILL_UNLOCKED = SkillEventManager.NOTIFY.SKILL_UNLOCKED
}

--[[
===================================
错误码和错误消息定义
===================================
]]

-- 错误码定义
SkillEventManager.ERROR_CODES = {
    SUCCESS = 0,
    PLAYER_NOT_FOUND = 1,
    SKILL_NOT_FOUND = 2,
    SKILL_ALREADY_LEARNED = 3,
    SKILL_NOT_LEARNED = 4,
    MAX_LEVEL_REACHED = 5,
    INSUFFICIENT_RESOURCES = 6,
    INVALID_SLOT = 7,
    SLOT_OCCUPIED = 8,
    SKILL_NOT_AVAILABLE = 9,
    PERMISSION_DENIED = 10,
    INVALID_PARAMETERS = 11
}

-- 错误消息映射
SkillEventManager.ERROR_MESSAGES = {
    [SkillEventManager.ERROR_CODES.SUCCESS] = "操作成功",
    [SkillEventManager.ERROR_CODES.PLAYER_NOT_FOUND] = "玩家不存在",
    [SkillEventManager.ERROR_CODES.SKILL_NOT_FOUND] = "技能不存在",
    [SkillEventManager.ERROR_CODES.SKILL_ALREADY_LEARNED] = "技能已学会",
    [SkillEventManager.ERROR_CODES.SKILL_NOT_LEARNED] = "尚未学会该技能",
    [SkillEventManager.ERROR_CODES.MAX_LEVEL_REACHED] = "技能已达最大等级",
    [SkillEventManager.ERROR_CODES.INSUFFICIENT_RESOURCES] = "资源不足",
    [SkillEventManager.ERROR_CODES.INVALID_SLOT] = "无效的装备槽位",
    [SkillEventManager.ERROR_CODES.SLOT_OCCUPIED] = "装备槽位已被占用",
    [SkillEventManager.ERROR_CODES.SKILL_NOT_AVAILABLE] = "技能不可学习",
    [SkillEventManager.ERROR_CODES.PERMISSION_DENIED] = "权限不足",
    [SkillEventManager.ERROR_CODES.INVALID_PARAMETERS] = "参数无效"
}

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
    -- 获取技能列表
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.GET_LIST, SkillEventManager.HandleGetSkillList)
    
    -- 学习技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.LEARN, SkillEventManager.HandleLearnSkill)
    
    -- 升级技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UPGRADE, SkillEventManager.HandleUpgradeSkill)
    
    -- 装备技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.EQUIP, SkillEventManager.HandleEquipSkill)
    
    -- 卸下技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UNEQUIP, SkillEventManager.HandleUnequipSkill)
    
    -- 获取技能详情
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.GET_DETAIL, SkillEventManager.HandleGetSkillDetail)
    
    -- 获取可学习技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.GET_AVAILABLE, SkillEventManager.HandleGetAvailableSkills)
    
    gg.log("已注册 " .. 7 .. " 个技能事件处理器")
end

--- 验证玩家和基础参数
---@param evt table 事件参数
---@param eventName string 事件名称
---@return Player|nil, number 玩家对象和错误码
function SkillEventManager.ValidatePlayer(evt, eventName)
    local env_player = evt.player
    local uin = env_player.uin
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

--- 发送错误响应给客户端
---@param evt table 事件参数
---@param errorCode number 错误码
---@param extraData table|nil 额外数据
function SkillEventManager.SendErrorResponse(evt, errorCode, extraData)
    local env_player = evt.player
    local uin = env_player.uin
    local response = {
        success = false,
        errorCode = errorCode,
        message = SkillEventManager.ERROR_MESSAGES[errorCode] or "未知错误"
    }
    
    if extraData then
        for k, v in pairs(extraData) do
            response[k] = v
        end
    end
    
    gg.network_channel:fireClient(uin, {
        cmd = SkillEventManager.RESPONSE.ERROR,
        data = response
    })
end

--- 发送成功响应给客户端
---@param evt table 事件参数
---@param eventName string 响应事件名称
---@param data table 响应数据
function SkillEventManager.SendSuccessResponse(evt, eventName, data)
    local uin = evt.uin or evt.player
    -- data.success = true
    -- data.errorCode = SkillEventManager.ERROR_CODES.SUCCESS
    
    -- gg.network_channel:fireClient(uin, {
    --     cmd = eventName,
    --     data = data
    -- })
end

--- 发送技能变化通知
---@param evt table 事件参数
---@param skillName string 技能名称
---@param changeType string 变化类型
function SkillEventManager.NotifySkillChanged(evt, skillName, changeType)
    local uin = evt.uin or evt.player
    gg.network_channel:fireClient(uin, {
        cmd = SkillEventManager.NOTIFY.SKILL_CHANGED,
        data = {
            skillName = skillName,
            changeType = changeType,
            timestamp = os.time()
        }
    })
end

--- 获取错误消息
---@param errorCode number 错误码
---@return string 错误消息
function SkillEventManager.GetErrorMessage(errorCode)
    return SkillEventManager.ERROR_MESSAGES[errorCode] or "未知错误"
end

--[[
===================================
客户端请求处理部分 - 处理客户端事件
===================================
]]

--- 处理获取技能列表请求
--- ---@param evt table 事件数据

function SkillEventManager.HandleGetSkillList(evt)
    gg.log("处理获取技能列表请求",evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "GetSkillList")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end

    local skillList = {}
    local equippedSkills = {}
    -- 已拥有的技能
    for skillName, skill in pairs(player.skills or {}) do
        table.insert(skillList, {
            name = skillName,
            icon = skill.skillType.icon,
            level = skill.level,
            nextSkills = skill.skillType.nextSkills,
            maxLevel = skill.skillType.maxLevel,
            equipped = skill.equipSlot > 0,
            equipSlot = skill.equipSlot,
            description = skill:GetDescription()
        })
        -- 装备槽位信息
        if skill.equipSlot > 0 then
            equippedSkills[skill.equipSlot] = skillName
        end
    end
    
    -- 构建响应数据（包含树状结构）
    local responseData = {
        skills = skillList,
        equippedSkills = equippedSkills
    }
    gg.log("发送技能列表响应，包含", #skillList, "个技能")
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.LIST, responseData)
end

--- 处理学习技能请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleLearnSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "LearnSkill")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end
    
    -- 从evt中获取技能名称
    local skillName = evt.skillName or evt.skill
    if not skillName then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 验证技能是否存在
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_FOUND)
        return
    end
    
    -- 检查是否已学会
    if player.skills and player.skills[skillName] then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_ALREADY_LEARNED)
        return
    end
    
    -- TODO: 检查学习条件（前置技能、资源等）
    
    -- 创建技能实例
    if not player.skills then
        player.skills = {}
    end
    
    local skill = Skill.New(player, {
        skill = skillName,
        level = evt.level or 1,
        slot = 0
    })
    
    player.skills[skillName] = skill
    
    -- 保存数据
    player:saveSkillConfig()
    
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.LEARN, {
        skillName = skillName,
        level = skill.level
    })
    
    -- 发送技能变化通知
    SkillEventManager.NotifySkillChanged(evt, skillName, "learned")
end

--- 处理升级技能请求
---@param evt table 事件数据 {uin, skillName, targetLevel}
function SkillEventManager.HandleUpgradeSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UpgradeSkill")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end
    
    -- 从evt中提取参数
    local skillName = evt.skillName or evt.skill
    local targetLevel = evt.targetLevel or evt.level or (evt.currentLevel and evt.currentLevel + 1) or 1
    
    if not skillName or targetLevel < 1 then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 检查是否拥有该技能
    local skill = player.skills and player.skills[skillName]
    if not skill then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_LEARNED)
        return
    end
    
    -- 检查等级限制
    if targetLevel > skill.skillType.maxLevel then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.MAX_LEVEL_REACHED)
        return
    end
    
    if targetLevel <= skill.level then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- TODO: 检查升级资源
    
    -- 记录旧等级
    local oldLevel = skill.level
    
    -- 执行升级
    local success = skill:Upgrade(targetLevel)
    if success then
        player:saveSkillConfig()
        
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE, {
            skillName = skillName,
            oldLevel = oldLevel,
            newLevel = targetLevel
        })
        
        SkillEventManager.NotifySkillChanged(evt, skillName, "upgraded")
    else
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INSUFFICIENT_RESOURCES)
    end
end

--- 处理装备技能请求
---@param evt table 事件数据 {uin, skillName, slot}
function SkillEventManager.HandleEquipSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "EquipSkill")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end
    
    -- 从evt中提取参数
    local skillName = evt.skillName or evt.skill
    local slot = evt.slot or evt.slotIndex
    
    if not skillName or not slot or slot < 1 or slot > 6 then -- 假设最多6个技能槽
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 检查技能是否存在
    local skill = player.skills and player.skills[skillName]
    if not skill then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_LEARNED)
        return
    end
    
    -- 执行装备
    local success = player:EquipSkill(skillName, slot)
    if success then
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.EQUIP, {
            skillName = skillName,
            slot = slot
        })
        
        SkillEventManager.NotifySkillChanged(evt, skillName, "equipped")
    else
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SLOT_OCCUPIED)
    end
end

--- 处理卸下技能请求
---@param evt table 事件数据 {uin, slot}
function SkillEventManager.HandleUnequipSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UnequipSkill")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end
    
    -- 从evt中提取参数
    local slot = evt.slot or evt.slotIndex
    if not slot or slot < 1 or slot > 6 then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 获取当前装备的技能
    local equippedSkill = player.equippedSkills and player.equippedSkills[slot]
    if not equippedSkill then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_SLOT)
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
        
        SkillEventManager.NotifySkillChanged(evt, skillName, "unequipped")
    else
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_SLOT)
    end
end

--- 处理获取技能详情请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleGetSkillDetail(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "GetSkillDetail")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end
    
    -- 从evt中提取参数
    local skillName = evt.skillName or evt.skill
    if not skillName then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 获取技能配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        SkillEventManager.SendErrorResponse(evt, SkillEventManager.ERROR_CODES.SKILL_NOT_FOUND)
        return
    end
    
    -- 构建详情数据
    local detail = {
        name = skillName,
        displayName = skillType.displayName,
        description = skillType.description,
        maxLevel = skillType.maxLevel,
        isEntrySkill = skillType.isEntrySkill,
        owned = false,
        level = 0,
        equipped = false,
        equipSlot = 0
    }
    
    -- 如果玩家拥有该技能，添加实例数据
    local skill = player.skills and player.skills[skillName]
    if skill then
        detail.owned = true
        detail.level = skill.level
        detail.equipped = skill.equipSlot > 0
        detail.equipSlot = skill.equipSlot
        detail.description = skill:GetDescription()
    end
    
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.DETAIL, detail)
end

--- 处理获取可学习技能请求
---@param evt table 事件数据 {uin}
function SkillEventManager.HandleGetAvailableSkills(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "GetAvailableSkills")
    if not player then
        SkillEventManager.SendErrorResponse(evt, errorCode)
        return
    end
    
    local availableSkills = {}
    
    -- 获取入口技能
    for _, skillType in ipairs(SkillTypeConfig.GetEntrySkills()) do
        if not (player.skills and player.skills[skillType.skillName]) then
            table.insert(availableSkills, {
                name = skillType.skillName,
                displayName = skillType.displayName,
                description = skillType.description,
                maxLevel = skillType.maxLevel,
                isEntrySkill = true
            })
        end
    end
    
    -- 获取已有技能的后续技能
    if player.skills then
        for skillName, skill in pairs(player.skills) do
            if skill.skillType.nextSkills then
                for _, nextSkillType in ipairs(skill.skillType.nextSkills) do
                    if not player.skills[nextSkillType.skillName] then
                        table.insert(availableSkills, {
                            name = nextSkillType.skillName,
                            displayName = nextSkillType.displayName,
                            description = nextSkillType.description,
                            maxLevel = nextSkillType.maxLevel,
                            isEntrySkill = false,
                            prerequisite = skillName
                        })
                    end
                end
            end
        end
    end
    
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.AVAILABLE, {
        availableSkills = availableSkills
    })
end

return SkillEventManager