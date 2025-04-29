
--- V109 miniw-haima
--- 描述怪物的战斗数值


---@class MConfigMonster
local MConfigMonster = {}



--数值模板
MConfigMonster.default_monster_battle_data = {
    hp_max = 100,       --生命值
    mp_max = 100,       --魔法值

    hp_factor = 2,      --怪物没有装备，进行血量加成

    str = 5,       --力量 增加物理攻击和防御
    int = 5,       --智力 增加法术攻击力
    agi = 5,       --敏捷 增加暴击率和命中
    vit = 5,       --体力 增加hp最大值
    
    cr = 0  , -- 物理暴击率
    mag_cr= 0  ,  -- 魔法暴击率
    attack   = 3,   --攻击随机下限
    attack2  = 5,   --攻击随机上限 
    defence   = 1,   --防御随机下限
    defence2  = 3,   --防御随机上限
    mag_defence =1,  --魔法防御下限
    mag_defence2 =3, --魔法防御上限

    spell    = 5,   --法术攻击下限
    spell2   = 8,   --法术攻击上限

    skills = {1001},    --技能列表

    level_factor = 2,     --等级增长因子
}




--怪物战斗数值模板 （ 基于 default_monster_battle_data 模板， 并替换属性 ）
MConfigMonster.monster_battle_config = {
    m1 = { },    --物理近身怪1 平砍

    m2 = {       --物理近身怪2 平砍 (伍长)
        hp_max = 200,
        hp_factor = 3,
        attack    =  7,
        defence   =  2,
        level_factor = 6,
    },

    m3 = {       --物理近身怪3 平砍 (百夫长)
        hp_max = 300,
        hp_factor = 5,

        attack    =  9,
        defence   =  3,
        level_factor = 8,
    },

    -------------------------远程
    r1 = {           --物理远程怪1 投矛 弓箭
        skills  =  {1002},
    },

    r2 = {           --物理远程怪2 投矛 弓箭  (百夫长)
        hp_factor = 3,
        attack    =  7,
        skills    =  {1002},
        level_factor = 6,
    },

    r3 = {           --物理远程怪3 回旋镖  (百夫长)
        mp_max    = 200,
        hp_factor = 5, 
        attack    =  9,
        defence   =  2,
        skills    =  {2006},
        level_factor = 8,
    },

    -----------------------------法师
    s1 = {            --法师怪
        hp_max=80,
        hp_factor = 3,
        mp_max=100,

        attack  =  2,
        spell   =  7,
        defence =  0,
        skills  =  {2001},   --火球
        level_factor = 6,
    },

    s2 = {            --法师怪 ( 寒霜 )
        hp_max=100,
        hp_factor = 5,
        mp_max=120,
        attack  =  3,
        spell   = 10,
        defence =  2,
        skills  =  {2005},    --冰球
        level_factor = 8,
    },

}



--怪物配置列表 (实际使用 dict_monster_config, 用来快速查找怪物配置 )
--id      怪物资源id
--battle  怪物战斗数值模板
--name    怪物名字
--high    怪物高度（计算名字和血条位置）
MConfigMonster.monster_config = {
    { id=100063,  battle='s1',   name='野人祭司',      high=30,  },   --毒素野人祭司 治疗野人祭司
    { id=100097,  battle='s2',   name='寒霜野人祭司',   high=30,  },
    { id=100107,  battle='r3',   name='虚空野人投矛百夫长', },
    { id=100108,  battle='m3',   name='虚空野人百夫长',     },
    { id=100113,  battle='m1',   name='野人战士',          },
    { id=100114,  battle='m2',   name='野人伍长',          },
    { id=100115,  battle='m3',   name='野人百夫长',        },
    { id=100116,  battle='m2',   name='虚空野人伍长',       },
    { id=100117,  battle='r1',   name='野人投矛手',         },
    { id=100118,  battle='r2',   name='野人投矛伍长',       },
    { id=100119,  battle='r3',   name='野人投矛百夫长',     },
    { id=100120,  battle='r2',   name='虚空野人投矛伍长',   },
    { id=100011,  battle='m3',   name='石头人',   }
}


return MConfigMonster