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

-- 槽位到UI卡片名称的映射配置
local SlotToCardMapping = {
    [2] = "卡片_1",  -- 副卡1对应卡片_1，数字键1
    [3] = "卡片_2",  -- 副卡2对应卡片_2，数字键2
    [4] = "卡片_3",  -- 副卡3对应卡片_3，数字键3
    [5] = "卡片_4"   -- 副卡4对应卡片_4，数字键4
}

-- 槽位到卡片名称和按键的完整映射配置（用于事件绑定）
local SlotToCardWithKeyMapping = {
    [2] = {cardName = "卡片_1", keyIndex = 1},  -- 槽位2对应卡片_1，数字键1
    [3] = {cardName = "卡片_2", keyIndex = 2},  -- 槽位3对应卡片_2，数字键2
    [4] = {cardName = "卡片_3", keyIndex = 3},  -- 槽位4对应卡片_3，数字键3
    [5] = {cardName = "卡片_4", keyIndex = 4}   -- 槽位5对应卡片_4，数字键4
}

-- 固定的卡片名称列表（按顺序对应数字键1-4）
local FixedCardNames = {"卡片_1", "卡片_2", "卡片_3", "卡片_4"}

-- 传送点配置，键为传送点ID，值为场景中对应节点的绝对路径
local TeleportPoints = {
    ["g0"] = "Ground/g0/传送点/传送",

}

--所有配置( 其他所有的配置文件将汇总到这里， 游戏逻辑代码只需要require这个文件即可 )
---@class common_config
local common_config = {
    EquipmentSlot = EquipmentSlot,
    SlotToCardMapping = SlotToCardMapping,
    SlotToCardWithKeyMapping = SlotToCardWithKeyMapping,
    FixedCardNames = FixedCardNames,
    TeleportPoints = TeleportPoints,
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
