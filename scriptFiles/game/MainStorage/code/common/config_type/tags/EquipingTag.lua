local MainStorage = game:GetService('MainStorage')
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule

---@class EquipingTag
---@field New fun(): EquipingTag
local EquipingTag = CommonModule.Class("EquipingTag")
function EquipingTag:OnInit()
    self.level = 0.0
    self.id = ""
    self.tagType = nil
    self.handlers = {}
end

return EquipingTag