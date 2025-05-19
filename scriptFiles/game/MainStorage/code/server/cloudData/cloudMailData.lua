print("Hello world!")--- 邮件数据云存储管理模块 - 精简版
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


---@class PlayerMailData
---@field mails table
---@field last_update number

---@class PlayerBitmapData
---@field bitmap table
---@field last_update number

---@class MailDataStruct
---@field player_mail_data_ PlayerMailData
---@field player_mail_bitmap_data_ PlayerBitmapData


---@class CloudMailData
local CloudMailData = {

    
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
---@param force boolean 是否强制保存
---@return boolean 是否成功
function CloudMailData:SavePlayerMail(uin, mailData)
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
    
    return mailData.id
end



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
    
    
    if success and data and data.bitmap then
        return data
    else
        return {
            uin = uin,
            bitmap = {},
            last_update = os.time()
        }
    end

end

--- 保存玩家邮件位图
---@param uin number 玩家ID
---@param force boolean 是否强制保存
---@return boolean 是否成功
function CloudMailData:SavePlayerMailBitmap(uin, bitmapData)
    -- 保存玩家邮件位图到云存储
    if not bitmapData then return false end
    
    -- 检查是否需要保存
    local now = os.time()
    -- 更新时间戳
    bitmapData.last_update = now
    -- 保存到云存储
    cloudService:SetTableAsync("mail_bitmap_" .. uin, bitmapData, function(success)
        if not success then
            gg.log("保存玩家邮件位图失败", uin)
            return false
        else
            gg.log("保存玩家邮件位图成功", uin)
            return true
        end
    end)
end


--- 玩家登录事件处理
---@param uin number 玩家ID
function CloudMailData:OnPlayerLogin(uin)
    -- 加载个人邮件
    local player_mail_data_ = self:LoadPlayerMail(uin)
    -- 加载邮件位图
    local player_mail_bitmap_data_ = self:LoadPlayerMailBitmap(uin)
    local ret = {
        player_mail_data_ = player_mail_data_,
        player_mail_bitmap_data_ = player_mail_bitmap_data_
    }
    return ret
end

--- 玩家登出事件处理
---@param uin number 玩家ID
---@param mial_data table 邮件数据
function CloudMailData:OnPlayerLogout(uin,mial_data)
    -- 保存个人邮件
    local playerMail = mial_data.player_mail_data_
    local playerMailBitmapData = mial_data.player_mail_bitmap_data_
    self:SavePlayerMail(uin, playerMail)
    -- 保存邮件位图
    self:SavePlayerMailBitmap(uin, playerMailBitmapData)
    
    gg.log("玩家邮件数据保存完成", uin)
    
end

return CloudMailData