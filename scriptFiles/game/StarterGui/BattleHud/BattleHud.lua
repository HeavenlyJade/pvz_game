local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
-- local ShakeBeh = require(MainStorage.code.client.camera.ShakeBeh) ---@type ShakeBeh
local tweenInfo = TweenInfo.New(0.2, Enum.EasingStyle.Linear)
local TweenService = game:GetService('TweenService')

---@class BattleHud:ViewBase
local BattleHud = ClassMgr.Class("BattleHud", ViewBase)
local localPlayer = nil ---@type Player
local uiConfig = {
    uiName = "BattleHud",
    layer = 0,
    hideOnInit = false, -- 初始隐藏，当玩家靠近NPC时显示
    initHudInteract = false
}

-- 缓存技能数据
---@type table<string, Skill>
local skills = {}
---@type table<number, string>
local equippedSkills = {}

-- 施法相关变量
local isCasting = false
local lastCastTime = 0
local updateTaskId = nil

local accumulatedVerticalRecoil = 0
local accumulatedHorizontalRecoil = 0
local lastShotTime = 0  -- 记录最后一次射击时间

---@class EquipSkillCooldownUpdate
---@field cmd string
---@field skillId string
---@field cooldown number

function BattleHud:Close()
    -- if localPlayer then
    --     localPlayer.CameraMode = Enum.CameraModel.Classic
    -- end
    CameraController.SetActive(false)
    if updateTaskId then
        ClientScheduler.cancel(updateTaskId)
        updateTaskId = nil
    end
    if self.recoilRecoveryConnection then
        self.recoilRecoveryConnection:Disconnect()
        self.recoilRecoveryConnection = nil
    end
end
local recoil = nil

function BattleHud:Open()
    -- localPlayer = game:GetService("Players").LocalPlayer
    -- localPlayer.CameraMode = Enum.CameraModel.LockFirstPerson
    if updateTaskId then
        ClientScheduler.cancel(updateTaskId)
    end
    CameraController.SetActive(true)
    -- 创建新的更新任务（每帧更新）`
    updateTaskId = ClientScheduler.add(function()
        self:UpdateCooldownAndCasting()
    end, 0, 0.034)
    
    self.recoilRecoveryFunc = function(deltaTime)
        if not recoil then return end
        if not isCasting then
            local currentTime = os.clock()
            -- 只有在超过冷却时间后才开始恢复后座力
            if currentTime - lastShotTime >= recoil.recoil_cooling_time then
                -- 恢复垂直后座力
                if math.abs(accumulatedVerticalRecoil) > 0.01 then
                    local recoveryAmount = recoil.vertical_recoil_correct * deltaTime
                    accumulatedVerticalRecoil =
                        math.max(0, math.abs(accumulatedVerticalRecoil) - recoveryAmount) *
                        (accumulatedVerticalRecoil > 0 and 1 or -1)
                end

                -- 恢复水平后座力
                if math.abs(accumulatedHorizontalRecoil) > 0.01 then
                    local recoveryAmount = recoil.horizontal_recoil_correct * deltaTime
                    accumulatedHorizontalRecoil =
                        math.max(0, math.abs(accumulatedHorizontalRecoil) - recoveryAmount) *
                        (accumulatedHorizontalRecoil > 0 and 1 or -1)
                end
            end
        end
    end

    -- 开始后座力恢复更新
    if not self.recoilRecoveryConnection then
        self.recoilRecoveryConnection = game.RunService.RenderStepped:Connect(self.recoilRecoveryFunc)
    end
end

function BattleHud:SetFov(fov)
    if self.cameraTween then
        self.cameraTween:Destroy()
    end
    self.cameraTween = TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {FieldOfView = fov})
    self.cameraTween:Play()
end

-- 更新冷却显示和持续施法
function BattleHud:UpdateCooldownAndCasting()
    if not equippedSkills[1] then
        self.fireIcon.node.FillAmount = 0
        return
    end
    
    local skillId = equippedSkills[1]
    local skill = skills[skillId]
    if not skill then
        self.fireIcon.node.FillAmount = 0
        return
    end
    
    local currentTime = os.clock()
    local elapsedTime = currentTime - lastCastTime
    local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
    local fillAmount = 1-remainingTime / skill.cooldownCache
    
    self.fireIcon.node.FillAmount = fillAmount
    
    -- 如果正在持续施法且冷却结束
    if isCasting and remainingTime <= 0 then
        self:SendCastSpellEvent(skillId)
        lastCastTime = currentTime
    end
end

-- 处理技能同步事件
---@param data {cmd: string, uin: number, skillData: {skills: table<string, {skill: string, level: number, slot: number}>}}
function BattleHud:OnSyncPlayerSkills(data)
    if not data or not data.skillData then return end
    
    -- 清空现有技能数据
    skills = {}
    equippedSkills = {}
    
    -- 反序列化技能数据
    for skillId, skillData in pairs(data.skillData.skills) do
        local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
        local skill = Skill.New(nil, skillData) ---@type Skill
        skills[skillId] = skill
        
        -- 记录已装备的技能
        if skill.skillType.activeSpell then
            equippedSkills[skill.equipSlot] = skillId
            if skill.equipSlot == 1 then
                recoil = skill.skillType.recoil
            end
        end
    end
    
    gg.log("已同步技能数据:", skills, equippedSkills)
end


function BattleHud:CalculateRecoil()
    -- 计算垂直后座力（主要是上抬）
    local verticalRecoil = recoil.vertical_recoil * (1 + math.random() * 0.5)
    -- 限制最大垂直后座力
    accumulatedVerticalRecoil =math.min(recoil.vertical_recoil_max,accumulatedVerticalRecoil + verticalRecoil)

    -- 计算水平后座力（随机左右）
    local horizontalRecoil = recoil.horizontal_recoil * (math.random() * 2 - 1)
    -- 限制最大水平后座力
    accumulatedHorizontalRecoil =
        math.clamp(
        accumulatedHorizontalRecoil + horizontalRecoil,
        -recoil.horizontal_recoil_max,
        recoil.horizontal_recoil_max
    )
    --改为在发射子弹时让子弹偏移，就不动镜头了
    -- CameraController.InputMove(
    --     accumulatedHorizontalRecoil * 100, -- 水平方向
    --     -accumulatedVerticalRecoil * 100 -- 垂直方向
    -- )
end

-- 处理技能冷却更新事件
---@param data EquipSkillCooldownUpdate
function BattleHud:OnEquipSkillCooldownUpdate(data)
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

-- 发送施法事件
---@param skillId string 技能ID
function BattleHud:SendCastSpellEvent(skillId)
    local camera = game.WorkSpace.CurrentCamera
    local direction = CameraController.GetRealForward(-accumulatedVerticalRecoil, accumulatedHorizontalRecoil)
    local targetPos = CameraController.RaytraceScene({1})
    gg.network_channel:FireServer({
        cmd = "CastSpell",
        skill = skillId,
        direction = direction,
        targetPos = targetPos
    })
    if recoil then
        self:CalculateRecoil()
    end
    lastShotTime = os.clock()  -- 更新最后射击时间
end

function BattleHud:OnInit(node, config)
    -- 注册技能同步事件监听
    ClientEventManager.Subscribe("SyncPlayerSkills", function(data)
        self:OnSyncPlayerSkills(data)
    end)
    
    -- 注册技能冷却更新事件监听
    ClientEventManager.Subscribe("EquipSkillCooldownUpdate", function(data)
        self:OnEquipSkillCooldownUpdate(data)
    end)
    
    self.fireIcon = self:Get("开火", ViewButton)
    self.fireIcon.node.TouchBegin:Connect(
        function(node, isTouchMove, vector2, int)
            local postProcessing = game.WorkSpace["Environment"].PostProcessing
            postProcessing.ChromaticAberrationIntensity = 0.5
            postProcessing.ChromaticAberrationStartOffset = 0.9
            postProcessing.ChromaticAberrationIterationStep = 5
            postProcessing.ChromaticAberrationIterationSamples = 4
        
            self:SetFov(30)
            isCasting = true
            self.fireInputBeginPos = vector2
        end
    )

    self.fireIcon.node.TouchEnd:Connect(
        function(node, isTouchMove, vector2, int)
            local postProcessing = game.WorkSpace["Environment"].PostProcessing
            postProcessing.ChromaticAberrationIntensity = 1
            postProcessing.ChromaticAberrationStartOffset = 0.4
            postProcessing.ChromaticAberrationIterationStep = 0.01
            postProcessing.ChromaticAberrationIterationSamples = 1
        
            self:SetFov(75)
            isCasting = false
        end
    )

    self.fireIcon.node.TouchMove:Connect(
        function(node, isTouchMove, vector2, int)
            -- 计算移动的距离
            local moveDistance = vector2 - self.fireInputBeginPos
            -- 更新按下的位置
            self.fireInputBeginPos = vector2
            CameraController.InputMove(
                moveDistance.x,
                moveDistance.y
            )
        end
    )
end

return BattleHud.New(script.Parent, uiConfig)