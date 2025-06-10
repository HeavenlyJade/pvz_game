--- V109 miniw-haima
--所有配置( 其他所有的配置文件将汇总到这个模块里 )

local pairs = pairs

local EquipmentSlot = {
    ["主卡"] = {
        [1] = "主卡"
    },
    ["副卡"] = {
        [2] = "副卡1",
        [3] = "副卡2",
        [4] = "副卡3",
        [5] = "副卡4"
    }
}


--所有配置( 其他所有的配置文件将汇总到这里， 游戏逻辑代码只需要require这个文件即可 )
---@class common_config
local common_config = {
    EquipmentSlot = EquipmentSlot,
}


---------- utils 帮助函数 ----------------
--浅拷贝 不拷贝meta ( 与gg.clone 一致， 避免再次require文件 )
function common_config.clone(ori_tab)
    local new_tab = {}
    for i, v in pairs(ori_tab) do
        if  type(v) == "table" then
            new_tab[i] = common_config.clone(v)
        else
            new_tab[i] = v
        end
    end
    return new_tab
end


return common_config
