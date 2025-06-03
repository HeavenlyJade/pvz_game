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
    
    -- 遍历所有卡片
    for i = 1, self.cardsList:GetChildCount() do
        local card = self.cardsList:GetChild(i) ---@type ViewButton
        local skillId = equippedSkills[i + 1]
        local skill = skills[skillId]
        
        if skill then
            local currentTime = os.clock()
            local lastCastTime = lastCastTimes[skillId]
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
                    card.node["卡片框"].FillColor = ColorQuad.New(150, 150, 150, 255)
                else
                    card.node["卡片框"].FillColor = ColorQuad.New(255, 255, 255, 255)
                end
            end
        end
    end
end

-- 处理技能同步事件

---@param data SyncPlayerSkillsData
function HudCards:OnSyncPlayerSkills(data)
    if not data or not data.skillData then return end
    gg.log("获取来自服务端的技能数据111", data)
    if not data or not data.skillData then return end
    local skillDataDic = data.skillData.skills
    -- 清空现有技能数据
    skills = {}
    equippedSkills = {}
    lastCastTimes = {}  -- 清空冷却时间记录
    
    -- 反序列化技能数据
    for skillId, skillData in pairs(data.skillData.skills) do
        local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
        local skill = Skill.New(nil, skillData) ---@type Skill
        skills[skillId] = skill
        -- 记录已装备的技能
        if skill.skillType.activeSpell then
            equippedSkills[skill.equipSlot] = skillId
        end
    end
    
    -- 更新卡片列表显示
    self:UpdateCardsDisplay()
    
    gg.log("已同步技能数据:", skills, equippedSkills)
end

-- 处理技能冷却更新事件
---@param data {cmd: string, skillId: string, cooldown: number}
function HudCards:OnEquipSkillCooldownUpdate(data)
    if not data or not data.skillId or not data.cooldown then
        gg.log("Invalid cooldown update data:", data)
        return
    end

    local skill = skills[data.skillId]
    if not skill then 
        gg.log("Skill not found for cooldown update:", data.skillId)
        return 
    end
    
    skill.cooldownCache = data.cooldown
end

-- 处理技能可释放状态更新事件
---@param data {cmd: string, castabilityData: table<string, boolean>}
function HudCards:OnUpdateSkillCastability(data)
    if not data or not data.castabilityData then return end
    
    -- 遍历所有卡片
    for i = 1, self.cardsList:GetChildCount() do
        local card = self.cardsList:GetChild(i) ---@type ViewButton
        local skillId = equippedSkills[i + 1]
        
        if skillId then
            local canCast = data.castabilityData[skillId]
            if canCast ~= nil then
                card:SetTouchEnable(canCast)
            end
        end
    end
end

function HudCards:UpdateCardsDisplay()
    if not self.cardsList then return end
    self.cardsList:SetElementSize(#equippedSkills - 1)
    -- 遍历所有卡片
    if #equippedSkills > 1 then
        for i = 1, self.cardsList:GetChildCount() do
            local card = self.cardsList:GetChild(i) ---@type ViewButton
            local skillId = equippedSkills[i + 1]
            local skill = skills[skillId]
            card.node["Title"].Title = skill.skillType.displayName
            card.node["Text"].Title = tostring(skill.level)
        end
    end
end





function HudCards:OnDestroy()
    if updateTaskId then
        ClientScheduler.cancel(updateTaskId)
        updateTaskId = nil
    end
end
function HudCards:OnInit(node, config)
    ViewBase.OnInit(self, node, config)
    gg.log("HudCards:OnInit", node, config)
    self.mainCardButton =  self:Get("主卡按钮", ViewButton) ---@type ViewButton
    self.subCardList =  self:Get("副卡列表", ViewList) ---@type ViewList

    -- 注册技能同步事件监听
    ClientEventManager.Subscribe(SkillEventConfig.RESPONSE.SYNC_SKILLS, function(data)
        self:OnSyncPlayerSkills(data)
    end)
    
    -- 注册技能冷却更新事件监听
    ClientEventManager.Subscribe("EquipSkillCooldownUpdate", function(data)
        self:OnEquipSkillCooldownUpdate(data)
    end)
    
    -- 注册技能可释放状态更新事件监听
    ClientEventManager.Subscribe("UpdateSkillCastability", function(data)
        self:OnUpdateSkillCastability(data)
    end)
    
    -- 创建冷却更新任务
    updateTaskId = ClientScheduler.add(function()
        self:UpdateCooldownDisplay()
    end, 0, 0.2)
    
    self.cardsList = self:Get("副卡列表", ViewList, function(n)
        local button = ViewButton.New(n, self)
        gg.log("副卡列表", button, button.node.Name)
        
        -- 设置触摸回调
        button.touchBeginCb = function(ui, btn, vector2) 
            -- 检查技能是否在冷却中
            local skillId = equippedSkills[btn.index + 1]
            local skill = skills[skillId]
            if skill then
                local currentTime = os.clock()
                local lastCastTime = lastCastTimes[skillId]
                if lastCastTime and skill.cooldownCache > 0 then
                    local elapsedTime = currentTime - lastCastTime
                    local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
                    if remainingTime > 0 then
                        return -- 在冷却中，不处理触摸事件
                    end
                end
            end

            local postProcessing = game.WorkSpace["Environment"].PostProcessing
            postProcessing.ChromaticAberrationIntensity = 0.5
            postProcessing.ChromaticAberrationStartOffset = 0.9
            postProcessing.ChromaticAberrationIterationStep = 5
            postProcessing.ChromaticAberrationIterationSamples = 4
            
            self:SetFov(30)
            self.touchBeginPos = vector2
            self.selectedCardIndex = btn.index
        end
        
        button.touchEndCb = function(ui, btn)
            -- 检查技能是否在冷却中
            local skillId = equippedSkills[btn.index + 1]
            local skill = skills[skillId]
            if skill then
                local currentTime = os.clock()
                local lastCastTime = lastCastTimes[skillId]
                if lastCastTime and skill.cooldownCache > 0 then
                    local elapsedTime = currentTime - lastCastTime
                    local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
                    if remainingTime > 0 then
                        return -- 在冷却中，不处理触摸事件
                    end
                end
            end

            local postProcessing = game.WorkSpace["Environment"].PostProcessing
            postProcessing.ChromaticAberrationIntensity = 1
            postProcessing.ChromaticAberrationStartOffset = 0.4
            postProcessing.ChromaticAberrationIterationStep = 0.0
            postProcessing.ChromaticAberrationIterationSamples = 1
            
            self:SetFov(75)
            
            -- 发送技能释放事件
            if self.selectedCardIndex then
                local skillId = equippedSkills[self.selectedCardIndex + 1]
                if skillId then
                    local direction = CameraController.GetForward()
                    local targetPos = CameraController.RaytraceScene({1})
                    lastCastTimes[skillId] = os.clock()
                    gg.network_channel:FireServer({
                        cmd = "CastSpell",
                        skill = skillId,
                        targetPos = targetPos,
                        direction = direction
                    })
                end
            end
        end
        
        button.touchMoveCb = function(ui, btn, vector2)
            -- 检查技能是否在冷却中
            local skillId = equippedSkills[btn.index + 1]
            local skill = skills[skillId]
            if skill then
                local currentTime = os.clock()
                local lastCastTime = lastCastTimes[skillId]
                if lastCastTime and skill.cooldownCache > 0 then
                    local elapsedTime = currentTime - lastCastTime
                    local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
                    if remainingTime > 0 then
                        return -- 在冷却中，不处理触摸事件
                    end
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
        
        return button
    end) ---@type ViewList<ViewButton>
end



return HudCards.New(script.Parent, uiConfig)
