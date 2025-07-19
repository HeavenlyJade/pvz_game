--- 技能事件管理器
--- 负责处理所有技能相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local SkillTypeConfig = require(MainStorage.config.SkillTypeConfig) ---@type SkillTypeConfig
local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig
local SkillCommon = require(MainStorage.code.server.spells.SkillCommon) ---@type SkillCommon
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local MiscConfig = require(MainStorage.config.MiscConfig) ---@type MiscConfig


---@class SkillEventManager
local SkillEventManager = {}

-- 将配置从event_skill.lua导入到当前模块
SkillEventManager.REQUEST = SkillEventConfig.REQUEST
SkillEventManager.RESPONSE = SkillEventConfig.RESPONSE
SkillEventManager.NOTIFY = SkillEventConfig.NOTIFY
SkillEventManager.ERROR_CODES = SkillEventConfig.ERROR_CODES
SkillEventManager.ERROR_MESSAGES = SkillEventConfig.ERROR_MESSAGES

-- === 新增：副卡槽位到UI卡片节点的映射 ===
SkillEventManager.SLOT_TO_CARD_MAPPING = {
    [2] = "卡片_1",  -- 副卡1对应卡片_1
    [3] = "卡片_2",  -- 副卡2对应卡片_2
    [4] = "卡片_3",  -- 副卡3对应卡片_3
    [5] = "卡片_4"   -- 副卡4对应卡片_4
}

SkillEventManager.StarLevelRequirements = {
    [0] = 10,   -- 0星 -> 1星需要10级
    [1] = 15,   -- 1星 -> 2星需要15级
    [2] = 25,   -- 2星 -> 3星需要25级
    [3] = 35,   -- 3星 -> 4星需要35级
    [4] = 50,   -- 4星 -> 5星需要50级
    [5] = 70,   -- 5星 -> 6星需要70级
    [6] = 100   -- 6星 -> 7星需要100级
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
    -- 学习技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.LEARN, SkillEventManager.HandleLearnSkill)

    -- 升级技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UPGRADE, SkillEventManager.HandleUpgradeSkill)

    -- 一键强化技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UPGRADE_ALL, SkillEventManager.HandleUpgradeAllSkill)

    -- 升星技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UPGRADE_STAR, SkillEventManager.HandleUpgradeStarSkill)

    -- 装备技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.EQUIP, SkillEventManager.HandleEquipSkill)

    -- 卸下技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.UNEQUIP, SkillEventManager.HandleUnequipSkill)

    -- 销毁技能
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.DESTROY, SkillEventManager.HandleDestroySkill)

    -- 同步技能数据
    ServerEventManager.Subscribe(SkillEventManager.REQUEST.SYNC_SKILLS, SkillEventManager.HandleSyncSkills)

end

--- 验证玩家和基础参数
---@param evt table 事件参数
---@param eventName string 事件名称
---@return Player|nil, number 玩家对象和错误码
function SkillEventManager.ValidatePlayer(evt, eventName)
    local env_player = evt.player
    local uin = env_player.uin
    gg.log("env_player", env_player, uin)
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



--[[
===================================
客户端请求处理部分 - 处理客户端事件
===================================
]]

--- 处理技能学习请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleLearnSkill(evt)
    gg.log("处理学习技能请求", evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "LearnSkill")
    if not player then
        return
    end

    -- 从evt中获取技能名称
    local skillName = evt.skillName
    if not skillName then
        gg.log("技能名称不能为空")
        return
    end

    -- 验证技能是否存在
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
        return
    end

    -- 检查玩家是否已拥有该技能
    local existingSkill = player.skills and player.skills[skillName]
    if existingSkill then
        gg.log("玩家已拥有该技能: " .. skillName)
        return
    end

    -- TODO: 检查学习条件（前置技能、资源等）

    -- 创建并学习新技能
    local success = player:LearnSkill(skillType)
    if not success then
        gg.log("技能学习失败: " .. skillName)
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

-- 星级等级上限校验函数
--- 检查技能是否超过当前星级允许的最大等级
---@param skill table 技能实例
---@param skillType table 技能类型配置
---@param addLevel number|nil 升级增量，默认为1
---@return table 校验结果
function SkillEventManager.CheckStarLevelLimit(skill, skillType, addLevel)
    addLevel = addLevel or 1
    local currentStar = skill.star_level or 0
    local currentLevel = skill.level or 0
    local maxLevel = skillType.maxLevel or 1
    local starLevelLimit = SkillEventManager.StarLevelRequirements[currentStar] or maxLevel
    local overLimit = (currentLevel + addLevel) > starLevelLimit
    return {
        overLimit = overLimit,
        currentStar = currentStar,
        starLevelLimit = starLevelLimit,
        currentLevel = currentLevel,
        addLevel = addLevel
    }
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
        player:SendHoverText("技能升级失败：技能名称不能为空")
        return
    end
    -- 验证技能是否存在于配置中
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
        player:SendHoverText("技能升级失败：技能配置不存在")
        return
    end
    local existingSkill = player.skills and player.skills[skillName]

    -- 根据技能类型进行不同的检查
    if skillType.category == 0 then
        -- 主卡技能：根据是否为入口技能进行不同的检查
        if skillType.isEntrySkill then
            -- 入口技能：检查技能本身是否存在
            if not existingSkill then
                gg.log("入口技能不存在，无法升级: " .. skillName)
                player:SendHoverText("技能升级失败：未学习该主卡技能")
                return
            end
        else
            -- 非入口技能：检查父类技能是否存在
            local prerequisite = skillType.prerequisite or {}
            for i, preSkillType in ipairs(prerequisite) do
                if not (player.skills and player.skills[preSkillType.name]) then
                    gg.log("父类技能不存在，无法升级: " .. skillName .. " 缺少前置技能: " .. preSkillType.name)
                    player:SendHoverText("技能升级失败：缺少前置技能 " .. (preSkillType.displayName or preSkillType.name))
                    return
                end
            end
        end
        -- 检查是否已达到最大等级
        if existingSkill and existingSkill.level >= skillType.maxLevel then
            gg.log("技能已达到最大等级: " .. skillName .. " 当前等级: " .. existingSkill.level)
            player:SendHoverText("技能升级失败：已达最大等级")
            return
        end
    elseif skillType.category == 1 then
        -- 副卡技能：只检查技能是否存在
        if not existingSkill then
            gg.log("副卡技能不存在，无法升级: " .. skillName)
            player:SendHoverText("技能升级失败：未学习该副卡技能")
            return
        end
        -- 检查是否已达到最大等级
        if existingSkill.level >= skillType.maxLevel then
            gg.log("副卡技能已达到最大等级: " .. skillName .. " 当前等级: " .. existingSkill.level)
            player:SendHoverText("技能升级失败：已达最大等级")
            return
        elseif existingSkill.growth < existingSkill.skillType:GetMaxGrowthAtLevel(existingSkill.level) then
            player:SendHoverText("技能升级失败：成长值不足，快去花圃挂机培养副卡吧")
            return
        end
    else
        gg.log("未知的技能类型: " .. skillName .. " 类型: " .. (skillType.category or "nil"))
        player:SendHoverText("技能升级失败：未知的技能类型")
        return
    end

    -- 星级等级上限校验
    if existingSkill then
        local check = SkillEventManager.CheckStarLevelLimit(existingSkill, skillType, 1)
        if check.overLimit then
            local displayName = skillType.displayName or skillName
            player:SendHoverText(string.format("%s当前星级上限强化等级为%d级，请先升星", displayName, check.starLevelLimit))
            gg.log("技能升级失败：超过当前星级等级上限", skillName, "当前星级：", check.currentStar, "最大等级：", check.starLevelLimit)
            return
        end
    end

    local cost = nil
    if existingSkill then
        cost = skillType:GetCostAtLevel(existingSkill.level+1)
        gg.log("升级成本", cost)
    else
        cost = skillType:GetCostAtLevel(1)
        gg.log("升级成本", cost)
    end
     -- 检查玩家资源是否足够
    if cost and next(cost) then
        if not player.bag:HasItems(cost) then
            local shortageInfo = player.bag:GetResourceShortageInfo(cost)
            if shortageInfo then
                local messages = {}
                for _, resource in ipairs(shortageInfo) do
                    table.insert(messages, string.format("【%s】缺少%d个", resource.displayName, resource.missing))
                end
                player:SendHoverText("技能升级失败：" .. table.concat(messages, "，"))
            end
            return
        end
        player.bag:RemoveItems(cost)
    end
    if existingSkill then
        existingSkill.growth = math.max(0, existingSkill.growth - existingSkill.skillType:GetMaxGrowthAtLevel(existingSkill.level))
    end
    -- 执行技能升级
    local success = player:UpgradeSkill(skillType)
    if not success then
        gg.log("技能升级失败: " .. skillName)
        player:SendHoverText("技能升级失败：未知原因")
        return
    end
    local upgradedSkill = player.skills[skillName]
    player:saveSkillConfig()
    player.bag:SyncToClient()
    gg.log("技能升级成功", skillName, "新等级:", upgradedSkill.level, "装备槽:", upgradedSkill.equipSlot)
    local responseData = {
        skillName = skillName,
        level = upgradedSkill.level,
        slot = upgradedSkill.equipSlot,
        maxLevel = skillType.maxLevel,
        growth = upgradedSkill.growth
    }
    -- 播放升级音效
    local misc = MiscConfig.Get("总控")
    if skillType.category == 0 then
        if skillType.activeSpell then
            player:PlaySound(misc["主动技能升级音效"])
        else
            player:PlaySound(misc["被动技能升级音效"])
        end
    else
        player:PlaySound(misc["次要技能升级音效"])
    end
    gg.log("发送技能升级响应", responseData)
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE, responseData)
end

--- 处理一键强化技能请求
---@param evt table 事件数据 {uin, skillName, targetLevel}
function SkillEventManager.HandleUpgradeAllSkill(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UpgradeAllSkill")
    if not player then
        return
    end

    -- 从evt中获取参数
    local skillName = evt.skillName
    local targetLevel = evt.targetLevel

    if not skillName then
        gg.log("技能名称不能为空")
        return
    end

    if not targetLevel or targetLevel <= 0 then
        gg.log("目标等级无效:", targetLevel)
        return
    end

    -- 验证技能是否存在于配置中
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
        return
    end

    -- 检查玩家是否拥有该技能
    local existingSkill = player.skills and player.skills[skillName]
    if not existingSkill then
        gg.log("玩家不拥有该技能: " .. skillName)
        return
    end

    local currentLevel = existingSkill.level
    local maxLevel = skillType.maxLevel or 1
    local nextLevel = currentLevel + 1

    -- 新增：星级等级上限校验
    local check = SkillEventManager.CheckStarLevelLimit(existingSkill, skillType, 1)
    gg.log("nextLevel", nextLevel, check.starLevelLimit)
    if check.overLimit then
        local displayName = skillType.displayName or skillName
        player:SendHoverText(string.format("%s当前星级上限强化等级为%d级，请先升星", displayName, check.starLevelLimit))
        gg.log("技能强化失败：超过当前星级等级上限", skillName, "当前星级：", check.currentStar, "最大等级：", check.starLevelLimit)
        return
    end

    -- 验证目标等级（现在只处理下一级）
    if currentLevel >= maxLevel then
        gg.log("技能已达最大等级: 当前等级", currentLevel, "最大等级", maxLevel)
        player:SendHoverText("技能已达最大等级，无法继续升级")
        return
    end

    if targetLevel ~= nextLevel then
        gg.log("一键强化只支持升级到下一级: 当前等级", currentLevel, "目标等级", targetLevel, "应为", nextLevel)
        targetLevel = nextLevel  -- 强制设置为下一级
    end

    gg.log("开始一键强化技能: " .. skillName .. " 从等级 " .. currentLevel .. " 到等级 " .. targetLevel)

    -- 检查下一级是否有一键强化配置
    local nextLevelCost = skillType:GetOneKeyUpgradeCostsAtLevel(nextLevel)
    if not nextLevelCost or not next(nextLevelCost) then
        local displayName = skillType.displayName or skillName
        player:SendHoverText(string.format("【%s】未配置一键强化资源，该技能暂不支持一键强化功能", displayName))
        gg.log("❌ 服务端检查：技能未配置一键强化资源:", skillName, "等级:", nextLevel)
        return
    end

    -- 检查是否有实际的资源消耗
    local hasActualResourceCost = false
    local processedCost = {}

    for resourceName, amount in pairs(nextLevelCost) do
        local consumeAmount = math.abs(amount)
        if consumeAmount > 0 then
            hasActualResourceCost = true
            processedCost[resourceName] = consumeAmount
        end
    end

    if not hasActualResourceCost then
        local displayName = skillType.displayName or skillName
        player:SendHoverText(string.format("【%s】一键强化配置无实际资源消耗，请使用单次强化按钮", displayName))
        gg.log("❌ 服务端检查：技能配置了一键强化但无实际资源消耗:", skillName, "等级:", nextLevel)
        return
    end

    gg.log("下一级一键强化成本:", processedCost)

    -- 进行资源检查和扣除
    if next(processedCost) then
        -- 统一资源检查逻辑，和升星一致
        if not player.bag:HasItems(processedCost) then
            gg.log("=== 一键强化资源检查失败 ===")
            local shortageInfo = player.bag:GetResourceShortageInfo(processedCost)
            if shortageInfo then
                local messages = {}
                for _, resource in ipairs(shortageInfo) do
                    table.insert(messages, string.format("【%s】缺少%d个", resource.displayName, resource.missing))
                end
                player:SendHoverText("一键强化失败，资源不足" .. table.concat(messages, "，"))
                return
            end
        end
        -- 所有资源充足，扣除资源
        gg.log("=== 资源充足，开始扣除下一级所需资源 ===")
        player.bag:RemoveItems(processedCost)
        gg.log("=== 资源扣除完成 ===")
    else
        gg.log("一键强化无需消耗资源")
        return 
    end

    -- 升级到下一级
    existingSkill.level = targetLevel
    player:saveSkillConfig()
    player.bag:SyncToClient()

    gg.log("一键强化成功", skillName, "原等级:", currentLevel, "最终等级:", targetLevel)

    -- 播放升级音效
    local misc = MiscConfig.Get("总控")
    if skillType.category == 0 then
        if skillType.activeSpell then
            player:PlaySound(misc["主动技能升级音效"])
        else
            player:PlaySound(misc["被动技能升级音效"])
        end
    else
        player:PlaySound(misc["次要技能升级音效"])
    end

    -- 发送响应
    local responseData = {
        skillName = skillName,
        originalLevel = currentLevel,
        finalLevel = targetLevel,
        level = targetLevel, -- 保持向后兼容
        slot = existingSkill.equipSlot,
        maxLevel = maxLevel,
        growth = existingSkill.growth
    }
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE, responseData)
end

--- 处理装备技能请求
---@param evt table 事件数据 {uin, skillName, slot}
function SkillEventManager.HandleEquipSkill(evt)
    gg.log("处理装备技能请求", evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "EquipSkill")
    if not player then
        return
    end
    gg.log("处理装备技能请求", player, errorCode)

    -- 从evt中提取参数
    local skillName = evt.skillName or evt.skill
    local slot = evt.slot or evt.slotIndex

    -- 参数验证
    if not skillName then
        gg.log("技能名称不能为空")
        return
    end

    -- 1. 判断玩家技能是否存在，不存在就返回并打印日志
    local skill = player.skills and player.skills[skillName]
    if not skill then
        gg.log("玩家技能不存在: " .. skillName .. " 玩家: " .. player.name)
        return
    end

    -- 获取技能类型配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置不存在: " .. skillName)
        return
    end

    -- 检查技能是否可装备
    if not skillType.isEquipable then
        gg.log("该技能不可装备: " .. skillName)
        player:SendHoverText("该技能为被动技能，无需装备")
        return
    end

    -- 2. 判断是否是主卡技能，如果是主卡技能，就获取主卡的配置，然后替换卡槽
    if skillType.category == 0 then -- 主卡技能
        gg.log("检测到主卡技能: " .. skillName .. ", 获取主卡配置进行槽位替换")

        -- 获取主卡配置
        local mainCardConfig = common_config.EquipmentSlot["主卡"]
        if not mainCardConfig then
            gg.log("主卡配置不存在")
            return
        end

        -- 遍历主卡配置，找到第一个可用的主卡槽位
        local mainCardSlot = nil
        for slotId, slotName in pairs(mainCardConfig) do
            mainCardSlot = slotId
            break -- 取第一个主卡槽位
        end

        if not mainCardSlot then
            gg.log("没有找到可用的主卡槽位")
            return
        end
        -- 使用主卡槽位替换原来的slot参数
        slot = mainCardSlot
        gg.log("主卡技能使用槽位: " .. slot .. " (" .. mainCardConfig[slot] .. ")")
    else
        -- 副卡技能，获取副卡配置并自动分配槽位
        gg.log("检测到副卡技能: " .. skillName .. ", 获取副卡配置进行槽位分配")

        -- 1. 获取副卡配置
        local subCardConfig = common_config.EquipmentSlot["副卡"]
        if not subCardConfig then
            gg.log("副卡配置不存在")
            return
        end

        -- 2. 获取副卡key的list并排序（从小到大）
        local subCardSlots = {}
        for slotId, slotName in pairs(subCardConfig) do
            table.insert(subCardSlots, slotId)
        end
        table.sort(subCardSlots) -- 按槽位ID从小到大排序

        gg.log("副卡槽位列表:", subCardSlots)

        -- 3. 检查玩家的equippedSkills是否有空位
        local availableSlot = nil
        local maxSlot = nil

        -- 遍历所有副卡槽位，寻找空位
        for _, slotId in ipairs(subCardSlots) do
            maxSlot = slotId -- 记录最大槽位
            if not player.equippedSkills[slotId] then
                -- 找到空位，优先使用槽位小的
                availableSlot = slotId
                gg.log("找到空副卡槽位:", availableSlot, "(" .. subCardConfig[availableSlot] .. ")")
                break
            end
        end

        -- 4. 如果没有空位，使用最大槽位
        if not availableSlot then
            availableSlot = maxSlot
            gg.log("没有空副卡槽位，使用最大槽位:", availableSlot, "(" .. subCardConfig[availableSlot] .. ")")
        end

        if not availableSlot then
            gg.log("没有找到可用的副卡槽位")
            return
        end

        -- 使用分配的副卡槽位
        slot = availableSlot
        gg.log("副卡技能使用槽位: " .. slot .. " (" .. subCardConfig[slot] .. ")")
    end

    -- 执行装备
    local success = player:EquipSkill(skillName, slot)
    if success then
        gg.log("技能装备成功: " .. skillName .. " 槽位: " .. slot)
        -- 播放装备音效
        local misc = MiscConfig.Get("总控")
        player:PlaySound(misc["技能装备音效"])
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.EQUIP, {
            skillName = skillName,
            slot = slot
        })
    else
        gg.log("技能装备失败: " .. skillName .. " 槽位: " .. slot)
    end
end

--- 处理卸下技能请求
---@param evt table 事件数据 {uin, skillName} 或 {uin, slot}
function SkillEventManager.HandleUnequipSkill(evt)
    gg.log("处理卸下技能请求", evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UnequipSkill")
    if not player then
        return
    end

    local skillName = evt.skillName
    local slot = evt.slot or evt.slotIndex

    -- 优先使用 skillName 参数
    if skillName then
        gg.log("通过技能名称卸下装备:", skillName)

        -- 验证技能是否存在
        local skill = player.skills and player.skills[skillName]
        if not skill then
            gg.log("玩家技能不存在: " .. skillName .. " 玩家: " .. player.name)
            return
        end

        -- 检查技能是否已装备
        if skill.equipSlot == 0 then
            gg.log("技能未装备，无法卸下: " .. skillName)
            return
        end

        slot = skill.equipSlot
        gg.log("找到技能装备槽位:", skillName, "槽位:", slot)


        -- 获取当前装备的技能
        local equippedSkill = player.equippedSkills and player.equippedSkills[slot]
        if not equippedSkill then
            gg.log("槽位没有装备技能:", slot, player.equippedSkills)
            return
        end

    else
        gg.log("缺少必要参数: skillName 或 slot")
        return
    end

    -- 执行卸下操作
    local success = player:UnequipSkill(slot)
    if success then
        player:saveSkillConfig()

        gg.log("技能卸下成功:", skillName, "槽位:", slot)
        local misc = MiscConfig.Get("总控")
        player:PlaySound(misc["技能卸下音效"])

        -- === 新增：根据槽位获取对应的UI卡片名称 ===
        local cardName = SkillEventManager.SLOT_TO_CARD_MAPPING[slot]
        gg.log("槽位", slot, "对应的UI卡片:", cardName)

        local responseData = {
            skillName = skillName,
            slot = 0, -- 卸下后槽位为0
            level = player.skills[skillName].level,
            unslot = slot,
            cardName = cardName  -- 新增：发送对应的UI卡片名称
        }

        gg.log("发送技能卸下响应", responseData)
        SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UNEQUIP, responseData)
    else
        gg.log("技能卸下失败:", skillName, "槽位:", slot)
    end
end

--- 处理升星技能请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleUpgradeStarSkill(evt)
    gg.log("处理升星技能请求", evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "UpgradeStarSkill")
    if not player then
        return
    end

    -- 从evt中获取技能名称
    local skillName = evt.skillName
    if not skillName then
        gg.log("技能名称不能为空")
        player:SendHoverText("升星失败：技能名称不能为空")
        return
    end

    -- 验证技能是否存在于配置中
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
        player:SendHoverText("升星失败：技能配置不存在")
        return
    end

    -- 检查玩家是否拥有该技能
    local existingSkill = player.skills and player.skills[skillName]
    if not existingSkill then
        gg.log("玩家不拥有该技能: " .. skillName)
        player:SendHoverText("升星失败：未学习该技能")
        return
    end

    -- 获取当前星级和等级
    local currentStar = existingSkill.star_level
    local currentLevel = existingSkill.level
    local maxStar = 7

    -- 检查是否已达到最大星级
    if currentStar >= maxStar then
        gg.log("技能已达到最大星级: " .. skillName .. " 当前星级: " .. currentStar)
        player:SendHoverText("升星失败：已达最大星级")
        return
    end



    -- 检查等级是否满足升星要求
    local requiredLevel = SkillEventManager.StarLevelRequirements[currentStar]
    if not requiredLevel then
        gg.log("未定义的星级要求:", currentStar)
        player:SendHoverText("升星失败：未定义的星级要求")
        return
    end

    if currentLevel < requiredLevel then
        gg.log("等级不足，无法升星:", skillName, "当前等级:", currentLevel, "需要等级:", requiredLevel, "当前星级:", currentStar)
        player:SendHoverText(string.format("升星失败：需要达到%d级才能升到%d星，当前等级：%d", requiredLevel, currentStar + 1, currentLevel))
        return
    end

    -- 检查是否配置了升星需求素材
    local starCosts = skillType:GetStarUpgradeCostAtLevel(existingSkill.level)
    if not starCosts or not next(starCosts) then
        gg.log("该技能未配置升星需求素材 (nil 或空表):", skillName,starCosts)
        player:SendHoverText("升星失败：该技能未配置升星需求")
        return
    end

    gg.log("升星素材需求:", starCosts)

    -- 检查玩家资源是否足够
    if not player.bag:HasItems(starCosts) then
        local shortageInfo = player.bag:GetResourceShortageInfo(starCosts)
        if shortageInfo then
            local messages = {}
            for _, resource in ipairs(shortageInfo) do
                table.insert(messages, string.format("【%s】缺少%d个", resource.displayName, resource.missing))
            end
            player:SendHoverText("升星失败：升星素材不足，" .. table.concat(messages, "，"))
        else
            player:SendHoverText("升星失败：升星素材不足")
        end
        return
    end

    -- 扣除升星素材
    player.bag:RemoveItems(starCosts)

    -- 执行升星逻辑：升星并重置等级和成长进度
    existingSkill.star_level = currentStar + 1
    existingSkill.level = 0  -- 重置等级为0
    existingSkill.growth = 0  -- 重置成长进度为0

    player:saveSkillConfig()
    player.bag:SyncToClient()

    gg.log("技能升星成功", skillName, "新星级:", existingSkill.star_level, "等级重置为:", existingSkill.level, "成长进度重置为:", existingSkill.growth)

    -- 使用 HandleUpgradeSkill 的响应事件格式
    local responseData = {
        skillName = skillName,
        level = existingSkill.level,  -- 重置后的等级（0）
        slot = existingSkill.equipSlot or 0,
        maxLevel = skillType.maxLevel,
        growth = existingSkill.growth,  -- 重置后的成长进度（0）
        star_level = existingSkill.star_level  -- 新的星级
    }

    -- 播放升级音效
    local misc = MiscConfig.Get("总控")
    if skillType.category == 0 then
        if skillType.activeSpell then
            player:PlaySound(misc["主动技能升级音效"])
        else
            player:PlaySound(misc["被动技能升级音效"])
        end
    else
        player:PlaySound(misc["次要技能升级音效"])
    end

    gg.log("发送技能升级响应（升星）", responseData)
    -- 使用 UPGRADE 响应事件而不是 UPGRADE_STAR，这样会触发 HandleUpgradeSkill 的客户端响应处理
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE, responseData)
end

--- 处理销毁技能请求
---@param evt table 事件数据 {uin, skillName}
function SkillEventManager.HandleDestroySkill(evt)
    gg.log("处理销毁技能请求", evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "DestroySkill")
    if not player then
        return
    end

    -- 从evt中获取参数
    local skillName = evt.skillName

    -- 使用SkillCommon的验证方法
    local skillType, skillInstance, errorCode = SkillCommon.ValidateSkillAndPlayer(player, skillName)

    if errorCode ~= SkillEventManager.ERROR_CODES.SUCCESS then
        gg.log("技能验证失败: " .. skillName .. " 错误: " .. SkillEventConfig.GetErrorMessage(errorCode))
        return
    end

    gg.log("开始销毁技能: " .. skillName)

    -- 执行销毁逻辑
    local destroyResult = SkillCommon.PerformSkillDestroy(player, skillName)

    if destroyResult.success then
        -- 保存玩家数据
        player:saveSkillConfig()

        -- 同步最新的技能数据到客户端
        player:syncSkillData()

        gg.log("技能销毁成功", skillName, "同时销毁的技能:", table.concat(destroyResult.destroyedSkills, ", "))
    else
        gg.log("技能销毁失败:", skillName, "错误:", destroyResult.errorCode)
    end
end

--- 处理同步技能数据请求
---@param evt table 事件数据 {uin}
function SkillEventManager.HandleSyncSkills(evt)
    local player, errorCode = SkillEventManager.ValidatePlayer(evt, "SyncSkills")
    if not player then
        return
    end
    -- 直接调用玩家的技能数据同步方法
    player:syncSkillData()

end

return SkillEventManager
