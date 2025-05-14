--- V109 miniw-haima
--- 全局变量中，基本上不会去修改的常量

local Vector3 = Vector3


---@class common_const
local  common_const = {

    MOVESPEED = 400,      --玩家和人物行走速度

    VECUP   = Vector3.New(0,1,0),     --向上方向 y+
    VECDOWN = Vector3.New(0,-1,0),    --向下方向 y-

    ---@class NPC_TYPE NPC类型枚举
    ---@field INITING NPC_TYPE 初始化状态
    ---@field PLAYER NPC_TYPE 玩家类型
    ---@field MONSTER NPC_TYPE 怪物类型
    ---@field NPC NPC_TYPE NPC类型
    ---@field AI NPC_TYPE AI机器人类型
    NPC_TYPE = {
        INITING  = 0,   --初始化
        PLAYER   = 1,   --玩家
        MONSTER  = 2,   --怪物
        NPC      = 3,   --npc
        AI       = 4,   --AI机器人
    },


    ---@class PLAYER_NET_STAT 玩家网络状态枚举
    ---@field INITING PLAYER_NET_STAT 初始化状态
    ---@field LOGIN_IN PLAYER_NET_STAT 服务器初始化完成
    ---@field CLIENT_OK PLAYER_NET_STAT 客户端连接正常(正常状态)
    ---@field LOGIN_OUT PLAYER_NET_STAT 玩家退出
    PLAYER_NET_STAT = {
        INITING   = 0,    --初始化
        LOGIN_IN  = 1,    --服务器初始化完成
        CLIENT_OK = 2,    --客户端连接正常  (正常状态) 
        LOGIN_OUT = 99,   --玩家退出
    },


    ---@class BATTLE_STAT 战斗状态枚举
    ---@field IDLE BATTLE_STAT 空闲状态(脱离战斗)
    ---@field FIGHT BATTLE_STAT 进入战斗状态
    ---@field DEAD_WAIT BATTLE_STAT 被击败状态(等待重生或者清理)
    ---@field WAIT_SPAWN BATTLE_STAT 等待重生状态
    BATTLE_STAT = {
        IDLE            = 1,      --空闲(脱离战斗)
        FIGHT           = 2,      --进入战斗
        DEAD_WAIT       = 91,     --被击败 (等待重生或者清理)
        WAIT_SPAWN      = 92,     --等待重生
    },


    ---@class ITEM_TYPE 物品类型枚举
    ---@field EQUIPMENT ITEM_TYPE 装备类型
    ---@field BOX ITEM_TYPE 箱子类型
    ---@field MAT ITEM_TYPE 材料类型
    ITEM_TYPE ={
        EQUIPMENT  = 1,      --装备
        BOX        = 2,      --箱子
        MAT        = 3,      --材料
    },

}

return common_const