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

---@class NpcInteractionEvent : SEvent
---@field player Player 交互的玩家
---@field npc Npc 被交互的NPC

---@class SpellCastEvent : SEvent
---@field caster Entity 施法者
---@field target Entity|Vector3 目标
---@field spell Spell 魔法
---@field param CastParam 参数
---@field cancelled boolean 是否取消释放