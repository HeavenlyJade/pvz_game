local MainStorage = game:GetService('MainStorage')
local cloudService = game:GetService("CloudService")   ---@type CloudService
-- 导入全局工具模块
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local CustomUI = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList

-- 导入服务器事件管理器
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

---@class Ranking:CustomUI
local Ranking = ClassMgr.Class("Ranking", CustomUI)

---@param data table
function Ranking:OnInit(data)
    -- 变量
    self.variable = data["变量"] or 'level'
    -- 排行榜组件
    self.list = data["榜单"] or {
        { '等级榜', '等级' },
        --{ '阳光榜', '阳光' },
    }
    -- 排行榜单组件
    self.RankingList = nil
    -- 玩家排行榜组件
    self.RankingSelectionList = nil
    -- 玩家列表
    self.PlayerList = {}
    if gg.isServer then
        -- 监听变量变化事件
        ServerEventManager.Subscribe("VariableChanged", function(evt)
            self:OnVariableChanged(evt)
        end)
    end
end


function Ranking:OnVariableChanged(evt)
    print('排行榜监听变量变化事件:' .. tostring(self.variable) .. '| key = ' .. tostring(evt.key) .. '|' .. tostring(evt.entity.isPlayer))
    if evt.entity.isPlayer then
        --{ entity = self, key = k, value = nil }
        if evt.key == self.variable then
            self:UpDataPlayerRankingList(evt.entity)
        end
    end
end

---@param player Player
function Ranking:S_BuildPacket(player, packet)
    print('-------------服务端更新榜单')
    self:UpDataPlayerRankingList(player)
end

-- 更新玩家排行表
function Ranking:UpDataPlayerRankingList(evt)
    -- 从云端获取指定排行榜
    local playerRankingSuccess, playerRankingData = cloudService:GetTableOrEmpty('Ranking' .. self.variable)
    if not playerRankingSuccess then
        return
    end
    local InTable = false
    local MyIndex = 0
    for i, v in ipairs(playerRankingData) do
        if v.uin == evt.uin then
            MyIndex = i
            InTable = true
            break
        end
    end
    local upTable = false
    -- 不在表内
    if not InTable then
        if #playerRankingData < 50 then
            upTable = true
            table.insert(playerRankingData, { uin = evt.uin, [self.variable] = evt[self.variable], name = evt.name })
        else
            for i, v in ipairs(playerRankingData) do
                if not v[self.variable] or evt[self.variable] > v[self.variable] then
                    table.insert(playerRankingData,{ uin = evt.uin, [self.variable] = evt[self.variable], name = evt.name })
                    break
                end
            end
        end
    else
        -- 在表内
        for i, v in ipairs(playerRankingData) do
            if v.uin == evt.uin then
                if v[self.variable] ~= evt[self.variable] then
                    playerRankingData[i] = { uin = evt.uin, [self.variable] = evt[self.variable], name = evt.name }
                    upTable = true
                end
                break
            end
        end
    end
    if upTable then
        if #playerRankingData > 1 then
            -- 从大到小排序
            table.sort(playerRankingData, function(a, b)
                return a[self.variable] > b[self.variable]
            end)
        end
        if #playerRankingData > 50 then
            while #playerRankingData > 50 do
                table.remove(playerRankingData)
            end
        end
        cloudService:SetTableAsync('Ranking' .. self.variable, playerRankingData, function()
        end)
    end
end
-----------------------客户端---------------------------

function Ranking:C_BuildUI(packet)
    print('-------------客户端榜单')
    local RankingUi = self.view
    local RankingPaths = self.paths
    local playerRankingSuccess, playerRankingData = cloudService:GetTableOrEmpty('Ranking' .. self.variable)
    if playerRankingSuccess then
        self.PlayerList = playerRankingData
    end
    local localPlayer = game:GetService("Players").LocalPlayer
    -- 设置默认角色名称
    RankingUi:Get(RankingPaths.PlayerRankingName).node.Title = localPlayer.Nickname
    -- 设置默认角色排名
    RankingUi:Get(RankingPaths.PlayerRankingNum).node.Title = '1'
    -- 角色等级
    RankingUi:Get(RankingPaths.PlayerRankingVal).node.Title = tostring(packet.level)

    RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = true
    -- 注册关闭事件
    RankingUi:Get(RankingPaths.RankingCloseButton, ViewButton).clickCb = function(ui, button)
        RankingUi:Close()
    end

    -- 排行榜
    self.RankingList = RankingUi:Get(self.paths.RankingList, ViewList, function(child, childPath)
        local c = ViewButton.New(child, RankingUi, childPath)
        return c
    end)

    -- 榜单分类栏点击事件
    self.RankingSelectionList = RankingUi:Get(self.paths.RankingSelectionList, ViewList, function(child, childPath)
        local c = ViewButton.New(child, RankingUi, childPath)
        c.clickCb = function(ui, button)
            self:RankingClick(ui, button)
        end
        return c
    end)

    -- 榜单分类栏
    self.RankingSelectionList:SetElementSize(0)

    for index, RankingData in ipairs(self.list) do
        local child = self.RankingSelectionList:GetChild(index)
        local categoryNode = child:Get(RankingPaths.RankingSelectionTypeName)
        local RankingName = RankingData[1]
        categoryNode.node.Title = RankingName
    end
    local button = { index = 1 }
    self:RankingClick(nil, button)
    RankingUi:Open()
end

-- 点击事件
function Ranking:RankingClick(ui, button)

    local RankingUi = self.view
    local RankingPaths = self.paths
    local RankingName = self.list[button.index][2]
    -- 第一步更改标题名称
    RankingUi:Get(RankingPaths.RankingKey).node.Title = RankingName
    -- 第二部更改角色排名和值
    local PlayerList, RankingNum, RankingVal = self:GetPlayerRanking()
    RankingUi:Get(RankingPaths.PlayerRankingVal).node.Title = tostring(RankingVal)
    if RankingNum == '1' then
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = true

        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_2).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
    elseif RankingNum == '2' then
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_2).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNum_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = true
    elseif RankingNum == '3' then
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_2).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_3).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = true
    elseif RankingNum == '未上榜' then
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = true
    else
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum).node.Title = tostring(RankingNum)
    end

    for index, RankingData in ipairs(PlayerList) do
        local child = self.RankingList:GetChild(index, 4)
        local Name = RankingData[1]
        local level = RankingData[2]
        local name = child:Get(RankingPaths.RankingPlayerName)
        local val = child:Get(RankingPaths.RankingPlayerVal)
        name.node.Title = Name
        val.node.Title = tostring(level)
        if index > 3 then
            local num = child:Get(RankingPaths.RankingPlayerNum)
            if num and num.node then
                num.node.Title = tostring(index)
            end
        end
    end
end

function Ranking:GetPlayerRanking()
    local user_uin = gg.getClientLocalPlayer().UserId
    local ret_t = {}
    local num = '未上榜'
    local val = self[self.variable]

    if #self.PlayerList > 1 then
        -- 从大到小排序
        table.sort(self.PlayerList, function(a, b)
            return a[self.variable] > b[self.variable]
        end)
    end
    for i = 1, 50 do
        if not self.PlayerList[i] then
            break
        end
        if self.PlayerList[i].uin == user_uin then
            if num == '未上榜' then
                num = tostring(i)
                val = self.PlayerList[i][self.variable]
            end
        end
        local tmp_t = {
            [1] = self.PlayerList[i].name,
            [2] = self.PlayerList[i][self.variable]
        }
        table.insert(ret_t, tmp_t)
    end
    return ret_t, num, val
end

return Ranking