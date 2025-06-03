
--- V109 miniw-haima
--- 描述NPC的战斗数值


---@class MConfigNpc
local MConfigNpc = {}


--默认数值模板
MConfigNpc.default_npc_battle_data = {
    hp_max = 2000,       --生命值
    mp_max = 1000,       --魔法值
    -- 四维属性
    str = 10,       --力量 增加物理攻击和防御
    int = 10,       --智力 增加法术攻击力
    agi = 10,       --敏捷 增加暴击率和命中
    vit = 10,       --体力 增加hp最大值

    cr = 0  , -- 物理暴击率
    mag_cr= 0  ,  -- 魔法暴击率
    attack   = 5,   --攻击随机下限
    attack2  = 10,  --攻击随机上限

    defence   = 1,   --物理防御下限
    defence2  = 3,   --物理防御上限
    mag_defence =1,  --魔法防御下限
    mag_defence2 =3, --魔法防御上限
    spell    = 10,  --法术攻击下限
    spell2   = 13,  --法术攻击上限


    skills = {1001},    --技能列表 1001 默认平砍
    level_factor = 1,     --等级增长因子 
}



--玩家的配置文件 （ 基于上面，并替换属性 ）
MConfigNpc.dict_player_config = {
    -- NPC职业模板 
    [1] = {     
        hp_max = 21000,       --生命值
        mp_max = 1200,       --魔法值
        str = 200,
        skills = { 1001},    --技能列表: 平砍1001
    },


}



return MConfigNpc