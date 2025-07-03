---@class EffectConfig
local EffectConfig = {}

-- 是否已加载配置
local loaded = false

-- 特效配置存储
EffectConfig.config = {}

---@class EffectTemplate
---@field effects table[] 特效列表
---@field description string 特效描述

-- 加载配置函数
local function LoadConfig()
    if loaded then return end

    -- ======================================
    -- 基础特效模板库
    -- ======================================
    
    -- 动画特效模板
    local AnimationTemplates = {
        ["攻击动画"] = {
            ["_type"] = "AnimationGraphic",
            ["播放动画"] = "attack",
            ["播放速度"] = 1,
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 0,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        },
        ["攻击动画_长时间"] = {
            ["_type"] = "AnimationGraphic",
            ["播放动画"] = "attack",
            ["播放速度"] = 1,
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 1,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        }
    }
    
    -- 镜头震荡模板
    local CameraShakeTemplates = {
        ["标准震荡"] = {
            ["_type"] = "CameraShakeGraphic",
            ["旋转"] = { 0, 0 },
            ["位移"] = { 0, 2, 5 },
            ["频率"] = 1,
            ["动画风格"] = "震荡",
            ["衰减风格"] = "反二次方",
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 0.5,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        }
    }
    
    -- 音效模板
    local SoundTemplates = {
        ["阳光收集"] = {
            ["_type"] = "SoundGraphic",
            ["声音资源"] = "sandboxId://soundeffect/sun[1~4].ogg",
            ["绑定实体"] = false,
            ["响度"] = 1,
            ["音调"] = 1,
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 1,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        },
        ["水泡发射"] = {
            ["_type"] = "SoundGraphic",
            ["声音资源"] = "sandboxId://soundeffect/puff水泡发射.ogg",
            ["绑定实体"] = false,
            ["响度"] = 1,
            ["音调"] = 1,
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 1,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        },
        ["毒气释放"] = {
            ["_type"] = "SoundGraphic",
            ["声音资源"] = "sandboxId://soundeffect/fume_毒气.ogg",
            ["绑定实体"] = false,
            ["响度"] = 1,
            ["音调"] = 1,
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 1,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        },
        ["撞击音效"] = {
            ["_type"] = "SoundGraphic",
            ["声音资源"] = "sandboxId://soundeffect/squash_hmm[1~2].ogg",
            ["绑定实体"] = false,
            ["响度"] = 1,
            ["音调"] = 1,
            ["目标"] = "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = 1,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        }
    }
    
    -- 粒子特效模板生成函数
    local function CreateParticleTemplate(particleName, target, bound, duration)
        return {
            ["_type"] = "ParticleGraphic",
            ["特效对象"] = particleName,
            ["特效资产"] = "",
            ["绑定实体"] = bound or false,
            ["绑定挂点"] = "",
            ["偏移"] = { 0, 0, 0 },
            ["目标"] = target or "自己",
            ["目标场景名"] = "",
            ["延迟"] = 0,
            ["持续时间"] = duration or 1,
            ["重复次数"] = 1,
            ["重复延迟"] = 0
        }
    end
    
    -- ======================================
    -- 武器类特效组合模板
    -- ======================================
    
    EffectConfig.config = {
        -- 基础射击特效
        ["射击_基础"] = {
            description = "基础射击特效：攻击动画",
            effects = {
                AnimationTemplates["攻击动画"]
            }
        },
        
        -- 豌豆射手系列特效
        ["射击_豌豆"] = {
            description = "豌豆射手开火特效：粒子+动画+击中爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/豌豆射手_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_绿色", "触发点", false, 1)
            }
        },
        
        ["射击_双头豌豆"] = {
            description = "双头豌豆开火特效：粒子+动画+击中爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/双头豌豆_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_绿色", "触发点", false, 1)
            }
        },
        
        ["射击_三头豌豆"] = {
            description = "三头豌豆开火特效：粒子+动画+击中爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/三头豌豆_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_绿色", "触发点", false, 1)
            }
        },
        
        -- 高速射手特效
        ["射击_高速"] = {
            description = "高速射手开火特效：粒子+动画+击中爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/高速射手_开火", "自己", true, 0),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_绿色", "触发点", false, 1)
            }
        },
        
        -- 加特林系列特效
        ["射击_寒冰加特林"] = {
            description = "寒冰加特林开火特效：镜头震荡+粒子+动画",
            effects = {
                CameraShakeTemplates["标准震荡"],
                CreateParticleTemplate("特效/开火/寒冰加特林_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"]
            }
        },
        
        ["射击_高速加特林"] = {
            description = "高速加特林开火特效：粒子+动画+击中爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/高速加特林_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_绿色", "触发点", false, 1)
            }
        },
        
        -- 火焰射手特效
        ["射击_火焰"] = {
            description = "火焰射手开火特效：粒子+动画+火球爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/火焰射手_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_黄色_火球炸开", "触发点", false, 1)
            }
        },
        
        -- 寒冰射手特效
        ["射击_寒冰"] = {
            description = "寒冰射手开火特效：粒子+动画+冰花溅射",
            effects = {
                CreateParticleTemplate("特效/开火/寒冰射手_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/溅射_蓝色_粒子水花散开", "触发点", false, 1)
            }
        },
        
        -- 椰子炮特效
        ["射击_椰子炮"] = {
            description = "椰子炮开火特效：粒子+动画+金色旋风爆炸",
            effects = {
                CreateParticleTemplate("特效/开火/椰子炮_开火", "自己", true, 0),
                AnimationTemplates["攻击动画_长时间"],
                CreateParticleTemplate("特效/击中/爆炸_金色_带旋风", "触发点", false, 1)
            }
        },
        
        -- 仙人掌特效
        ["射击_仙人掌"] = {
            description = "仙人掌开火特效：粒子+动画+金色小型爆炸",
            effects = {
                CreateParticleTemplate("开火/开火/仙人掌_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/爆炸_金色_带橘色小型", "触发点", false, 1)
            }
        },
        
        -- 特殊射击特效
        ["射击_喷射"] = {
            description = "喷射攻击特效：粒子+动画+音效",
            effects = {
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/开火/喷射_紫色", "触发点", false, 1),
                SoundTemplates["水泡发射"]
            }
        },
        
        -- ======================================
        -- 前摇特效模板
        -- ======================================
        
        ["前摇_标准震荡"] = {
            description = "标准前摇震荡特效",
            effects = {
                CameraShakeTemplates["标准震荡"]
            }
        },
        
        ["前摇_毒气"] = {
            description = "毒气类技能前摇：震荡+动画+音效",
            effects = {
                CameraShakeTemplates["标准震荡"],
                AnimationTemplates["攻击动画_长时间"],
                SoundTemplates["毒气释放"]
            }
        },
        
        ["前摇_豌豆蓄力"] = {
            description = "豌豆射手蓄力前摇：震荡+粒子+动画",
            effects = {
                CameraShakeTemplates["标准震荡"],
                CreateParticleTemplate("特效/开火/豌豆射手_开火", "自己", true, 1),
                AnimationTemplates["攻击动画"]
            }
        },
        
        -- ======================================
        -- 生产类特效模板
        -- ======================================
        
        ["生产_阳光获取"] = {
            description = "阳光获取特效：收集音效",
            effects = {
                SoundTemplates["阳光收集"]
            }
        },
        
        -- ======================================
        -- 撞击类特效模板
        -- ======================================
        
        ["撞击_绿色溅射"] = {
            description = "绿色撞击溅射特效：动画+粒子+音效",
            effects = {
                AnimationTemplates["攻击动画"],
                CreateParticleTemplate("特效/击中/溅射_绿色_带烟雾和叶片飞开", "触发点", false, 1),
                SoundTemplates["撞击音效"]
            }
        },
        
        -- ======================================
        -- 爆炸类特效模板
        -- ======================================
        
        ["爆炸_绿色"] = {
            description = "绿色爆炸特效",
            effects = {
                CreateParticleTemplate("特效/击中/爆炸_绿色", "触发点", false, 1)
            }
        },
        
        ["爆炸_黄色火球"] = {
            description = "黄色火球爆炸特效",
            effects = {
                CreateParticleTemplate("特效/击中/爆炸_黄色_火球炸开", "触发点", false, 1)
            }
        },
        
        ["爆炸_金色旋风"] = {
            description = "金色旋风爆炸特效",
            effects = {
                CreateParticleTemplate("特效/击中/爆炸_金色_带旋风", "触发点", false, 1)
            }
        },
        
        ["溅射_蓝色水花"] = {
            description = "蓝色水花溅射特效",
            effects = {
                CreateParticleTemplate("特效/击中/溅射_蓝色_粒子水花散开", "触发点", false, 1)
            }
        }
    }
    
    loaded = true
end

---@param effectName string 特效名称
---@return table[]|nil 特效配置数组
function EffectConfig.Get(effectName)
    if not loaded then
        LoadConfig()
    end
    
    local template = EffectConfig.config[effectName]
    if template then
        return template.effects
    end
    
    return nil
end

---@param effectName string 特效名称
---@return string|nil 特效描述
function EffectConfig.GetDescription(effectName)
    if not loaded then
        LoadConfig()
    end
    
    local template = EffectConfig.config[effectName]
    if template then
        return template.description
    end
    
    return nil
end

---@return table 所有特效配置
function EffectConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return EffectConfig.config
end

---@return string[] 所有特效名称列表
function EffectConfig.GetNames()
    if not loaded then
        LoadConfig()
    end
    
    local names = {}
    for name, _ in pairs(EffectConfig.config) do
        table.insert(names, name)
    end
    return names
end

return EffectConfig 