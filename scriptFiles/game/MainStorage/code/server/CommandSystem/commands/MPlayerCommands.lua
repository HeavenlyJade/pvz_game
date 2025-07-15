--- 玩家数据相关命令处理器

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local cloudDataMgr = require(MainStorage.code.server.MCloudDataMgr) ---@type MCloudDataMgr

---@class PlayerCommands
local PlayerCommands = {}

--- 清空玩家指定数据
--- @param clearOptions table 允许通过 { "背包" = true, "技能" = true, "任务" = true, "等级" = true } 来指定要清除的数据，若不指定则全部清除
--- @param targetPlayer Player
function PlayerCommands.clearData(clearOptions, targetPlayer)
    local clearedItems = {}
    clearOptions = clearOptions or {} -- 如果 "操作内容" 不存在，则创建一个空表，以触发 shouldClearAll

    -- 检查是否指定了要清除的特定数据，如果没有，则默认全部清除
    local shouldClearAll = not clearOptions["背包"] and not clearOptions["技能"] and not clearOptions["任务"] and not clearOptions["等级"]

    -- 1. 清空背包数据
    if clearOptions["背包"] or shouldClearAll then
        if targetPlayer.bag then
            targetPlayer.bag.bag_items = {}
            targetPlayer.bag.bag_index = {}
            targetPlayer.bag:MarkDirty(true) -- 标记为需要同步和保存
            table.insert(clearedItems, "背包")
        end
    end

    -- 2. 清空技能数据
    if clearOptions["技能"] or shouldClearAll then
        targetPlayer.skills = {}
        targetPlayer.equippedSkills = {}
        targetPlayer.tempSkills = {}
        targetPlayer.variables = {} -- 清空所有变量
        targetPlayer:SetLevel(1)
        targetPlayer.exp = 0
        targetPlayer:rsyncData(2)
        table.insert(clearedItems, "等级")
        table.insert(clearedItems, "技能")
        table.insert(clearedItems, "变量")
    end

    -- 3. 清空任务数据
    if clearOptions["任务"] or shouldClearAll then
        targetPlayer.quests = {}
        targetPlayer.acceptedQuestIds = {}
        targetPlayer.questKey = {}
        table.insert(clearedItems, "任务")
    end

    -- 4. 清空等级数据



    -- 5. 保存所有变更到云端
    targetPlayer:Save()

    -- 6. 刷新玩家状态并同步到客户端
    targetPlayer:RefreshStats()       -- 移除技能后需要刷新属性
    targetPlayer:UpdateQuestsData()   -- 同步空的任务列表
    targetPlayer:syncSkillData()      -- 同步空的技能列表
    if targetPlayer.bag then
        targetPlayer.bag:SyncToClient() -- 同步空的背包
    end

    local message = "玩家 " .. targetPlayer.name .. " 的数据已清空: " .. table.concat(clearedItems, ", ")
    gg.log(message)

    return message -- 返回成功信息
end

--- 命令分发器
--- @param params table
--- @param executor Player 指令执行者
function PlayerCommands.main(params, executor)
    local targetPlayer
    local uin = params["uin"]
    local playerName = params["玩家"]

    if uin then
        targetPlayer = gg.getPlayerByUin(uin)
        if not targetPlayer then
            executor:SendHoverText("通过 UIN 未找到玩家: " .. tostring(uin))
            return false
        end

        if targetPlayer.name ~= playerName then
            gg.log(string.format("指令安全校验失败: UIN %s 对应的玩家是 '%s', 但指令提供的玩家名是 '%s'。", uin, targetPlayer.name, playerName))
            executor:SendHoverText("UIN 和玩家名不匹配，操作已取消。")
            return false
        end
    else
        executor:SendHoverText("指令错误: 必须提供 'uin' 或 '玩家' 字段来指定目标玩家。")
        return false
    end

    -- 校验通过，执行后续操作
    local action = params["操作"]
    if not action then
        executor:SendHoverText("玩家命令错误: 缺少 '操作' 参数。")
        return false
    end

    if action == "清空数据" then
        local clearOptions = params["操作内容"]
        local successMessage = PlayerCommands.clearData(clearOptions, targetPlayer)
        -- 将成功信息反馈给执行者
        if successMessage then
            executor:SendHoverText(successMessage)
            return true
        end
        return false
    else
        executor:SendHoverText("玩家命令错误: 未知的操作 -> " .. action)
        return false
    end
end

return PlayerCommands
