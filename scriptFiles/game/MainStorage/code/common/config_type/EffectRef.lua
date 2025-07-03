---@class EffectRef
local EffectRef = {}

---@class EffectRefData
---@field 特效模板 string|nil 引用的特效模板名称（新的统一特效系统）
---@field 自定义特效 table[]|nil 自定义特效配置（传统方式）
---@field 混合特效 table|nil 混合配置，包含模板和自定义特效

--- 创建特效引用实例
---@param data EffectRefData|string 特效引用数据或特效模板名称
---@return EffectRef
function EffectRef.New(data)
    local instance = {}
    setmetatable(instance, {__index = EffectRef})
    
    if type(data) == "string" then
        -- 如果直接传入字符串，作为特效模板名称
        instance.templateName = data
        instance.customEffects = nil
    elseif type(data) == "table" then
        if data["特效模板"] then
            -- 使用特效模板
            instance.templateName = data["特效模板"]
            instance.customEffects = data["自定义特效"]
        elseif data["混合特效"] then
            -- 混合模式：模板 + 自定义
            instance.templateName = data["混合特效"]["模板"]
            instance.customEffects = data["混合特效"]["自定义"]
        else
            -- 传统的自定义特效数组
            instance.templateName = nil
            instance.customEffects = data
        end
    else
        instance.templateName = nil
        instance.customEffects = nil
    end
    
    return instance
end

--- 获取特效配置
---@return table[]|string|nil 返回特效配置数组或模板名称
function EffectRef:GetEffects()
    if self.templateName and self.customEffects then
        -- 混合模式：模板 + 自定义
        return {
            template = self.templateName,
            custom = self.customEffects
        }
    elseif self.templateName then
        -- 仅使用模板
        return self.templateName
    else
        -- 仅使用自定义特效
        return self.customEffects
    end
end

--- 检查是否有有效的特效配置
---@return boolean
function EffectRef:HasEffects()
    return self.templateName ~= nil or (self.customEffects ~= nil and #self.customEffects > 0)
end

--- 获取特效描述
---@return string
function EffectRef:GetDescription()
    if self.templateName then
        local EffectConfig = require(game:GetService('MainStorage').code.common.config.EffectConfig)
        local desc = EffectConfig.GetDescription(self.templateName)
        if desc then
            if self.customEffects then
                return desc .. " + 自定义特效"
            else
                return desc
            end
        else
            return "特效模板: " .. self.templateName
        end
    elseif self.customEffects then
        return "自定义特效 (" .. #self.customEffects .. " 个)"
    else
        return "无特效"
    end
end

--- 便捷创建函数
EffectRef.Template = function(templateName)
    return EffectRef.New(templateName)
end

EffectRef.Custom = function(effects)
    return EffectRef.New(effects)
end

EffectRef.Mix = function(templateName, customEffects)
    return EffectRef.New({
        ["混合特效"] = {
            ["模板"] = templateName,
            ["自定义"] = customEffects
        }
    })
end

return EffectRef 