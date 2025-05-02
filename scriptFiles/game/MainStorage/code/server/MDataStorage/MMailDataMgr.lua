--- V109 miniw-haima
--- 邮件数据管理，负责邮件数据的存储和读取

local game = game
local pairs = pairs
local ipairs = ipairs
local table = table
local string = string
local os = os
local math = math
local type = type

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   -- 云数据服务
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local MMailConfig = require(MainStorage.code.common.MMail.MMailConfig)   ---@type MMailConfig
local MMailConst = require(MainStorage.code.common.MMail.MMailConst)   ---@type MMailConst
local MMailUtils = require(MainStorage.code.common.MMail.MMailUtils)   ---@type MMailUtils

---@class MMailDataMgr
local MMailDataMgr = {
    -- 玩家邮件数据缓存 {uin: mailData}
    playerMailCache = {},
    
    -- 系统邮件缓存
    systemMailCache = nil,
    
    -- 活动邮件缓存
    eventMailCache = {},
    
    -- 邮件索引缓存
    mailIndexCache = nil,
    
    -- 最后一次保存时间
    lastSaveTime = {},
    
    -- 自动保存间隔（秒）
    SAVE_INTERVAL = 60,
    
    -- 缓存过期时间（秒）
    CACHE_EXPIRY = 300,
    
    -- 最后一次缓存清理
    lastCacheCleanup = 0,
    
    -- 队列中的批量操作
    pendingBatchOperations = {}
}

-- 初始化邮件数据管理器
function MMailDataMgr:Init()
    -- 设置定时任务
    self:SetupTimers()
    
    -- 加载邮件索引
    self:LoadMailIndex()
    
    -- 加载全局系统邮件
    self:LoadSystemMails()
    
    gg.log("邮件数据管理器初始化完成")
    return self
end

-- 设置定时任务
function MMailDataMgr:SetupTimers()
    -- 定时保存数据
    local function autoSave()
        self:SaveAllCachedData()
        wait(self.SAVE_INTERVAL)
        autoSave()
    end
    
    -- 定时清理缓存
    local function cleanupCache()
        self:CleanupCache()
        wait(self.CACHE_EXPIRY)
        cleanupCache()
    end
    
    -- 处理批量操作队列
    local function processBatchQueue()
        self:ProcessBatchQueue()
        wait(30) -- 每30秒处理一次
        processBatchQueue()
    end
    
    -- 启动定时任务
    gg.thread_call(autoSave)
    gg.thread_call(cleanupCache)
    gg.thread_call(processBatchQueue)
end

---------------------------
-- 邮件索引相关方法
---------------------------

-- 加载邮件索引
function MMailDataMgr:LoadMailIndex()
    local success, data = cloudService:GetTableOrEmpty(MMailConfig.STORAGE_KEYS.MAIL_INDEX)
    
    if success and data and data.player_index then
        self.mailIndexCache = data
        gg.log("成功加载邮件索引数据")
    else
        -- 创建默认邮件索引
        self.mailIndexCache = {
            player_index = {},
            global_mail_list = {},
            event_mail_index = {},
            version = 1,
            last_update = MMailUtils.getCurrentTimestamp()
        }
        gg.log("创建默认邮件索引数据")
    end
end

-- 保存邮件索引
function MMailDataMgr:SaveMailIndex()
    if not self.mailIndexCache then return false end
    
    -- 更新时间戳
    self.mailIndexCache.last_update = MMailUtils.getCurrentTimestamp()
    
    -- 保存到云存储
    local success = cloudService:SetTable(MMailConfig.STORAGE_KEYS.MAIL_INDEX, self.mailIndexCache)
    
    if success then
        gg.log("成功保存邮件索引数据")
    else
        gg.log("保存邮件索引数据失败")
    end
    
    return success
end

-- 更新玩家邮件索引
function MMailDataMgr:UpdatePlayerMailIndex(playerUin, stats)
    if not self.mailIndexCache or not playerUin then return false end
    
    -- 确保玩家索引存在
    if not self.mailIndexCache.player_index[playerUin] then
        self.mailIndexCache.player_index[playerUin] = {}
    end
    
    -- 更新统计信息
    local index = self.mailIndexCache.player_index[playerUin]
    index.mail_count = stats.total
    index.unread_count = stats.unread
    index.unclaimed_count = stats.unclaimed
    index.last_mail_time = stats.lastMailTime or MMailUtils.getCurrentTimestamp()
    
    -- 标记需要保存
    self.lastSaveTime.mailIndex = 0
    
    return true
end

-- 添加全局邮件索引
function MMailDataMgr:AddGlobalMailIndex(mailId)
    if not self.mailIndexCache then return false end
    
    table.insert(self.mailIndexCache.global_mail_list, mailId)
    
    -- 标记需要保存
    self.lastSaveTime.mailIndex = 0
    
    return true
end

-- 删除全局邮件索引
function MMailDataMgr:RemoveGlobalMailIndex(mailId)
    if not self.mailIndexCache then return false end
    
    for i, id in ipairs(self.mailIndexCache.global_mail_list) do
        if id == mailId then
            table.remove(self.mailIndexCache.global_mail_list, i)
            
            -- 标记需要保存
            self.lastSaveTime.mailIndex = 0
            
            return true
        end
    end
    
    return false
end

-- 添加活动邮件索引
function MMailDataMgr:AddEventMailIndex(eventId, mailId)
    if not self.mailIndexCache then return false end
    
    -- 确保事件索引存在
    if not self.mailIndexCache.event_mail_index[eventId] then
        self.mailIndexCache.event_mail_index[eventId] = {}
    end
    
    table.insert(self.mailIndexCache.event_mail_index[eventId], mailId)
    
    -- 标记需要保存
    self.lastSaveTime.mailIndex = 0
    
    return true
end

---------------------------
-- 玩家邮件相关方法
---------------------------

-- 加载玩家邮件数据
function MMailDataMgr:LoadPlayerMailData(playerUin)
    -- 检查缓存
    if self.playerMailCache[playerUin] then
        return true, self.playerMailCache[playerUin]
    end
    
    -- 从云存储加载
    local storageKey = MMailConfig.STORAGE_KEYS.PLAYER_MAIL .. playerUin
    local success, data = cloudService:GetTableOrEmpty(storageKey)
    
    if success then
        -- 验证数据正确性
        if data and data.uin == playerUin then
            -- 确保邮件列表存在
            if not data.mail_list then data.mail_list = {} end
            if not data.system_mail_status then data.system_mail_status = {} end
            
            -- 缓存数据
            self.playerMailCache[playerUin] = data
            self.lastSaveTime[playerUin] = MMailUtils.getCurrentTimestamp()
            
            gg.log("成功加载玩家邮件数据: " .. playerUin)
            return true, data
        else
            -- 创建默认数据
            local defaultData = self:CreateDefaultPlayerMailData(playerUin)
            self.playerMailCache[playerUin] = defaultData
            self.lastSaveTime[playerUin] = MMailUtils.getCurrentTimestamp()
            
            gg.log("创建默认玩家邮件数据: " .. playerUin)
            return true, defaultData
        end
    else
        gg.log("加载玩家邮件数据失败: " .. playerUin)
        return false, nil
    end
end

-- 创建默认玩家邮件数据
function MMailDataMgr:CreateDefaultPlayerMailData(playerUin)
    return {
        uin = playerUin,
        mail_list = {},
        system_mail_status = {},
        mail_status = {
            unread_count = 0,
            unclaimed_count = 0,
            last_mail_time = MMailUtils.getCurrentTimestamp()
        },
        mail_meta = {
            version = 1,
            last_update = MMailUtils.getCurrentTimestamp(),
            last_cleanup = MMailUtils.getCurrentTimestamp()
        }
    }
end

-- 保存玩家邮件数据
function MMailDataMgr:SavePlayerMailData(playerUin, force)
    -- 检查是否需要保存
    local now = MMailUtils.getCurrentTimestamp()
    if not force and self.lastSaveTime[playerUin] and (now - self.lastSaveTime[playerUin] < self.SAVE_INTERVAL) then
        return false
    end
    
    -- 获取玩家邮件数据
    local mailData = self.playerMailCache[playerUin]
    if not mailData then
        gg.log("保存失败：玩家邮件数据不存在: " .. playerUin)
        return false
    end
    
    -- 更新元数据
    mailData.mail_meta.last_update = now
    
    -- 保存到云存储
    local storageKey = MMailConfig.STORAGE_KEYS.PLAYER_MAIL .. playerUin
    local success = cloudService:SetTable(storageKey, mailData)
    
    if success then
        self.lastSaveTime[playerUin] = now
        gg.log("成功保存玩家邮件数据: " .. playerUin)
    else
        gg.log("保存玩家邮件数据失败: " .. playerUin)
    end
    
    return success
end

-- 添加邮件到玩家邮箱
function MMailDataMgr:AddMailToPlayer(playerUin, mail)
    -- 加载玩家数据
    local success, playerMailData = self:LoadPlayerMailData(playerUin)
    if not success then
        return false, "加载玩家数据失败"
    end
    
    -- 检查邮件数量限制
    if MMailConfig:isMailLimitReached(#playerMailData.mail_list) then
        return false, "邮件数量达到上限"
    end
    
    -- 添加邮件
    playerMailData.mail_list[mail.uuid] = mail
    
    -- 更新状态统计
    playerMailData.mail_status.unread_count = playerMailData.mail_status.unread_count + 1
    if mail.attachments and #mail.attachments > 0 then
        playerMailData.mail_status.unclaimed_count = playerMailData.mail_status.unclaimed_count + 1
    end
    playerMailData.mail_status.last_mail_time = mail.create_time
    
    -- 标记需要保存
    self.lastSaveTime[playerUin] = 0
    
    -- 更新玩家邮件索引
    self:UpdatePlayerMailIndex(playerUin, playerMailData.mail_status)
    
    return true, mail.uuid
end

-- 更新玩家邮件
function MMailDataMgr:UpdatePlayerMail(playerUin, mailId, updates)
    -- 加载玩家数据
    local success, playerMailData = self:LoadPlayerMailData(playerUin)
    if not success then
        return false, "加载玩家数据失败"
    end
    
    -- 检查邮件是否存在
    local mail = playerMailData.mail_list[mailId]
    if not mail then
        return false, "邮件不存在"
    end
    
    -- 应用更新
    local statusChanged = false
    
    for key, value in pairs(updates) do
        -- 特殊处理状态变更
        if key == "read" and mail.read ~= value then
            statusChanged = true
            if value then
                playerMailData.mail_status.unread_count = math.max(0, playerMailData.mail_status.unread_count - 1)
            else
                playerMailData.mail_status.unread_count = playerMailData.mail_status.unread_count + 1
            end
        elseif key == "claimed" and mail.claimed ~= value then
            statusChanged = true
            if value then
                playerMailData.mail_status.unclaimed_count = math.max(0, playerMailData.mail_status.unclaimed_count - 1)
            else
                playerMailData.mail_status.unclaimed_count = playerMailData.mail_status.unclaimed_count + 1
            end
        end
        
        -- 更新字段
        mail[key] = value
    end
    
    -- 标记需要保存
    self.lastSaveTime[playerUin] = 0
    
    -- 如果状态变更，更新索引
    if statusChanged then
        self:UpdatePlayerMailIndex(playerUin, playerMailData.mail_status)
    end
    
    return true
end

-- 删除玩家邮件
function MMailDataMgr:DeletePlayerMail(playerUin, mailId)
    -- 加载玩家数据
    local success, playerMailData = self:LoadPlayerMailData(playerUin)
    if not success then
        return false, "加载玩家数据失败"
    end
    
    -- 检查邮件是否存在
    local mail = playerMailData.mail_list[mailId]
    if not mail then
        return false, "邮件不存在"
    end
    
    -- 更新状态统计
    if not mail.read then
        playerMailData.mail_status.unread_count = math.max(0, playerMailData.mail_status.unread_count - 1)
    end
    
    if mail.attachments and #mail.attachments > 0 and not mail.claimed then
        playerMailData.mail_status.unclaimed_count = math.max(0, playerMailData.mail_status.unclaimed_count - 1)
    end
    
    -- 删除邮件
    playerMailData.mail_list[mailId] = nil
    
    -- 标记需要保存
    self.lastSaveTime[playerUin] = 0
    
    -- 更新玩家邮件索引
    self:UpdatePlayerMailIndex(playerUin, playerMailData.mail_status)
    
    return true
end

-- 获取玩家所有邮件
function MMailDataMgr:GetAllPlayerMails(playerUin)
    -- 加载玩家数据
    local success, playerMailData = self:LoadPlayerMailData(playerUin)
    if not success then
        return false, "加载玩家数据失败"
    end
    
    -- 合并系统邮件
    local allMails = self:MergeSystemMails(playerUin, playerMailData)
    
    return true, allMails
end

-- 获取玩家单封邮件
function MMailDataMgr:GetPlayerMail(playerUin, mailId)
    -- 加载玩家数据
    local success, playerMailData = self:LoadPlayerMailData(playerUin)
    if not success then
        return false, "加载玩家数据失败"
    end
    
    -- 检查是否是玩家个人邮件
    local mail = playerMailData.mail_list[mailId]
    if mail then
        return true, mail
    end
    
    -- 检查是否是系统邮件
    local systemMailStatus = playerMailData.system_mail_status[mailId]
    if systemMailStatus then
        -- 加载系统邮件
        local systemMailSuccess, systemMail = self:GetSystemMail(mailId)
        if systemMailSuccess then
            -- 合并系统邮件状态到邮件对象
            local mergedMail = self:MergeSystemMailStatus(systemMail, systemMailStatus)
            return true, mergedMail
        end
    end
    
    return false, "邮件不存在"
end

-- 更新系统邮件状态
function MMailDataMgr:UpdateSystemMailStatus(playerUin, mailId, status)
    -- 加载玩家数据
    local success, playerMailData = self:LoadPlayerMailData(playerUin)
    if not success then
        return false, "加载玩家数据失败"
    end
    
    -- 检查系统邮件状态是否存在
    if not playerMailData.system_mail_status[mailId] then
        return false, "系统邮件状态不存在"
    end
    
    -- 更新状态
    local oldStatus = playerMailData.system_mail_status[mailId]
    local statusChanged = false
    
    for key, value in pairs(status) do
        -- 特殊处理状态变更
        if key == "read" and oldStatus.read ~= value then
            statusChanged = true
            if value then
                playerMailData.mail_status.unread_count = math.max(0, playerMailData.mail_status.unread_count - 1)
            else
                playerMailData.mail_status.unread_count = playerMailData.mail_status.unread_count + 1
            end
        elseif key == "claimed" and oldStatus.claimed ~= value then
            statusChanged = true
            if value then
                playerMailData.mail_status.unclaimed_count = math.max(0, playerMailData.mail_status.unclaimed_count - 1)
            else
                playerMailData.mail_status.unclaimed_count = playerMailData.mail_status.unclaimed_count + 1
            end
        end
        
        -- 更新字段
        oldStatus[key] = value
    end
    
    -- 标记需要保存
    self.lastSaveTime[playerUin] = 0
    
    -- 如果状态变更，更新索引
    if statusChanged then
        self:UpdatePlayerMailIndex(playerUin, playerMailData.mail_status)
    end
    
    return true
end

---------------------------
-- 系统邮件相关方法
---------------------------

-- 加载系统邮件
function MMailDataMgr:LoadSystemMails()
    local success, data = cloudService:GetTableOrEmpty(MMailConfig.STORAGE_KEYS.SYSTEM_MAIL)
    
    if success and data and data.mail_list then
        self.systemMailCache = data
        gg.log("成功加载系统邮件数据")
    else
        -- 创建默认系统邮件数据
        self.systemMailCache = {
            mail_list = {},
            mail_meta = {
                version = 1,
                last_update = MMailUtils.getCurrentTimestamp()
            }
        }
        gg.log("创建默认系统邮件数据")
    end
end

-- 保存系统邮件
function MMailDataMgr:SaveSystemMails(force)
    -- 检查是否需要保存
    local now = MMailUtils.getCurrentTimestamp()
    if not force and self.lastSaveTime.systemMail and (now - self.lastSaveTime.systemMail < self.SAVE_INTERVAL) then
        return false
    end
    
    -- 检查缓存是否存在
    if not self.systemMailCache then
        gg.log("保存失败：系统邮件缓存不存在")
        return false
    end
    
    -- 更新元数据
    self.systemMailCache.mail_meta.last_update = now
    
    -- 保存到云存储
    local success = cloudService:SetTable(MMailConfig.STORAGE_KEYS.SYSTEM_MAIL, self.systemMailCache)
    
    if success then
        self.lastSaveTime.systemMail = now
        gg.log("成功保存系统邮件数据")
    else
        gg.log("保存系统邮件数据失败")
    end
    
    return success
end

-- 添加系统邮件
function MMailDataMgr:AddSystemMail(mail)
    -- 确保系统邮件缓存已加载
    if not self.systemMailCache then
        self:LoadSystemMails()
    end
    
    -- 添加邮件
    self.systemMailCache.mail_list[mail.uuid] = mail
    
    -- 标记需要保存
    self.lastSaveTime.systemMail = 0
    
    -- 添加到邮件索引
    self:AddGlobalMailIndex(mail.uuid)
    
    return true, mail.uuid
end

-- 获取系统邮件
function MMailDataMgr:GetSystemMail(mailId)
    -- 确保系统邮件缓存已加载
    if not self.systemMailCache then
        self:LoadSystemMails()
    end
    
    -- 获取邮件
    local mail = self.systemMailCache.mail_list[mailId]
    if not mail then
        return false, "系统邮件不存在"
    end
    
    return true, mail
end

-- 更新系统邮件
function MMailDataMgr:UpdateSystemMail(mailId, updates)
    -- 确保系统邮件缓存已加载
    if not self.systemMailCache then
        self:LoadSystemMails()
    end
    
    -- 检查邮件是否存在
    local mail = self.systemMailCache.mail_list[mailId]
    if not mail then
        return false, "系统邮件不存在"
    end
    
    -- 更新字段
    for key, value in pairs(updates) do
        mail[key] = value
    end
    
    -- 标记需要保存
    self.lastSaveTime.systemMail = 0
    
    return true
end

-- 删除系统邮件
function MMailDataMgr:DeleteSystemMail(mailId)
    -- 确保系统邮件缓存已加载
    if not self.systemMailCache then
        self:LoadSystemMails()
    end
    
    -- 检查邮件是否存在
    if not self.systemMailCache.mail_list[mailId] then
        return false, "系统邮件不存在"
    end
    
    -- 删除邮件
    self.systemMailCache.mail_list[mailId] = nil
    
    -- 标记需要保存
    self.lastSaveTime.systemMail = 0
    
    -- 从邮件索引中移除
    self:RemoveGlobalMailIndex(mailId)
    
    return true
end

-- 获取所有系统邮件
function MMailDataMgr:GetAllSystemMails()
    -- 确保系统邮件缓存已加载
    if not self.systemMailCache then
        self:LoadSystemMails()
    end
    
    return true, self.systemMailCache.mail_list
end

---------------------------
-- 活动邮件相关方法
---------------------------

-- 加载活动邮件
function MMailDataMgr:LoadEventMail(eventId)
    -- 检查缓存
    if self.eventMailCache[eventId] then
        return true, self.eventMailCache[eventId]
    end
    
    -- 从云存储加载
    local storageKey = MMailConfig.STORAGE_KEYS.EVENT_MAIL .. eventId
    local success, data = cloudService:GetTableOrEmpty(storageKey)
    
    if success and data and data.event_id == eventId then
        -- 缓存数据
        self.eventMailCache[eventId] = data
        self.lastSaveTime["event_" .. eventId] = MMailUtils.getCurrentTimestamp()
        
        gg.log("成功加载活动邮件数据: " .. eventId)
        return true, data
    else
        -- 创建默认数据
        local defaultData = {
            event_id = eventId,
            mail_list = {},
            deliveries = {},
            summary = {
                total_players = 0,
                delivered_count = 0,
                template_stats = {}
            },
            meta = {
                version = 1,
                last_update = MMailUtils.getCurrentTimestamp(),
                complete = false
            }
        }
        
        self.eventMailCache[eventId] = defaultData
        self.lastSaveTime["event_" .. eventId] = MMailUtils.getCurrentTimestamp()
        
        gg.log("创建默认活动邮件数据: " .. eventId)
        return true, defaultData
    end
end

-- 保存活动邮件
function MMailDataMgr:SaveEventMail(eventId, force)
    -- 检查是否需要保存
    local now = MMailUtils.getCurrentTimestamp()
    local saveKey = "event_" .. eventId
    if not force and self.lastSaveTime[saveKey] and (now - self.lastSaveTime[saveKey] < self.SAVE_INTERVAL) then
        return false
    end
    
    -- 检查缓存是否存在
    local eventData = self.eventMailCache[eventId]
    if not eventData then
        gg.log("保存失败：活动邮件缓存不存在: " .. eventId)
        return false
    end
    
    -- 更新元数据
    eventData.meta.last_update = now
    
    -- 保存到云存储
    local storageKey = MMailConfig.STORAGE_KEYS.EVENT_MAIL .. eventId
    local success = cloudService:SetTable(storageKey, eventData)
    
    if success then
        self.lastSaveTime[saveKey] = now
        gg.log("成功保存活动邮件数据: " .. eventId)
    else
        gg.log("保存活动邮件数据失败: " .. eventId)
    end
    
    return success
end

-- 添加活动邮件
function MMailDataMgr:AddEventMail(eventId, mail)
    -- 加载活动邮件数据
    local success, eventData = self:LoadEventMail(eventId)
    if not success then
        return false, "加载活动邮件数据失败"
    end
    
    -- 添加邮件
    eventData.mail_list[mail.uuid] = mail
    
    -- 标记需要保存
    self.lastSaveTime["event_" .. eventId] = 0
    
    -- 添加到邮件索引
    self:AddEventMailIndex(eventId, mail.uuid)
    
    return true, mail.uuid
end

-- 更新活动邮件发送状态
function MMailDataMgr:UpdateEventMailDelivery(eventId, playerUin, templateId, status)
    -- 加载活动邮件数据
    local success, eventData = self:LoadEventMail(eventId)
    if not success then
        return false, "加载活动邮件数据失败"
    end
    
    -- 确保玩家发送记录存在
    if not eventData.deliveries[playerUin] then
        eventData.deliveries[playerUin] = {}
    end
    
    -- 更新发送状态
    eventData.deliveries[playerUin][templateId] = status
    
    -- 更新统计信息
    if status.status == "sent" and eventData.summary.template_stats[templateId] then
        eventData.summary.template_stats[templateId].sent = (eventData.summary.template_stats[templateId].sent or 0) + 1
        eventData.summary.delivered_count = eventData.summary.delivered_count + 1
    end
    
    -- 标记需要保存
    self.lastSaveTime["event_" .. eventId] = 0
    
    return true
end

-- 获取活动邮件发送状态
function MMailDataMgr:GetEventMailDeliveryStatus(eventId, playerUin, templateId)
    -- 加载活动邮件数据
    local success, eventData = self:LoadEventMail(eventId)
    if not success then
        return false, "加载活动邮件数据失败"
    end
    
    -- 检查发送记录是否存在
    if not eventData.deliveries[playerUin] or not eventData.deliveries[playerUin][templateId] then
        return false, "发送记录不存在"
    end
    
    return true, eventData.deliveries[playerUin][templateId]
end

-- 获取待发送的玩家列表
function MMailDataMgr:GetPendingEventMailPlayers(eventId, templateId, limit)
    -- 加载活动邮件数据
    local success, eventData = self:LoadEventMail(eventId)
    if not success then
        return false, "加载活动邮件数据失败"
    end
    
    limit = limit or 100
    local pendingPlayers = {}
    local count = 0
    
    -- 获取所有玩家索引
    local playerIndex = self.mailIndexCache.player_index
    
    -- 查找未发送的玩家
    for playerUin, _ in pairs(playerIndex) do
        -- 检查是否已发送
        local delivered = eventData.deliveries[playerUin] and 
                          eventData.deliveries[playerUin][templateId] and 
                          eventData.deliveries[playerUin][templateId].status == "sent"
        
        if not delivered then
            table.insert(pendingPlayers, playerUin)
            count = count + 1
            
            if count >= limit then
                break
            end
        end
    end
    
    return true, pendingPlayers
end

---------------------------
-- 辅助方法
---------------------------

-- 合并系统邮件和玩家状态
function MMailDataMgr:MergeSystemMailStatus(systemMail, status)
    local mergedMail = {}
    
    -- 复制系统邮件内容
    for key, value in pairs(systemMail) do
        mergedMail[key] = value
    end
    
    -- 合并玩家特定状态
    mergedMail.read = status.read or false
    mergedMail.claimed = status.claimed or false
    mergedMail.receive_time = status.receive_time
    mergedMail.deleted = status.deleted or false
    
    return mergedMail
end

-- 合并系统邮件到玩家邮件列表
function MMailDataMgr:MergeSystemMails(playerUin, playerMailData)
    local allMails = {}
    
    -- 添加个人邮件
    for id, mail in pairs(playerMailData.mail_list) do
        allMails[id] = mail
    end
    
    -- 获取系统邮件
    local success, systemMailList = self:GetAllSystemMails()
    if success then
        -- 筛选并添加适用于该玩家的系统邮件
        for id, systemMail in pairs(systemMailList) do
            -- 检查邮件是否适用于该玩家
            if self:IsSystemMailApplicableToPlayer(systemMail, playerUin) then
                -- 检查玩家是否已有该系统邮件状态
                local status = playerMailData.system_mail_status[id]
                
                -- 如果没有状态记录，创建一个
                if not status then
                    status = {
                        read = false,
                        claimed = false,
                        receive_time = MMailUtils.getCurrentTimestamp(),
                        deleted = false
                    }
                    
                    -- 保存新状态
                    playerMailData.system_mail_status[id] = status
                    
                    -- 更新统计
                    playerMailData.mail_status.unread_count = playerMailData.mail_status.unread_count + 1
                    if systemMail.attachments and #systemMail.attachments > 0 then
                        playerMailData.mail_status.unclaimed_count = playerMailData.mail_status.unclaimed_count + 1
                    end
                    
                    -- 标记需要保存
                    self.lastSaveTime[playerUin] = 0
                end
                
                -- 合并邮件和状态
                local mergedMail = self:MergeSystemMailStatus(systemMail, status)
                allMails[id] = mergedMail
            end
        end
    end
    
    return allMails
end

-- 检查系统邮件是否适用于指定玩家
function MMailDataMgr:IsSystemMailApplicableToPlayer(mail, playerUin)
    -- 全服邮件
    if mail.target_type == MMailConst.TARGET_TYPE.ALL then
        return true
    end
    
    -- 单个玩家邮件
    if mail.target_type == MMailConst.TARGET_TYPE.SINGLE and mail.receiver == playerUin then
        return true
    end
    
    -- 多玩家邮件
    if mail.target_type == MMailConst.TARGET_TYPE.MULTIPLE and mail.recipients then
        for _, recipient in ipairs(mail.recipients) do
            if recipient == playerUin then
                return true
            end
        end
    end
    
    -- 条件筛选邮件
    if mail.target_type == MMailConst.TARGET_TYPE.CONDITION and mail.condition then
        -- 这里需要实现条件检查逻辑，根据游戏规则判断
        -- 例如检查玩家等级、VIP状态等
        -- 此处简化实现，默认不符合
        return false
    end
    
    -- 公会邮件
    if mail.target_type == MMailConst.TARGET_TYPE.GUILD and mail.guild_id then
        -- 这里需要实现公会检查逻辑
        -- 检查玩家是否在指定公会
        -- 此处简化实现，默认不符合
        return false
    end
    
    return false
end

---------------------------
-- 批量操作相关方法
---------------------------

-- 添加批量操作任务
function MMailDataMgr:AddBatchOperation(operation)
    table.insert(self.pendingBatchOperations, operation)
    return #self.pendingBatchOperations
end

-- 处理批量操作队列
function MMailDataMgr:ProcessBatchQueue()
    if #self.pendingBatchOperations == 0 then
        return
    end
    
    -- 处理队列中的第一个操作
    local operation = table.remove(self.pendingBatchOperations, 1)
    
    -- 根据操作类型执行不同的处理
    if operation.type == "send_system_mail" then
        self:ProcessBatchSendSystemMail(operation)
    elseif operation.type == "send_event_mail" then
        self:ProcessBatchSendEventMail(operation)
    elseif operation.type == "cleanup" then
        self:ProcessBatchCleanup(operation)
    end
end

-- 处理批量发送系统邮件
function MMailDataMgr:ProcessBatchSendSystemMail(operation)
    -- 加载系统邮件
    local success, mail = self:GetSystemMail(operation.mail_id)
    if not success then
        gg.log("批量发送系统邮件失败：邮件不存在: " .. operation.mail_id)
        return
    end
    
    -- 获取当前批次的玩家列表
    local playerList = {}
    local start = operation.current_batch * operation.batch_size + 1
    local finish = math.min(start + operation.batch_size - 1, #operation.recipients)
    
    for i = start, finish do
        table.insert(playerList, operation.recipients[i])
    end
    
    -- 发送邮件给这批玩家
    for _, playerUin in ipairs(playerList) do
        -- 加载玩家邮件数据
        local playerSuccess, playerMailData = self:LoadPlayerMailData(playerUin)
        if playerSuccess then
            -- 检查玩家是否已收到此邮件
            if not playerMailData.system_mail_status[operation.mail_id] then
                -- 创建状态记录
                playerMailData.system_mail_status[operation.mail_id] = {
                    read = false,
                    claimed = false,
                    receive_time = MMailUtils.getCurrentTimestamp(),
                    deleted = false
                }
                
                -- 更新统计
                playerMailData.mail_status.unread_count = playerMailData.mail_status.unread_count + 1
                if mail.attachments and #mail.attachments > 0 then
                    playerMailData.mail_status.unclaimed_count = playerMailData.mail_status.unclaimed_count + 1
                end
                
                -- 保存玩家数据
                self:SavePlayerMailData(playerUin)
            end
        end
    end
    
    -- 更新批次信息
    operation.current_batch = operation.current_batch + 1
    
    -- 检查是否完成所有批次
    if start + operation.batch_size <= #operation.recipients then
        -- 还有更多批次，重新加入队列
        self:AddBatchOperation(operation)
    else
        -- 全部完成
        gg.log("批量发送系统邮件完成: " .. operation.mail_id)
        
        -- 更新邮件状态
        mail.delivery_status = "completed"
        mail.delivery_complete_time = MMailUtils.getCurrentTimestamp()
        self:UpdateSystemMail(operation.mail_id, {
            delivery_status = mail.delivery_status,
            delivery_complete_time = mail.delivery_complete_time
        })
    end
end

-- 处理批量发送活动邮件
function MMailDataMgr:ProcessBatchSendEventMail(operation)
    -- 加载活动邮件数据
    local success, eventData = self:LoadEventMail(operation.event_id)
    if not success then
        gg.log("批量发送活动邮件失败：活动邮件数据加载失败: " .. operation.event_id)
        return
    end
    
    -- 获取模板
    local template = eventData.mail_list[operation.template_id]
    if not template then
        gg.log("批量发送活动邮件失败：模板不存在: " .. operation.template_id)
        return
    end
    
    -- 获取当前批次的玩家列表
    local batchSize = MMailConfig.EVENT_MAIL_CONFIG.DELIVERY_BATCH_SIZE
    local success, pendingPlayers = self:GetPendingEventMailPlayers(operation.event_id, operation.template_id, batchSize)
    
    if not success or #pendingPlayers == 0 then
        -- 没有待发送的玩家，标记完成
        eventData.meta.complete = true
        self:SaveEventMail(operation.event_id, true)
        gg.log("批量发送活动邮件完成: " .. operation.event_id .. ", 模板: " .. operation.template_id)
        return
    end
    
    -- 创建一封样板邮件
    local sampleMail = {
        sender = template.sender or MMailConst.PREDEFINED_SENDER.EVENT,
        sender_type = template.sender_type or MMailConst.SENDER_TYPE.SYSTEM,
        title = template.title,
        content = template.content,
        create_time = MMailUtils.getCurrentTimestamp(),
        expire_time = template.expire_time or MMailUtils.calculateExpiryTime(MMailConfig.MAIL_TYPES.EVENT, template.attachments and #template.attachments > 0, false),
        read = false,
        attachments = template.attachments or {},
        claimed = false,
        type = MMailConfig.MAIL_TYPES.EVENT,
        category = template.category or MMailConfig.MAIL_TYPES.EVENT,
        importance = template.importance or MMailConfig.IMPORTANCE_LEVEL.NORMAL,
        deleted = false,
        event_id = operation.event_id,
        template_id = operation.template_id
    }
    
    -- 发送邮件给这批玩家
    for _, playerUin in ipairs(pendingPlayers) do
        -- 创建个性化邮件
        local mailCopy = {}
        for k, v in pairs(sampleMail) do
            mailCopy[k] = v
        end
        
        -- 设置收件人
        mailCopy.uuid = MMailUtils.generateMailUUID()
        mailCopy.receiver = playerUin
        
        -- 替换变量
        -- 这里可以添加个性化变量替换逻辑
        -- 例如获取玩家名称、等级等信息
        
        -- 添加到玩家邮箱
        local addSuccess, _ = self:AddMailToPlayer(playerUin, mailCopy)
        
        -- 更新发送状态
        local deliveryStatus = {
            status = addSuccess and "sent" or "failed",
            mail_uuid = addSuccess and mailCopy.uuid or nil,
            send_time = MMailUtils.getCurrentTimestamp(),
            variables = {} -- 可以记录使用的变量
        }
        
        self:UpdateEventMailDelivery(operation.event_id, playerUin, operation.template_id, deliveryStatus)
    end
    
    -- 还需要继续处理，重新加入队列
    if #pendingPlayers == batchSize then
        self:AddBatchOperation(operation)
    else
        -- 处理完成
        eventData.meta.complete = true
        self:SaveEventMail(operation.event_id, true)
        gg.log("批量发送活动邮件完成: " .. operation.event_id .. ", 模板: " .. operation.template_id)
    end
end

-- 处理批量清理过期邮件
function MMailDataMgr:ProcessBatchCleanup(operation)
    local now = MMailUtils.getCurrentTimestamp()
    
    -- 清理系统邮件
    if operation.cleanup_system then
        local _, systemMails = self:GetAllSystemMails()
        if systemMails then
            local needSave = false
            
            for id, mail in pairs(systemMails) do
                -- 检查是否过期
                if MMailUtils.isExpired(mail.expire_time) then
                    -- 检查过期时间是否超过保留期
                    local retentionPeriod = 7 * 24 * 3600 -- 7天
                    if now - mail.expire_time > retentionPeriod then
                        -- 删除系统邮件
                        systemMails[id] = nil
                        needSave = true
                        
                        -- 从索引中移除
                        self:RemoveGlobalMailIndex(id)
                    end
                end
            end
            
            if needSave then
                self:SaveSystemMails(true)
            end
        end
    end
    
    -- 清理玩家邮件
    if operation.cleanup_player and operation.player_batch and #operation.player_batch > 0 then
        for _, playerUin in ipairs(operation.player_batch) do
            local success, playerMailData = self:LoadPlayerMailData(playerUin)
            if success then
                local needSave = false
                
                -- 清理个人邮件
                for id, mail in pairs(playerMailData.mail_list) do
                    -- 检查是否过期
                    if MMailUtils.isExpired(mail.expire_time) then
                        -- 根据邮件状态决定是否删除
                        local shouldDelete = false
                        
                        -- 已领取附件的邮件
                        if mail.claimed then
                            -- 如果过期超过7天
                            if now - mail.expire_time > 7 * 24 * 3600 then
                                shouldDelete = true
                            end
                        else
                            -- 未领取附件的邮件
                            -- 如果过期超过30天
                            if now - mail.expire_time > 30 * 24 * 3600 then
                                shouldDelete = true
                            end
                        end
                        
                        if shouldDelete then
                            -- 删除邮件
                            playerMailData.mail_list[id] = nil
                            needSave = true
                            
                            -- 更新统计
                            if not mail.read then
                                playerMailData.mail_status.unread_count = math.max(0, playerMailData.mail_status.unread_count - 1)
                            end
                            
                            if mail.attachments and #mail.attachments > 0 and not mail.claimed then
                                playerMailData.mail_status.unclaimed_count = math.max(0, playerMailData.mail_status.unclaimed_count - 1)
                            end
                        end
                    end
                end
                
                -- 清理系统邮件状态
                for id, status in pairs(playerMailData.system_mail_status) do
                    -- 检查系统邮件是否存在
                    local systemMailExists = self.systemMailCache and self.systemMailCache.mail_list and self.systemMailCache.mail_list[id]
                    
                    if not systemMailExists then
                        -- 系统邮件已删除，清理状态
                        playerMailData.system_mail_status[id] = nil
                        needSave = true
                        
                        -- 更新统计
                        if not status.read then
                            playerMailData.mail_status.unread_count = math.max(0, playerMailData.mail_status.unread_count - 1)
                        end
                        
                        local systemMail = self.systemMailCache and self.systemMailCache.mail_list and self.systemMailCache.mail_list[id]
                        if systemMail and systemMail.attachments and #systemMail.attachments > 0 and not status.claimed then
                            playerMailData.mail_status.unclaimed_count = math.max(0, playerMailData.mail_status.unclaimed_count - 1)
                        end
                    end
                end
                
                if needSave then
                    -- 更新清理时间
                    playerMailData.mail_meta.last_cleanup = now
                    
                    -- 保存玩家数据
                    self:SavePlayerMailData(playerUin, true)
                    
                    -- 更新玩家邮件索引
                    self:UpdatePlayerMailIndex(playerUin, playerMailData.mail_status)
                end
            end
        end
    end
    
    -- 安排下一批玩家清理
    if operation.cleanup_player and operation.index < operation.total_players then
        -- 计算下一批玩家
        local start = operation.index + 1
        local finish = math.min(start + operation.batch_size - 1, operation.total_players)
        
        local nextBatch = {}
        for i = start, finish do
            table.insert(nextBatch, operation.player_list[i])
        end
        
        -- 创建新的清理任务
        local nextOperation = {
            type = "cleanup",
            cleanup_system = false, -- 系统邮件只清理一次
            cleanup_player = true,
            player_batch = nextBatch,
            index = finish,
            total_players = operation.total_players,
            batch_size = operation.batch_size,
            player_list = operation.player_list
        }
        
        -- 添加到队列
        self:AddBatchOperation(nextOperation)
    end
end

---------------------------
-- 数据维护相关方法
---------------------------

-- 保存所有缓存数据
function MMailDataMgr:SaveAllCachedData()
    -- 保存邮件索引
    if self.mailIndexCache and self.lastSaveTime.mailIndex and 
       (MMailUtils.getCurrentTimestamp() - self.lastSaveTime.mailIndex >= self.SAVE_INTERVAL) then
        self:SaveMailIndex()
    end
    
    -- 保存系统邮件
    if self.systemMailCache and self.lastSaveTime.systemMail and 
       (MMailUtils.getCurrentTimestamp() - self.lastSaveTime.systemMail >= self.SAVE_INTERVAL) then
        self:SaveSystemMails()
    end
    
    -- 保存玩家邮件
    for playerUin, _ in pairs(self.playerMailCache) do
        if self.lastSaveTime[playerUin] and 
           (MMailUtils.getCurrentTimestamp() - self.lastSaveTime[playerUin] >= self.SAVE_INTERVAL) then
            self:SavePlayerMailData(playerUin)
        end
    end
    
    -- 保存活动邮件
    for eventId, _ in pairs(self.eventMailCache) do
        local saveKey = "event_" .. eventId
        if self.lastSaveTime[saveKey] and 
           (MMailUtils.getCurrentTimestamp() - self.lastSaveTime[saveKey] >= self.SAVE_INTERVAL) then
            self:SaveEventMail(eventId)
        end
    end
end

-- 清理缓存
function MMailDataMgr:CleanupCache()
    local now = MMailUtils.getCurrentTimestamp()
    
    -- 如果上次清理时间不足间隔，跳过
    if now - self.lastCacheCleanup < self.CACHE_EXPIRY then
        return
    end
    
    -- 更新清理时间
    self.lastCacheCleanup = now
    
    -- 清理玩家邮件缓存
    for playerUin, lastSaveTime in pairs(self.lastSaveTime) do
        -- 跳过非玩家数据的保存时间记录
        if type(playerUin) == "number" or string.match(playerUin, "^%d+$") then
            -- 超过缓存过期时间且已保存的数据，从缓存中移除
            if now - lastSaveTime >= self.CACHE_EXPIRY and self.playerMailCache[playerUin] then
                self.playerMailCache[playerUin] = nil
                gg.log("清理玩家邮件缓存: " .. playerUin)
            end
        end
    end
    
    -- 清理活动邮件缓存
    for eventId, _ in pairs(self.eventMailCache) do
        local saveKey = "event_" .. eventId
        if self.lastSaveTime[saveKey] and now - self.lastSaveTime[saveKey] >= self.CACHE_EXPIRY then
            self.eventMailCache[eventId] = nil
            gg.log("清理活动邮件缓存: " .. eventId)
        end
    end
end

-- 启动邮件清理
function MMailDataMgr:StartMailCleanup()
    -- 获取所有玩家ID
    local playerList = {}
    
    -- 从邮件索引获取玩家列表
    if self.mailIndexCache and self.mailIndexCache.player_index then
        for playerUin, _ in pairs(self.mailIndexCache.player_index) do
            table.insert(playerList, playerUin)
        end
    end
    
    -- 创建清理任务
    local cleanupOperation = {
        type = "cleanup",
        cleanup_system = true,
        cleanup_player = true,
        player_batch = {},
        index = 0,
        total_players = #playerList,
        batch_size = 50,
        player_list = playerList
    }
    
    -- 计算第一批玩家
    local batchSize = math.min(cleanupOperation.batch_size, #playerList)
    for i = 1, batchSize do
        table.insert(cleanupOperation.player_batch, playerList[i])
    end
    cleanupOperation.index = batchSize
    
    -- 添加到队列
    self:AddBatchOperation(cleanupOperation)
    
    gg.log("启动邮件清理任务，共 " .. #playerList .. " 名玩家")
    
    return true
end

-- 导出接口
return MMailDataMgr:Init()