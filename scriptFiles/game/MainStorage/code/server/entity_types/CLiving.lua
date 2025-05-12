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
local common_const      = require(MainStorage.code.common.MConst)     ---@type common_const

local CommonModule      = require(MainStorage.code.common.CommonModule)    ---@type CommonModule
local cloudDataMgr      = require(MainStorage.code.server.MCloudDataMgr)      ---@type MCloudDataMgr
local Battle            = require(MainStorage.code.server.Battle)    ---@type Battle
local ServerEventManager      = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

--local StartPlayer = game:GetService("StartPlayer")
--local MainServer = require( game:GetService("MainStorage"):WaitForChild('code').server.MServerMain )
--local PlayerModule = require( StartPlayer.StarterPlayerScripts.PlayerModule )


local BATTLE_STAT_IDLE       = common_const.BATTLE_STAT.IDLE
local BATTLE_STAT_FIGHT      = common_const.BATTLE_STAT.FIGHT
local BATTLE_STAT_DEAD_WAIT  = common_const.BATTLE_STAT.DEAD_WAIT
local BATTLE_STAT_WAIT_SPAWN = common_const.BATTLE_STAT.WAIT_SPAWN

local TRIGGER_STAT_TYPES = {
    ["生命"] = function(creature, value)
        creature.SetMaxHealth(value)
    end,
    
}

---@class CLiving :Class  管理单个场景中的actor实例和有共性的属性，被包含在 player monster boss中
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
---@field New fun( info_:table ):CLiving
local _M = CommonModule.Class("CLiving")        --父类 (子类： CPlayer, CMonster )

-- 新增属性
function _M:OnInit(info_)
    self.info = info_      --{ x,y,z, uin, level, npc_type, owner }
    self.name = nil
    self.uuid = nil
    self.isEntity = true
    self.uin  = info_.uin
    self.exp   = 0     --当前经验值
    self.level = 1     --当前等级
    self.drop_items = info_.drop_items  -- 怪物掉落物配置
    self.npc_type   = common_const.NPC_TYPE.INITING   --NPC类型
    self.stats = {}

    self.scene_name = nil           --场景名字 g0 g10 g20
    self.scene      = nil           --当前场景

    self.actor         = nil        --game_actor
    self.target        = nil        --当前目标 actor
    self.orgMoveSpeed  = 0          --common_const.MOVESPEED, --原始速度
    self.weapon_speed  = 1          --武器速度，默认1.0
    self.model_weapon  = nil        --武器

    self.bb_title   = nil           --头顶名字和等级 billboard
    self.bb_damage  = nil           --伤害飘字

    -- 冷却系统
    self.cd_list = {}               --全局冷却列表
    self.cooldownTarget = {}        --目标相关冷却列表

    -- 战斗属性
    self.health = 0
    self.maxHealth = 0
    self.mana = 0
    self.maxMana = 0
    self.shield = 0
    
    -- 词条系统
    self.tagHandlers = {}           --词条处理器
    self.tagIds = {}                --词条ID映射
    
    -- BUFF系统
    self.activeBuffs = {}           --激活的BUFF
    
    -- 变量系统
    self.variables = {}
    
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
end


function _M:RefreshStats()
    self:ResetStats("EQUIP")

end

-- 词条系统 --------------------------------------------------------

--- 获取词条
---@param id string 词条ID
---@return EquipingTag|nil
function _M:GetTag(id)
    if self.tagIds[id] then
        return self.tagIds[id]
    end
    
    -- 模糊匹配
    for tagId, tag in pairs(self.tagIds) do
        if string.find(tagId, id) then
            return tag
        end
    end
    
    return nil
end

--- 重建词条处理器
function _M:RebuildTagHandlers()
    self.tagHandlers = {}
    
    for _, equipingTag in pairs(self.tagIds) do
        for key, handlers in pairs(equipingTag.handlers) do
            if not self.tagHandlers[key] then
                self.tagHandlers[key] = {}
            end
            
            table.insert(self.tagHandlers[key], equipingTag)
            
            -- 如果有多个处理器，按优先级排序
            if #self.tagHandlers[key] > 1 then
                table.sort(self.tagHandlers[key], function(a, b)
                    return a.handlers[key][1].priority < b.handlers[key][1].priority
                end)
            end
        end
    end
end

--- 添加词条处理器
---@param equipingTag EquipingTag 词条对象
function _M:AddTagHandler(equipingTag)
    if self.tagIds[equipingTag.id] then
        -- 已存在相同ID的词条，增加等级
        local existingTag = self.tagIds[equipingTag.id]
        existingTag.level = existingTag.level + equipingTag.level
    else
        self.tagIds[equipingTag.id] = equipingTag
    end
    
    self:RebuildTagHandlers()
end

--- 移除词条处理器
---@param id string 词条ID
function _M:RemoveTagHandler(id)
    if self.tagIds[id] then
        local equippingTag = self.tagIds[id]
        
        -- 从tagHandlers中移除
        for key, handlers in pairs(equippingTag.handlers) do
            if self.tagHandlers[key] then
                for i, tag in ipairs(self.tagHandlers[key]) do
                    if tag.id == id then
                        table.remove(self.tagHandlers[key], i)
                        break
                    end
                end
                
                if #self.tagHandlers[key] == 0 then
                    self.tagHandlers[key] = nil
                end
            end
        end
        
        self.tagIds[id] = nil
    else
        -- 模糊匹配移除
        local removedIds = {}
        for tagId in pairs(self.tagIds) do
            if string.find(tagId, id) then
                table.insert(removedIds, tagId)
            end
        end
        
        for _, tagId in ipairs(removedIds) do
            self:RemoveTagHandler(tagId)
        end
    end
end

--- 触发词条
---@param key string 触发键
---@param target CLiving|Vector3 目标
---@param castParam CastParam|nil 施法参数
---@param ... any 额外参数
function _M:TriggerTags(key, target, castParam, ...)
    -- 处理动态词条
    if castParam and castParam.dynamicTags and castParam.dynamicTags[key] then
        for _, equipingTag in ipairs(castParam.dynamicTags[key]) do
            for _, tag in ipairs(equipingTag.handlers[key]) do
                tag:Trigger(self, target, equipingTag, ...)
            end
        end
    end
    
    -- 处理普通词条
    if self.tagHandlers[key] then
        for _, equipingTag in ipairs(self.tagHandlers[key]) do
            for _, tag in ipairs(equipingTag.handlers[key]) do
                tag:Trigger(self, target, equipingTag, ...)
            end
        end
    end
end

-- BUFF系统 --------------------------------------------------------

--- 添加BUFF
---@param buff ActiveBuff BUFF对象
function _M:AddBuff(buff)
    self.activeBuffs[buff.id] = buff
end

--- 移除BUFF
---@param buffId string BUFF ID
function _M:RemoveBuff(buffId)
    self.activeBuffs[buffId] = nil
end

--- 获取BUFF堆叠数
---@param keyword string BUFF关键字
---@return number 堆叠数
function _M:GetBuffStacks(keyword)
    local stacks = 0
    
    if not keyword or keyword == "" then
        -- 获取所有BUFF的堆叠数
        for _, buff in pairs(self.activeBuffs) do
            stacks = stacks + buff.stack
        end
    else
        -- 获取特定关键字的BUFF堆叠数
        for _, buff in pairs(self.activeBuffs) do
            if string.find(buff.spell.spellName, keyword) then
                stacks = stacks + buff.stack
            end
        end
    end
    
    return stacks
end

-- 冷却系统 --------------------------------------------------------

--- 获取冷却时间
---@param reason string 冷却原因
---@param target CLiving|nil 目标对象
---@return number 剩余冷却时间
function _M:GetCooldown(reason, target)
    if target then
        -- 检查目标相关的冷却
        if self.cooldownTarget[reason] then
            local targetId = target.actor and target.actor.InstanceID or 0
            if self.cooldownTarget[reason][targetId] then
                local remainingTime = self.cooldownTarget[reason][targetId] - os.time()
                return remainingTime > 0 and remainingTime or 0
            end
        end
    end
    
    -- 检查全局冷却
    if self.cd_list[reason] then
        local remainingTime = self.cd_list[reason] - os.time()
        return remainingTime > 0 and remainingTime or 0
    end
    
    return 0
end

--- 检查是否在冷却中
---@param reason string 冷却原因
---@param target CLiving|Vector3|nil 目标对象
---@return boolean 是否在冷却中
function _M:IsCoolingdown(reason, target)
    return self:GetCooldown(reason, target) > 0
end

--- 设置冷却时间
---@param reason string 冷却原因
---@param time number 冷却时间(秒)
---@param target CLiving|Vector3|nil 目标对象
function _M:SetCooldown(reason, time, target)
    if target and target.isEntity then
        -- 设置目标相关的冷却
        if not self.cooldownTarget[reason] then
            self.cooldownTarget[reason] = {}
        end
        local targetId = target.actor and target.actor.InstanceID or 0
        self.cooldownTarget[reason][targetId] = os.time() + time
    else
        -- 设置全局冷却
        self.cd_list[reason] = os.time() + time
    end
end

--- 清除目标冷却
---@param reason string|nil 冷却原因，nil表示清除所有
function _M:ClearTargetCooldowns(reason)
    if reason then
        self.cooldownTarget[reason] = nil
    else
        self.cooldownTarget = {}
    end
end

-- 变量系统 --------------------------------------------------------

--- 设置变量
---@param key string 变量名
---@param value number 变量值
function _M:SetVariable(key, value)
    self.variables[key] = value
end

--- 获取变量
---@param key string 变量名
---@return number 变量值
function _M:GetVariable(key)
    -- 检查是否是特殊格式的变量名（category#variable）
    if string.find(key, "#") then
        local parts = {}
        for part in string.gmatch(key, "[^#]+") do
            table.insert(parts, part)
        end
        
        if #parts == 2 then
            local category = parts[1]
            local variable = parts[2]
            
            -- 创建并发布事件
            local evt = {
                __class = "VariableEvent",
                category = category,
                variable = variable,
                value = 0
            }
            
            -- 这里应该触发事件系统，但Lua中可能需要其他实现
            ServerEventManager.Publish(evt)
            
            return evt.value
        end
    end
    
    -- 如果不是特殊格式或解析失败，返回普通变量值
    return self.variables[key] or 0
end

--- 增加变量值
---@param key string 变量名
---@param value number 增加值
function _M:AddVariable(key, value)
    if not self.variables[key] then
        self.variables[key] = 0
    end
    self.variables[key] = self.variables[key] + value
end

--- 移除变量
---@param key string 变量名或部分名
function _M:RemoveVariable(key)
    local keysToRemove = {}
    
    for k in pairs(self.variables) do
        if string.find(k, key) then
            table.insert(keysToRemove, k)
        end
    end
    
    for _, k in ipairs(keysToRemove) do
        self.variables[k] = nil
    end
end

-- 属性管理系统 ----------------------------------------------------

--- 添加属性
---@param statName string 属性名
---@param amount number 属性值
---@param ... table 参数。 source=string 来源，refresh=boolean 是否刷新
function _M:AddStat(statName, amount, ...)
    local params = ... and ... or {}
    if params.source == nil then
        params.source = "BASE"
    end
    local source = params.source
    if params.refresh == nil then
        params.refresh = true
    end
    
    if not self.stats[source] then
        self.stats[source] = {}
    end
    
    if not self.stats[source][statName] then
        self.stats[source][statName] = 0
    end
    
    self.stats[source][statName] = self.stats[source][statName] + amount
    
    -- 这里应该有触发属性类型逻辑，但需要根据具体游戏逻辑实现
    if params.refresh and TRIGGER_STAT_TYPES[statName] then
        TRIGGER_STAT_TYPES[statName](self, self:GetStat(statName))
    end
end

--- 获取属性值
---@param statName string 属性名
---@param ... table 参数。 sources=string[] 来源列表，triggerTags=boolean 是否触发词条，castParam=CastParam 施法参数
---@return number 属性值
function _M:GetStat(statName, ...)
    local amount = 0
    local params = ... and ... or {}
    if params.triggerTags == nil then
        params.triggerTags = true
    end
    
    -- 遍历所有来源的属性
    for source, statMap in pairs(self.stats) do
        if not params.sources or table:contains(params.sources, source) then
            if statMap[statName] then
                amount = amount + statMap[statName]
            end
        end
    end
    
    -- 触发词条影响属性
    if params.triggerTags and self.tagHandlers[statName] then
        local battle = Battle.New(self, self, statName)
        battle:AddModifier("BASE", "增加", amount)
        self:TriggerTags(statName, self, params.castParam, battle)
        amount = battle:GetFinalDamage()
    end
    
    return amount
end

--- 重置属性
---@param id string 来源ID
function _M:ResetStats(id)
    self.stats[id] = nil
end

-- 战斗系统 --------------------------------------------------------

--- 攻击目标
---@param victim CLiving 目标对象
---@param baseDamage number 基础伤害
---@param source string|nil 伤害来源
---@param castParam CastParam|nil 施法参数
---@return Battle 战斗结果
function _M:Attack(victim, baseDamage, source, castParam)
    -- 这里需要Battle类的实现，暂时简化处理
    local battle = Battle.New(self, victim, source, castParam)
    battle:AddModifier("BASE", "增加", baseDamage)
    battle:CalculateBattle()
    
    victim:Hurt(battle:GetFinalDamage(), self, battle.isCrit)
    return battle
end

--- 受到伤害
---@param amount number 伤害值
---@param damager CLiving 伤害来源
---@param isCrit boolean 是否暴击
function _M:Hurt(amount, damager, isCrit)
    if self.battle_stat == BATTLE_STAT_DEAD_WAIT or self.battle_stat == BATTLE_STAT_WAIT_SPAWN then
        return
    end
    
    -- 先扣除护盾
    if self.shield > 0 then
        if self.shield >= amount then
            self.shield = self.shield - amount
            amount = 0
        else
            amount = amount - self.shield
            self.shield = 0
        end
    end
    
    -- 扣除生命值
    if amount > 0 then
        self:SetHealth(self.health - amount)
        
        -- 显示伤害数字
        if self.scene then
            self.scene:showDamage(self, amount, { cr = isCrit and 1 or 0 })
        end
    end
    
    -- 检查死亡
    if self.health <= 0 then
        self:Die()
    end
end

--- 治疗
---@param health number 治疗量
---@param source string|nil 治疗来源
function _M:Heal(health, source)
    self:SetHealth(self.health + health)
    local maxHealth = self:GetStat("Health")
    
    if self.health > maxHealth then
        self.health = maxHealth
    end
end

function _M:SetHealth(health)
    self.health = health
    self.actor.Health = health
end

--- 添加护盾
---@param amount number 护盾值
---@param source string|nil 护盾来源
function _M:AddShield(amount, source)
    self.shield = self.shield + amount
    local maxHealth = self:GetStat("Health")
    
    if self.shield > maxHealth then
        self.shield = maxHealth
    end
end

--- 死亡处理
function _M:Die()
    self:DestroyObject()
end

function _M:DestroyObject()
    self.actor:Destroy()
end

--- 设置最大生命值
---@param amount number 最大生命值
function _M:SetMaxHealth(amount)
    local percentage
    if self.maxHealth == 0 then
        percentage = 1
    else
        percentage = math.min(1, self.health / self.maxHealth)
    end
    
    self.maxHealth = amount
    self.health = self.maxHealth * percentage
    self.actor.MaxHealth = self.maxHealth
    self.actor.Health = self.health
end

-- 位置和状态 ------------------------------------------------------

--- 获取位置
---@return Vector3 位置坐标
function _M:GetLocation()
    -- if self.battle_stat == BATTLE_STAT_DEAD_WAIT or self.battle_stat == BATTLE_STAT_WAIT_SPAWN then
    --     return self.deadPosition or Vector3.new(0, 0, 0)
    -- end
    
    -- -- 如果有偏移量，计算偏移后的位置
    -- if self.mob and self.mob.mobType.offset then
    --     local offset = self.mob.mobType.offset
    --     local scale = self.actor and self.actor.LocalScale or Vector3.new(1, 1, 1)
    --     return Vector3.new(
    --         self.actor.Position.x + offset.x * scale.x,
    --         self.actor.Position.y + offset.y * scale.y,
    --         self.actor.Position.z
    --     )
    -- end
    
    return self.actor and self.actor.Position or Vector3.new(0, 0, 0)
end

--- 是否是生物
---@return boolean
function _M:IsCreature()
    return true
end

--- 获取生物对象
---@return CLiving
function _M:GetCreature()
    return self
end


--设置游戏场景中使用的actor实例
function _M:setGameActor( actor_ )
    self.actor = actor_
    --self.actor:UseDefaultAnimation(false);     --取消默认动作(自行用代码控制)

    actor_.PhysXRoleType    = Enum.PhysicsRoleType.BOX
	actor_.IgnoreStreamSync = false

    if  self.orgMoveSpeed == 0 then
        self.orgMoveSpeed = self.actor.Movespeed
    end

end


--是否是一个玩家
function _M:isPlayer()
    return self.npc_type == common_const.NPC_TYPE.PLAYER
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
---@param target_ CLiving
---@param with_name_ boolean
function _M:syncTargetInfo( target_, with_name_ )
    local info_ = {
        cmd    = 'cmd_sync_target_info',
        show = 1,   --0=不显示， 1=显示

        hp     = target_.health,
        hp_max = target_.maxHealth
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
    if common_config.expLevelUp[ self.level + 1 ] then
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

    cloudDataMgr.SavePlayerData( self.uin, save_flag_ )   --加经验存盘
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

        self:createHpBar( name_level_billboard )

        --self:enableAnimateDebugTest();     --是否打开动画测试
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

        local attack_speed = self:GetStat("攻速")
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
        if  self.mana < skill_config_.mp then
            return 9   --检查魔法值失败
        end
    end

    return 0
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
        self.mana = self.mana - skill_config_.mp
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
    --TODO: 刷新属性
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

    self.health = self.health + hp_ + spell_add_
    if  self.health > self.maxHealth then
        self.health = self.maxHealth
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
        hp=self.health, hp_max=self.maxHealth,
        mp=self.mana, mp_max=self.maxMana
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
-- function _M:checkAbnormalStatFlags( tick_ )
--     local stat_flags_ = self.stat_flags

--     --始发中
--     if  stat_flags_.skill_uuid then
--         if  stat_flags_.cast_time > 0 then
--             stat_flags_.cast_time = stat_flags_.cast_time - tick_

--             if  gg.out_distance( stat_flags_.cast_pos, self.actor.Position, 2 ) then    --distance=2
--                 --取消施法
--                 stat_flags_.skill_uuid = nil
--                 stat_flags_.cast_time  = nil
--                 stat_flags_.cast_pos   = nil
--                 self:play_animation( '100101', 1.0, 0 )   --walk
--                 gg.network_channel:fireClient( self.uin, { cmd='cmd_player_spell', v=0.1, max=0.1 } )

--             else
--                 self:play_animation( '100112', 1.0, 0 )   --spell
--             end

--         else
--             --施法结束
--             local skill_id_ = stat_flags_.skill_uuid
--             stat_flags_.skill_uuid = nil
--             stat_flags_.cast_time  = nil
--             stat_flags_.cast_pos   = nil
--             skillMgr.castTimeOver( skill_id_ )    --防施法卡死
--         end
--     end


--     --减速中
--     if  stat_flags_.slow then
--         if  stat_flags_.slow_tick > 0 then
--             stat_flags_.slow_tick = stat_flags_.slow_tick - tick_
--         else
--             stat_flags_.slow      = nil
--             stat_flags_.slow_tick = nil
--             self:calculateMoveSpeed()
--         end
--     end

-- end


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