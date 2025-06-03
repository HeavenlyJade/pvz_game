--- V109 miniw-haima
--- 关卡配置 （ 刷怪点 怪物个数，等级）

--- monster_spawnX 场景中配置的刷怪点

---@class MConfigScene
local MConfigScene = {

    --monster_count默认刷怪数量
    --range       刷怪范围
    --level       怪物最小等级
    --level2      怪物最大等级

    default = {
        monster_spawn1 = { monster_count = 5, range = 500, level = 1, level2 = 3 },
        monster_spawn2 = { monster_count = 5, range = 500, level = 3, level2 = 4 },
        monster_spawn3 = { monster_count = 5, range = 500, level = 5, level2 = 6 },
    },


    -- 大厅
    g0 = {
        ["monster_spawn1"] = { ["monster_count"] = 5, ["range"] = 500,
        ["level"] = 10, ["level2"] = 20, ["refresh_interval"] = 30, ["monster_template"] = "g0", 
        ["spawned_monsters"] = { [100113] = { ["spawn_probability"] = 60 }, [100114] = 
        { ["spawn_probability"] = 30 }, [100115] = { ["spawn_probability"] = 10 } }, ["drop_items"] =
        { { ["drop_type"] = "epic_equ", ["num"] = 1, ["item_id"] = "eq_1", ["drop_rate"] = 100 } } },
        ["monster_spawn2"] = { ["monster_count"] = 8, ["range"] = 1000, ["level"] = 10, ["level2"] = 20, ["refresh_interval"] = 45, ["monster_template"] = "g0", ["spawned_monsters"] = { [100118] = { ["spawn_probability"] = 50 }, [100119] = { ["spawn_probability"] = 50 } }, ["drop_items"] = { { ["drop_type"] = "epic_equ", ["num"] = 1, ["item_id"] = "eq_2", ["drop_rate"] = 100 } } },
        ["monster_spawn3"] = { ["monster_count"] = 3, ["range"] = 1000, ["level"] = 10, ["level2"] = 20, ["refresh_interval"] = 20, ["monster_template"] = "g0", ["spawned_monsters"] = { [100063] = { ["spawn_probability"] = 80 }, [100097] = { ["spawn_probability"] = 20 } }, ["drop_items"] = { { ["drop_type"] = "epic_weapon", ["num"] = 1, ["item_id"] = "we_1", ["drop_rate"] = 100 } } },
    }

}

function MConfigScene.getLevelStr(name_)
    if MConfigScene[name_] then
        local min, max = 1, 1
        min = MConfigScene[name_]['monster_spawn1'].level

        for i = 1, 10 do
            if MConfigScene[name_]['monster_spawn' .. i] then
                max = MConfigScene[name_]['monster_spawn' .. i].level2
            else
                break;
            end
        end
        return '(' .. min .. '-' .. max .. ')'
    end
    return ''
end

return MConfigScene
