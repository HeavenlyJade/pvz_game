

--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local math         = math
local game         = game
local pairs        = pairs


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const



-- 管理武器装备的生成

---@class EqGen
local EqGen = {}



local const_eq_pos = {
    [ 1001 ] = '之刃',
    [ 1002 ] = '之盾',

    [ 1003 ] = '头盔',
    [ 1004 ] = '长袍',
    [ 1005 ] = '护腿',

    [ 1006 ] = '披风',
    [ 1007 ] = '战鞋',
    [ 1008 ] = '饰物',
}



--[ 1001 ] = {},   --武器
--[ 1002 ] = {},   --盾牌

--[ 1003 ] = {},   --头盔
--[ 1004 ] = {},   --衣服
--[ 1005 ] = {},   --裤子

--[ 1006 ] = {},   --披风
--[ 1007 ] = {},   --鞋子
--[ 1008 ] = {},   --饰品


--装备类型 pos：     1001, 1002, 1003  ----  1008
--装备品质 quality:   1=白色普通  2=蓝色魔法*2  3=黄金传奇*3  4=粉色史诗*4  5=橙色传说*5



local const_pos_assets = {

    [1001] = {
        'sandboxSysId://items/icon11582.png',
        'sandboxSysId://items/icon12303.png',
        'sandboxSysId://items/icon12013.png',
        'sandboxSysId://items/icon12005.png',
        'sandboxSysId://items/icon12009.png',
        'sandboxSysId://items/icon12010.png',
        'sandboxSysId://items/icon12063.png',
        'sandboxSysId://items/icon12012.png',
    },   --武器

    [1002] = {
        'sandboxSysId://items/icon12317.png',
        'sandboxSysId://items/icon12318.png',
        'sandboxSysId://items/icon12319.png',
        'sandboxSysId://items/icon12309.png',
        'sandboxSysId://items/icon12598.png',
    },   --盾牌

    [1003] = {
        'sandboxSysId://items/icon12201.png',   --1
        'sandboxSysId://items/icon12211.png',
        'sandboxSysId://items/icon12216.png',
        'sandboxSysId://items/icon12221.png',
        'sandboxSysId://items/icon12231.png',   --5
        'sandboxSysId://items/icon12312.png',
        'sandboxSysId://items/icon12241.png',
    },    --头盔

    [1004] = {
        'sandboxSysId://items/icon12202.png',
        'sandboxSysId://items/icon12212.png',
        'sandboxSysId://items/icon12217.png',
        'sandboxSysId://items/icon12222.png',
        'sandboxSysId://items/icon12232.png',
        'sandboxSysId://items/icon12242.png',
        'sandboxSysId://items/icon12313.png',
    },    --衣服

    [1005] = {
        'sandboxSysId://items/icon12203.png',
        'sandboxSysId://items/icon12213.png',
        'sandboxSysId://items/icon12218.png',
        'sandboxSysId://items/icon12233.png',
        'sandboxSysId://items/icon12243.png',
    },    --裤子

    [1006] = {
        'sandboxSysId://items/icon12205.png',
        'sandboxSysId://items/icon12206.png',
        'sandboxSysId://items/icon12207.png',
        'sandboxSysId://items/icon12208.png',
        'sandboxSysId://items/icon12209.png',
        'sandboxSysId://items/icon12210.png',
    },    --披风

    [1007] = {
        'sandboxSysId://items/icon12204.png',
        'sandboxSysId://items/icon12214.png',
        'sandboxSysId://items/icon12219.png',
        'sandboxSysId://items/icon12224.png',
        'sandboxSysId://items/icon12244.png',
        'sandboxSysId://items/icon12234.png',
        'sandboxSysId://items/icon12204.png',
    },    --鞋子

    [1008] = {
        'sandboxSysId://items/icon12250.png',
        'sandboxSysId://items/icon12251.png',
        'sandboxSysId://items/icon12252.png',
        'sandboxSysId://items/icon11591.png',
        'sandboxSysId://items/icon12287.png',
    },    --饰品

}



--建立一个物品(捡到物品： 装备, 箱子，材料，道具，任务物品 )
function EqGen.pickup_create_item( item_info_ )
    if  item_info_.itype == common_const.ITEM_TYPE.BOX then
        return EqGen.createBox( item_info_ )    -- 箱子
    elseif  item_info_.itype == common_const.ITEM_TYPE.EQUIPMENT then
        return EqGen.createRandEquipment( item_info_ )

    elseif  item_info_.itype == common_const.ITEM_TYPE.MAT then
        return EqGen.createMat( item_info_ )
    else
        gg.log( 'error itype', item_info_.itype )
    end
end



-- 箱子
function EqGen.createBox( item_info_ )
    --{ uuid=dbxxx, model=drop_box_, level=self.level, quality=3 }
    local box_ = {
        uuid    = item_info_.uuid,
        quality = item_info_.quality,
        level   = item_info_.level,
        itype  = common_const.ITEM_TYPE.BOX,
        pos    = 0,       --不可装备到任何位置
        asset  = common_config.assets_dict.icon_box,
        name   = '宝箱-' .. gg.getQualityStr( item_info_.quality ),
    }
    return box_
end



-- 材料
function EqGen.createMat( item_info_ )
    --{ uuid=dbxxx, model=drop_box_, level=1, quality=1 }
    local box_ = {
        uuid    = item_info_.uuid,
        quality = item_info_.quality,
        level   = 1,
        num     = item_info_.num,
        itype   = common_const.ITEM_TYPE.MAT,
        mat_id  = common_const.MAT_ID.FRAGMENT,
        pos     = 0,       --不可装备到任何位置
        asset   = common_config.assets_dict.icon_mat1,
        name    = '魔力碎片',
    }
    return box_
end

-- 更具掉落物生成物品
function EqGen.createRandEquipment( info_ )
    gg.log( '根据掉落物生成物品', info_)
    local drop_item = info_.drop_item


    if not drop_item then
        return nil
    end
    local drop_type = drop_item.drop_type
    local item_id = drop_item.item_id

    local config_map = {
        epic_weapon = common_config.weapon_config.weapon_def,
        epic_equ = common_config.equipment_config.equipment_def
    }
    local temp  = config_map[drop_type]
    if not temp then
        return nil
    end
    gg.log("config_map",config_map)
    local item_info = config_map[drop_type][item_id]
    gg.log("equipment item_info",item_info,drop_type,item_id)
    item_info.uuid   = gg.create_uuid( 'eq_' )
    return item_info
end


--随机生成一个玩家的装备
function EqGen.debug_createRandEquipment()

    local ret_ = {
        bag_index = {},
        bag_items = {},
        bag_ver   = 1000,    --版本号(物品改动后+1)
        bag_size  = 36,      --背包大小
    }


    --装备
    -- for i=1, 8 do
    --     local pos_ = 1000 + i
    --     local eq_ = EqGen.createRandEquipment( { pos=pos_, quality=gg.rand_int_between(1,3), level=gg.rand_int_between(1,30) } )
    --     gg.log( '1111eq_', eq_)

    --     ret_.bag_items[ eq_.uuid ]  = eq_
    --     ret_.bag_index[ pos_ ] = { uuid=eq_.uuid }
    -- end

    ret_.bag_ver = ret_.bag_ver + 1   --装备改变
    return ret_
end





return EqGen