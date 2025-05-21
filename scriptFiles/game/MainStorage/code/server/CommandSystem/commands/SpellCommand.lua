--- 物品相关命令处理器
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local SpellConfig = require(MainStorage.code.common.config.SpellConfig)  ---@type SpellConfig
local SubSpell = require(MainStorage.code.server.spells.SubSpell) ---@type SubSpell
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig


---@class SpellCommand
local SpellCommand = {}

---@param player Player
function SpellCommand.cast(params, player)
    if params["复杂魔法"] and params["魔法"] ~= "null" then
        local spell = SubSpell.New(params["复杂魔法"])
        spell:Cast(player, nil)
    else
        local spell = SpellConfig.Get(params["魔法名"])
        if not spell then
            player:SendChatText("不存在的魔法", params["魔法名"])
            return false
        end
        spell:Cast(player, nil)
    end
    return true
end

---@param player Player
function SpellCommand.skill(params, player)
    local skillType = SkillTypeConfig.Get(params["技能名"])
    if not skillType then
        player:SendChatText("不存在的技能: %s", params["技能名"])
        return false
    end

    local action = params["操作"] or "升级"
    if action == "升级" then
        if player:UpgradeSkill(skillType) then
            player:syncSkillData()
            player:SendChatText("技能操作成功: %s", skillType.name)
            return true
        else
            player:SendChatText("技能操作失败: %s", skillType.name)
            return false
        end
    elseif action == "装备" then
        local slot = params["装备格子"]
        if not slot or slot < 1 then
            player:SendChatText("无效的装备格子: %d", slot)
            return false
        end

        -- 查找玩家是否已拥有该技能
        local foundSkillId = nil
        for skillId, skill in pairs(player.skills) do
            if skill.skillType == skillType then
                foundSkillId = skillId
                break
            end
        end

        if not foundSkillId then
            player:SendChatText("未学习该技能: %s", skillType.name)
            return false
        end

        -- 装备技能
        if player:EquipSkill(foundSkillId, slot) then
            player:SendChatText("技能装备成功: %s", skillType.name)
            return true
        else
            player:SendChatText("技能装备失败: %s", skillType.name)
            return false
        end
    else
        player:SendChatText("未知的操作类型: %s", action)
        return false
    end
end

return SpellCommand