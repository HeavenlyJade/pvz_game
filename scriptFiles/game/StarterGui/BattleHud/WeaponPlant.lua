local Perlin = MS.Math.Perlin
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local BulletManager = require("ServiceNodes.MainStorage.Character.BulletManager")

local WeaponPlant = MS.Class.new("WeaponPlant", MS.ActorBase)

local WeaponState = {
    READY = 1,
    FIRING = 2,
    RELOADING = 3
}

function WeaponPlant:CloneActor(actorBase)
    -- 复制基本属性
    self.uid = actorBase.uid
    self.bindActor = actorBase.bindActor
    self.bindTween = actorBase.bindTween
    self.actorClass = actorBase.actorClass
    self.controller = actorBase.controller
    -- self.AnimatorSupportLayerBlend = false
    -- if self.bindActor.Name == "FumeShroom" or self.bindActor.Name == "SplitPeaShooter" then
    self.AnimatorSupportLayerBlend = true
    -- end
    if self.bindActor.Name == "FumeShroom" then
        self.AnimatorSupportLayerBlend = false
    end

    -- 复制所有组件
    self.actorComponents = {}
    for componentType, component in pairs(actorBase.actorComponents) do
        self.actorComponents[componentType] = component
        -- 更新组件的owner引用为新的WeaponPlant实例
        component.owner = self
    end

    -- 外面再包一个Actor,方便使用UseCameraAngle功能
    self.actorContainer = SandboxNode.New("Actor")
    self.actorContainer.Parent = self.bindActor.Parent
    self.actorContainer.Position = self.bindActor.Position
    self.actorContainer.LocalEuler = Vector3.New(0, 0, 0)
    self.actorContainer.Visible = false
    self.actorContainer.Name = self.bindActor.Name
    self.actorContainer:SetAttribute("GameplayTag", self.bindActor:GetAttribute("GameplayTag"))

    self.bindActor.Parent = self.actorContainer
    self.bindActor.InheritParentVisible = false
    self.bindActor.Visible = true
    if self.bindActor.Name == "FumeShroom" then
        self.bindActor.LocalEuler = Vector3.New(0, -90, 0)
    else
        self.bindActor.LocalEuler = Vector3.New(0, 90, 0)
    end
    self.bindActor.Name = "ActorModel"

    -- 把bindActor指向actorContainer
    self.bindActor = self.actorContainer
    if self.AnimatorSupportLayerBlend then
        self:AddUpdateListener()
    end
end

function WeaponPlant:AddUpdateListener()
    if self.renderSteppedIns == nil then
        self.renderSteppedIns =
            RunService.RenderStepped:Connect(
            function()
                self:UpdateNeck()
            end
        )
    end
end

function WeaponPlant:RemoveUpdateListener()
    if self.renderSteppedIns then
        self.renderSteppedIns:Disconnect()
        self.renderSteppedIns = nil
    end
end

function WeaponPlant:UpdateNeck()
    local camera = Workspace.Camera
    if camera == nil then
        print("is Nil", camera, Workspace)
        return
    end
    local model = self.bindActor.ActorModel
    local X = camera.LocalEuler.X
    local Animator = model.Animator
    if X < -90 then
        X = -90
    end
    if X > 90 then
        X = 90
    end
    -- print("aaa",X)
    if X >= 0 then
        -- down
        local alpha = 1 - X / 90.0
        Animator:SetLayerWeight(0, alpha)
        Animator:SetLayerWeight(1, 0)
        Animator:SetLayerWeight(2, 1.0 - alpha)
    else
        -- up
        local alpha = 1 - (0 - X) / 90
        Animator:SetLayerWeight(0, alpha)
        Animator:SetLayerWeight(1, 1.0 - alpha)
        Animator:SetLayerWeight(2, 0)
    end
end

function WeaponPlant:ctor(actorBase)
    self:CloneActor(actorBase)

    self.weaponState = WeaponState.READY
    -- 获取武器配置
    self.weaponPlant_config = MS.DataConfig.Config_WeaponPlant[self.bindActor.Name]

    -- 开火参数
    self.fireInterval = self.weaponPlant_config.fire_rate / 1000
    self.delayFire = false --是否延迟开火
    self.fireDelay = self.weaponPlant_config.fire_delay / 1000
    self.shootingMode = self.weaponPlant_config.shooting_mode
    -- 弹丸参数
    self.muzzleVelocity = self.weaponPlant_config.muzzle_velocity
    self.gunRepel = self.weaponPlant_config.gun_repel
    self.pillNum = self.weaponPlant_config.pill_num

    -- 装弹参数
    self.reloadTime = self.weaponPlant_config.reload_time / 1000
    self.reloadType = self.weaponPlant_config.reload_type
    self.magazine = self.weaponPlant_config.magazine
    self.magazine_carry = self.weaponPlant_config.magazine_carry

    -- 后坐力
    -- 垂直后坐力相关参数
    self.recoilVerticalStrength = self.weaponPlant_config.vertical_recoil[1] * 180 / MS.Math.PI -- 基础垂直后坐力强度(角度)
    self.recoilVerticalRecoilMax = self.weaponPlant_config.vertical_recoil_max[1] * 180 / MS.Math.PI -- 最大垂直后坐力强度(角度)
    self.recoilVerticalCorrectSpeed = self.weaponPlant_config.horizontal_recoil_correct[1] * 180 / MS.Math.PI -- 垂直后坐力恢复速度
    self.recoilVerticalBuildupSpeed = self.weaponPlant_config.recoil_cooling_time -- 垂直后坐力累积速度
    self.verticalRecoilProportion = self.weaponPlant_config.vertical_recoil_proportion -- 垂直后坐力比例系数

    -- 水平后坐力相关参数
    self.recoilHorizontalStrength = self.weaponPlant_config.horizontal_recoil[1] * 180 / MS.Math.PI -- 基础水平后坐力强度(角度)
    self.recoilHorizontalRecoilMax = self.weaponPlant_config.horizontal_recoil_max[1] * 180 / MS.Math.PI -- 最大水平后坐力强度(角度)
    self.recoilHorizontalCorrectSpeed = self.weaponPlant_config.horizontal_recoil_correct[1] * 180 / MS.Math.PI -- 水平后坐力恢复速度
    self.recoilHorizontalBuildupSpeed = self.weaponPlant_config.recoil_cooling_time -- 水平后坐力累积速度
    self.horizontalRecoilProportion = self.weaponPlant_config.horizontal_recoil_proportion -- 水平后坐力比例系数

    self.recoilCoolingTime = self.fireInterval

    -- 添加累积后座力追踪
    self.accumulatedVerticalRecoil = 0
    self.accumulatedHorizontalRecoil = 0
    self.recoilRecoveryConnection = nil

    -- 子弹偏转
    self.spreadProbability = self.weaponPlant_config.change_probability[1] -- 子弹偏转概率
    self.spreadRadius = self.weaponPlant_config.spread_radius[1] -- 子弹偏转半径
    self.spreadRadiusCorrect = self.weaponPlant_config.spread_radius_correct[1] -- 子弹偏转半径修正
    self.spreadRadiusMax = self.weaponPlant_config.spread_max[1] -- 子弹偏转半径最大值
    self.spreadCoolingTime = self.weaponPlant_config.spread_cooling_time -- 子弹偏转冷却时间

    -- 准心参数
    self.crosshairMode = self.weaponPlant_config.crosshair_mode
    self.HIPCrossHairRes = self.weaponPlant_config.HIP_crosshair

    -- 辅助瞄准和自动扳机
    self.autoAimDistance = self.weaponPlant_config.auto_aim_dis
    self.autoFireDistance = self.weaponPlant_config.auto_fire_dis

    -- 子弹对象池
    self.bulletPool = {}
    self.bulletPoolCapacity = 75 -- 设置对象池的最大容量

    -- 机制

    -- 开火机制参数
    self.pullingTrigger = false
    self.fireTimer =
        MS.Timer.CreateTimer(
        self.fireInterval,
        self.fireInterval,
        false,
        function()
            if self.weaponState == WeaponState.FIRING then
                self:SetWeaponState(WeaponState.READY)
            end
        end
    )

    -- 装弹机制参数
    self.ammo = self.magazine
    self.reloadTimer =
        MS.Timer.CreateTimer(
        self.reloadTime,
        self.reloadTime,
        false,
        function()
            self:Reload()
            -- 子弹数量UI更新
            _G.PlayerController.eventObject:FireEvent(
                "OnAttributeUpdate",
                self.positionIndex,
                "Ammo",
                self.ammo,
                self.magazine_carry
            )
        end
    )

    self.muzzleFlashTimer =
        MS.Timer.CreateTimer(
        0.02,
        0.02,
        false,
        function()
            self.bindActor.ActorModel.FirePosition.MuzzleFlash.Active = false
        end
    )
    -- 音效
    self.soundCue = MS.SoundCue.new(self.bindActor.ActorModel.SoundGroup)
end

function WeaponPlant:Init(positionIndex)
    self.positionIndex = positionIndex
    self.firePosition = self.bindActor.ActorModel.FirePosition

    local bulletConfig = MS.Config.GetCustomConfigNode(self.bindActor.Name)
    local bulletData = require(bulletConfig.Data)
    local bulletName = bulletData.Attributes.spawnObjectName

    -- 初始化子弹管理器
    self.bulletManager = BulletManager.new(self)
    self.bulletManager:Init(bulletName)
end

function WeaponPlant:AttachCameraComponent(cameraController)
    cameraController.owner = self
    self.actorComponents["CameraController"] = cameraController
    self.bindActor.UseCameraAngle = true

    if self.pullingTrigger then
        self:ReleaseTrigger()
    end
    -- 添加后座力恢复更新
    self.recoilRecoveryFunc = function(deltaTime)
        if not self.pullingTrigger then
            -- 恢复垂直后座力
            if math.abs(self.accumulatedVerticalRecoil) > 0.01 then
                local recoveryAmount = self.recoilVerticalCorrectSpeed * deltaTime
                self.accumulatedVerticalRecoil =
                    math.max(0, math.abs(self.accumulatedVerticalRecoil) - recoveryAmount) *
                    (self.accumulatedVerticalRecoil > 0 and 1 or -1)
                cameraController:InputMove(0, -self.accumulatedVerticalRecoil)
            end

            -- 恢复水平后座力
            if math.abs(self.accumulatedHorizontalRecoil) > 0.01 then
                local recoveryAmount = self.recoilHorizontalCorrectSpeed * deltaTime
                self.accumulatedHorizontalRecoil =
                    math.max(0, math.abs(self.accumulatedHorizontalRecoil) - recoveryAmount) *
                    (self.accumulatedHorizontalRecoil > 0 and 1 or -1)
                cameraController:InputMove(-self.accumulatedHorizontalRecoil, 0)
            end
        end
    end

    -- 开始后座力恢复更新
    if not self.recoilRecoveryConnection then
        self.recoilRecoveryConnection = MS.RunService.RenderStepped:Connect(self.recoilRecoveryFunc)
    end
end

function WeaponPlant:UnAttachCameraComponent()
    if self.pullingTrigger then
        self:ReleaseTrigger()
    end

    self.actorContainer.UseCameraAngle = false
    self.actorComponents["CameraController"] = nil

    if self.recoilRecoveryConnection then
        self.recoilRecoveryConnection:Disconnect()
        self.recoilRecoveryConnection = nil
    end
end

function WeaponPlant:GetWeaponState()
    return self.weaponState
end

function WeaponPlant:SetWeaponState(state)
    self.weaponState = state
end

function WeaponPlant:PullTrigger()
    self.pullingTrigger = true

    while self.pullingTrigger do
        self:TryFire()
        wait(0.02) -- 控制触发频率，间隔0.02秒
    end
end

function WeaponPlant:ReleaseTrigger()
    self.pullingTrigger = false

    self:CancelRecoil()
end

--@func 尝试开火
--@返回
function WeaponPlant:TryFire()
    if not (self:GetWeaponState() == WeaponState.READY) then
        return
    end

    local targetPosition = self:GetPositionUnderCursor()

    if self.AnimatorSupportLayerBlend then
        self.bindActor.ActorModel.Animator:Play("Base Layer.ATK", 0, 0)
        self.bindActor.ActorModel.Animator:Play("UpLayer.ATKUp", 1, 0)
        self.bindActor.ActorModel.Animator:Play("DownLayer.ATKDown", 2, 0)
    else
        self.bindActor.ActorModel.Animator:Play("Base.Attack", 0, 0)
    end
    if targetPosition ~= nil then
        self:Fire(targetPosition)
    end
end

function WeaponPlant:Fire(targetPosition)
    self:SetWeaponState(WeaponState.FIRING)

    local bulletActor = self.bulletManager:GetIdleBullet()
    self.bulletManager:EnableBullet(bulletActor)

    local weaponConfigNode = MS.Config.GetCustomConfigNode(self.bindActor.Name)
    local weaponData = require(weaponConfigNode.Data)
    local weaponDamage = weaponData.Attributes.damage

    local bullet =
        self.actorComponents["SpawnComponent"]:Spawn(bulletActor, targetPosition, self.muzzleVelocity, weaponDamage)
    if bullet == nil then
        print("bullet is nil")
    end

    if self.fireTimer:GetRunState() == Enum.TimerRunState.RUNNING then
        self.fireTimer:Stop()
    end
    self.fireTimer:Start()

    self:AfterFire()
end

--@func 开火之后处理
function WeaponPlant:AfterFire()
    -- 更新子弹
    self.ammo = self.ammo - 1

    if self.ammo <= 0 then
        self:TryReload()
    end

    _G.PlayerController.playerHUD.eventObject:FireEvent(
        "OnAttributeUpdate",
        self.positionIndex,
        "Ammo",
        self.ammo,
        self.magazine_carry
    )
    self.soundCue:PlayShootSound()

    if self.bindActor.ActorModel.FirePosition.MuzzleFlash ~= nil then
        self.bindActor.ActorModel.FirePosition.MuzzleFlash.Active = true
        self.muzzleFlashTimer:Start()
    end

    self:CalculateRecoil()
    --self:ApplyRecoil(recoil)
    self:ApplyCameraShake(self.bindActor.Name)
    _G.PlayerController.eventObject:FireEvent("OnFire", self.accumulatedVerticalRecoil)

	local fe = self.bindActor.ActorModel.FirePosition.FireEffect
    if fe then
        fe:ReStart()
		for _, c in ipairs(fe.Children) do
			c:ReStart()
		end
    end
end

function WeaponPlant:ApplySpread(targetPosition)
    local noiseX = math.random() * 1000 -- 随机起始点，避免每次相同
    local noiseY = math.random() * 1000

    if math.random() < 0.8 then
        -- 使用 Perlin 噪声生成偏转角度
        local spreadAngle = Perlin:Noise2D(noiseX, noiseY) * 2 * math.pi
        -- 使用 Perlin 噪声生成偏转幅度
        local spreadMagnitude = Perlin:Noise2D(noiseX + 1, noiseY + 1) * self.spreadRadiusMax
        -- 确保偏转幅度不超过当前的最大偏转半径
        spreadMagnitude = math.min(spreadMagnitude, self.spreadRadius + self.spreadRadiusCorrect)

        -- 计算偏转向量
        local spreadOffset =
            Vector3.New(spreadMagnitude * math.cos(spreadAngle), 0, spreadMagnitude * math.sin(spreadAngle))

        -- 将偏转应用到目标位置
        targetPosition = targetPosition + spreadOffset
    end

    return targetPosition
end

function WeaponPlant:ApplyCameraShake(shakeName)
    if not self.actorComponents["CameraController"] then
        return
    end
    self.actorComponents["CameraController"]:StartShake(shakeName)
end

function WeaponPlant:CalculateRecoil()
    -- 计算垂直后座力（主要是上抬）
    local verticalRecoil = self.recoilVerticalStrength * (1 + math.random() * 0.2) / 10
    -- 限制最大垂直后座力
    self.accumulatedVerticalRecoil =
        math.min(
        self.recoilVerticalRecoilMax,
        self.accumulatedVerticalRecoil + verticalRecoil * self.verticalRecoilProportion
    )

    -- 计算水平后座力（随机左右）
    local horizontalRecoil = self.recoilHorizontalStrength * (math.random() * 2 - 1) / 10
    -- 限制最大水平后座力
    self.accumulatedHorizontalRecoil =
        math.clamp(
        self.accumulatedHorizontalRecoil + horizontalRecoil * self.horizontalRecoilProportion,
        -self.recoilHorizontalRecoilMax,
        self.recoilHorizontalRecoilMax
    )
end
function WeaponPlant:ApplyRecoil()
    if not self.actorComponents["CameraController"] then
        return
    end
    -- 通过模拟鼠标输入应用后座力
    self.actorComponents["CameraController"]:InputMove(
        self.accumulatedHorizontalRecoil, -- 水平方向
        -self.accumulatedVerticalRecoil -- 垂直方向
    )
end

function WeaponPlant:CancelRecoil()
    self.accumulatedVerticalRecoil = 0
    self.accumulatedHorizontalRecoil = 0

    if self.recoilRecoveryConnection then
        self.recoilRecoveryConnection:Disconnect()
        self.recoilRecoveryConnection = nil
    end
end

-- 获取闲置的子弹
function WeaponPlant:GetIdleBullet()
    for _, bullet in pairs(self.bulletPool) do
        if not bullet.enabled then
            return bullet
        end
    end
    return nil
end

-- 启用子弹
function WeaponPlant:EnableBullet(bullet)
    bullet.bindActor.Visible = true
    if bullet.bindActor.ProjectileTrail.AssetID == "" then
        local assetID = bullet.bindActor.ProjectileTrail:GetAttribute("assetID")
        bullet.bindActor.ProjectileTrail:SetAssetID(
            assetID,
            function()
            end
        )
    end
    bullet.enabled = true
end

-- 回收子弹
function WeaponPlant:RecycleBullet(bullet)
    if bullet.tween then
        bullet.tween:Destroy()
        bullet.tween = nil
    end

    bullet.bindActor.Position = bullet.spawner.firePosition.Position
    bullet.bindActor.Visible = false
    bullet.enabled = false
end

--尝试换弹
function WeaponPlant:TryReload()
    if self:GetWeaponState() == WeaponState.RELOADING then
        return
    end

    if self.ammo < self.magazine and self.magazine_carry > 0 then
        self:StartReload()
    end
end

function WeaponPlant:StartReload()
    self:SetWeaponState(WeaponState.RELOADING)
    self.reloadTimer:Start()
    self.soundCue:PlayReloadSound()
end

function WeaponPlant:Reload()
    local ammoNeeded = self.magazine - self.ammo
    local ammoToReload = math.min(ammoNeeded, self.magazine_carry)

    self.ammo = self.ammo + ammoToReload
    self.magazine_carry = self.magazine_carry - ammoToReload

    self:SetWeaponState(WeaponState.READY)
end

function WeaponPlant:SmoothLookAt(targetPosition)
end

function WeaponPlant:GetPositionUnderCursor()
    local windowCenterCursor = {
        Position = {
            x = MS.WorkSpace.CurrentCamera.ViewportSize.x / 2,
            y = MS.WorkSpace.CurrentCamera.ViewportSize.y / 2
        }
    }
    local rayLength = 10000
    local raycastResult = MS.Utils.TryGetRaycastUnderCursor(windowCenterCursor, rayLength, false, {1, 3})
    return raycastResult.position
end

function WeaponPlant:Destroy()
    self:RemoveUpdateListener()
    if self.bulletManager then
        self.bulletManager:Destroy()
    end
end

return WeaponPlant
