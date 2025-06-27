local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local SkillEventConfig = require(MainStorage.code.common.event_conf.event_skill) ---@type SkillEventConfig
local CardIcon = require(MainStorage.code.common.ui_icon.card_icon) ---@type CardIcon
local BagEventConfig = require(MainStorage.code.common.event_conf.event_bag) ---@type BagEventConfig
local MConfig = require(MainStorage.code.common.MConfig) ---@type common_config

local tweenInfo = TweenInfo.New(0.2, Enum.EasingStyle.Linear)
local TweenService = game:GetService('TweenService')



---@class HudCards:ViewBase
local HudCards = ClassMgr.Class("HudCards", ViewBase)

local uiConfig = {
    uiName = "HudCards",
    layer = 0,
    hideOnInit = false,
}

-- 缓存技能数据
---@type table<string, Skill>
local skills = {}
---@type table<number, string>
local equippedSkills = {}
-- 施法相关变量
local lastCastTimes = {}  -- 记录每个技能的释放时间
local updateTaskId = nil
local decal = nil
local refreshDecal = false
local localPlayer = game.Players.LocalPlayer.Character

function HudCards:SetFov(fov)
    if self.cameraTween then
        self.cameraTween:Destroy()
    end
    self.cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {FieldOfView = fov})
    self.cameraTween:Play()
end

-- 更新冷却显示
function HudCards:UpdateCooldownDisplay()
    if not self.cardsList then return end

    -- === 使用配置文件中的槽位映射 ===
    local SLOT_TO_CARD_MAPPING = MConfig.SlotToCardMapping

    -- === 遍历当前装备的副卡技能来更新冷却显示 ===
    for slotId, skill in pairs(self.subCardData) do
        if skill and skill.skillType then
            local cardName = SLOT_TO_CARD_MAPPING[slotId]
            if cardName then
                -- 根据卡片名称获取对应的UI卡片
                local card = self.cardsList:GetChildByName(cardName)
                if card then
                    local currentTime = gg.GetTimeStamp()
                    local lastCastTime = lastCastTimes[skill.skillName]
                    if lastCastTime and skill.cooldownCache > 0 then
                        local elapsedTime = currentTime - lastCastTime
                        local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
                        local fillAmount = remainingTime / skill.cooldownCache
                        
                        -- 更新冷却显示
                        if card.node["冷却条"] then
                            card.node["冷却条"].FillAmount = fillAmount
                        end

                        -- 检查是否在冷却中
                        local isOnCooldown = remainingTime > 0
                        card:SetTouchEnable(not isOnCooldown, false)
                        if isOnCooldown then
                            if card.node["卡片框"] then
                                card.node["卡片框"].FillColor = ColorQuad.New(150, 150, 150, 255)
                            end
                        else
                            if card.node["卡片框"] then
                                card.node["卡片框"].FillColor = ColorQuad.New(255, 255, 255, 255)
                            end
                        end
                    else
                        -- 如果没有冷却时间或冷却已结束，确保卡片显示正常颜色
                        if card.node["卡片框"] then
                            card.node["卡片框"].FillColor = ColorQuad.New(255, 255, 255, 255)
                        end
                        if card.node["冷却条"] then
                            card.node["冷却条"].FillAmount = 0
                        end
                        card:SetTouchEnable(true, false)
                    end
                end
            end
        end
    end
end

-- 处理技能同步事件

---@param data SyncPlayerSkillsData
function HudCards:OnSyncPlayerSkills(data)
    if not data or not data.skillData then return end
    -- 清空现有技能数据
    skills = {}
    equippedSkills = {}
    lastCastTimes = {}  -- 清空冷却时间记录

    -- 清空卡片数据
    self.mainCardData = {}
    self.subCardData = {}

    -- 反序列化技能数据
    for skillId, skillData in pairs(data.skillData.skills) do
        local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
        local skill = Skill.New(nil, skillData) ---@type Skill
        skills[skillId] = skill

        -- 获取技能类型配置
        local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
        local skillType = SkillTypeConfig.Get(skillId)
        self.selectedSkill[skillId] = skill
        if skillType then
            -- 根据技能分类和槽位分别存储
            if skillType.category == 0 then
                -- 主卡技能：slot不等于0且是主卡类型
                if skill.equipSlot and skill.equipSlot ~= 0 then
                    self.mainCardData[skill.equipSlot] = skill
                end
            elseif skillType.category == 1 then
                -- 副卡技能：slot不等于0且是副卡类型
                if skill.equipSlot and skill.equipSlot ~= 0 then
                    self.subCardData[skill.equipSlot] = skill
                end
            end
        end

        -- 记录已装备的技能（保持原有逻辑）
        if skill.skillType.activeSpell then
            equippedSkills[skill.equipSlot] = skillId
        end
    end
    -- 更新卡片列表显示
    self:UpdateCardsDisplay()
end

-- === 新增：副卡品质图标设置方法 ===
---@param cardNode UIImage 卡片节点
---@param skillType table 技能类型配置
function HudCards:SetSubCardQualityIcons(cardNode, skillType)
    if not cardNode or not skillType then return end

    local quality = skillType.quality or "N"  -- 默认为N品质

    -- === 通用的节点品质图标设置函数 ===
    ---@param node UIImage 要设置的节点
    ---@param quality string 品质等级（如 "N", "R", "SR", "SSR", "UR"）
    ---@param defIconTable table 默认图标资源表
    ---@param clickIconTable table 点击图标资源表
    local function setNodeQualityIcon(node, quality, defIconTable, clickIconTable)
        if not node or not quality then return end

        local defIcon = defIconTable[quality]
        local clickIcon = clickIconTable[quality]
        gg.log("设置品质图标",node,quality,defIcon,clickIcon)
        -- 设置默认图标和"图片-默认"属性
        if defIcon and defIcon ~= "" and node.Icon ~= defIcon then
            node.Icon = defIcon
            node:SetAttribute("图片-默认", defIcon)
        end

        -- 设置"图片-点击"属性
        if clickIcon and clickIcon ~= "" then
            local currentClickIcon = node:GetAttribute("图片-点击")
            if currentClickIcon ~= clickIcon then
                node:SetAttribute("图片-点击", clickIcon)
            end
        end
    end
    -- 设置主节点的品质图标
    setNodeQualityIcon(cardNode, quality, CardIcon.qualityBaseMapDefIcon, CardIcon.qualityBaseMapClickIcon)

    -- 设置"卡片框"子节点的品质图标
    if cardNode["卡片框"] then
        setNodeQualityIcon(cardNode["卡片框"], quality, CardIcon.qualityBaseMapboxIcon, CardIcon.qualityBaseMapboxClickIcon)
    end

end

-- 处理技能冷却更新事件
---@param data {cmd: string, skillId: string, cooldown: number}
function HudCards:OnEquipSkillCooldownUpdate(data)
    if not data or not data.skillId or not data.cooldown then
        return
    end

    local skill = skills[data.skillId]
    if not skill then
        return
    end

    skill.cooldownCache = data.cooldown
end

-- 处理技能可释放状态更新事件
---@param data {cmd: string, castabilityData: table<string, boolean>}
function HudCards:OnUpdateSkillCastability(data)
    if not data or not data.castabilityData then return end

    -- === 使用配置文件中的槽位映射 ===
    local SLOT_TO_CARD_MAPPING = MConfig.SlotToCardMapping

    -- === 遍历当前装备的副卡技能来更新可释放状态 ===
    for slotId, skill in pairs(self.subCardData) do
        if skill and skill.skillType then
            local cardName = SLOT_TO_CARD_MAPPING[slotId]
            if cardName then
                -- 根据卡片名称获取对应的UI卡片
                local card = self.cardsList:GetChildByName(cardName)
                if card then
                    local canCast = data.castabilityData[skill.skillName]
                    if canCast ~= nil then
                        card:SetTouchEnable(canCast)
                    end
                end
            end
        end
    end
end

function HudCards:UpdateCardsDisplay()
    -- 更新主卡显示
    self:UpdateMainCardDisplay()

    -- 更新副卡显示
    self:UpdateSubCardDisplay()
end

-- 更新主卡显示
function HudCards:UpdateMainCardDisplay()
    if not self.mainCardButton then return end

    -- 查找主卡数据（主卡槽位为1）
    ---@type Skill
    local mainCardSkill = nil
    local mainCardSlot = nil
    for slotId, skill in pairs(self.mainCardData) do
        mainCardSkill = skill
        mainCardSlot = slotId
        break -- 取第一个主卡（目前只有一个主卡槽位）
    end

    if mainCardSkill and mainCardSkill.skillType then
        -- 更新主卡按钮显示
        local cardName = mainCardSkill.skillType.displayName
        self.mainCardButton.node["框体"]["Text"].Title = cardName
        local icon = mainCardSkill.skillType.icon
        if icon  and icon ~= "" then
            self.mainCardButton.node["框体"]["主卡图标"].Icon =icon

        end

        if self.mainCardButton.node["Title"] then
            self.mainCardButton.node["Title"].Title = "未装备"
        end
        if self.mainCardButton.node["Text"] then
            self.mainCardButton.node["Text"].Title = ""
        end
    else
        self.mainCardButton.node["框体"]["Text"].Title = "未装备"
        -- 清除事件绑定
        self.mainCardButton.clickCb = nil

        if self.mainCardButton.node["Title"] then
            self.mainCardButton.node["Title"].Title = "未装备"
        end
        if self.mainCardButton.node["Text"] then
            self.mainCardButton.node["Text"].Title = ""
        end
    end
end

-- 更新副卡显示
function HudCards:UpdateSubCardDisplay()
    if not self.cardsList then return end

    -- === 使用配置文件中的槽位映射 ===
    local SLOT_TO_CARD_MAPPING = MConfig.SlotToCardMapping

    -- === 确保4个固定卡片位置存在 ===
    local cardNames = MConfig.FixedCardNames
    
    -- 获取模板节点
    if not self.cardTemplate then
        self.cardTemplate = self:Get("副卡列表_模版/卡片_1", ViewButton)
        if not self.cardTemplate then
            gg.log("错误：无法找到卡片模板")
            return
        end
    end

    -- 确保所有4个卡片位置都存在
    for i, cardName in ipairs(cardNames) do
        local existingCard = self.cardsList:GetChildByName(cardName)
        if not existingCard then
            gg.log("创建固定卡片位置:", cardName)
            local newCardNode = self.cardTemplate.node:Clone()
            newCardNode.Name = cardName
            newCardNode.Visible = false  -- 默认隐藏
            self.cardsList:AppendChild(newCardNode)
        end
    end

    -- === 第一步：隐藏所有卡片 ===
    for _, cardName in ipairs(cardNames) do
        local card = self.cardsList:GetChildByName(cardName)
        if card and card.node then
            card.node.Visible = false
        end
    end

    -- === 第二步：显示并更新有技能的卡片 ===
    for slotId, skill in pairs(self.subCardData) do
        if skill and skill.skillType then
            local cardName = SLOT_TO_CARD_MAPPING[slotId]
            if cardName then
                local card = self.cardsList:GetChildByName(cardName)
                if card and card.node then
                    gg.log("显示并更新卡片:", cardName, "技能:", skill.skillType.displayName, "槽位:", slotId)
                    
                    -- 显示卡片
                    card.node.Visible = true
                    
                    -- 更新卡片内容
                    if card.node["名字"] then
                        card.node["名字"].Title = skill.skillType.displayName or skill.skillName
                    end
                    
                    if card.node["等级"] then
                        card.node["等级"].Title = tostring(skill.level)
                    end
                    
                    local icon = skill.skillType.icon
                    if icon and icon ~= "" and card.node["图标"] then
                        card.node["图标"].Icon = icon
                    end
                    
                    -- 设置副卡品质图标
                    self:SetSubCardQualityIcons(card.node, skill.skillType)
                else
                    gg.log("错误：无法找到卡片:", cardName)
                end
            else
                gg.log("警告：槽位", slotId, "没有对应的卡片映射")
            end
        end
    end

    -- 重新绑定副卡事件
    self:RebindSubCardEvents()
end

-- 重新绑定副卡事件（基于新的subCardData）
function HudCards:RebindSubCardEvents()
    if not self.cardsList then return end

    -- === 使用配置文件中的槽位映射 ===
    local SLOT_TO_CARD_MAPPING = MConfig.SlotToCardWithKeyMapping

    -- === 第一步：清除所有卡片的事件绑定 ===
    local cardNames = MConfig.FixedCardNames
    for _, cardName in ipairs(cardNames) do
        local card = self.cardsList:GetChildByName(cardName)
        if card then
            card.touchBeginCb = nil
            card.touchEndCb = nil
            card.touchMoveCb = nil
            -- 清除按键提示
            if card.node["pc_hint"] then
                card.node["pc_hint"].Title = ""
            end
        end
    end

    -- === 第二步：为有技能的卡片绑定事件 ===
    for slotId, skill in pairs(self.subCardData) do
        if skill and skill.skillType then
            local mapping = SLOT_TO_CARD_MAPPING[slotId]
            if mapping then
                local card = self.cardsList:GetChildByName(mapping.cardName)
                if card then
                    gg.log("为卡片绑定事件:", mapping.cardName, "技能:", skill.skillType.displayName, "数字键:", mapping.keyIndex)
                    
                    -- 设置键盘提示
                    if card.node["pc_hint"] then
                        card.node["pc_hint"].Title = string.format("[ %d ]", mapping.keyIndex)
                    end

                    -- 绑定触摸开始事件
                    card.touchBeginCb = function(ui, btn, vector2)
                        self:StartSkillTracking(skill, vector2)
                    end

                    -- 绑定触摸结束事件
                    card.touchEndCb = function(ui, btn)
                        if self.selectSkillCb then
                            self.selectSkillCb(btn.index, skill)
                            self.selectSkillCb = nil
                            self.pressedSkillId = nil
                            return
                        end
                        if self.pressedSkillId == skill.skillName then
                            self:CastSkill(skill)
                        end
                        self.pressedSkillId = nil -- 抬起后清空
                    end

                    -- 绑定触摸移动事件
                    card.touchMoveCb = function(ui, btn, vector2)
                        -- 检查技能是否在冷却中
                        local currentTime = gg.GetTimeStamp()
                        local lastCastTime = lastCastTimes[skill.skillName]
                        if lastCastTime and skill.cooldownCache > 0 then
                            local elapsedTime = currentTime - lastCastTime
                            local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
                            if remainingTime > 0 then
                                return -- 在冷却中，不处理触摸事件
                            end
                        end

                        if not self.touchBeginPos then return end

                        -- 计算移动的距离
                        local moveDistance = vector2 - self.touchBeginPos
                        -- 更新按下的位置
                        self.touchBeginPos = vector2

                        -- 移动相机
                        CameraController.InputMove(
                            moveDistance.x,
                            moveDistance.y
                        )
                    end
                else
                    gg.log("警告：无法找到对应的UI卡片:", mapping.cardName, "槽位:", slotId)
                end
            else
                gg.log("警告：槽位", slotId, "没有对应的卡片映射")
            end
        end
    end
end

function HudCards:OnDestroy()
    if updateTaskId then
        ClientScheduler.cancel(updateTaskId)
        updateTaskId = nil
    end
    -- 确保追踪任务被取消
    if self.trackingTaskId then
        ClientScheduler.cancel(self.trackingTaskId)
        self.trackingTaskId = nil
    end
end

function HudCards:RegisterEventFunction()
    if self.CardpackButton then
        self.CardpackButton.clickCb = function (ui, button)
            gg.log("HudCards:RegisterEventFunction,打开卡包")
            -- 同时请求同步背包数据和技能数据
            gg.network_channel:FireServer({ cmd = SkillEventConfig.REQUEST.SYNC_SKILLS})
            ViewBase["CardsGui"]:Open()
        end
    end
end

function HudCards:OnInit(node, config)
    self.mainCardButton =  self:Get("主卡按钮", ViewButton) ---@type ViewButton
    self.CardpackButton = self:Get("卡包", ViewButton) ---@type ViewButton

    self.mainCardData = {} ---@type table<string, Skill>
    self.subCardData = {} ---@type table<number, Skill>
    self.selectedSkill ={} ---@type table<string, Skill>
    self.selectSkillCb = nil
    self.pressedSkillId = nil
    self.pressedKey = nil -- 记录当前按下的数字键

    -- 注册技能同步事件监听
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.SYNC_SKILLS, function(data)
        self:OnSyncPlayerSkills(data)
    end)

    -- 监听按键事件
    ClientEventManager.Subscribe("PressKey", function(data)
        if ViewBase.topGui then
            return
        end
        if not data.isDown then
            -- 按键抬起时，检查是否是之前按下的数字键
            if self.pressedKey and data.key == self.pressedKey then
                -- === 修复：数字键1-4直接对应卡片_1到卡片_4 ===
                local keyIndex = self.pressedKey - Enum.KeyCode.One.Value + 1  -- 1,2,3,4
                local cardName = "卡片_" .. keyIndex
                
                -- 根据卡片名称查找对应的技能
                local targetSkill = nil
                for slotId, skill in pairs(self.subCardData) do
                    if MConfig.SlotToCardMapping[slotId] == cardName then
                        targetSkill = skill
                        break
                    end
                end
                
                if targetSkill then
                    gg.log("键盘释放技能:", targetSkill.skillType.displayName, "卡片:", cardName)
                    self:CastSkill(targetSkill)
                end
                self.pressedKey = nil
            end
        else
            -- 按键按下时，记录数字键并执行触摸开始逻辑
            if data.key >= Enum.KeyCode.One.Value and data.key <= Enum.KeyCode.Four.Value then
                self.pressedKey = data.key
                -- === 修复：数字键1-4直接对应卡片_1到卡片_4 ===
                local keyIndex = data.key - Enum.KeyCode.One.Value + 1  -- 1,2,3,4
                local cardName = "卡片_" .. keyIndex
                
                -- 根据卡片名称查找对应的技能
                local targetSkill = nil
                for slotId, skill in pairs(self.subCardData) do
                    if MConfig.SlotToCardMapping[slotId] == cardName then
                        targetSkill = skill
                        break
                    end
                end
                
                if targetSkill then
                    gg.log("键盘开始追踪技能:", targetSkill.skillType.displayName, "卡片:", cardName)
                    self:StartSkillTracking(targetSkill)
                end
            end
        end
    end)

    ClientEventManager.Subscribe("AfkSpotSelectCard", function(data)
        local ui = ViewBase.GetUI("ForceClickHud") ---@cast ui ForceClickHud
        ui.focusingChain = nil
        ui:FocusOnNode(self.cardsList.node, "选择一枚要成长的副卡")
        self.selectSkillCb = function (index, skill) ---@cast skill Skill
            gg.network_channel:FireServer({
                cmd = "AfkSelectSkill",
                npcId = data.npcId,
                skillName = skill.skillType.name
            })
        end
    end)

    -- 注册技能冷却更新事件监听
    ClientEventManager.Subscribe("EquipSkillCooldownUpdate", function(data)
        self:OnEquipSkillCooldownUpdate(data)
    end)

    -- 注册技能可释放状态更新事件监听
    ClientEventManager.Subscribe("UpdateSkillCastability", function(data)
        self:OnUpdateSkillCastability(data)
    end)

    -- 注册卸下装备响应事件监听
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.UNEQUIP, function(data)
        self:OnUnequipSkillResponse(data)
    end)

    -- 注册装备技能响应事件监听
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.EQUIP, function(data)
        self:OnEquipSkillResponse(data)
    end)

    -- 创建冷却更新任务
    updateTaskId = ClientScheduler.add(function()
        self:UpdateCooldownDisplay()
    end, 0, 0.2)

    self.cardsList = self:Get("副卡列表", ViewList, function(n)
        local button = ViewButton.New(n, self)
        -- 注意：具体的事件绑定由 RebindSubCardEvents 方法在数据同步后动态绑定
        return button
    end) ---@type ViewList<ViewButton>
    self:RegisterEventFunction()
end

-- === 新增：发送卸下装备请求 ===`
---@param skillName string 要卸下的技`能名称
function HudCards:SendUnequipRequest(skillName)
    gg.network_channel:FireServer({
        cmd = SkillEventConfig.REQUEST.UNEQUIP,
        skillName = skillName
    })
end

-- === 新增：处理装备技能响应 ===
---@param data table 装备技能响应数据 {skillName: string, slot: number}
function HudCards:OnEquipSkillResponse(data)
    if not data or not data.data then
        return
    end

    local responseData = data.data
    local skillName = responseData.skillName
    local slot = responseData.slot

    -- 获取技能对象
    local skill = skills[skillName]
    if not skill then
        return
    end

    -- 更新技能装备槽位
    skill.equipSlot = slot

    -- 获取技能类型配置
    local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
    local skillType = SkillTypeConfig.Get(skillName)

    if skillType then
        -- 根据技能类型更新对应的数据结构
        if skillType.category == 0 then
            -- 主卡技能
            self.mainCardData[slot] = skill
        elseif skillType.category == 1 then
            -- 副卡技能
            self.subCardData[slot] = skill
        end

        -- 更新装备技能列表
        equippedSkills[slot] = skillName
    end

    -- 重新更新卡片显示
    self:UpdateCardsDisplay()
end

-- === 新增：处理卸下装备响应 ===
---@param data table 卸下装备响应数据 {skillName: string, slot: number, level: number, cardName: string}
function HudCards:OnUnequipSkillResponse(data)
    if not data or not data.data then
        return
    end

    local responseData = data.data
    local skillName = responseData.skillName
    local cardName = responseData.cardName  -- 获取对应的UI卡片名称
    local unslot = responseData.unslot  -- 卸下的槽位
    local oldSlot = nil

    -- 从主卡数据中移除
    for slotId, skill in pairs(self.mainCardData) do
        if skill.skillName == skillName then
            oldSlot = slotId
            self.mainCardData[slotId] = nil
            break
        end
    end

    -- 从副卡数据中移除
    if not oldSlot then
        for slotId, skill in pairs(self.subCardData) do
            if skill.skillName == skillName then
                oldSlot = slotId
                self.subCardData[slotId] = nil
                break
            end
        end
    end

    -- 更新本地技能数据
    if skills[skillName] then
        skills[skillName].equipSlot = 0  -- 卸下后槽位为0
    end

    -- 从装备技能列表中移除
    if oldSlot and equippedSkills[oldSlot] == skillName then
        equippedSkills[oldSlot] = nil
    end

    -- === 新增：根据服务器发送的卡片名称直接隐藏对应的UI节点 ===
    if cardName then
        gg.log("收到卸下装备响应:", cardName, "技能:", skillName, "槽位:", unslot)
        self:HideCardByName(cardName)
    end

    -- 重新更新卡片显示（让UpdateCardsDisplay统一处理界面更新）
    self:UpdateCardsDisplay()
end

---检查技能是否在冷却中
---@param skill Skill 要检查的技能
---@return boolean 是否在冷却中
---@return number 剩余冷却时间
function HudCards:CheckSkillCooldown(skill)
    local currentTime = gg.GetTimeStamp()
    local lastCastTime = lastCastTimes[skill.skillName]
    if lastCastTime and skill.cooldownCache > 0 then
        local elapsedTime = currentTime - lastCastTime
        local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
        return remainingTime > 0, remainingTime
    end
    return false, 0
end

---释放技能
---@param skill Skill 要释放的技能
function HudCards:CastSkill(skill)
    if decal then
        decal.Visible = false
    end
    self:SetFov(75)
    if self.trackingTaskId then
        ClientScheduler.cancel(self.trackingTaskId)
        self.trackingTaskId = nil
    end
    -- 检查冷却
    local isOnCooldown, remainingTime = self:CheckSkillCooldown(skill)
    if isOnCooldown then
        return false
    end

    -- 获取目标位置和方向
    local direction = CameraController.GetForward()
    local targetPos, targetObj = CameraController.RaytraceScene({1, 2, 3})

    -- 检查技能范围
    local indicatorRange = skill.skillType.indicatorRange
    if indicatorRange and indicatorRange > 0 then
        local distance = gg.vec.Distance3(targetPos, localPlayer.Position)
        if distance > indicatorRange then
            local direction = (targetPos - localPlayer.Position) / distance
            targetPos = localPlayer.Position + direction * indicatorRange
        end
    end

    -- 更新冷却时间
    lastCastTimes[skill.skillName] = gg.GetTimeStamp()

    -- 发送释放技能请求
    gg.network_channel:FireServer({
        cmd = "CastSpell",
        skill = skill.skillType.name,
        targetPos = targetPos,
        direction = direction
    })

    return true
end

---开始技能追踪
---@param skill Skill 要追踪的技能
---@param vector2? Vector2 触摸位置（可选）
function HudCards:StartSkillTracking(skill, vector2)
    if self.selectSkillCb then
        return
    end
    -- 检查技能是否在冷却中
    local currentTime = gg.GetTimeStamp()
    local lastCastTime = lastCastTimes[skill.skillName]
    if lastCastTime and skill.cooldownCache > 0 then
        local elapsedTime = currentTime - lastCastTime
        local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
        if remainingTime > 0 then
            return -- 在冷却中，不处理触摸事件
        end
    end
    local postProcessing = game.WorkSpace["Environment"].PostProcessing
    postProcessing.ChromaticAberrationIntensity = 0.5
    postProcessing.ChromaticAberrationStartOffset = 0.9
    postProcessing.ChromaticAberrationIterationStep = 5
    postProcessing.ChromaticAberrationIterationSamples = 4

    self:SetFov(58)
    if vector2 then
        self.touchBeginPos = vector2
    end
    self.pressedSkillId = skill.skillName -- 记录按下时的技能ID

    -- 创建追踪任务
    if self.trackingTaskId then
        ClientScheduler.cancel(self.trackingTaskId)
    end
    refreshDecal = true
    self.trackingTaskId = ClientScheduler.add(function()
        local targetPos, targetObj = CameraController.RaytraceScene({1, 2, 3})
        if not targetObj then
            return
        end
        if refreshDecal then
            refreshDecal = false
            if not decal then
                decal = SandboxNode.New("Decal", targetObj)
                decal.TextureId = "AssetId://394777658842574854"
                decal.LocalEuler = Vector3.New(-90, 0, 0)
                decal.Width = 100
                decal.Height = 400
                decal.Length = 100
                decal.Cullback = false
            else
                decal.Visible = true
                decal.Parent = targetObj
            end
            decal.LocalScale = skill.skillType.indicatorScale
        end
        local indicatorRange = skill.skillType.indicatorRange
        if indicatorRange and indicatorRange > 0 then
            local distance = gg.vec.Distance3(targetPos, localPlayer.Position)
            if distance > indicatorRange then
                local direction = (targetPos - localPlayer.Position) / distance
                targetPos = localPlayer.Position + direction * indicatorRange
            end
        end
        decal.Position = targetPos
    end, 0, 0.067)
end

-- === 修改：根据卡片名称隐藏对应的UI节点（不销毁） ===
---@param cardName string UI卡片节点名称（如"卡片_1"、"卡片_2"等）
function HudCards:HideCardByName(cardName)
    if not cardName or not self.cardsList then
        gg.log("HideCardByName: 参数无效", cardName, self.cardsList)
        return
    end

    gg.log("隐藏UI卡片:", cardName)
    
    -- 根据卡片名称获取对应的UI卡片
    local card = self.cardsList:GetChildByName(cardName)
    if card and card.node then
        -- 隐藏卡片而不是销毁
        card.node.Visible = false
        
        -- 清除事件绑定
        card.touchBeginCb = nil
        card.touchEndCb = nil
        card.touchMoveCb = nil
        
        -- 清除按键提示
        if card.node["pc_hint"] then
            card.node["pc_hint"].Title = ""
        end
        
        gg.log("成功隐藏UI卡片:", cardName)
    else
        gg.log("HideCardByName: 未找到对应的UI卡片", cardName)
    end
end

return HudCards.New(script.Parent, uiConfig)

