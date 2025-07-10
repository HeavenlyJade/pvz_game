local MainStorage  = game:GetService('MainStorage')
local ClientCustomUI = require(MainStorage.code.common.config_type.custom_ui.ClientCustomUI) ---@type ClientCustomUI

local function InitComponentPaths(ui)
    return {
        PacksList = "抽卡机背景",
        FrontGlass = "抽卡机背景/前挡风玻璃",
        DrawOnce = "抽卡机背景/前挡风玻璃/单抽",
        DrawTen = "抽卡机背景/前挡风玻璃/十连",
        BuyTicket = "抽卡机背景/前挡风玻璃/购买抽奖券",
        ItemIcon = "抽卡机背景/前挡风玻璃/ItemIcon",
        ItemIconAmount = "抽卡机背景/前挡风玻璃/ItemIcon/Amount",
        TopInfo = "抽卡机背景/顶部信息栏/顶部信息",
        TopInfo2 = "抽卡机背景/顶部信息栏/顶部信息2",
        PrizesList = "侧边奖池/奖池列表",
        CloseBtn = "关闭",
        Pack = "卡包",
        PackUpper = "卡包_上层",
        Amount = "Amount",
        -- 可继续补充其它控件路径
    }
end

return ClientCustomUI.Load(script.Parent, InitComponentPaths)