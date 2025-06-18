--- 邮件系统主模块
--- V109 miniw-haima
--- 集成邮件管理器和全局邮件管理器

local MainStorage = game:GetService("MainStorage")
local MailManager = require(MainStorage.code.server.Mail.MailManager) ---@type MailManager
local GlobalMailManager = require(MainStorage.code.server.Mail.GlobalMailManager) ---@type GlobalMailManager

local Mail = {
    Manager = MailManager,
    GlobalManager = GlobalMailManager
}

return Mail
