

---@class MobDeadEvent : SEvent
---@field mob Monster 死亡的怪物

---@class PlayerDeadEvent : SEvent
---@field player Player 死亡的玩家

---@class PreBattleEvent : SEvent
---@field battle Battle 战斗实例

---@class PostBattleEvent : SEvent
---@field battle Battle 战斗实例

---@class RefreshEquipmentEvent : SEvent
---@field creature Entity 需要刷新装备的生物

---@class GetVariableEvent : SEvent
---@field creature Entity 获取变量的生物
---@field category string 变量类别
---@field variable string 变量名
---@field value number 变量值