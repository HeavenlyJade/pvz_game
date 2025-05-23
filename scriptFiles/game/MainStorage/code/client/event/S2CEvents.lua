---@class SerializedQuest
---@field name string
---@field description string
---@field count number
---@field countMax number

---@class QuestsUpdate : S2CEvent
---@field quests table<number, SerializedQuest>

---@class NPCInteractionOption
---@field npcName string 选项文本
---@field icon string 图标
---@field npcId string 选项类型 (对话/交易/任务等)

---@class NPCInteractionUpdate : S2CEvent
---@field interactOptions NPCInteractionOption[] 交互选项列表

---@class EquipSkillCooldownUpdate : S2CEvent
---@field skillId string
---@field index number
---@field cooldown number