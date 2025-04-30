
--- V109 miniw-haima
--- 全局变量中，基本上不会去修改的常量

local Vector3 = Vector3


---@class common_const
local  common_const = {

    MOVESPEED = 400,      --玩家和人物行走速度

    VECUP   = Vector3.new(0,1,0),     --向上方向 y+
    VECDOWN = Vector3.new(0,-1,0),    --向下方向 y-

    ---@enum NPC_TYPE  --玩家类型
    NPC_TYPE = {
        INITING  = 0,   --初始化
        PLAYER   = 1,   --玩家
        MONSTER  = 2,   --怪物
        NPC      = 3,   --npc
        AI       = 4,   --AI机器人
    },


    ---@enum PLAYER_NET_STAT  --玩家网络状态
    PLAYER_NET_STAT = {
        INITING   = 0,    --初始化
        LOGIN_IN  = 1,    --服务器初始化完成
        CLIENT_OK = 2,    --客户端连接正常  (正常状态) 
        LOGIN_OUT = 99,   --玩家退出
    },


    ---@enum BATTLE_STAT         --玩家或者怪物战斗状态
    BATTLE_STAT = {
        IDLE            = 1,      --空闲(脱离战斗)
        FIGHT           = 2,      --进入战斗
        DEAD_WAIT       = 91,     --被击败 (等待重生或者清理)
        WAIT_SPAWN      = 92,     --等待重生
    },


    ---@enum ITEM_TYPE       --物品类型 itype
    ITEM_TYPE ={
        EQUIPMENT  = 1,      --装备
        BOX        = 2,      --箱子
        MAT        = 3,      --材料
        CARD       = 4,      --卡片
        CONSUMABLE = 5,      --消耗品
        UNKNOWN    = 99,     --未知
    },


    ---@enum MAT_ID        --可堆叠的mat物品材料类型ID( ITEM_TYPE=MAT )
    MAT_ID = {
        FRAGMENT  = 1001,    --碎片
        HP_POTION = 2001,    --红药水
        MP_POTION = 2002,    --蓝药水
        HM_POTION = 2003,    --红蓝药水
    },

}


function common_const:getContainerNameByType(itemType)
    local typeToContainer = {
        [common_const.ITEM_TYPE.EQUIPMENT] = "bag_equ_items",
        [common_const.ITEM_TYPE.CONSUMABLE] = "bag_consum_items",
        [common_const.ITEM_TYPE.BOX] = "bag_consum_items", -- 宝箱也放在消耗品容器
        [common_const.ITEM_TYPE.MAT] = "bag_mater_items",
        [common_const.ITEM_TYPE.CARD] = "bag_card_items"
    }
    return typeToContainer[itemType] or "bag_equ_items" -- 默认放在装备容器
end


return common_const