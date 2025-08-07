local MainStorage  = game:GetService('MainStorage')
local ClientCustomUI = require(MainStorage.code.common.config_type.custom_ui.ClientCustomUI) ---@type ClientCustomUI

local function InitComponentPaths(ui)
    return {
        MainBg = "界面背景",
        RankingCloseButton = "关闭按钮",
        RankingSelectionList = "界面背景/选择列表背景/排行选择列表",
        RankingSelectionTypeName = "类型名字",

        RankingList = "界面背景/排名列表",
        RankingPlayerName = "名称",
        RankingPlayerVal = "等级",
        RankingPlayerNum = '排名图标/排名',




        RankingKey = "界面背景/排名标题/玩家等级",

        PlayerRankingName = "界面背景/玩家自身排名/玩家名称",
        PlayerRankingVal = "界面背景/玩家自身排名/玩家等级",


        PlayerRankingNumBG = "界面背景/玩家自身排名/排名图标",
        PlayerRankingNum = "界面背景/玩家自身排名/排名图标/排名",

        PlayerRankingNum_1_3 = "界面背景/玩家自身排名/前三排名",

        PlayerRankingNum_1 = "界面背景/玩家自身排名/前三排名/第一名",
        PlayerRankingNum_2 = "界面背景/玩家自身排名/前三排名/第二名",
        PlayerRankingNum_3 = "界面背景/玩家自身排名/前三排名/第三名",

        PlayerNotRanking = "界面背景/玩家自身排名/未上榜排名",

    }
end

return ClientCustomUI.Load(script.Parent, InitComponentPaths)