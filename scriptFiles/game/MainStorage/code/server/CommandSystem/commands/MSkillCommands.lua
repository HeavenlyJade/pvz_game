--- 技能相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)  ---@type MCloudDataMgr

---@class SkillCommands
local SkillCommands = {}

-- 命令执行器工厂
local CommandExecutors = {}

-- 解锁技能执行器
function CommandExecutors.UnlockSkill(params, player)
    if params.category ~= "技能" then return false end
    
    local skillType = params.subcategory  -- 火系, 水系等
    local skillId = tonumber(params.id)
    
    -- 检查技能是否存在
    if not common_config.skill_def[skillId] then
        gg.log("技能不存在: " .. skillId)
        return false
    end
    
    -- 寻找空闲的技能栏位
    local skillSlot = nil
    for i = 1, 6 do
        if not player.dict_btn_skill[i] or player.dict_btn_skill[i] == 0 then
            skillSlot = i
            break
        end
    end
    
    if not skillSlot then
        -- 技能栏已满
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "技能栏已满，请先移除一个技能",
            color = ColorQuad.New(255, 0, 0, 255)
        })
        return false
    end
    
    -- 添加技能
    player.dict_btn_skill[skillSlot] = skillId
    player:saveSkillConfig()
    
    -- 通知客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = "解锁技能: " .. common_config.skill_def[skillId].name,
        color = ColorQuad.New(0, 255, 0, 255)
    })
    
    return true
end

-- 设置技能等级执行器
function CommandExecutors.SetSkillLevel(params, player)
    if params.category ~= "技能" then return false end
    
    local skillId = tonumber(params.subcategory)
    
    if params.action ~= "等级" then return false end
    
    local level = tonumber(params.value)
    
    -- 检查技能是否存在
    if not player:HasSkill(skillId) then
        gg.log("玩家未拥有技能: " .. skillId)
        return false
    end
    
    player:SetSkillLevel(skillId, level)
    
    -- 通知客户端
    gg.network_channel:fireClient(player.uin, {
        cmd = "cmd_client_show_msg",
        txt = common_config.skill_def[skillId].name .. " 等级提升至 " .. level,
        color = ColorQuad.New(0, 255, 0, 255)
    })
    
    return true
end

-- 添加武魂执行器
function CommandExecutors.AddSoulWeapon(params, player)
    if params.category ~= "武魂" then return false end
    
    if params.subcategory == "随机" then
        -- 添加随机武魂
        player:AddRandomSoulWeapon()
        
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获得随机武魂!",
            color = ColorQuad.New(0, 255, 0, 255)
        })
        
        return true
    else
        -- 添加指定武魂
        local soulType = params.subcategory
        player:AddSoulWeapon(soulType)
        
        -- 通知客户端
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "获得武魂: " .. soulType,
            color = ColorQuad.New(0, 255, 0, 255)
        })
        
        return true
    end
end

-- 命令映射表
local CommandMapping = {
    ["解锁"] = CommandExecutors.UnlockSkill,
    ["设置"] = CommandExecutors.SetSkillLevel,
    ["添加"] = CommandExecutors.AddSoulWeapon,
}

-- 命令执行函数
function SkillCommands.Execute(command, params, player)
    local executor = CommandMapping[command]
    if not executor then
        gg.log("未知技能命令: " .. command)
        return false
    end
    
    return executor(params, player)
end

-- 兼容旧版接口
SkillCommands.handlers = {}
for command, executor in pairs(CommandMapping) do
    SkillCommands.handlers[command] = executor
end

return SkillCommands