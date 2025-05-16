
local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg


---@class ModelPlayer
---@field New fun(animator:Animator, stateConfig: table)
local ModelPlayer = ClassMgr.Class("ModelPlayer")


---@param animator Animator
function ModelPlayer:OnInit(animator, stateConfig)
    self.animator = animator
    self.stateConfig = stateConfig
    self.currentState = nil
    self:SwitchState(stateConfig["初始状态"])
    animator.GetAnimationPostNotify:Connect(function (...)
        gg.log("动画播放完毕", ...)
    end)
end

function ModelPlayer:SwitchState(stateId)
    local state = self.stateConfig["状态"][stateId]
    if not state then
        return
    end
    local fadeTime = 0
    if self.currentState then
        local transition = self.currentState["切换"][stateId]
        fadeTime = transition["混合时间"]
    end
    if fadeTime > 0 then
        self.animator:CrossFade(stateId, 0, fadeTime, 0)
    else
        self.animator:Play(stateId, 0, 0)
    end
end

return ModelPlayer