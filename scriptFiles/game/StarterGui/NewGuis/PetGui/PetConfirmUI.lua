local MainStorage  = game:GetService('MainStorage')
local ClientCustomUI = require(MainStorage.code.common.config_type.custom_ui.ClientCustomUI) ---@type ClientCustomUI

local function InitComponentPaths(ui)
    return {
        MainBg = "界面背景",
        -- 上方
        CloseButton = "界面背景/关闭按钮",
        ShowPet = "界面背景/宠物",
        ShowPet = "界面背景/宠物ID",
        -- 左侧
        PetList = "界面背景/宠物栏列表",
        PetPic = "宠物图片",
        IsUsePet = "是否携带",


        -- 右侧
        ShowPet = "界面背景/右侧/宠物样子",
        Start_1 = "界面背景/右侧/星级/星_1",
        Start_2 = "界面背景/右侧/星级/星_2",
        Start_3 = "界面背景/右侧/星级/星_3",
        Start_4 = "界面背景/右侧/星级/星_4",
        Start_5 = "界面背景/右侧/星级/星_5",
        UpPet = "界面背景/右侧/升星",
        DownPet = "界面背景/右侧/取下",
        PetLevel = "界面背景/右侧/等级",

        -- 底部
        CanUsePetNum = "界面背景/底部/携带数量/背包数",
        BagPetNum = "界面背景/底部/背包数量/背包数",
        LockBtn = "界面背景/底部/锁住按钮",
        UnlockBtn = "界面背景/底部/解锁按钮",
        DelBtn = "界面背景/底部/删除按钮",
        MergeBtn = "界面背景/底部/一键合成",
        UseBestBtn = "界面背景/底部/装备最佳",

    }
end

return ClientCustomUI.Load(script.Parent, InitComponentPaths)