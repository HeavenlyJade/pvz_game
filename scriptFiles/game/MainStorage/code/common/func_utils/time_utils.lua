--- 提供时间相关的辅助函数
---@class TimeUtils
local TimeUtils = {}

--- 将Unix时间戳转换为格式化的日期时间字符串.
--- 该函数是安全的，会处理无效或越界的时间戳.
---@param timestamp number|nil Unix时间戳 (秒).
---@return string 格式化后的字符串 (例如 "2023-10-27 10:30:00")，或在失败时返回 "无效日期" 或 "无".
function TimeUtils.FormatTimestamp(timestamp)
    if not timestamp or type(timestamp) ~= "number" or timestamp <= 0 then
        return "无"
    end

    -- 使用pcall来安全地调用os.date，防止无效或越界的时间戳导致错误
    local status, result = pcall(os.date, "%Y-%m-%d %H:%M:%S", timestamp)

    if status and type(result) == "string" then
        return result
    else
        -- 如果os.date调用失败或返回的不是字符串，则返回一个备用值
        return "无效日期"
    end
end

--- 将时间戳格式化为"多久以前"的相对时间字符串.
---@param timestamp number|nil Unix时间戳 (秒).
---@param currentTime number|nil 当前时间戳，默认为os.time().
---@return string 相对时间字符串 (例如: "刚刚", "5分钟前", "3小时前", "3天前").
function TimeUtils.FormatTimeAgo(timestamp, currentTime)
    if not timestamp or type(timestamp) ~= "number" or timestamp <= 0 then
        return "未知时间"
    end

    currentTime = currentTime or os.time()
    local diff = currentTime - timestamp

    if diff < 0 then
        -- 对于未来的时间，直接显示具体日期，避免显示负数
        return TimeUtils.FormatTimestamp(timestamp)
    end

    if diff < 60 then
        return "刚刚"
    elseif diff < 3600 then -- 小于1小时
        return math.floor(diff / 60) .. "分钟前"
    elseif diff < 86400 then -- 小于1天
        return math.floor(diff / 3600) .. "小时前"
    elseif diff < 2592000 then -- 小于30天
        return math.floor(diff / 86400) .. "天前"
    else
        -- 超过30天，直接显示更具体的日期 (不含时间)
        local status, result = pcall(os.date, "%Y年%m月%d日", timestamp)
        if status and type(result) == "string" then
            return result
        else
            return "很久以前"
        end
    end
end

return TimeUtils