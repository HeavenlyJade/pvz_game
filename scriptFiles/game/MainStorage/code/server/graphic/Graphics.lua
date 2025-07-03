local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local DummyEntity = require(MainStorage.code.server.entity_types.DummyEntity) ---@type DummyEntity

---@class Graphic:Class
local Graphic = ClassMgr.Class("Graphic")

-- 从模板创建新的特效对象
local particlePools = {} ---@type table<string, table<SandboxNode>>
local nodeCache = {} ---@type table<string, SandboxNode>

local function CreateParticle(particleName)
    if particleName == "" then
        return nil, nil
    end
    
    -- 获取或创建对象池
    if not particlePools[particleName] then
        particlePools[particleName] = {}
    end
    local pool = particlePools[particleName]
    
    -- 尝试从对象池中获取对象
    local fx = table.remove(pool)
    if fx then
        fx.Visible = true
        fx.Enabled = true
        for _, child in ipairs(fx.Children) do
            child.Enabled = true
            child.Visible = true
        end
        return fx, nodeCache[particleName]
    end
    
    if not nodeCache[particleName] then
        local node = MainStorage
        local fullPath = ""
        local lastPart = ""
        
        -- 遍历路径的每一部分
        for part in particleName:gmatch("[^/]+") do
            if part ~= "" then
                lastPart = part
                if not node then
                    return nil
                end
                node = node[part]
                if fullPath == "" then
                    fullPath = part
                else
                    fullPath = fullPath .. "/" .. part
                end
            end
        end
        
        if not node then
            return nil, nil
        end
        nodeCache[particleName] = node
    end
    
    return nodeCache[particleName]:Clone(), nodeCache[particleName]
end

-- 回收特效对象到对象池
local function RecycleParticle(particleName, fx)
    if not fx or not particleName or particleName == "" then
        return
    end
    
    -- 确保对象池存在
    if not particlePools[particleName] then
        particlePools[particleName] = {}
    end
    
    -- 重置特效状态
    fx.Visible = false
    fx.Enabled = false
    -- if fx:IsA("EffectObject") then
    --     fx:Stop(0)
    -- end
    for _, child in ipairs(fx.Children) do
        child.Visible = false
        child.Enabled = false
    end
    -- 将对象添加到对象池
    table.insert(particlePools[particleName], fx)
end

-- 清理对象池
local function ClearParticlePool(particleName)
    if not particleName or particleName == "" then
        return
    end
    
    local pool = particlePools[particleName]
    if pool then
        for _, fx in ipairs(pool) do
            if fx.Enabled then
                fx.Enabled = false
            end
            fx:Destroy()
        end
        particlePools[particleName] = {}
    end
end

-- 清理所有对象池
local function ClearAllParticlePools()
    for particleName, pool in pairs(particlePools) do
        for _, fx in ipairs(pool) do
            if fx.Enabled then
                fx.Enabled = false
            end
            fx:Destroy()
        end
    end
    particlePools = {}
    nodeCache = {} -- 同时清理node缓存
end

function Graphic:OnInit( data )
    self.offset = gg.Vec3.new(data["偏移"]) or gg.Vec3.zero()
    self.targeter = data["目标"]
    self.targeterPath = data["目标场景名"]
    self.delay = data["延迟"] or 0
    self.duration = data["持续时间"] or 0
    self.repeatCount = data["重复次数"] or 1
    self.repeatDelay = data["重复延迟"] or 0
    self.autoPlay = self.targeter == "目标" or self.targeter == "自己" or self.targeter == "场景"
end

function Graphic:IsTargeter(targeter)
    if self.autoPlay then
        if targeter then
        return false
        end
    else
        if targeter ~= self.targeter then
            return false
        end
    end
    return true
end

function Graphic:GetTarget(caster, target)
    if self.targeter == "目标" then
        return target
    elseif self.targeter == "自己" then
        return caster
    elseif self.targeter == "场景" and ClassMgr.Is(target, "Entity") then
        local targeterPath = self.targeterPath
        if not targeterPath then
            return target
        end
        local scene = target.scene ---@type Scene
        local node = scene:Get(targeterPath)
        if not node then
            return target
        end
        local entity = Entity.node2Entity[node]
        if not entity then
            entity = DummyEntity.New(node)
        end
        return entity
    end
    return target
end

---@param caster Entity
---@param target Entity
---@param param CastParam
---@param actions table
function Graphic:PlayAt(caster, target, param, actions)
    local c
    if self.autoPlay then
        c = self:GetTarget(caster, target)
    else
        c = target
    end
    if self.delay > 0 then
        if gg.isServer then
            ServerScheduler.add(function ()
                self:PlayAtReal(caster, c, param, actions)
            end, self.delay)
        else
            ClientScheduler.add(function ()
                self:PlayAtReal(caster, c, param, actions)
            end, self.delay)
        end
    else
        self:PlayAtReal(caster, c, param, actions)
    end
end

---@param caster Entity
---@param target Entity
---@param param CastParam
---@param actions table
function Graphic:PlayAtReal(caster, target, param, actions)
    local isCancelled = false
    local currentRepeat = 0
    
    local function addCancelFunction(effect, repeatIndex)
        local effectCancel = function()
            if effect.Enabled then
                effect.Enabled = false
                effect:Destroy()
            end
        end
        table.insert(actions, effectCancel)
        return effectCancel
    end
    
    local function playEffect()
        if isCancelled then 
            return 
        end
        -- 创建并设置效果对象
        local effect = self:CreateEffect(target, caster.scene)
        if not effect then 
            return 
        end
        
        -- 添加取消函数
        local effectCancel = addCancelFunction(effect, currentRepeat + 1)
        
        currentRepeat = currentRepeat + 1
        
        -- 设置持续时间
        if self.duration > 0 then
            ServerScheduler.add(function()
                if not isCancelled then
                    effectCancel()
                end
            end, self.duration)
        end
        
        -- 设置下一次重复
        if currentRepeat < self.repeatCount and self.repeatDelay > 0 then
            ServerScheduler.add(playEffect, self.repeatDelay)
        end
    end
    
    -- 启动第一次播放
    playEffect()
end

-- 子类需要实现的抽象方法
function Graphic:GetType()
    return "Graphic"
end

function Graphic:GetName()
    return "Unknown"
end

function Graphic:CreateEffect(target, scene)
    return nil
end

---@class ParticleGraphic:Graphic
local ParticleGraphic = ClassMgr.Class("ParticleGraphic", Graphic)
function ParticleGraphic:OnInit( data )
    self.particleName = data["特效对象"]
    self.particleAssetId = data["特效资产"] or nil
    self.boundToEntity = data["绑定实体"] or false
    self.boundToBone = data["绑定挂点"] or nil
end

function ParticleGraphic:GetType()
    return "特效"
end

function ParticleGraphic:GetName()
    return self.particleName
end

function ParticleGraphic:CreateEffect(target, scene)
    local fx, previous = CreateParticle(self.particleName)
    if not fx or not previous then 
        return nil 
    end
    if gg.isServer then
        local container
        if self.boundToEntity and target.isEntity then
            container = target.actor
        else
            container = game.WorkSpace["Ground"][scene.name]["世界特效"]
        end
        if not container then
            return nil
        end
        fx:SetParent(container)
        if not self.boundToEntity then
            fx.Position = gg.vec.ToVector3(self.offset + target:GetCenterPosition())
        else
            fx.LocalPosition = previous.LocalPosition
            fx.LocalEuler = previous.LocalEuler
        end
        if self.duration > 0 then
            ServerScheduler.add(function()
                RecycleParticle(self.particleName, fx)
            end, self.duration)
        end
    else
        fx:SetParent(target)
        fx.LocalPosition = previous.LocalPosition
        fx.LocalEuler = previous.LocalEuler
    end
    return fx
end

---@class AnimationGraphic:Graphic
local AnimationGraphic = ClassMgr.Class("AnimationGraphic", Graphic)
function AnimationGraphic:OnInit( data )
    self.animationName = data["播放动画"]
    self.playbackSpeed = data["播放速度"]
end

function AnimationGraphic:PlayAtReal(caster, target, param)
    if target.modelPlayer then
        target.modelPlayer:SwitchState(self.animationName, self.playbackSpeed)
    end
end

---@class CameraShakeGraphic:Graphic
local CameraShakeGraphic = ClassMgr.Class("CameraShakeGraphic", Graphic)

function CameraShakeGraphic:OnInit( data )
    self.rotation = data["旋转"] ---@type Vector2
    self.position = data["位移"] ---@type Vector3
    self.tweenStyle = data["动画风格"]
    self.dropStyle = data["衰减风格"]
    self.frequency = data["频率"]
end

function CameraShakeGraphic:PlayAtReal(caster, target, param)
    if gg.isServer then
        if target.isPlayer then
            gg.network_channel:fireClient(target.uin, {
                cmd = "ShakeCamera",
                dura = self.duration,
                rotShake = self.rotation,
                posShake = self.position,
                mode = self.tweenStyle,
                drop = self.dropStyle,
                frequency = self.frequency
            })
        end
    else
        local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
        ClientEventManager.Publish("ShakeCamera", {
            dura = self.duration,
            rotShake = self.rotation,
            posShake = self.position,
            mode = self.tweenStyle,
            drop = self.dropStyle,
            frequency = self.frequency
        })
    end
end

---@class ModelGraphic:Graphic
local ModelGraphic = ClassMgr.Class("ModelGraphic", Graphic)
function ModelGraphic:OnInit( data )
    self.modelName = data["模型对象"]
    self.stateMachine = data["模型状态机"]
    self.animationName = data["播放动画"]
    self.boundToEntity = data["绑定实体"] or false
    self.boundToBone = data["绑定挂点"] or nil
end

function ModelGraphic:GetType()
    return "模型"
end

function ModelGraphic:GetName()
    return self.modelName
end

function ModelGraphic:CreateEffect(target, scene)
    local model, previous = CreateParticle(self.modelName)
    if not model or not previous then return nil end
    if gg.isServer then
        local container
        if self.boundToEntity and target.isEntity then
            container = target.actor
        else
            container = game.WorkSpace["Ground"][scene.name]["世界特效"]
        end
        
        if not container then
            return nil
        end
        
        
        model:SetParent(container)
        if not self.boundToEntity then
            model.LocalPosition = gg.vec.ToVector3(target:GetPosition())
        else
            model.LocalPosition = previous.LocalPosition
            model.LocalEuler = previous.LocalEuler
        end
        model.Enabled = true
    else
        model:SetParent(target)
        model.LocalPosition = previous.LocalPosition
        model.LocalEuler = previous.LocalEuler
    end
    
    if self.animationName and self.animationName ~= "" then
        local modelPlayer = model.Animator
        if modelPlayer then
            modelPlayer:Play(self.animationName, 0, 0)
        end
    end
    return model
end

---@class SoundGraphic:Graphic
local SoundGraphic = ClassMgr.Class("SoundGraphic", Graphic)
function SoundGraphic:OnInit( data )
    self.soundAssetId = data["声音资源"]
    self.boundToEntity = data["绑定实体"] or false
    self.volume = data["响度"] or 1.0
    self.pitch = data["音调"] or 1.0
end

function SoundGraphic:GetType()
    return "音效"
end

function SoundGraphic:GetName()
    return self.soundAssetId
end

function SoundGraphic:PlayAtReal(caster, target, param)
    if not self.soundAssetId or self.soundAssetId == "" then
        return
    end
    if gg.isServer then
        local boundTo = nil
        if self.boundToEntity and target.isEntity then
            boundTo = target.actor
        else
            boundTo = gg.Vec3.new(target:GetPosition())
        end
        caster.scene:PlaySound(self.soundAssetId, boundTo, self.volume, self.pitch)
    else
        local data = {
            soundAssetId = self.soundAssetId,
            volume = self.volume,
            pitch = self.pitch,
            range = 6000,
            key = key,
            position = {target.Position.x, target.Position.y, target.Position.z}
        }
        local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
        ClientEventManager.Publish("PlaySound", data)
    end
end

---@class Graphics
---@field ParticleGraphic ParticleGraphic
---@field AnimationGraphic AnimationGraphic
---@field CameraShakeGraphic CameraShakeGraphic
---@field ModelGraphic ModelGraphic
---@field SoundGraphic SoundGraphic
local loaders = {
    ParticleGraphic = ParticleGraphic,
    AnimationGraphic = AnimationGraphic,
    CameraShakeGraphic = CameraShakeGraphic,
    ModelGraphic = ModelGraphic,
    SoundGraphic = SoundGraphic,
}

--- 加载特效配置
---@param effectsData table[]|nil 特效配置数组
---@return Graphic[] 特效实例数组
local function Load(effectsData)
    if not effectsData then return {} end
    
    local effects = {}
    for _, effectData in ipairs(effectsData) do
        if effectData["_type"] then
            local effectClass = loaders[effectData["_type"]]
            if effectClass then
                local effect = effectClass.New(effectData)
                table.insert(effects, effect)
            end
        end
    end
    return effects
end

loaders["Load"] = Load

return loaders