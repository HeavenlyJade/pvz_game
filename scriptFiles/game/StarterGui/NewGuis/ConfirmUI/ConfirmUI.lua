local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList

local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton

print("ConfirmUI LOCAL SCRIPT")

local uiConfig = {
    uiName = "ConfirmUI",
    layer = 4,
    hideOnInit = true,
}

---@class ConfirmUI:ViewBase
local ConfirmUI = ClassMgr.Class("ConfirmUI", ViewBase)

function ConfirmUI:OnInit(node, config)
    print("ConfirmUI OnInit")
    self.title = self:Get("ui/title/title_text").node ---@type UITextLabel
    self.content = self:Get("ui/content").node ---@type UITextLabel
    self.confirmBtn = self:Get("ui/b_confirm", ViewButton) ---@type ViewButton
    self.confirmBtn.clickCb = function(ui, button)
        self.closing = true
        if self.confirmCallback then
            self.confirmCallback()
        end
        if self.closing then
            self:Close()
        end
    end
    self.cancelBtn = self:Get("ui/b_cancel", ViewButton) ---@type ViewButton
    self.cancelBtn.clickCb = function(ui, button)
        self:Close()
        if self.cancelCallback then
            self.cancelCallback()
        end
    end
    self.confirmCallback = nil ---@type function
    self.cancelCallback = nil ---@type function
end

function ConfirmUI:Display(title, content, confirmCallback, cancelCallback)
    self.closing = false
    self.title.Title = title
    self.content.Title = content
    self.confirmCallback = confirmCallback
    self.cancelCallback = cancelCallback
    self:Open()
end

return ConfirmUI.New(script.Parent, uiConfig)