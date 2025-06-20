--- 技能事件管理器
--- 负责处理所有技能相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig
local SkillCommon = require(MainStorage.code.server.spells.SkillCommon) ---@type SkillCommon
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config


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

    gg.log("已注册 " .. 7 .. " 个技能事件处理器")
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
        return
    end

    -- 验证技能是否存在于配置中
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        gg.log("技能配置文件不存在: " .. skillName .. " 玩家: " .. player.name)
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
                return
            end
        else
            -- 非入口技能：检查父类技能是否存在
            local prerequisite = skillType.prerequisite or {}
            for i, preSkillType in ipairs(prerequisite) do
                if not (player.skills and player.skills[preSkillType.name]) then
                    gg.log("父类技能不存在，无法升级: " .. skillName .. " 缺少前置技能: " .. preSkillType.name)
                    return
                end
            end
        end

        -- 检查是否已达到最大等级
        if existingSkill and existingSkill.level >= skillType.maxLevel then
            gg.log("技能已达到最大等级: " .. skillName .. " 当前等级: " .. existingSkill.level)
            return
        end
    elseif skillType.category == 1 then
        -- 副卡技能：只检查技能是否存在
        if not existingSkill then
            gg.log("副卡技能不存在，无法升级: " .. skillName)
            return
        end

        -- 检查是否已达到最大等级
        if existingSkill.level >= skillType.maxLevel then
            gg.log("副卡技能已达到最大等级: " .. skillName .. " 当前等级: " .. existingSkill.level)
            return
        end
        -- 新增：检查副卡强化进度是否已满
        if skillType.GetMaxGrowthAtLevel then
            local currentLevel = existingSkill.level
            local currentGrowth = existingSkill.growth or 0
            local maxGrowthForLevel = skillType:GetMaxGrowthAtLevel(currentLevel)

            if maxGrowthForLevel and currentGrowth < maxGrowthForLevel then
                local message = "当前等级成长进度未满，无法强化"
                gg.log(string.format("副卡升级失败: %s. %s. 进度: %d/%d", skillName, message, currentGrowth, maxGrowthForLevel))
                player:SendHoverText(message)
                return
            end
        end
    else
        gg.log("未知的技能类型: " .. skillName .. " 类型: " .. (skillType.category or "nil"))
        return
    end

    -- TODO: 检查升级条件（资源、前置技能等级等）
    local cost = nil
    if existingSkill then
        cost = skillType:GetCostAtLevel(existingSkill.level+1)
        gg.log("升级成本", cost)
    else
        cost = skillType:GetCostAtLevel(1)
        gg.log("升级成本", cost)
    end

    -- 检查玩家资源是否足够
    if cost then
        local insufficientResources = {}  -- 记录不足的资源

        for resourceName, requiredAmount in pairs(cost) do
            local needAmount = math.ceil(math.abs(requiredAmount))  -- 对小数成本向上取整

            if needAmount > 0 then
                local itemData = player.bag:GetItemDataByName(resourceName)
                if not itemData or itemData.amount < needAmount then
                    table.insert(insufficientResources, {
                        name = resourceName,
                        need = needAmount,
                        have = itemData and itemData.amount or 0,
                        missing = needAmount - (itemData and itemData.amount or 0)
                    })
                else
                    gg.log("资源检查通过: " .. resourceName .. " 需要:" .. needAmount .. " 拥有:" .. itemData.amount)
                end
            end
        end

        -- 如果有资源不足，输出完整列表后返回
        if #insufficientResources > 0 then
            gg.log("=== 资源不足列表 ===")
            local messages = {}
            for i, resource in ipairs(insufficientResources) do
                gg.log(string.format("%d. %s: 需要 %d, 拥有 %d, 缺少 %d",
                    i, resource.name, resource.need, resource.have, resource.missing))
                table.insert(messages, string.format("%s缺少%d个", resource.name, resource.missing))
            end

            -- 向客户端发送友好提示
            local message = "技能升级失败，资源不足：" .. table.concat(messages, "，")
            player:SendHoverText(message)
            gg.log("技能升级失败，资源不足")
            return
        end

                -- 资源充足，扣除资源
        for resourceName, requiredAmount in pairs(cost) do
            local absAmount = math.ceil(math.abs(requiredAmount)) -- 对小数成本向上取整

            if absAmount > 0 then
                local itemData = player.bag:GetItemDataByName(resourceName)
                if not itemData then
                    gg.log("资源不存在: " .. resourceName)
                    return
                end
                -- 扣除对应数量的资源
                player.bag:SetItemAmount(itemData.position, itemData.amount - absAmount)
                gg.log("扣除资源: " .. resourceName .. " 数量:" .. absAmount)
            end
        end

        -- 扣除完成后，打印玩家背包中对应物品的剩余数量
        gg.log("=== 资源扣除后剩余数量 ===")
        for resourceName, requiredAmount in pairs(cost) do
            local itemData = player.bag:GetItemDataByName(resourceName)
            if itemData then
                gg.log(string.format("%s 剩余数量: %d", resourceName, itemData.amount))
            else
                gg.log(string.format("%s 剩余数量: 0 (已完全消耗)", resourceName))
            end
        end
    end
    -- 执行技能升级
    local success = player:UpgradeSkill(skillType)
    if not success then
        gg.log("技能升级失败: " .. skillName)
        return
    end

    local upgradedSkill = player.skills[skillName]
    -- 新增：如果是副卡，升级后重置强化进度
    if skillType.category == 1 then
        upgradedSkill.growth = 0
        gg.log("副卡升级后，重置强化进度为0: " .. skillName)
    end
    player:saveSkillConfig()
    player.bag:SyncToClient()

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

--- 处理一键强化技能请求
---@param evt table 事件数据 {uin, skillName, targetLevel}
function SkillEventManager.HandleUpgradeAllSkill(evt)
    gg.log("处理一键强化技能请求", evt)
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

    -- 验证目标等级
    if currentLevel >= targetLevel then
        gg.log("目标等级无效: 当前等级", currentLevel, "目标等级", targetLevel)
        return
    end

    if targetLevel > maxLevel then
        gg.log("目标等级超过最大等级: 目标", targetLevel, "最大", maxLevel)
        targetLevel = maxLevel  -- 限制到最大等级
    end

    gg.log("开始一键强化技能: " .. skillName .. " 从等级 " .. currentLevel .. " 到等级 " .. targetLevel)

    -- 一次性计算总升级成本
    local totalCost = {}
    for level = currentLevel + 1, targetLevel do
        local levelCost = skillType:GetCostAtLevel(level)
        if levelCost then
            for resourceName, amount in pairs(levelCost) do
                local consumeAmount = math.abs(amount)
                totalCost[resourceName] = (totalCost[resourceName] or 0) + consumeAmount
            end
        end
    end

    gg.log("一键强化总成本计算完成:", totalCost)

    -- 如果有消耗，进行资源检查和扣除
    if next(totalCost) then
        -- 第一步：检查所有资源是否充足
        local insufficientResources = {}
        local resourcesData = {}  -- 缓存资源数据，避免重复查询

        for resourceName, requiredAmount in pairs(totalCost) do
            local itemData = player.bag:GetItemDataByName(resourceName)
            resourcesData[resourceName] = itemData  -- 缓存数据

            if not itemData then
                table.insert(insufficientResources, {
                    name = resourceName,
                    need = requiredAmount,
                    have = 0,
                    missing = requiredAmount
                })
            elseif itemData.amount < requiredAmount then
                table.insert(insufficientResources, {
                    name = resourceName,
                    need = requiredAmount,
                    have = itemData.amount,
                    missing = requiredAmount - itemData.amount
                })
            end
        end

        -- 如果有任何资源不足，直接返回，不扣除任何资源
        if #insufficientResources > 0 then
            gg.log("=== 一键强化资源检查失败 ===")
            local messages = {}
            for i, resource in ipairs(insufficientResources) do
                gg.log(string.format("%d. %s: 需要 %d, 拥有 %d, 缺少 %d",
                    i, resource.name, resource.need, resource.have, resource.missing))
                table.insert(messages, string.format("%s缺少%d个", resource.name, resource.missing))
            end

            -- 向客户端发送友好提示
            local message = "一键强化失败，资源不足：" .. table.concat(messages, "，")
            player:SendHoverText(message)
            gg.log("一键强化失败，资源不足，未扣除任何资源")
            return
        end

        -- 第二步：所有资源充足，一次性扣除所有资源
        gg.log("=== 资源充足，开始一次性扣除所有资源 ===")
        for resourceName, requiredAmount in pairs(totalCost) do
            local itemData = resourcesData[resourceName]
            if itemData then
                -- 扣除对应数量的资源
                player.bag:SetItemAmount(itemData.position, itemData.amount - requiredAmount)
                gg.log("扣除资源: " .. resourceName .. " 数量:" .. requiredAmount)
            end
        end

        -- 第三步：打印扣除后的剩余数量
        gg.log("=== 一键强化资源扣除后剩余数量 ===")
        for resourceName, requiredAmount in pairs(totalCost) do
            local itemData = player.bag:GetItemDataByName(resourceName)
            if itemData then
                gg.log(string.format("%s 剩余数量: %d", resourceName, itemData.amount))
            else
                gg.log(string.format("%s 剩余数量: 0 (已完全消耗)", resourceName))
            end
        end

        gg.log("=== 资源扣除完成 ===")
    else
        gg.log("一键强化无需消耗资源")
    end

    -- 直接升级到目标等级
    existingSkill.level = targetLevel
    player:saveSkillConfig()
    player.bag:SyncToClient()

    gg.log("一键强化成功", skillName, "原等级:", currentLevel, "最终等级:", targetLevel)

    -- 发送响应
    local responseData = {
        skillName = skillName,
        originalLevel = currentLevel,
        finalLevel = targetLevel,
        level = targetLevel, -- 保持向后兼容
        slot = existingSkill.equipSlot,
        maxLevel = maxLevel
    }
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE, responseData)
end

--- 执行一键强化逻辑
---@param player Player 玩家对象
---@param skillType SkillType 技能配置
---@param skill table 技能实例
---@return table 升级结果 {finalLevel, errorCode, resourcesUsed}
function SkillEventManager.PerformUpgradeAll(player, skillType, skill)
    local currentLevel = skill.level
    local maxLevel = skillType.maxLevel or 1
    local finalLevel = currentLevel
    local resourcesUsed = {}
    local errorCode = SkillEventManager.ERROR_CODES.SUCCESS

    gg.log("执行一键强化:", skillType.name, "当前等级:", currentLevel, "目标等级:", maxLevel)

    -- 计算总升级成本
    local totalCost = {}

    for level = currentLevel + 1, maxLevel do
        -- 使用SkillType:GetCostAtLevel函数计算每一级的消耗
        local levelCosts = skillType:GetCostAtLevel(level)
        if levelCosts then
            for resourceType, amount in pairs(levelCosts) do
                totalCost[resourceType.name] = (totalCost[resourceType.name] or 0) + amount
            end
        end
    end

    gg.log("计算总升级成本:", totalCost)

    -- 检查玩家资源是否足够
    local canAffordAll = true
    for resourceTypeName, requiredAmount in pairs(totalCost) do
        local playerAmount = player.resources and player.resources[resourceTypeName] or 0
        if playerAmount < requiredAmount then
            gg.log("资源不足:", resourceTypeName, "需要:", requiredAmount, "拥有:", playerAmount)
            canAffordAll = false
            break
        end
    end

    if canAffordAll then
        -- 资源充足，直接升级到满级
        gg.log("资源充足，直接升级到满级")

        -- 扣除资源
        for resourceTypeName, amount in pairs(totalCost) do
            if player.resources and player.resources[resourceTypeName] then
                player.resources[resourceTypeName] = player.resources[resourceTypeName] - amount
                resourcesUsed[resourceTypeName] = amount
            end
        end

        -- 升级到满级
        skill.level = maxLevel
        finalLevel = maxLevel
        errorCode = SkillEventManager.ERROR_CODES.SUCCESS

        gg.log("一键强化成功，技能升级到满级:", maxLevel)
    else
        -- 资源不足，直接失败
        gg.log("资源不足，无法升级")
        finalLevel = currentLevel
        errorCode = SkillEventManager.ERROR_CODES.INSUFFICIENT_RESOURCES
    end

    return {
        finalLevel = finalLevel,
        errorCode = errorCode,
        resourcesUsed = resourcesUsed
    }
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
            gg.log("槽位没有装备技能:", slot)
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

        local responseData = {
            skillName = skillName,
            slot = 0, -- 卸下后槽位为0
            level = player.skills[skillName].level
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

    -- 获取当前星级
    local currentStar = existingSkill.star_level or 0
    local maxStar = 7

    -- 检查是否已达到最大星级
    if currentStar >= maxStar then
        gg.log("技能已达到最大星级: " .. skillName .. " 当前星级: " .. currentStar)
        return
    end

    -- 执行升星逻辑
    existingSkill.star_level = currentStar + 1
    player:saveSkillConfig()

    gg.log("技能升星成功", skillName, "新星级:", existingSkill.star_level)

    local responseData = {
        skillName = skillName,
        star_level = existingSkill.star_level,
        level = existingSkill.level,
        slot = existingSkill.equipSlot or 0
    }

    gg.log("发送技能升星响应", responseData)
    SkillEventManager.SendSuccessResponse(evt, SkillEventManager.RESPONSE.UPGRADE_STAR, responseData)
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

return SkillEventManager
