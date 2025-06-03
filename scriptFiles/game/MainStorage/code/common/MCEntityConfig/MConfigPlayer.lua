
--- V109 miniw-haima
--- 描述玩家的战斗数值


---@class MConfigPlayer
local MConfigPlayer = {}


--默认数值模板
MConfigPlayer.default_player_battle_data = {
    hp_max = 200,       --生命值
    mp_max = 100,       --魔法值
    -- 四维属性
    str = 100,       --力量 增加物理攻击和防御
    int = 10,       --智力 增加法术攻击力
    agi = 10,       --敏捷 增加暴击率和命中
    vit = 10,       --体力 增加hp最大值

    cr = 0  , -- 物理暴击率
    mag_cr= 0  ,  -- 魔法暴击率
    attack   = 200,   --攻击随机下限
    attack2  = 300,  --攻击随机上限

    defence   = 1,   --物理防御下限
    defence2  = 3,   --物理防御上限
    mag_defence =1,  --魔法防御下限
    mag_defence2 =3, --魔法防御上限
    spell    = 10,  --法术攻击下限
    spell2   = 13,  --法术攻击上限


    skills = {1001},    --技能列表 1001 默认平砍
    level_factor = 1,     --等级增长因子 
}



--玩家的配置文件 （ 基于上面 default_player_battle_data 模板，并替换属性 ）
MConfigPlayer.dict_player_config = {
    -- 武魂就是职业 
    [1] = {     --  蓝银草
        hp_max = 210,       --生命值
        mp_max = 120,       --魔法值
        str = 20,

        skills = { 1001},    --技能列表: 平砍1001
    },

    [2] = {     -- 昊天锤
        str = 20,
        hp_max = 320,       --生命值
        mp_max = 90,        --魔法值
        skills = { 1001},    --技能列表
    },

}


--升级经验表  x*x*100
MConfigPlayer.expLevelUp = {
      0,
    100,
    400,
    900,
    1600,
    2500,
    -- ...
}

--初始化经验表
function MConfigPlayer.Init()
    for i=1, 100 do
        MConfigPlayer.expLevelUp[i] = (i-1)*(i-1)*100
    end
end

MConfigPlayer.Init()

return MConfigPlayer