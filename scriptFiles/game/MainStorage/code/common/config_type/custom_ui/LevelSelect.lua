local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.code.common.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local ItemTypeConfig = require(MainStorage.code.common.config.ItemTypeConfig) ---@type ItemTypeConfig
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local LevelConfig = require(MainStorage.code.common.config.LevelConfig)  ---@type LevelConfig


---@class LevelSelect:CustomUI
local LevelSelect = ClassMgr.Class("LevelSelect", CustomUI)

---@param data table
function LevelSelect:OnInit(data)
    self.levelTypes = {} ---@type LevelType[]
    for i, levelTypeId in ipairs(data["关卡"]) do
        local levelType = LevelConfig.Get(levelTypeId)
        if levelType then
            self.levelTypes[i] = levelType
        end
    end
end

---@param player Player
function LevelSelect:S_BuildPacket(player, packet)
    packet.levels = {}
    for _, levelType in ipairs(self.levelTypes) do
        packet.levels[levelType.levelId] = {
            desc = gg.ProcessVariables(levelType.description, player, player),
            enterable = levelType:CanJoin(player),
            cleared = levelType.firstClearReward and player:GetVariable("levelcleared_".. levelType.levelId) > 0,
            claimed = player:GetVariable("levelclaimed_".. levelType.levelId) > 0
        }
    end
end


---@param player Player
function LevelSelect:onClaimFirstClearedItem(player, args)
    local levelType = LevelConfig.Get(args.levelType)
    if not levelType.firstClearReward then
        self:SendHoverText("没有首通奖励可以领取")
        return
    end
    if player:GetVariable("levelcleared_".. levelType.levelId) <= 0 then
        self:SendHoverText("关卡尚未完成！完成后即可领取")
        return
    end
    if player:GetVariable("levelclaimed_".. levelType.levelId) > 0 then
        self:SendHoverText("关卡已经领取")
        return
    end
    player:SetVariable("levelclaimed_".. levelType.levelId, 1)
    player.bag:GiveItem(levelType.firstClearReward)
end


-----------------------客户端---------------------------


---@param levelType  LevelType
function LevelSelect:_claimFirstClearedItem(levelType)
    if not levelType.firstClearReward then
        self:SendHoverText("没有首通奖励可以领取")
        return
    end
    local levelInfo = self._levels[levelType.levelId]
    if not levelInfo.cleared then
        self:SendHoverText("关卡尚未完成！完成后即可领取")
        return
    end
    if levelInfo.claimed then
        self:SendHoverText("关卡已经领取")
        return
    end
    self:C_SendEvent("onClaimFirstClearedItem", {
        levelType = levelType.levelId
    })
end

function LevelSelect:C_BuildUI(packet)
    local levels = packet.levels
    self._levels = levels

    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
    local ui = self.view

    self.levelSelectList = ui:Get("背景/关卡列表", ViewList, function (child, childPath)
        local c = ViewComponent.New(child, ui, childPath)
        c:Get("确认按钮", ViewButton).clickCb = function (ui, button)
            self:_viewLevelType(self.levelTypes[button.index])
        end
        return c
    end) ---@type ViewList
    self.levelSelectList:SetElementSize(0)
    for i, levelType in ipairs(self.levelTypes) do
        local levelInfo = levels[levelType.levelId]
        local child = self.levelSelectList:GetChild(i)
        child:Get("关卡名字").node.Title = levelType.levelId
        child:Get("描述").node.Title = levelInfo.desc
        child:Get("确认按钮"):SetTouchEnable(levelInfo.enterable)
        local fcItem = child:Get("首通", ViewItem)
        if not fcItem.clickCb then
            fcItem.extraParams.index = i
            fcItem.clickCb = function (ui, button)
                self:_claimFirstClearedItem(levelType)
            end
        end
        if levelType.firstClearReward then
            fcItem.node.Visible = true
            fcItem:SetItem(levelType.firstClearReward)
            fcItem:SetTouchEnable(not levelInfo.claimed)
        else
            fcItem.node.Visible = false
        end
        child:Get("首通奖励_可领取").node.Visible = not levelInfo.claimed and levelInfo.cleared
    end
    ui:Get("背景/关闭按钮", ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
    self.packet = packet
    self.view:Open()
end

return LevelSelect