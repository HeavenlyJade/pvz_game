local MainStorage = game:GetService('MainStorage')
local cloudService = game:GetService("CloudService")   ---@type CloudService
-- 导入全局工具模块
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local CustomUI = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

-- 导入服务器事件管理器
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager

---@class Ranking:CustomUI
local Ranking = ClassMgr.Class("Ranking", CustomUI)

local rankingchanged = 'rankingchanged'

---@param data table
function Ranking:OnInit(data)
    -- 变量
    self.variable = data["变量"] or 'level'
    -- 排行榜组件
    self.list = data["榜单"] or {
        { '等级榜', '等级' ,'level'},
        { '战力榜', '战力' ,'combat'},
    }

    if gg.isServer then
        ServerEventManager.Subscribe("VariableChanged", function(evt)
            self:OnVariableChanged(evt)
        end)
    end
    if not self._rankingUpdateRegistered then
        -- 监听排行列表响应
        ClientEventManager.Subscribe(rankingchanged, function(data)
            self:HandleRankingListResponse(data)
        end)
        self._rankingUpdateRegistered = true
    end

end

-- 服务端进入
function Ranking:S_BuildPacket(player, packet)

end
table.is_empty = function(tab)
    if type(tab) ~= 'table' or not next(tab) then
        return true
    end
    return false
end

-- 服务端接受玩家信息，返回排行榜到客户端
function Ranking:S_SendRankingTOClient(player,packet)
    local name = player.name
    local uin = player.uin
    local list = self:UpDataPlayerRankingList(player,packet.variable)
    if table.is_empty(list) then
        player:SendChatText("该榜单尚未开放!")
    end
    -- 发送排行列表到客户端
    gg.network_channel:fireClient(uin, {
        cmd = rankingchanged,
        uin = uin,
        list = list,
        name = name
    })
end

-- 监听变量发生变化
function Ranking:OnVariableChanged(evt)
    if evt.entity.isPlayer then
        if evt.key == self.variable then
            local pack = {variable = self.variable}
            print('pack = ' .. tostring(pack))
            self:S_SendRankingTOClient(evt.entity,pack)
        end
    end
end


-- 处理玩家排行表
function Ranking:UpDataPlayerRankingList(player,packet_variable)
    -- 变量
    local variable = packet_variable or self.variable
    -- 从云端获取指定排行榜
    local playerRankingSuccess, playerRankingData = cloudService:GetTableOrEmpty('Ranking' .. variable)
    if not playerRankingSuccess then
        return {}
    end
    if not player[variable] then
        print('不存在变量' .. tostring(variable))
        return {}
    end
    local InTable = false
    local MyIndex = 0
    for i, v in ipairs(playerRankingData) do
        if v.uin == player.uin then
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
            table.insert(playerRankingData, { uin = player.uin, [variable] = player[variable], name = variable.name })
        else
            for i, v in ipairs(playerRankingData) do
                if not v[variable] or player[variable] > v[variable] then
                    table.insert(playerRankingData,{ uin = player.uin, [variable] = player[variable], name = player.name })
                    break
                end
            end
        end
    else
        -- 在表内
        for i, v in ipairs(playerRankingData) do
            if v.uin == player.uin then
                print(v[variable] .. '|' .. player[variable])
                if v[variable] ~= player[variable] then
                    playerRankingData[i] = { uin = player.uin, [variable] = player[variable], name = player.name }
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
                return a[variable] > b[variable]
            end)
        end
        if #playerRankingData > 50 then
            while #playerRankingData > 50 do
                table.remove(playerRankingData)
            end
        end
        cloudService:SetTableAsync('Ranking' .. variable, playerRankingData, function()
        end)
    end
    return playerRankingData
end

-----------------客户端
-- 客户端进入
function Ranking:C_BuildUI(packet)
    --print('---Ranking客户端 测试 ' .. tostring(self.test))

    --Bag.MoneyType[moneyId]

    -- 界面组件
    if not self._testValueRegistered then
        local RankingUi = self.view
        local RankingPaths = self.paths
        -- 注册关闭事件
        RankingUi:Get(RankingPaths.RankingCloseButton, ViewButton).clickCb = function(ui, button)
            RankingUi:Close()
        end
        -- 排行榜
        self.RankingList = RankingUi:Get(RankingPaths.RankingList, ViewList, function(child, childPath)
            local c = ViewButton.New(child, RankingUi, childPath)
            return c
        end)
        -- 榜单分类栏点击事件
        self.RankingSelectionList = RankingUi:Get(RankingPaths.RankingSelectionList, ViewList, function(child, childPath)
            local c = ViewButton.New(child, RankingUi, childPath)
            c.clickCb = function(ui, button)
                -- 点击事件
                local RankingName = self.list[button.index][2]
                -- 第一步更改标题名称
                RankingUi:Get(RankingPaths.RankingKey).node.Title = RankingName
                -- 改变变量
                self.variable = self.list[button.index][3]
                print('变更变量为' .. self.variable)
                self:C_SendEvent("S_SendRankingTOClient",{
                    variable = self.variable
                } )
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
        self._testValueRegistered = true
    end
    self:C_SendEvent("S_SendRankingTOClient",{
        variable = self.variable
    } )
end

-- 处理排行列表响应
function Ranking:HandleRankingListResponse(data)
    if table.is_empty(data.list) then
        gg.log("排行列表响应数据为空")
        self.RankingList:SetElementSize(0)
        local RankingUi = self.view
        local RankingPaths = self.paths
        RankingUi:Get(RankingPaths.PlayerRankingName).node.Title = '尚未开放'
        RankingUi:Get(RankingPaths.PlayerRankingVal).node.Title = ''
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        return
    end
    -- 更新榜单 ？
    local variable = self.variable
    local my_uin = data.uin
    local my_name = data.name
    local my_variable = '0'
    local my_ranking = '未上榜'
    local ranking_list = data.list
    if #ranking_list > 1 then
        -- 从大到小排序
        table.sort(ranking_list, function(a, b)
            return a[variable] > b[variable]
        end)
    end
    for i = 1, 50 do
        if not ranking_list[i] then
            break
        end
        if ranking_list[i].uin == my_uin then
            if my_ranking == '未上榜' then
                my_ranking = tostring(i)
                my_variable = ranking_list[i][variable] and tostring(ranking_list[i][variable]) or '0'
                break
            end
        end
    end
    -- 拿到排名表 ranking_list 拿到我的排名 my_ranking 我的值 my_variable
    local RankingUi = self.view
    local RankingPaths = self.paths
    -- 我的值
    RankingUi:Get(RankingPaths.PlayerRankingName).node.Title = my_name
    RankingUi:Get(RankingPaths.PlayerRankingVal).node.Title = my_variable
    if my_ranking == '1' then
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_2).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
    elseif my_ranking == '2' then
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_2).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNum_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = true
    elseif my_ranking == '3' then
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_1).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_2).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum_3).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = true
    elseif my_ranking == '未上榜' then
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = true
    else
        RankingUi:Get(RankingPaths.PlayerRankingNum_1_3).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNumBG).node.Visible = true
        RankingUi:Get(RankingPaths.PlayerNotRanking).node.Visible = false
        RankingUi:Get(RankingPaths.PlayerRankingNum).node.Title = tostring(my_ranking)
    end
    for index, RankingData in ipairs(ranking_list) do
        local child = self.RankingList:GetChild(index, 4)
        local Name = RankingData.name
        local level = RankingData[self.variable]
        local name = child:Get(RankingPaths.RankingPlayerName)
        local val = child:Get(RankingPaths.RankingPlayerVal)
        name.node.Title = tostring(Name)
        val.node.Title = tostring(level)
        if index > 3 then
            local num = child:Get(RankingPaths.RankingPlayerNum)
            if num and num.node then
                num.node.Title = tostring(index)
            end
        end
    end
end


return Ranking