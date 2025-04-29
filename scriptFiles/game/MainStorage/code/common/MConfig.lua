
--- V109 miniw-haima
--所有配置( 其他所有的配置文件将汇总到这个模块里 )

local game  = game
local pairs = pairs


local MainStorage     = game:GetService("MainStorage")
local configAssets    = require(MainStorage.code.common.MConfigAssets)   ---@type MConfigAssets
local configScene     = require(MainStorage.code.common.MCEntitySpawn.MConfigScene)    ---@type MConfigScene
local configNpc       = require(MainStorage.code.common.MCEntitySpawn.MCNpcSpawnConfig)    ---@type NpcConfigSpawn

local configPlayer    = require(MainStorage.code.common.MCEntityConfig.MConfigPlayer)   ---@type MConfigPlayer
local configMonster   = require(MainStorage.code.common.MCEntityConfig.MConfigMonster)  ---@type MConfigMonster

local buffConfig      = require(MainStorage.code.common.MCSkillBuffConfig.MConfigBuff)  ---@type MConfigBuff
local configSkill     = require(MainStorage.code.common.MCSkillBuffConfig.MConfigSkill)    ---@type MConfigSkill

local configWeapon    = require(MainStorage.code.common.MCItem.MConfigWeapon)   ---@type MConfigWeapon
local weaponConfig    = require(MainStorage.code.common.MCItem.MCWeaponConfig)  ---@type MCWeaponConfig
local equipmentConfig = require(MainStorage.code.common.MCItem.MCEquipmentConfig)  ---@type MCEquipmentConfig
local gametaskConfig = require(MainStorage.code.common.MCTask.MCGameTaskConfig)  ---@type MCGameTaskConfig

-- 初始化任务目标类型
local OBJECTIVE_TYPES = {
    KILL = "kill",
    COLLECT = "collect",
    TALK = "talk",
    VISIT = "visit",
    USE_ITEM = "use_item",
    USE_SKILL = "use_skill",
    ESCORT = "escort",
    DEFEND = "defend",
    CRAFT = "craft",
    LEVEL_UP = "level_up",
    CUSTOM = "custom"
}

local typeText = {
    ["kill"] = "击杀目标",
    ["collect"] = "收集物品",
    ["talk"] = "对话",
    ["visit"] = "访问地点",
    ["use_item"] = "使用物品",
    ["use_skill"] = "使用技能",
    ["escort"] = "护送NPC",
    ["defend"] = "防御目标",
    ["craft"] = "制作物品",
    ["level_up"] = "升级",
    ["custom"] = "自定义目标"
}

local const_quality_name = {
    [1]='(普通)',
    [2]='(魔法)',
    [3]='(传奇)',
    [4]='(史诗)',
    [5]='(传说)',
}

local const_ui_eq_pos = {
    [ 1001 ] = '武器',
    [ 1002 ] = '盾牌',

    [ 1003 ] = '头盔',
    [ 1004 ] = '衣服',
    [ 1005 ] = '裤子',

    [ 1006 ] = '披风',
    [ 1007 ] = '鞋子',
    [ 1008 ] = '饰品',
}



--所有配置( 其他所有的配置文件将汇总到这里， 游戏逻辑代码只需要require这个文件即可 )
---@class common_config
local common_config = {

    assets_dict  = configAssets,

    common_attr     = configWeapon.common_attr,
    common_att_dict = configWeapon.common_att_dict,

    skill_def   = configSkill.skill_def,       -- InitSkillConfig 里会再次初始化一次数据
    buff_def    =  buffConfig.buff_def,

    scene_config = configScene,    -- 刷怪点
    npc_spawn_config  = configNpc, -- Npc刷新点

    --玩家
    default_player_battle_data = configPlayer.default_player_battle_data,
    dict_player_config         = configPlayer.dict_player_config,
    expLevelUp                 = configPlayer.expLevelUp,


    --怪物
    default_monster_battle_data = configMonster.default_monster_battle_data,
    monster_config              = configMonster.monster_config,   -- 怪物配置
    monster_battle_config       = configMonster.monster_battle_config,

    -- npc
    dict_npc_config  = {},
    -- 物品配置
    weapon_config  = weaponConfig, -- 武器
    equipment_config = equipmentConfig, --装备

    -- 任务配置
    main_line_task_config = gametaskConfig,
    objective_types = OBJECTIVE_TYPES,
    typeText = typeText,

    -- 武器相关
    const_quality_name = const_quality_name,
    const_ui_eq_pos = const_ui_eq_pos,
}




---------- utils 帮助函数 ----------------
--浅拷贝 不拷贝meta ( 与gg.table_value_copy 一致， 避免再次require文件 )
function common_config.table_value_copy(ori_tab)
    local new_tab = {}
    for i, v in pairs(ori_tab) do
        if  type(v) == "table" then
            new_tab[i] = common_config.table_value_copy(v)
        else
            new_tab[i] = v
        end
    end
    return new_tab
end




--初始化 dict_monster_config， 用来快速生成生物配置
function common_config.Init()

    --玩家属性表
    for seq_, config_ in pairs(common_config.dict_player_config) do
        --合并来自 common_config.default_player_battle_data 的属性
        for k, v in pairs( common_config.default_player_battle_data ) do     --{ hp=100, mp=100 }
            if  config_[ k ] == nil then
                --补全没有的基础属性
                if  type(v) == 'table' then
                    config_[ k ] = common_config.table_value_copy(v)
                else
                    config_[ k ] = v
                end
            end
        end
    end


    -- 怪物属性表
    common_config.dict_monster_config = {}
    for seq_, config_ in pairs( common_config.monster_config ) do     --{ id=100113,  battle='m1',   name='野人战士',  },

        --合并来自 common_config.default_monster_battle_data 的属性
        for k, v in pairs( common_config.default_monster_battle_data ) do     --{ hp=100, mp=100 }
            if  type(v) == 'table' then
                config_[ k ] = common_config.table_value_copy(v)
            else
                config_[ k ] = v
            end
        end
        --合并额外战斗属性 common_config.monster_battle_config  --m1 r1 s1
        if  config_.battle then
            local config_battle = common_config.monster_battle_config[ config_.battle ]
            if  config_battle then
                for k, v in pairs( config_battle ) do
                    if  type(v) == 'table' then
                        config_[ k ] = common_config.table_value_copy(v)
                    else
                        config_[ k ] = v
                    end
                end
            end
        end
        common_config.dict_monster_config[ config_.id ] = config_
    end


end
common_config.Init()


return common_config



-- obj.ModelId = 'sandboxSysId://entity/100028/body.omod'    -- 野人战士
--Legacy table={ 
    --1=1001011 2=1001001 3=100102 4=100103 5=100104 6=1001051 7=100112 8=200207 9=100109 10=100106 
    --11=100107 12=100122 13=100113 14=100164 15=100162 16=100159 17=100116 18=100114 19=200106 20=200107 
    --21=200108 22=200109 23=100127 24=100136 25=100137 26=100129 27=100139 28=100138 29=100141 30=100142 
    --31=100143 32=100144 33=100145 34=100146 35=100147 36=100148 37=100149 38=100150 39=100151 40=100153 
    --41=100154 42=100155 43=200209 44=100156 45=100140 46=100131 47=200208 48=200200 49=200201 50=100163 
    --51=200105 52=200104 53=200202 54=100108 55=200103 56=200100 57=200203 58=100160 59=100161 60=100124 
    --61=200204 62=200206 63=100812 64=200210 65=200213 66=200212 67=100100 68=100101 69=100105 70=200205 } 



-- obj.ModelId = 'sandboxSysId://entity/100113/body.omod'    -- 野人战士
-- obj.ModelId = 'sandboxSysId://entity/100114/body.omod'    -- 野人伍长
-- Legacy table={ 
    --1=100102 2=100103 3=100104 4=100112 5=200207 6=100109 7=100106 8=100107 9=100122 10=100113 
    --11=100164 12=100162 13=100159 14=100116 15=100114 16=200210 17=200107 18=200108 19=200109 20=100127 
    --21=100136 22=100137 23=100129 24=100139 25=100138 26=100141 27=100142 28=100143 29=100144 30=100145 
    --31=100146 32=100147 33=100148 34=100149 35=100150 36=100151 37=100153 38=100154 39=100155 40=200209 
    --41=100156 42=100140 43=100131 44=200208 45=200200 46=200201 47=100163 48=200105 49=200104 50=200202 
    --51=100108 52=200103 53=200100 54=200203 55=100160 56=100161 57=100124 58=200204 59=200206 60=100812 
    --61=200106 62=200213 63=200212 64=100130 65=100105 66=100101 67=100100 68=200205 69=600168 70=600129 
    --71=600130 72=600131 73=600132 74=600133 75=600128 76=600134 77=600135 78=600136 79=600137 80=600139 
    --81=600140 82=600138 83=600141 84=600143 85=600144 86=600145 87=600146 88=600147 89=600148 90=600142 
    --91=600149 92=600150 93=600151 94=600152 95=600153 96=600154 97=600155 98=600156 99=600157 100=600158 
    --101=600159 102=600160 103=600161 104=600162 105=600163 106=600164 107=600165 108=600166 109=600167 } 


-- obj.ModelId = 'sandboxSysId://entity/100063/body.omod'    -- 野人祭司
--Legacy table={ 1=100100 2=100101 3=100105 4=100111 5=100112 6=100106 7=100107 8=100130 } 


