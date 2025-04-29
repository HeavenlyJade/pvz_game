--- V109 miniw-haima

local print         = print
local setmetatable  = setmetatable
local math          = math
local game          = game
local pairs         = pairs

local math_ceil     = math.ceil

local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const

-- 管理武器装备的词条管理

---@class EqAttr
local EqAttr        = {}



--计算一个生物的所有的属性值, 根据eq_attrs，temporary_buff 计算最终的battle_data
--ed={v=18} int={v=27} r0={v=18} sp3={v=9} cr={v=6}
---@param living CLiving
function EqAttr.visitAllAttr(living)
    --MConfigPlayer.default_player_battle_data = {
    --hp_max = 200,    --生命值
    --mp_max = 100,    --魔法值
    --str = 10,       --力量 增加物理攻击和防御
    --int = 10,       --智力 增加法术攻击力
    --agi = 10,       --敏捷 增加暴击率和命中
    --vit = 10,       --体力 增加hp最大值
    --attack   = 5,   --攻击随机下限
    --attack2  = 10,  --攻击随机上限
    --defence   = 1,   --防御随机下限
    --defence2  = 3,   --防御随机上限
    --spell    = 10,  --法术攻击下限
    --spell2   = 13,  --法术攻击上限
    --skills = {1001},    --技能列表
    --level_factor = 1,     --等级增长因子
    --}


    local battle_data_ = {} --最终属性结果

    --1 获取玩家武魂/怪物属性
    for k, v in pairs(living.battlt_config) do
        battle_data_[k] = v
    end

    --生物当前等级
    local level_ = living.level
    battle_data_.level = level_

    --计算等级增长因子
    local fc_ = battle_data_.level_factor * (level_ - 1)


    --2 计算基础值
    --每个级别四维都+1
    battle_data_.str = battle_data_.str + fc_ -- 力量
    battle_data_.int = battle_data_.int + fc_ -- 智力
    battle_data_.agi = battle_data_.agi + fc_ -- 敏捷
    battle_data_.vit = battle_data_.vit + fc_ -- 体力
    --来自装备的数值
    local attrs_ = living.eq_attrs
    local tmp_attrs = living.temporary_buff  -- 来自buff或者其它的一些临时数值

    local function addValueFromTable(dest, name, source)
        local value = source[name]
        if not value then
            return  -- 如果源表中没有该值，直接返回
        end
        
        -- 检查目标表中的值是否是表类型
        if type(dest[name]) == "table" and dest[name].v ~= nil then
            -- 如果值也是表且有v属性，则对v进行操作
            if type(value) == "table" and value.v ~= nil then
                dest[name].v = dest[name].v + value.v
            -- 如果值是数字，直接加到表的v属性上
            elseif type(value) == "number" then
                dest[name].v = dest[name].v + value
            end
        -- 如果目标不是表，但值是表且有v属性
        elseif type(value) == "table" and value.v ~= nil then
            -- 如果目标是数字
            if type(dest[name]) == "number" then
                dest[name] = dest[name] + value.v
            else
                -- 如果目标不存在或不是数字，直接赋值
                dest[name] = value.v
            end
        -- 如果两者都是简单的数值，执行常规加法
        elseif type(value) == "number" and type(dest[name]) == "number" then
            dest[name] = dest[name] + value
        end
    end

    --增加词条属性值
    local function addAttrValue(name_)
        if not battle_data_[name_] then
            battle_data_[name_] = 0
        end
        if tmp_attrs then
            addValueFromTable(battle_data_, name_, tmp_attrs)
        end
        addValueFromTable(battle_data_, name_, attrs_)
    end
    local baseAttrNames = { 'attack', 'attack2', 'spell', 'spell2', 'defence', 'defence2',
    'str', 'int', 'agi',  'vit','hp_max','mp_max',  'cr',  'crd',                                                                'speed',                                                     
    'dod','a_dod', 'hp_vam', 'mp_vam', 'rd0', 'rd0p','rd3','rd4', 'rd5','rd6','s3','s4','s5','s6',
    'sp3','sp4','sp5','sp6','r3','r4','r5','r6','rd_melee','rd_spell' }
    for _, name in ipairs(baseAttrNames) do
        addAttrValue(name)
    end


    battle_data_.hp_max   = battle_data_.hp_max + battle_data_.vit * 2 -- 生命力，由体力计算公式
    --上
    battle_data_.attack   = battle_data_.attack + battle_data_.str * 0.5   -- 攻击上限 计算公式
    battle_data_.defence  = battle_data_.defence + battle_data_.str * 0.125 --力量会轻度增加防御
    battle_data_.spell    = battle_data_.spell + battle_data_.int * 0.25
    --下限
    battle_data_.attack2  = battle_data_.attack2 + battle_data_.str
    battle_data_.spell2   = battle_data_.spell2 + battle_data_.int * 0.5
    battle_data_.defence2 = battle_data_.defence2 + battle_data_.str * 0.25 --强壮会轻度增加防御



    battle_data_.cr    = 5 + battle_data_.agi * 0.05  --暴击 100级别 5+5  agi 敏捷暴击
    battle_data_.crd   = 50                           --暴伤 加成

    battle_data_.speed = 0

    battle_data_.dod   = 5 + battle_data_.agi * 0.05  --躲闪
    battle_data_.a_dod = 0 + battle_data_.agi * 0.03  --命中 100级别 0+3

    --物理
    if attrs_.ed then
        battle_data_.attack  = battle_data_.attack + attrs_.ed.v
        battle_data_.attack2 = battle_data_.attack2 + attrs_.ed.v
    end

    if attrs_.edp then
        battle_data_.attack  = battle_data_.attack * (1 + attrs_.edp.v * 0.01)
        battle_data_.attack2 = battle_data_.attack2 * (1 + attrs_.edp.v * 0.01)
    end

    --法系
    if attrs_.es then
        battle_data_.spell  = battle_data_.spell + attrs_.es.v
        battle_data_.spell2 = battle_data_.spell2 + attrs_.es.v
    end

    if attrs_.esp then
        battle_data_.spell  = battle_data_.spell * (1 + attrs_.esp.v * 0.01)
        battle_data_.spell2 = battle_data_.spell2 * (1 + attrs_.esp.v * 0.01)
    end


    --所有抗性，直接加到三种元素上
    --addAttrValue( 'all_rs' )
    if attrs_.all_rs then
        battle_data_.r3 = attrs_.all_rs.v --水
        battle_data_.r4 = attrs_.all_rs.v --电
        battle_data_.r5 = attrs_.all_rs.v --火
        battle_data_.r6 = attrs_.all_rs.v --木
    end


    --防御值，直接加到防御值上
    if attrs_.r0 then
        battle_data_.defence  = battle_data_.defence + attrs_.r0.v
        battle_data_.defence2 = battle_data_.defence2 + attrs_.r0.v
    end

    --关键属性整数化
    battle_data_.hp_max   = math.floor(battle_data_.hp_max)
    battle_data_.mp_max   = math.floor(battle_data_.mp_max)
    battle_data_.attack   = math.floor(battle_data_.attack)
    battle_data_.spell    = math.floor(battle_data_.spell)
    battle_data_.defence  = math.floor(battle_data_.defence)
    battle_data_.attack2  = math.floor(battle_data_.attack2)
    battle_data_.spell2   = math.floor(battle_data_.spell2)
    battle_data_.defence2 = math.floor(battle_data_.defence2)


    --百分比数值转换
    local fields = {"dod","a_dod","cr","crd","sp2", "sp3", "sp4", "rd0p", "rd3", "rd4", "rd5", "rd6", "r3", "r4","r5", "r6",}
    for _, field in ipairs(fields) do
        if battle_data_[field] then
            battle_data_[field] = battle_data_[field] * 0.01
        end
    end
    --保留原来的hp mp值
    battle_data_.hp = living.battle_data.hp
    battle_data_.mp = living.battle_data.mp
    living.battle_data = battle_data_
end

return EqAttr
