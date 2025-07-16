local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local Players = game:GetService('Players')
local ClientEventManager= require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.code.client.ClientScheduler)

---@class HudAvatar:ViewBase
local HudAvatar = ClassMgr.Class("HudAvatar", ViewBase)

local uiConfig = {
    uiName = "HudAvatar",
    layer = 0,
    hideOnInit = false,
}

function HudAvatar:OnInit(node, config)
    self.selectingCard = 0
    local localPlayer = game:GetService("Players").LocalPlayer
    self:Get("名字背景/玩家名").node.Title = localPlayer.Nickname
    self:Get("名字背景/UID").node.Title = tostring(localPlayer.UserId)
    self.questList = self:Get("头像背景/任务列表", ViewList, function (node)
        local button = ViewButton.New(node, self)
        button.clickCb = function (ui, button)
            gg.network_channel:FireServer({
                cmd = "ClickQuest",
                name = button.extraParams.questId,
            })
        end
        return button
    end)
    self:Get("头像背景/任务按钮", ViewButton).clickCb = function (ui, viewButton)
        self.questList:SetVisible(not self.questList.node.Enabled)
    end
    
    ClientEventManager.Subscribe("UpdateQuestsData", function(evt)
        local evt = evt ---@type QuestsUpdate
        self.questList:SetElementSize(#evt.quests)
        self:NavigateTo(nil, "")
        for i, child in ipairs(evt.quests) do
            local ele = self.questList:GetChild(i) ---@cast ele ViewButton
            ele.extraParams = {
                questId = child.name
            }
            if child.count >= child.countMax then
                ele.normalImg = "sandboxId://textures/ui/主界面UI/头像信息UI/任务面板_1.png"
                ele.hoverImg = ele.normalImg
                ele.clickImg = ele.normalImg
                ele.node.Icon = ele.normalImg
            else
                ele.normalImg = "sandboxId://textures/ui/主界面UI/头像信息UI/任务面板.png"
                ele.hoverImg = ele.normalImg
                ele.clickImg = ele.normalImg
                ele.node.Icon = ele.normalImg
            end
            ele:Get("任务标题").node.Title = child.description
            ele:Get("任务数量").node.Title = string.format("%d/%d", child.count, child.countMax)
            if i == 1 and child.targetLoc then
                self:NavigateTo(gg.Vec3.new(child.targetLoc), child.description)
            end
        end
    end)
    ClientEventManager.Subscribe("UpdateHud", function(data)
        self:Get("名字背景/等级").node.Title = tostring(data.level)
    end)
    
    ClientEventManager.Subscribe("NavigateTo", function(data)
        local stopRange = data.range ^ 2
        local vec = Vector3.New(data.pos[1], data.pos[2], data.pos[3])
        self.targetPos = vec
        Players.LocalPlayer.Character:NavigateTo(vec)
        self:NavigateTo(gg.Vec3.new(vec), data.text or "")
        
        -- 取消之前的检查任务（如果存在）
        if self.navigationCheckTaskId then
            ClientScheduler.cancel(self.navigationCheckTaskId)
        end
        
        -- 创建新的检查任务
        self.navigationCheckTaskId = ClientScheduler.add(function()
            local character = Players.LocalPlayer.Character ---@type MiniPlayer
            if not character then return end
            
            local currentPos = character.Position
            local distance = gg.vec.DistanceSq3(currentPos, self.targetPos)
            
            if distance <= stopRange then
                character:StopNavigate()
                gg.network_channel:FireServer({
                    cmd = "NavigateReached"
                })
                -- 取消检查任务
                ClientScheduler.cancel(self.navigationCheckTaskId)
                self.navigationCheckTaskId = nil
                self.targetPos = nil
            end
        end, 1, 1) -- 每秒检查一次
    end)
    ClientEventManager.Subscribe("ShowPointerTo", function(data)
        if data.pos then
            -- 将数组格式的位置转换为Vec3对象
            local targetPos = gg.Vec3.new(data.pos)
            self:NavigateTo(targetPos, data.text)
            
            -- 处理靠近目标后解除的逻辑
            if data.distance > 0 then
                self.checkTask = ClientScheduler.add(function()
                    local character = Players.LocalPlayer.Character
                    if character and targetPos:DistanceSq(character.Position) < data.distance * data.distance then
                        self:NavigateTo(nil)  -- 关闭指针
                        ClientScheduler.cancel(self.checkTask)
                    end
                end, 1, 1)
            end
        end
    end)
end

function HudAvatar:NavigateTo(pos, text)
    if not self._pointer then
        self._pointer = MainStorage["特效"]["导航指针"]:Clone() ---@type Model
        self._pointer.Parent = game.WorkSpace
        self._pointer.Visible = false
    end
    if not pos then
        self._pointer["UIRoot3D"]["导航文本"].Title = ""
        self._pointer.Visible = false
        if self._pointerUpdateTaskId then
            self._pointerUpdateTaskId:Disconnect()
            self._pointerUpdateTaskId = nil
        end
    else
        self._pointer.Visible = true
        if text then
            self._pointer["UIRoot3D"]["导航文本"].Title = text
        end
        self._pointerUpdateTaskId = game.RunService.RenderStepped:Connect(function ()
            local delta = pos - gg.Vec3.new(Players.LocalPlayer.Character.Position)
            local rot = delta:GetRotation()
            self._pointer.Euler = rot:ToVector3()
            self._pointer.Position = Players.LocalPlayer.Character.Position
        end)
    end
end

return HudAvatar.New(script.Parent, uiConfig)
