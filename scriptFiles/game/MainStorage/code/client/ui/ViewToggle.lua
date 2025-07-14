local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg


---@class ViewToggle:ViewButton
---@field New fun(node: SandboxNode, ui: ViewBase, path?: string, realButtonPath?: string): ViewButton
local  ViewToggle = ClassMgr.Class("ViewToggle", ViewButton)

function ViewToggle:OnInit(node, ui)
    self.isOn = false
    self.unselectedImg = self.node.Icon
    self.selectedImg = self.node:GetAttribute("图片-点击")
end

function ViewToggle:OnClick(vector2)
    if not self.enabled then return end
    if self.clickCb then
        if self.clickCb(self.ui, self) == false then
            return
        end
    end
    self:SetOn(not self.isOn)
    ClientEventManager.Publish("ButtonClicked", {
        button = self
    })
end

function ViewToggle:SetOn(isOn)
    self.isOn = isOn
    if isOn then
        self.img.Icon = self.selectedImg
        self.normalImg = self.selectedImg
        self.hoverImg = self.unselectedImg
        self.clickImg = self.unselectedImg
    else
        self.img.Icon = self.unselectedImg
        self.normalImg = self.unselectedImg
        self.hoverImg = self.selectedImg
        self.clickImg = self.selectedImg
    end
end

return ViewToggle
