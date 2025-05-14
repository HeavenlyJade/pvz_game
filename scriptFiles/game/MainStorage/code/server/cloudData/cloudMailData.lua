--- 邮件数据云存储管理模块 - 精简版
--- V109 miniw-haima
--- 负责管理邮件数据的存储和检索，包括个人邮件和全服邮件

local game = game
local pairs = pairs
local ipairs = ipairs
local table = table
local os = os
local math = math

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local cloudService = game:GetService("CloudService")   ---@type CloudService

---@class CloudMailData
local CloudMailData = {
    -- 个人邮件缓存: {[uin] = {mails = {邮件列表}, last_update = 时间戳}}
    player_mail_cache = {},
    
    -- 全服邮件缓存: {mails = {邮件列表}, last_update = 时间戳}
    global_mail_cache = nil,
    
    -- 位图索引缓存: {[uin] = {bitmap = {}, last_update = 时间戳}}
    mail_bitmap_cache = {},
    
    -- 保存间隔（秒）
    SAVE_INTERVAL = 60,
    
    -- 邮件过期时间（天）
    DEFAULT_EXPIRE_DAYS = 30
}

--- 初始化邮件数据系统
function CloudMailData:Init()
    -- 加载全服邮件
    self:LoadGlobalMail()
    
    gg.log("邮件数据系统初始化完成")
    return self
end

--- 生成邮件ID
---@param prefix string 前缀，如"mail_p_"或"mail_g_"
---@return string 生成的邮件ID
function CloudMailData:GenerateMailId(prefix)
    local timestamp = os.time()
    local random = math.random(10000, 99999)
    return prefix .. timestamp .. "_" .. random
end



---------------------------
-- 个人邮件相关函数
---------------------------

--- 加载玩家邮件
---@param uin number 玩家ID
---@return table 玩家邮件数据
function CloudMailData:LoadPlayerMail(uin)
    local ret, data = cloudService:GetTableOrEmpty('mail_player_' .. uin)
    
    if ret and data and data.mails then
        self.player_mail_cache[uin] = data
        gg.log("加载玩家邮件成功", uin)
    else
        -- 创建默认邮件数据
        self.player_mail_cache[uin] = {
            uin = uin,
            mails = {},
            last_update = os.time()
        }
        gg.log("创建玩家邮件默认数据", uin)
    end
    
    return self.player_mail_cache[uin]
end

--- 保存玩家邮件
---@param uin number 玩家ID
---@param force boolean 是否强制保存
---@return boolean 是否成功
function CloudMailData:SavePlayerMail(uin, force)
    local mailData = self.player_mail_cache[uin]
    if not mailData then
        return false
    end
    
    -- 检查是否需要保存
    local now = os.time()
    if not force and now - mailData.last_update < self.SAVE_INTERVAL then
        return false
    end
    
    -- 更新时间戳
    mailData.last_update = now
    
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

--- 获取玩家邮件数据
---@param uin number 玩家ID
---@return table 玩家邮件数据
function CloudMailData:GetPlayerMail(uin)
    if not self.player_mail_cache[uin] then
        return self:LoadPlayerMail(uin)
    end
    
    return self.player_mail_cache[uin]
end

--- 添加邮件到玩家邮箱
---@param uin number 玩家ID
---@param mailData table 邮件数据
---@return string 邮件ID
function CloudMailData:AddPlayerMail(uin, mailData)
    local playerMail = self:GetPlayerMail(uin)
    
    -- 生成邮件ID
    mailData.id = self:GenerateMailId("mail_p_")
    
    -- 设置时间戳
    mailData.send_time = os.time()
    
    -- 设置过期时间（默认30天）
    local expireDays = mailData.expire_days or self.DEFAULT_EXPIRE_DAYS
    mailData.expire_time = mailData.send_time + (expireDays * 86400)
    
    -- 设置初始状态
    mailData.status = 0  -- 未读
    
    -- 检查附件格式
    if not mailData.attachments then
        mailData.attachments = {}
    end
    
    -- 添加新邮件
    playerMail.mails[mailData.id] = mailData
    playerMail.last_update = os.time()
    
    -- 保存到云存储
    self:SavePlayerMail(uin, true)
    
    return mailData.id
end

---------------------------
-- 全服邮件相关函数
---------------------------

--- 加载全服邮件
---@return table 全服邮件数据
function CloudMailData:LoadGlobalMail()
    local success, data = cloudService:GetTableOrEmpty("mail_global")
    
    if success and data and data.mails then
        self.global_mail_cache = data
        gg.log("加载全服邮件成功")
    else
        -- 初始化默认全服邮件缓存
        self.global_mail_cache = {
            mails = {},
            last_update = os.time()
        }
        gg.log("创建全服邮件默认数据")
    end
    
    return self.global_mail_cache
end

--- 保存全服邮件
---@param force boolean 是否强制保存
---@return boolean 是否成功
function CloudMailData:SaveGlobalMail(force)
    if not self.global_mail_cache then
        return false
    end
    
    -- 检查是否需要保存
    local now = os.time()
    if not force and now - self.global_mail_cache.last_update < self.SAVE_INTERVAL then
        return false
    end
    
    -- 更新时间戳
    self.global_mail_cache.last_update = now
    
    -- 保存到云存储
    cloudService:SetTableAsync("mail_global", self.global_mail_cache, function(success)
        if not success then
            gg.log("保存全服邮件失败")
        else
            gg.log("保存全服邮件成功")
        end
    end)
    
    return true
end

--- 获取全服邮件数据
---@return table 全服邮件数据
function CloudMailData:GetGlobalMail()
    if not self.global_mail_cache then
        return self:LoadGlobalMail()
    end
    
    return self.global_mail_cache
end

--- 添加全服邮件
---@param mailData table 邮件数据
---@return string 邮件ID
function CloudMailData:AddGlobalMail(mailData)
    if not self.global_mail_cache then
        self:LoadGlobalMail()
    end
    
    -- 生成邮件ID
    mailData.id = self:GenerateMailId("mail_g_")
    
    -- 设置时间戳
    mailData.send_time = os.time()
    
    -- 设置过期时间（默认30天）
    local expireDays = mailData.expire_days or self.DEFAULT_EXPIRE_DAYS
    mailData.expire_time = mailData.send_time + (expireDays * 86400)
    
    -- 检查附件格式
    if not mailData.attachments then
        mailData.attachments = {}
    end
    
    -- 添加新邮件
    self.global_mail_cache.mails[mailData.id] = mailData
    self.global_mail_cache.last_update = os.time()
    
    -- 保存全服邮件
    self:SaveGlobalMail(true)
    
    return mailData.id
end

---------------------------
-- 位图索引相关函数
---------------------------

--- 加载玩家邮件位图
---@param uin number 玩家ID
---@return table 位图数据
function CloudMailData:LoadPlayerMailBitmap(uin)
    -- 从云存储加载玩家邮件位图
    local success, data = cloudService:GetTableOrEmpty("mail_bitmap_" .. uin)
    
    -- 初始化默认位图
    self.mail_bitmap_cache[uin] = {
        bitmap = {},
        last_update = os.time()
    }
    
    if success and data and data.bitmap then
        self.mail_bitmap_cache[uin] = data
        gg.log("加载玩家邮件位图成功", uin)
    else
        gg.log("创建玩家邮件位图默认数据", uin)
    end
    
    return self.mail_bitmap_cache[uin]
end

--- 保存玩家邮件位图
---@param uin number 玩家ID
---@param force boolean 是否强制保存
---@return boolean 是否成功
function CloudMailData:SavePlayerMailBitmap(uin, force)
    -- 保存玩家邮件位图到云存储
    local bitmapData = self.mail_bitmap_cache[uin]
    if not bitmapData then return false end
    
    -- 检查是否需要保存
    local now = os.time()
    if not force and now - bitmapData.last_update < self.SAVE_INTERVAL then
        return false
    end
    
    -- 更新时间戳
    bitmapData.last_update = now
    
    -- 保存到云存储
    cloudService:SetTableAsync("mail_bitmap_" .. uin, bitmapData, function(success)
        if not success then
            gg.log("保存玩家邮件位图失败", uin)
        else
            gg.log("保存玩家邮件位图成功", uin)
        end
    end)
    
    return true
end

--- 获取玩家邮件位图
---@param uin number 玩家ID
---@return table 位图数据
function CloudMailData:GetBitmap(uin)
    -- 获取玩家位图，如不存在则加载
    if not self.mail_bitmap_cache[uin] then
        self:LoadPlayerMailBitmap(uin)
    end
    return self.mail_bitmap_cache[uin].bitmap
end

--- 设置邮件位状态
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@param bitValue number 位值
---@return boolean 是否成功
function CloudMailData:SetMailBit(uin, mailId, bitValue)
    -- 设置特定邮件的位状态
    local bitmap = self:GetBitmap(uin)
    bitmap[mailId] = bitValue
    self.mail_bitmap_cache[uin].last_update = os.time()
    
    -- 延迟保存
    self:SavePlayerMailBitmap(uin, false)
    
    return true
end

--- 获取邮件位状态
---@param uin number 玩家ID
---@param mailId string 邮件ID
---@return number 位值
function CloudMailData:GetMailBit(uin, mailId)
    -- 获取特定邮件的位状态
    local bitmap = self:GetBitmap(uin)
    return bitmap[mailId] or 0  -- 默认为未读未领取
end

---------------------------
-- 玩家事件响应函数
---------------------------

--- 玩家登录事件处理
---@param uin number 玩家ID
function CloudMailData:OnPlayerLogin(uin)
    -- 加载个人邮件
    self:LoadPlayerMail(uin)
    
    -- 加载邮件位图
    self:LoadPlayerMailBitmap(uin)
    
    gg.log("玩家邮件数据加载完成", uin)
end

--- 玩家登出事件处理
---@param uin number 玩家ID
function CloudMailData:OnPlayerLogout(uin)
    -- 保存个人邮件
    self:SavePlayerMail(uin, true)
    
    -- 保存邮件位图
    self:SavePlayerMailBitmap(uin, true)
    
    gg.log("玩家邮件数据保存完成", uin)
    
    -- 清理缓存
    self.player_mail_cache[uin] = nil
    self.mail_bitmap_cache[uin] = nil
end

return CloudMailData:Init()