
--- V109 miniw-haima
--- 云资源列表

---@class MConfigAssets
local MConfigAssets = {

    startup_bg = {
        'RainbowId&filetype=6://257285792363253760',
        'RainbowId&filetype=6://257285866019426304',
        'RainbowId&filetype=6://257285933300256768',
        'RainbowId&filetype=6://257285993962475520',

        'RainbowId&filetype=6://257286062480625664',
        'RainbowId&filetype=6://257286130751311872',
        'RainbowId&filetype=6://257286195070963712',
        'RainbowId&filetype=6://257286256504934400',

        'RainbowId&filetype=6://257339960838918144',
        'RainbowId&filetype=6://257340038811029504',
        'RainbowId&filetype=6://257340189743058944',
        'RainbowId&filetype=6://257340286069444608',

        'RainbowId&filetype=6://257340402591404032',
        'RainbowId&filetype=6://257340488385892352',
        'RainbowId&filetype=6://257340663359672320',
    },


    jpg_mask          = 'RainbowId&filetype=6://264282384597323776',      --白色mask
    skill_cd_mask     = 'RainbowId&filetype=5://264889835264741376',      --技能cd mask

    btn_jump          = 'RainbowId&filetype=5://257348889568415744',      --跳跃

    btn_press1        = 'RainbowId&filetype=5://246821913711677440',      --按钮1
    btn_press2        = 'RainbowId&filetype=5://246821862532780032',      --按钮2
    btn_press3        = "RainbowId&filetype=5://246821820799455232",      --按钮3


    btn_skill_ui      = 'RainbowId&filetype=5://260978740426772480',      --技能选择面板
    btn_bag_ui        = 'RainbowId&filetype=5://260978776535535616',      --背包界面
    btn_close         = 'RainbowId&filetype=5://258844478885924864',      --关闭按钮

    btn_empty_frame   = 'RainbowId&filetype=5://259184713712865280',      --空框
    icon_point_frame1 = 'RainbowId&filetype=5://259185703719604224',      --装备指示框1
    icon_point_frame2 = 'resid://282005810523217920',                     --装备指示框2


    skill_bg          = 'RainbowId&filetype=5://255461692430946304',      --技能背景
    --bag_bg_man        = 'RainbowId&filetype=6://262777528732684288',      --人物背景1
    bag_bg_man        = 'RainbowId&filetype=5://264172822309441536',      --人物背景2

    icon_hp_bar       = 'RainbowId&filetype=5://246821862532780032',      --血法条

    icon_box        = 'sandboxSysId://items/icon10020.png',   --宝箱图标

    icon_mat1       = 'sandboxSysId://items/icon11618.png',   --魔力碎片1
    icon_mat2       = 'sandboxSysId://items/icon11626.png',   --神力碎片2


    -- 'sandboxSysId://blocks/magical_brick_top.png'

    --模型
    model = {
        model_sword     = 'sandboxSysId://itemmods/12012/body.omod',   -- 一把剑
        model_changmao  = 'sandboxSysId://itemmods/12004/body.omod',   -- 长矛
    },


    --特效
    effect = {
        end_table_effect   = 'sandboxSysId://particles/3504_chaosball.ent',    --火焰14 传送门
        bomb_effect        = 'sandboxSysId://particles/1005.ent',              --爆炸2
        revive_effect      = 'sandboxSysId://particles/item_137_red.ent',      --复活特效

        spell_effect       = 'sandboxSysId://particles/bossskill_3510_laserblue.ent',     -- 释法特效
        fireball_effect    = 'sandboxSysId://particles/3508_lavaball.ent',                -- 火球特效

        iceball_effect      = 'sandboxSysId://particles/1031.ent',                    -- 冰球特效1 技能2005
        iceball_bomb_effect = 'sandboxSysId://particles/icebreak.ent',                -- 冰球特效2 技能2005 炸开效果

        --blade_effect        = 'sandboxSysId://particles/item_12004_1.ent',            --回旋镖特效 技能2006
        blade_effect       = 'sandboxSysId://particles/item_12004_3.ent',            --回旋镖特效 技能2006

        tp_effect          = 'sandboxSysId://particles/bosskill_3510_laserhitpoint.ent',  -- 闪现特效
        heal_effect        = 'sandboxSysId://particles/skill_frenzy.ent',                 --治愈术特效
        drop_box_effect    = 'sandboxSysId://particles/skill_frenzy.ent',                 --掉落特效
    },

}

return MConfigAssets;