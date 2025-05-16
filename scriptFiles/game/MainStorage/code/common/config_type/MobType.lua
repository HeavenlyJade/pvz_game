local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Monster     = require(MainStorage.code.server.entity_types.Monster) ---@type Monster
local Vector3      = Vector3
local gg           = require(MainStorage.code.common.MGlobal) ---@type gg

-- StatType 类
---@class MobType:Class
---@field New fun( data:table ):MobType
local MobType      = ClassMgr.Class("MobType")
function MobType:OnInit(data)
    self.data = data
end

---@param position Vector3
---@param scene Scene
---@return Monster
function MobType:Spawn(position, level, scene)
    local monster_ = Monster.New({ ---@type Monster
        position = position,
        mobType  = self,
        level = level,
    })
    monster_:CreateModel(scene)
    monster_:ChangeScene(scene)
    scene.monsters[monster_.uuid] = monster_
    scene.node2Entity[monster_.actor] = monster_
    return monster_
end

---@param statType string
---@param level number
---@return number
function MobType:GetStatAtLevel(statType, level)
    if not self.data["属性公式"][statType] then
        return 0
    end

    local expr = self.data["属性公式"][statType]:gsub("LVL", tostring(level))
    if not expr:match("^[%d%+%-%*%/%%%^%(%)(%.)%s]+$") then
        print(string.format("怪物%s的属性%s包含非法字符: %s", self["名字"], statType, expr))
        return 0
    end

    local result = gg.eval(expr)
    print("calc result:", expr, result)

    return result
end

return MobType
