
--- nnpc

local setmetatable = setmetatable
local SandboxNode  = SandboxNode
local Vector3      = Vector3
local game         = game


local MainStorage = game:GetService("MainStorage")
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config     = require(MainStorage.code.common.MConfig)    ---@type common_config
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const
local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule


local CLiving   = require(MainStorage.code.server.entity_types.CLiving)    ---@type CLiving
-- local skillMgr  = require(MainStorage.code.server.skill.MSkillMgr)         ---@type SkillMgr


local BATTLE_STAT_IDLE  = common_const.BATTLE_STAT.IDLE
local BATTLE_STAT_FIGHT = common_const.BATTLE_STAT.FIGHT

-- info 结构
-- position 刷怪点
-- scene_name 节点名字
-- nickname npc名字
-- npc_type   NPC类型 
-- uin  当前节点对npc的唯一配置
-- lv  npc等级
-- model_id  模型资源ID 
-- profession = npc_spawn_config.profession,
-- rotation = npc_spawn_config.rotation,
-- id = npc_id,

---@class CLNpc:CLiving    --NPC类 (单个Npc) (管理NPC状态)
---@field npc_config any
local _M = CommonModule.Class('CLNpc', CLiving)        --父类CLiving
function _M:OnInit( info_ )
    
    CLiving:OnInit(info_)    --父类初始化
    self.uuid = gg.create_uuid( 'npc' )       --uniq id


    -- NPC配置文件  
    self.npc_config  = common_config.dict_monster_config[info_.id]
    -- CLiving.initBattleData( self, self.npc_config  )             --父类初始化NPC面板数据
end



--直接获得游戏中的actor的位置
function _M:getPosition()
    return self.actor.Position
end


--建立NPC 模型
function _M:InitModel()

    local info_ = self.info
    local npc_name = info_.nickname
    local level = info_.lv
    local npc_position = info_["position"]
    self.npc_type =  common_const.NPC_TYPE.NPC
    local npc_uin = info_.uin
    local plot = info_.plot --级别对话
    -- local npc_model =  gg.serverGetContainerNpc( self.scene_name )[npc_uin]
    local npc_model = SandboxNode.new('Actor', gg.serverGetContainerNpc( self.scene_name ) )  
    npc_model.Visible = true
    npc_model.LocalPosition = Vector3.new( npc_position[1], npc_position[2], npc_position[3     ] )
    npc_model.ModelId = info_.model_id
    npc_model.Name    = info_.uin
    npc_model.CollideGroupID =2  -- 设置模型可以被玩家碰撞
    self:setGameActor( npc_model )    --monster
    npc_model.LoadFinish:connect( function(ret)
        -- gg.log( 'create_model LoadFinish ok:', info_, ret )
        -- npc_model.CubeBorderEnable = true   --debug显示碰撞方块
        npc_model.Size   = Vector3.new( 120,  160,  120 )      --touch盒子的大小
        npc_model.Center = Vector3.new(  0,    80,    0 )      --盒子中心位置
        local image_args = {size={1000,100},icon="AssetId://377665866517590023",name="npc_plot",title= "对话",}
        self:createTitle( { name=npc_name, level=level, high=30,image_args=image_args } )
        self:createQuestDialogImage(image_args)
        self:CreateInteractArea(npc_model)
        
    end )

end



--按时间自动回血蓝
function _M:checkHPMP()
    if  self.battle_data.hp > 0 then
        if  self.battle_data.hp < self.battle_data.hp_max then
            self.battle_data.hp = self.battle_data.hp + 1
        end

        if  self.battle_data.mp < self.battle_data.mp_max then
            self.battle_data.mp = self.battle_data.mp + 2
        end
    end
end



--尝试在本场景里找一个目标
function _M:tryGetTargetPlayer()
    --gg.log( 'tryGetTargetPlayer', self.uuid )
    local player_ = self.scene:tryGetTarget( self:getPosition() )
    if  player_ then
        self:been_hit( player_ )
    end
end


--距离自己的刷新点太远
function _M:checkTooFarFromPos()
    local pos1_ = Vector3.new( self.info.x, self.info.y, self.info.z )
    local pos2_ = self:getPosition()
    if  gg.fast_out_distance( pos1_, pos2_, 6400 ) then
        -- gg.log( 'monster out range', self.name )
        self:spawnRandomPos( 500, 100, 500 )      --超过距离，重新刷回来
    end
end


function _M:spawnRandomPos( xx, yy, zz )
    local pos_ = self.info;
    self.actor.Position = Vector3.new(pos_.x+gg.rand_int_both(xx) , pos_.y+gg.rand_int(yy), pos_.z+gg.rand_int_both(zz) )
end

-- 战斗动作
function _M:checkFight( ticks, fight_data_ )
    --判断与目标的距离，导航到目标，并攻击

    if  fight_data_.wait > 0 then
        fight_data_.wait = fight_data_.wait - ticks   --继续上一个动作

    else
        --gg.print_table( 'checkFight====', self.uuid, fight_data_ )

        if  self.target then

            local pos_ = self.target:getPosition()

            local dir_ = self:getPosition() - pos_
            local dir2_ = Vector3.new( dir_.x + gg.rand_int_both(16), 0, dir_.z + gg.rand_int_both(16) )   --角度稍微随机，围绕玩家
            Vector3.Normalize( dir2_ )

            local skill_, range_ = self:getSkill1AndRange()
            local tar_pos_ = Vector3.new( pos_.x+dir2_.x*32,  pos_.y,  pos_.z+dir2_.z*32 )
            --gg.log( 'skill_config', skill_, range_ )

            if  gg.out_distance( self:getPosition(), tar_pos_, range_ * 0.9 ) then     --比攻击距离range要近一点
                self.actor:NavigateTo( tar_pos_ )              --导航到目标
                self:play_animation( '100101', 1.0, 0 )      --walk
            else
                self.actor:StopNavigate()
                skillMgr.tryAttackSpell( self, skill_ )       --攻击目标 怪物攻击
            end

        else
            --怪物战斗中失去目标
            self:setBattleStat( BATTLE_STAT_IDLE )
        end

        fight_data_.wait = 5   --间隔5帧=0.5秒
    end

end



--状态机
--IDLE            = 1,      --空闲(脱离战斗)
--FIGHT           = 2,      --进入战斗
--DEAD_WAIT       = 91,     --被击败 (等待重生或者清理)
--WAIT_SPAWN      = 92,     --等待重生
function _M:checkMonStat( ticks )

    local stat_      = self.battle_stat
    local stat_data_ = self.stat_data
    if  stat_ == BATTLE_STAT_IDLE then
        self:checkIdle( ticks, stat_data_.idle )
    elseif stat_ == BATTLE_STAT_FIGHT then
        self:checkFight( ticks, stat_data_.fight )

    else

    end

end



--tick刷新
function _M:update_npc()
    --self:update()
    --self:checkMonStat( 1 )
end



return _M;