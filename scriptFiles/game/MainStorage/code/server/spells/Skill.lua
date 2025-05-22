
local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig

---@class Skill : Class
---@field player Player 玩家实例
local Skill = ClassMgr.Class("Skill")

function Skill:OnInit( player, data )
    gg.log("Skill:OnInit", player, data)
    self.player = player
    self.skillType = SkillTypeConfig.Get(data["skill"]) ---@type SkillType
    self.level = data["level"] or 1
    self.equipSlot = data["slot"] or 0
end

return Skill