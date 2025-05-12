--- 玩家任务界面

local game = game
local script = script
local print = print
local math  = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs
local Vector2 = Vector2
local ColorQuad = ColorQuad
local Vector3 = Vector3

local MainStorage = game:GetService("MainStorage")
local gg                 = require(MainStorage.code.common.MGlobal)   ---@type gg
local common_config      = require(MainStorage.code.common.MConfig)   ---@type common_config

local Players            = game:GetService('Players')


---@class UiGameTask
local UiGameTask = {
    bg = nil,
    ui_task_bg = nil,
    ui_game_task = nil,
    task_index = 0,
    task_data = {},
    isNavigating = false,
    currentNavigateEvent = nil
}

--------------------------------------------------
-- UI 界面可见性控制函数
--------------------------------------------------

-- 显示任务界面
function UiGameTask.show()
    if UiGameTask.bg == nil then
        UiGameTask.initUI()
    end
    UiGameTask.bg.Visible = true
end

-- 关闭任务界面
function UiGameTask.close()
    UiGameTask.bg.Visible = false
end

-- 切换任务背景显示状态
function UiGameTask.toggleTaskBg()
    UiGameTask.ui_task_bg.Visible = not UiGameTask.ui_task_bg.Visible
end

--------------------------------------------------
-- UI 初始化函数
--------------------------------------------------

-- 初始化UI界面
function UiGameTask.init_map()
    local ui_root = gg.get_ui_root()
    local ui_root_spell = gg.get_ui_root_spell()
    
    UiGameTask.ui_task_bg = ui_root_spell.ui_task_left.bg
    UiGameTask.ui_game_task = ui_root_spell.ui_task_left.ui_game_task
    UiGameTask.bg = ui_root.ui_task.bg
    
    -- 绑定事件处理
    UiGameTask.bindUIEvents()
end

-- 绑定UI事件
function UiGameTask.bindUIEvents()
    UiGameTask.bg.ui_close.Click:Connect(function() UiGameTask.close() end)
    UiGameTask.ui_game_task.Click:Connect(function() UiGameTask.toggleTaskBg() end)
end

--------------------------------------------------
-- 任务数据处理函数
--------------------------------------------------

-- 获取完整任务配置信息
function UiGameTask.getTaskConfigById(taskId)
    -- 遍历所有章节查找匹配的任务ID
    for chapterKey, chapterData in pairs(common_config.main_line_task_config) do
        if chapterData.quests then
            for _, quest in ipairs(chapterData.quests) do
                if quest.id == taskId then
                    return quest, chapterData
                end
            end
        end
    end
    
    return nil, nil
end

-- 获取任务状态
function UiGameTask.getTaskStatus(taskId, mainLine)
    local status_value = 0  -- 默认为"未解锁"
    if mainLine.pending_pickup[taskId] then
        status_value = 3    -- "待领取"
    elseif mainLine.progress[taskId] then
        status_value = 1    -- "进行中"
    elseif mainLine.finish[taskId] then
        status_value = 2    -- "已完成"
    end
    
    return status_value
end

-- 获取任务状态文本
function UiGameTask.getTaskStatusText(statusValue)
    local status_text = {
        [0] = "未解锁",
        [1] = "进行中",
        [2] = "已完成",
        [3] = "待领取"
    }
    
    return status_text[statusValue]
end

-- 设置任务元素的状态
function UiGameTask.setTaskElementStatus(taskElement, taskId, mainLine)
    local statusValue = UiGameTask.getTaskStatus(taskId, mainLine)
    local statusText = UiGameTask.getTaskStatusText(statusValue)
    
    taskElement.task_status.Title = statusText
    
    return statusValue
end

-- 获取任务目标类型文本
function UiGameTask.getObjectiveTypeText(objectiveType)
    local typeText = common_config.typeText
    
    return typeText[objectiveType] or "未知目标"
end

--------------------------------------------------
-- 导航和任务高亮函数
--------------------------------------------------

-- 创建NPC区域高亮
function UiGameTask.createNpcHighlight(npcId)
    -- 检查npcId类型
    if type(npcId) ~= "table" and type(npcId) ~= "string" then
        gg.log("无效的NPC ID类型:", type(npcId))
        return nil
    end
    
    -- 转换为表格格式处理
    local npcList = {}
    if type(npcId) == "string" then
        table.insert(npcList, npcId)
    else
        npcList = npcId -- 已经是表格
    end
    
    local safeAreas = {}
    local container_npc = gg.clentGetContainerNpc()
    
    -- 为每个NPC创建高亮区域
    for _, npcIdStr in ipairs(npcList) do
        -- 查找NPC对象
        local obj_npc = container_npc[npcIdStr]
        if not obj_npc then
            gg.log("NPC未找到:", npcIdStr)
            return nil
        end
        
        -- 创建高亮区域
        local safeArea = SandboxNode.new('Area', obj_npc)
        local npcSize = obj_npc.Size
        local centerPos = obj_npc.Position
        
        -- 设置区域范围
        local expand = Vector3.new(25, 10, 150)
        safeArea.Beg = centerPos - (npcSize/2 + expand)
        safeArea.End = centerPos + (npcSize/2 + expand)
        
        -- 设置区域显示样式
        safeArea.Show = true
        safeArea.Color = ColorQuad.new(0, 255, 0, 100)
        safeArea.EffectWidth = 3        
        table.insert(safeAreas, safeArea)
    end
    
    return safeAreas
end

-- 设置导航事件
function UiGameTask.setupNavigation(taskButton, location, safeAreas)
    if not location then return end
    
    taskButton.Click:Connect(function()
        local targetPos = Vector3.new(location[1], location[2], location[3])
        local actor_ = gg.getClientLocalPlayer()
        
        if UiGameTask.isNavigating then
            actor_:StopNavigate()
            UiGameTask.isNavigating = false
            return
        end
        
        actor_:NavigateTo(targetPos)
        UiGameTask.isNavigating = true          
    end)
    
    -- 为每个安全区域添加事件
    if type(safeAreas) == "table" then
        for _, safeArea in ipairs(safeAreas) do
            if safeArea then
                safeArea.EnterNode:Connect(function(node)
                    if node.UserId and node.UserId > 0 then
                        node:StopNavigate()
                        UiGameTask.isNavigating = false          
                    end
                end)
            end
        end
    end
end

-- 创建任务按钮
function UiGameTask.createTaskButton(taskConfig, statusValue, questData)
    if statusValue ~= 1 then  -- 只有进行中的任务需要创建按钮
        return
    end
    
    local textLabel_ = UiGameTask.ui_task_bg.task_btton 
    local task_desc_ = UiGameTask.ui_task_bg.task_desc
    
    -- 构建详细任务描述    
    
    task_desc_.Title = taskConfig.description
    
    -- 设置任务按钮
    textLabel_.Size = Vector2.new(148, 30)
    textLabel_.Pivot = Vector2.new(0.5, 0)
    textLabel_.Position = Vector2.new(76, 0 + UiGameTask.task_index * 30)
    textLabel_.FillColor = ColorQuad.new(0, 0, 0, 0)
    textLabel_.TitleSize = 20
    textLabel_.Name = "task" .. taskConfig.id
    textLabel_.Title = taskConfig.name
    textLabel_.TextHAlignment = Enum.TextHAlignment.Center
    
    -- 设置任务ID属性
    textLabel_:AddAttribute("task_id", Enum.AttributeType.Number)
    textLabel_:SetAttribute("task_id", taskConfig.id)
    
    -- 创建NPC高亮区域并设置导航事件
    local safeArea = UiGameTask.createNpcHighlight(taskConfig.npc)
    UiGameTask.setupNavigation(textLabel_, taskConfig.location, safeArea)
    
    -- 如果任务正在追踪中，显示导航标记
    if questData and questData.tracking and questData.tracking.active then
        textLabel_.TitleColor = ColorQuad.new(0, 255, 0, 255) -- 绿色表示正在追踪
    else
        textLabel_.TitleColor = ColorQuad.new(255, 255, 255, 255) -- 白色表示未追踪
    end
    
    UiGameTask.task_index = UiGameTask.task_index + 1
    
    return textLabel_
end

-- 处理单个任务项
function UiGameTask.processTaskItem(taskConfig, taskElement, mainLine, isFirst, index)
    if not taskConfig then return nil end
    
    local taskId = taskConfig.id
    
    -- 设置任务名称
    taskElement.task_tiitle.Title = taskConfig.name
    
    -- 设置任务位置
    if not isFirst then
        taskElement.Position = Vector2.new(
            taskElement.Position.x, 
            taskElement.Position.y + (index - 1) * taskElement.Size.y
        )
    else
        taskElement.Position = Vector2.new(
            taskElement.Position.x,
            taskElement.Position.y - 230
        )
    end
    
    -- 设置任务状态
    local statusValue = UiGameTask.setTaskElementStatus(taskElement, taskId, mainLine)
    
    -- 获取任务的详细数据
    local questData = mainLine.progress[taskId]
    
    -- 创建任务按钮（如果是进行中）
    UiGameTask.createTaskButton(taskConfig, statusValue, questData)
    
    return taskElement
end

--------------------------------------------------
-- 主要任务同步函数
--------------------------------------------------

-- 处理任务章节显示
function UiGameTask.displayChapterInfo(chapterData, chapterElement)
    chapterElement.chapter_num.Title = chapterData.chapter
    chapterElement.chapter_title.Title = chapterData.name
    chapterElement.chapter_desc.Title = chapterData.description
end

-- 处理同步玩家游戏任务
function UiGameTask.handleSyncPlayerGameTask(game_args_)
    -- gg.log("处理同步玩家的游戏任务数据handleSyncPlayerGameTask", game_args_)
    if not game_args_ then return end
    
    local task_data = game_args_.task_data
    if not task_data then return end
    
    local main_line = task_data.main_line
    if not main_line then return end
    
    -- 重置任务索引
    UiGameTask.task_index = 0
    
    -- 获取UI元素
    local bg = UiGameTask.bg
    if not bg then return end
    
    local chapter_task = bg.chapter_task
    local task_list = chapter_task.task_list
    
    -- 处理章节和任务
    for chapterKey, chapterData in pairs(common_config.main_line_task_config) do
        -- 更新章节信息
        UiGameTask.displayChapterInfo(chapterData, chapter_task.chapter)
        
        -- 获取基础任务元素
        local task_base = task_list.task_base
        
        -- 处理任务列表
        if chapterData.quests then
            for index, quest in ipairs(chapterData.quests) do
                if index == 1 then
                    UiGameTask.processTaskItem(quest, task_base, main_line, true, index)
                else
                    local task_clone = task_base:Clone()
                    task_clone.Name = "main" .. quest.id
                    task_clone.Parent = task_list
                    UiGameTask.processTaskItem(quest, task_clone, main_line, false, index)
                end
            end
        end
    end
    
    -- 如果有任务正在追踪，自动显示任务界面
    local hasActiveTracking = false
    for questType, questData in pairs(task_data) do
        if questData.progress then
            for questId, quest in pairs(questData.progress) do
                if quest.tracking and quest.tracking.active then
                    hasActiveTracking = true
                    UiGameTask.ui_task_bg.Visible = true
                    break
                end
            end
            if hasActiveTracking then break end
        end
    end
end

return UiGameTask