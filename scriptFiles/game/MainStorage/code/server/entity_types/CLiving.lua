--- V109 miniw-haima

local print        = print
local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local Enum         = Enum
local math         = math
local Vector2      = Vector2
local ColorQuad    = ColorQuad
local wait         = wait
local game         = game
local pairs        = pairs
local coroutine    = coroutine
local next         = next


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const

local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule

local skillMgr          = require(MainStorage.code.server.skill.MSkillMgr)    ---@type SkillMgr
local eqAttr            = require(MainStorage.code.server.equipment.MEqAttr)  ---@type EqAttr
local cloudDataMgr      = require(MainStorage.code.server.MCloudDataMgr)      ---@type MCloudDataMgr




--local StartPlayer = game:GetService("StartPlayer")
--local MainServer = require( game:GetService("MainStorage"):WaitForChild('code').server.MServerMain )
--local PlayerModule = require( StartPlayer.StarterPlayerScripts.PlayerModule )


local BATTLE_STAT_IDLE       = common_const.BATTLE_STAT.IDLE
local BATTLE_STAT_FIGHT      = common_const.BATTLE_STAT.FIGHT
local BATTLE_STAT_DEAD_WAIT  = common_const.BATTLE_STAT.DEAD_WAIT
local BATTLE_STAT_WAIT_SPAWN = common_const.BATTLE_STAT.WAIT_SPAWN



---@class CLiving  管理单个场景中的actor实例和有共性的属性，被包含在 player monster boss中
---@field info any
---@field uuid string
---@field uin  number
---@field cd_list any
---@field tick number
---@field wait_tick number
---@field stat_flags any
---@field npc_type NPC_TYPE
---@field battle_stat_func any[]
---@field battle_stat BATTLE_STAT
---@field stat_data any
---@field weapon_speed number
---@field model_weapon any
---@field actor any
---@field target CPlayer | CMonster
---@field orgMoveSpeed number
---@field New function      --New=OnInit
local _M = CommonModule.Class("CLiving")        --父类 (子类： CPlayer, CMonster )
function _M:OnInit( info_ )
    self.info = info_      --{ x,y,z, uin, level, npc_type, owner }
    self.uuid = nil
    self.uin  = info_.uin
    self.exp   = 0     --当前经验值
    self.level = 1     --当前等级
    self.drop_items = info_.drop_items  -- 怪物掉落物配置
    self.npc_type   = common_const.NPC_TYPE.INITING   --NPC类型

    self.scene_name = nil           --场景名字 g0 g10 g20
    --self.pre_scene_name = nil       --准备前往的场景名字

    self.scene      = nil           --当前场景

    self.actor         = nil        --game_actor
    self.target        = nil        --当前目标 actor

    self.orgMoveSpeed  = 0          --common_const.MOVESPEED, --原始速度

    self.weapon_speed  = 1          --武器速度，默认1.0
    self.model_weapon  = nil        --武器

    --self.attack_box    = nil      --debug攻击范围

    self.bb_title   = nil           --头顶名字和等级 billboard
    self.bb_damage  = nil           --伤害飘字

    self.cd_list = {}               --cd列表
    --debug_anim_index = 0       --debug


    self.tick  = 0                   --总tick值(递增)
    self.wait_tick = 0               --等待状态tick值(递减)（剧情使用）

    self.last_anim = ''              --最后一个播放的动作


    self.battle_stat_func = {}                   --状态机函数
    self.battle_stat  = BATTLE_STAT_IDLE         --战斗状态： 空闲 战斗 死亡 复活

    self.stat_data = {     --每个状态下的数据
        idle  = { select=0,   wait=0 },    --monster
        fight = { wait=0 },                --monster

        wait_spawn = { wait=0 },
        dead_wait  = { wait=0 },
    }

    self.battlt_config = nil    --战斗配置
    self.battle_data = {        --战斗数据
        --(先复制battle_config)
        --skills
        --hp mp hp_max mp_max
        --attack_speed
    }
    self.eq_attrs = {}         --所有装备词缀
    self.temporary_buff ={}    -- 临时的buff的数值

    self.stat_flags  = {        --玩家状态标志位
        --skill_uuid            --当前技能实例uuid( 释法中 )
        --cast_time             --技能施法时间
        --cast_time_max         --技能施法时间最大值
        --cast_pos              --施法开始时候的位置

        --stun = 1              --晕迷
        --stun_tick = 10,       --晕迷时间
        --slow = 1              --减速
        --slow_tick = 10,       --减速时间
        --swim = 1              --游泳中
    }

    if  info_.npc_type then
        self.npc_type = info_.npc_type      --1=player 2=monster 3=npc 4=ai
    end

    if  info_.exp then
        self.exp = info_.exp
    end

    if  info_.level then
        self.level = info_.level
    end

    if  info_.scene_name then
        self.scene_name = info_.scene_name
    end

end



--设置游戏场景中使用的actor实例
function _M:setGameActor( actor_ )
    self.actor = actor_
    --self.actor:UseDefaultAnimation(false);     --取消默认动作(自行用代码控制)

    actor_.PhysXRoleType    = Enum.PhysicsRoleType.BOX
	actor_.IgnoreStreamSync = false

    --self.actor.MaxHealth = 200
    --self.actor.Health = 100

    if  self.orgMoveSpeed == 0 then
        self.orgMoveSpeed = self.actor.Movespeed
    end

end


--是否是一个玩家
function _M:isPlayer()
    return self.npc_type == common_const.NPC_TYPE.PLAYER
end

function _M:isNpc()
    return self.npc_type == common_const.NPC_TYPE.NPC
end

--玩家切换目标
---@param target_ CPlayer | CMonster
function _M:changeTarget( target_ )
    self.target = target_

    if  self:isPlayer() then
	    gg.network_channel:fireClient( self.uin, { cmd='cmd_change_target', scene_name=self.scene_name, uin=self.uin,  v=target_.uuid } )
        self:syncTargetInfo( target_, true )
    end
end



--同步给客户端当前目标的资料
function _M:syncTargetInfo( target_, with_name_ )
    local info_ = {
        cmd    = 'cmd_sync_target_info',
        show = 1,   --0=不显示， 1=显示

        hp     = target_.battle_data.hp,
        hp_max = target_.battle_data.hp_max,

        mp     = target_.battle_data.mp,
        mp_max = target_.battle_data.mp_max,
    }

    if  with_name_ then
        info_.name = target_.info.nickname
    end

    gg.network_channel:fireClient( self.uin, info_ )
end



--被击中
---@param target_ CPlayer | CMonster
function _M:been_hit( target_ )
    if  not self.target then
        self:changeTarget(target_)
    end

    if  self.battle_stat == BATTLE_STAT_IDLE then
        self:setBattleStat( BATTLE_STAT_FIGHT )
    end

    if  not self:isPlayer() then
        self:calculateMoveSpeed()
        self.scene:updateTargetHPMPBar( self.uuid )    --怪物更新观察者player血条
    end
end



--玩家跳跃
function _M:doJump()
    self.actor:Jump(true)
end


--hp为0
function _M:checkDead()
    self:setBattleStat( BATTLE_STAT_DEAD_WAIT )
end



--增加经验值
function _M:addExp( exp_ )
    self.exp = self.exp + exp_

    local save_flag_ = false
    if  common_config.expLevelUp[ self.level + 1 ] then
        --是否升级
        if  self.exp >= common_config.expLevelUp[ self.level + 1 ] then
            self.level = self.level + 1
            self:resetBattleData( true )
            save_flag_ = true

            gg.log( 'addExp levelUp:', self.exp, self.level  )
            self:showDamage( 0, { levelup=self.level } )

            --展示特效
            self:showReviveEffect( self.actor.Position )
        end
    end

    cloudDataMgr.savePlayerData( self.uin, save_flag_ )   --加经验存盘
end



--获得经验值
function _M:getMonExp()
    return  10*self.level;        --1级10经验  10级100经验
end



-- 怪物头部出现的名字和等级
-- { name=desc_.name, level=self.level, high=0 }
function _M:createTitle( desc_ )
    if  not self.bb_title then
        local name_level_billboard = SandboxNode.new( 'UIBillboard', self.actor )
        name_level_billboard.Name = 'name_level'
        name_level_billboard.Billboard = true
        name_level_billboard.CanCollide = false            --避免产生物理碰撞
        name_level_billboard.Size2d    = Vector2.new(5,5)

        local high = 286 + (desc_.high or 0)   --名字高度
        name_level_billboard.LocalPosition = Vector3.new( 0, high, 0 )
        name_level_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X


        local number_level = gg.createTextLabel( name_level_billboard, desc_.name .. ' ' .. (desc_.level or self.level) )
        number_level.ShadowEnable = true
        number_level.ShadowOffset = Vector2.new( 3, 3 )

        if ( desc_.level or 1 ) > 50 then
            number_level.TitleColor  = ColorQuad.new( 255,   0,   0, 255 )
            number_level.ShadowColor = ColorQuad.new( 0, 0, 0, 255 )
        else
            number_level.TitleColor  = ColorQuad.new( 255, 255,  0,  255 )
            number_level.ShadowColor = ColorQuad.new( 0, 0, 0, 255 )
        end

        self.bb_title = number_level        
        if self:isNpc() then else
            self:createHpBar( name_level_billboard )
        end
        -- self:enableAnimateDebugTest();     --是否打开动画测试
    end
end



--血条
function _M:createHpBar( root_ )
    local bg_  = SandboxNode.new( "UIImage", root_ )
    local bar_ = SandboxNode.new( "UIImage", root_ )

    bg_.Name = 'spell_bg'
    bar_.Name = 'spell_bar'

    bg_.Icon  = common_config.assets_dict.icon_hp_bar
    bar_.Icon = common_config.assets_dict.icon_hp_bar

    bg_.FillColor  = ColorQuad.new( 255, 255, 255, 255 )
    bar_.FillColor = ColorQuad.new( 255, 0, 0, 255 )

    bg_.LayoutHRelation = Enum.LayoutHRelation.Middle
    bg_.LayoutVRelation = Enum.LayoutVRelation.Bottom

    bar_.LayoutHRelation = Enum.LayoutHRelation.Middle
    bar_.LayoutVRelation = Enum.LayoutVRelation.Bottom

    bg_.Size   = Vector2.new(256, 32)
    bar_.Size  = Vector2.new(256, 32)

    bg_.Pivot  = Vector2.new(0.5, -1.5)
    bar_.Pivot = Vector2.new(0.5, -1.5)

    bar_.FillMethod = Enum.FillMethod.Horizontal
    bar_.FillAmount = 1

    --bg_.Position  = Vector2.new( 0, -32 )
    --bar_.Position = Vector2.new( 0, -32 )
    self.hp_bar = bar_

end




-- 显示伤害飘字，闪避，升级
function _M:showDamage( number_, eff_ )

    --无伤害，无特殊效果
    if  number_ == 0 then
        if  not next( eff_ ) then
            return   --没有特别效果
        end
    end


    local damage_billboard = SandboxNode.new( 'UIBillboard', self.actor )
    damage_billboard.Name  = 'dmg'
    damage_billboard.Billboard       = true
    damage_billboard.CanCollide      = false            --避免产生物理碰撞
    damage_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X


    local xx = gg.rand_int_between( -10, 10 )
    local yy = gg.rand_int_between( -10, 10 )

    if  self:isPlayer() then
        damage_billboard.Size2d          = Vector2.new( 5, 5 )
        damage_billboard.LocalPosition   = Vector3.new( xx, 258+yy, 0 )
    else
        damage_billboard.Size2d          = Vector2.new( 8, 8 )
        damage_billboard.LocalPosition   = Vector3.new( xx, 330+yy, 0 )
    end


    local function wrap_thread( time_ )
        local function long_call( damage_billboard_ )
            wait(time_)
            damage_billboard_:Destroy()
        end
        coroutine.work( long_call, damage_billboard )    --立即返回，long_call转入协程执行
    end

    if  eff_.dodge == 1 then
        --闪避
        local number_level = gg.createTextLabel( damage_billboard, '闪避' )
        number_level.TitleColor = ColorQuad.new( 255, 255, 255, 255 )  --白色字
        wrap_thread( 1 )

    elseif  eff_.levelup then
        --升级
        local number_level = gg.createTextLabel( damage_billboard, '等级升级到' .. eff_.levelup )
        number_level.TitleColor = ColorQuad.new( 255, 255, 255, 255 )  --白色字
        wrap_thread( 2.5 )

    elseif eff_.bag_full == 1 then
        local number_level = gg.createTextLabel( damage_billboard, '背包已满' )
        number_level.TitleColor = ColorQuad.new( 255, 255, 255, 255 )  --白色字
        wrap_thread( 1 )
    else
        -- 伤害值
        local number_level = gg.createTextLabel( damage_billboard, '-' .. number_ )

        if  self:isPlayer() then
            number_level.TitleColor = ColorQuad.new( 255, 0, 0, 255 )      --红色字
        else
            if  eff_ and eff_.cr == 1 then
                damage_billboard.Size2d = Vector2.new( 16, 16 )
                number_level.TitleColor = ColorQuad.new( 255, 255, 0,   255 )  --黄字
            else
                number_level.TitleColor = ColorQuad.new( 255, 255, 255, 255 )  --白色字
            end
        end
        wrap_thread( 1 )
    end
end



-- 在actor头顶上显示一个文字
function _M:showTips( msg_ )
    local damage_billboard = SandboxNode.new( 'UIBillboard', self.actor )
    damage_billboard.Name  = 'tips'
    damage_billboard.Billboard       = true
    damage_billboard.CanCollide      = false            --避免产生物理碰撞
    damage_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X

    if  self:isPlayer() then
        damage_billboard.Size2d          = Vector2.new( 3, 3 )
        damage_billboard.LocalPosition   = Vector3.new( 0, 258, 0 )
    else
        damage_billboard.Size2d          = Vector2.new( 8, 8 )
        damage_billboard.LocalPosition   = Vector3.new( 0, 330, 0 )
    end
    local txt_ = gg.createTextLabel( damage_billboard, msg_ )
    txt_.RenderIndex = 101   --在高层展示
    --self.bb_damage = damage_billboard;
    local function long_call( damage_billboard_ )
        wait(0.5)
        damage_billboard_:Destroy()
    end
    coroutine.work( long_call, damage_billboard )    --立即返回，long_call转入协程执行
end



--装备一个武器
function _M:equipWeapon( model_src_ )
    if  self.actor.Hand then
        local model = SandboxNode.new('Model', self.actor.Hand )
        model.Name       = 'weapon'

        model.EnablePhysics = false
        model.CanCollide    = false
        model.CanTouch      = false

        model.ModelId    = model_src_     --模型
        model.LocalScale = Vector3.new( 2, 2, 2 )


        self.model_weapon = model

        --model.TextureId  =      --皮肤
        --model.Size   = Vector3.new( 80, 80, 100 )
        --model.Center = Vector3.new( 40, 40,  50 )
        --model.LocalPosition = Vector3.new( -50, -43, -45 )  --模型中点偏移量

        --[[判断击中目标 建立一个可碰撞体
        if  self.model_weapon.toucher then
            --已经建立
        else
            local model_toucher      = SandboxNode.new('GeoSolid', self.model_weapon )
            model_toucher.Name       = 'toucher'
            model_toucher.LocalScale    = Vector3.new( 0.1, 1, 0.1 )
            model_toucher.LocalPosition = Vector3.new( 0,  50, 0 )
            model_toucher.Size          = Vector3.new( 100, 100, 100 )

            model_toucher.EnablePhysics = true
            model_toucher.CanCollide    = false
            model_toucher.CanTouch      = true   --可以接触

            model_toucher.Touched:connect( function(node, pos, normal)
                gg.log( '==== sword Touched ', node, node.Tag, node.Name );
            end )
        end
        --]]


    end
end



--玩家改变场景   g10 g20 g30
function _M:changeScence( new_name_ )
    if  self.scene_name == new_name_ then
        return
    end

    --离开旧场景
    if  self.scene_name then
        local scene_ = gg.server_scene_list[ self.scene_name ]
        if  scene_ then
            if  self:isPlayer() then
                scene_:player_leave( self.uin )
            end
        else
            gg.log( 'error player_leave, not find scene:', self.scene_name )
        end

        gg.log( scene_.name, ' player_leave====', self.uin )
    end


    --进入新场景
    self.scene_name = new_name_
    gg.network_channel:fireClient( self.uin, { cmd='change_scene_ok', v=new_name_ } )  --同步给客户端

    local scene_ = gg.server_scene_list[ new_name_ ]
    if  scene_ then
        if  self:isPlayer() then
            scene_:player_enter( self.uin )
        end
        self.scene = scene_
    else
        gg.log( 'error player_enter, not find scene:', new_name_ )
    end

    gg.log( scene_.name, ' player_enter====', self.uin )

end




-- 播放一个动作
-- id 动作id    -- 1=100100(stand) 2=100130(下蹲) 3=100101(run)
-- speed:          动作播放速度  1=正常速度  0.5=半速慢动作
-- loop:是否循环    0=循环  1=单次  2=单次后定在最后一帧
function _M:play_animation( id_, speed_, loop_ )

    --gg.log( 'play_animation', self.uuid, id_, speed_, loop_ )

    if  self.last_anim == id_ then
        if  loop_ == 0 then
            return    --循环且相同的动作
        end
    else

        if  self:isPlayer() then
        end

        self.actor:StopAllAnimation(false)
        self.last_anim = id_
    end

    if  self.battle_stat == BATTLE_STAT_DEAD_WAIT then
        self.actor:PlayAnimation( '100106', 1.0, 2  );    --播放动作
    else
        self.actor:PlayAnimation( id_, speed_, loop_  );   --播放动作
    end

end



-- 测试使用，怪物触碰后，播放一个动作
function _M:enableAnimateDebugTest()
    local const_anim_ =  { 100955, 100101, 100102 }

    --TouchEnded Touched
    self.actor.TouchEnded:connect( function(node, pos1, normal1 )
        if  node  then
            self.debug_anim_index = (self.debug_anim_index or 0) + 1
            local index_ = self.debug_anim_index % #const_anim_ + 1    --循环播放
            local anim_name_ = '' .. const_anim_[ index_ ]

            self.bb_title.Title = anim_name_;
            self:play_animation( anim_name_, 1, 0 );
        end
    end )

end



--检测攻击前置条件： cd时间  mp魔法值 等
function _M:checkAttackSpellConfig( skill_id_, skill_config_ )

    if  skill_config_.speed == 1 then
        --攻速
        if  not self.cd_list[ skill_id_ ] then
            self.cd_list[ skill_id_ ] = { last=-1000 }
        end

        local attack_speed = self:getAttackSpeedTick()
        if  gg.tick - self.cd_list[ skill_id_ ].last > attack_speed then
            --self.cd_list[ skill_id_ ].last = gg.tick
        else
            return 1  --检查speed攻速失败
        end

    elseif  skill_config_.cd and skill_config_.cd > 0 then
        --技能cd
        if  not self.cd_list[ skill_id_ ] then
            self.cd_list[ skill_id_ ] = { last=-1000 }
        end

        if  gg.tick - self.cd_list[ skill_id_ ].last > skill_config_.cd then
            --self.cd_list[ skill_id_ ].last = gg.tick
        else
            return 2   --检查cd失败
        end

    end


    --魔法值
    if  skill_config_.mp and skill_config_.mp>0 then
        if  self.battle_data.mp < skill_config_.mp then
            return 9   --检查魔法值失败
        end
    end

    return 0
end



--怪物的魔法值耗尽，切换近战技能
function _M:outOfMana()
    self.battle_data.skills = {1001}
end



--获得攻速帧
function _M:getAttackSpeedTick()
    --默认攻速都是1.2=12帧   1=10帧
    if  not self.battle_data.attack_speed then
        self.battle_data.attack_speed = self.weapon_speed * 10
        gg.log( 'set AttackSpeedTick:', self.battle_data.attack_speed )
    end
    return self.battle_data.attack_speed
end



--施法成功后，设置cd并扣除魔法值
function _M:setAttackSpellByConfig( skill_id_, skill_config_ )

    if  skill_config_.speed == 1 then
        self.cd_list[ skill_id_ ].last = gg.tick             --攻速
    elseif  skill_config_.cd and skill_config_.cd > 0 then
        self.cd_list[ skill_id_ ].last = gg.tick             --技能cd

        --同步给客户端
        gg.network_channel:fireClient( self.uin, { cmd='cmd_cd_list', tick=gg.tick, v=self.cd_list } )
    end

    --魔法值
    if  skill_config_.mp and skill_config_.mp > 0 then
        self.battle_data.mp = self.battle_data.mp - skill_config_.mp
        self:refreshHpMpBar()
    end
end



--初始化战斗数值和状态机
function _M:initBattleData( config_ )
    self.battlt_config = config_
    self:resetBattleData( true )

    self:initBattleStatFunc()
end



--重置所有属性
function _M:resetBattleData( resethpmp_ )
    eqAttr.visitAllAttr( self )

    if  self:isPlayer() then
        -- gg.log( '玩家属性重新计算======', self.uin, self.uuid, self.battle_data )
        
    else
        --怪物血量加成 battle_data_.hp_factor
        if  self.battle_data.hp_factor then
            self.battle_data.hp_max = self.battle_data.hp_max * self.battle_data.hp_factor
        end
    end


    if  resethpmp_ then
        self.battle_data.hp = self.battle_data.hp_max
        self.battle_data.mp = self.battle_data.mp_max
    end

    --控制血量最大值
    if  self.battle_data.hp > self.battle_data.hp_max then self.battle_data.hp = self.battle_data.hp_max end
    if  self.battle_data.mp > self.battle_data.mp_max then self.battle_data.mp = self.battle_data.mp_max end

    self:refreshHpMpBar()
    self:calculateMoveSpeed()
end




function _M:refreshHpMpBar()
    if  self.hp_bar then
        local rate_ =  self.battle_data.hp / self.battle_data.hp_max
        self.hp_bar.FillAmount = rate_
    end

    if  self.mp_bar then
        local rate_ =  self.battle_data.mp / self.battle_data.mp_max
        self.mp_bar.FillAmount = rate_
    end


    if  self:isPlayer() then
        --通知改变客户端显示
        gg.network_channel:fireClient( self.uin, { cmd='cmd_player_hpmp',
            hp=self.battle_data.hp, hp_max=self.battle_data.hp_max,
            mp=self.battle_data.mp, mp_max=self.battle_data.mp_max
        } )
    else
        if  self.scene then
            self.scene:updateTargetHPMPBar( self.uuid )    --怪物更新观察者player血条
        end
    end

end



--释放加血加魔
function _M:spellHealth( hp_, mp_ )
    --加上法强
    local spell_add_ = gg.rand_int_between(self.battle_data.spell, self.battle_data.spell2 )

    self.battle_data.hp = self.battle_data.hp + hp_ + spell_add_
    if  self.battle_data.hp > self.battle_data.hp_max then
        self.battle_data.hp = self.battle_data.hp_max
    end
    self:refreshHpMpBar()

end



--复活
function _M:revive()
    self.actor.Visible = true
    self:resetBattleData( true )  --重置所有属性

    if  self:isPlayer() then
        self.target = nil         --怪物复活 失去目标
    end
    self:setBattleStat( BATTLE_STAT_IDLE )
    self:play_animation( '100100', 1.0, 0 )   --idle

    gg.network_channel:fireClient( self.uin, { cmd='cmd_player_actor_stat', v='revive',
        hp=self.battle_data.hp, hp_max=self.battle_data.hp_max,
        mp=self.battle_data.mp, mp_max=self.battle_data.mp_max
    } )

end



--判断当前目标是否丢失(隐身 复活中)
function _M:checkTargetLost()
    if  self.target.battle_stat == BATTLE_STAT_WAIT_SPAWN then
        gg.log( 'checkTargetLost1', self.uuid )
        self.scene:infoTargetLost( self.target.uuid )
        self.target = nil

    elseif  self.target.actor.Visible == false then
        gg.log( 'checkTargetLost2', self.uuid )
        self.scene:infoTargetLost( self.target.uuid )
        self.target = nil

    end

end



--获得怪物的配置：第一技能和攻击距离（怪物使用）
function _M:getSkill1AndRange()
    local skill_id_ = self.battle_data.skills[1]
    local range_ = common_config.skill_def[ skill_id_ ].range
    --gg.log( 'getSkill1AndRange:', skill_id_, range_ )
    return  skill_id_, range_
end



--设置攻击前置时间， 施法前摇，标志位和时间
function _M:setSkillCastTime( skill_uuid_, cast_time_ )
    local stat_flags_ = self.stat_flags
    if  stat_flags_.skill_uuid then
        self:showTips( '正在施法中')   --.. (stat_flags_.cast_time or 'nil') .. '/' .. (stat_flags_.cast_time_max or 'nil' ) )
        return 1
    else
        stat_flags_.skill_uuid    = skill_uuid_
        stat_flags_.cast_time     = cast_time_
        stat_flags_.cast_time_max = cast_time_

        stat_flags_.cast_pos = self.actor.Position

        gg.network_channel:fireClient( self.uin, { cmd='cmd_player_spell', v=stat_flags_.cast_time, max=stat_flags_.cast_time_max } )
        return 0
    end
end



--被减速
function _M:slowDown( tick_, v_ )
    local stat_flags_ = self.stat_flags
    gg.log( 'slowDown', self.actor.Movespeed, v_ )

    stat_flags_.slow_tick = tick_
    stat_flags_.slow = v_

    self:calculateMoveSpeed()
end



--计算行走速度
function _M:calculateMoveSpeed()
    local speed_ = self.orgMoveSpeed

    if  not self:isPlayer() then
        --怪物的速度，血量越低越慢
        local rate_ =  self.battle_data.hp / self.battle_data.hp_max
        if     rate_ < 0.5  then rate_ = 0.5
        elseif rate_ > 1    then rate_ = 1    end
        speed_ = speed_ * rate_
    end
    if  self.stat_flags.slow then speed_ = speed_ * self.stat_flags.slow end
    if  self.actor then self.actor.Movespeed = speed_ end

end



--展示复活特效
function _M:showReviveEffect( pos_ )
    local function thread_wrap()
        --爆炸特效
        local expl = SandboxNode.new('DefaultEffect', self.actor )
        expl.AssetID = common_config.assets_dict.effect.revive_effect
        expl.Position = Vector3.new( pos_.x, pos_.y, pos_.z )
        expl.LocalScale = Vector3.new( 3, 3, 3 )
        wait(1.5)
        expl:Destroy()
    end
    gg.thread_call( thread_wrap )
end



--无法被攻击状态
function _M:canNotBeenAttarked()
    if  self.battle_stat == BATTLE_STAT_DEAD_WAIT or
        self.battle_stat == BATTLE_STAT_WAIT_SPAWN then
        return true
    end
    return false
end



--检查异常状态
--skill_uuid = 1        --释法中 cast_time
--stun = 1              --晕迷
--slow = 1              --减速
--swim = 1              --游泳中
function _M:checkAbnormalStatFlags( tick_ )
    local stat_flags_ = self.stat_flags

    --始发中
    if  stat_flags_.skill_uuid then
        if  stat_flags_.cast_time > 0 then
            stat_flags_.cast_time = stat_flags_.cast_time - tick_

            if  gg.out_distance( stat_flags_.cast_pos, self.actor.Position, 2 ) then    --distance=2
                --取消施法
                stat_flags_.skill_uuid = nil
                stat_flags_.cast_time  = nil
                stat_flags_.cast_pos   = nil
                self:play_animation( '100101', 1.0, 0 )   --walk
                gg.network_channel:fireClient( self.uin, { cmd='cmd_player_spell', v=0.1, max=0.1 } )

            else
                self:play_animation( '100112', 1.0, 0 )   --spell
            end

        else
            --施法结束
            local skill_id_ = stat_flags_.skill_uuid
            stat_flags_.skill_uuid = nil
            stat_flags_.cast_time  = nil
            stat_flags_.cast_pos   = nil
            skillMgr.castTimeOver( skill_id_ )    --防施法卡死
        end
    end


    --减速中
    if  stat_flags_.slow then
        if  stat_flags_.slow_tick > 0 then
            stat_flags_.slow_tick = stat_flags_.slow_tick - tick_
        else
            stat_flags_.slow      = nil
            stat_flags_.slow_tick = nil
            self:calculateMoveSpeed()
        end
    end

end


-- 修改玩家的属性
function _M:applyAttributeModifier(property_name, value, mode)
    -- 确保battle_data和指定属性存在
    if not self.battle_data or not self.battle_data[property_name] then
        return
    end
    
    -- 获取当前属性值
    local current_value = self.battle_data[property_name]
    
    -- 根据模式进行不同的计算
    if mode == "absolute" then
        -- 绝对值模式：直接添加数值
        self.temporary_buff[property_name] = value
    elseif mode == "percent" then
        -- 百分比模式：按百分比增加
        -- value为0.1表示增加10%，value为-0.2表示减少20%
        local increase = current_value * value
        self.battle_data[property_name] =increase
    else
  
    end
end
function _M:createLootFromConfig(attacker_ ,target_)
    local drop_items = target_.drop_items -- 掉落物的配置
    if not drop_items then
        return
    else
        for i, item in ipairs(drop_items) do
            local rand_value = math.random(1, 10000)/10000
            if rand_value <= item.drop_rate then
                -- 掉落成功，调用 dropBox
                self:dropBox(attacker_, item)
            end
        end
    end
    
end

--掉落物品
function _M:dropBox( attacker_ ,drop_item)
    --建立模型
    local drop_box_    = gg.cloneFromTemplate('drop_box')     --克隆（速度更快）
    drop_box_.Parent   = gg.serverGetContainerMonster( self.scene_name )
    drop_box_.Name     = 'drop'
    drop_box_.Visible  = true

    --起始点
    local pos_ = self.actor.Position
    drop_box_.Position = Vector3.new( pos_.x + gg.rand_int(50), pos_.y + 50, pos_.z + gg.rand_int(50) )
    drop_box_.LocalScale = Vector3.new( 0.25, 0.5, 0.5 )
    drop_box_.Anchored       = false
    drop_box_.EnableGravity  = true
    drop_box_.CanCollide     = true
    drop_box_.CanTouch       = true
    drop_box_.CollideGroupID = 2  --设置为玩家可以碰撞
    drop_box_.Friction       = 0.5


    local drop_item = { 
        uuid=gg.create_uuid('box'),
        itype=common_const.ITEM_TYPE.EQUIPMENT,
        model=drop_box_,
        level= gg.rand_int_between(1, self.level), 
        player_uin = attacker_.uin,
        quality=gg.rand_qulity(),
        drop_item = drop_item
    }
    if  self.scene then
        self.scene:addDrop( drop_item )
    end
    drop_box_.EnableGravity  = false
    drop_box_.CanCollide     = false
    drop_box_.OwnerUin   = attacker_.uin
    drop_box_.Size       = Vector3.new( 1, 1, 1  )
    drop_box_.Center     = Vector3.new( 0,   0,  0 )
    --特效
    local expl = SandboxNode.new('DefaultEffect', drop_box_ )
    expl.AssetID = common_config.assets_dict.effect.drop_box_effect
    expl.LocalPosition = Vector3.new( 0, 50, 0 )
    expl.LocalScale    = Vector3.new( 2, 2, 2 )

    -- local function touch_func(touch_func)
    --     gg.log( "掉落物碰撞:", touch_func )

    -- end
    -- drop_box_.Touched:connect( touch_func )

end


---------------------------------------- 状态机 ----------------------------
--设置状态机函数
function _M:initBattleStatFunc()
    self.battle_stat_func = {

        --空闲
        [ BATTLE_STAT_IDLE ] = {
            --enter  = function (self) end,           --进入状态
            --exit   = function (self) end,           --离开状态
            --update = function (self) end,           --更新状态
        },


        --战斗中
        [ BATTLE_STAT_FIGHT ] = {
        },


        --死亡等待
        [ BATTLE_STAT_DEAD_WAIT ] = {
            enter  = function (self)
                self.actor:StopNavigate()   --停止导航
                if  self:isPlayer() then
                    --发消息给客户端，禁止操作
                    gg.network_channel:fireClient( self.uin, { cmd='cmd_player_actor_stat', v='dead' } )
                    self.stat_data.dead_wait.wait = 30
                else
                    self.stat_data.dead_wait.wait = 60
                end
                self:play_animation( '100106', 1.0, 2 )   --dead
            end,

            update = function (self)
                --死亡后定住N帧
                local data_ = self.stat_data.dead_wait
                if  data_.wait > 0 then
                    data_.wait = data_.wait - 1
                else
                    self:setBattleStat( BATTLE_STAT_WAIT_SPAWN )
                end
            end,
        },


        --等待复活
        [ BATTLE_STAT_WAIT_SPAWN ] = {
            enter  = function (self)
                if  self:isPlayer() then
                    self.stat_data.wait_spawn.wait = 10
                    self:changeScence( 'g0' )    --返回大厅
                else
                    self.stat_data.wait_spawn.wait = 30
                end

                gg.log( 'set WAIT_SPAWN', self.uuid )

                --回到起始坐标
                self.actor.Visible = false
                self.actor.Position = Vector3.new( self.info.x, self.info.y, self.info.z )
                wait(0.02)
                self.actor.Position = Vector3.new( self.info.x, self.info.y, self.info.z )


                if  self:isPlayer() then
                    self:showReviveEffect( Vector3.new( self.info.x, self.info.y, self.info.z ) )
                end
            end,

            update = function (self)
                --等待重生
                local data_ = self.stat_data.wait_spawn
                if  data_.wait > 0 then
                    data_.wait = data_.wait - 1
                else
                    self:revive()   --复活
                end
            end,
        },
    }

end

-- 在NPC右侧创建任务对话栏
function _M:createQuestDialogImage(params)
    local task_billboard = SandboxNode.new( 'UIBillboard', self.actor )
    task_billboard.Name = 'Task'
    task_billboard.Billboard = false
    task_billboard.CanCollide      = false            --避免产生物理碰撞
    task_billboard.ResolutionLevel = Enum.ResolutionLevel.R4X
    task_billboard.Size2d          = Vector2.new( 8, 8 )
    task_billboard.LocalPosition   = Vector3.new(100, 200,0 )
    local dialog_button= SandboxNode.new('UIButton', task_billboard)
    local icon_ = params.icon
    dialog_button.Name = 'Image'
    dialog_button.Visible = false
    dialog_button.ClickPass = false   
    dialog_button.LayoutHRelation = Enum.LayoutHRelation.Middle  
    dialog_button.LayoutVRelation = Enum.LayoutVRelation.Middle 
    dialog_button.Alpha =1
    dialog_button.Pivot = Vector2.new(0.5, -1.5)
    dialog_button.Size = Vector2.new(params.size[1], params.size[2])
    dialog_button.Icon = icon_
    dialog_button.Name = "Dialogue"
    dialog_button.OutlineEnable= true
    --设置开启阴影
    dialog_button.ShadowEnable= true
    dialog_button.Click:Connect(function(node,  isClick, vector2, int)  
        gg.log(node,  isClick, vector2, int)
        gg.log("点击了对话框")
    end)
	gg.log("dialog_button",dialog_button)
   
    return dialog_button
end


function _M:CreateInteractArea(model)
    -- 获取区域和模型属性
    local interactArea = SandboxNode.new('Area', model)
    local npcSize = model.Size
    local centerPos = model.Position
    local expand = Vector3.new(150, 100, 150)
    
    -- 设置区域范围
    interactArea.Beg = centerPos - (npcSize/2 + expand)
    interactArea.End = centerPos + (npcSize/2 + expand)
    
    -- 区域外观（调试用）
    interactArea.Show = true -- 正式环境设为false
    interactArea.Color = ColorQuad.new(0, 255, 0, 50)
    interactArea.EffectWidth = 1
    
    -- 确保对话图标初始状态为隐藏
    if model.name_level.Dialogue then
        model.name_level.Dialogue.Visible = false
    end
    
    -- 创建客户端事件处理
    local function handlePlayerInteraction(node, isEntering)
        -- 在服务器上，我们需要向特定客户端发送消息
        local userId = node.UserId or node.OwnerUin
        if userId and node:GetAttribute("model_type") == "player" then
            -- 向特定客户端发送显示/隐藏对话框的消息
            gg.network_channel:fireClient(userId, {
                cmd = "cmd_npc_dialogue_visibility",
                npc_id = model.Name,
                visible = isEntering
            })
        end
    end
    
    -- 注册区域事件
    interactArea.EnterNode:connect(function(node)
        handlePlayerInteraction(node, true) -- 玩家进入
    end)
    
    interactArea.LeaveNode:connect(function(node)
        handlePlayerInteraction(node, false) -- 玩家离开
    end)
    
    return interactArea
end

--改变状态
function _M:setBattleStat( battle_stat_ )
    --gg.log( 'setBattleStat:', battle_stat_ )

    local exit_func_ = self.battle_stat_func[ self.battle_stat ].exit
    if  exit_func_ then
        exit_func_(self)
    end
    self.battle_stat = battle_stat_
    local enter_func_ = self.battle_stat_func[ battle_stat_ ].enter
    if  enter_func_ then
        enter_func_(self)
    end

end



--tick刷新
function _M:update()

    self.tick = self.tick + 1

    if  self.tick % 2 == 0 then
        if  next( self.stat_flags ) then
            self:checkAbnormalStatFlags(2)   --检查异常状态
        end

        if  self.target then
            self:checkTargetLost()           --检查目标是否丢失
        end
    end


    --更新状态机
    local update_func_ = self.battle_stat_func[ self.battle_stat ].update
    if  update_func_ then
        update_func_( self )
    end

end



return _M