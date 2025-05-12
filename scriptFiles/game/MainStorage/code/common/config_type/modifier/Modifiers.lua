
local MainStorage = game:GetService('MainStorage')
local ClassMgr      = require(MainStorage.code.common.ClassMgr)    ---@type ClassMgr
local Modifier = require(MainStorage.code.common.config_type.modifier.Modifier)
---@class Modifiers:Class
---@field New fun( data: table[] ):Modifiers
local _M = ClassMgr.Class("Modifiers")

function _M:OnInit(data)
    self.modifiers = {}
    for _, condition in ipairs(data) do
        table.insert(self.modifiers, Modifier.New(condition))
    end
end

function _M:Check(caster, target, param)
    for _, modifier in ipairs(self.modifiers) do
        modifier:Check(caster, target, param)
    end
end

return _M