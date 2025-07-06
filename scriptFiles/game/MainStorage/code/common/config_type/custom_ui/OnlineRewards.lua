local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI

-- ItemType class
---@class OnlineRewardsUI:CustomUI
local OnlineRewardsUI = ClassMgr.Class("OnlineRewardsUI", CustomUI)


function OnlineRewardsUI:OnInit(data)
    self.itemRewards = {} ---@type
    local resetType = data["重置周期"] or "每日"
    if resetType == "每日" then
        self.var = string.format("%s_daily_claimed_", self.id) .. "%d"
    elseif resetType == "每周" then
        self.var = string.format("%s_weekly_claimed_", self.id) .. "%d"
    elseif resetType == "每月" then
        self.var = string.format("%s_monthly_claimed_", self.id) .. "%d"
    else
        self.var = string.format("%s_claimed_", self.id) .. "%d"
    end
    for _, itemData in ipairs(data["奖励物品"]) do
        table.insert(self.itemRewards, {
            item = ItemTypeConfig.Get(itemData["物品"]):ToItem(itemData["数量"]),
            time = itemData["在线时间"]
        })
    end
end

---@param player Player
function OnlineRewardsUI:S_BuildPacket(player, packet)
    packet["online_time"] = player:GetOnlineTime()
    local claimed = {}
    packet["claimed"] = claimed
    for index, _ in ipairs(self.itemRewards) do
        claimed[index] = player:GetVariable(string.format(self.var, index))
        gg.log("claimed",claimed , string.format(self.var, index), player:GetVariable(string.format(self.var, index)))
    end
end

---@param player Player
function OnlineRewardsUI:OnClickReward(player, packet)
    local index = packet.index
    if player:GetVariable(string.format(self.var, index)) ~= 0 then
        player:SendHoverText("此奖励已领取过！")
        return
    end
    if player:GetOnlineTime() < self.itemRewards[index].time then
        player:SendHoverText("今日在线时长不足！")
        return
    end
    player:SetVariable(string.format(self.var, index), 1)
    player.bag:GiveItem(self.itemRewards[index].item)
    self:S_Open(player)
end

-----------------------客户端---------------------------

function OnlineRewardsUI:C_BuildUI(packet)
    self.packet = packet
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    self.view:Get("在线奖励背景/关闭按钮", ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
    self.online_time = packet.online_time
    self.refreshTime = os.time()
    if not self.rewardsList then
        self.rewardsList = self.view:Get("在线奖励背景/在线进度背景/在线奖励列表", ViewList, function (child, childPath)
            local c = ViewButton.New(child, self.view, childPath)
            c.clickCb = function (ui, button)
                self:C_SendEvent("OnClickReward", {
                    index = button.index
                })
            end
            return c
        end) ---@type ViewList
    end
    self.nodePercent = {}
    local bar = self.view:Get("在线奖励背景/在线进度背景/在线进度").node ---@type UIComponent
    local startX = bar:GetGlobalPos().x
    local fullWidth = bar.Size.x
    self.nodePercent[0] = 0
    for index, itemInfo in ipairs(self.itemRewards) do
        local canClaim = self.packet["claimed"][index] == 0 and self.online_time > itemInfo.time
        local icon = self.rewardsList:GetChild(index) ---@cast icon ViewButton
        icon:Get("Item", ViewItem):SetItem(itemInfo.item)
        icon:Get("Item", ViewItem):SetGray(not canClaim)
        icon:Get("时间节点").node.Title = gg.FormatTime(itemInfo.time)
        icon:Get("已领取打勾").node.Visible = self.packet["claimed"][index] == 1
        local pointerX = icon:GetGlobalPos().x + icon.node.Size.x/2
        local percent = (pointerX - startX) / fullWidth
        self.nodePercent[index] = percent
        icon:SetTouchEnable(canClaim)
    end
    self:_RefreshBar()
    self.view.openCb = function ()
        local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
        self.taskId = ClientScheduler.add(function ()
            self:_RefreshBar()
        end, 1, 1)
    end
    self.view.closeCb = function ()
        local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
        self.taskId = ClientScheduler.cancel(self.taskId)
    end
end

function OnlineRewardsUI:_RefreshBar()
    local online_time = self.online_time + os.time() - self.refreshTime
    local bar = self.view:Get("在线奖励背景/在线进度背景/在线进度").node ---@type UIComponent
    local hasReward = false
    
    for index, itemInfo in ipairs(self.itemRewards) do
        if online_time < itemInfo.time then
            local deltaTime = 0
            if index == 1 then
                deltaTime = online_time / self.itemRewards[index].time
            else
                deltaTime = (online_time - self.itemRewards[index-1].time) / (self.itemRewards[index].time - self.itemRewards[index-1].time)
            end
            local newFillAmount = self.nodePercent[index-1] + (self.nodePercent[index] - self.nodePercent[index-1]) * deltaTime
            bar.FillAmount = newFillAmount
            self.view:Get("在线奖励背景/倒计时").node.Title = gg.FormatTime(itemInfo.time - online_time, false)
            hasReward = true
            break
        end
        local icon = self.rewardsList:GetChild(index) ---@cast icon ViewButton
        icon:SetTouchEnable(self.packet["claimed"][index] == 0 and online_time > itemInfo.time)
    end
    if not hasReward then
        bar.FillAmount = 1
        self.view:Get("在线奖励背景/倒计时").node.Title = "已领取完毕，明日再来吧！"
    end
end

return OnlineRewardsUI