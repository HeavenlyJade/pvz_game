local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

local displayingUI = {}
local allUI = {}

---@class ViewConfig
---@field uiName string 界面名称
---@field hideOnInit boolean 是否在初始化时隐藏
---@field layer number 0=主界面Hud， >1=GUI界面。 GUI在打开时关闭其他同layer的GUI

---@class ViewBase:Class
---@field New fun(node: SandboxNode, config: ViewConfig): ViewBase
---@field GetUI fun(name: string): ViewBase
local ViewBase = ClassMgr.Class("ViewBase")

ViewBase.UiBag = nil ---@type UiBag
ViewBase.UIConfirm = nil ---@type UIConfirm

---@generic T : ViewBase
---@param name string
---@return T
function ViewBase.GetUI(name)
    return allUI[name]
end

---@generic T : ViewComponent
---@param path string 组件路径
---@param type? T 组件类型
---@param ... any 额外参数
---@return T
function ViewBase:Get(path, type, ...)
    local cacheKey = path
    if self.componentCache[cacheKey] then
        return self.componentCache[cacheKey]
    end

    local node = self.node
    local fullPath = ""
    local lastPart = ""
    for part in path:gmatch("[^/]+") do -- 用/分割字符串
        if part ~= "" then
            lastPart = part
            if not node then
                gg.log(string.format("UI[%s]获取路径[%s]失败: 在[%s]处节点不存在", self.className, path,
                    fullPath))
                return nil
            end
            node = node[part]
            if fullPath == "" then
                fullPath = part
            else
                fullPath = fullPath .. "/" .. part
            end
        end
    end

    if not node then
        gg.log(string.format("UI[%s]获取路径[%s]失败: 最终节点[%s]不存在", self.className, path, lastPart))
        return nil
    end

    if not type then
        local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
        type = ViewComponent
    end
    ---@cast type ViewComponent
    local component = type.New(node, self, fullPath, ...)

    -- Cache the component
    self.componentCache[cacheKey] = component
    return component
end

---@param node SandboxNode
---@param config ViewConfig
function ViewBase:OnInit(node, config)
    self.componentCache = {}
    self.node = node ---@type SandboxNode
    self.hideOnInit = config.hideOnInit == nil and true or config.hideOnInit
    self.layer = config.layer == nil and 1 or config.layer
    self.displaying = false
    self.isOnTop = false
    self.tweeningComponents = {} ---@type table<ViewComponent, boolean>
    self.tweenTaskId = nil
    allUI[self.className] = self
    ViewBase[self.className] = self

    -- print("config", self.className, self.hideOnInit)
    if self.hideOnInit then
        self:Close()
    else
        self:Open()
    end
end

function ViewBase:RegisterTween(component)
    if not self.tweeningComponents[component] then
        self.tweeningComponents[component] = true

        if not self.tweenTaskId then
            self.tweenTaskId = ClientScheduler.add(function()
                -- local traceback = debug.traceback()
                -- print("SetVisible traceback:", traceback)
                local hasActiveTweens = false
                local componentsToRemove = {}

                -- Update all tweening components
                for component, _ in pairs(self.tweeningComponents) do
                    if component.currentTween then
                        local isFinished = component.currentTween:Update()
                        if isFinished then
                            -- Handle next tween if exists
                            if component.currentTween.nextTween then
                                component.currentTween = component.currentTween.nextTween
                                hasActiveTweens = true
                            else
                                -- Mark component for removal
                                component.currentTween = nil
                                table.insert(componentsToRemove, component)
                            end
                        else
                            hasActiveTweens = true
                        end
                    end
                end

                -- Remove finished components
                for _, component in ipairs(componentsToRemove) do
                    self.tweeningComponents[component] = nil
                end

                -- If no more active tweens, cancel the task
                if not hasActiveTweens then
                    if self.tweenTaskId then
                        ClientScheduler.cancel(self.tweenTaskId)
                        self.tweenTaskId = nil
                    end
                end
            end, 0, 1, true)
        end
    end
end

function ViewBase:SetVisible(visible)
    self.node.Enabled = visible
    self.node.Visible = visible
end

function ViewBase:Close()
    self:SetVisible(false)
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
            topUI:SetVisible(true)
            topUI.isOnTop = true
        end
    end
    self.displaying = false
end

function ViewBase:Open()
    self.displaying = true
    self:SetVisible(true)
    if self.layer > 0 then
        if displayingUI[self.layer] then
            local oldUI = displayingUI[self.layer]
            if oldUI ~= self then
                oldUI.isOnTop = false
                oldUI:Close()
            end
        end
        self.isOnTop = true
        for i = 1, self.layer do
            if displayingUI[i] then
                displayingUI[i].isOnTop = false
                displayingUI[i].node.Enabled = false
            end
        end
        displayingUI[self.layer] = self
    end
end

function ViewBase:OnHide()

end

return ViewBase
