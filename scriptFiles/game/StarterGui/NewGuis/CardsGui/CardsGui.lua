local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local SkillTypeUtils = require(MainStorage.code.common.conf_utils.SkillTypeUtils) ---@type SkillTypeUtils
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig
local CardIcon = require(MainStorage.code.common.ui_icon.card_icon) ---@type CardIcon
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig)



local gg = require(MainStorage.code.common.MGlobal)   ---@type gg


local uiConfig = {
    uiName = "CardsGui",
    layer = 3,
    hideOnInit = true,
    qualityList = CardIcon.qualityList,
    qualityListMap = CardIcon.qualityListMap,
    qualityPriority = CardIcon.qualityPriority,
    qualityDefIcon = CardIcon.qualityDefIcon,
    qualityClickIcon = CardIcon.qualityClickIcon,
    qualityBaseMapDefIcon = CardIcon.qualityBaseMapDefIcon,
    qualityBaseMapClickIcon = CardIcon.qualityBaseMapClickIcon,
    mianCard ="主卡",
    Subcard = "副卡"
}

---@class CardsGui:ViewBase
local CardsGui = ClassMgr.Class("CardsGui", ViewBase)


ClientEventManager.Subscribe("PressKey", function (evt)
    if evt.key == Enum.KeyCode.K.Value and not ViewBase.topGui then
        ViewBase.GetUI("CardsGui"):Open()
    end
end)

-- 通用按钮状态管理
function CardsGui:_updateButtonGrayState(button, isUnlocked)
    if button and button.img then
        button.img.Grayed = not isUnlocked
    end
end

-- 通用按钮创建
function CardsGui:_createButtonWithCallback(node, clickCallback, extraParams, backgroundPath)
    local button = ViewButton.New(node, self, nil, backgroundPath or "卡框背景")
    button.extraParams = extraParams or {}
    button:SetTouchEnable(true)
    button.clickCb = clickCallback
    return button
end

-- 通用技能数据更新
function CardsGui:_updateSkillData(skillName, level, slot, starLevel)
    local skillData = self.ServerSkills[skillName]
    if skillData then
        skillData.level = level
        if slot then skillData.slot = slot end
        if starLevel then skillData.star_level = starLevel end
    else
        self.ServerSkills[skillName] = {
            level = level,
            slot = slot or 0,
            skill = skillName,
            star_level = starLevel or 0
        }
    end

    -- 更新装备槽
    if slot and slot > 0 then
        self.equippedSkills[slot] = skillName
    end
end


function CardsGui:_setCardIcon(cardFrame, resourceTable)
    if not resourceTable or type(resourceTable) ~= "table" then
        return
    end

    local iconPath = resourceTable.iconPath
    local iconNodePath = resourceTable.iconNodePath or "卡框背景/图标"

    if not iconPath or iconPath == "" then
        return
    end

    -- 解析节点路径
    local pathParts = {}
    for part in string.gmatch(iconNodePath, "[^/]+") do
        table.insert(pathParts, part)
    end

    -- 找到目标图标节点
    local iconNode = cardFrame
    for _, part in ipairs(pathParts) do
        iconNode = iconNode[part]
        if not iconNode then
            -- gg.log("❌ _setCardIcon: 找不到节点路径:", iconNodePath)
            return
        end
    end

    -- === 新增：避免重复设置相同资源 ===
    local finalIcon = resourceTable.normalIcon or iconPath

    -- 检查是否需要更新图标
    if iconNode.Icon ~= finalIcon then
        iconNode.Icon = finalIcon
        -- gg.log("✅ 设置基础图标:", finalIcon, "路径:", iconNodePath)
    end

    -- 设置点击图标（检查重复）
    if resourceTable.clickIcon and resourceTable.clickIcon ~= "" then
        local currentClickIcon = iconNode:GetAttribute("图片-点击")
        if currentClickIcon ~= resourceTable.clickIcon then
            iconNode:SetAttribute("图片-点击", resourceTable.clickIcon)
        else
        end
    else
    end

    -- 设置悬浮图标（检查重复）
    if resourceTable.hoverIcon and resourceTable.hoverIcon ~= "" then
        local currentHoverIcon = iconNode:GetAttribute("图片-悬浮")
        if currentHoverIcon ~= resourceTable.hoverIcon then
            iconNode:SetAttribute("图片-悬浮", resourceTable.hoverIcon)
        else
        end
    else
    end

    -- 设置自定义属性（检查重复）
    if resourceTable.attributes and type(resourceTable.attributes) == "table" then
        for attrName, attrValue in pairs(resourceTable.attributes) do
            if attrValue and attrValue ~= "" then
                local currentValue = iconNode:GetAttribute(attrName)
                if currentValue ~= attrValue then
                    iconNode:SetAttribute(attrName, attrValue)
                    -- gg.log("✅ 设置自定义属性:", attrName, "值:", attrValue)
                end
            end
        end
    end
end

function CardsGui:_setCardName(cardFrame, name, nameNodePath)
    local nameNode = cardFrame[nameNodePath or "技能名"]
    if nameNode then
        nameNode.Title = name
    end
end

function CardsGui:_setCardLevel(cardFrame, currentLevel, maxLevel, levelNodePath)
    local levelNode = cardFrame[levelNodePath or "等级"]
    if levelNode then
        levelNode.Title = string.format("%d/%d", currentLevel, maxLevel)
    end
end

-- 通用星级显示更新
function CardsGui:_updateStarDisplay(cardFrame, starLevel)
    if not cardFrame then return end

    local starContainer = cardFrame["星级"]
    if not starContainer then return end

    for i = 1, 7 do
        local starNode = starContainer["星_" .. i]
        if starNode then
            local targetIcon
            if starLevel > 0 then
                targetIcon = starNode:GetAttribute("存在")
            else
                targetIcon = starNode:GetAttribute("不存在")
            end

            -- === 新增：避免重复设置相同的星级图标 ===
            if starNode.Icon ~= targetIcon then
                starNode.Icon = targetIcon
            end
        end
    end
end

-- 通用排序函数
function CardsGui:_sortCardsByPriority(cardList, stateManager, priorityFunc)
    table.sort(cardList, function(a, b)
        local aState = stateManager[a]
        local bState = stateManager[b]
        return priorityFunc(aState, bState)
    end)
    return cardList
end

-- 主卡优先级函数
function CardsGui:_getMainCardPriority(aState, bState)
    local aEquipped = aState and aState.isEquipped or false
    local bEquipped = bState and bState.isEquipped or false
    local aUnlocked = aState and aState.serverUnlocked or false
    local bUnlocked = bState and bState.serverUnlocked or false

    -- 获取品质信息
    local aQuality = aState and aState.configData and aState.configData.quality or "N"
    local bQuality = bState and bState.configData and bState.configData.quality or "N"

    -- 使用配置中的品质优先级映射
    local aPriority = uiConfig.qualityPriority[aQuality] or 1
    local bPriority = uiConfig.qualityPriority[bQuality] or 1

    -- 第一优先级：装备状态
    if aEquipped and not bEquipped then
        return true
    elseif not aEquipped and bEquipped then
        return false
    elseif aEquipped and bEquipped then
        -- 都已装备：按品质排序 (UR > SSR > SR > R > N)
        return aPriority > bPriority
    end

    -- 第二优先级：解锁状态
    if aUnlocked and not bUnlocked then
        return true
    elseif not aUnlocked and bUnlocked then
        return false
    elseif aUnlocked and bUnlocked then
        -- 都已解锁未装备：按品质排序
        return aPriority > bPriority
    elseif not aUnlocked and not bUnlocked then
        -- 都未解锁：按品质排序
        return aPriority > bPriority
    end

    return false
end

-- 副卡优先级函数
function CardsGui:_getSubCardPriority(aState, bState)
    local aEquipped = aState and aState.isEquipped or false
    local bEquipped = bState and bState.isEquipped or false
    local aUnlocked = aState and aState.serverUnlocked or false
    local bUnlocked = bState and bState.serverUnlocked or false

    -- 1. 装备的优先
    if aEquipped and not bEquipped then return true end
    if not aEquipped and bEquipped then return false end

    -- 2. 解锁的优先
    if aUnlocked and not bUnlocked then return true end
    if not aUnlocked and bUnlocked then return false end

    -- 3. 其他情况，保持原顺序
    return false
end

-- 通用功能按钮显示控制
function CardsGui:_setButtonVisible(button, visible, touchEnable)
    if button then
        button:SetVisible(visible)
        if visible and touchEnable ~= nil then
            button:SetTouchEnable(touchEnable)
        end
    end
end

-- === 新增：主卡按钮品质图标设置 ===
function CardsGui:_setMainCardQualityIcons(cardNode, skillType)
    if not cardNode or not skillType then return end

    local quality = skillType.quality or "N"  -- 默认为N品质


    -- === 增强检查：检查目标节点的当前图标和属性是否已经正确 ===
    local frameNode = cardNode["卡框背景"] and cardNode["卡框背景"]["卡框"]
    local backgroundNode = cardNode["卡框背景"]

    -- 检查卡框节点是否已经是目标图标
    if frameNode then
        local currentFrameIcon = frameNode.Icon
        local targetFrameIcon = uiConfig.qualityDefIcon[quality]
        local currentClickIcon = frameNode:GetAttribute("图片-点击")
        local targetClickIcon = uiConfig.qualityClickIcon[quality]
        local currentDefaultIcon = frameNode:GetAttribute("图片-默认")
        local targetDefaultIcon = uiConfig.qualityDefIcon[quality]

        if currentFrameIcon == targetFrameIcon and
           currentClickIcon == targetClickIcon and
           currentDefaultIcon == targetDefaultIcon then
            -- gg.log("卡框图标和属性已经正确，检查背景:", quality, skillType.name)
            -- 继续检查背景节点
            if backgroundNode then
                local currentBgIcon = backgroundNode.Icon
                local targetBgIcon = uiConfig.qualityBaseMapDefIcon[quality]
                local currentBgClickIcon = backgroundNode:GetAttribute("图片-点击")
                local targetBgClickIcon = uiConfig.qualityBaseMapClickIcon[quality]
                local currentBgDefaultIcon = backgroundNode:GetAttribute("图片-默认")
                local targetBgDefaultIcon = uiConfig.qualityBaseMapDefIcon[quality]

                if currentBgIcon == targetBgIcon and
                   currentBgClickIcon == targetBgClickIcon and
                   currentBgDefaultIcon == targetBgDefaultIcon then
                    -- gg.log("背景图标和属性也已经正确，完全跳过设置:", quality, skillType.name)
                    return  -- 两个节点的图标和属性都已经正确，完全跳过
                end
            end
        end
    end

    -- 构建品质资源table
    local frameQualityResources = {
        iconPath = uiConfig.qualityDefIcon[quality],       -- 基础图标路径
        iconNodePath = "卡框背景/卡框",                     -- 节点路径
        clickIcon = uiConfig.qualityClickIcon[quality],    -- 点击状态图标
        hoverIcon = uiConfig.qualityDefIcon[quality],      -- 悬浮状态图标（使用默认图标）
        attributes = {
            ["图片-默认"] = uiConfig.qualityDefIcon[quality],  -- 设置默认状态图标
            ["图片-悬浮"] = uiConfig.qualityDefIcon[quality]   -- 设置悬浮状态图标
        }
    }

    local iconQualityResources = {
        iconPath = uiConfig.qualityBaseMapDefIcon[quality],        -- 基础底图路径
        iconNodePath = "卡框背景",                             -- 节点路径
        clickIcon = uiConfig.qualityBaseMapClickIcon[quality],     -- 点击状态底图
        hoverIcon = uiConfig.qualityBaseMapDefIcon[quality],       -- 悬浮状态底图（使用默认底图）
        attributes = {
            ["图片-默认"] = uiConfig.qualityBaseMapDefIcon[quality],  -- 设置默认状态底图
            ["图片-悬浮"] = uiConfig.qualityBaseMapDefIcon[quality]   -- 设置悬浮状态底图
        }
    }

    self:_setCardIcon(cardNode, frameQualityResources)
    self:_setCardIcon(cardNode, iconQualityResources)


end

-- === 新增：副卡按钮品质图标设置 ===
function CardsGui:_setSubCardQualityIcons(cardNode, skillType)
    if not cardNode or not skillType then return end

    local quality = skillType.quality or "N"  -- 默认为N品质

    -- 设置图标底图/卡框的品质图标
    local frameQualityResources = {
        iconPath = uiConfig.qualityDefIcon[quality],       -- 基础图标路径
        iconNodePath = "图标底图/卡框",                     -- 节点路径
        clickIcon = uiConfig.qualityClickIcon[quality],    -- 点击状态图标
        hoverIcon = uiConfig.qualityDefIcon[quality],      -- 悬浮状态图标（使用默认图标）
        attributes = {
            ["图片-默认"] = uiConfig.qualityDefIcon[quality],  -- 设置默认状态图标
            ["图片-悬浮"] = uiConfig.qualityDefIcon[quality]   -- 设置悬浮状态图标
        }
    }

    -- 设置图标底图的品质底图
    local iconQualityResources = {
        iconPath = uiConfig.qualityBaseMapDefIcon[quality],        -- 基础底图路径
        iconNodePath = "图标底图",                                  -- 节点路径
        clickIcon = uiConfig.qualityBaseMapClickIcon[quality],     -- 点击状态底图
        hoverIcon = uiConfig.qualityBaseMapDefIcon[quality],       -- 悬浮状态底图（使用默认底图）
        attributes = {
            ["图片-默认"] = uiConfig.qualityBaseMapDefIcon[quality],  -- 设置默认状态底图
            ["图片-悬浮"] = uiConfig.qualityBaseMapDefIcon[quality]   -- 设置悬浮状态底图
        }
    }

    -- 使用通用函数设置副卡品质图标
    self:_setCardIcon(cardNode, frameQualityResources)

    -- 使用通用函数设置副卡底图
    self:_setCardIcon(cardNode, iconQualityResources)

    -- gg.log("设置副卡品质图标:", skillType.name, "品质:", quality,
    --        "卡框图标:", frameQualityResources.iconPath,
    --        "底图图标:", iconQualityResources.iconPath)
end



-- 副卡功能按钮状态更新
function CardsGui:_updateSubCardFunctionButtons(skill, skillLevel, serverData)
    gg.log("更新副卡功能按钮", skill, skillLevel, serverData)
    if serverData then
        local maxLevel = skill.maxLevel or 1
        local isMaxLevel = skillLevel >= maxLevel
        local isEquipped = serverData.slot and serverData.slot > 0 or false
        local currentStar = serverData.star_level or 0
        local maxStar = 7

        -- === 新增：检查副卡是否可装备 ===
        local canEquip = skill.isEquipable ~= nil

        -- === 新增：检查强化资源是否足够 ===
        local canAffordUpgrade = self:CanAffordUpgrade(skill, skillLevel + 1)
        -- === 新增：检查一键强化是否至少能升一级 ===
        local upgradeAllData = self:CalculateUpgradeAllCost(skill.name)
        local canAffordUpgradeAll = upgradeAllData and upgradeAllData.canUpgrade

        -- 强化按钮：未满级且资源足够时显示
        local showUpgrade = not isMaxLevel
        self:_setButtonVisible(self.SubcardEnhancementButton, showUpgrade, canAffordUpgrade)
        self:_setButtonVisible(self.SubcardAllEnhancementButton, showUpgrade, canAffordUpgradeAll)
        -- 升星按钮：未满星时显示
        local showUpgradeStar = currentStar < maxStar
        self:_setButtonVisible(self.SubcardUpgradeStarButton, showUpgradeStar, true)

        -- 装备/卸下按钮：只有可装备的技能才显示
        if canEquip then
            self:_setButtonVisible(self.SubcardEquipButton, not isEquipped, true)
            self:_setButtonVisible(self.SubcardUnEquipButton, isEquipped, true)
        else
            -- 不可装备的副卡：隐藏装备相关按钮
            self:_setButtonVisible(self.SubcardEquipButton, false)
            self:_setButtonVisible(self.SubcardUnEquipButton, false)
        end
    else
        -- 无服务端数据：隐藏所有功能按钮
        self:_setButtonVisible(self.SubcardEnhancementButton, false)
        self:_setButtonVisible(self.SubcardAllEnhancementButton, false)
        self:_setButtonVisible(self.SubcardUpgradeStarButton, false)
        self:_setButtonVisible(self.SubcardEquipButton, false)
        self:_setButtonVisible(self.SubcardUnEquipButton, false)
    end
end
-- 注册主卡/副卡按钮事件
function CardsGui:RegisterCardButtons()
    -- 主卡按钮点击事件
    if self.mainCardButton then
        -- self.mainCardButton:SetTouchEnable(true)
        self.mainCardButton.clickCb = function(ui, button)
            self:SwitchToCardType("主卡")
        end
    else
    end

    if self.subCardButton then
        self.subCardButton:SetTouchEnable(true)
        self.subCardButton.clickCb = function(ui, button)
            self:SwitchToCardType("副卡")
        end
    else
    end
end

-- 注册所有技能相关事件
function CardsGui:RegisterSkillEvents()
    -- 监听技能数据同步事件
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.SYNC_SKILLS, function(data)
        self:HandleSkillSync(data)
    end)

    -- 监听技能升级响应
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.UPGRADE, function(data)
        self:OnSkillLearnUpgradeResponse(data)
    end)

    -- 监听技能升星响应
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.UPGRADE_STAR, function(data)
        self:OnSkillUpgradeStarResponse(data)
    end)

    -- 监听单个新技能添加事件
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.LEARN, function(data)
        self:HandleNewSkillAdd(data)
    end)

    -- 监听技能装备响应
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.EQUIP, function(data)
        self:OnSkillEquipResponse(data)
    end)

    -- 监听技能卸下响应
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.UNEQUIP, function(data)
        self:OnSkillUnequipResponse(data)
    end)

    -- 监听技能等级设置响应（管理员指令）
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.SET_LEVEL, function(data)
        self:OnSkillSetLevelResponse(data)
    end)

    -- 监听背包库存同步事件
    ClientEventManager.Subscribe(BagEventConfig.RESPONSE.SYNC_INVENTORY_ITEMS, function(data)
        self:HandleInventorySync(data)
    end)
end


---@override
function CardsGui:OnInit(node, config)
    self.playerLevel = 1
    ClientEventManager.Subscribe("UpdateHud", function(data)
        self.playerLevel = data.level
    end)
    self.qualityList = self:Get("品质列表", ViewList) ---@type ViewList
    self.mainCardButton = self:Get("框体/标题/卡片/主卡", ViewButton) ---@type ViewButton
    self.subCardButton = self:Get("框体/标题/卡片/副卡", ViewButton) ---@type ViewButton
    self.closeButton = self:Get("框体/关闭", ViewButton) ---@type ViewButton
    self.attributeButton = self:Get("框体/主卡属性", ViewComponent) ---@type ViewComponent
    self.subCardAttributeButton = self:Get("框体/副卡属性", ViewComponent) ---@type ViewComponent
    self.mainCardComponent = self:Get("框体/主卡", ViewComponent) ---@type ViewComponent
    self.subCardComponent = self:Get("框体/副卡", ViewComponent) ---@type ViewComponent
    self.confirmPointsButton = self:Get("框体/主卡属性/主卡_研究", ViewButton) ---@type ViewButton
    self.EquipmentSkillsButton = self:Get("框体/主卡属性/主卡_装备", ViewButton) ---@type ViewButton
    self.mainCardUnEquipButton = self:Get("框体/主卡属性/主卡_卸下", ViewButton) ---@type ViewButton
    self.mainCardUpgradeStarButton = self:Get("框体/主卡属性/主卡_升星", ViewButton) ---@type ViewButton
    self.SubcardEnhancementButton = self:Get("框体/副卡属性/副卡_强化", ViewButton) ---@type ViewButton
    self.SubcardAllEnhancementButton = self:Get("框体/副卡属性/副卡一键强化", ViewButton) ---@type ViewButton
    self.SubcardEquipButton = self:Get("框体/副卡属性/副卡_装备", ViewButton) ---@type ViewButton
    self.SubcardUnEquipButton = self:Get("框体/副卡属性/副卡_卸下", ViewButton) ---@type ViewButton
    self.SubcardUpgradeStarButton = self:Get("框体/副卡属性/副卡_升星", ViewButton) ---@type ViewButton
    self.ConfirmStrengthenUI = self:Get("框体/副卡属性/确认强化", ViewComponent) ---@type ViewComponent
    self.StrengthenProgressUI = self:Get("框体/副卡/强化进度", ViewComponent) ---@type ViewComponent
    self.subCardenhancement = self:Get("框体/副卡/素材需求框", ViewComponent) ---@type ViewComponent

    self.ConfirmButton = self:Get("框体/副卡属性/确认强化/b_confirm", ViewButton) ---@type ViewButton
    self.CancelButton = self:Get("框体/副卡属性/确认强化/b_cancel", ViewButton) ---@type ViewButton


    self.selectionList = self:Get("框体/主卡/选择列表", ViewList) ---@type ViewList
    self.mainCardFrame = self:Get("框体/主卡/加点框/纵列表/主卡框", ViewButton) ---@type ViewButton
    self.skillButtons = {} ---@type table<string, ViewButton> -- 主卡按钮框
    self.skillLists = {} ---@type table<string, ViewList>     -- 主卡技能树列表
    self.mainCardButtondict = {} ---@type table<string, ViewButton> -- 主卡技能树的按钮
    self.subCardButtondict = {} ---@type table<string, ViewButton> -- 副卡技能的按钮
    self.subQualityLists ={} ---@type table<string, ViewList> -- 副卡品级列表
    self.mainQualityLists = {} ---@type table<string, ViewList> -- 主卡品质列表 UR:Viewlist

    self.qualityListMap = {} ---@type table<string, string> -- 构建反射的品质按钮名->品质名字典
    -- 玩家的装备槽数据数据
    self.equippedSkills = {} ---@type table<number, string>
    --- 玩家来自服务器的当前是技能数据
    self.ServerSkills = {} ---@type table<string, table>

    -- === 新增的主卡管理数据结构 ===
    self.mainCardButtonConfig = {} ---@type table<string, table> -- 存储所有配置的主卡信息
    self.mainCardButtonStates = {} ---@type table<string, table> -- 存储主卡按钮状态和位置信息
    -- 格式: {skillName = {button = ViewButton, position = number, activated = boolean, serverData = table, configData = table}}
    self.configMainCards = {} ---@type string[] -- 配置中的主卡列表（排序用）

    -- 当前点击主卡技能树的按钮
    ---@type ViewButton
    self.currentMCardButtonName = nil
    self.currentSubCardButtonName = nil

    -- === 移除了选择组管理 ===
    -- 当前显示的卡片类型 ("主卡" 或 "副卡")
    self.currentCardType = nil

    -- === 新增：防止重复切换的标志 ===
    self.isSwitching = false

    -- === 新增：跟踪是否是第一次切换到主卡 ===
    self.isFirstTimeToMainCard = true

    -- === 新增：跟踪是否是第一次切换到副卡 ===
    self.isFirstTimeToSubCard = true

    -- === 副卡管理数据结构（参考主卡逻辑）===
    self.subCardButtonConfig = {} ---@type table<string, table> -- 存储所有配置的副卡信息
    self.subCardButtonStates = {} ---@type table<string, table> -- 存储副卡按钮状态
    -- 格式: {skillName = {button = ViewButton, position = number, serverUnlocked = boolean, serverData = table, configData = table}}
    self.configSubCards = {} ---@type string[] -- 配置中的副卡列表（排序用）

    -- === 背包库存数据 ===
    self.playerInventory = {} ---@type table<string, number> -- 整合后的库存数据，key为物品名称，value为数量

    -- === 副卡素材需求ViewList存储 ===
    self.subCardMaterialLists = {} ---@type table<string, ViewList> -- 存储每个副卡的素材ViewList

    -- 存储一键强化的临时数据
    self.currentUpgradeData = nil

    -- 初始化确认强化UI为隐藏状态
    if self.ConfirmStrengthenUI then
        self.ConfirmStrengthenUI.node.Visible = false
    end

    self.closeButton.clickCb = function ()
        self:Close()
    end

    self:RegisterMainCardFunctionButtons()
    self:RegisterCardButtons()
    -- 设置默认显示主卡

    -- === 新的主卡初始化流程 ===
    self:LoadMainCardConfig()
    self:LoadMainCardsAndClone()

    -- === 新的副卡初始化流程 ===
    self:LoadSubCardConfig()
    self:InitializeSubCardButtons()

    self:BindQualityButtonEvents()
    self:RegisterSkillEvents()

    -- 初始化研究装备按钮状态（默认隐藏）
    self:InitializeFunctionButtonsVisibility()
    self:SwitchToCardType("主卡")

end

-- === 新增方法：加载主卡配置 ===
function CardsGui:LoadMainCardConfig()

    local skillMainTrees = SkillTypeUtils.BuildSkillForest(0)
    SkillTypeUtils.lastForest = skillMainTrees
    -- 存储配置数据
    for skillName, rootNode in pairs(skillMainTrees) do
        local skillType = rootNode.data
        self.mainCardButtonConfig[skillName] = {
            skillType = skillType,
            rootNode = rootNode
        }
        table.insert(self.configMainCards, skillName)

        -- 初始化按钮状态
        self.mainCardButtonStates[skillName] = {
            button = nil,
            position = #self.configMainCards,
            serverUnlocked = false,  -- 是否在服务端解锁
            isEquipped = false,      -- 是否已装备 (新增)
            equipSlot = 0,          -- 装备槽位 (新增)
            serverData = nil,
            configData = skillType
        }
    end

end


-- === 新增方法：初始化功能按钮可见性 ===
function CardsGui:InitializeFunctionButtonsVisibility()
    -- 主卡属性面板默认隐藏（只有点击具体主卡时才显示）
    self.attributeButton:SetVisible(false)

    -- 副卡属性面板默认隐藏（只有点击具体副卡时才显示）
    self.subCardAttributeButton:SetVisible(false)

    -- 主卡功能按钮默认隐藏
    self.confirmPointsButton:SetVisible(false)
    self.EquipmentSkillsButton:SetVisible(false)
    self.mainCardUnEquipButton:SetVisible(false)
    self.mainCardUpgradeStarButton:SetVisible(false)
    self.SubcardEnhancementButton:SetVisible(false)
    self.SubcardAllEnhancementButton:SetVisible(false)
    self.SubcardEquipButton:SetVisible(false)
    self.SubcardUnEquipButton:SetVisible(false)
    self.SubcardUpgradeStarButton:SetVisible(false)
    
end


-- === 新增方法：更新主卡装备状态 ===
function CardsGui:UpdateMainCardEquipStatus(skillName, serverData)
    local buttonState = self.mainCardButtonStates[skillName]
    if buttonState and serverData then
        local equipSlot = serverData.slot or 0
        buttonState.isEquipped = equipSlot > 0
        buttonState.equipSlot = equipSlot

    end
end

-- === 新增方法：设置主卡装备视觉效果 ===
function CardsGui:SetMainCardEquippedVisual(skillName, isEquipped)
    local buttonState = self.mainCardButtonStates[skillName]
    if not buttonState or not buttonState.button then
        return
    end

    local button = buttonState.button

    if isEquipped then

        local equipMark = button.node:FindFirstChild("装备标记")
        if equipMark then
            equipMark.Visible = true
        end
    else
        -- 未装备：清除特殊视觉效果
        local equipMark = button.node:FindFirstChild("装备标记")
        if equipMark then
            equipMark.Visible = false
        end
    end
end



-- === 修改方法：处理服务端主卡数据（支持装备状态）===
function CardsGui:ProcessServerMainCardData(serverSkillMainTrees)

    -- 首先确保所有主卡按钮的灰色状态正确
    for _, skillName in ipairs(self.configMainCards) do
        local buttonState = self.mainCardButtonStates[skillName]
        if buttonState and buttonState.button then
            -- 检查是否在服务端数据中
            local serverSkillData = serverSkillMainTrees[skillName]
            if serverSkillData then
                -- 标记为服务端已解锁   
                local serverData = serverSkillData.serverData
                buttonState.serverUnlocked = true
                buttonState.serverData = serverData
                -- 更新装备状态
                self:UpdateMainCardEquipStatus(skillName, serverData)
                -- 恢复按钮正常颜色（已解锁）
                buttonState.button.img.Grayed = false
                -- 设置装备状态的视觉反馈
                self:SetMainCardEquippedVisual(skillName, buttonState.isEquipped)
            else
                -- 确保未解锁的主卡保持灰色
                buttonState.serverUnlocked = false
                buttonState.isEquipped = false
                buttonState.equipSlot = 0
                buttonState.serverData = nil
                buttonState.button.img.Grayed = true
                self:SetMainCardEquippedVisual(skillName, false)
            end
        else
        end
    end

end

-- === 优化后的排序和更新主卡布局方法 ===
function CardsGui:SortAndUpdateMainCardLayout()
    -- 使用工具函数进行排序
    local sortedCards = {}
    for _, skillName in ipairs(self.configMainCards) do
        table.insert(sortedCards, skillName)
    end

    self:_sortCardsByPriority(sortedCards, self.mainCardButtonStates, function(aState, bState)
        return self:_getMainCardPriority(aState, bState)
    end)

    self:RecreateMainCardButtonsInOrder(sortedCards)
    self.configMainCards = sortedCards

end

-- === 修改：按顺序重新创建主卡按钮（采用协调算法） ===
function CardsGui:RecreateMainCardButtonsInOrder(sortedCards)
    gg.log("按新顺序重新创建主卡按钮", sortedCards)
    local mainCardList = self:Get('框体/主卡/选择列表/列表', ViewList)
    local templateNode = self:Get('框体/主卡/选择列表/模板/主卡_1', ViewComponent).node

    -- 步骤 1: 建立当前子节点的映射，方便快速查找
    local existingChildrenMap = {}
    for _, child in ipairs(mainCardList.childrens) do
        if child.node and child.node.Name then
            existingChildrenMap[child.node.Name] = child
        end
    end

    -- 步骤 2: 遍历排序后的列表，协调UI状态
    local newChildrens = {}
    for newIndex, skillName in ipairs(sortedCards) do
        local buttonState = self.mainCardButtonStates[skillName]
        
        if buttonState and buttonState.configData then
            local skillType = buttonState.configData
            local mainCardButton

            -- 检查节点是否已存在
            if existingChildrenMap[skillName] then
                mainCardButton = existingChildrenMap[skillName]
                -- 标记为已处理，这样它就不会在末尾被删除
                existingChildrenMap[skillName] = nil
            else
                -- 节点不存在，创建新的
                local clonedNode = templateNode:Clone()
                clonedNode.Name = skillName
                
                mainCardButton = self:_createButtonWithCallback(clonedNode, function(ui, button)
                    local skillId = button.extraParams["skillId"]
                    self:ShowSkillTree(skillId)
                    if self.skillLists[skillId] then
                        self.attributeButton:SetVisible(true)
                        self:AutoClickMainCardFrameInSkillTree(skillId)
                    end
                end, {skillId = skillName})

                -- 更新全局存储
                self.skillButtons[skillName] = mainCardButton
                self.mainCardButtonStates[skillName].button = mainCardButton
            end

            -- 步骤 3: 更新按钮状态（无论是新是旧）
            mainCardButton.extraParams.skillId = skillName
            mainCardButton.node.Visible = true
            
            local iconResources = {iconPath = skillType.icon, iconNodePath = "卡框背景/图标"}
            self:_setCardIcon(mainCardButton.node, iconResources)
            self:_setMainCardQualityIcons(mainCardButton.node, skillType)
            
            self:_updateButtonGrayState(mainCardButton, buttonState.serverUnlocked)
            self:SetMainCardEquippedVisual(skillName, buttonState.isEquipped)
            
            buttonState.position = newIndex
            table.insert(newChildrens, mainCardButton)
        end
    end

    -- 步骤 4: 移除不再需要的旧节点
    for skillName, child in pairs(existingChildrenMap) do
        if child and child.node then
            child.node:Destroy()
            -- 从字典中移除，防止内存泄漏
            self.skillButtons[skillName] = nil
            if self.mainCardButtonStates[skillName] then
                self.mainCardButtonStates[skillName].button = nil
            end
        end
    end
    
    -- 步骤 5: 应用新的子节点列表并刷新布局
    mainCardList.childrens = newChildrens
    mainCardList:_refreshLayout()
    gg.log("主卡按钮重新创建完成")
end

-- 注册主卡功能按钮事件
function CardsGui:RegisterMainCardFunctionButtons()
    self.confirmPointsButton.clickCb = function (ui, button)

        if not self.currentMCardButtonName then
            return
        end

        if not self.currentMCardButtonName.extraParams then
            return
        end

        local skillName = self.currentMCardButtonName.extraParams["skillId"]
        if not skillName then
            return
        end

        gg.network_channel:FireServer({
            cmd = SkillEventConfig.REQUEST.UPGRADE,
            skillName = skillName
        })
    end
    self.EquipmentSkillsButton.clickCb = function (ui, button)
        gg.network_channel:FireServer({
            cmd = SkillEventConfig.REQUEST.EQUIP,
            skillName = self.currentMCardButtonName.extraParams["skillId"],

        })
    end

    if self.mainCardUnEquipButton then
        self.mainCardUnEquipButton.clickCb = function(ui, button)
            local skillName = self.currentMCardButtonName.extraParams["skillId"]
            gg.network_channel:FireServer({
                cmd = SkillEventConfig.REQUEST.UNEQUIP,
                skillName = skillName
            })
        end
    end

    if self.mainCardUpgradeStarButton then
        self.mainCardUpgradeStarButton.clickCb = function(ui, button)
            local skillName = self.currentMCardButtonName.extraParams["skillId"]
            gg.network_channel:FireServer({
                cmd = SkillEventConfig.REQUEST.UPGRADE_STAR,
                skillName = skillName
            })
        end
    end
    if self.SubcardEnhancementButton then
        self.SubcardEnhancementButton.clickCb = function(ui, button)
            local skillName = self.currentSubCardButtonName.extraParams["skillId"]

            gg.network_channel:FireServer({
                cmd = SkillEventConfig.REQUEST.UPGRADE,
                skillName = skillName
            })
        end
    end
    if self.SubcardAllEnhancementButton then
        self.SubcardAllEnhancementButton.clickCb = function(ui, button)
            local skillName = self.currentSubCardButtonName.extraParams["skillId"]

            -- 计算强化数据并显示确认对话框
            self:ShowUpgradeConfirmDialog(skillName)
        end
    end
    if self.SubcardEquipButton then
        self.SubcardEquipButton.clickCb = function(ui, button)
            local skillName = self.currentSubCardButtonName.extraParams["skillId"]
            gg.network_channel:FireServer({
                cmd = SkillEventConfig.REQUEST.EQUIP,
                skillName = skillName
            })
        end
    end

    if self.SubcardUnEquipButton then
        self.SubcardUnEquipButton.clickCb = function(ui, button)
            local skillName = self.currentSubCardButtonName.extraParams["skillId"]
            gg.network_channel:FireServer({
                cmd = SkillEventConfig.REQUEST.UNEQUIP,
                skillName = skillName
            })
        end
    end

    if self.SubcardUpgradeStarButton then
        self.SubcardUpgradeStarButton.clickCb = function(ui, button)
            local skillName = self.currentSubCardButtonName.extraParams["skillId"]
            gg.network_channel:FireServer({
                cmd = SkillEventConfig.REQUEST.UPGRADE_STAR,
                skillName = skillName
            })
        end
    end

    -- 绑定确认强化相关按钮事件
    if self.ConfirmButton then
        self.ConfirmButton.clickCb = function(ui, button)
            self:OnConfirmUpgrade()
        end
    end

    if self.CancelButton then
        self.CancelButton.clickCb = function(ui, button)
            self:OnCancelUpgrade()
        end
    end
end
-- 处理技能同步数据
function CardsGui:HandleSkillSync(data)
    gg.log("HandleSkillSync",data)
    if not data or not data.skillData then return end
    local skillDataDic = data.skillData.skills

    self.ServerSkills = {}
    self.equippedSkills = {}
    local serverSkillMainTrees = {} ---@type table<string, table>
    local serverSubskillDic = {} ---@type table<string, table>

    -- 反序列化技能数据
    for skillName, skillData in pairs(skillDataDic) do
        -- 创建技能对象
        self.ServerSkills[skillName] = skillData
        -- 记录已装备的技能
        if skillData.slot > 0 then
            self.equippedSkills[skillData.slot] = skillName
        end

        local skillType = SkillTypeConfig.Get(skillName)

        if skillType then
            if skillType.isEntrySkill and skillType.category==0 then
                serverSkillMainTrees[skillName] = {data=skillType,serverData=skillData}
            elseif skillType.isEntrySkill and skillType.category==1 then
                serverSubskillDic[skillName] = {data=skillType,serverData=skillData}
            else
            end
        else
        end

        --- 更新技能树的节点显示
        self:UpdateSkillTreeNodeDisplay(skillName)
    end


    self:ProcessServerMainCardData(serverSkillMainTrees)
    self:ProcessServerSubCardData(serverSubskillDic)

    -- 更新所有技能按钮的灰色状态
    self:UpdateAllSkillButtonsGrayState()

    -- 更新主卡按钮状态（解锁状态和装备状态）
    self:UpdateMainCardButtonStates()

    -- 重新排序主卡布局（考虑解锁和装备状态的变化）
    self:SortAndUpdateMainCardLayout()

    -- 调试：输出技能列表状态
    -- self:DebugPrintSkillListsStatus()
    if self.isFirstTimeToMainCard then
        self.isFirstTimeToMainCard = false
        self:AutoSelectFirstMainCard()
    end
end

function CardsGui:UpdateSkillTreeNodeDisplay(skillName)
    local skillTreeButton = self.mainCardButtondict[skillName]

    local skillType = SkillTypeConfig.Get(skillName)
    if skillTreeButton and skillTreeButton.node then
        self:SetSkillLevelOnCardFrame(skillTreeButton.node, skillType)

        -- 更新按钮的灰色状态
        local serverSkill = self.ServerSkills[skillName]
        if serverSkill then
            -- 技能已解锁：恢复正常颜色
            skillTreeButton.img.Grayed = false

        else
            -- 技能未解锁：设置为灰色
            skillTreeButton.img.Grayed = true
        end
    end

end

function CardsGui:UpdateSubCardTreeNodeDisplay(skillName)
    local skillTreeButton = self.subCardButtondict[skillName]
    local skillType = SkillTypeConfig.Get(skillName)
    if skillTreeButton and skillTreeButton.node then
        self:SetSkillLevelSubCardFrame(skillTreeButton.node, skillType)
    end
end

-- === 新增方法：更新所有技能树按钮的灰色状态 ===
function CardsGui:UpdateAllSkillButtonsGrayState()

    -- 更新所有已创建的技能树按钮
    for skillName, skillButton in pairs(self.mainCardButtondict) do
        local serverSkill = self.ServerSkills[skillName]
        if serverSkill then
            -- 技能已解锁：恢复正常颜色
            skillButton.img.Grayed = false
        else
            -- 技能未解锁：设置为灰色
            skillButton.img.Grayed = true
        end
    end


end

-- === 新增方法：更新主卡按钮状态 ===
function CardsGui:UpdateMainCardButtonStates()

    -- 遍历所有主卡按钮状态
    for skillName, buttonState in pairs(self.mainCardButtonStates) do
        local serverSkill = self.ServerSkills[skillName]

        -- 更新解锁状
        buttonState.serverUnlocked = (serverSkill ~= nil)

        if serverSkill then
            -- 技能已解锁：更新装备状态和服务端数据
            buttonState.serverData = serverSkill
            self:UpdateMainCardEquipStatus(skillName, serverSkill)

            -- 更新按钮的灰色状态（如果按钮存在）
            if buttonState.button then
                buttonState.button.img.Grayed = false
            end

        else
            -- 技能未解锁：重置状态
            buttonState.serverData = nil
            buttonState.isEquipped = false
            buttonState.equipSlot = 0

            -- 更新按钮的灰色状态（如果按钮存在）
            if buttonState.button then
                buttonState.button.img.Grayed = true
            end

        end
    end

end


--- 处理技能学习/升级响应
function CardsGui:OnSkillLearnUpgradeResponse(response)
    local data = response.data
    local skillName = data.skillName
    local serverlevel = data.level
    local serverslot = data.slot

    -- 使用工具函数更新技能数据
    self:_updateSkillData(skillName, serverlevel, serverslot)
    local skillType = SkillTypeConfig.Get(skillName)
    if skillType.category==1 then
        -- 副卡升级：更新副卡显示和按钮状态
        self:UpdateSubCardTreeNodeDisplay(skillName)

        -- === 新增：更新副卡按钮状态数据 ===
        local buttonState = self.subCardButtonStates[skillName]
        if buttonState then
            buttonState.serverUnlocked = true
            -- 更新按钮的extraParams中的serverData
            if buttonState.button then
                buttonState.button.extraParams.serverData = buttonState.serverData
                buttonState.button.img.Grayed = false  -- 确保按钮不是灰色状态
            end
        end

        -- 如果当前选中的是这个副卡，更新属性面板
        if self.currentSubCardButtonName and
           self.currentSubCardButtonName.extraParams.skillId == skillName then
            local serverData = buttonState and buttonState.serverData
            local skillLevel = serverData and serverData.level or 0

            -- 重新更新属性面板（会自动处理按钮显示逻辑）
            self:UpdateSubCardAttributePanel(skillType, skillLevel, serverData)

            -- === 新增：同步更新副卡强化等级显示 ===
            self:UpdateSubCardLevelDisplay(skillName, skillLevel)

            -- === 新增：同步更新对应材料数据 ===
            self:UpdateSubCardMaterialRequirements(skillName, skillLevel)
        end

    elseif skillType.category==0  then
        -- 主卡升级：更新主卡技能树显示和装备状态
        self:UpdateSkillTreeNodeDisplay(skillName)

        -- 检查并更新主卡装备状态
        local buttonState = self.mainCardButtonStates[skillName]
        if buttonState then
            local oldEquipped = buttonState.isEquipped
            self:UpdateMainCardEquipStatus(skillName, self.ServerSkills[skillName])

            -- 如果装备状态发生变化，重新排序
            if oldEquipped ~= buttonState.isEquipped then
                self:SortAndUpdateMainCardLayout()
            end
        end

        -- === 新增：如果当前选中的是这个主卡，更新货币消耗显示 ===
        if self.currentMCardButtonName and
           self.currentMCardButtonName.extraParams.skillId == skillName then
            local attributeButton = self.attributeButton.node
            local skillData = self.ServerSkills[skillName]
            local newSkillLevel = skillData and skillData.level or 0

            -- 更新货币消耗显示
            self:UpdateMainCardResourceCost(attributeButton, skillType, newSkillLevel)
        end
    end

    -- self:UpdateSkillDisplay()
end

--- 处理技能升星响应
function CardsGui:OnSkillUpgradeStarResponse(response)
    local data = response.data
    local skillName = data.skillName
    local serverStarLevel = data.star_level
    local serverLevel = data.level
    local serverSlot = data.slot

    -- 使用工具函数更新技能数据
    self:_updateSkillData(skillName, serverLevel, serverSlot, serverStarLevel)

    -- 获取技能类型
    local skillType = SkillTypeConfig.Get(skillName)
    if skillType then
        if skillType.category == 0 then
            -- 主卡升星：更新主卡技能树显示
            self:UpdateSkillTreeNodeDisplay(skillName)

            -- === 新增：如果当前选中的是这个主卡，更新属性面板 ===
            if self.currentMCardButtonName and
               self.currentMCardButtonName.extraParams.skillId == skillName then
                local attributeButton = self.attributeButton.node
                local skillData = self.ServerSkills[skillName]
                local skillLevel = skillData and skillData.level or 0

                -- 更新货币消耗显示
                self:UpdateMainCardResourceCost(attributeButton, skillType, skillLevel)
            end
                         -- 如果当前选中的是这个主卡，更新星级显示
        elseif skillType.category == 1 then
            -- 副卡升星：更新副卡显示
            self:UpdateSubCardTreeNodeDisplay(skillName)

            -- 如果当前选中的是这个副卡，更新星级显示
            if self.currentSubCardButtonName and
               self.currentSubCardButtonName.extraParams.skillId == skillName then
                -- 获取更新后的技能数据
                local skillData = self.ServerSkills[skillName]
                local skillLevel = skillData and skillData.level or 0
                self:UpdateSubCardAttributePanel(skillType, skillLevel, skillData)
            end
        end
    end

end

-- === 新增方法：处理技能装备响应 ===
function CardsGui:OnSkillEquipResponse(response)
    -- gg.log("收到技能装响应", response)
    local data = response.data
    local skillName = data.skillName
    local slot = data.slot

    -- 更新服务端技能数据
    local skillData = self.ServerSkills[skillName]
    if skillData then
        skillData.slot = slot
    else
        self.ServerSkills[skillName] = {
            level = data.level or 1,
            slot = slot,
            skill = skillName
        }
    end

    -- === 新增：处理原有装备技能的自动卸下 ===
    local originalSkillName = self.equippedSkills[slot]
    if originalSkillName and originalSkillName ~= skillName then
        -- 原有技能存在且不是当前技能，需要卸下

        -- 更新原有技能的服务端数据
        local originalSkillData = self.ServerSkills[originalSkillName]
        if originalSkillData then
            originalSkillData.slot = 0  -- 设置为未装备状态
        end

        -- 获取原有技能类型并更新其状态
        local originalSkillType = SkillTypeConfig.Get(originalSkillName)
        if originalSkillType and originalSkillType.category == 0 then
            -- 原有主卡：更新装备状态
            local originalButtonState = self.mainCardButtonStates[originalSkillName]
            if originalButtonState then
                self:UpdateMainCardEquipStatus(originalSkillName, originalSkillData)
                self:SetMainCardEquippedVisual(originalSkillName, false)
            end
        end
    end

    -- 更新装备槽数据（覆盖原有技能）
    self.equippedSkills[slot] = skillName

    -- 获取技能类型
    local skillType = SkillTypeConfig.Get(skillName)
    if skillType then
        if skillType.category == 0 then
            -- 主卡装备：更新主卡装备状态和重新排序
            local buttonState = self.mainCardButtonStates[skillName]
            if buttonState then
                self:UpdateMainCardEquipStatus(skillName, skillData)
                self:SetMainCardEquippedVisual(skillName, true)
                -- 无论是否有原有技能，都重新排序以确保所有按钮状态正确
                self:SortAndUpdateMainCardLayout()
            end

            -- 如果当前选中的是这个主卡，更新装备/卸下按钮显示
            if self.currentMCardButtonName and
               self.currentMCardButtonName.extraParams.skillId == skillName then
                -- 装备后：显示卸下按钮，隐藏装备按钮
                self.mainCardUnEquipButton:SetVisible(true)
                self.EquipmentSkillsButton:SetVisible(false)
                self.mainCardUnEquipButton:SetTouchEnable(true)

                -- === 新增：更新货币消耗显示 ===
                local attributeButton = self.attributeButton.node
                local skillLevel = skillData and skillData.level or 0
                self:UpdateMainCardResourceCost(attributeButton, skillType, skillLevel)
            end

        elseif skillType.category == 1 then
            -- 副卡装备：更新副卡显示
            self:UpdateSubCardTreeNodeDisplay(skillName)

            -- 如果当前选中的是这个副卡，更新属性面板
            if self.currentSubCardButtonName and
                self.currentSubCardButtonName.extraParams.skillId == skillName then
                local skillLevel = skillData and skillData.level or 0
                self:UpdateSubCardAttributePanel(skillType, skillLevel, skillData)
            end
        end
    end
end

-- === 新增方法：处理技能卸下响应 ===
function CardsGui:OnSkillUnequipResponse(response)
    local data = response.data
    local skillName = data.skillName
    local oldSlot = nil

    -- 从装备槽中移除
    for slot, equippedSkillName in pairs(self.equippedSkills) do
        if equippedSkillName == skillName then
            oldSlot = slot
            self.equippedSkills[slot] = nil
            break
        end
    end

    -- 更新服务端技能数据
    local skillData = self.ServerSkills[skillName]
    if skillData then
        skillData.slot = 0  -- 卸下后槽位为0
    end

    -- 获取技能类型
    local skillType = SkillTypeConfig.Get(skillName)
    if skillType then
        if skillType.category == 0 then
            -- 主卡卸下：更新主卡装备状态和重新排序
            local buttonState = self.mainCardButtonStates[skillName]
            if buttonState then
                self:UpdateMainCardEquipStatus(skillName, skillData)
                self:SetMainCardEquippedVisual(skillName, false)
                self:SortAndUpdateMainCardLayout()
            end

            -- 如果当前选中的是这个主卡，更新装备/卸下按钮显示
            if self.currentMCardButtonName and
               self.currentMCardButtonName.extraParams.skillId == skillName then
                -- 卸下后：显示装备按钮，隐藏卸下按钮
                self.EquipmentSkillsButton:SetVisible(true)
                self.mainCardUnEquipButton:SetVisible(false)
                self.EquipmentSkillsButton:SetTouchEnable(true)

            end

        elseif skillType.category == 1 then
            -- 副卡卸下：更新副卡显示
            self:UpdateSubCardTreeNodeDisplay(skillName)

            -- 如果当前选中的是这个副卡，更新属性面板
            if self.currentSubCardButtonName and
                self.currentSubCardButtonName.extraParams.skillId == skillName then
                local skillLevel = skillData and skillData.level or 0
                self:UpdateSubCardAttributePanel(skillType, skillLevel, skillData)
            end
        end
    end
end



function CardsGui:Display(title, content, confirmCallback, cancelCallback)
    self.qualityList.Title = title
    self.mainCardButton.Title = content
    self.confirmCallback = confirmCallback
    self.cancelCallback = cancelCallback
end

-- ========== 卡片切换功能 ==========

-- 切换到指定的卡片类型
function CardsGui:SwitchToCardType(cardType)
    -- === 防止重复调用 ===
    if self.isSwitching then
        return
    end

    if self.currentCardType == cardType then
        return
    end

    self.isSwitching = true
    self.currentCardType = cardType
    local shouldShow = (cardType == "副卡")
    for _, qualityComponent in ipairs(self.qualityList.childrens) do
        qualityComponent:SetVisible(shouldShow)
    end

    -- === 移除了主卡副卡按钮的选中状态设置 ===
    if cardType == "主卡" then

    elseif cardType == "副卡" then
        if self.isFirstTimeToSubCard then
            self:ShowSubCardQuality("ALL")
            self.isFirstTimeToSubCard = false
            self:AutoSelectFirstSubCard()
        end
    end

    self:UpdateCardDisplay(cardType)

    -- === 切换完成，重置标志 ===
    self.isSwitching = false
end

-- 更新指定卡片类型的显示
function CardsGui:UpdateCardDisplay(cardType)
    if self.mainCardComponent then
        local showMain = (cardType == "主卡")
        self.mainCardComponent:SetVisible(showMain)
        -- 注意：主卡属性面板初始隐藏，只有点击具体主卡时才显示
        if showMain then
            -- 如果之前有选中的主卡，保持属性面板显示状态
            if self.currentMCardButtonName then
                self.attributeButton:SetVisible(true)
            else
                self.attributeButton:SetVisible(false)
            end
        else
            self.attributeButton:SetVisible(false)
        end
        self.subCardComponent:SetVisible(not showMain)
    end
    if self.subCardComponent then
        local showSub = (cardType == "副卡")
        self.subCardComponent:SetVisible(showSub)

        -- 副卡属性面板处理：类似主卡逻辑
        if showSub then
            -- 如果之前有选中的副卡，保持属性面板显示状态
            if self.currentSubCardButtonName then
                self.subCardAttributeButton:SetVisible(true)
            else
                self.subCardAttributeButton:SetVisible(false)
            end
            -- 切换到副卡时隐藏主卡属性面板
            self.attributeButton:SetVisible(false)
        else
            self.subCardAttributeButton:SetVisible(false)
        end
    end
end



-- 获取当前卡片类型
function CardsGui:GetCurrentCardType()
    return self.currentCardType
end

-- === 新增：自动选择第一个主卡按钮 ===
function CardsGui:AutoSelectFirstMainCard()
    -- 优先选择已解锁的主卡，其次选择第一个主卡
    local targetButton = nil
    local targetSkillId = nil

    -- 1. 首先尝试找到第一个已解锁的主卡
    for _, skillName in ipairs(self.configMainCards) do
        local buttonState = self.mainCardButtonStates[skillName]
        if buttonState and buttonState.button and buttonState.serverUnlocked then
            targetButton = buttonState.button
            targetSkillId = skillName
            break
        end
    end

    -- 2. 如果没有已解锁的主卡，选择第一个主卡（即使是灰色的）
    if not targetButton then
        for _, skillName in ipairs(self.configMainCards) do
            local buttonState = self.mainCardButtonStates[skillName]
            if buttonState and buttonState.button then
                targetButton = buttonState.button
                targetSkillId = skillName
                break
            end
        end
    end

    -- 3. 如果找到了目标按钮，模拟点击
    if targetButton and targetSkillId then
        -- === 移除了选择组管理，直接调用相关方法 ===

        -- 显示对应的技能树
        self:ShowSkillTree(targetSkillId)

        -- 如果技能树存在，显示属性面板
        if self.skillLists[targetSkillId] then
            self.attributeButton:SetVisible(true)
        end

        self.currentMCardButtonName = targetButton

        -- === 新增：自动点击技能树中的主卡框 ===
        self:AutoClickMainCardFrameInSkillTree(targetSkillId)

    else
    end
end

-- === 新增：自动点击技能树中的主卡框 ===
function CardsGui:AutoClickMainCardFrameInSkillTree(skillId)
    -- gg.log("AutoClickMainCardFrameInSkillTree", skillId)

    -- 通过skillId从主卡按钮字典中找到对应的技能树主卡框按钮
    local mainCardFrameButton = self.mainCardButtondict[skillId]

    if mainCardFrameButton then
        -- 模拟点击技能树中的主卡框
        -- 调用OnSkillTreeNodeClick方法来处理点击逻辑
        self:OnSkillTreeNodeClick(nil, mainCardFrameButton, mainCardFrameButton.node)

    else
    end
end

-- === 修改：自动选择第一个副卡按钮（支持当前品质感知）===
function CardsGui:AutoSelectFirstSubCard()
    -- 获取当前显示的品质
    local currentQuality = self:GetCurrentDisplayedQuality()

    -- 如果能确定当前品质，使用品质特定的选择逻辑
    if currentQuality then
        self:AutoSelectFirstSubCardInQuality(currentQuality)
        return
    end

    -- 回退逻辑：如果无法确定当前品质，默认使用ALL品质
    self:AutoSelectFirstSubCardInQuality("ALL")
end

-- === 新增：获取当前显示的副卡品质 ===
function CardsGui:GetCurrentDisplayedQuality()
    -- 检查哪个品质列表当前是可见的
    for quality, qualityList in pairs(self.subQualityLists or {}) do
        if qualityList and qualityList.node and qualityList.node.Visible then
            return quality
        end
    end

    -- 如果没有找到可见的品质列表，返回nil
    return nil
end

-- === 新增：自动选择指定品质的第一个副卡 ===
function CardsGui:AutoSelectFirstSubCardInQuality(quality)

    -- 获取指定品质的ViewList
    local qualityViewList = self.subQualityLists[quality]
    if not qualityViewList then
        self:HideSubCardUIElements()
        return
    end

    -- 检查ViewList是否有子元素
    if qualityViewList:GetChildCount() == 0 then
        self:HideSubCardUIElements()
        return
    end

    -- 获取第一个子节点
    local firstChild = qualityViewList:GetChild(1)



    -- 判断child是否存在，没有就算了
    if not firstChild then
        self:HideSubCardUIElements()
        return
    end

    if not firstChild.node  then
        self:HideSubCardUIElements()
        return
    end

    -- 从第一个子节点获取skillId
    local skillId = firstChild.node.Name

    -- 如果子组件没有extraParams，尝试从subCardButtondict中查找


    local targetButton = self.subCardButtondict[skillId]

    if not targetButton then
        self:HideSubCardUIElements()
        return
    end

    if not targetButton then
        self:HideSubCardUIElements()
        return
    end

    -- 模拟副卡按钮点击
    self:OnSubCardButtonClick(nil, targetButton)
end

-- === 新增：隐藏副卡相关UI元素 ===
function CardsGui:HideSubCardUIElements()
    -- 隐藏副卡属性面板
    self.subCardAttributeButton:SetVisible(false)

    -- 获取副卡组件节点
    local subNode = self.subCardComponent.node
    if subNode then
        -- 隐藏卡牌图标
        local subCardIconNode = subNode["主背景"]["上层背景"]["卡牌图标"]
        if subCardIconNode then
            subCardIconNode.Visible = false
        end

        -- 清空当前强化等级字段
        local currentLevelNode = subNode["主背景"]["主背景强化显示"]["当前强化等级"]
        if currentLevelNode then
            currentLevelNode.Title = ""
        end

        -- 隐藏星级显示
        local starContainer = subNode["星级"]
        if starContainer then
            for i = 1, 7 do
                local starNode = starContainer["星_" .. i]
                if starNode then
                    starNode.Visible = false
                end
            end
        end
    end

    -- 隐藏所有副卡的素材需求
    for skillName, materialViewList in pairs(self.subCardMaterialLists) do
        if materialViewList and materialViewList.node then
            materialViewList.node.Visible = false
        end
    end

    -- 清除当前选中的副卡状态
    self.currentSubCardButtonName = nil

end

-- === 新增：技能树节点点击事件处理 ===
function CardsGui:OnSkillTreeNodeClick(ui, button, cardFrame)
    local skillId = button.extraParams.skillId
    local skill = SkillTypeConfig.Get(skillId) ---@type SkillType
    local skillInst = self.ServerSkills[skillId]
    local skillLevel = 0

    -- 点击主卡技能时显示属性面板
    self.attributeButton:SetVisible(true)

    local attributeButton = self.attributeButton.node
    if skillInst then
        skillLevel = skillInst.level
    end
    local nameNode = attributeButton["卡片名字"]
    if nameNode then
        nameNode.Title = skill.displayName
    end
    -- 更新技能描述
    attributeButton["卡片介绍"].Title = skill.description

    local descPreTitleNode = attributeButton["列表_强化前"]["强化标题"]
    local descPostTitleNode = attributeButton["列表_强化后"]["强化标题"]
    local descPreNode = attributeButton["列表_强化前"]["属性_1"]
    local descPostNode = attributeButton["列表_强化后"]["属性_1"]
    local subCardNode = self.subCardComponent.node
    local subCardIconNode = subCardNode["主背景"]["上层背景"]['卡牌图标']

    descPreTitleNode.Title = string.format("等级 %d/%d", skillLevel, skill.maxLevel)
    local descPre = {}
    for _, tag in pairs(skill.passiveTags) do
        table.insert(descPre, tag:GetDescription(skillLevel))
    end
    table.insert(descPre, string.format("玩家等级: %s", self.playerLevel))
    descPreNode.Title = table.concat(descPre, "\n")
    if skillLevel < skill.maxLevel then
        descPostTitleNode.Title = string.format("等级 %d/%d", skillLevel+1, skill.maxLevel)
        local descPost = {}
        for _, tag in pairs(skill.passiveTags) do
            table.insert(descPost, tag:GetDescription(skillLevel+1))
        end
        table.insert(descPost, string.format("玩家等级: %s", self.playerLevel + skill.levelUpPlayer))
        descPostNode.Title = table.concat(descPost, "\n")
    else
        descPostNode.Title = "已达最大等级"
    end

    local curCardSkillData = self.ServerSkills[skillId]
    ---@ type SkillType
    local curSkillType = SkillTypeConfig.Get(skillId)
    local prerequisite = curSkillType.prerequisite

    -- === 检查前置技能和服务端数据 ===
    local existsPrerequisite = false
    -- 如果没有前置技能，则不能通过前置条件研究
    if #prerequisite == 0 then
        existsPrerequisite = false
    else
        -- 有前置技能时，检查是否都已解锁
        existsPrerequisite = true
        for i, preSkillType in ipairs(prerequisite) do
            if not self.ServerSkills[preSkillType.name] then
                existsPrerequisite = false
                break
            end
        end
    end

    local skillLevel = 0
    local canResearchOrEquip = false

    -- 修改逻辑：当前技能存在 OR 所有父类技能都存在 就可以研究
    if curCardSkillData then
        -- 当前技能已存在：可以研究升级和装备
        skillLevel = curCardSkillData.level
        canResearchOrEquip = true
    elseif existsPrerequisite then
        -- 当前技能不存在，但所有前置技能都存在：可以研究学习
        skillLevel = 0
        canResearchOrEquip = true
    else
        -- 前置技能不满足：无法研究
    end

    -- === 新增：在设置按钮状态前检查资源 ===
    local canAfford = self:UpdateMainCardResourceCost(attributeButton, skill, skillLevel)

    -- 设置研究装备按钮状态
    if canResearchOrEquip then
        -- 显示研究按钮
        self.confirmPointsButton:SetVisible(true)

        if curCardSkillData then
            -- 技能已存在：显示装备相关按钮和升星按钮
            local isEquipped = curCardSkillData.slot and curCardSkillData.slot > 0 or false
            local currentStar = curCardSkillData.star_level or 0
            local maxStar = 7  -- 最大星级为7星

            -- === 新增：检查技能是否可装备 ===
            local canEquip = skill.isEquipable ~= nil

            if canEquip then
                -- 技能可装备：显示装备相关按钮
                if isEquipped then
                    -- 已装备：显示卸下按钮，隐藏装备按钮
                    self.mainCardUnEquipButton:SetVisible(true)
                    self.EquipmentSkillsButton:SetVisible(false)
                    self.mainCardUnEquipButton:SetTouchEnable(true)
                else
                    -- 未装备：显示装备按钮，隐藏卸下按钮
                    self.EquipmentSkillsButton:SetVisible(true)
                    self.mainCardUnEquipButton:SetVisible(false)
                    self.EquipmentSkillsButton:SetTouchEnable(true)
                end
            else
                -- 技能不可装备：隐藏所有装备相关按钮
                self.EquipmentSkillsButton:SetVisible(false)
                self.mainCardUnEquipButton:SetVisible(false)
            end

            -- 升星按钮：未满星且技能已存在时显示
            if self.mainCardUpgradeStarButton then
                if currentStar < maxStar then
                    self.mainCardUpgradeStarButton:SetVisible(true)
                    self.mainCardUpgradeStarButton:SetTouchEnable(true)
                else
                    self.mainCardUpgradeStarButton:SetVisible(false)
                end
            end
        else
            -- 技能未学会：隐藏装备相关按钮和升星按钮
            self.EquipmentSkillsButton:SetVisible(false)
            self.mainCardUnEquipButton:SetVisible(false)

            if self.mainCardUpgradeStarButton then
                self.mainCardUpgradeStarButton:SetVisible(false)
            end
        end

        local maxLevel = skill.maxLevel
        local levelNode = cardFrame["等级"]

        -- 研究按钮：未满级可研究
        if skillLevel < maxLevel then
            self.confirmPointsButton:SetTouchEnable(canAfford)
        else
            self.confirmPointsButton:SetTouchEnable(false)
        end

        if levelNode then
            levelNode.Title = string.format("%d/%d", skillLevel, maxLevel)
        end
    else
        -- 服务端无数据：隐藏所有功能按钮
        self.confirmPointsButton:SetVisible(false)
        self.EquipmentSkillsButton:SetVisible(false)
        self.mainCardUnEquipButton:SetVisible(false)

        if self.mainCardUpgradeStarButton then
            self.mainCardUpgradeStarButton:SetVisible(false)
        end

        -- 显示等级0
        local levelNode = cardFrame["等级"]
        if levelNode then
            levelNode.Title = string.format("0/%d", skill.maxLevel or 1)
        end
    end

    self.currentMCardButtonName = button
end

-- === 新增方法：显示指定品质的副卡列表 ===
function CardsGui:ShowSubCardQuality(quality)
    if self.subQualityLists then
        for q, listNode in pairs(self.subQualityLists) do
            listNode:SetVisible(q == quality)
        end
    end
end

-- === 修改：读取主卡数据并克隆节点（适配新逻辑）===
function CardsGui:LoadMainCardsAndClone()

    local skillMainTrees = SkillTypeUtils.lastForest
    if not skillMainTrees then
        skillMainTrees = SkillTypeUtils.BuildSkillForest(0)
        SkillTypeUtils.lastForest = skillMainTrees
    end

    -- 使用美化的打印函数显示技能树结构
    --SkillTypeUtils.PrintSkillForest(skillMainTrees)
    self:CloneVerticalListsForSkillTrees(skillMainTrees)
end

-- === 新增工具方法：检查主卡是否在服务端解锁 ===
function CardsGui:IsMainCardServerUnlocked(skillName)
    local buttonState = self.mainCardButtonStates[skillName]
    return buttonState and buttonState.serverUnlocked or false
end

-- === 新增工具方法：获取服务端已解锁的主卡列表 ===
function CardsGui:GetServerUnlockedMainCards()
    local unlockedCards = {}
    for _, skillName in ipairs(self.configMainCards) do
        local buttonState = self.mainCardButtonStates[skillName]
        if buttonState and buttonState.serverUnlocked then
            table.insert(unlockedCards, skillName)
        end
    end
    return unlockedCards
end

-- 注册主卡技能书的卡片的ViewButton
function CardsGui:RegisterSkillCardButton(cardFrame, skill, lane, position)
    -- === 重要：在创建ViewButton之前先设置品质图标 ===
    self:_setMainCardQualityIcons(cardFrame, skill)
    -- 设置图标
    if skill.icon and skill.icon ~= "" then
        local iconNode = cardFrame["卡框背景"]["图标"]
        iconNode.Icon = skill.icon
    end

    -- 现在创建ViewButton，此时图标属性已经正确设置
    local viewButton = ViewButton.New(cardFrame, self, nil, "卡框背景")
    viewButton.extraParams = {skillId = skill.name,lane = lane,position = position}
    -- 检查技能是否在服务端数据中存在，设置初始灰色状态
    local serverSkill = self.ServerSkills[skill.name]
    if not serverSkill then
        -- 未解锁技能：设置为灰色
        viewButton:SetGray(true)
    else
        -- 已解锁技能：正常颜色
        viewButton:SetGray(false)
    end
    viewButton.clickCb = function(ui, button)self:OnSkillTreeNodeClick(ui, button, cardFrame)end
    -- 设置技能名称
    cardFrame["技能名"].Title = skill.shortName

    local iconNode = viewButton.img["角标"]
    if iconNode then
        if skill.miniIcon then
            iconNode.Icon = skill.miniIcon
            iconNode.Visible = true
        else
            iconNode.Visible = false
        end
    end
    -- 设置技能等级
    self:SetSkillLevelOnCardFrame(cardFrame, skill)
    self.mainCardButtondict[skill.name] = viewButton
    return viewButton
end

function CardsGui:SetSkillLevelOnCardFrame(cardFrame, skill)
    local severSkill = self.ServerSkills[skill.name]
    local skillLevel = severSkill and severSkill.level or 0
    local star_level = severSkill and severSkill.star_level or 0

    -- 使用工具函数设置等级
    self:_setCardLevel(cardFrame, skillLevel, skill.maxLevel or 1, "等级")

    -- === 新增：只有存在星级容器时才更新星级显示（避免主卡无星级警告）===
    local starContainer = cardFrame["星级"]
    if starContainer then
        -- 使用工具函数设置星级
        self:_updateStarDisplay(cardFrame, star_level)
    end
end

function CardsGui:SetSkillLevelSubCardFrame(cardFrame, skill)
    local severSkill = self.ServerSkills[skill.name]
    local skillLevel = severSkill and severSkill.level or 0
    local star_level = severSkill and severSkill.star_level or 0
    local growth = severSkill and severSkill.growth or 0

    -- 使用工具函数设置等级
    cardFrame["强化等级"].Title = "强化等级:" .. skillLevel
    -- 使用工具函数设置图标和名称
    local iconResources = { iconPath = skill.icon,iconNodePath = "图标底图/图标"}
    self:_setCardIcon(cardFrame, iconResources)
    self:_setCardName(cardFrame, skill.displayName, "副卡名字")
    -- === 新增：设置副卡品质图标 ===
    self:_setSubCardQualityIcons(cardFrame, skill)
    -- 设置new识的可见性
    local newnode = cardFrame["new"]
    if newnode then
        newnode.Visible = false
    end

    -- 使用工具函数设置星级
    self:_updateStarDisplay(cardFrame, star_level)
end

-- === 新增：更新副卡强化进度显示 ===
function CardsGui:UpdateSubCardProgress( skill, growth, skillLevel)
    local cardFrame = self.StrengthenProgressUI
    if not cardFrame or not skill then
        return
    end

    -- 检查技能对象是否有效
    if not skill.GetMaxGrowthAtLevel then
        return
    end


    -- 获取进度条节点（根据UI结构调整路径）
    local progressBar = cardFrame.node["强化进度条"]
    local progressText = cardFrame.node["强化进度值"]


    -- 检查是否满级
    local maxLevel = skill.maxLevel or 1
    if skillLevel >= maxLevel then
        -- 满级处理：设置进度条为100%
        if progressBar then
            progressBar.FillAmount = 1

        end

        if progressText then
            progressText.Title = "满级"
        end


        return
    end

    -- 获取当前等级需要的最大经验值
    local maxGrowthThisLevel = skill:GetMaxGrowthAtLevel(skillLevel)
    if not maxGrowthThisLevel or maxGrowthThisLevel <= 0 then
        maxGrowthThisLevel = 100  -- 使用默认值
    end

    -- 当前经验直接用于进度计算: 当前经验/当前等级最大经验
    local currentLevelProgress = growth
    if currentLevelProgress > maxGrowthThisLevel then
        currentLevelProgress = maxGrowthThisLevel
    end

    -- 计算进度百分比: 当前经验/当前等级最大经验
    local progressPercent = currentLevelProgress / maxGrowthThisLevel


    if progressBar then
        progressBar.FillAmount = progressPercent  -- Fill属性通常是0-1范围
    end
    -- 更新进度文本
    if progressText then
        -- 显示当前经验/当前等级最大经验
        progressText.Title = string.format("%d/%d", currentLevelProgress, maxGrowthThisLevel)
    end


end

-- === 新增：更新副卡属性面板中的强化进度显示 ===
function CardsGui:UpdateSubCardProgressInAttributePanel(attributePanel, skill, growth, skillLevel)
    if not attributePanel or not skill then
        return
    end

    -- 检查技能对象是否有效
    if not skill.GetMaxGrowthAtLevel then
        return
    end

    -- 使用StrengthenProgressUI获取进度条和进度文本节点
    local progressBar = nil
    local progressText = nil

    if self.StrengthenProgressUI and self.StrengthenProgressUI.node then
        local progressUI = self.StrengthenProgressUI.node
        progressBar = progressUI["强化进度条"]
        progressText = progressUI["强化进度显示"]
    end

    -- 检查是否满级
    local maxLevel = skill.maxLevel or 1
    if skillLevel >= maxLevel then
        -- 满级处理 - 使用FillAmount，不修改节点大小
        if progressBar then
            -- 使用FillAmount属性设置满级（100%）
            if progressBar.FillAmount ~= nil then
                progressBar.FillAmount = 1.0
            end
            -- 使用Value属性设置满级
            if progressBar.Value ~= nil then
                progressBar.Value = 100
            end
            -- 兼容性：使用Fill属性
            if progressBar.Fill ~= nil then
                progressBar.Fill = 1.0
            end
            -- ⚠️ 移除Size修改，避免改变节点大小
            -- 移除了progressBar.Size的修改代码
        end

        if progressText then
            progressText.Title = "MAX"
        end

        return
    end

    -- 获取当前等级需要的最大经验值
    local maxGrowthThisLevel = skill:GetMaxGrowthAtLevel(skillLevel)
    if not maxGrowthThisLevel or maxGrowthThisLevel <= 0 then
        maxGrowthThisLevel = 100  -- 使用默认值
    end

    -- 当前经验直接用于进度计算: 当前经验/当前等级最大经验
    local currentLevelProgress = growth
    if currentLevelProgress > maxGrowthThisLevel then
        currentLevelProgress = maxGrowthThisLevel
    end

    -- 计算进度百分比: 当前经验/当前等级最大经验
    local progressPercent = currentLevelProgress / maxGrowthThisLevel

    -- 更新进度条 - 使用FillAmount，不修改节点大小
    if progressBar then
        -- 使用FillAmount属性控制进度（0-1范围）
        if progressBar.FillAmount ~= nil then
            progressBar.FillAmount = progressPercent
        end
        -- 如果是UIProgressBar类型，使用Value属性
        if progressBar.Value ~= nil then
            progressBar.Value = progressPercent * 100  -- Value通常是0-100范围
        end
        -- 兼容性：尝试Fill属性
        if progressBar.Fill ~= nil then
            progressBar.Fill = progressPercent
        end
        -- ⚠️ 移除Size修改，避免改变节点大小
        -- 移除了progressBar.Size的修改代码
    end

    -- 更新进度文本
    if progressText then
        -- 显示当前经验/当前等级最大经验和百分比
        progressText.Title = string.format("强化进度: %d/%d (%.1f%%)",
            currentLevelProgress, maxGrowthThisLevel, progressPercent * 100)
    end


end

-- 更新星级显示 - 重定向到工具函数
function CardsGui:UpdateStarLevelDisplay(cardFrame, star_level)
    self:_updateStarDisplay(cardFrame, star_level)
end

-- 为技能树克隆纵列表
function CardsGui:CloneVerticalListsForSkillTrees(skillMainTrees)
    local verticalListTemplate = self:Get("框体/主卡/加点框/纵列表", ViewList)
    for mainSkillName, skillTree in pairs(skillMainTrees) do
        local clonedVerticalList = verticalListTemplate.node:Clone()
        clonedVerticalList.Name = mainSkillName
        clonedVerticalList.Parent = verticalListTemplate.node.Parent
        clonedVerticalList.Visible = false
        local mainCardFrame = clonedVerticalList["主卡框"]
        local mainCardNode = skillTree.data
        if mainCardFrame then
            self:RegisterSkillCardButton(mainCardFrame, mainCardNode, 0, 2)
        end

        local listTemplate = clonedVerticalList["列表_1"]
        if not listTemplate then return end

        -- ===== 修复后的DAG处理算法 =====
        local nodeDepth = {}         -- 节点深度
        local nodePositions = {}     -- 节点位置
        local layers = {}            -- 按深度分组的节点
        local layerNodes = {}        -- 存储每层的节点和位置信息
        local parentMap = {}         -- 父节点映射
        local processed = {}         -- 标记已处理的节点，防止重复处理

        -- 初始化根节点
        nodeDepth[skillTree] = 0
        nodePositions[skillTree] = 2
        layers[0] = {skillTree}
        layerNodes[0] = {{node = skillTree, position = 2}}
        processed[skillTree] = true  -- 标记根节点已处理

        -- 添加根节点的所有直接子节点到队列
        local queue = {}
        for _, child in ipairs(skillTree.children) do
           if not processed[child] then  -- 只添加未处理的节点
               table.insert(queue, child)
               parentMap[child] = {skillTree}
               processed[child] = true   -- 立即标记为已处理，防止重复入队
           else
               -- 如果子节点已经处理过，只更新其父节点关系
               parentMap[child] = parentMap[child] or {}
               table.insert(parentMap[child], skillTree)
           end
        end

        -- BFS遍历所有节点
        while #queue > 0 do
           local node = table.remove(queue, 1)
           local parents = parentMap[node] or {}

           -- 计算节点深度 = 所有父节点最大深度+1
           local maxParentDepth = -1
           for _, parent in ipairs(parents) do
               if nodeDepth[parent] and nodeDepth[parent] > maxParentDepth then
                   maxParentDepth = nodeDepth[parent]
               end
           end
           local depth = maxParentDepth + 1
           nodeDepth[node] = depth

           -- 添加到层级（每个节点只添加一次）
           layers[depth] = layers[depth] or {}
           table.insert(layers[depth], node)

           -- 初始化当前层的节点位置表
           layerNodes[depth] = layerNodes[depth] or {}

           -- ===== 改进的位置分配算法 =====
           -- 1. 收集所有父节点位置
           local parentPositions = {}
           for _, parent in ipairs(parents) do
               if nodePositions[parent] then
                   table.insert(parentPositions, nodePositions[parent])
               end
           end
           -- 2. 计算理想位置（父节点位置的中位数）
           table.sort(parentPositions)
           local medianPos = parentPositions[math.ceil(#parentPositions/2)] or 2
           -- 3. 检查同层是否已有相同位置的节点
           local targetPos = medianPos
           local positionTaken = {}
           for _, existingItem in ipairs(layerNodes[depth]) do
               positionTaken[existingItem.position] = true
           end
           -- 4. 优化的特殊处理：根据当前层节点数量进行位置分配
           local currentLayerNodes = layerNodes[depth] or {}
           local currentLayerCount = #currentLayerNodes

           if currentLayerCount == 0 then
               -- 当前层的第一个节点，放在中间位置2
               targetPos = 2
           elseif currentLayerCount == 1 then
               -- 当前层已有一个节点，这是第二个节点
               local firstNodePos = currentLayerNodes[1].position
               if firstNodePos == 2 then
                   -- 第一个节点在中间，将其调整到位置1，当前节点设为位置3
                   currentLayerNodes[1].position = 1
                   nodePositions[currentLayerNodes[1].node] = 1
                   targetPos = 3
               else
                   -- 第一个节点不在中间，根据其位置决定当前节点位置
                   if firstNodePos == 1 then
                       targetPos = 3  -- 第一个在左，当前放右
                   else -- firstNodePos == 3
                       targetPos = 1  -- 第一个在右，当前放左
                   end
               end
           else
               -- 当前层已有两个或更多节点，使用原来的位置分配逻辑
               if positionTaken[targetPos] then
                   local candidatePositions = {}
                   for pos = 1, 3 do
                       if not positionTaken[pos] then
                           table.insert(candidatePositions, pos)
                       end
                   end
                   if #candidatePositions > 0 then
                       table.sort(candidatePositions, function(a, b)
                           return math.abs(a - medianPos) < math.abs(b - medianPos)
                       end)
                       targetPos = candidatePositions[1]
                   end
               end
           end
           -- 5. 分配最终位置
           nodePositions[node] = targetPos
           -- 存储当前节点到层节点表
           table.insert(layerNodes[depth], {node = node, position = targetPos})

           -- ===== 处理子节点（防止重复） =====
           for _, child in ipairs(node.children) do
               if not processed[child] then
                   -- 子节点未处理过，加入队列
                   table.insert(queue, child)
                   parentMap[child] = {node}
                   processed[child] = true  -- 立即标记为已处理
               else
                   -- 子节点已处理过，只更新父节点关系
                   parentMap[child] = parentMap[child] or {}
                   table.insert(parentMap[child], node)
               end
           end
        end

        -- ===== 渲染UI层级 =====
        local maxDepth = 0
        for depth in pairs(layers) do
            if depth > maxDepth then maxDepth = depth end
        end

        -- 打印层节点信息（调试用）
        local hierarchyInfo = string.format("技能树层级信息: %s\n", mainSkillName)
        for depth = 0, maxDepth do
            if layerNodes[depth] then
                hierarchyInfo = hierarchyInfo .. string.format("深度 %d: ", depth)
                for _, item in ipairs(layerNodes[depth]) do
                    hierarchyInfo = hierarchyInfo .. string.format("%s [%s] (位置 %d), ", item.node.data.name, tostring(item.node), item.position)
                end
                hierarchyInfo = hierarchyInfo .. "\n"
            end
        end
        gg.log(hierarchyInfo)

        for depth = 0, maxDepth do
            if layers[depth] then
                if depth == 0 then
                    -- 根节点已在主卡框处理
                else
                    local clonedList = listTemplate:Clone()
                    clonedList.Name = "列表_" .. depth
                    clonedList.Parent = clonedVerticalList

                    -- 初始化所有卡框为不可见
                    local lastFound = nil
                    for i = 1, 3 do
                        local cardFrame = clonedList["卡框_" .. i]
                        if cardFrame then
                            lastFound = cardFrame
                        else
                            cardFrame = lastFound:Clone()
                            cardFrame.Parent = lastFound.Parent
                            cardFrame.Name = "卡框_" .. i
                        end
                        cardFrame.Visible = false
                    end

                    -- 使用 layerNodes 表来渲染节点
                    for _, item in ipairs(layerNodes[depth] or {}) do
                        local node = item.node
                        local position = item.position

                        if position and position >= 1 and position <= 3 then
                            local cardFrame = clonedList["卡框_" .. position]
                            if cardFrame then
                                cardFrame.Visible = true
                                cardFrame.Name = node.data.name
                                self:RegisterSkillCardButton(cardFrame, node.data, depth, position)

                                -- ===== 箭头处理逻辑 =====
                                -- 获取所有箭头元素
                                local upRightArrow = cardFrame["上右"]
                                local downRightArrow = cardFrame["下右"]
                                local rightArrow = cardFrame["箭头右"]

                                -- 初始化所有箭头为不可见
                                if upRightArrow then upRightArrow.Visible = false end
                                if downRightArrow then downRightArrow.Visible = false end
                                if rightArrow then rightArrow.Visible = false end

                                -- 如果没有子节点，不需要显示箭头
                                if #node.children == 0 then

                                    -- 这里直接用空语句代替即可
                                else
                                    -- 获取直接子节点的位置
                                    local childPositions = {}
                                    for _, child in ipairs(node.children) do
                                        if layerNodes[depth + 1] then
                                            for _, childItem in ipairs(layerNodes[depth + 1]) do
                                                if childItem.node == child then
                                                    table.insert(childPositions, childItem.position)
                                                    break
                                                end
                                            end
                                        end
                                    end

                                    -- 根据当前节点位置和子节点位置显示箭头
                                    for _, childPos in ipairs(childPositions) do
                                        if position == 1 then -- 当前节点在左边
                                            if childPos == 1 then
                                                if rightArrow then rightArrow.Visible = true end
                                            elseif childPos == 2 then
                                                if downRightArrow then downRightArrow.Visible = true end
                                            else -- childPos == 3
                                                if downRightArrow then downRightArrow.Visible = true end
                                            end
                                        elseif position == 2 then -- 当前节点在中间
                                            if childPos == 1 then
                                                if upRightArrow then upRightArrow.Visible = true end
                                            elseif childPos == 2 then
                                                if rightArrow then rightArrow.Visible = true end
                                            else -- childPos == 3
                                                if downRightArrow then downRightArrow.Visible = true end
                                            end
                                        else -- position == 3 当前节点在右边
                                            if childPos == 1 then
                                                if upRightArrow then upRightArrow.Visible = true end
                                            elseif childPos == 2 then
                                                if upRightArrow then upRightArrow.Visible = true end
                                            else -- childPos == 3
                                                if rightArrow then rightArrow.Visible = true end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        listTemplate:Destroy()
        local verticalList = ViewList.New(clonedVerticalList, self, "框体/主卡/加点框/" .. mainSkillName)
        self.skillLists[mainSkillName] = verticalList
    end

    if verticalListTemplate and verticalListTemplate.node then
        verticalListTemplate.node:Destroy()
    end
end


function CardsGui:BindQualityButtonEvents()
    local qualityListMap = uiConfig.qualityListMap or {}
    for btnName, quality in pairs(qualityListMap) do
        local qualityBtn = self:Get("品质列表/"  .. btnName, ViewButton)
        if qualityBtn then
            qualityBtn.clickCb = function()
                if self.currentCardType == "副卡" or self.currentCardType == "sub" then
                    -- 切换品质时清除当前选中的副卡状态，隐藏属性面板
                    self.currentSubCardButtonName = nil
                    self.subCardAttributeButton:SetVisible(false)

                    -- 使用新的显示方法
                    self:ShowSubCardQuality(quality)
                    self:AutoSelectFirstSubCardInQuality(quality)
                end
            end
        end
    end
end


-- 处理单个新技能添加
function CardsGui:HandleNewSkillAdd(data)
    if not data or not data.data then
        return
    end

    local responseData = data.data
    local skillName = responseData.skillName
    local skillLevel = responseData.level or 0
    local skillSlot = responseData.slot or 0

    if not skillName then
        return
    end

    -- 构建技能数据
    local skillData = {
        level = skillLevel,
        slot = skillSlot,
        skill = skillName
    }

    -- 更新服务端技能数据
    self.ServerSkills[skillName] = skillData

    -- 记录已装备的技能
    if skillSlot > 0 then
        self.equippedSkills[skillSlot] = skillName
    end

    -- 获取技能配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType or not skillType.isEntrySkill then
        return
    end

    -- 根据技能类型生成对应的卡片
    if skillType.category == 0 then
        -- 主卡技能
        self:AddNewMainCardSkill(skillName, skillType, skillData)
    elseif skillType.category == 1 then
        -- 副卡技能
        self:AddNewSubCardSkill(skillName, skillType, skillData)
    end

    -- 更新技能按钮的灰色状态（新获得的技能应该不是灰色）
    if self.mainCardButtondict[skillName] then
        self.mainCardButtondict[skillName].img.Grayed = false
    end

end

-- === 修改：添加新的主卡技能（适配新逻辑）===
function CardsGui:AddNewMainCardSkill(skillName, skillType, skillData)

    -- 检查按钮状态
    local buttonState = self.mainCardButtonStates[skillName]
    if not buttonState then
        -- 如果是配置中不存在的新技能，需要动态添加
        self:AddDynamicMainCardSkill(skillName, skillType, skillData)
        -- 重新排序
        self:SortAndUpdateMainCardLayout()
        return
    end

    if buttonState.serverUnlocked then
        return
    end

    -- 标记为服务端已解锁
    buttonState.serverUnlocked = true
    buttonState.serverData = skillData

    -- 更新装备状态
    self:UpdateMainCardEquipStatus(skillName, skillData)

    -- 恢复按钮正常颜色
    if buttonState.button then
        buttonState.button.img.Grayed = false

        -- 设置装备状态的视觉反馈
        self:SetMainCardEquippedVisual(skillName, buttonState.isEquipped)
    end


    -- 重新排序主卡按钮
    self:SortAndUpdateMainCardLayout()

end

-- === 新增：动态添加配置中不存在的主卡技能 ===
function CardsGui:AddDynamicMainCardSkill(skillName, skillType, skillData)

    -- 添加到配置中
    self.mainCardButtonConfig[skillName] = {
        skillType = skillType,
        rootNode = nil  -- 动态技能可能没有完整的技能树
    }

    -- 获取选择列表
    local ListTemplate = self:Get('框体/主卡/选择列表/列表', ViewList) ---@type ViewList

    -- 计算新的位置（在配置列表的末尾）
    local newPosition = #self.configMainCards + 1
    local child = ListTemplate:GetChild(newPosition)

    if child then
        child.extraParams = child.extraParams or {}
        child.extraParams["skillId"] = skillName
        child.node.Name = skillType.name

        -- 使用工具函数设置图标
        local iconResources = {
            iconPath = skillType.icon,
            iconNodePath = "卡框背景/图标"
        }
        self:_setCardIcon(child.node, iconResources)

        -- === 新增：设置主卡品质图标 ===
        self:_setMainCardQualityIcons(child.node, skillType)

        -- 创建激活状态的按钮（动态添加的技能默认已解锁）
        local button = ViewButton.New(child.node, self, nil, "卡框背景")
        button.extraParams = {skillId = skillName}
        button:SetTouchEnable(true, false) -- 可点击，不自动变灰

        -- 动态添加的技能默认为正常颜色（已解锁）
        button.img.Grayed = false


        button.clickCb = function(ui, button)
            local skillId = button.extraParams["skillId"]

            -- === 移除了选择组管理，直接调用相关方法 ===

            local currentList = self.skillLists[skillId]
            if currentList then
                -- 隐藏所有其他技能树
                for name, vlist in pairs(self.skillLists) do
                    if name ~= skillId then
                        vlist:SetVisible(false)
                    end
                end
                -- 显示当前技能树
                currentList:SetVisible(true)

                -- 点击主卡选择按钮时显示属性面板
                self.attributeButton:SetVisible(true)
                -- === 新增：自动显示对应主卡的属性信息 ===
                self:AutoClickMainCardFrameInSkillTree(skillId)
            else

                -- 尝试重新创建技能树
                local skillType = SkillTypeConfig.Get(skillId)
                if skillType then
                    -- 创建成功后显示属性面板
                    if self.skillLists[skillId] then
                        self.attributeButton:SetVisible(true)
                        -- === 新增：自动显示对应主卡的属性信息 ===
                        self:AutoClickMainCardFrameInSkillTree(skillId)
                    end

                else
                end
            end
        end


        -- 存储按钮状态
        self.skillButtons[skillName] = button
        self.mainCardButtonStates[skillName] = {
            button = button,
            position = newPosition,
            serverUnlocked = true,
            isEquipped = skillData.slot and skillData.slot > 0 or false,
            equipSlot = skillData.slot or 0,
            serverData = skillData,
            configData = skillType
        }

        -- 添加到配置列表
        table.insert(self.configMainCards, skillName)


    else
    end
end

-- === 修改：添加新的副卡技能（适配新逻辑）===
function CardsGui:AddNewSubCardSkill(skillName, skillType, skillData)

    -- 检查按钮状态
    local buttonState = self.subCardButtonStates[skillName]
    if not buttonState then
        -- 如果是配置中不存在的新技能，需要动态添加
        self:AddDynamicSubCardSkill(skillName, skillType, skillData)
        return
    end

    if buttonState.serverUnlocked then
        return
    end

    -- 标记为服务端已解锁
    buttonState.serverUnlocked = true
    -- 恢复按钮正常颜色
    if buttonState.button then
        buttonState.button.img.Grayed = false
        buttonState.button.extraParams.serverData = skillData
    end

    -- 重新排序副卡按钮
    self:SortAndUpdateSubCardLayout()

end

-- === 新增：动态添加配置中不存在的副卡技能 ===
function CardsGui:AddDynamicSubCardSkill(skillName, skillType, skillData)

    local quality = skillType.quality or "N"

    -- 添加到配置中
    self.subCardButtonConfig[skillName] = {
        skillType = skillType
    }
    table.insert(self.configSubCards, skillName)

    -- 初始化按钮状态（动态添加的技能默认已解锁）
    self.subCardButtonStates[skillName] = {
        button = nil,
        position = 0, -- 稍后会重新计算
        serverUnlocked = true,
        configData = skillType
    }

    -- === 先检查原品质列表是否存在 ===
    local qualityList = self.subQualityLists[quality]
    if not qualityList then
        return
    end

    -- === 准备要更新的品质列表 ===
    local qualitiesToUpdate = {quality}  -- 添加到原品质列表
    if quality ~= "ALL" and self.subQualityLists["ALL"] then
        table.insert(qualitiesToUpdate, "ALL")  -- 也添加到ALL列表（如果存在）
    end

    -- 获取副卡模板
    local subCardTemplate = self:Get('框体/副卡/副卡列/副卡列表/副卡槽_1', ViewButton)
    if not subCardTemplate or not subCardTemplate.node then
        return
    end
    local existingSubCard = subCardTemplate.node

    -- === 为每个相关品质列表创建副卡按钮 ===
    for index, qualityToUpdate in ipairs(qualitiesToUpdate) do
        local currentQualityList = self.subQualityLists[qualityToUpdate]
        if currentQualityList then
            -- 克隆新的副卡节点
            local clonedNode = existingSubCard:Clone()
            clonedNode.Name = skillName
            clonedNode.Visible = true

            -- 设置副卡UI
            self:SetSkillLevelSubCardFrame(clonedNode, skillType)

            -- 使用AppendChild添加到ViewList
            currentQualityList:AppendChild(clonedNode)

            -- 创建按钮（动态添加的技能默认为正常颜色）
            local subCardButton = ViewButton.New(clonedNode, self)
            subCardButton.extraParams = {
                skillId = skillName,
                serverData = skillData
            }
            subCardButton:SetTouchEnable(true)
            subCardButton.img.Grayed = false  -- 动态添加的技能默认已解锁

            subCardButton.clickCb = function(ui, button)
                self:OnSubCardButtonClick(ui, button)
            end
            -- 如果是原品质，存储按钮引用
            if qualityToUpdate == quality then
                self.subCardButtondict[skillName] = subCardButton
                self.subCardButtonStates[skillName] = {
                    button = subCardButton,
                    position = index,
                    serverUnlocked = false,
                    configData = skillType
                }
            end

            -- 更新列表的LineCount
            local currentCount = currentQualityList.node.LineCount or 0
            currentQualityList.node.LineCount = currentCount + 1

        end
    end
end

-- === 新增调试方法：获取技能列表数量 ===
function CardsGui:GetSkillListsCount()
    local count = 0
    for _ in pairs(self.skillLists) do
        count = count + 1
    end
    return count
end



-- === 新增方法：显示技能树 ===
function CardsGui:ShowSkillTree(skillName)

    local currentList = self.skillLists[skillName]
    if currentList then
        -- 隐藏所有其他技能树
        for name, vlist in pairs(self.skillLists) do
            if name ~= skillName then
                vlist:SetVisible(false)
            end
        end
        -- 显示当前技能树
        currentList:SetVisible(true)
    else
    end
end

-- === 新增方法：加载副卡配置 ===
function CardsGui:LoadSubCardConfig()

    local allSkills = SkillTypeConfig.GetAll()
    -- 遍历所有技能，找到副卡入口技能
    for skillName, skillType in pairs(allSkills) do
        if skillType.category == 1 and skillType.isEntrySkill then
            -- 存储配置数据
            self.subCardButtonConfig[skillName] = {
                skillType = skillType
            }
            table.insert(self.configSubCards, skillName)
            -- 初始化按钮状态
            self.subCardButtonStates[skillName] = {
                button = nil,
                position = #self.configSubCards,
                serverUnlocked = false,  -- 是否在服务端解锁
                configData = skillType
            }
        end
    end

end

-- === 新增方法：初始化所有副卡按钮（置灰状态）===
function CardsGui:InitializeSubCardButtons()

    local qualityList = uiConfig.qualityList

    -- 按品级分组副卡
    local subCardsByQuality = {}
    for _, quality in ipairs(qualityList) do
        subCardsByQuality[quality] = {}
    end

    -- 分类配置的副卡
    for _, skillName in ipairs(self.configSubCards) do
        local skillConfig = self.subCardButtonConfig[skillName]
        local skillType = skillConfig.skillType
        local quality = skillType.quality or "N"

        -- 将副卡添加到对应品质列表
        if subCardsByQuality[quality] then
            table.insert(subCardsByQuality[quality], skillName)
        end
        if subCardsByQuality["ALL"] then
            table.insert(subCardsByQuality["ALL"], skillName)
        end
        -- === 为每个副卡创建素材需求ViewList ===
        self:CreateSubCardMaterialViewList(skillName)
    end
    -- 存放各品级的副卡列表
    for _, quality in ipairs(qualityList) do
        local qualityList = self:Get('框体/副卡/副卡列/副卡列表_'.. quality, ViewList) ---@type ViewList
        qualityList:SetVisible(false)
        local listClone = qualityList.node
        local qualityName = "副卡列表_" .. quality
        listClone.Name = qualityName
        listClone.Visible = false
        local count = #subCardsByQuality[quality]
        listClone.LineCount = count > 0 and count or 1
        self.subQualityLists[quality] = qualityList
    end

    -- 获取副卡模板
    local existingSubCard = self:Get('框体/副卡/副卡列/副卡列表/副卡槽_1', ViewButton).node

    -- 为每个品级生成对应的副卡按钮（置灰状态）
    for _, quality in ipairs(qualityList) do
        local qualitySkills = subCardsByQuality[quality]
        local ViewListNode = self.subQualityLists[quality]  

        if ViewListNode then
            for index, skillName in ipairs(qualitySkills) do
                local skillConfig = self.subCardButtonConfig[skillName]
                local skillType = skillConfig.skillType
                -- 克隆副卡节点，使用正确的命名格式
                local clonedNode = existingSubCard:Clone()
                clonedNode.Name = skillName
                -- 使用AppendChild添加到ViewList
                local subCardButton = ViewButton.New(clonedNode, self)
                subCardButton.extraParams = {skillId = skillName,serverData = nil } -- 初始无服务端数据
                subCardButton:SetTouchEnable(true) -- 可点击
                subCardButton.clickCb = function(ui, button) self:OnSubCardButtonClick(ui, button)end
                ViewListNode:insertIntoChildrens(subCardButton, index)
                -- 设置副卡UI
                self:SetSkillLevelSubCardFrame(clonedNode, skillType)
                -- 初始化时隐藏所有星级（因为还没有服务端数据）
                self:UpdateStarLevelDisplay(clonedNode, 0)
                -- 存储按钮引用
                self.subCardButtondict[skillName] = subCardButton
                self.subCardButtonStates[skillName] = {
                    button = subCardButton,
                    position = index,
                    serverUnlocked = false,
                    configData = skillType
                }

            end
        end
    end
    -- 默认显示ALL品质（初始化完成后）
    self:ShowSubCardQuality("ALL")
end

-- === 新增方法：更新副卡属性面板 ===
function CardsGui:UpdateSubCardAttributePanel(skill, skillLevel, serverData)
    -- 点击副卡时显示属性面板
    self.subCardAttributeButton:SetVisible(true)

    local attributeButton = self.subCardAttributeButton.node

    -- 更新副卡名称
    local nameNode = attributeButton["卡片名字"]
    if nameNode then
        nameNode.Title = skill.displayName or skill.name
    end

    -- 更新副卡描述
    local descNode = attributeButton["卡片介绍"]
    if descNode then
        descNode.Title = skill.description or "暂无描述"
    end

    -- === 新增：更新属性面板中的强化进度显示 ===
    local growth = serverData and serverData.growth or 0
    self:UpdateSubCardProgressInAttributePanel(attributeButton, skill, growth, skillLevel)

    -- 更新强化前后属性
    local descPreTitleNode = attributeButton["列表_强化前"]["强化标题"]
    local descPostTitleNode = attributeButton["列表_强化后"]["强化标题"]
    local descPreNode = attributeButton["列表_强化前"]["属性_1"]
    local descPostNode = attributeButton["列表_强化后"]["属性_1"]

    descPreTitleNode.Title = string.format("等级 %d/%d", skillLevel, skill.maxLevel or 1)

    -- 显示当前等级属性
    local descPre = {}
    if skill.passiveTags then
        for _, tag in pairs(skill.passiveTags) do
            table.insert(descPre, tag:GetDescription(skillLevel))
        end
    end
    descPreNode.Title = table.concat(descPre, "\n")

    -- 显示下一等级属性或满级提示
    if skillLevel < (skill.maxLevel or 1) then
        descPostTitleNode.Title = string.format("等级 %d/%d", skillLevel+1, skill.maxLevel or 1)
        local descPost = {}
        if skill.passiveTags then
            for _, tag in pairs(skill.passiveTags) do
                table.insert(descPost, tag:GetDescription(skillLevel+1))
            end
        end
        descPostNode.Title = table.concat(descPost, "\n")
    else
        descPostTitleNode.Title = "已满级"
        descPostNode.Title = ""
    end
        self:_updateSubCardFunctionButtons(skill, skillLevel, serverData)
end

-- === 新增方法：处理服务端副卡数据 ===
function CardsGui:ProcessServerSubCardData(serverSubskillDic)

    -- 处理所有配置的副卡，更新解锁状态
    for _, skillName in ipairs(self.configSubCards) do
        local buttonState = self.subCardButtonStates[skillName]
        if buttonState then
            -- 检查是否在服务端数据中
            local serverSkill = serverSubskillDic[skillName]
            if serverSkill and serverSkill.serverData then
                local serverData = serverSkill.serverData

                -- 标记为服务端已解锁
                buttonState.serverUnlocked = true
                buttonState.serverData = serverData
                self:UpdateSubCardEquipStatus(skillName, serverData)
                if buttonState.button then
                    -- 恢复按钮正常颜色（已解锁）
                    buttonState.button:SetGray(false)
                    -- 更新按钮的服务端数据
                    buttonState.button.extraParams.serverData = serverData
                end

                -- 更新副卡的星级显示
                self:UpdateSubCardTreeNodeDisplay(skillName)
            else
                -- 确保未解锁的副卡保持灰色
                buttonState.serverUnlocked = false
                self:UpdateSubCardEquipStatus(skillName, nil)

                if buttonState.button then
                    buttonState.button:SetGray(true)
                    buttonState.button.extraParams.serverData = nil
                end
            end
        end
    end

    -- 重新排序副卡按钮：已解锁的在前，未解锁的在后
    self:SortAndUpdateSubCardLayout()

end

-- === 优化后的排序和更新副卡布局方法 ===
function CardsGui:SortAndUpdateSubCardLayout()
    local qualityList = uiConfig.qualityList

    -- 按品级分别排序
    for _, quality in ipairs(qualityList) do
        local qualityCards = self:_getSubCardsByQuality(quality)

        if #qualityCards > 0 then
            -- 使用工具函数进行排序
            self:_sortCardsByPriority(qualityCards, self.subCardButtonStates, function(aState, bState)
                return self:_getSubCardPriority(aState, bState)
            end)

            -- 重新创建该品级的副卡按钮
            self:RecreateSubCardButtonsInOrder(quality, qualityCards)
        end
    end
end

-- 获取指定品质的副卡列表
function CardsGui:_getSubCardsByQuality(quality)
    local qualityCards = {}

    if quality == "ALL" then
        -- ALL品质：包含所有副卡
        for _, skillName in ipairs(self.configSubCards) do
            table.insert(qualityCards, skillName)
        end
    else
        -- 其他品质：只包含对应品质的副卡
        for _, skillName in ipairs(self.configSubCards) do
            local buttonState = self.subCardButtonStates[skillName]
            if buttonState and buttonState.configData and buttonState.configData.quality == quality then
                table.insert(qualityCards, skillName)
            end
        end
    end

    return qualityCards
end

-- === 修改：按顺序重新创建副卡按钮（添加移除旧节点逻辑） ===
function CardsGui:RecreateSubCardButtonsInOrder(quality, sortedCards)
    gg.log("副卡重新排序", quality, sortedCards)
    local qualityList = self.subQualityLists[quality]
    if not qualityList then return end

    -- 获取副卡模板
    local subCardTemplate = self:Get('框体/副卡/副卡列/副卡列表/副卡槽_1', ViewButton)
    if not subCardTemplate or not subCardTemplate.node then
        return
    end
    local templateNode = subCardTemplate.node

    -- 步骤 1: 建立当前子节点的映射，方便快速查找
    local existingChildrenMap = {}
    for _, child in ipairs(qualityList.childrens) do
        if child.node and child.node.Name then
            existingChildrenMap[child.node.Name] = child
        end
    end
    -- 步骤 2: 遍历排序后的列表，协调UI状态
    local newChildrens = {}
    for newIndex, skillName in ipairs(sortedCards) do
        local buttonState = self.subCardButtonStates[skillName]
        -- 使用 if 替代 goto
        if buttonState and buttonState.configData then
            local skillType = buttonState.configData
            local subCardButton

            -- 检查节点是否已存在
            if existingChildrenMap[skillName] then
                subCardButton = existingChildrenMap[skillName]
                
                -- 标记为已处理，这样它就不会在末尾被删除
                existingChildrenMap[skillName] = nil
            else
                -- 节点不存在，创建新的
                local clonedNode = templateNode:Clone()
                clonedNode.Name = skillName
                
                subCardButton = ViewButton.New(clonedNode, self)
                subCardButton.extraParams = {skillId = skillName}
                subCardButton.clickCb = function(ui, button) self:OnSubCardButtonClick(ui, button) end
                -- 更新全局存储
                self.subCardButtondict[skillName] = subCardButton
                self.subCardButtonStates[skillName].button = subCardButton
            end
            -- 步骤 3: 更新按钮状态（无论是新是旧）
            subCardButton.extraParams.serverData = buttonState.serverData
            subCardButton.node.Visible = true
            self:SetSkillLevelSubCardFrame(subCardButton.node, skillType)
            subCardButton:SetGray(not buttonState.serverUnlocked)
            buttonState.position = newIndex
            table.insert(newChildrens, subCardButton)
        end
    end

    -- 新增：步骤 4: 移除不再需要的旧节点
    for skillName, child in pairs(existingChildrenMap) do
        if child and child.node then
            child.node:Destroy()
            -- 从字典中移除，防止内存泄漏
            self.subCardButtondict[skillName] = nil
            if self.subCardButtonStates[skillName] then
                self.subCardButtonStates[skillName].button = nil
            end
        end
    end

    -- 步骤 5: 应用新的子节点列表并刷新布局
    qualityList.childrens = newChildrens
    qualityList:_refreshLayout()
end

-- === 新增方法：处理技能等级设置响应（管理员指令）===
function CardsGui:OnSkillSetLevelResponse(response)
    gg.log("收到技能等级设置响应", response)
    local data = response.data
    local skillName = data.skillName
    local newLevel = data.level
    local newGrowth = data.growth or 0
    local slot = data.slot or 0
    local removed = data.removed or false

    if not skillName then
        return
    end

    -- 获取技能类型配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        return
    end

    if removed then
        -- 技能被移除：从服务端技能数据中移除
        self.ServerSkills[skillName] = nil

        -- 从装备槽中移除
        for equipSlot, equippedSkillName in pairs(self.equippedSkills) do
            if equippedSkillName == skillName then
                self.equippedSkills[equipSlot] = nil
                break
            end
        end

        -- 根据技能类型更新UI
        if skillType.category == 0 then
            -- 主卡被移除：更新主卡状态
            self:HandleMainCardRemoval(skillName, skillType)
        elseif skillType.category == 1 then
            -- 副卡被移除：更新副卡状态
            self:HandleSubCardRemoval(skillName, skillType)
        end
    else
        -- 技能等级/经验被更新：更新服务端数据

        -- 更新或创建服务端技能数据
        if not self.ServerSkills[skillName] then
            self.ServerSkills[skillName] = {}
        end

        local skillData = self.ServerSkills[skillName]
        skillData.level = newLevel
        skillData.growth = newGrowth
        skillData.slot = slot
        skillData.skill = skillName

        -- 更新装备槽数据
        if slot > 0 then
            self.equippedSkills[slot] = skillName
        end

        -- 根据技能类型更新UI
        if skillType.category == 0 then
            -- 主卡更新：更新主卡状态和显示
            self:HandleMainCardUpdate(skillName, skillType, skillData)
        elseif skillType.category == 1 then
            -- 副卡更新：更新副卡状态和显示
            self:HandleSubCardUpdate(skillName, skillType, skillData)
        end
    end

end

-- === 新增方法：处理主卡移除 ===
function CardsGui:HandleMainCardRemoval(skillName, skillType)
    -- 更新主卡按钮状态
    local buttonState = self.mainCardButtonStates[skillName]
    if buttonState then
        buttonState.serverUnlocked = false
        buttonState.isEquipped = false
        buttonState.equipSlot = 0
        buttonState.serverData = nil

        -- 更新按钮显示（设为灰色）
        if buttonState.button then
            buttonState.button.img.Grayed = true
            self:SetMainCardEquippedVisual(skillName, false)
        end
    end

    -- 更新主卡技能树显示
    self:UpdateSkillTreeNodeDisplay(skillName)

    -- 重新排序主卡布局
    self:SortAndUpdateMainCardLayout()

end

-- === 新增方法：处理副卡移除 ===
function CardsGui:HandleSubCardRemoval(skillName, skillType)
    -- 更新副卡按钮状态
    local buttonState = self.subCardButtonStates[skillName]
    if buttonState then
        buttonState.serverUnlocked = false
        -- 更新按钮显示（设为灰色）
        if buttonState.button then
            buttonState.button.img.Grayed = true
            buttonState.button.extraParams.serverData = nil
        end
    end

    -- 更新副卡显示
    self:UpdateSubCardTreeNodeDisplay(skillName)

    -- 重新排序副卡布局
    self:SortAndUpdateSubCardLayout()

    -- 如果当前选中的是被移除的副卡，清除选择状态
    if self.currentSubCardButtonName and
       self.currentSubCardButtonName.extraParams.skillId == skillName then
        self.currentSubCardButtonName = nil
        self.subCardAttributeButton:SetVisible(false)
    end

end

-- === 新增方法：处理主卡更新 ===
function CardsGui:HandleMainCardUpdate(skillName, skillType, skillData)
    -- 更新主卡按钮状态
    local buttonState = self.mainCardButtonStates[skillName]
    if buttonState then
        buttonState.serverUnlocked = true
        buttonState.serverData = skillData
        self:UpdateMainCardEquipStatus(skillName, skillData)

        -- 更新按钮显示（恢复正常颜色）
        if buttonState.button then
            buttonState.button.img.Grayed = false
            self:SetMainCardEquippedVisual(skillName, buttonState.isEquipped)
        end
    else
        -- 如果是新创建的主卡技能，需要动态添加
        self:AddDynamicMainCardSkill(skillName, skillType, skillData)
    end

    -- 更新主卡技能树显示
    self:UpdateSkillTreeNodeDisplay(skillName)

    -- 重新排序主卡布局
    self:SortAndUpdateMainCardLayout()

    -- 如果当前选中的是这个主卡，更新属性面板
    if self.currentMCardButtonName and
       self.currentMCardButtonName.extraParams.skillId == skillName then
        -- 重新触发点击事件以更新属性面板
        local mainCardFrameButton = self.mainCardButtondict[skillName]
        if mainCardFrameButton then
            self:OnSkillTreeNodeClick(nil, mainCardFrameButton, mainCardFrameButton.node)
        end
    end

end

-- === 新增方法：处理副卡更新 ===
function CardsGui:HandleSubCardUpdate(skillName, skillType, skillData)
    -- 更新副卡按钮状态
    local buttonState = self.subCardButtonStates[skillName]
    if buttonState then
        buttonState.serverUnlocked = true

        -- 更新按钮显示（恢复正常颜色）
        if buttonState.button then
            buttonState.button.img.Grayed = false
            buttonState.button.extraParams.serverData = skillData
        end
    else
        -- 如果是新创建的副卡技能，需要动态添加
        self:AddDynamicSubCardSkill(skillName, skillType, skillData)
    end

    -- 更新副卡显示
    self:UpdateSubCardTreeNodeDisplay(skillName)

    -- 重新排序副卡布局
    self:SortAndUpdateSubCardLayout()

    -- 如果当前选中的是这个副卡，更新属性面板和进度显示
    if self.currentSubCardButtonName and
       self.currentSubCardButtonName.extraParams.skillId == skillName then
        -- 更新按钮的服务端数据
        self.currentSubCardButtonName.extraParams.serverData = skillData

        -- 重新触发点击事件以更新属性面板和进度条
        self:OnSubCardButtonClick(nil, self.currentSubCardButtonName)
    end

end

-- === 创建副卡素材需求ViewList ===
function CardsGui:CreateSubCardMaterialViewList(skillName)

    if not skillName then
        return
    end

    -- 获取技能配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        return
    end

    local subCardEnhancementList = self:Get("框体/副卡/素材需求框/素材列表", ViewList)
    local materiaTemplate = self:Get('框体/副卡/素材需求框/素材列表/素材_1', ViewComponent)

    if not materiaTemplate then
        return
    end
    -- 克隆素材列表
    local materiaListClone = subCardEnhancementList.node:Clone()
    materiaListClone.Name = skillName
    materiaListClone.Parent = subCardEnhancementList.node.Parent
    subCardEnhancementList:SetVisible(false)
    -- 清除原有的素材模板
    for _, child in ipairs(materiaListClone.Children) do
        if string.find(child.Name, "素材_") then
            child:Destroy()
        end
    end

    -- 获取技能的升级素材需求（假设以1级为例来获取素材类型）
    local upgradeCosts = skillType:GetCostAtLevel(1)
    if upgradeCosts and next(upgradeCosts) then
        -- 遍历素材需求，为每个素材创建对应的子节点
        for materialName, costFormula in pairs(upgradeCosts) do
            -- 获取物品配置
            local itemConfig = ItemTypeConfig.Get(materialName)
            if itemConfig then
                -- 克隆素材模板
                local materialNodeclone = materiaTemplate.node:Clone()
                materialNodeclone.Name = materialName
                materialNodeclone.Parent = materiaListClone
                materialNodeclone.Visible = true
                -- 设置素材图标
                local iconNode = materialNodeclone["图标"]
                if iconNode and itemConfig.icon and itemConfig.icon ~= "" then
                    iconNode.Icon = itemConfig.icon
                end
                local countNode = materialNodeclone["货币量对比"]

                countNode.Title = "0/"..math.abs(costFormula)

            else
            end
        end
    end

    -- 创建ViewList实例
    local materiaListIns = ViewList.New(materiaListClone, self, "框体/副卡/素材需求框/"..skillName)
    materiaListIns:SetGray(true)
    materiaListIns:SetVisible(false)
    -- 存储ViewList引用
    self.subCardMaterialLists[skillName] = materiaListIns

end

-- === 更新副卡素材需求显示 ===
function CardsGui:UpdateSubCardMaterialRequirements(skillName, skillLevel)
    if not skillName then
        return
    end

    -- 隐藏所有副卡的素材需求
    for otherSkillName, materialViewList in pairs(self.subCardMaterialLists) do
        if materialViewList and materialViewList.node then
            materialViewList.node.Visible = false
        end
    end

    -- 获取当前副卡的素材ViewList
    local materialViewList = self.subCardMaterialLists[skillName]
    if not materialViewList then
        return
    end

    local ServerSkillData =  self.ServerSkills[skillName]

    -- 获取技能配置
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        return
    end

    -- 获取下一级升级成本
    local currentLevel = skillLevel or 0
    local nextLevel = currentLevel + 1
    local upgradeCosts = skillType:GetCostAtLevel(nextLevel)

    if not upgradeCosts or not next(upgradeCosts) then
        materialViewList.node.Visible = false
        return
    end

    -- 更新素材槽显示
    for materialName, costAmount in pairs(upgradeCosts) do
        local materialNode = materialViewList.node[materialName]
        if materialNode then
            local needAmount = math.abs(costAmount)
            local currentAmount = self:GetItemAmount(materialName)
            local countNode = materialNode["货币量对比"]
            if countNode then
                countNode.Title = currentAmount .. "/" .. needAmount
            end
        end
    end

    -- 显示当前副卡的素材需求
    if ServerSkillData then
        materialViewList:SetGray(false)
    else
        materialViewList:SetGray(true)

    end
    materialViewList:SetVisible(true)
end



-- === 背包库存处理方法 ===
-- 处理背包库存同步事件
function CardsGui:HandleInventorySync(data)

    if not data then
        return
    end

    local items = data.items or {}
    local moneys = data.moneys or {}

    -- 创建整合后的库存数据
    local inventory = {}

    -- 处理普通物品数据
    for slot, itemData in pairs(items) do
        if itemData and itemData.itype and itemData.amount then
            local itemName = itemData.itype
            local amount = itemData.amount or 0

            -- 如果物品已存在，累加数量
            if inventory[itemName] then
                inventory[itemName] = inventory[itemName] + amount
            else
                inventory[itemName] = amount
            end
        end
    end

    -- 处理货币数据
    for _, moneyData in ipairs(moneys) do
        if moneyData and moneyData.it and moneyData.a then
            local moneyName = moneyData.it
            local amount = moneyData.a or 0

            -- 货币直接设置（不累加，因为货币数据本身就是总数）
            inventory[moneyName] = amount
        end
    end

    -- 保存到本地库存数据中
    self.playerInventory = inventory

    -- -- 打印整合后的库存数据
    -- gg.log("=== CardsGui - 玩家库存数据 ===")
    -- local sortedItems = {}
    -- for itemName, amount in pairs(inventory) do
    --     table.insert(sortedItems, {name = itemName, amount = amount})
    -- end
    -- === 更新当前显示的副卡素材需求 ===
    if self.currentSubCardButtonName then
        local skillId = self.currentSubCardButtonName.extraParams.skillId
        local skillLevel = self.ServerSkills[skillId].level
        self:UpdateSubCardMaterialRequirements(skillId, skillLevel)
    end

    -- 打印整合后的库存数据
    gg.log("=== CardsGui - 玩家库存数据 ===")
    local sortedItems = {}
    for itemName, amount in pairs(inventory) do
        table.insert(sortedItems, {name = itemName, amount = amount})
    end

    -- -- 按物品名称排序
    -- table.sort(sortedItems, function(a, b)
    --     return a.name < b.name
    -- end)

    -- for _, item in ipairs(sortedItems) do
    --     gg.log(string.format("%s: %d", item.name, item.amount))
    -- end
    -- gg.log("=== CardsGui - 库存数据结束 ===",self.playerInventory)

end


-- === 库存查询API ===
-- 获取指定物品的数量
function CardsGui:GetItemAmount(itemName)
    return self.playerInventory[itemName] or 0
end

-- 检查是否拥有足够的物品
function CardsGui:HasItems(requiredItems)
    for itemName, requiredAmount in pairs(requiredItems) do
        local currentAmount = self:GetItemAmount(itemName)
        if currentAmount < requiredAmount then
            return false
        end
    end
    return true
end

-- 获取不足的物品列表
function CardsGui:GetInsufficientItems(requiredItems)
    local insufficientItems = {}
    for itemName, requiredAmount in pairs(requiredItems) do
        local currentAmount = self:GetItemAmount(itemName)
        if currentAmount < requiredAmount then
            insufficientItems[itemName] = requiredAmount - currentAmount
        end
    end
    return insufficientItems
end

-- 检查技能升级资源（示例方法）
function CardsGui:CheckSkillUpgradeResources(skillName)
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then return end

    local serverSkill = self.ServerSkills[skillName]
    local currentLevel = serverSkill and serverSkill.level or 0

    if currentLevel >= (skillType.maxLevel or 1) then
        return
    end

    -- 获取升级成本
    local cost = skillType:GetCostAtLevel(currentLevel + 1)
    if cost then
        local canUpgrade = true
        local missingItems = {}

        for resourceName, requiredAmount in pairs(cost) do
            if requiredAmount < 0 then  -- 负数表示消耗
                local needAmount = math.abs(requiredAmount)
                local currentAmount = self:GetItemAmount(resourceName)

                if currentAmount < needAmount then
                    canUpgrade = false
                    missingItems[resourceName] = needAmount - currentAmount
                end
            end
        end

    end
end

-- 计算一键强化的总消耗（逐级检查资源限制）
function CardsGui:CalculateUpgradeAllCost(skillName)
    local skillType = SkillTypeConfig.Get(skillName)
    if not skillType then
        return
    end

    local serverSkill = self.ServerSkills[skillName]
    local currentLevel = serverSkill and serverSkill.level or 0
    local maxLevel = skillType.maxLevel or 1

    if currentLevel >= maxLevel then
        return
    end


    -- 获取玩家当前拥有的资源（创建副本，避免修改原始数据）
    local availableResources = {}
    for resourceName, amount in pairs(self.playerInventory or {}) do
        availableResources[resourceName] = amount
    end

    -- 逐级计算消耗，找到最高可达等级
    local cumulativeCost = {}  -- 累计总消耗
    local levelDetails = {}    -- 每一级的详细信息
    local maxAchievableLevel = currentLevel  -- 最高可达等级
    local isResourceLimited = false  -- 是否受资源限制
    local limitingResource = nil     -- 限制资源名称

    for level = currentLevel + 1, maxLevel do
        local levelCost = skillType:GetOneKeyUpgradeCostsAtLevel(level)

        if levelCost then
            -- 检查这一级是否有足够资源
            local canUpgradeThisLevel = true
            local thisLevelCost = {}

            for resourceName, amount in pairs(levelCost) do
                local consumeAmount = math.abs(amount)
                thisLevelCost[resourceName] = consumeAmount

                -- 检查累计消耗后是否还有足够资源
                local totalNeeded = (cumulativeCost[resourceName] or 0) + consumeAmount
                local available = availableResources[resourceName] or 0

                if available < totalNeeded then
                    canUpgradeThisLevel = false
                    isResourceLimited = true
                    limitingResource = resourceName
                    break
                end

            end

            if canUpgradeThisLevel then
                -- 更新累计消耗
                local levelInfo = {}
                for resourceName, consumeAmount in pairs(thisLevelCost) do
                    cumulativeCost[resourceName] = (cumulativeCost[resourceName] or 0) + consumeAmount
                    table.insert(levelInfo, resourceName .. ":" .. consumeAmount)
                end

                maxAchievableLevel = level
                if #levelInfo > 0 then
                    levelDetails[level] = "等级" .. (level-1) .. "→" .. level .. " [" .. table.concat(levelInfo, ", ") .. "]"
                end
            else
                break
            end
        end
    end

    -- 构建返回结果
    local result = {
        skillName = skillName,
        currentLevel = currentLevel,
        maxLevel = maxLevel,
        maxAchievableLevel = maxAchievableLevel,
        canUpgrade = maxAchievableLevel > currentLevel,
        canFullUpgrade = maxAchievableLevel == maxLevel,
        cumulativeCost = cumulativeCost,
        availableResources = availableResources,
        limitingResource = limitingResource,
        isResourceLimited = isResourceLimited
    }

    -- 计算下一级所需资源（如果适用）
    if maxAchievableLevel + 1 <= maxLevel and limitingResource then
        local nextLevelCost = skillType:GetCostAtLevel(maxAchievableLevel + 1)
        if nextLevelCost and nextLevelCost[limitingResource] then
            local nextLevelNeed = math.abs(nextLevelCost[limitingResource])
            local totalNeedForNext = (cumulativeCost[limitingResource] or 0) + nextLevelNeed
            local missing = totalNeedForNext - (availableResources[limitingResource] or 0)
            result.nextLevelMissing = {
                resource = limitingResource,
                need = nextLevelNeed,
                missing = missing
            }
        end
    end

    return result
end

-- 显示升级确认对话框
function CardsGui:ShowUpgradeConfirmDialog(skillName)
    if not skillName then return end

    -- 计算升级数据
    local upgradeData = self:CalculateUpgradeAllCost(skillName)
    if not upgradeData then return end

    -- 保存当前升级数据
    self.currentUpgradeData = upgradeData

    -- 生成显示内容
    local contentText = self:GenerateUpgradeContentText(upgradeData)
    self.ConfirmStrengthenUI.node.content.Title = contentText
    -- 显示确认对话框
    if self.ConfirmStrengthenUI then
        self.ConfirmStrengthenUI.node.Visible = true
    end

end

-- 生成升级内容文本
function CardsGui:GenerateUpgradeContentText(upgradeData)
    local lines = {}

    -- 技能信息
    table.insert(lines, string.format("技能：%s", upgradeData.skillName))

    if upgradeData.canFullUpgrade then
        table.insert(lines, string.format("等级：%d → %d (满级)",
            upgradeData.currentLevel, upgradeData.maxAchievableLevel))
    else
        table.insert(lines, string.format("等级：%d → %d (最高可达/满级%d)",
            upgradeData.currentLevel, upgradeData.maxAchievableLevel, upgradeData.maxLevel))
    end

    table.insert(lines, "")

    -- 检查是否可以升级
    if not upgradeData.canUpgrade then
        table.insert(lines, "❌ 无法升级任何等级，资源不足")
        if upgradeData.limitingResource then
            local available = upgradeData.availableResources[upgradeData.limitingResource] or 0
            table.insert(lines, string.format("💰 限制资源：%s (拥有%d)", upgradeData.limitingResource, available))
        end
        return table.concat(lines, "\n")
    end

    -- 消耗资源列表
    table.insert(lines, "消耗资源：")

    if next(upgradeData.cumulativeCost) then
        -- 按资源名称排序
        local sortedResources = {}
        for resourceName, amount in pairs(upgradeData.cumulativeCost) do
            table.insert(sortedResources, {name = resourceName, amount = amount})
        end
        table.sort(sortedResources, function(a, b)
            return a.name < b.name
        end)

        for _, resource in ipairs(sortedResources) do
            local available = upgradeData.availableResources[resource.name] or 0
            local remaining = math.max(0, available - resource.amount)
            local status = available >= resource.amount and "✅" or "❌"
            table.insert(lines, string.format("%s %s：%d (拥有%d，剩余%d)",
                status, resource.name, resource.amount, available, remaining))
        end
    else
        table.insert(lines, "无需消耗资源")
    end

    table.insert(lines, "")

    -- 升级结果提示
    if upgradeData.canFullUpgrade then
        table.insert(lines, "🎉 可以强化到满级！")
    elseif upgradeData.isResourceLimited then
        table.insert(lines, string.format("⚠️ 资源限制，只能强化到等级%d", upgradeData.maxAchievableLevel))
        if upgradeData.nextLevelMissing then
            table.insert(lines, string.format("再升一级还需：%s %d个",
                upgradeData.nextLevelMissing.resource, upgradeData.nextLevelMissing.missing))
        end
    end

    return table.concat(lines, "\n")
end

-- 确认升级
function CardsGui:OnConfirmUpgrade()
    if not self.currentUpgradeData then
        return
    end

    local skillName = self.currentUpgradeData.skillName
    local targetLevel = self.currentUpgradeData.maxAchievableLevel


    -- 发送升级请求到服务器，包含目标强化等级
    gg.network_channel:FireServer({
        cmd = SkillEventConfig.REQUEST.UPGRADE_ALL,
        skillName = skillName,
        targetLevel = targetLevel
    })

    -- 隐藏确认对话框
    self:HideUpgradeConfirmDialog()
end

-- 取消升级
function CardsGui:OnCancelUpgrade()

    -- 隐藏确认对话框
    self:HideUpgradeConfirmDialog()
end

-- 隐藏升级确认对话框
function CardsGui:HideUpgradeConfirmDialog()
    if self.ConfirmStrengthenUI then
        self.ConfirmStrengthenUI.node.Visible = false
    end

    -- 清除临时数据
    self.currentUpgradeData = nil
end

-- === 新增方法：更新副卡资源消耗显示 ===
function CardsGui:UpdateSubCardResourceCost(subNode, skill, currentLevel)
    if not subNode or not skill then
        return
    end

    -- 获取货币消耗显示节点（根据你的UI结构调整路径）
    local costContainer = subNode["货币消耗"]
    if costContainer then
        -- 取消副卡属性的货币消耗显示，设置为不可见
        costContainer.Visible = false
    end
end

-- === 新增方法：统一的副卡点击处理函数 ===
function CardsGui:OnSubCardButtonClick(ui, button)
    local skillId = button.extraParams.skillId
    local skill = SkillTypeConfig.Get(skillId)
    local serverData = self.ServerSkills[skillId]
    local skillLevel = serverData and serverData.level or 0
    local growth = serverData and serverData.growth or 0

    -- 更新副卡图标和星级显示
    local subNode = self.subCardComponent.node
    if subNode then
        -- 更新副卡图标
        local subCardIconNode = subNode["主背景"]["上层背景"]["卡牌图标"]
        if subCardIconNode then
            -- 确保图标可见（可能之前因为没有卡片而被隐藏了）
            subCardIconNode.Visible = true
            if skill.icon and skill.icon ~= "" then
                subCardIconNode.Icon = skill.icon
            end
        end

        -- 更新当前强化等级显示（只有已解锁的副卡才显示）
        local currentLevelNode = subNode["主背景"]["主背景强化显示"]["当前强化等级"]
        if currentLevelNode then
            if serverData then
                -- 已解锁：显示当前强化等级
                currentLevelNode.Title = "当前强化等级: LV" .. skillLevel
            else
                -- 未解锁：不显示等级信息
                currentLevelNode.Title = ""
            end
        else
        end

        -- === 新增：更新副卡组件中的强化进度显示 ===
        self:UpdateSubCardProgress( skill, growth, skillLevel)

        -- 更新星级显示
        local starContainer = subNode["星级"]
        if starContainer then
            -- 确保星级容器可见（可能之前因为没有卡片而被隐藏了）
            for i = 1, 7 do
                local starNode = starContainer["星_" .. i]
                if starNode then
                    starNode.Visible = true
                end
            end

            local star_level = 0  -- 默认0星级（不存在状态）
            -- 如果存在服务器数据，获取真实星级
            if serverData and serverData.star_level then
                star_level = serverData.star_level
            else
            end

            -- 调用星级显示更新函数
            self:UpdateStarLevelDisplay(starContainer, star_level)
        else
        end
    end

    -- 计算并显示下一级资源消耗
    local subCardAttributeButton = self.subCardAttributeButton.node
    self:UpdateSubCardResourceCost(subCardAttributeButton, skill, skillLevel)

    -- 更新副卡属性面板
    self:UpdateSubCardAttributePanel(skill, skillLevel, serverData)

    -- === 新增：确保功能按钮状态被刷新 ===
    self:_updateSubCardFunctionButtons(skill, skillLevel, serverData)

    -- 记录当前选中的副卡按钮
    self.currentSubCardButtonName = button

    -- === 显示对应技能的素材需求ViewList，隐藏其他ViewList ===
    gg.log("点击副卡:", skillId, "显示对应素材需求")
    self:UpdateSubCardMaterialRequirements(skillId, skillLevel)

end

-- === 新增方法：更新主卡资源消耗显示 ===
function CardsGui:UpdateMainCardResourceCost(attributeButton, skill, currentLevel)
    if not attributeButton or not skill then
        return true
    end

    local maxLevel = skill.maxLevel or 1
    local nextLevel = currentLevel + 1

    -- 获取货币消耗显示节点
    local costContainer = attributeButton["货币消耗"]
    if not costContainer then
        return true
    end

    -- 如果已经满级，隐藏消耗显示
    if currentLevel >= maxLevel then
        costContainer.Visible = false
        return false
    end

    -- 获取下一级升级成本
    local nextLevelCost = skill:GetCostAtLevel(nextLevel)
    if not nextLevelCost or not next(nextLevelCost) then
        -- 无升级成本，隐藏显示
        costContainer.Visible = false
        return true
    end

    -- 显示消耗容器
    costContainer.Visible = true

    -- 构建资源消耗文本
    local costTexts = {}
    local sortedResources = {}
    local allSufficient = true

    -- 整理并排序资源
    for resourceName, amount in pairs(nextLevelCost) do
        local needAmount = math.abs(amount)
        table.insert(sortedResources, {
            name = resourceName,
            need = needAmount,
            current = self:GetItemAmount(resourceName)
        })
    end

    -- 按资源名称排序
    table.sort(sortedResources, function(a, b)
        return a.name < b.name
    end)

    -- 生成消耗文本
    for _, resource in ipairs(sortedResources) do
        local sufficient = resource.current >= resource.need
        if not sufficient then
            allSufficient = false
        end
        local status = sufficient and "✅" or "❌"
        local costText = string.format("%s %s: %d/%d",
            status, resource.name, resource.current, resource.need)
        table.insert(costTexts, costText)

        gg.log("主卡资源消耗:", skill.name, "升级到", nextLevel,
            resource.name, "需要", resource.need, "拥有", resource.current, "足够", sufficient)
    end

    -- 更新UI显示
    local costText = table.concat(costTexts, "\n")
    costContainer.Title = string.format("升级到等级%d消耗：\n%s", nextLevel, costText)

    gg.log("主卡货币消耗显示已更新:", skill.name, "等级:", currentLevel, "->", nextLevel)
    return allSufficient
end

-- === 新增方法：更新副卡强化等级显示 ===
function CardsGui:UpdateSubCardLevelDisplay(skillName, skillLevel)
    if not skillName or not skillLevel then
        return
    end

    -- 更新副卡组件中的强化等级显示
    local subNode = self.subCardComponent.node
    if subNode then
        local currentLevelNode = subNode["主背景"]["主背景强化显示"]["当前强化等级"]
        if currentLevelNode then
            currentLevelNode.Title = "当前强化等级: LV" .. skillLevel
        end
    end

    -- 更新副卡属性面板中的强化等级显示
    if self.subCardAttributeButton then
        local attributeButton = self.subCardAttributeButton.node
        local descPreTitleNode = attributeButton["列表_强化前"]["强化标题"]
        if descPreTitleNode then
            local skillType = SkillTypeConfig.Get(skillName)
            if skillType then
                descPreTitleNode.Title = string.format("等级 %d/%d", skillLevel, skillType.maxLevel or 1)
            end
        end
    end

    gg.log("副卡强化等级显示已更新:", skillName, "等级:", skillLevel)
end

-- === 新增：检查技能升级资源的通用函数 ===
function CardsGui:CanAffordUpgrade(skill, level)
    if not skill or not level or level <= 0 then
        return false
    end

    local cost = skill:GetCostAtLevel(level)
    if not cost or not next(cost) then
        return true -- 没有消耗，视为资源足够
    end

    local requiredItems = {}
    for resourceName, requiredAmount in pairs(cost) do
        if requiredAmount < 0 then
            requiredItems[resourceName] = math.abs(requiredAmount)
        end
    end

    return self:HasItems(requiredItems)
end

-- === 新增方法：更新副卡装备状态 ===
function CardsGui:UpdateSubCardEquipStatus(skillName, serverData)
    local buttonState = self.subCardButtonStates[skillName]
    if buttonState and serverData then
        local equipSlot = serverData.slot or 0
        buttonState.isEquipped = equipSlot > 0
        buttonState.equipSlot = equipSlot
    elseif buttonState then
        buttonState.isEquipped = false
        buttonState.equipSlot = 0
    end
end

return CardsGui.New(script.Parent, uiConfig)

