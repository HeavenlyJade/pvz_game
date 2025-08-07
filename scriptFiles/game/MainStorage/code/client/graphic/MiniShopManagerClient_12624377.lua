local MainStorage     = game:GetService("MainStorage")
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local store = game:GetService("DeveloperStoreService")

-- 获取地图开发者商店商品列表
local function GetStoreList()
	local storeList = store:GetDeveloperStoreItems()
	print("store list = ", storeList)
	local listLength = #storeList
	if listLength > 0 then
		-- 遍历每个商品信息
		local storeitem = {}
		for _, value in pairs(storeList) do
			print("store list key = ", _)
			for key, info in pairs(value) do
				storeitem[key] = info
				print("store list key = ", key)
				print("store list info = ", info)
			end
		end
	end
	return storeList
end

-- 获取玩家已购买的商品列表
local function GetPurchasedList()
	local buyList = store:GetPlayerDeveloperProducts()
	print("store buy list = ", buyList)
	local buyListLength = #buyList
	if buyListLength > 0 then
		-- 遍历每个商品信息
		local buyItem = {}
		for _, value in pairs(buyList) do
			print("store buy list key = ", _)
			for key, info in pairs(value) do
				buyItem[key] = info
				print("store buy list key = ", key)
				print("store buy list info = ", info)
			end
		end
	end
	return buyList
end

-- 获取地图开发者商店某个商品详细信息
local function GetGoodsInfo(goodsid)
	local goodsInfo = store:GetProductInfo(goodsid)
	if goodsInfo.name ~= nil then
		print("goods name = ", goodsInfo["name"])
	end
	if goodsInfo.desc ~= nil then
		print("goods desc = ", goodsInfo["desc"])
	end
	if goodsInfo.goodId ~= nil then
		print("goods goodId = ", goodsInfo["goodId"])
	end
	if goodsInfo.costType ~= nil then
		print("goods costType = ", goodsInfo["costType"])
	end
	if goodsInfo.costNum ~= nil then
		print("goods costNum = ", goodsInfo["costNum"])
	end
	if goodsInfo.download ~= nil then
		print("goods download = ", goodsInfo["download"])
	end
	if goodsInfo.cover ~= nil then
		print("goods cover = ", goodsInfo["cover"])
	end
	return goodsInfo
end

local function BuyGoods(goodsid, num)
end

ClientEventManager.Subscribe("ViewMiniGood", function (evt)
    store:BuyGoods(evt.goodId, evt.desc, evt.amount)
end)