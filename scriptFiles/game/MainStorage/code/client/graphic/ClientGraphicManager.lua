local MainStorage = game:GetService('MainStorage')
local WorkSpace = game:GetService('WorkSpace')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local TweenService = game:GetService('TweenService')

---@class ClientGraphicManager
local ClientGraphicManager = {}

-- 缓存特效模板节点
local nodeCache = {} ---@type table<string, SandboxNode>

-- 活跃特效管理 - 按effectId存储
local activeEffects = {} ---@type table<string, SandboxNode[]>

-- 获取特效模板节点
local function GetEffectTemplate(effectPath)
    if nodeCache[effectPath] then
        return nodeCache[effectPath]
    end
    
    local node = MainStorage
    for part in effectPath:gmatch("[^/]+") do
        if part ~= "" and node then
            node = node[part]
        end
    end
    
    if node then
        nodeCache[effectPath] = node
        return node
    end
    
    return nil
end

-- 创建粒子特效
local function CreateParticleEffect(data, position, duration, boundToPath, effectId)
    local template = GetEffectTemplate(data.particleName)
    if not template then
        gg.log("特效模板未找到:", data.particleName)
        return
    end
    
    local fx = template:Clone()
    if not fx then
        gg.log("特效克隆失败:", data.particleName)
        return
    end
    
    -- 设置父节点
    local parentNode
    if boundToPath and data.boundToEntity then
        -- 绑定到指定实体
        parentNode = gg.GetChild(WorkSpace, boundToPath)
        if not parentNode then
            gg.log("找不到绑定节点:", boundToPath)
            parentNode = WorkSpace["客户端特效"] or WorkSpace
        end
    else
        -- 放在客户端特效容器下
        parentNode = WorkSpace["客户端特效"] or WorkSpace
    end
    
    fx:SetParent(parentNode)
    
    -- 设置位置
    if data.boundToEntity and boundToPath then
        -- 绑定实体时使用本地位置
        fx.LocalPosition = template.LocalPosition
        fx.LocalEuler = template.LocalEuler
    elseif position then
        -- 不绑定时使用世界位置
        fx.Position = Vector3.New(position[1], position[2], position[3])
    end
    
    -- 启用特效
    fx.Visible = true
    fx.Enabled = true
    for _, child in ipairs(fx.Children) do
        child.Enabled = true
        child.Visible = true
    end
    
    -- 注册到活跃特效列表
    if effectId then
        if not activeEffects[effectId] then
            activeEffects[effectId] = {}
        end
        table.insert(activeEffects[effectId], fx)
    end
    
    -- 设置自动销毁
    if duration and duration > 0 then
        ClientScheduler.add(function()
            if fx and fx.Parent then
                fx:Destroy()
                -- 从活跃特效列表中移除
                if effectId and activeEffects[effectId] then
                    for i, effect in ipairs(activeEffects[effectId]) do
                        if effect == fx then
                            table.remove(activeEffects[effectId], i)
                            break
                        end
                    end
                    if #activeEffects[effectId] == 0 then
                        activeEffects[effectId] = nil
                    end
                end
            end
        end, duration)
    end
    
    return fx
end

-- 创建模型特效
local function CreateModelEffect(data, position, duration, boundToPath, effectId)
    local template = GetEffectTemplate(data.modelName)
    if not template then
        gg.log("模型模板未找到:", data.modelName)
        return
    end
    
    local model = template:Clone()
    if not model then
        gg.log("模型克隆失败:", data.modelName)
        return
    end
    
    -- 设置父节点
    local parentNode
    gg.log("boundToPath", boundToPath, data.boundToEntity)
    if boundToPath and data.boundToEntity then
        -- 绑定到指定实体
        parentNode = gg.GetChild(WorkSpace, boundToPath)
        if not parentNode then
            gg.log("找不到绑定节点:", boundToPath)
            parentNode = WorkSpace["客户端特效"] or WorkSpace
        end
    else
        -- 放在客户端特效容器下
        parentNode = WorkSpace["客户端特效"] or WorkSpace
    end
    
    model:SetParent(parentNode)
    
    -- 设置位置
    if data.boundToEntity and boundToPath then
        -- 绑定实体时使用本地位置
        model.LocalPosition = template.LocalPosition
        model.LocalEuler = template.LocalEuler
    elseif position then
        -- 不绑定时使用世界位置
        model.Position = Vector3.New(position[1], position[2], position[3])
    end
    
    -- 启用模型
    model.Enabled = true
    model.Visible = true
    
    -- 播放动画
    if data.animationName and data.animationName ~= "" then
        local animator = model.Animator
        if animator then
            animator:Play(data.animationName, 0, 0)
        end
    end
    
    -- 注册到活跃特效列表
    if effectId then
        if not activeEffects[effectId] then
            activeEffects[effectId] = {}
        end
        table.insert(activeEffects[effectId], model)
    end
    
    -- 设置自动销毁
    if duration and duration > 0 then
        ClientScheduler.add(function()
            if model and model.Parent then
                model:Destroy()
                -- 从活跃特效列表中移除
                if effectId and activeEffects[effectId] then
                    for i, effect in ipairs(activeEffects[effectId]) do
                        if effect == model then
                            table.remove(activeEffects[effectId], i)
                            break
                        end
                    end
                    if #activeEffects[effectId] == 0 then
                        activeEffects[effectId] = nil
                    end
                end
            end
        end, duration)
    end
    
    return model
end

-- 播放动画特效
local function PlayAnimationEffect(data, targetPlayer)
    if targetPlayer and targetPlayer.modelPlayer then
        targetPlayer.modelPlayer:SwitchState(data.animationName, data.playbackSpeed or 1.0)
    end
end

-- 播放相机震动特效
local function PlayCameraShakeEffect(data, duration)
    ClientEventManager.Publish("ShakeCamera", {
        dura = duration,
        rotShake = data.rotation,
        posShake = data.position,
        mode = data.tweenStyle,
        drop = data.dropStyle,
        frequency = data.frequency
    })
end

-- 播放音效
local function PlaySoundEffect(data, position)
    local soundData = {
        soundAssetId = data.soundAssetId,
        volume = data.volume or 1.0,
        pitch = data.pitch or 1.0,
        range = data.range,
        position = position
    }
    ClientEventManager.Publish("PlaySound", soundData)
end

-- 处理特效播放事件
local function OnPlayGraphicEffect(eventData)
    if not eventData then
        gg.log("特效事件数据为空")
        return
    end
    
    local position = eventData.position
    local duration = eventData.duration
    local effectType = eventData.type
    local effectData = eventData.data
    local effectId = eventData.effectId
    
    -- 处理重复播放
    local function playOnce()
        if effectType == "特效" then
            CreateParticleEffect(effectData, position, duration, eventData.boundToPath, effectId)
        elseif effectType == "模型" then
            CreateModelEffect(effectData, position, duration, eventData.boundToPath, effectId)
        elseif effectType == "动画" then
            local localPlayer = game.Players.LocalPlayer
            PlayAnimationEffect(effectData, localPlayer)
        elseif effectType == "相机震动" then
            PlayCameraShakeEffect(effectData, duration)
        elseif effectType == "音效" then
            PlaySoundEffect(effectData, position)
        else
            gg.log("未知特效类型:", effectType)
        end
    end
    
    -- 处理延迟和重复
    local repeatCount = eventData.repeatCount or 1
    local repeatDelay = eventData.repeatDelay or 0
    
    if repeatCount > 1 and repeatDelay > 0 then
        -- 有重复播放
        for i = 1, repeatCount do
            if i == 1 then
                playOnce()
            else
                ClientScheduler.add(playOnce, (i - 1) * repeatDelay)
            end
        end
    else
        -- 单次播放
        playOnce()
    end
end

-- 处理特效取消事件
local function OnCancelGraphicEffect(eventData)
    if not eventData or not eventData.effectId then
        gg.log("取消特效事件数据无效")
        return
    end
    
    local effectId = eventData.effectId
    local effects = activeEffects[effectId]
    
    if effects then
        -- 销毁所有相关特效
        for _, effect in ipairs(effects) do
            if effect and effect.Parent then
                effect:Destroy()
            end
        end
        -- 清理记录
        activeEffects[effectId] = nil
        gg.log("取消特效:", effectId, "共", #effects, "个对象")
    end
end

-- 初始化客户端特效管理器
function ClientGraphicManager.Init()
    -- 创建客户端特效容器
    if not WorkSpace["客户端特效"] then
        local container = SandboxNode.New("Transform", WorkSpace)
        container.Name = "客户端特效"
    end
    
    -- 注册事件监听
    ClientEventManager.Subscribe("PlayGraphicEffect", OnPlayGraphicEffect)
    ClientEventManager.Subscribe("CancelGraphicEffect", OnCancelGraphicEffect)
    
    gg.log("客户端特效管理器初始化完成")
end

-- 清理所有客户端特效
function ClientGraphicManager.ClearAllEffects()
    local container = WorkSpace["客户端特效"]
    if container then
        for _, child in ipairs(container.Children) do
            child:Destroy()
        end
    end
    
    -- 清理活跃特效记录
    for effectId, effects in pairs(activeEffects) do
        for _, effect in ipairs(effects) do
            if effect and effect.Parent then
                effect:Destroy()
            end
        end
    end
    activeEffects = {}
    
    -- 清理缓存
    nodeCache = {}
end

return ClientGraphicManager