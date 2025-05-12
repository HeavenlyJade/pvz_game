local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr

---@class EquipingTag
---@field New fun(): EquipingTag
local EquipingTag = ClassMgr.Class("EquipingTag")
function EquipingTag:OnInit()
    self.level = 0.0
    self.id = ""
    self.tagType = nil
    self.handlers = {}
end

return EquipingTag