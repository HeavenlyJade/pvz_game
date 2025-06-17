local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class FocusOnNode
---@field UI名 string
---@field 控件路径 string
---@field 提示文本 string

---@class FocusChain
---@field 聚焦UI FocusOnNode[]
---@field 完成时执行指令 string


---@class ForceClickHud:ViewBase
local ForceClickHud = ClassMgr.Class("ForceClickHud", ViewBase)

local uiConfig = {
    uiName = "ForceClickHud",
    layer = 20,
    hideOnInit = true
}

function ForceClickHud:OnInit(node, config)
    self.text = self:Get("文本").node
    self.up = self:Get("上").node
    self.down = self:Get("下").node
    self.left = self:Get("左").node
    self.right = self:Get("右").node
    self.focusingChain = nil ---@type FocusChain
    self.index = 0
    self.lastFocusTime = 0 ---@type number
    self.allowClickAnywhere = false
    ClientEventManager.Subscribe("FocusOnUI", function (evt)
        ---@cast evt FocusChain
        self.focusingChain = evt
        self.index = 0
        self:FocusOnNextNode()
    end)

    -- 监听按钮点击事件
    ClientEventManager.Subscribe("ButtonTouchIn", function(data)
        if self.displaying then
            self:FocusOnNextNode()
            if self.nodePressCb then
                self.nodePressCb:Disconnect()
                self.nodePressCb = nil
            end
        end
    end)
    
    if game.UserInputService.TouchEnabled then -- 触摸设备
        game.UserInputService.TouchStarted:Connect(
            function(inputObj, gameprocessed)
                self:OnClickAnywhere()
            end
        )
    elseif game.UserInputService.MouseEnabled then -- 鼠标设备
        game.UserInputService.InputBegan:Connect(
            function(inputObj, gameprocessed)
                -- 只有鼠标右键才开始摄像头控制
                if inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
                    self:OnClickAnywhere()
                end
            end
        )
    end

    ClientEventManager.Subscribe("PressKey", function(data)
        self:OnClickAnywhere()
    end)
end

function ForceClickHud:OnClickAnywhere()
    if self.allowClickAnywhere then
        self.allowClickAnywhere = false
        self:FocusOnNextNode()
        if self.nodePressCb then
            self.nodePressCb:Disconnect()
            self.nodePressCb = nil
        end
    end
end

function ForceClickHud:FocusOnNextNode()
    local currentTime = gg.GetTimeStamp()
    if currentTime - self.lastFocusTime < 0.1 then
        return
    end
    self.lastFocusTime = currentTime

    self.index = self.index + 1
    if not self.focusingChain or #self.focusingChain["聚焦UI"] < self.index then
        self:Close()
        gg.network_channel:FireServer({
            cmd = "FinishFocusUI"
        })
        return
    end
    local focus = self.focusingChain["聚焦UI"][self.index]
    if game.RunService:IsPC() and focus["若是PC端则改为"] and focus["若是PC端则改为"]["UI名"] then
        focus = focus["若是PC端则改为"]
    end
    local ui = ViewBase.GetUI(focus["UI名"])
    if not ui then
        print(string.format("配置错误: 路径 %s 需求的UI %s 不存在!", focus["控件路径"], focus["UI名"]))
        return
    end
    if not ui.displaying then
        ui:Open()
    end
    local node = ui:Get(focus["控件路径"])
    if not node then
        print(string.format("配置错误: UI %s 的节点 %s 不存在!", focus["UI名"], focus["控件路径"]))
        return
    end
    self:FocusOnNode(node.node, focus["提示文本"], focus["可点击任意位置"])
end

---@param node UIComponent
function ForceClickHud:FocusOnNode(node, text, allowClickAnywhere)
    self.allowClickAnywhere = allowClickAnywhere or false
    local size = node.Size
    local pos = node:GetGlobalPos() - Vector2.New(node.Pivot.x * size.x, node.Pivot.y * size.y)
    if self.nodePressCb then
        self.nodePressCb:Disconnect()
        self.nodePressCb = nil
    end

    if text then
        self.text.Position = Vector2.New(pos.x + size.x/2 - self.text.Size.x / 2, pos.y - self.text.Size.y-10)
        local screenSize = self:GetScreenSize()
        if self.text.Position.x + self.text.Size.x > screenSize.x then
            self.text.Position = Vector2.New(screenSize.x - self.text.Size.x, self.text.Position.y)
        end
        if self.text.Position.y < 0 then
            self.text.Position = Vector2.New(self.text.Position.x, pos.y + size.y)
        end
        self.text.Title = text:gsub("\\n", "\n")
        self.text.Visible = true
    else
        self.text.Visible = false
    end

    self.up.Position = Vector2.New(pos.x - self.up.Size.x / 2, pos.y - self.up.Size.y)
    self.down.Position = Vector2.New(pos.x - self.down.Size.x / 2, pos.y + size.y)
    self.left.Size = Vector2.New(self.left.Size.x, size.y)
    self.left.Position = Vector2.New(pos.x - self.left.Size.x, pos.y)
    self.right.Size = Vector2.New(self.right.Size.x, size.y)
    self.right.Position = Vector2.New(pos.x + size.x, pos.y)
    self:Open()
    self.nodePressCb = node.TouchEnd:Connect(function ()
        self:FocusOnNextNode()
        self.nodePressCb:Disconnect()
        self.nodePressCb = nil
    end)
end

return ForceClickHud.New(script.Parent, uiConfig)
