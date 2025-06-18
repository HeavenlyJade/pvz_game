--- 邮件数据云存储模块 (Data Access Layer)
--- V109 miniw-haima
--- 负责直接与CloudService交互，进行邮件数据的存取。

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)
local cloudService = game:GetService("CloudService")   ---@type CloudService

---@class CloudMailDataAccessor
local CloudMailDataAccessor = {}

---------------------------
-- 个人邮件数据存取
---------------------------

--- 加载玩家邮件
---@param uin number 玩家ID
---@return PlayerMailData 玩家邮件数据
function CloudMailDataAccessor:LoadPlayerMail(uin)
    local ret, data = cloudService:GetTableOrEmpty('mail_player_' .. uin)

    if ret and data and data.mails then
        return data
    else
        -- 创建默认邮件数据
        return {
            uin = uin,
            mails = {},
            last_update = os.time()
        }
    end
end

--- 保存玩家邮件
---@param uin number 玩家ID
---@param mailData PlayerMailData
---@return boolean 是否成功
function CloudMailDataAccessor:SavePlayerMail(uin, mailData)
    if not mailData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync('mail_player_' .. uin, mailData, function(success)
        if not success then
            gg.log("保存玩家邮件失败", uin)
        else
            gg.log("保存玩家邮件成功", uin)
        end
    end)

    return true
end

---------------------------
-- 全服邮件数据存取
---------------------------

--- 加载全服邮件
---@return GlobalMailCache 全服邮件数据
function CloudMailDataAccessor:LoadGlobalMail()
    local success, data = cloudService:GetTableOrEmpty("mail_global")

    gg.log("--- 开始加载全服邮件 ---")
    gg.log("加载状态:", success)
    gg.log("加载到的原始数据:", data)

    -- 辅助函数：计算table中的元素数量
    local function table_count(t)
        if not t then return 0 end
        local count = 0
        for _ in pairs(t) do
            count = count + 1
        end
        return count
    end

    if success and data and data.mails then
        gg.log("加载全服邮件成功，邮件数量:", table_count(data.mails))
        return data
    else
        -- 初始化默认全服邮件缓存
        gg.log("创建全服邮件默认数据")
        return {
            mails = {},
            last_update = os.time()
        }
    end
end

--- 保存全服邮件
---@param globalMailData GlobalMailCache
---@return boolean 是否成功
function CloudMailDataAccessor:SaveGlobalMail(globalMailData)
    if not globalMailData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync("mail_global", globalMailData, function(success)
        if not success then
            gg.log("保存全服邮件失败")
        else
            gg.log("保存全服邮件成功")
        end
    end)

    return true
end

---------------------------
-- 玩家全服邮件状态存取
---------------------------

--- 加载玩家的全服邮件状态数据
---@param uin number 玩家ID
---@return PlayerGlobalMailContainer 位图数据
function CloudMailDataAccessor:LoadPlayerGlobalMailData(uin)
    -- 从云存储加载玩家邮件位图
    local success, data = cloudService:GetTableOrEmpty("mail_global_status_" .. uin)


    if success and data and data.statuses then
        return data
    else
        return {
            uin = uin,
            statuses = {},
            last_update = os.time()
        }
    end

end

--- 保存玩家的全服邮件状态数据
---@param uin number 玩家ID
---@param data PlayerGlobalMailContainer
---@return boolean 是否成功
function CloudMailDataAccessor:SavePlayerGlobalMailData(uin, data)
    -- 保存玩家邮件位图到云存储
    if not data then return false end

    -- 检查是否需要保存
    local now = os.time()
    -- 更新时间戳
    data.last_update = now
    -- 保存到云存储
    cloudService:SetTableAsync("mail_global_status_" .. uin, data, function(success)
        if not success then
            gg.log("保存玩家全服邮件状态失败", uin)
            return false
        else
            gg.log("保存玩家全服邮件状态成功", uin)
            return true
        end
    end)
end

---------------------------
-- 批量数据获取
---------------------------



--- 批量加载玩家邮件数据（个人邮件 + 全服邮件状态）
--- 一次性获取玩家的个人邮件和全服邮件状态，减少数据库调用
---@param uin number 玩家ID
---@return PlayerMailBundle 玩家邮件数据包
function CloudMailDataAccessor:LoadPlayerMailBundle(uin)
    local bundle = {}
    
    -- 并行获取个人邮件数据
    local playerMailKey = 'mail_player_' .. uin
    local playerMailSuccess, playerMailData = cloudService:GetTableOrEmpty(playerMailKey)
    
    if playerMailSuccess and playerMailData and playerMailData.mails then
        bundle.playerMail = playerMailData
        gg.log("加载玩家个人邮件成功", uin)
    else
        -- 创建默认个人邮件数据
        bundle.playerMail = {
            uin = uin,
            mails = {},
            last_update = os.time()
        }
        gg.log("创建玩家个人邮件默认数据", uin)
    end
    
    -- 并行获取全服邮件状态数据
    local globalStatusKey = "mail_global_status_" .. uin
    local globalStatusSuccess, globalStatusData = cloudService:GetTableOrEmpty(globalStatusKey)
    
    if globalStatusSuccess and globalStatusData and globalStatusData.statuses then
        bundle.globalMailStatus = globalStatusData
        gg.log("加载玩家全服邮件状态成功", uin)
    else
        -- 创建默认全服邮件状态数据
        bundle.globalMailStatus = {
            uin = uin,
            statuses = {},
            last_update = os.time()
        }
        gg.log("创建玩家全服邮件状态默认数据", uin)
    end
    
    return bundle
end

--- 批量保存玩家邮件数据（个人邮件 + 全服邮件状态）
--- 一次性保存玩家的个人邮件和全服邮件状态，提高保存效率
---@param uin number 玩家ID
---@param bundle PlayerMailBundle 玩家邮件数据包
---@return boolean 是否成功
function CloudMailDataAccessor:SavePlayerMailBundle(uin, bundle)
    if not bundle or not bundle.playerMail or not bundle.globalMailStatus then
        gg.log("批量保存失败：数据包无效", uin)
        return false
    end
    
    local success = true
    local now = os.time()
    
    -- 更新时间戳
    bundle.playerMail.last_update = now
    bundle.globalMailStatus.last_update = now
    
    -- 异步保存个人邮件数据
    cloudService:SetTableAsync('mail_player_' .. uin, bundle.playerMail, function(saveSuccess)
        if not saveSuccess then
            gg.log("批量保存玩家个人邮件失败", uin)
            success = false
        else
            gg.log("批量保存玩家个人邮件成功", uin)
        end
    end)
    
    -- 异步保存全服邮件状态数据
    cloudService:SetTableAsync("mail_global_status_" .. uin, bundle.globalMailStatus, function(saveSuccess)
        if not saveSuccess then
            gg.log("批量保存玩家全服邮件状态失败", uin)
            success = false
        else
            gg.log("批量保存玩家全服邮件状态成功", uin)
        end
    end)
    
    gg.log("批量保存玩家邮件数据完成", uin)
    return success
end

return CloudMailDataAccessor
