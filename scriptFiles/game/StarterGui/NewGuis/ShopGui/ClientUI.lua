local MainStorage  = game:GetService('MainStorage')
local ClientCustomUI = require(MainStorage.code.common.config_type.custom_ui.ClientCustomUI) ---@type ClientCustomUI

local function InitComponentPaths(ui)
    return {
        MainBg = "商城主背景",
        BigIconBg = "商城主背景/物品大图标背景",
        BigIcon = "商城主背景/物品大图标背景/物品大图标",
        BigIconAmount = "商城主背景/物品大图标背景/物品大图标/图标数量",
        IconAmount = "图标数量",
        HotSale = "热卖",
        Limited = "限定",
        Price = "价格",
        CurrencyIcon = "货币图标",
        CategoryName = "分类名",
        InfoBox = "商城主背景/信息框",
        Name = "商城主背景/信息框/名字",
        Desc = "商城主背景/信息框/详细介绍信息",
        BuyBtn = "商城主背景/购买",
        PriceInfo = "商城主背景/价格信息",
        PriceIcon = "商城主背景/价格信息/UIImage",
        CloseBtn = "商城主背景/关闭按钮",
        CategoryList = "商城主背景/分类栏背景/分类栏列表",
        GoodsList = "商城主背景/物品栏背景/物品栏列表",
        MiniCoinBtn = "商城主背景/兑换迷你币",
    }
end

return ClientCustomUI.Load(script.Parent, InitComponentPaths)