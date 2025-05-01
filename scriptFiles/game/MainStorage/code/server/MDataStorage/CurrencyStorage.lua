--- V109 miniw-haima
--- 货币存储管理，负责货币数据持久化，与云服务交互

local game = game
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg
local cloudService = game:GetService("CloudService")   -- 云数据服务

---@class CurrencyStorage
local CurrencyStorage = {

    
    -- 最后一次加载时间缓存 {uin: timestamp}
    lastLoadTime = {},
    
    -- 存储键前缀
    STORAGE_KEY_PREFIX = "currency_"
}

--- 加载玩家货币数据
---@param uin number 玩家ID
---@return boolean 是否成功
---@return table 货币数据
function CurrencyStorage:LoadPlayerCurrencyData(uin)
    -- 检查是否有缓存过期控制
    local now = os.time()

    -- 从云存储加载数据
    local success, data = cloudService:GetTableOrEmpty(self.STORAGE_KEY_PREFIX .. uin)
    
    if success then
        -- 更新加载时间
        self.lastLoadTime[uin] = now
        
        -- 验证数据完整性
        if data and data.uin == uin then
            gg.log("成功加载玩家货币数据", uin)
            return true, data
        else
            gg.log("玩家货币数据结构不完整", uin)
            return false, {}  -- 返回nil，让调用者创建新数据
        end
    else
        gg.log("加载玩家货币数据失败", uin)
        return false, {}
    end
end

--- 保存玩家货币数据
---@param uin number 玩家ID
---@param data table 货币数据
---@return boolean 是否成功
function CurrencyStorage:SavePlayerCurrencyData(uin, data)
    -- 确保数据有效
    if not data or data.uin ~= uin then
        gg.log("货币数据无效，保存失败", uin)
        return false
    end
    
    -- 使用异步方法保存数据
    cloudService:SetTableAsync(self.STORAGE_KEY_PREFIX .. uin, data, function(success)
        if success then
            gg.log("成功保存玩家货币数据", uin)
        else
            gg.log("保存玩家货币数据失败", uin)
        end
    end)
    
    return true
end

--- 删除玩家货币数据
---@param uin number 玩家ID
---@return boolean 是否成功
function CurrencyStorage:DeletePlayerCurrencyData(uin)
    -- 直接设置为空表来"删除"数据
    local success = cloudService:SetTable(self.STORAGE_KEY_PREFIX .. uin, {})
    
    if success then
        -- 清除缓存
        self.lastLoadTime[uin] = nil
        gg.log("成功删除玩家货币数据", uin)
    else
        gg.log("删除玩家货币数据失败", uin)
    end
    
    return success
end

--- 批量加载玩家货币数据
---@param uinList table 玩家ID列表
---@return table 货币数据表 {uin: data}
function CurrencyStorage:BatchLoadPlayerCurrencyData(uinList)
    local result = {}
    
    for _, uin in ipairs(uinList) do
        local success, data = self:LoadPlayerCurrencyData(uin)
        if success and data then
            result[uin] = data
        end
    end
    
    return result
end


--- 初始化存储服务
function CurrencyStorage:Init()
    gg.log("货币存储系统初始化完成")
    return self
end

return CurrencyStorage:Init()
    