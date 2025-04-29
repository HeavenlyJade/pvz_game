

--- V109 miniw-haima
--- 武器装备属性配置

---@class MConfigWeapon
local MConfigWeapon = {

    --装备类型： 1001=武器  1002=盾牌  1003=头盔
    --装备品质:  1=白色普通  2=蓝色魔法*2  3=黄金传奇*3  4=粉色史诗*4  5=橙色传说*5


    -- 词缀属性
    -- ( name=属性名 min=最小值 max=最大值 des=描述 per=百分比 wname=词缀 quality=质量 )  装备品质( 白色  蓝色*2  亮金*3  橙色*4  暗金*5 )
    common_attr = {

        --属性
        { name='str',  min=1, max=10,  des='增加力量',  },    --增加物理攻击和防御
        { name='int',  min=1, max=10,  des='增加智力',  },    --增加法术攻击力和法力值
        { name='agi',  min=1, max=10,  des='增加敏捷', },    --增加暴击率和防御
        { name='vit',  min=1, max=10,  des='增加体力', },    --增加hp最大值
        { name='hp_max',  min=10, max=50,   des='增加血量',    },
        { name='mp_max',  min=1,  max=5,    des='增加法力',   },
        { name='hp_vam',  min=1, max=2,    des='攻击回血', quality=3,  },
        { name='mp_vam',  min=1, max=2,    des='攻击回蓝', quality=3,  },
        --攻击
        { name='ed',   min=2,  max=20,  des='伤害增加', quality=3,          },
        { name='edp',  min=2,  max=10,  des='伤害百分比增加', quality=3, per=1,  },      --百分比
        { name='es',   min=2,  max=20,  des='技能伤害增加', quality=3,        },
        { name='esp',  min=2,  max=10,  des='技能伤害百分比增加', quality=3, per=1,  },   --百分比
        { name='speed', min=5,  max=10,  des='速度增加',    per=1,  },
        { name='cr',   min=1,  max=2,   des='暴击几率增加',  quality=2, per=1,  },
        { name='crd',  min=10, max=20,  des='暴击伤害增加',  quality=2, per=1,   },
        { name='a_dod',  min=1, max=2,   des='命中', per=1,    },  --百分比
        { name='rd0',   min=10, max=20,  des='破甲',        quality=4, per=1,  },   --减少目标防御
        { name='rd0p',  min=1,  max=10,  des='忽视目标防御', quality=4, per=1,  },   --百分比


        { name='rd3',  min=1,  max=10,  des='降低目标冰抗',  quality=4, per=1,    },   --百分比
        { name='rd4',  min=1,  max=10,  des='降低目标电抗',  quality=4, per=1,   },   --百分比
        { name='rd5',  min=1,  max=10,  des='降低目标木抗',  quality=4, per=1,   },   --百分比
        { name='rd6',  min=1,  max=10,  des='降低目标火抗',  quality=4, per=1,   },   --百分比

        { name='s3',   min=1,  max=10,  des='附加水系伤害',  quality=2,  },
        { name='s4',   min=1,  max=10,  des='附加电系伤害',  quality=2,  },
        { name='s5',   min=1,  max=10,  des='附加木系伤害',  quality=2,  },
        { name='s6',   min=1,  max=10,  des='附加火系伤害',  quality=2,   },

        { name='sp3',  min=1,  max=10,  des='水系伤害增强',  quality=2, per=1,    },   --百分比
        { name='sp4',  min=1,  max=10,  des='电系伤害增强',  quality=2, per=1,    },   --百分比
        { name='sp5',  min=1,  max=10,  des='木系伤害增强',  quality=2, per=1,    },   --百分比
        { name='sp6',  min=1,  max=10,  des='火系伤害增强',  quality=2, per=1,    },   --百分比
        --防御
        { name='all_rs',  min=1, max=1,   des='所有抗性增加', per=1,  },  --百分比

        { name='r0',  min=1, max=40, des='增加防御',              },
        { name='r3',  min=2, max=10, des='增加冰系抗性', per=1,   },   --百分比
        { name='r4',  min=2, max=10, des='增加电系抗性', per=1,   } ,   --百分比
        { name='r5',  min=2, max=10, des='增加木系抗性', per=1,    },   --百分比
        { name='r6',  min=2, max=10, des='增加火系抗性', per=1,   },   --百分比


        { name='dod',   min=1, max=2,    des='躲闪', per=1,        },  --百分比
        { name='rd_melee',  min=3, max=30,    des='减少物理伤害',   },
        { name='rd_spell',  min=2, max=20,    des='减少法术伤害',   },
        { name='rd_melee_ratio',  min=1, max=10,   per=1,  des='减少物理百分比伤害',   } ,
        { name='rd_spell_ratio',  min=1, max=10,  per=1,   des='减少法术百分比伤害', },


    },

    common_att_dict = {},   --用来查询的字典
}




--生成 common_att_dict 字典
function MConfigWeapon.Init()
    for seq_, v in pairs( MConfigWeapon.common_attr ) do
        if  MConfigWeapon.common_att_dict[ v.name ] then
            --属性定义重复出错提示
            print( 'ERROR: attr name duplicate:', v.name )
            assert(0)
        else
            MConfigWeapon.common_att_dict[ v.name ] = v
        end
    end
end


MConfigWeapon.Init()

return MConfigWeapon