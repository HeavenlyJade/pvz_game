local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity
local DummyEntity = require(MainStorage.code.server.entity_types.DummyEntity) ---@type DummyEntity

---@class Graphic:Class
local Graphic = ClassMgr.Class("Graphic")

-- 服务端不再管理特效对象，仅发送事件到客户端

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
---@return function|nil 取消函数
function Graphic:PlayAt(caster, target, param, actions)
    local c
    if self.autoPlay then
        c = self:GetTarget(caster, target)
    else
        c = target
    end
    
    local isCancelled = false
    local cancelFunction = function()
        isCancelled = true
    end
    
    if self.delay > 0 then
        if gg.isServer then
            ServerScheduler.add(function ()
                if not isCancelled then
                    self:PlayAtReal(caster, c, param, actions, cancelFunction)
                end
            end, self.delay)
        else
            ClientScheduler.add(function ()
                if not isCancelled then
                    self:PlayAtReal(caster, c, param, actions, cancelFunction)
                end
            end, self.delay)
        end
    else
        self:PlayAtReal(caster, c, param, actions, cancelFunction)
    end
    
    return cancelFunction
end

---@param caster Entity
---@param target Entity  
---@param param CastParam
---@param actions table
---@param cancelFunction function
function Graphic:PlayAtReal(caster, target, param, actions, cancelFunction)
    -- 只在服务端向客户端发送特效事件
    if gg.isServer then
        local effectId = gg.create_uuid("fx_")
        local targetPos = target:GetCenterPosition()
        local eventData = {
            effectId = effectId,
            type = self:GetType(),
            name = self:GetName(),
            targetUin = target.isPlayer and target.uin or nil,
            position = {targetPos.x, targetPos.y, targetPos.z},
            duration = self.duration,
            repeatCount = self.repeatCount,
            repeatDelay = self.repeatDelay,
            offset = {self.offset.x, self.offset.y, self.offset.z},
            data = self:GetEffectData()
        }
        
        -- 为需要绑定的特效添加目标节点路径
        if self.boundToEntity and target.actor then
            eventData.boundToPath = gg.GetFullPath(target.actor)
        end
        
        -- 增强取消函数以发送取消事件
        if cancelFunction then
            local originalCancel = cancelFunction
            cancelFunction = function()
                originalCancel()
                -- 发送取消事件到客户端
                local cancelEventData = { effectId = effectId }
                if target.isPlayer then
                    target:SendEvent("CancelGraphicEffect", cancelEventData)
                else
                    caster.scene:BroadcastEventAround("CancelGraphicEffect", cancelEventData, nil, 0)
                end
            end
        end
        
        -- 如果目标是玩家，只发送给该玩家；否则发送给场景内所有玩家
        if target.isPlayer then
            target:SendEvent("PlayGraphicEffect", eventData)
        else
            caster.scene:BroadcastEventAround("PlayGraphicEffect", eventData, nil, 0)
        end
        
        -- 处理重复播放的取消机制
        if self.repeatCount > 1 and self.repeatDelay > 0 then
            local currentRepeat = 1
            local scheduleNext
            scheduleNext = function()
                if cancelFunction and not cancelFunction.cancelled then
                    currentRepeat = currentRepeat + 1
                    if currentRepeat <= self.repeatCount then
                        ServerScheduler.add(function()
                            if not cancelFunction.cancelled then
                                -- 发送下一次重复的特效事件
                                eventData.effectId = gg.create_uuid("fx_")
                                if target.isPlayer then
                                    target:SendEvent("PlayGraphicEffect", eventData)
                                else
                                    caster.scene:BroadcastEventAround("PlayGraphicEffect", eventData, nil, 0)
                                end
                                scheduleNext()
                            end
                        end, self.repeatDelay)
                    end
                end
            end
            scheduleNext()
        end
    end
end

-- 子类需要实现的抽象方法
function Graphic:GetType()
    return "Graphic"
end

function Graphic:GetName()
    return "Unknown"
end

-- 由子类实现，返回特效数据
function Graphic:GetEffectData()
    return {}
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

function ParticleGraphic:GetEffectData()
    return {
        particleName = self.particleName,
        particleAssetId = self.particleAssetId,
        boundToEntity = self.boundToEntity,
        boundToBone = self.boundToBone
    }
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

function ModelGraphic:GetEffectData()
    return {
        modelName = self.modelName,
        stateMachine = self.stateMachine,
        animationName = self.animationName,
        boundToEntity = self.boundToEntity,
        boundToBone = self.boundToBone
    }
end

---@class SoundGraphic:Graphic
local SoundGraphic = ClassMgr.Class("SoundGraphic", Graphic)
function SoundGraphic:OnInit( data )
    self.soundAssetId = data["声音资源"]
    self.boundToEntity = data["绑定实体"] or false
    self.volume = data["响度"] or 1.0
    self.pitch = data["音调"] or 1.0
    self.range = data["距离"]
    self.relevantOnly = data["仅播放给相关者"] or false
end

function SoundGraphic:GetType()
    return "音效"
end

function SoundGraphic:GetName()
    return self.soundAssetId
end

function SoundGraphic:GetEffectData()
    return {
        soundAssetId = self.soundAssetId,
        boundToEntity = self.boundToEntity,
        volume = self.volume,
        pitch = self.pitch,
        range = self.range,
        relevantOnly = self.relevantOnly
    }
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