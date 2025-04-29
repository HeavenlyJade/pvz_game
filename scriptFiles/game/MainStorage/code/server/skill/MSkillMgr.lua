--- V109 miniw-haima

local game          = game
local pairs         = pairs
local ipairs        = ipairs
local type          = type
local SandboxNode   = SandboxNode
local Vector2       = Vector2
local Vector3       = Vector3
local ColorQuad     = ColorQuad
local Enum          = Enum
local wait          = wait
local math          = math
local os            = os
local require       = require

local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const
local buffer_mgr    =  require(MainStorage.code.server.buff.BuffMgr) ---@type BufferMgr
local skillUtils    = require(MainStorage.code.server.skill.MSkillUtils) ---@type SkillUtils


-- 将技能加载的实列存放在这里
---@class SkillMgr
local SkillMgr = {
	skill_instance_list = {
		-- skill_1, skill_1, skill_2   --存放每一个技能实例( 特效，投掷物，弹道等 )
	}
}

-- 所有技能定义列表的 lua-modules (通过 InitSkillConfig 初始化)
---@type any[]
local CONST_skill_module = {
	--[1001] = require(MainStorage.code.server.skill.CSkill_1001),
}


function SkillMgr.InitSkillConfig()
	for skill_id, v in pairs(common_config.skill_def) do
		v.id                           = skill_id --补齐技能id
		v.icon                         = common_config.skill_def[skill_id].icon
		v.name                         = common_config.skill_def[skill_id].name
		local skill_sn                 = common_config.skill_def[skill_id].skill_sn
		local name_                    = MainStorage.code.server.skill.SkillFactory['CSkill_' .. skill_sn]
		CONST_skill_module[skill_id]   = require(name_)
	end
end

--玩家选定一个目标
function SkillMgr.handlePickActor(uin_, args1_)
	local player_ = gg.server_players_list[uin_]
	if player_ then
		local target_ = gg.findMonsterByUuid(args1_.v)
		if target_ then
			gg.log('handlePickActor', uin_, target_.uuid)
			player_:changeTarget(target_)
			player_:setAutoAttack(0) --切换目标，去掉自动攻击
		end
	end
end

--同步玩家技能数据
function SkillMgr.handlePlayerSkillReq(uin_, args1_)
	local player_ = gg.server_players_list[uin_]
	if player_ then
		player_:syncSkillData()
	end
end

--玩家选择或者更换了一个技能
function SkillMgr.handlePlayerSelectSkill(uin_, args1_)
	local player_ = gg.server_players_list[uin_]
	if player_ then
		-- { cmd='cmd_select_skill', btn=i, skill_id=skill_id_ }
		if common_config.skill_def[args1_.skill_id] then
			--排重掉其他相同的技能按钮
			local duplicates = {}
			for k, v in pairs(player_.dict_btn_skill) do
				if v == args1_.skill_id then
					duplicates[#duplicates + 1] = k
				end
			end
			for i = 1, #duplicates do
				player_.dict_btn_skill[duplicates[i]] = nil
			end
			player_.dict_btn_skill[args1_.btn] = args1_.skill_id
			player_:saveSkillConfig()
		end
	end
end

--AOE技能选定了坐标
function SkillMgr.handleAoeSelectPos(uin_, args1_)
	gg.log('handleAoeSelectPos:', uin_, args1_)
	local skill_ = SkillMgr.skill_instance_list[args1_.uuid]
	if skill_ then
		skill_:AoeSelectPos(args1_)
	end
end

--客户端按钮事件:玩家跳跃，攻击或者施法
-- 魔法数值：0 表示跳跃，> 1000 表示技能，这些判断逻辑应该在文档或代码注释中说明原因，或者用常量替代。
function SkillMgr.handleClientBtn(uin_, args1_)
	local player_ = gg.server_players_list[uin_]
	if player_ then
		if args1_.v == 0 then
			player_:doJump()
		else
			local skill_id_ = player_.dict_btn_skill[args1_.v]
			if skill_id_ and skill_id_ >= 1000 then
				SkillMgr.tryAttackSpell(player_, skill_id_) --玩家技能释放
			end
		end
	end
end




-- 检查目标距离
function SkillMgr.checkTargetDistance(attacker_, skill_config)
	if not (skill_config.need_target == 1 and attacker_.target) then
		return true -- 不需要目标或无目标，视为成功
	end

	if skill_config.range and skill_config.range > 0 then
		-- 检查目标是否在范围内
		if gg.out_distance(attacker_:getPosition(), attacker_.target:getPosition(), skill_config.range) then
			-- 根据攻击者类型显示适当的消息
			local message = attacker_:isPlayer() and '距离太远了' or '距离太远'
			attacker_:showTips(message)
			return false
		end
	end

	-- 改变朝向
	gg.actorLookAtActorY0(attacker_.actor, attacker_.target.actor)
	return true
end

-- 处理施法条件检查结果
function SkillMgr.handlePrerequisiteResult(attacker_, ret_)
	if ret_ > 0 then
		if attacker_:isPlayer() then
			-- 玩家特定反馈
			if ret_ == 9 then
				attacker_:showTips('魔法值不足')
			elseif ret_ == 2 then
				attacker_:showTips('技能冷却中')
			end
		elseif ret_ == 9 then
			-- 怪物魔法值不足处理
			attacker_:showTips('魔法值不足')
			attacker_:outOfMana()
		end
		return false
	end
	return true
end

-- 获取技能模块
function SkillMgr.getSkillModule(skill_id_)
	local skill_module_ = CONST_skill_module[skill_id_]
	if not skill_module_ then
		gg.log('技能释放没有找到该技能:', skill_id_)
		return nil
	end
	return skill_module_
end

-- 创建技能实例
function SkillMgr.createSkillInstance(skill_module_, attacker_, skill_id_)
	local info_ = { from = attacker_, skill_id = skill_id_ }
	local skill_

	if skill_module_.New then
		skill_ = skill_module_.New(info_)
	else
		skill_ = skill_module_:new(info_)
	end

	SkillMgr.skill_instance_list[skill_.uuid] = skill_
	return skill_
end

-- 如果技能有配置BUff，就创建buff
function SkillMgr.createBufferInstance(attacker_,skill_config)
	local buff_list = skill_config.buff_list
	if not buff_list then return nil end
	for i, buff_id in ipairs(buff_list) do
		local buffer_info_ = { from=attacker_, buff_id=buff_id }
		local buff_config = common_config.buff_def[buff_id]
		local buffer_module= buffer_mgr.CONST_Buffer_module[buff_id]
		---@type BuffBase 
		local buffer_ins 
		if  buffer_module then
			if  buffer_module.New then
				buffer_ins = buffer_module.New( buffer_info_ )
			else
				buffer_ins = buffer_module:new( buffer_info_ )
			end
			buffer_ins:castSpell()
			if buff_config.need_target == 0 then
				attacker_.buff_instance[buff_id] = buffer_ins
			end
		end

	end
end
-- 处理施法时间
function SkillMgr.handleCastTime(attacker_, skill_, skill_config)
	if skill_config.cast_time and skill_config.cast_time > 0 then
		-- 有施法时间
		if attacker_:setSkillCastTime(skill_.uuid, skill_config.cast_time) == 0 then
			skill_:castTimePre()
		end
	else
		-- 没有施法时间，直接攻击或施法
		skill_:castSpell()
	end
end

-- 处理自动攻击设置
function SkillMgr.handleAutoAttack(attacker_, skill_id_, skill_config)
	if attacker_.auto_attack then
		if skill_id_ >= 1000 and skill_id_ < 2000 then
			-- 基础攻击技能(1001, 1002)
			attacker_:setAutoAttack(skill_id_, skill_config.speed or 1)
		end
	end
end

-- 主函数：尝试释放技能
function SkillMgr.tryAttackSpell(attacker_, skill_id_)
	-- 检查技能配置
	local skill_config = common_config.skill_def[skill_id_]
	if not skill_config then return 0 end

	-- 检查攻击者是否存活
	if skillUtils.checkAlive( attacker_, skill_config ) > 0 then
		return 1
	end

	-- 检查目标距离
	if not SkillMgr.checkTargetDistance(attacker_, skill_config) then
		return 1
	end

	-- 检查前置条件(速度、冷却、魔法值)
	local ret_ = attacker_:checkAttackSpellConfig(skill_id_, skill_config)
	if not SkillMgr.handlePrerequisiteResult(attacker_, ret_) then
		return ret_
	end

	-- 获取技能模块
	local skill_module_ = SkillMgr.getSkillModule(skill_id_)
	if not skill_module_ then
		return 0
	end

	-- 创建技能实例
	local skill_ = SkillMgr.createSkillInstance(skill_module_, attacker_, skill_id_)
	SkillMgr.createBufferInstance(attacker_,skill_config)
	-- 处理施法时间
	SkillMgr.handleCastTime(attacker_, skill_, skill_config)
	-- 处理自动攻击设置
	SkillMgr.handleAutoAttack(attacker_, skill_id_, skill_config)

	return 0 -- 成功
end




--玩家自动攻击
function SkillMgr.tryAutoAttack(attacker_, skill_id_)
	local skill_config = common_config.skill_def[skill_id_]
	local ret_         = attacker_:checkAttackSpellConfig(skill_id_, skill_config) --player or monster
	if ret_ > 0 then
		return                                                            --cd中
	end

	--需要判断目标距离
	if attacker_.target then
		if skill_config.range and skill_config.range > 0 then
			--检查距离
			if gg.out_distance(attacker_:getPosition(), attacker_.target:getPosition(), skill_config.range) then
				return 1
			end
		end

		--目标状态
		if skillUtils.checkAlive(attacker_, skill_config) > 0 then
			attacker_:setAutoAttack(0) --目标死亡
			return 1
		end
	else
		attacker_:setAutoAttack(0) --目标丢失，取消
		return 2
	end


	local skill_module_ = CONST_skill_module[skill_id_]
	local info_ = { from = attacker_, skill_id = skill_id_ }

	---@type CSkill_1001 | CSkill_2001
	local skill_
	if skill_module_.New then
		skill_ = skill_module_.New(info_)
	else
		skill_ = skill_module_:new(info_)
	end


	SkillMgr.skill_instance_list[skill_.uuid] = skill_
	skill_:castSpell() --没有前置时间，直接攻击或者施法

	return 0
end

--施法完毕
function SkillMgr.castTimeOver(uuid_)
	local skill_ = SkillMgr.skill_instance_list[uuid_]
	if skill_ then
		skill_:castSpell()
	end
end

--技能更新tick
function SkillMgr.update()
	local clean_list_ = {}
	for uuid_, skill_ in pairs(SkillMgr.skill_instance_list) do
		skill_:update()
		if skill_.tick > 300 or skill_.stat == 99 then
			clean_list_[#clean_list_ + 1] = uuid_
			skill_:DestroySkill()
		end
	end

	if #clean_list_ > 0 then
		for i = 1, #clean_list_ do
			SkillMgr.skill_instance_list[clean_list_[i]] = nil --清理技能实例
		end
	end
end

return SkillMgr
