
local store = game:GetService("DeveloperStoreService")
local MainStorage = game:GetService("MainStorage")
local ClassMgr    = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg

---@class MiniShopManager
local MiniShopManager = ClassMgr.Class("MiniShopManager")
MiniShopManager.miniId2ShopGood = {}

store.RemoteBuyGoodsCallBack:Connect(function(uin, goodsid, code, msg, num)
	if code ~= 0 then
		print("迷你商品兑换失败！错误: ", code, msg)
		--0-购买成功
		--1001-地图未上传
		--1002-用户取消购买
		--1003-此商品查询失败
		--1004-请求失败
		--1005-迷你币不足
		--
		--710-商品不存在
		--711-商品状态异常
		--712-不能购买自己的商品
		--713-已购买该商品，不能重复购买
		--714-购买失败，购买数量已达上限
		--
		return
	end
	if not MiniShopManager.miniId2ShopGood[goodsid] then
		print("迷你商品兑换失败！未配置于Unity的商品ID：", goodsid)
		return
	end
    local player = gg.getPlayerByUin(uin)
    if not player then
		print("迷你商品兑换失败！不存在的玩家UIN：", uin)
		return
    end
	--code=0 购买成功
	print("Goods purchase Success.")
	print("RemoteBuyGoodsCallBack - uin : ",uin)
	print("RemoteBuyGoodsCallBack - goodsid: ",goodsid)
	print("RemoteBuyGoodsCallBack - num: ",num)
    local shopGood = MiniShopManager.miniId2ShopGood[goodsid]
    shopGood:Give(player)
end)

-- 服务器：获取某个玩家已购买的商品列表
function MiniShopManager.GetPlayerPurchasedList(playerid)
	local buyList = store:ServiceGetPlayerDeveloperProducts(playerid)
	print("cloud store buy list = ", buyList)
	local buyListLength = #buyList
	if buyListLength > 0 then
		-- 遍历每个商品信息
		local buyItem = {}
		for _, value in pairs(buyList) do
			print("cloud buy list key = ", _)
			for key, info in pairs(value) do
				buyItem[key] = info
				print("cloud buy list key = ", key)
				print("cloud buy list info = ", info)
			end
		end
	end
	return buyList
end

return MiniShopManager