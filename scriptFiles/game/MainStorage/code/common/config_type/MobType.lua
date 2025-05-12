local MainStorage  = game:GetService('MainStorage')
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule
local CMonster     = require(MainStorage.code.server.entity_types.CMonster) ---@type CMonster
local Vector3      = Vector3
local gg           = require(MainStorage.code.common.MGlobal) ---@type gg

---@class Vector3
---@field x number
---@field y number
---@field z number

-- StatType 类
---@class MobType:Class
---@field New fun( data:table ):MobType
local MobType      = CommonModule.Class("MobType")
function MobType:OnInit(data)
    self.data = data
end

---@param position Vector3
---@param scene CScene
---@return CMonster
function MobType:Spawn(position, level, scene)
    local monster_ = CMonster.New({ ---@type CMonster
        position = position,
        mobType  = self,
        level = level
    })
    monster_:createModel()
    monster_.scene = scene
    scene.monsters[monster_.uuid] = monster_
    return monster_
end

---@param statType string
---@param level number
---@return number
function MobType:GetStatAtLevel(statType, level)
    if self.data["属性公式"][statType] then
        local expr = self.data["属性公式"][statType]:gsub("LVL", tostring(level))
        if not expr:match("^[%d%+%-%*%/%%%^%(%)(%.)%s]+$") then
            print(string.format("怪物%s的属性%s包含非法字符: %s", self["名字"], statType, expr))
            return 0
        end
    
        local func, err = load("return " .. expr)
        if not func then
            print(string.format("怪物%s的属性%s表达式语法错误: %s", self["名字"], statType, expr))
            return 0
        end
    
        local success, result = pcall(func)
        if not success then
            print(string.format("怪物%s的属性%s计算错误: %s", self["名字"], statType, result))
            return 0
        end
        return result
    end
    return 0
end

return MobType
