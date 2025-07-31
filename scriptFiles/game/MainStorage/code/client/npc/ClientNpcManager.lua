local MainStorage = game:GetService('MainStorage')
local WorkSpace = game:GetService('WorkSpace')
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

---@class ClientNpcManager
local ClientNpcManager = {}

-- 处理NPC节点变量批量更新事件
local function OnUpdateNpcNodeVariables(eventData)
    if not eventData then
        gg.log("NPC节点变量批量更新事件数据为空")
        return
    end
    
    local nodePath = eventData.nodePath
    local variables = eventData.variables
    local npcName = eventData.npcName
    
    if not nodePath or not variables then
        gg.log("NPC节点变量批量更新事件缺少必要参数")
        return
    end
    
    -- 通过路径找到NPC节点
    local npcNode = gg.GetChild(WorkSpace, nodePath)
    if not npcNode then
        gg.log("找不到NPC节点:", nodePath, "NPC名:", npcName)
        return
    end
    
    -- 批量设置节点属性
    local updateCount = 0
    for variableName, variableInfo in pairs(variables) do
        local success = ClientNpcManager.SetNodeVariable(npcNode, variableName, variableInfo.value, variableInfo.variableType)
        if success then
            updateCount = updateCount + 1
        end
    end
    
    gg.log("客户端批量更新NPC节点变量:", npcName, "成功更新", updateCount, "个变量")
end

-- 处理NPC节点变量更新事件（单个变量，保留兼容性）
local function OnUpdateNpcNodeVariable(eventData)
    if not eventData then
        gg.log("NPC节点变量更新事件数据为空")
        return
    end
    
    local nodePath = eventData.nodePath
    local variableName = eventData.variableName
    local value = eventData.value
    local variableType = eventData.variableType
    local npcName = eventData.npcName
    
    if not nodePath or not variableName then
        gg.log("NPC节点变量更新事件缺少必要参数")
        return
    end
    
    -- 通过路径找到NPC节点
    local npcNode = gg.GetChild(WorkSpace, nodePath)
    if not npcNode then
        gg.log("找不到NPC节点:", nodePath, "NPC名:", npcName)
        return
    end
    
    -- 设置节点属性
    ClientNpcManager.SetNodeVariable(npcNode, variableName, value, variableType)
    
    gg.log("客户端更新NPC节点变量:", npcName, variableName, "=", value)
end

---设置节点变量的值
---@param node SandboxNode NPC节点
---@param variableName string 变量名
---@param value any 要设置的值
---@param variableType string 变量类型
---@return boolean 是否设置成功
function ClientNpcManager.SetNodeVariable(node, variableName, value, variableType)
    if not node then
        return false
    end
    
    -- 检查节点是否有该属性
    local hasProperty = pcall(function()
        return node[variableName]
    end)
    
    if not hasProperty then
        gg.log("警告: 节点没有属性", variableName, "节点:", node.Name)
        return false
    end
    
    -- 根据变量类型进行类型转换并设置
    local success, err = pcall(function()
        if variableType == "真假" then
            node[variableName] = value and true or false
        elseif variableType == "数字" then
            node[variableName] = tonumber(value) or 0
        elseif variableType == "字符串" then
            node[variableName] = tostring(value)
        else
            node[variableName] = value
        end
    end)
    
    if not success then
        gg.log("设置节点变量失败:", err, "节点:", node.Name, "变量:", variableName, "值:", value)
        return false
    end
    
    return true
end

-- 初始化客户端NPC管理器
function ClientNpcManager.Init()
    -- 注册事件监听
    ClientEventManager.Subscribe("UpdateNpcNodeVariables", OnUpdateNpcNodeVariables) -- 批量更新
    ClientEventManager.Subscribe("UpdateNpcNodeVariable", OnUpdateNpcNodeVariable)   -- 单个更新（兼容）
    
    gg.log("客户端NPC管理器初始化完成")
end

return ClientNpcManager