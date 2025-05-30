--- 技能相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr)  ---@type MCloudDataMgr

---@class SkillCommands
local SkillCommands = {}

-- --装载配置的文件的技能
function SkillCommands.UnlockSkill(params, player)
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


return SkillCommands