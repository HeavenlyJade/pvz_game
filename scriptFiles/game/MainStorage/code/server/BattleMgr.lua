-- 战斗系统中的数值运算和玩家装备属性刷新


local print        = print
local setmetatable = setmetatable
local math         = math
local game         = game
local pairs        = pairs


local MainStorage   = game:GetService("MainStorage")
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local common_config = require(MainStorage.code.common.MConfig) ---@type common_config
local common_const  = require(MainStorage.code.common.MConst) ---@type common_const
local eqAttr        = require(MainStorage.code.server.equipment.MEqAttr) ---@type EqAttr


-- 管理战斗的数值部分

---@class BattleMgr
local BattleMgr = {}



---@param attacker_ CPlayer | CMonster
---@param target_ CPlayer | CMonster
function BattleMgr.calculate_attack(attacker_, target_, skill_config_)
    local effect_ = {}    --特性：暴击 躲闪 流血效果等
    
    -- 检查目标是否可被攻击
    if target_:canNotBeenAttarked() then 
        return 0, effect_ --无法击中
    end
    
    local att_ = attacker_.battle_data
    local tar_ = target_.battle_data
    local dmg_types = skill_config_.dmg_type
    table.sort(dmg_types)
    
    -- 检查闪避
    local dodge_result, dodge_effect = BattleMgr.check_dodge(att_, tar_)
    if dodge_result then
        return 0, dodge_effect
    end
    -- 计算基础伤害
    local base_dmg = BattleMgr.calculate_base_damage(att_, dmg_types, skill_config_.power)
    -- 应用暴击
    base_dmg, effect_ = BattleMgr.apply_critical(base_dmg, att_, dmg_types, effect_)
    -- 伤害分类处理
    local base_damages, element_damages = BattleMgr.categorize_damages(dmg_types, base_dmg)
    -- 处理基础伤害（物理和魔法）
    base_damages = BattleMgr.process_base_damages(base_damages, att_, tar_) 
    -- 处理元素伤害
    element_damages = BattleMgr.process_element_damages(element_damages, att_, tar_)  
    -- 计算总伤害
    local damage_ = BattleMgr.calculate_total_damage(base_damages, element_damages)
    -- 应用伤害到目标
    BattleMgr.apply_damage_to_target(damage_, attacker_, target_, tar_)
    return damage_, effect_
end

-- 检查闪避
---@param att_ table 攻击者战斗数据
---@param tar_ table 目标战斗数据
---@return boolean, table 是否闪避，效果表
function BattleMgr.check_dodge(att_, tar_)
    if tar_.dod > 0 then
        if math.random() < tar_.dod - att_.a_dod then
            return true, { dodge = 1 } --闪避
        end
    end
    return false, {}
end

-- 计算基础伤害
---@param att_ table 攻击者战斗数据
---@param dmg_types table 伤害类型
---@param power number 技能威力系数
---@return number 基础伤害
function BattleMgr.calculate_base_damage(att_, dmg_types, power)
    local base_dmg = 0
    if gg.contains(dmg_types, 1) then 
        base_dmg = gg.rand_int_between(att_.attack, att_.attack2) --物理伤害
    elseif gg.contains(dmg_types, 2) then 
        base_dmg = gg.rand_int_between(att_.spell, att_.spell2) --魔法伤害
    end
    -- 应用伤害放大系数
    return base_dmg * (power or 1)
end

-- 应用暴击
---@param base_dmg number 基础伤害
---@param att_ table 攻击者战斗数据
---@param dmg_types table 伤害类型
---@param effect_ table 效果表
---@return number, table 应用暴击后的伤害，更新的效果表
function BattleMgr.apply_critical(base_dmg, att_, dmg_types, effect_)
    local function apply_crit(crit_rate, crit_damage, effect_key)
        if crit_rate and crit_damage then
            if math.random() < crit_rate then
                base_dmg = base_dmg * (1 + crit_damage)
                effect_[effect_key] = 1
            end
        end
    end
    
    if gg.contains(dmg_types, 1) then 
        apply_crit(att_.cr, att_.crd, "cr") -- 物理暴击
    elseif gg.contains(dmg_types, 2) then 
        apply_crit(att_.mag_cr, att_.mag_cr, "mag_cr") -- 魔法暴击
    end
    
    return base_dmg, effect_
end

-- 伤害分类
---@param dmg_types table 伤害类型
---@param base_dmg number 基础伤害
---@return table, table 基础伤害表，元素伤害表
function BattleMgr.categorize_damages(dmg_types, base_dmg)
    local element_damages = {} -- 元素伤害
    local base_damages = {}    -- 基础伤害，物理，魔法
    
    -- 遍历 damages 并分类
    for _, v in ipairs(dmg_types) do
        if v == 1 or v == 2 then 
            base_damages[v] = base_dmg
        else 
            element_damages[v] = base_dmg 
        end
    end
    
    return base_damages, element_damages
end

-- 计算单一伤害与防御的关系
---@param base_damage number 基础伤害
---@param def_min number 最小防御值
---@param def_max number 最大防御值
---@param rd0 number 固定减防
---@param rd0p number 百分比减防
---@return number 计算后的伤害
function BattleMgr.calculate_damage_vs_defense(base_damage, def_min, def_max, rd0, rd0p)
    if not base_damage or base_damage == 0 then return 0 end
    local defence = gg.rand_int_between(def_min, def_max)
    -- 减少防御值
    if rd0 then defence = defence - rd0 end
    -- 百分比减少防御
    if rd0p then defence = defence * (1 - rd0p) end
    -- 确保防御不小于0
    defence = math.max(0, defence)
    -- 计算最终伤害
    return math.max(0, base_damage - defence)
end


-- 处理基础伤害（物理和魔法）
---@param base_damages table 基础伤害表
---@param att_ table 攻击者战斗数据
---@param tar_ table 目标战斗数据
---@return table 处理后的基础伤害表
function BattleMgr.process_base_damages(base_damages, att_, tar_)
    -- 计算物理伤害
    if base_damages[1] then
        base_damages[1] = BattleMgr.calculate_damage_vs_defense(base_damages[1], tar_.defence,tar_.defence2,att_.rd0, att_.rd0p)
        
        -- 物理减伤
        if tar_.rd_melee then
            base_damages[1] = math.max(0, base_damages[1] - tar_.rd_melee)
        end
    end
    
    -- 计算魔法伤害
    if base_damages[2] then
        base_damages[2] = BattleMgr.calculate_damage_vs_defense(base_damages[2],tar_.mag_defence,tar_.mag_defence2, att_.mag_rd0,att_.mag_rd0p)
        -- 魔法减伤
        if tar_.rd_spell then
            base_damages[2] = math.max(0, base_damages[2] - tar_.rd_spell)
        end
    end
    
    return base_damages
end

---@param element number 元素类型系数
---@param damage number 基本伤害
---@param att_ table 攻击者战斗数据
---@param tar_ table 目标战斗数据
function BattleMgr.calculate_damage_defense(element, damage,att_, tar_)
    local flat_bonus = att_['s' .. element] or 0
    local percent_bonus = att_['sp' .. element] or 0
    -- 计算初始伤害（基础+附加元素伤害）
    local initial_damage = damage + flat_bonus
    -- 应用百分比增益
    local amplified_damage = initial_damage * (1 + percent_bonus)
    -- 计算抗性值
    local resistance = tar_['r' .. element] or 0
    local resistance_reduction = att_['rd' .. element] or 0
    local final_resistance = math.max(0, resistance - resistance_reduction) -- 避免负抗性，除非游戏允许
    return amplified_damage * (1 - final_resistance)
end

-- 处理元素伤害
---@param element_damages table 元素伤害表
---@param att_ table 攻击者战斗数据
---@param tar_ table 目标战斗数据
---@return table 处理后的元素伤害表
function BattleMgr.process_element_damages(element_damages, att_, tar_)
    for element, damage in pairs(element_damages) do 
        element_damages[element] = BattleMgr.calculate_damage_defense(element, damage,att_, tar_)
    end
    return element_damages
end

-- 获取表中最大值
---@param t table 要查找的表
---@return number 最大值
function BattleMgr.get_max_value(t)
    local max_value = 0  -- 存储最大值
    for _, value in pairs(t) do
        if max_value == 0 or value > max_value then 
            max_value = value
        end
    end
    return max_value
end

-- 计算总伤害
---@param base_damages table 基础伤害表
---@param element_damages table 元素伤害表
---@return number 总伤害
function BattleMgr.calculate_total_damage(base_damages, element_damages)
    local element_max_value = BattleMgr.get_max_value(element_damages)
    local base_max_value = BattleMgr.get_max_value(base_damages)
    --合并所有伤害
    local damage_ = math.ceil(element_max_value + base_max_value)
    --最小伤害
    if damage_ < 1 then 
        damage_ = math.random(1, 9) 
    end
    
    return damage_
end

-- 应用伤害到目标
---@param damage_ number 伤害值
---@param attacker_ CPlayer | CMonster 攻击者
---@param target_ CPlayer | CMonster 目标
---@param tar_ table 目标战斗数据
function BattleMgr.apply_damage_to_target(damage_, attacker_, target_, tar_)
    tar_.hp = tar_.hp - damage_
    if tar_.hp <= 0 then
        tar_.hp = 0
        target_:checkDead()
        if attacker_:isPlayer() then
            attacker_:addExp(target_:getMonExp()) --增加经验
            -- local command = "增加 任务 " .. questType .. " " .. questId .. " 目标 " .. i .. " 进度 %p = 1"
            -- gg.CommandManager:ExecuteCommand(command, target_)
            attacker_:rsyncData(2)
        end
        if not target_:isPlayer() then 

            target_:createLootFromConfig(attacker_, target_)
            
        end
    else target_:play_animation('100107', 1.0, 1) --been_hit
    end
    target_:refreshHpMpBar()
end


-- 玩家改动装备，重算一个玩家的属性和词条
-- 遍历玩家已装备物品：读取玩家背包中"已装备"的物品（不同部位）。
-- 汇总装备属性：将所有装备的基础攻防和词缀属性（如 attack, defence, spell, p 等）进行叠加。
-- 写回玩家对象：将计算好的总属性更新到玩家对象里，并调用 resetBattleData 对战斗属性做最终重置或生效。
-- 日志输出：打印调试信息，方便查看玩家最终属性。
function BattleMgr.refreshPlayerAttr(uin_)
    local player_data_ = gg.server_player_bag_data[uin_]
    
    local all_attr = {
        wspeed   = 1, --武器速度
        attack   = 0, --最小伤害
        attack2  = 0, --最大伤害
        spell    = 0, --最小技能伤害
        spell2   = 0, --最大技能伤害
        defence  = 0, --最小防御
        defence2 = 0, --最大防御
    }
    
    --计算所有的已经装备的物品
    for i = 1, 8 do
        local pos_ = 1000 + i
        if player_data_.bag_index[pos_] then
            local uuid_ = player_data_.bag_index[pos_].uuid
            if uuid_ then
                -- 根据物品类型获取对应容器
                local item_type = player_data_.bag_index[pos_].type
                local containerName = common_const:getContainerNameByType(item_type)
                local item_ = player_data_[containerName] and player_data_[containerName][uuid_]

                --词缀
                if item_ and item_.attrs then
                    for seq_, attr in pairs(item_.attrs) do
                        if all_attr[attr.k] then
                            all_attr[attr.k].v = all_attr[attr.k].v + attr.v
                        else
                            all_attr[attr.k] = { v = attr.v }
                        end
                    end
                end

                --攻防
                if pos_ == 1001 and item_ then
                    --如果是武器，计算速度
                    if item_.wspeed and all_attr.wspeed then all_attr.wspeed = item_.wspeed end
                end

                --基础攻防
                if item_ then
                    if item_.attack then all_attr.attack = all_attr.attack + item_.attack end
                    if item_.attack2 then all_attr.attack2 = all_attr.attack2 + item_.attack2 end
                    if item_.spell then all_attr.spell = all_attr.spell + item_.spell end
                    if item_.spell2 then all_attr.spell2 = all_attr.spell2 + item_.spell2 end
                    if item_.defence then all_attr.defence = all_attr.defence + item_.defence end
                    if item_.defence2 then all_attr.defence2 = all_attr.defence2 + item_.defence2 end
                end
            end
        end
    end

    --修改属性数据
    local player_ = gg.getPlayerByUin(uin_)
    if player_ then
        player_.eq_attrs = all_attr --设置玩家的装备词缀，装备改动后
        player_:resetBattleData(false)
    end
end

return BattleMgr;