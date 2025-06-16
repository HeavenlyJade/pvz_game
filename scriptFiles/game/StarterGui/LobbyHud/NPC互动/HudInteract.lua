local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class HudInteract:ViewBase
local HudInteract = ClassMgr.Class("HudInteract", ViewBase)

local uiConfig = {
    uiName = "HudInteract",
    layer = 0,
    hideOnInit = false, -- 初始隐藏，当玩家靠近NPC时显示
}

---@param viewButton ViewButton
local function OnInteractClick(ui, viewButton)
    local button = viewButton ---@cast button ViewButton
    local option = ui.currentOptions[button.index]
    if option then
        -- 发送交互请求到服务器
        gg.network_channel:FireServer({
            cmd = "InteractWithNpc",
            npcId = option.npcId
        })
    end
end

function HudInteract:OnInit(node, config)
    self.currentOptions = {} -- 存储当前可交互的NPC选项
    self.pcInteract = self:Get("PC右键提示")
    self.pcInteract.node.Visible = false
    self.currentOptionIndex = 1 -- 当前选中的选项索引
    
    -- 初始化交互列表
    self.interactList = self:Get("交互列表", ViewList, function(n)
        local button = ViewButton.New(n, self)
        button.node.ClickPass = true
        button.clickCb = OnInteractClick
        return button
    end)
    self.pcInteractOffset = self.pcInteract.node:GetGlobalPos() - self.interactList:GetChild(1).node:GetGlobalPos()

    -- 检查交互列表是否成功初始化
    if not self.interactList then
        gg.log("错误: 交互列表初始化失败!")
        return
    end

    -- 先隐藏交互界面
    self:HideInteract()

    -- 确保UI完全初始化后再订阅事件（可以使用延迟）
    wait(0.1) -- 延迟一小段时间确保UI组件已完全准备好

    -- 监听NPC交互更新事件
    ClientEventManager.Subscribe("NPCInteractionUpdate", function(evt)
        local evt = evt ---@type NPCInteractionUpdate
        if evt and evt.interactOptions and #evt.interactOptions > 0 then
            self:ShowInteract(evt.interactOptions)
        else
            self:HideInteract()
        end
    end)

    -- 监听鼠标滚轮事件
    ClientEventManager.Subscribe("MouseScroll", function(data)
        if not self.pcInteract.node.Visible or #self.currentOptions == 0 then
            return
        end

        -- 根据滚轮方向更新索引
        if data.isDown then
            -- 向下滚动，选择下一个选项
            self.currentOptionIndex = self.currentOptionIndex % #self.currentOptions + 1
        else
            -- 向上滚动，选择上一个选项
            self.currentOptionIndex = (self.currentOptionIndex - 2) % #self.currentOptions + 1
        end

        -- 更新提示框位置
        self:UpdatePcInteractPosition()
    end)

    -- 监听右键点击事件
    ClientEventManager.Subscribe("MouseButton", function(data)
        if data.right and data.isDown then
            if self.pcInteract.node.Visible and #self.currentOptions > 0 then
                local option = self.currentOptions[self.currentOptionIndex]
                if option then
                    -- 发送交互请求到服务器
                    gg.network_channel:FireServer({
                        cmd = "InteractWithNpc",
                        npcId = option.npcId
                    })
                end
            end
        end
    end)
end

---更新PC交互提示框位置
function HudInteract:UpdatePcInteractPosition()
    if not self.pcInteract or not self.interactList then return end
    
    local currentButton = self.interactList:GetChild(self.currentOptionIndex)
    if not currentButton then return end
    self.pcInteract.node.Position = currentButton.node:GetGlobalPos() + self.pcInteractOffset
end

---显示交互界面
---@param interactOptions NPCInteractionOption[] 交互选项列表
function HudInteract:ShowInteract(interactOptions)
    self.currentOptions = interactOptions
    self.currentOptionIndex = 1 -- 重置选中索引
    
    -- 设置交互选项数量
    self.interactList:SetElementSize(#interactOptions)
    
    -- 更新交互选项
    for i, option in ipairs(interactOptions) do
        local button = self.interactList:GetChild(i) ---@cast button ViewButton
        button:Get("Text").node.Title = option.npcName
        if option.icon then
            button:Get("图标").node.Icon = option.icon 
        end
        button.index = i
    end
    self.pcInteract.node.Visible = game.RunService:IsPC() and game.MouseService:IsSight() and self.interactList:GetChildCount() > 0

    self:UpdatePcInteractPosition()
end

---隐藏交互界面
function HudInteract:HideInteract()
    self.currentOptions = {} -- 清空当前选项
    self.currentOptionIndex = 1 -- 重置选中索引
    self.interactList:SetElementSize(0)
    self.pcInteract.node.Visible = false
end

return HudInteract.New(script.Parent, uiConfig)
