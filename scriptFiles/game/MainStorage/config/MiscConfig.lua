local MainStorage = game:GetService('MainStorage')
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
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
            ["商城购买_1"] = {
                ["菜单按钮名"] = "商城购买_1",
                ["按键"] = "P",
                ["指令"] = {
                    [[viewUI {"界面ID":"道具"} ]]
                }
            },
            ["每日奖励_2"] = {
                ["菜单按钮名"] = "每日奖励_2",
                ["按键"] = "O",
                ["指令"] = {
                    [[viewUI {"界面ID":"在线奖励"} ]]
                }
            },
            ["月卡奖励_3"] = {
                ["菜单按钮名"] = "月卡奖励_3",
                ["按键"] = "I",
                ["指令"] = {
                    [[viewUI {"界面ID":"月卡"} ]]
                }
            },
            ["排行榜_5"] = {
                ["菜单按钮名"] = "排行榜_5",
                ["按键"] = "U",
                ["指令"] = {
                    [[viewUI {"界面ID":"排行榜页面","参数":{}} ]]
                }
            },
            ["卡片抽取_4"] = {
                ["菜单按钮名"] = "卡片抽取_4",
                ["按键"] = "Y",
                ["指令"] = {
                    [[viewUI {"界面ID":"抽卡页面"} ]]
                }
            },
            ["宠物背包_6"] = {
                ["菜单按钮名"] = "宠物背包_6",
                ["按键"] = "T",
                ["指令"] = {
                    [[viewUI {"界面ID":"宠物页面"} ]]
                }
            },

            --
            ["商城购买_货币1"] = {
                ["菜单按钮名"] = "商城购买_货币1",
                ["按键"] = "",
                ["指令"] = {
                    [[viewUI {"界面ID":"水晶","参数":{"商品名":"阳光补给包"}} ]]
                }
            },
            ["商城购买_货币2"] = {
                ["菜单按钮名"] = "商城购买_货币2",
                ["按键"] = "",
                ["指令"] = {
                    [[viewUI {"界面ID":"水晶","参数":{"商品名":"金币补给包"}} ]]
                }
            },
            ["商城购买_货币3"] = {
                ["菜单按钮名"] = "商城购买_货币3",
                ["按键"] = "",
                ["指令"] = {
                    [[viewUI {"界面ID":"水晶","参数":{"商品名":"能量豆补给包"}} ]]
                }
            },
            ["商城购买_货币4"] = {
                ["菜单按钮名"] = "商城购买_货币4",
                ["按键"] = "",
                ["指令"] = {
                    [[viewUI {"界面ID":"水晶","参数":{"商品名":"水晶x10"}} ]]
                }
            },
            ["自动战斗"] = {
                ["菜单按钮名"] = "自动战斗",
                ["按键"] = "L",
                ["指令"] = {
                    [[toggleAutoBattle {"状态":"切换"} ]],
                    [[cast {"魔法名":"自动战斗进出判断","复杂魔法":{}} ]]
                },
                ["显示条件"] = Modifiers.New({
                    {
                        ["目标"] = "自己",
                        ["条件类型"] = "VariableCondition",
                        ["条件"] = {
                            ["名字"] = "level",
                            ["最小值"] = 0,
                            ["最大值"] = 100,
                            ["最小"] = "2",
                            ["最大"] = "X"
                        },
                        ["动作"] = "必须"
                    }
                })
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
        ["点击商城购买按钮指令"] = {
            [[viewUI {"界面ID":"水晶","参数":{"商品名":"水晶x60"}} ]]
        },
        ["每日刷新指令"] = {
            [[cast {"魔法名":"基金卡每日发放指令","复杂魔法":{}} ]],
            [[cast {"魔法名":"特权卡每日变量减少","复杂魔法":{}} ]],
            [[var {"操作":"全部改为","变量名":"daily_","值":"0"} ]],
            [[var {"操作":"全部改为","变量名":"online_time","值":"0"} ]]
        },
        ["每周刷新指令"] = {
            [[var {"操作":"全部改为","变量名":"weekly_","值":"0"} ]]
        },
        ["每月刷新指令"] = {
            [[var {"操作":"全部改为","变量名":"monthly_","值":"0"} ]]
        },
        ["主动技能升级音效"] = "sandboxId://soundeffect/wakeup唤醒.ogg",
        ["被动技能升级音效"] = "sandboxId://soundeffect/points点.ogg",
        ["次要技能升级音效"] = "sandboxId://soundeffect/points点.ogg",
        ["技能装备音效"] = "sandboxId://soundeffect/plant_lift.ogg",
        ["技能卸下音效"] = "sandboxId://soundeffect/shovel铲子.ogg",
        ["任务完成音效"] = "sandboxId://soundeffect/quest_cleared.mp3",
        ["商城购买音效"] = "sandboxId://soundeffect/shop_buy.ogg"
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

if gg.isServer then
    ServerEventManager.Subscribe("ClickMenu", function (evt)
        local status, menuConfig = pcall(function()
            return MiscConfig.Get("总控")["菜单指令"][evt.menu]
        end)
        if not status or not menuConfig then
            evt.player:SendHoverText("尚未开放，敬请期待！")
            return
        end
        
        -- 检查显示条件
        if menuConfig["显示条件"] then
            local castParam = menuConfig["显示条件"]:Check(evt.player, evt.player)
            if castParam.cancelled then
                evt.player:SendHoverText("条件不满足，无法执行！")
                return
            end
        end
        
        local ok, err = pcall(function()
            evt.player:ExecuteCommands(menuConfig["指令"])
        end)
        if not ok then
            evt.player:SendHoverText("尚未开放，敬请期待！")
            return
        end
    end)
end
return MiscConfig
