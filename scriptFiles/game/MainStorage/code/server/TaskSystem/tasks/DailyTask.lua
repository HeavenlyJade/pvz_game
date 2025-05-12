--- 日常任务实现类
--- V109 miniw-haima

local game = game
local pairs = pairs
local table = table
local os = os
local math = math

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local common_const = require(MainStorage.code.common.MConst)  ---@type common_const
local ClassMgr = require(MainStorage.code.common.ClassMgr)  ---@type ClassMgr
local CommandManager = require(MainStorage.code.server.CommandSystem.MCommandManager)  ---@type CommandManager
local BaseTask = require(MainStorage.code.server.TaskSystem.tasks.BaseTask) ---@type BaseTask

---@class DailyTask:BaseTask
local DailyTask = ClassMgr.Class('DailyTask', BaseTask)

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化任务
function DailyTask:OnInit(taskData)
    -- 调用基类初始化
    BaseTask.OnInit(self, taskData)
    
    -- 日常任务特有属性
    self.resetTime = taskData.resetTime or 0     -- 每日重置时间点（小时）
    self.availability = taskData.availability or {} -- 可用天数 {1, 2, 3, 4, 5, 6, 7}，空表示所有天数可用
    self.category = taskData.category or "default" -- 日常任务分类
    self.difficulty = taskData.difficulty or 1    -- 难度等级
    self.repeatable = taskData.repeatable or false -- 是否可重复完成（同一天内）
    self.timesCompleted = 0                       -- 当天已完成次数
    self.maxCompletions = taskData.maxCompletions or 1 -- 每日最大完成次数
    self.lastResetDate = nil                      -- 上次重置日期
    
    -- 检查任务是否需要重置
    self:CheckReset()
end

--------------------------------------------------
-- 日常任务特有方法
--------------------------------------------------

-- 检查任务是否需要重置
function DailyTask:CheckReset()
    local currentDate = os.date("*t")
    local currentDay = currentDate.wday -- 1是星期天，2是星期一，以此类推
    
    -- 如果没有上次重置日期，则设置为今天并返回
    if not self.lastResetDate then
        self.lastResetDate = os.date("%Y-%m-%d")
        return
    end
    
    -- 检查是否过了一天
    local lastDate = self.lastResetDate
    local today = os.date("%Y-%m-%d")
    
    if lastDate ~= today then
        -- 检查新的一天是否是可用日
        if #self.availability == 0 or gg.contains(self.availability, currentDay) then
            -- 重置任务
            self:Reset()
            self.lastResetDate = today
        else
            -- 如果今天不可用，则设置任务为不可接取
            self.status = "不可用"
        end
    end
end

-- 重置日常任务
function DailyTask:Reset()
    -- 清空当天已完成次数
    self.timesCompleted = 0
    
    -- 如果任务状态是已完成，则重置为未接取
    if self.status == "已完成" or self.status == "不可用" then
        self.status = "未接取"
    end
    
    -- 重置所有目标进度
    for i, _ in ipairs(self.objectives) do
        self.objectives[i].current = 0
        self.objectives[i].completed = false
    end
end

-- 检查任务是否可用
function DailyTask:IsAvailable()
    -- 检查任务是否需要重置
    self:CheckReset()
    
    -- 如果任务今天不可用，则返回false
    if self.status == "不可用" then
        return false
    end
    
    -- 如果日常任务不可重复且已完成，则返回false
    if not self.repeatable and self.status == "已完成" then
        return false
    end
    
    -- 如果日常任务可重复但已达到最大完成次数，则返回false
    if self.repeatable and self.timesCompleted >= self.maxCompletions then
        return false
    end
    
    return true
end

--------------------------------------------------
-- 重写基类方法
--------------------------------------------------

-- 重写接取任务方法，添加日常任务特有逻辑
function DailyTask:Accept(player)
    -- 检查任务是否可用
    if not self:IsAvailable() then
        return false, "日常任务当前不可用"
    end
    
    -- 调用基类的Accept方法
    return BaseTask.Accept(self, player)
end

-- 重写完成任务方法，添加日常任务特有逻辑
function DailyTask:Complete(player)
    -- 先调用基类的Complete方法
    local success, message = BaseTask.Complete(self, player)
    
    if success then
        -- 增加当天已完成次数
        self.timesCompleted = self.timesCompleted + 1
        
        -- 如果日常任务可重复且未达到最大完成次数，则重置为未接取状态
        if self.repeatable and self.timesCompleted < self.maxCompletions then
            self.status = "未接取"
            
            -- 重置所有目标进度
            for i, _ in ipairs(self.objectives) do
                self.objectives[i].current = 0
                self.objectives[i].completed = false
            end
            
            -- 通知玩家
            gg.network_channel:fireClient(player.uin, {
                cmd = "cmd_client_show_msg",
                txt = "日常任务已重置，还可完成" .. (self.maxCompletions - self.timesCompleted) .. "次",
                color = ColorQuad.new(0, 255, 0, 255)
            })
        end
    end
    
    return success, message
end

-- 重写获取UI数据方法，添加日常任务特有信息
function DailyTask:GetUIData()
    -- 获取基类的UI数据
    local baseData = BaseTask.GetUIData(self)
    
    -- 添加日常任务特有信息
    baseData.category = self.category
    baseData.difficulty = self.difficulty
    baseData.repeatable = self.repeatable
    baseData.timesCompleted = self.timesCompleted
    baseData.maxCompletions = self.maxCompletions
    baseData.remainingCompletions = math.max(0, self.maxCompletions - self.timesCompleted)
    baseData.resetTime = self.resetTime
    baseData.nextResetTime = self:GetNextResetTime()
    
    return baseData
end

-- 获取下次重置时间
function DailyTask:GetNextResetTime()
    local currentDate = os.date("*t")
    local nextResetDate = {
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day,
        hour = self.resetTime,
        min = 0,
        sec = 0
    }
    
    -- 如果当前时间已经过了今天的重置时间，则下次重置时间是明天
    if currentDate.hour >= self.resetTime then
        nextResetDate.day = nextResetDate.day + 1
    end
    
    -- 返回下次重置时间的时间戳
    return os.time(nextResetDate)
end