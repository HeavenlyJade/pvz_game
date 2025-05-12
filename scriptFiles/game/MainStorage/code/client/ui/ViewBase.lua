local MainStorage = game:GetService("MainStorage")
local CommonModule = require(MainStorage.code.common.CommonModule) ---@type CommonModule

local displayingUI = {}
local allUI = {}

---@class ViewConfig
---@field uiName string 界面名称
---@field hideOnInit boolean 是否在初始化时隐藏
---@field layer number 0=主界面Hud， >1=GUI界面。 GUI在打开时关闭其他同layer的GUI

---@class ViewBase:Class
---@field New fun(node: SandboxNode, config: ViewConfig): ViewBase
---@field GetUI fun(name: string): ViewBase
local  ViewBase = CommonModule.Class("ViewBase")

ViewBase.UiBag = {} ---@type UiBag
ViewBase.UIConfirm = {} ---@type UIConfirm

---@generic T : ViewBase
---@param name string
---@return T
function ViewBase.GetUI(name)
    return allUI[name]
end

---@generic T : UIComponent
---@param path string
---@return T
function ViewBase:Get(path)
    local node = self.node
    for part in path:gmatch("[^/]+") do --用/分割字符串
        if part ~= "" then
            node = node[part]
        end
    end
    return node
end

---@param node SandboxNode
---@param config ViewConfig
function ViewBase:OnInit(node, config)
    self.node = node ---@type SandboxNode
    self.hideOnInit = config.hideOnInit or true
    self.layer = config.layer or 1
    self.displaying = false
    self.isOnTop = false
    self.tweeningComponents = {} ---@type table<ViewComponent, boolean>
    self.tweenTaskId = nil
    allUI[config.uiName] = self
    ViewBase[config.uiName] = self

    if self.hideOnInit then
        self:Close()
    else
        self:Open()
    end
end

function ViewBase:RegisterTween(component)
    if not self.tweeningComponents[component] then
        self.tweeningComponents[component] = true
    end
end

function ViewBase:Close()
    self.node.Enabled = false
    self.node.Visible = false
    if displayingUI[self.layer] == self then
        displayingUI[self.layer] = nil
    end
    if self.isOnTop then
        local maxLayer = 1
        for layer, _ in pairs(displayingUI) do
            if layer > maxLayer then
                maxLayer = layer
            end
        end
        if displayingUI[maxLayer] then
            local topUI = displayingUI[maxLayer]
            topUI.Enabled = true
            topUI.Visible = true
            topUI.isOnTop = true
        end
    end
    self.displaying = false
end

function ViewBase:Open()
    self.displaying = true
    self.node.Enabled = true
    self.node.Visible = true
    if displayingUI[self.layer] then
        local oldUI = displayingUI[self.layer]
        oldUI.isOnTop = false
        oldUI:Close()
    end
    self.isOnTop = true
    for i = 1, self.layer do
        if displayingUI[i] then
            displayingUI[i].isOnTop = false
            displayingUI[i].Enabled = false
        end
    end
    displayingUI[self.layer] = self
end

function ViewBase:OnHide()

end


return ViewBase