
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg

--- 动画配置文件
---@class AnimationConfig
local AnimationConfig = {}
local loaded = false

local function LoadConfig()
    AnimationConfig.config ={
    ["植物"] = {
        ["初始状态"] = "idle",
        ["状态"] = {
            ["idle"] = {
                ["播放模式"] = "循环",
                ["切换"] = {
                    ["attack"] = {
                        ["混合时间"] = 0.4,
                        ["移动中"] = false,
                        ["静止中"] = false,
                        ["跳跃中"] = false,
                        ["攻击时"] = true,
                        ["死亡时"] = false
                    }
                }
            },
            ["attack"] = {
                ["播放模式"] = "单次",
                ["切换"] = {
                    ["idle"] = {
                        ["混合时间"] = 0,
                        ["移动中"] = false,
                        ["静止中"] = false,
                        ["跳跃中"] = false,
                        ["攻击时"] = false,
                        ["死亡时"] = false,
                        ["播放完成时"] = true
                    }
                }
            }
        }
    }
}loaded = true
end

---@return Animation
function AnimationConfig.Get(name)
    if not loaded then
        LoadConfig()
    end
    return AnimationConfig.config[name]
end

---@return Animation[]
function AnimationConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return AnimationConfig.config
end
return AnimationConfig
