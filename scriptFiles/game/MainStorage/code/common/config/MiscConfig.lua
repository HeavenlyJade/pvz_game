
local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

--- MiscConfig配置文件
---@class MiscConfig
local MiscConfig = {}
local loaded = false

local function LoadConfig()
    MiscConfig.config ={
    ["总控"] = {
        ["ID"] = "总控",
        ["菜单指令"] = {
            ["每日奖励_2"] = {
                ["菜单按钮名"] = "每日奖励_2",
                ["按键"] = "O",
                ["指令"] = {
                    [[viewUI {"界面ID":"在线奖励"}]]
                }
            },
            ["月卡奖励_3"] = {
                ["菜单按钮名"] = "月卡奖励_3",
                ["按键"] = "P",
                ["指令"] = {
                    [[viewUI {"界面ID":"月卡"}]]
                }
            }
        },
        ["装备类型"] = {
            ["主卡"] = {
                ["名字"] = "主卡",
                ["指令"] = {
                    ["1"] = "主卡"
                }
            },
            ["副卡"] = {
                ["名字"] = "副卡",
                ["指令"] = {
                    ["2"] = "副卡1",
                    ["3"] = "副卡2",
                    ["4"] = "副卡3",
                    ["5"] = "副卡4"
                }
            }
        },
        ["每日刷新指令"] = {
            [[title {"信息":"每日刷新"}]]
        },
        ["每周刷新指令"] = {
            [[title {"信息":"每周刷新"}]]
        },
        ["每月刷新指令"] = {
            [[title {"信息":"每月刷新"}]]
        }
    }
}loaded = true
end

---@return table
function MiscConfig.Get(name)
    if not loaded then
        LoadConfig()
    end
    return MiscConfig.config[name]
end

---@return table[]
function MiscConfig.GetAll()
    if not loaded then
        LoadConfig()
    end
    return MiscConfig.config
end

gg.log("MiscConfig", gg.isServer)
if gg.isServer then
    ServerEventManager.Subscribe("ClickMenu", function (evt)
        local menuConfig = MiscConfig.Get("总控")["菜单指令"][evt.menu]
        if not menuConfig then
            evt.player:SendHoverText("尚未开放，敬请期待！")
            return
        end
        evt.player:ExecuteCommands(menuConfig["指令"])
    end)
end
return MiscConfig
