local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig

---@class DungeonCleared:ViewBase
local DungeonCleared = ClassMgr.Class("DungeonCleared", ViewBase)

local uiConfig = {
    uiName = "DungeonCleared",
    layer = 1,
    hideOnInit = true,
}

function DungeonCleared:OnInit(node, config)
    self.description = self:Get("描述")
    local rewardBtn = self:Get("退出", ViewButton)
    if rewardBtn then
        rewardBtn.clickCb = function(ui, button)
            ClientEventManager.SendToServer("DungeonCleared_ClaimReward", {})
            self:Close()
        end
    end
    self.rewardList = self:Get("奖励列表背景/奖励列表", ViewList, function (child, childPath)
        local c = ViewItem.New(child, self, childPath)
        return c
    end) ---@type ViewList

    -- 监听DungeonClearedStats事件
    ClientEventManager.Subscribe("DungeonClearedStats", function(evt)
        local desc = ""
        for mobName, count in pairs(evt.kills or {}) do
            desc = desc .. string.format("%s：%d\n", mobName, count)
        end
        self.description.node.Title = desc ~= "" and desc or "无击杀"
        -- 2. 显示奖励物品
        self.rewardList:SetElementSize(0)
        local index = 1
        for itemName, amount in pairs(evt.rewards or {}) do
            local itemType = ItemTypeConfig.Get(itemName)
            if itemType then
                self.rewardList:GetChild(index):SetItem(itemType:ToItem(amount))
                index = index + 1
            end
        end
        self:Open()
    end)
end

return DungeonCleared.New(script.Parent, uiConfig)
