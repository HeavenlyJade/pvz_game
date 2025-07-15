local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers


---@class NpcData
---@field 名字 string
---@field 场景 string
---@field 节点 string
---@field 互动条件 table
---@field 互动指令 string[]

--- NPC配置文件
---@class NpcConfig
local NpcConfig = {}
local loaded = false

local function LoadConfig()
    NpcConfig.config ={
    ["戴夫商店"] = {
        ["名字"] = "戴夫商店",
        ["显示名"] = " ",
        ["场景"] = "g0",
        ["节点名"] = "戴夫商店",
        ["互动指令"] = {
            [[viewUI {"界面ID":"道具"} ]],
            [[graphic {"特效":[{"_type":"SoundGraphic","声音资源":"sandboxId://soundeffect/crazydaveshort1_人物音效_外币巴布.ogg","绑定实体":false,"响度":1.0,"音调":1.0,"距离":[600,6000],"仅播放给相关者":true,"目标":"自己","目标场景名":"","延迟":0.0,"持续时间":1.0,"重复次数":1,"重复延迟":0.0}]} ]]
        },
        ["额外互动距离"] = {
            100,
            100,
            200
        },
        ["看向附近玩家"] = false,
        ["名字尺寸"] = 1
    },
    ["防御僵尸 1"] = {
        ["名字"] = "防御僵尸 1",
        ["显示名"] = " ",
        ["场景"] = "g0",
        ["节点名"] = "抵御僵尸",
        ["互动指令"] = {
            [[viewUI {"界面ID":"第一章"} ]]
        },
        ["额外互动距离"] = {
            0,
            100,
            0
        },
        ["看向附近玩家"] = false,
        ["名字尺寸"] = 2
    },
    ["防御僵尸"] = {
        ["名字"] = "防御僵尸",
        ["显示名"] = " ",
        ["场景"] = "g0",
        ["节点名"] = "抵御僵尸1",
        ["互动指令"] = {
            [[viewUI {"界面ID":"第一章"} ]]
        },
        ["额外互动距离"] = {
            0,
            100,
            0
        },
        ["看向附近玩家"] = false,
        ["名字尺寸"] = 2
    },
    ["抽卡机"] = {
        ["名字"] = "抽卡机",
        ["显示名"] = " ",
        ["场景"] = "g0",
        ["节点名"] = "抽卡机",
        ["互动指令"] = {
            [[viewUI {"界面ID":"抽卡页面"} ]]
        },
        ["额外互动距离"] = {
            100,
            100,
            100
        },
        ["看向附近玩家"] = false,
        ["名字尺寸"] = 1
    }
}loaded = true
end

---@param npcName string
---@return Npc
function NpcConfig.Get(npcName)
    if not loaded then
        LoadConfig()
    end
    return NpcConfig.config[npcName]
end

---@return Npc[]
function NpcConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return NpcConfig.config
end
return NpcConfig
