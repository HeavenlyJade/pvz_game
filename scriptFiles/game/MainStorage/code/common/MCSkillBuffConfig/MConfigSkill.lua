---
--- Created by Administrator.
--- DateTime: 2025/2/11 下午2:37
---
--- V109 miniw-haima
--- 技能配置
--skill_sn        用来标注这个技能是用来具体哪个实列类的
--id              技能id
--dmg_type        技能伤害类型   1=物理  2=魔法  3=冰霜  4=雷电  5=毒素
--power           技能伤害放大系数 ( 玩家攻击值 x power )
--range           技能攻击距离
--need_target     是否需要选定目标
--mp              消耗的魔法值
--speed           攻速 1=武器速度(两次攻击间隔秒)
--cast_time       技能前置施法时间
--cd              技能cd帧数
--duration_time   持续时间(aoe引导时间)
--size            aoe范围大小

---@class MConfigSkill
local MConfigSkill = {

    skill_def = {
     
        [1010] = {
            skill_sn = 1000,
            dmg_type = {1},
            power = 1.5,
            range = 360,
            speed = 2,
            need_target = 0,
            name = '终极平砍',
            icon = 'sandboxSysId://ui/bufficons/attack_punch_add.png',
            desc = '普通近距离攻击(不消耗法力值)',
        }, --超级平砍
        [1000] = {
            skill_sn = 1000,
            dmg_type = {1},
            power = 1.5,
            range = 360,
            speed = 2,
            need_target = 0,
            name = '超级攻击',
            icon = 'sandboxSysId://ui/bufficons/attack_punch_add.png',
            desc = '普通近距离攻击(不消耗法力值)',
        }, --超级平砍
        [1001] = {
            skill_sn  = 1001,
            dmg_type = {1},
            power = 1.5,
            range = 260,
            speed = 2,
            need_target = 0,
            name = '平砍',
            icon = 'sandboxSysId://ui/bufficons/attack_punch_add.png',
            desc = '普通近距离攻击(不消耗法力值)',
        }, --平砍
        [1002] = {
            skill_sn  = 1002,
            dmg_type = {1},
            power = 1,
            range = 2200,
            speed = 1,
            need_target = 1,
            name = '投矛',
            icon = 'RainbowId&filetype=5://257360081590489088',
            desc = '远距离投出一根长矛(不消耗法力值)'
        }, --投矛 弓箭

        --施法技能
        [2001] = {
            skill_sn  = 2001,
            dmg_type = {2,6},
            power = 2,
            range = 2000,
            mp = 20,
            cd = 10,
            cast_time = 5,
            need_target = 0,
            name = '火球术',
            icon = 'RainbowId&filetype=5://254022700078534656',
            desc = '发射一颗大火球，击中目标后，造成较大的火系伤害'
        }, --火球术
        [2002] = {
            skill_sn  = 2002,
            dmg_type = {2,3},
            power = 0.8,
            range = 1500,
            mp = 25,
            cd = 0,
            size = 1000,
            duration_time = 35,
            name = '暴风雪',
            icon = 'RainbowId&filetype=5://257359971842330624',
            desc = '在指定范围内落下暴风雪，造成冰系伤害，并让目标减速'
        }, --AOE 暴风雪
        [2003] = {
            skill_sn  = 2003,
            dmg_type = {2,4},
            power = 1,
            range = 1000,
            mp = 5,
            cd = 60,
            name = '闪现',
            icon = 'RainbowId&filetype=5://257359999172415488',
            desc = '向前突进一段距离，并造成小范围的闪电伤害，并让目标晕迷'
        }, --闪现
        [2004] = {
            skill_sn  = 2004,
            power = 1,
            range = 2000,
            mp = 10,
            cd = 10,
            cast_time = 15,
            name = '治愈术',
            icon = 'RainbowId&filetype=5://257359922353737728',
            desc = '恢复玩家较多的生命值',
            buff_list ={1}
        }, --治愈术
        [2005] = {
            skill_sn  = 2005,
            dmg_type ={2,3},
            power = 1.6,
            range = 2000,
            mp = 20,
            cd = 10,
            cast_time = 10,
            need_target = 1,
            name = '冰箭',
            icon = 'RainbowId&filetype=5://257360030067658752',
            desc = '发射一只冰箭，击中目标后造成冰系伤害，并让目标减速'
        }, --冰箭
        [2006] = {
            skill_sn  = 2006,
            dmg_type = {1},
            power = 1,
            range = 1500,
            mp = 25,
            cd = 30,
            size = 1000,
            name = '回旋镖',
            icon = 'RainbowId&filetype=5://254023724075913216',
            desc = '发射一个来回运动的回旋镖，沿途造成多次物理伤害'
        }, --回旋镖 AOE
    },

}

return MConfigSkill
