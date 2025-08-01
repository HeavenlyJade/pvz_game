local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local UserInputService = game:GetService("UserInputService") ---@type UserInputService
-- local ShakeBeh = require(MainStorage.code.client.camera.ShakeBeh) ---@type ShakeBeh
local tweenInfo = TweenInfo.New(0.2, Enum.EasingStyle.Linear)
local TweenService = game:GetService('TweenService') ---@type TweenService

---@class BattleHud:ViewBase
local BattleHud = ClassMgr.Class("BattleHud", ViewBase)
local localPlayer = nil ---@type MiniPlayer
local uiConfig = {
    uiName = "BattleHud",
    layer = -1,
    hideOnInit = true,
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
    ViewBase.Close(self)
    ViewBase.GetUI("HudAvatar"):Open()
    ViewBase.GetUI("HudMenu"):Open()
    if updateTaskId then
        ClientScheduler.cancel(updateTaskId)
        updateTaskId = nil
    end
    if self.recoilRecoveryConnection then
        self.recoilRecoveryConnection:Disconnect()
        self.recoilRecoveryConnection = nil
    end
    -- 断开鼠标事件监听
    if self.mouseInputConnection then
        self.mouseInputConnection:Disconnect()
        self.mouseInputConnection = nil
    end
    if self.mouseInputEndConnection then
        self.mouseInputEndConnection:Disconnect()
        self.mouseInputEndConnection = nil
    end
    if self.mouseInputChangedConnection then
        self.mouseInputChangedConnection:Disconnect()
        self.mouseInputChangedConnection = nil
    end
end
local recoil = nil

function BattleHud:Open()
    ViewBase.Open(self)
    localPlayer = game:GetService("Players").LocalPlayer.Character
    -- localPlayer.CameraMode = Enum.CameraModel.LockFirstPerson
    if self._isInit or not MainStorage:GetAttribute("初始是战斗状态")  then
        ViewBase.Open(self)
        ViewBase.GetUI("HudAvatar"):Close()
        ViewBase.GetUI("HudMenu"):Close()
    end
    self._isInit = true
    if updateTaskId then
        ClientScheduler.cancel(updateTaskId)
    end
    -- 创建新的更新任务（每帧更新）`
    updateTaskId = ClientScheduler.add(function()
        self:UpdateCooldownAndCasting()
    end, 0, 0.034)
    
    self.recoilRecoveryFunc = function(deltaTime)
        if not recoil then return end
        if not isCasting then
            local currentTime = gg.GetTimeStamp()
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

    -- 订阅鼠标事件
    ClientEventManager.Subscribe("MouseButton", function(data)
        if not data.right and self.displaying then -- 左键
            if data.isDown then
                self:onFireBegin(Vector2.new(0, 0))
            else
                self:onFireEnd(Vector2.new(0, 0))
            end
        end
    end)
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
    
    local currentTime = gg.GetTimeStamp()
    local elapsedTime = currentTime - lastCastTime
    local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
    local fillAmount = 1-remainingTime / skill.cooldownCache
    
    self.fireIcon.node.FillAmount = math.clamp(fillAmount, 0, 1)
    
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
    
    for skillId, skillData in pairs(data.skillData.equipped_skills) do
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

-- 抽离开火相关逻辑为函数
function BattleHud:onFireBegin(vector2)
    local postProcessing = game.WorkSpace["Environment"].PostProcessing
    postProcessing.ChromaticAberrationIntensity = 0.5
    postProcessing.ChromaticAberrationStartOffset = 0.9
    postProcessing.ChromaticAberrationIterationStep = 5
    postProcessing.ChromaticAberrationIterationSamples = 4

    self:SetFov(58)
    isCasting = true
    self.fireInputBeginPos = vector2
end

function BattleHud:onFireEnd(vector2)
    local postProcessing = game.WorkSpace["Environment"].PostProcessing
    postProcessing.ChromaticAberrationIntensity = 1
    postProcessing.ChromaticAberrationStartOffset = 0.4
    postProcessing.ChromaticAberrationIterationStep = 0.01
    postProcessing.ChromaticAberrationIterationSamples = 1

    self:SetFov(75)
    isCasting = false
end

function BattleHud:onFireMove(vector2)
    if not self.fireInputBeginPos then return end
    local moveDistance = vector2 - self.fireInputBeginPos
    self.fireInputBeginPos = vector2
    CameraController.InputMove(
        moveDistance.x,
        moveDistance.y
    )
end

function BattleHud:OnInit(node, config)
    self.healthBar = self:Get("血条/进度条").node
    self.healthText = self:Get("血条/生命值").node
    ClientEventManager.Subscribe("UpdateHealth", function(data)
        self.healthBar.FillAmount = math.max(0, math.min(1, data.h / data.mh))
        self.healthText.Title = string.format("%d/%d", math.max(0, math.ceil(data.h)), math.ceil(data.mh))
    end)

    local approaching = self:Get("大波僵尸").node
    approaching.Visible = false
    self.hitIndicator = self:Get("击中提示").node
    self.hitIndicator.Visible = false
    self.hitIndicator.FillColor = ColorQuad.New(255, 255, 255, 0)
    
    -- 伤害累计相关变量
    self.accumulatedDamage = 0
    self.lastDamageTime = 0
    self.damageUpdateTask = nil
    
    ClientEventManager.Subscribe("SyncPlayerSkills", function(data)
        self:OnSyncPlayerSkills(data)
    end)
    
    -- 注册技能冷却更新事件监听
    ClientEventManager.Subscribe("EquipSkillCooldownUpdate", function(data)
        self:OnEquipSkillCooldownUpdate(data)
    end)
    
    ClientEventManager.Subscribe("ShowDamage", function(data)
        local currentTime = gg.GetTimeStamp()
        
        -- 如果距离上次伤害超过0.1秒，重置累计伤害
        if currentTime - self.lastDamageTime > 0.1 then
            self.accumulatedDamage = 0
        end
        
        -- 累加伤害
        self.accumulatedDamage = math.min(10, self.accumulatedDamage + data.percent)
        self.lastDamageTime = currentTime
        
        -- 更新指示器
        self.hitIndicator.Visible = true
        self.hitIndicator.Scale = Vector2.New(0.7 + self.accumulatedDamage, 0.7 + self.accumulatedDamage)
        self.hitIndicator.FillColor = ColorQuad.New(255, 255, 255, 255)
        
        -- 重置透明度更新任务
        if not self.damageUpdateTask then
            self.damageUpdateTask = ClientScheduler.add(function()
                local alpha = self.hitIndicator.FillColor.a - 30
                if alpha <= 0 then
                    self.hitIndicator.Visible = false
                    self.hitIndicator.FillColor = ColorQuad.New(255, 255, 255, 0)
                    ClientScheduler.cancel(self.damageUpdateTask)
                    self.damageUpdateTask = nil
                else
                    self.hitIndicator.FillColor = ColorQuad.New(255, 255, 255, alpha)
                end
            end, 0.06, 0.06)
        end
    end)

    -- 注册战斗开始事件监听
    ClientEventManager.Subscribe("BattleStartEvent", function(data)
        self:Open()
        -- 重置后座力
        accumulatedVerticalRecoil = 0
        accumulatedHorizontalRecoil = 0
        lastShotTime = 0
        -- 设置进度条
        if data.waveMobCounts and data.totalMobCount then
            local waveCount = #data.waveMobCounts
            self.progress:SetElementSize(waveCount - 1)
            local progressWidth = self.progress.node["进度条"].Size.x
            -- 计算每个波次的怪物百分比
            local accumulatedPercent = 0
            for i = 1, waveCount - 1 do
                local waveMobCount = data.waveMobCounts[i]
                local mobPercent = waveMobCount / data.totalMobCount
                accumulatedPercent = accumulatedPercent + mobPercent
                
                -- 设置波次标记的位置
                local child = self.progress:GetChild(i)
                if child then
                    child.node.Position = Vector2.New(progressWidth * (1-accumulatedPercent), 0)
                end
            end
            -- 保存波次怪物数量数据用于后续计算
            self.waveMobCounts = data.waveMobCounts
            self.totalMobCount = data.totalMobCount
            self.currentWaveIndex = 1
        end
    end)

    -- 注册波次生命更新事件监听
    ClientEventManager.Subscribe("WaveHealthUpdate", function(data)
        if not self.waveMobCounts or not self.totalMobCount then return end
        
        -- 检查波次是否发生变化
        if data.waveIndex ~= self.currentWaveIndex then
            self.currentWaveIndex = data.waveIndex
            self:PlayWaveApproaching(data.waveImg)
        end
        
        local previousWavesMobCount = 0
        for i = data.waveIndex + 1, #self.waveMobCounts do
            previousWavesMobCount = previousWavesMobCount + self.waveMobCounts[i]
        end
        previousWavesMobCount = previousWavesMobCount / self.totalMobCount
        local percent = previousWavesMobCount + data.healthPercent * (self.waveMobCounts[data.waveIndex] / self.totalMobCount)
        self.progress.node["装饰图"].Position = Vector2.New(self.progress.node.Size.x * percent, 0)
        self.progress.node["进度条"].FillAmount = 1 - percent
    end)

    -- 注册战斗结束事件监听
    ClientEventManager.Subscribe("BattleEndEvent", function(data)
        self:Close()
        -- 重置后座力
        accumulatedVerticalRecoil = 0
        accumulatedHorizontalRecoil = 0
        lastShotTime = 0
        self.currentWaveIndex = nil
    end)

    self.progress = self:Get("击杀进度条", ViewList)
    
    self.fireIcon = self:Get("开火", ViewButton)
    self.fireIcon.node.Visible = not game.RunService:IsPC()
    -- fireIcon 事件绑定改为调用上述函数
    self.fireIcon.node.TouchBegin:Connect(
        function(node, isTouchMove, vector2, int)
            self:onFireBegin(vector2)
        end
    )

    self.fireIcon.node.TouchEnd:Connect(
        function(node, isTouchMove, vector2, int)
            self:onFireEnd(vector2)
        end
    )

    self.fireIcon.node.TouchMove:Connect(
        function(node, isTouchMove, vector2, int)
            self:onFireMove(vector2)
        end
    )
end

---播放波次接近动画
function BattleHud:PlayWaveApproaching(waveImg)
    local approaching = self:Get("大波僵尸").node
    if waveImg then
        approaching.Icon = waveImg
    end
    approaching.Visible = true
    approaching.Scale = Vector2.New(3,3)
    approaching.FillColor = ColorQuad.New(255, 255, 255, 0)
    local scaleTween = TweenService:Create(approaching, TweenInfo.New(1, Enum.EasingStyle.Quad), 
        {Scale = Vector2.New(1,1), FillColor = ColorQuad.New(255, 255, 255, 255)})
    scaleTween:Play()
    scaleTween.Completed:Connect(function ()
        local fadeOut = TweenService:Create(approaching, TweenInfo.New(3, Enum.EasingStyle.Quad), 
            {FillColor = ColorQuad.New(255, 255, 255, 0)})
        fadeOut:Play()
        fadeOut.Completed:Connect(function ()
            approaching.Visible = false
        end)
    end)
end

BattleHud.autoBattle = false
BattleHud.autoBattleTaskId = nil

function BattleHud:ToggleAutoBattle()
    self.autoBattle = not self.autoBattle
    if self.autoBattle then
        self.autoBattleTaskId = ClientScheduler.add(function()
            self:AutoBattleTick()
        end, 0, 0.1)
    else
        if self.autoBattleTaskId then
            ClientScheduler.cancel(self.autoBattleTaskId)
            self.autoBattleTaskId = nil
        end
    end
    ClientEventManager.SendToServer("ToggleAutoBattle", {
        autoBattle = self.autoBattle
    })
end

function BattleHud:AutoBattleTick()
    local myPos = game.Players.LocalPlayer.Character.Position
    local myPosCenter = myPos + Vector3.New(0,100,0)
    local results = game.WorldService:OverlapSphere(6000, myPos, false, {3})
    local nearestEnemy = nil
    local minDist = math.huge
    for _, v in ipairs(results) do
        local obj = v.obj
        if obj and obj.Position then
            local dist = gg.vec.Distance3(obj.Position, myPos)
            if dist < minDist then
                local deltaDir = obj.Position + Vector3.New(0,100,0) - myPosCenter ---@type Vector3
                local length = gg.vec.Length3(deltaDir)
                local result = game.WorldService:RaycastClosest(myPosCenter, deltaDir / length, length, true, {1,2})
                if not result.isHit then
                    minDist = dist
                    nearestEnemy = obj
                end
            end
        end
    end
    if not nearestEnemy then return end

    -- 先尝试副卡技能
    if ViewBase.GetUI("HudCards"):AutoBattleTick(nearestEnemy) then
        return
    end

    -- 副卡技能都在冷却中，尝试主卡普攻
    local skillId = equippedSkills[1]
    if not skillId then return end -- 没有装备主卡技能
    
    local skill = skills[skillId]
    if not skill then return end -- 技能不存在
    
    local currentTime = gg.GetTimeStamp()
    local elapsedTime = currentTime - lastCastTime
    local remainingTime = math.max(0, skill.cooldownCache - elapsedTime)
    
    -- 如果主卡技能冷却结束，进行普攻
    if remainingTime <= 0 then
        local rot = gg.Vec3.new(nearestEnemy.Position - myPos):GetRotation()
        CameraController.RotateTo(rot.x, rot.y)
        self:SendCastSpellEvent(skillId, nearestEnemy.Position + nearestEnemy.Size / 2)
    end
end

function BattleHud:SendCastSpellEvent(skillId, targetPos)
    local camera = game.WorkSpace.CurrentCamera
    local direction = CameraController.GetForward()
    if not targetPos then
        targetPos = CameraController.RaytraceScene({1, 2, 3})
    end
    gg.network_channel:FireServer({
        cmd = "CastSpell",
        skill = skillId,
        direction = direction,
        targetPos = targetPos
    })
    if not localPlayer then
        localPlayer = game:GetService("Players").LocalPlayer.Character
    end
    localPlayer.Euler = Vector3.New(0, camera.Euler.y + 180, 0)
    if recoil then
        self:CalculateRecoil()
    end
    lastShotTime = gg.GetTimeStamp()  -- 更新最后射击时间
end

ClientEventManager.Subscribe("PressKey", function (evt)
    if evt.isDown and evt.key == Enum.KeyCode.F6.Value then
        BattleHud:ToggleAutoBattle()
        if BattleHud.autoBattle then
            gg.log("自动战斗已开启")
        else
            gg.log("自动战斗已关闭")
        end
    end
end)

-- 监听服务端发送的自动战斗切换事件
ClientEventManager.Subscribe("ToggleAutoBattleFromServer", function(data)
    BattleHud.autoBattle = data.autoBattle
    if BattleHud.autoBattle then
        if not BattleHud.autoBattleTaskId then
            BattleHud.autoBattleTaskId = ClientScheduler.add(function()
                BattleHud:AutoBattleTick()
            end, 0, 0.1)
        end
    else
        if BattleHud.autoBattleTaskId then
            ClientScheduler.cancel(BattleHud.autoBattleTaskId)
            BattleHud.autoBattleTaskId = nil
        end
    end
end)

return BattleHud.New(script.Parent, uiConfig)