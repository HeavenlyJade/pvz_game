local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local Tweens = require(MainStorage.code.client.ui.Tweens) ---@type Tweens
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager


---@class SettingBut
local SettingBut = {
    bg = nil,
}


function SettingBut:OnInit()
    
end