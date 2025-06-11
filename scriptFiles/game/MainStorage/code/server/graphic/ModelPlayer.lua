local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler


---@class ModelPlayer
---@field New fun(animator:Animator, stateConfig: table)
local ModelPlayer = ClassMgr.Class("ModelPlayer")
local modelAnimCache = {}
local modelSizeCache = {}

function ModelPlayer.FetchModelSize(actor, getCallback)
    local modelId = actor.ModelId
    if not modelSizeCache[modelId] then
        ServerScheduler.add(function ()
            local pos = gg.Vec3.new(actor.Position)
            local closestPlayer = pos:FindClosestPlayer(1000)
            if closestPlayer then
                local path = gg.GetFullPath(actor)
                closestPlayer:SendEvent("FetchModelSize", {
                    path = path,
                }, function (data)
                    modelAnimCache[modelId] = data
                    getCallback(data)
                end)
            end
        end, 2)
    else
        getCallback(modelAnimCache[modelId])
    end
end

---@param animator Animator
function ModelPlayer:OnInit(name, animator, stateConfig)
    self.name = name
    self.animator = animator
    self.finishTask = nil
    self.stateConfig = stateConfig
    self.currentState = nil ---@type table
    self.animationFinished = true
    self.isMoving = false
    self:SwitchState(stateConfig["初始状态"])
    self.animName = animator.ControllerAsset
    if not modelAnimCache[self.animName] then
        ServerScheduler.add(function ()
            self:FetchModelAnim()
        end, 2)
    end
end

function ModelPlayer:FetchModelAnim()
    if not modelAnimCache[self.animName] and self.animator:IsValid() and self.animator.Parent then
        local states = {}
        for stateId, _ in pairs(self.stateConfig["状态"]) do
            states[stateId] = 0
        end
        local pos = gg.Vec3.new(self.animator.Parent.Position)
        local closestPlayer = pos:FindClosestPlayer(1000)
        if closestPlayer then
            local path = gg.GetFullPath(self.animator)
            closestPlayer:SendEvent("FetchAnimDuration", {
                path = path,
                states = states
            }, function (data)
                modelAnimCache[self.animName] = data
            end)
        end
    end
end


---@private
function ModelPlayer:GetTransition()
    if not self.currentState then
        return
    end
    local transitions = self.currentState["切换"]
    if not transitions then
        return
    end
    return transitions
end

---@private
function ModelPlayer:CanTransitTo(transition)
    if transition["已播放完成"] and not self.animationFinished then
        return false
    elseif transition["移动中"] and not self.isMoving then
        return false
    elseif transition["静止中"] and self.isMoving then
        return false
    end
    return true
end

---@private
---@param key string
---@return number
function ModelPlayer:PlayTransition(key)
    local transitions = self:GetTransition()
    if not transitions then
        return 0
    end
    local validAnims = {}
    -- gg.log("PlayTransition", key, transitions)
    for animId, transition in pairs(transitions) do
        local canSwitch = true
        if transition["时机"] ~= key then
            -- gg.log("PlayTransition REJECT 时机", key, transition["时机"])
            canSwitch = false
        else
            if not self:CanTransitTo(transition) then
                -- gg.log("PlayTransition CanTransitTo 时机", key, transition, self.isMoving, self.animationFinished)
                canSwitch = false
            end
        end
        
        if canSwitch then
            table.insert(validAnims, animId)
        end
    end
    if #validAnims > 0 then
        local randomAnim = validAnims[math.random(1, #validAnims)]
        return self:SwitchState(randomAnim)
    end
    return 0
end

function ModelPlayer:OnStand()
    self.isMoving = false
    -- print("OnIdle")
    return self:PlayTransition("无")
end
function ModelPlayer:OnWalk()
    self.isMoving = true
    -- print("OnWalk")
    return self:PlayTransition("无")
end
function ModelPlayer:OnAttack()
    -- print("OnAttack")
    return self:PlayTransition("攻击时")
end
function ModelPlayer:OnDead()
    -- print("OnDead")
    return self:PlayTransition("死亡时")
end

---@param stateId string
---@param speed? number = 1
---@return number
function ModelPlayer:SwitchState(stateId, speed)
    -- print("SwitchState", stateId, speed)
    if self.finishTask then
        self.finishTask = ServerScheduler.cancel(self.finishTask)
    end
    speed = speed or 1
    local state = self.stateConfig["状态"][stateId]
    if not state then
        return 0
    end
    local fadeTime = 0
    if self.currentState then
        local transition = self.currentState["切换"][stateId]
        fadeTime = transition and transition["混合时间"] or 0
    end
    local playMode = state["播放模式"]
    self.animationFinished = false
    self.animator.Speed = speed
    if fadeTime > 0 then
        self.animator:CrossFade(stateId, 0, fadeTime, 0)
    else
        self.animator:Play(stateId, 0, 0)
    end
    local playTime = 0
    if playMode == "单次" then
        playTime = 1
        if not state[self.animName] then
            self:FetchModelAnim()
        else
            playTime = state[self.animName][stateId]
        end
        if playTime and playTime > 0 then
            self.finishTask = ServerScheduler.add(function ()
                self.animationFinished = true
                self:PlayTransition("无")
            end, playTime - 0.1)
        end
    end
    self.currentState = state
    return playTime
end

return ModelPlayer