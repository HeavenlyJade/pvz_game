--- Npc的刷新点  --- NpcConfigSpawn 场景中配置的刷怪点 ---  ---  --- ---
---@class NpcConfigSpawn
local NpcConfigSpawn = {
    g0 = {
        su_yun_tao = {
            name = "素云涛",
            position = {-1048, 8, 322},
            rotation = {0, 30, 0},
            type = "Actor",
            model = "sandboxSysId://entity/100009/body.omod",
            lv = 26,
            profession = 1,
            plot = {
                "欢迎来到斗魂殿"
            }

        },
        nu_ding_blacksmith = {
            name = "诺丁铁匠",
            position = {-943, 7, 892},
            rotation = {0, 30, 0},
            type = "Actor",
            model = "sandboxSysId://entity/100009/body.omod",
            lv = 30,
            profession = 1,
            plot = {
                "欢迎来到诺丁铁匠铺"
            }
        }
    }
}

return NpcConfigSpawn