local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler

---@class Graphic:Class
local Graphic = ClassMgr.Class("Graphic")

-- 从模板创建新的特效对象
local function CreateParticle(particleName)
    local fxTemplate = game.WorkSpace["特效"][particleName]
    if fxTemplate then
        return fxTemplate:Clone()
    end
    return nil
end

function Graphic:OnInit( data )
    self.offset = data["偏移"] or Vector3.New(0,0,0)
    self.targeter = data["目标"]
    self.targeterPath = data["目标场景名"]
    self.delay = data["延迟"] or 0
    self.duration = data["持续时间"] or 0
    self.repeatCount = data["重复次数"] or 1
    self.repeatDelay = data["重复延迟"] or 0
end

function Graphic:GetTarget(caster, target)
    if self.targeter == "目标" then
        return target
    elseif self.targeter == "自己" then
        return caster
    else
        local scene = target.scene ---@type Scene
        return scene.node2Entity[scene:Get(self.targeterPath)]
    end
end

---@param caster Entity
---@param target Entity
---@param param CastParam
function Graphic:PlayAt(caster, target, param)
    if self.delay > 0 then
        ServerScheduler.add(function ()
            self:PlayAtReal(caster, target, param)
        end, self.delay)
    else
        self:PlayAtReal(caster, target, param)
    end
end

function Graphic:PlayAtReal(caster, target, param)
end

---@class ParticleGraphic:Graphic
local ParticleGraphic = ClassMgr.Class("ParticleGraphic", Graphic)
function ParticleGraphic:OnInit( data )
    Graphic.OnInit(self, data)
    self.particleName = data["特效对象"]
    self.particleAssetId = data["特效资产"] or nil
    self.boundToEntity = data["绑定实体"] or false
    self.boundToBone = data["绑定挂点"] or nil
end

---@return fun()[]|nil 调用后取消特效
function ParticleGraphic:PlayAtReal(caster, target, param)
    local scene = target.scene
    local container
    if self.boundToEntity and target.isEntity then
        container = target.actor
        print(string.format("[特效] %s: 绑定到实体 %s", self.particleName, target.name))
    else
        container = game.WorkSpace["Ground"][scene.name]["世界特效"]
        print(string.format("[特效] %s: 绑定到世界特效容器 %s", self.particleName, scene.name))
    end
    
    if not container then
        print(string.format("[特效] %s: 找不到容器", self.particleName))
        return nil
    end
    
    local isCancelled = false
    local cancelFunctions = {}
    local currentRepeat = 0
    
    local function playEffect()
        if isCancelled then 
            print(string.format("[特效] %s: 已取消播放", self.particleName))
            return 
        end
        
        -- 创建新的特效对象
        local fx = CreateParticle(self.particleName)
        if not fx then 
            print(string.format("[特效] %s: 创建特效对象失败", self.particleName))
            return 
        end
        
        -- 设置特效位置和父节点
        fx:SetParent(container)
        if not self.boundToEntity then
            fx.LocalPosition = target:GetPosition()
        end
        fx.Enabled = true
        print(string.format("[特效] %s: 第%d次播放", self.particleName, currentRepeat + 1))
        
        -- 为每个特效创建独立的取消函数
        local fxCancel = function()
            if fx.Enabled then
                fx.Enabled = false
                fx:Destroy()
                print(string.format("[特效] %s: 第%d次播放被取消并销毁", self.particleName, currentRepeat + 1))
            end
        end
        table.insert(cancelFunctions, fxCancel)
        
        currentRepeat = currentRepeat + 1
        
        -- 设置持续时间
        if self.duration > 0 then
            print(string.format("[特效] %s: 设置持续时间 %.1f秒", self.particleName, self.duration))
            ServerScheduler.add(function()
                if not isCancelled then
                    fxCancel()
                end
            end, self.duration)
        end
        
        -- 设置下一次重复
        if currentRepeat < self.repeatCount and self.repeatDelay > 0 then
            print(string.format("[特效] %s: 设置下次重复延迟 %.1f秒", self.particleName, self.repeatDelay))
            ServerScheduler.add(playEffect, self.repeatDelay)
        end
    end
    
    -- 启动第一次播放
    print(string.format("[特效] %s: 开始播放 (重复次数: %d, 持续时间: %.1f, 重复延迟: %.1f)", 
        self.particleName, self.repeatCount, self.duration, self.repeatDelay))
    playEffect()
    
    return cancelFunctions
end

---@class AnimationGraphic:Graphic
local AnimationGraphic = ClassMgr.Class("AnimationGraphic", Graphic)
function AnimationGraphic:OnInit( data )
    Graphic.OnInit(self, data)
    self.animationName = data["播放动画"]
    self.playbackSpeed = data["播放速度"]
end

function AnimationGraphic:PlayAtReal(caster, target, param)
    if target.modelPlayer then
        target.modelPlayer:SwitchState(self.animationName, self.playbackSpeed)
    end
end

---@class Graphics
---@field ParticleGraphic ParticleGraphic
---@field AnimationGraphic AnimationGraphic
local loaders = {
    ParticleGraphic = ParticleGraphic,
    AnimationGraphic = AnimationGraphic,
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

-- local MainStorage = game:GetService('MainStorage')
-- local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
-- local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler

-- ---@class Graphic:Class
-- local Graphic = ClassMgr.Class("Graphic")
-- local graphicPool = {}

-- -- 特效对象池
-- local particlePools = {} -- 按特效名称分类的对象池

-- -- 从对象池获取特效对象
-- local function GetParticleFromPool(particleName)
--     if not particlePools[particleName] then
--         particlePools[particleName] = {}
--     end
    
--     local pool = particlePools[particleName]
--     -- 查找可用的特效对象
--     for _, fx in ipairs(pool) do
--         if not fx.Enabled then
--             return fx
--         end
--     end
    
--     -- 如果没有可用的，创建新的
--     local fxTemplate = game.WorkSpace["特效"][particleName]
--     if fxTemplate then
--         local newFx = fxTemplate:Clone()
--         table.insert(pool, newFx)
--         return newFx
--     end
    
--     return nil
-- end


-- function Graphic:OnInit( data )
--     self.offset = data["偏移"] or Vector3.New(0,0,0)
--     self.targeter = data["目标"]
--     self.targeterPath = data["目标场景名"]
--     self.delay = data["延迟"] or 0
--     self.duration = data["持续时间"] or 0
--     self.repeatCount = data["重复次数"] or 1
--     self.repeatDelay = data["重复延迟"] or 0
-- end

-- function Graphic:GetTarget(caster, target)
--     if self.targeter == "目标" then
--         return target
--     elseif self.targeter == "自己" then
--         return caster
--     else
--         local scene = target.scene ---@type Scene
--         return scene.node2Entity[scene:Get(self.targeterPath)]
--     end
-- end

-- ---@param caster Entity
-- ---@param target Entity
-- ---@param param CastParam
-- function Graphic:PlayAt(caster, target, param)
--     if self.delay > 0 then
--         ServerScheduler.add(function ()
--             self:PlayAtReal(caster, target, param)
--         end, self.delay )
--     else
--         self:PlayAtReal(caster, target, param)
--     end
-- end

-- function Graphic:PlayAtReal(caster, target, param)
-- end

-- ---@class ParticleGraphic:Graphic
-- local ParticleGraphic = ClassMgr.Class("ParticleGraphic", Graphic)
-- function ParticleGraphic:OnInit( data )
--     Graphic.OnInit(self, data)
--     self.particleName = data["特效对象"]
--     self.particleAssetId = data["特效资产"] or nil
--     self.boundToEntity = data["绑定实体"] or false
--     self.boundToBone = data["绑定挂点"] or nil
-- end

-- ---@return fun()[]|nil 调用后取消特效
-- function ParticleGraphic:PlayAtReal(caster, target, param)
--     local scene = target.scene
--     local container
--     if self.boundToEntity and target.isEntity then
--         container = target.actor
--         print(string.format("[特效] %s: 绑定到实体 %s", self.particleName, target.name))
--     else
--         container = game.WorkSpace["Ground"][scene.name]["世界特效"]
--         print(string.format("[特效] %s: 绑定到世界特效容器 %s", self.particleName, scene.name))
--     end
    
--     if not container then
--         print(string.format("[特效] %s: 找不到容器", self.particleName))
--         return nil
--     end
    
--     local isCancelled = false
--     local cancelFunctions = {}
--     local currentRepeat = 0
    
--     local function playEffect()
--         if isCancelled then 
--             print(string.format("[特效] %s: 已取消播放", self.particleName))
--             return 
--         end
        
--         -- 每次重复都获取新的特效对象
--         local fx = GetParticleFromPool(self.particleName)
--         if not fx then 
--             print(string.format("[特效] %s: 获取特效对象失败", self.particleName))
--             return 
--         end
        
--         -- 设置特效位置和父节点
--         fx:SetParent(container)
--         fx.Enabled = true
--         print(string.format("[特效] %s: 第%d次播放", self.particleName, currentRepeat + 1))
        
--         -- 为每个特效创建独立的取消函数
--         local fxCancel = function()
--             if fx.Enabled then
--                 fx.Enabled = false
--                 print(string.format("[特效] %s: 第%d次播放被取消", self.particleName, currentRepeat + 1))
--             end
--         end
--         table.insert(cancelFunctions, fxCancel)
        
--         currentRepeat = currentRepeat + 1
        
--         -- 设置持续时间
--         if self.duration > 0 then
--             print(string.format("[特效] %s: 设置持续时间 %.1f秒", self.particleName, self.duration))
--             ServerScheduler.add(function()
--                 if not isCancelled then
--                     fxCancel()
--                 end
--             end, self.duration, 0, true)
--         end
        
--         -- 设置下一次重复
--         if currentRepeat < self.repeatCount and self.repeatDelay > 0 then
--             print(string.format("[特效] %s: 设置下次重复延迟 %.1f秒", self.particleName, self.repeatDelay))
--             ServerScheduler.add(playEffect, self.repeatDelay, 0, true)
--         end
--     end
    
--     -- 启动第一次播放
--     print(string.format("[特效] %s: 开始播放 (重复次数: %d, 持续时间: %.1f, 重复延迟: %.1f)", 
--         self.particleName, self.repeatCount, self.duration, self.repeatDelay))
--     playEffect()
    
--     return cancelFunctions
-- end

-- ---@class AnimationGraphic:Graphic
-- local AnimationGraphic = ClassMgr.Class("AnimationGraphic", Graphic)
-- function AnimationGraphic:OnInit( data )
--     Graphic.OnInit(self, data)
--     self.animationName = data["播放动画"]
--     self.playbackSpeed = data["播放速度"]
-- end

-- function AnimationGraphic:PlayAtReal(caster, target, param)
--     if target.modelPlayer then
--         target.modelPlayer:SwitchState(self.animationName, self.playbackSpeed)
--     end
-- end

-- ---@class Graphics
-- ---@field ParticleGraphic ParticleGraphic
-- ---@field AnimationGraphic AnimationGraphic
-- local loaders = {
--     ParticleGraphic = ParticleGraphic,
--     AnimationGraphic = AnimationGraphic,
-- }

-- --- 加载特效配置
-- ---@param effectsData table[]|nil 特效配置数组
-- ---@return Graphic[] 特效实例数组
-- local function Load(effectsData)
--     if not effectsData then return {} end
    
--     local effects = {}
--     for _, effectData in ipairs(effectsData) do
--         if effectData["_type"] then
--             local effectClass = loaders[effectData["_type"]]
--             if effectClass then
--                 local effect = effectClass.New(effectData)
--                 table.insert(effects, effect)
--             end
--         end
--     end
--     return effects
-- end

-- loaders["Load"] = Load
-- return loaders