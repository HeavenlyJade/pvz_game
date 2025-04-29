--- V109 miniw-haima
--- BUff配置
--buff_sn        用来标注这个buff是用来具体哪个实列类的
--id              buff_ id
--dmg_type        buff伤害类型  1,2,3,4,5,6 物理，魔法，火，电，水，木伤害类型，0就是说明该buff不是直接伤害
--range           buff距离
--target          目标  0 是自己 ，1是选定对对象 ，2 是范围对象，3当前地图存在的组队队友
-- cost           消耗物品
--speed           施法速度
--cast_time       前置释放时间
--buff_cd              冷却时间, 单位是秒
--duration_time   buff持续时间 单位是秒
--size            aoe范围大小
-- value_type = "absolute" , "percent" 一个是按照数值一个是按照百分比
---@class MConfigBuff
local MConfigBuff = {

    buff_def = {

        [1] = {
            buff_sn = 1,
            dmg_type = 0,
            range = 360,
            speed = 2,
            need_target = 0,
            name = '圣光',
            icon = 'resId&usev2=1://358753448074747904',
            desc = '赋予自身全部力，智，敏，体力各10点',
            duration_time = 10,
            buff_cd = 180,
            cost = { 
                { type = "thing", name = "魔力碎片", num = -10,value_type = "absolute" },
                { type = "property", name = "hp", num = -100,value_type = "absolute" } },
            buff_effect = {
                  { type = "property", name = "str", num = 10,value_type = "absolute"  },
                  { type = "property", name = "int", num = 10 ,value_type = "absolute" },
                  { type = "property", name = "agi", num = 10 ,value_type = "absolute" },
                  { type = "property", name = "vit", num = 10 ,value_type = "absolute" } 
            }
        }, --圣光
    },

}

return MConfigBuff
