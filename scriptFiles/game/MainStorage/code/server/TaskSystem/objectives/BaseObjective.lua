--- 任务目标基类
--- V109 miniw-haima

local game = game
local pairs = pairs
local table = table

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg
local common_config = require(MainStorage.code.common.MConfig)  ---@type common_config
local common_const = require(MainStorage.code.common.MConst)  ---@type common_const
local ClassMgr = require(MainStorage.code.common.ClassMgr)  ---@type ClassMgr

---@class BaseObjective
local BaseObjective = ClassMgr.Class('BaseObjective')

--------------------------------------------------
-- 初始化方法
--------------------------------------------------

-- 初始化目标
function BaseObjective:OnInit(objectiveData)
    self.type = objectiveData.type                -- 目标类型
    self.target = objectiveData.target            -- 目标对象
    self.target_id = objectiveData.target_id      -- 目标ID
    self.target_name = objectiveData.target_name  -- 目标名称
    self.required = objectiveData.count or 1      -- 需要完成的数量
    self.current = 0                              -- 当前完成数量
    self.completed = false                        -- 是否已完成
    self.optional = objectiveData.optional or false -- 是否可选
    self.locations = objectiveData.locations or {} -- 目标位置
    self.config = objectiveData                   -- 目标配置
    self.task = nil                               -- 关联的任务
end

--------------------------------------------------
-- 目标进度管理
--------------------------------------------------

-- 更新目标进度
function BaseObjective:Update(player, progress)
    -- 如果目标已完成，则不再更新
    if self.completed then
        return false, "目标已完成"
    end
    
    -- 更新进度
    self.current = math.min(self.current + progress, self.required)
    
    -- 检查是否完成
    if self.current >= self.required then
        self.completed = true
        
        -- 通知玩家
        gg.network_channel:fireClient(player.uin, {
            cmd = "cmd_client_show_msg",
            txt = "目标已完成！",
            color = ColorQuad.New(0, 255, 0, 255)
        })
    end
    
    return true, "目标进度已更新"
end

-- 检查目标是否完成
function BaseObjective:IsCompleted()
    return self.completed
end

-- 重置目标
function BaseObjective:Reset()
    self.current = 0
    self.completed = false
end

-- 设置关联任务
function BaseObjective:SetTask(task)
    self.task = task
end

--------------------------------------------------
-- 目标UI相关
--------------------------------------------------

-- 获取目标描述
function BaseObjective:GetDescription()
    local targetName = self.target_name or self.target or ""
    local typeText = common_config.typeText[self.type] or "未知目标"
    local optionalText = self.optional and "[可选] " or ""
    
    -- 默认描述
    return optionalText .. typeText .. " (" .. self.current .. "/" .. self.required .. ")"
end

-- 获取目标数据（用于UI展示）
function BaseObjective:GetUIData()
    return {
        type = self.type,
        target = self.target,
        target_id = self.target_id,
        target_name = self.target_name,
        current = self.current,
        required = self.required,
        completed = self.completed,
        optional = self.optional,
        locations = self.locations,
        description = self:GetDescription()
    }
end

return BaseObjective