-- 在UIDialogBox.lua中添加与NPC交互的功能
--- 任务对话框

local game = game
local script = script
local print = print
local math = math
local SandboxNode = SandboxNode
local Enum = Enum
local pairs = pairs
local Vector2 = Vector2
local Vector3 = Vector3
local ColorQuad = ColorQuad
local MainStorage = game:GetService("MainStorage")
local inputservice = game:GetService("UserInputService")
local Players = game:GetService('Players')

local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local UIDialogBox = require(MainStorage.code.client.ui.UiTask.UIDialogBox) ---@type UIDialogBox
local UiGameTask = require(MainStorage.code.client.ui.UiTask.UiTaskMain) ---@type UiGameTask

-- 添加NPC交互系统
local NPCInteraction = {
    activeNPC = nil,
    npcTasks = {},  -- 存储NPC关联的任务
    activeAreas = {}  -- 存储活跃的交互区域
}

-- 初始化NPC交互区域（修改版）
function NPCInteraction.setupNPCInteraction(npcIds, task)
    -- 转换为表格格式处理
    local npcList = {}
    if type(npcIds) == "string" then
        table.insert(npcList, npcIds)   else
        npcList = npcIds -- 已经是表格
    end
    
    for _, npcId in ipairs(npcList) do
        local container_npc = gg.clentGetContainerNpc()
        local npc_node_id
        gg.log("container_npc",container_npc)
        if string.find(npcId, " ") then
            local npc_msg = gg.split(npcId, " ")
            npc_node_id = gg.client_scene_name .. npc_msg[2]
        else
            npc_node_id = gg.client_scene_name .. "_" .. npcId
        end
        
        local obj_npc = container_npc[npc_node_id]
        if not obj_npc then
            gg.log("NPC未找到:", npc_node_id)
            goto continue
        end
        
        -- 创建交互区域
        local interactArea = SandboxNode.new('Area', obj_npc)
        local npcSize = obj_npc.Size
        local centerPos = obj_npc.Position
        
        -- 设置区域范围
        local expand = Vector3.New(15, 5, 15)
        interactArea.Beg = centerPos - (npcSize/2 + expand)
        interactArea.End = centerPos + (npcSize/2 + expand)
        
        -- 存储NPC关联的任务
        NPCInteraction.npcTasks[npcId] = task
        
        -- 设置进入和离开事件
        interactArea.EnterNode:Connect(function(node)
            if node.UserId and node.UserId > 0 then
                NPCInteraction.activeNPC = npcId
                NPCInteraction.triggerNPCDialog(npcId)
            end
        end)
        
        interactArea.LeaveNode:Connect(function(node)
            if node.UserId and node.UserId > 0 and NPCInteraction.activeNPC == npcId then
                NPCInteraction.activeNPC = nil
                if UIDialogBox.isVisible() then
                    UIDialogBox.hide()
                end
            end
        end)
        
        NPCInteraction.activeAreas[npcId] = interactArea
        ::continue::
    end
end

-- 触发NPC对话
function NPCInteraction.triggerNPCDialog(npcId)
    local tasks = NPCInteraction.npcTasks[npcId]
    if not tasks or #tasks == 0 then
        return
    end
    
    -- 获取第一个可用任务
    local activeTask = nil
    for _, task in ipairs(tasks) do
        -- 检查任务状态，只触发进行中或可接取的任务
        local mainLine = gg.getPlayerTaskData().main_line
        local statusValue = UiGameTask.getTaskStatus(task.id, mainLine)
        if statusValue == 1 or statusValue == 3 then  -- 进行中或待领取
            activeTask = task
            break
        end
    end
    
    if not activeTask then
        return
    end
    
    -- 创建对话内容
    local npcName = activeTask.npcName or "NPC"
    local dialogs = {}
    
    if activeTask.dialogs then
        dialogs = activeTask.dialogs
    else
        -- 根据任务状态创建默认对话
        local mainLine = gg.getPlayerTaskData().main_line
        local statusValue = UiGameTask.getTaskStatus(activeTask.id, mainLine)
        
        if statusValue == 3 then  -- 待领取
            table.insert(dialogs, {
                name = npcName,
                content = "任务已完成！请领取奖励。"
            })
        else  -- 进行中
            table.insert(dialogs, {
                name = npcName,
                content = activeTask.description or "请完成任务目标。"
            })
        end
    end
    
    -- 显示对话框
    UIDialogBox.startDialogs(dialogs, function()
        -- 对话结束后更新任务状态
        NPCInteraction.handleTaskInteraction(activeTask)
    end)
end

-- 处理任务交互
function NPCInteraction.handleTaskInteraction(task)
    local mainLine = gg.getPlayerTaskData().main_line
    local statusValue = UiGameTask.getTaskStatus(task.id, mainLine)
    
    if statusValue == 3 then  -- 待领取
        -- 领取任务奖励
        gg.log("领取任务奖励:", task.id)
        gg.sendTaskComplete(task.id)
        
        -- 显示奖励提示
        UIDialogBox.setDialog(
            "系统",
            "完成任务：" .. task.name .. "，获得奖励！",
            function()
                -- 刷新任务列表
                gg.requestSyncGameTask()
            end
        )
    elseif statusValue == 0 then  -- 未解锁
        -- 尝试接取任务
        gg.log("尝试接取任务:", task.id)
        gg.sendTaskStart(task.id)
        
        -- 刷新任务列表
        gg.requestSyncGameTask()
    end
end

-- 在游戏初始化时注册所有NPC交互区域
function NPCInteraction.initAllNPCInteractions()
    local common_config = require(MainStorage.code.common.MConfig)
    local gametask_data = common_config.main_line_task_config
    
    for chapter_key, chapter_data in pairs(gametask_data) do
        for _, quest in ipairs(chapter_data.quests) do
            if quest.npc then
                NPCInteraction.setupNPCInteraction(quest.npc, quest)
            end
        end
    end
end

-- 获取玩家任务数据的辅助函数（需要根据实际代码调整）
function gg.getPlayerTaskData()
    -- 这个函数需要根据你的实际代码返回玩家任务数据
    -- 如果已有类似函数，可以直接调用而不需要实现这个
    local gameData = game:GetService("Players").LocalPlayer.TaskData
    gg.log("获取玩家任务数据", gameData)
    return gameData
end

-- 发送任务完成请求
function gg.sendTaskComplete(taskId)
    -- 向服务器发送任务完成请求
    gg.network_channel:FireServer({
        cmd = "cmd_complete_task",
        task_id = taskId
    })
end

-- 发送任务开始请求
function gg.sendTaskStart(taskId)
    -- 向服务器发送任务开始请求
    game:GetService("ReplicatedStorage").RemoteEvents.TaskStart:FireServer(taskId)
end

-- 请求同步游戏任务
function gg.requestSyncGameTask()
    -- 请求服务器同步最新的任务数据
    game:GetService("ReplicatedStorage").RemoteEvents.SyncGameTask:FireServer()
end

return NPCInteraction