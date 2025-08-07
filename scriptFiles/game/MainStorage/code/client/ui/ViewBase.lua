local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

local displayingUI = {}
local hiddenHuds = {} -- 记录被隐藏的layer=0界面

---@class ViewConfig
---@field uiName string 界面名称
---@field hideOnInit boolean 是否在初始化时隐藏
---@field layer number 0=主界面Hud， >1=GUI界面。 GUI在打开时关闭其他同layer的GUI
---@field closeHuds boolean
---@field mouseVisible boolean
---@field closeHideMouse boolean

---@class ViewBase:Class
---@field New fun(node: SandboxNode, config: ViewConfig): ViewBase
---@field GetUI fun(name: string): ViewBase
local ViewBase = ClassMgr.Class("ViewBase")
ViewBase.topGui = nil ---@type ViewBase
ViewBase.UiBag = nil ---@type UiBag
ViewBase.UIConfirm = nil ---@type UIConfirm
ViewBase.allUI = {}
ViewBase.serverNews = {} ---@type table 服务端红点状态字典
ViewBase.clientNews = {} ---@type table 客户端本地红点状态字典
ViewBase.newsCache = {} ---@type table<string, boolean> 红点路径状态缓存
ViewBase.pathHierarchy = {} ---@type table<string, string[]> 路径层级关系索引 {父路径 = {子路径列表}}
ViewBase.newsInitialized = false ---@type boolean 红点系统是否已初始化
ViewBase.newsWatchers = {} ---@type table<string, ViewButton[]> 红点路径监听者列表
ViewBase.hasReceivedSync = false ---@type boolean 是否已接收过服务端同步数据
---@generic T : ViewBase
---@param name string
---@return T
function ViewBase.GetUI(name)
    return ViewBase.allUI[name]
end

---初始化红点系统
function ViewBase.InitNewsSystem()
    if ViewBase.newsInitialized then
        return
    end
    
    ViewBase.newsInitialized = true
    
    -- 监听同步所有红点事件
    ClientEventManager.Subscribe("SyncAllNews", function(evt)
        local serverNews = evt.news or {}
        ViewBase.serverNews = serverNews
        ViewBase._clearAllCache() -- 清空路径缓存
        -- 刷新所有监听者
        ViewBase._refreshAllWatchers()
    end)
    
    -- 监听红点变化事件
    ClientEventManager.Subscribe("UpdateNews", function(evt)
        ViewBase._updateNewsPath(evt.path, evt.mark, ViewBase.serverNews)
        gg.log("红点系统: 更新服务端路径", evt.path, "状态", evt.mark)
        -- 刷新相关监听者
        ViewBase._refreshWatchersForPath(evt.path)
    end)
end

---合并两个红点数据表
---@param serverData table 服务端数据
---@param clientData table 客户端数据
---@return table 合并后的数据
function ViewBase._mergeNewsData(serverData, clientData)
    local result = {}
    
    -- 深拷贝服务端数据作为基础
    ViewBase._deepCopyTable(serverData, result)
    
    -- 将客户端数据合并进去
    ViewBase._mergeTableRecursive(result, clientData)
    
    return result
end

---深拷贝表
---@param source table 源表
---@param target table 目标表
function ViewBase._deepCopyTable(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = {}
            ViewBase._deepCopyTable(value, target[key])
        else
            target[key] = value
        end
    end
end

---递归合并表（客户端数据优先）
---@param target table 目标表
---@param source table 源表
function ViewBase._mergeTableRecursive(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            elseif type(target[key]) ~= "table" then
                -- 如果目标是boolean值，转换为table
                target[key] = {}
            end
            ViewBase._mergeTableRecursive(target[key], value)
        else
            -- 客户端的boolean值直接覆盖
            target[key] = value
        end
    end
end

---更新红点路径状态
---@param path string 红点路径
---@param mark boolean 红点状态
---@param targetTable? table 目标表，默认为ViewBase.clientNews
function ViewBase._updateNewsPath(path, mark, targetTable)
    if not path then return end
    
    targetTable = targetTable or ViewBase.clientNews
    
    -- 只有操作客户端或服务端主表时才使缓存失效
    if targetTable == ViewBase.clientNews or targetTable == ViewBase.serverNews then
        ViewBase._invalidatePathCache(path)
    end
    
    -- 分割路径
    local current = targetTable
    local parts = {}
    local parentTables = {}
    
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    -- 创建或删除嵌套表结构
    for i, part in ipairs(parts) do
        if i == #parts then
            -- 最后一个部分
            if mark then
                current[part] = true
            else
                current[part] = nil
            end
        else
            -- 中间部分
            if mark then
                if type(current[part]) == "boolean" then
                    -- 如果当前节点是boolean值，需要转换为table
                    current[part] = {}
                else
                    current[part] = current[part] or {}
                end
            elseif not current[part] then
                return -- 如果是要取消标记但路径不存在，直接返回
            end
            table.insert(parentTables, {table = current, key = part})
            current = current[part]
        end
    end
    
    -- 递归清理空表
    if not mark then
        for i = #parentTables, 1, -1 do
            local parent = parentTables[i]
            if next(parent.table[parent.key]) == nil then
                parent.table[parent.key] = nil
            else
                break -- 如果遇到非空表，停止清理
            end
        end
    end
end

---使指定路径及其所有父路径的缓存失效
---@param path string 红点路径
function ViewBase._invalidatePathCache(path)
    if not path then return end
    
    -- 清除当前路径缓存
    ViewBase.newsCache[path] = nil
    
    -- 清除所有父路径缓存
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    for i = 1, #parts - 1 do
        local parentPath = table.concat(parts, "/", 1, i)
        ViewBase.newsCache[parentPath] = nil
    end
end

---建立路径层级关系
---@param childPath string 子路径
function ViewBase._buildPathHierarchy(childPath)
    if not childPath then return end
    
    local parts = {}
    for part in childPath:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    -- 为每个父路径添加子路径关系
    for i = 1, #parts - 1 do
        local parentPath = table.concat(parts, "/", 1, i)
        if not ViewBase.pathHierarchy[parentPath] then
            ViewBase.pathHierarchy[parentPath] = {}
        end
        
        -- 避免重复添加
        local found = false
        for _, child in ipairs(ViewBase.pathHierarchy[parentPath]) do
            if child == childPath then
                found = true
                break
            end
        end
        
        if not found then
            table.insert(ViewBase.pathHierarchy[parentPath], childPath)
        end
    end
end

---移除路径层级关系
---@param childPath string 子路径
function ViewBase._removePathHierarchy(childPath)
    if not childPath then return end
    
    local parts = {}
    for part in childPath:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    -- 从每个父路径中移除子路径关系
    for i = 1, #parts - 1 do
        local parentPath = table.concat(parts, "/", 1, i)
        if ViewBase.pathHierarchy[parentPath] then
            for j, child in ipairs(ViewBase.pathHierarchy[parentPath]) do
                if child == childPath then
                    table.remove(ViewBase.pathHierarchy[parentPath], j)
                    break
                end
            end
            
            -- 如果父路径没有子路径了，清理
            if #ViewBase.pathHierarchy[parentPath] == 0 then
                ViewBase.pathHierarchy[parentPath] = nil
            end
        end
    end
end

---清空所有路径缓存
function ViewBase._clearAllCache()
    ViewBase.newsCache = {}
    ViewBase.pathHierarchy = {}
end

---检查红点状态（检查服务端和客户端两个表）
---@param path string 红点路径
---@return boolean
function ViewBase.IsNew(path)
    if not path then 
        return false 
    end
    
    -- 检查缓存
    if ViewBase.newsCache[path] ~= nil then
        return ViewBase.newsCache[path]
    end
    
    -- 检查服务端红点
    local hasServerNews = ViewBase._checkPathInTable(path, ViewBase.serverNews)
    if hasServerNews then
        ViewBase.newsCache[path] = true
        return true
    end
    
    -- 检查客户端红点
    local hasClientNews = ViewBase._checkPathInTable(path, ViewBase.clientNews)
    if hasClientNews then
        ViewBase.newsCache[path] = true
        return true
    end
    
    -- 两个表都没有，缓存false结果
    ViewBase.newsCache[path] = false
    return false
end

---检查指定路径在表中是否存在
---@param path string 红点路径
---@param table table 要检查的表
---@return boolean
function ViewBase._checkPathInTable(path, table)
    if not table then
        return false
    end
    
    local current = table
    for part in path:gmatch("[^/]+") do
        if not current[part] then
            return false
        end
        current = current[part]
    end
    
    -- 存在即为true，不管是叶子节点(true值)还是中间节点(table)
    return true
end

---注册红点监听者
---@param path string 红点路径
---@param button ViewButton 按钮组件
function ViewBase.RegisterNewsWatcher(path, button)
    if not path or not button then
        return
    end
    
    if not ViewBase.newsWatchers[path] then
        ViewBase.newsWatchers[path] = {}
    end
    
    -- 检查是否已经注册过
    for _, watcher in ipairs(ViewBase.newsWatchers[path]) do
        if watcher == button then
            return -- 已经注册过，跳过
        end
    end
    
    table.insert(ViewBase.newsWatchers[path], button)
    
    -- 建立路径层级关系
    ViewBase._buildPathHierarchy(path)
    
    -- 立即刷新该按钮的红点状态
    ViewBase._refreshButtonNews(button, path)
end

---取消注册红点监听者
---@param path string 红点路径
---@param button ViewButton 按钮组件
function ViewBase.UnregisterNewsWatcher(path, button)
    if not path or not button or not ViewBase.newsWatchers[path] then
        return
    end
    
    for i, watcher in ipairs(ViewBase.newsWatchers[path]) do
        if watcher == button then
            table.remove(ViewBase.newsWatchers[path], i)
            break
        end
    end
    
    -- 如果该路径没有监听者了，清理
    if #ViewBase.newsWatchers[path] == 0 then
        ViewBase.newsWatchers[path] = nil
    end
end

---刷新所有监听者的红点状态
function ViewBase._refreshAllWatchers()
    -- 直接刷新所有注册的监听者
    for path, watchers in pairs(ViewBase.newsWatchers) do
        for _, button in ipairs(watchers) do
            ViewBase._refreshButtonNews(button, path)
        end
    end
end

---刷新指定路径相关的监听者
---@param changedPath string 发生变化的路径
function ViewBase._refreshWatchersForPath(changedPath)
    -- 刷新完全匹配的路径
    if ViewBase.newsWatchers[changedPath] then
        for _, button in ipairs(ViewBase.newsWatchers[changedPath]) do
            ViewBase._refreshButtonNews(button, changedPath)
        end
    end
    
    -- 使用层级关系索引快速找到需要刷新的父路径
    local parts = {}
    for part in changedPath:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    -- 检查所有父路径是否有监听者需要刷新
    for i = 1, #parts - 1 do
        local parentPath = table.concat(parts, "/", 1, i)
        if ViewBase.newsWatchers[parentPath] then
            for _, button in ipairs(ViewBase.newsWatchers[parentPath]) do
                ViewBase._refreshButtonNews(button, parentPath)
            end
        end
    end
end

---刷新单个按钮的红点状态
---@param button ViewButton 按钮组件
---@param path string 红点路径
function ViewBase._refreshButtonNews(button, path)
    if not button or not button.newNode then
        return
    end
    
    -- 强制清除该路径的缓存，确保获取最新状态
    ViewBase.newsCache[path] = nil
    
    local isNew = ViewBase.IsNew(path)
    button.newNode.Visible = isNew
end

---客户端标记红点状态（等同于MarkNew，保留用于兼容性）
---@param path string 红点路径  
---@param mark boolean 红点状态 (true=标记红点, false=清除红点)
function ViewBase.SetNew(path, mark)
    ViewBase.MarkNew(path, mark)
end
---客户端标记红点状态（只影响客户端本地红点）
---@param path string 红点路径
---@param mark boolean 红点状态 (true=标记红点, false=清除红点)
function ViewBase.MarkNew(path, mark)
    if not path or path == "" then
        gg.log("[ViewBase.MarkNew] 错误: 红点路径不能为空")
        return false
    end
    
    -- 参数验证
    if type(path) ~= "string" then
        gg.log("[ViewBase.MarkNew] 错误: 红点路径必须是字符串, 收到:", type(path))
        return false
    end
    
    if type(mark) ~= "boolean" then
        gg.log("[ViewBase.MarkNew] 错误: 红点状态必须是布尔值, 收到:", type(mark))
        return false
    end
    
    gg.log("MarkNewClient", path, mark)
    ViewBase._updateNewsPath(path, mark, ViewBase.clientNews)
    ViewBase._refreshWatchersForPath(path)
    
    return true
end


---客户端批量标记红点状态（只影响客户端本地红点）
---@param markList table 红点标记列表 {path1=true, path2=false, ...}
function ViewBase.MarkNewBatch(markList)
    if not markList or type(markList) ~= "table" then
        gg.log("[ViewBase.MarkNewBatch] 错误: 标记列表必须是表格")
        return false
    end
    
    local validMarks = {}
    local hasValidMark = false
    
    -- 验证和处理每个标记
    for path, mark in pairs(markList) do
        if type(path) == "string" and path ~= "" and type(mark) == "boolean" then
            -- 立即更新本地客户端红点状态
            ViewBase._updateNewsPath(path, mark, ViewBase.clientNews)
            -- 刷新相关的监听者
            ViewBase._refreshWatchersForPath(path)
            
            validMarks[path] = mark
            hasValidMark = true
        else
            gg.log("[ViewBase.MarkNewBatch] 跳过无效标记:", "路径=" .. tostring(path), "状态=" .. tostring(mark))
        end
    end
    
    -- 返回操作结果
    if hasValidMark then
        gg.log("[ViewBase.MarkNewBatch] 客户端批量红点操作:", gg.table2str(validMarks))
        return true
    else
        gg.log("[ViewBase.MarkNewBatch] 警告: 没有有效的红点标记")
        return false
    end
end

---@param visible boolean 是否锁定鼠标
function ViewBase.LockMouseVisible(visible)
    if game.RunService:IsPC() then
        if visible then
            -- 如果已经有锁定任务，先取消
            if ViewBase.mouseLockTaskId then
                ClientScheduler.cancel(ViewBase.mouseLockTaskId)
            end
            -- 创建新的锁定任务
            ViewBase.mouseLockTaskId = ClientScheduler.add(function()
                game.MouseService:SetMode(0)
            end, 0, 0.1) -- 每帧执行一次
        else
            -- 取消锁定任务
            if ViewBase.mouseLockTaskId then
                ClientScheduler.cancel(ViewBase.mouseLockTaskId)
                ViewBase.mouseLockTaskId = nil
            end
            -- 恢复鼠标模式
            game.MouseService:SetMode(1)
            -- 新增：通知CameraController进入极限输入保护期
            local CameraController = require(MainStorage.code.client.camera.CameraController)
            CameraController.BlockExtremeInputFor(0.1)
        end
    end
end

if game.RunService:IsPC() then
    ClientEventManager.Subscribe("PressKey", function (evt)
        if evt.key == Enum.KeyCode.Escape.Value then
            -- 直接使用 topGui 关闭最上层的 UI
            if ViewBase.topGui then
                ViewBase.topGui:Close()
            end
        end
    end)
end

---@return ViewComponent
function ViewBase:GetComponent(path)
    return self:Get(path)
end

---@return ViewItem
function ViewBase:GetItem(path)
    local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
    return self:Get(path, ViewItem)
end

---@return ViewToggle
function ViewBase:GetToggle(path)
    local ViewToggle = require(MainStorage.code.client.ui.ViewToggle) ---@type ViewToggle
    return self:Get(path, ViewToggle)
end

---@return ViewList
function ViewBase:GetList(path, onAddElementCb)
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    return self:Get(path, ViewList, onAddElementCb)
end

---@return ViewButton
function ViewBase:GetButton(path)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    return self:Get(path, ViewButton)
end

---@generic T : ViewComponent
---@param path string 组件路径
---@param type? T 组件类型
---@param ... any 额外参数
---@return T
function ViewBase:Get(path, type, ...)
    local cacheKey = path
    if self.componentCache[cacheKey] then
        return self.componentCache[cacheKey]
    end
    local node = self.node
    local fullPath = ""
    local lastPart = ""
    for part in path:gmatch("[^/]+") do -- 用/分割字符串
        if part ~= "" then
            lastPart = part
            if not node then
                gg.log(string.format("UI[%s]获取路径[%s]失败: 在[%s]处节点不存在", self.className, path,
                    fullPath))
                return nil
            end
            node = node[part]
            if fullPath == "" then
                fullPath = part
            else
                fullPath = fullPath .. "/" .. part
            end
        end
    end
    if not node then
        gg.log(string.format("UI[%s]获取路径[%s]失败: 最终节点[%s]不存在", self.className, path, lastPart))
        return nil
    end

    if not type then
        local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
        type = ViewComponent
    end
    ---@cast type ViewComponent
    local component = type.New(node, self, fullPath, ...)

    -- Cache the component
    self.componentCache[cacheKey] = component
    return component
end

---@param node SandboxNode
---@param config ViewConfig
function ViewBase:OnInit(node, config)
    self.openCb = nil
    self.closeCb = nil
    self.componentCache = {}
    self.node = node ---@type SandboxNode
    self.openSound = self.node:GetAttribute("打开音效")
    self.closeSound = self.node:GetAttribute("关闭音效")
    self.bgmMusic = self.node:GetAttribute("背景音乐")
    self.hideOnInit = config.hideOnInit == nil and true or config.hideOnInit
    self.layer = config.layer == nil and 1 or config.layer
    self.closeHuds = config.closeHuds
    self.mouseVisible = config.mouseVisible or self.layer > 0
    self.closeHideMouse = config.closeHideMouse
    if self.closeHideMouse == nil then
        self.closeHideMouse = self.mouseVisible
    end
    if self.closeHuds == nil then
        self.closeHuds = self.layer >= 1
    end
    self.displaying = false
    self.isOnTop = false
    ViewBase.allUI[self.className] = self
    ViewBase[self.className] = self
    
    -- 在第一个UI初始化时启动红点系统
    ViewBase.InitNewsSystem()

    if self.hideOnInit then
        self:SetVisible(false)
        self.displaying = false
    else
        self:SetVisible(true)
        self.displaying = true
    end
end

---@return Vector2
function ViewBase.GetScreenSize()
    local evt = {}
    ClientEventManager.Publish("GetScreenSize", evt)
    return evt.size
end

function ViewBase:SetVisible(visible)
    self.node.Enabled = visible
    self.node.Visible = visible
end

function ViewBase:Close()
    self:SetVisible(false)
    if not self.displaying then
        return
    end
    if self.bgmMusic and self.bgmMusic ~= "" then
        ClientEventManager.Publish("PlaySound", {
            close = true,
            key = "bgm",
            layer = self.layer + 5,
        })
    end
    if self.closeSound then
        ClientEventManager.Publish("PlaySound", {
            soundAssetId = self.closeSound
        })
    end
    if self.closeHideMouse then
        -- 只有没有任何layer>=1的界面显示时才隐藏鼠标
        local hasOtherLayerUI = false
        for _, ui in pairs(ViewBase.allUI) do
            if ui ~= self and ui.layer and ui.layer > 0 and ui.displaying then
                hasOtherLayerUI = true
                break
            end
        end
        if not hasOtherLayerUI then
            ViewBase.LockMouseVisible(false)
        end
    end
    if displayingUI[self.layer] == self then
        displayingUI[self.layer] = nil
    end
    if self.isOnTop then
        local maxLayer = 1
        for layer, _ in pairs(displayingUI) do
            if layer > maxLayer then
                maxLayer = layer
            end
        end
        if displayingUI[maxLayer] then
            local topUI = displayingUI[maxLayer]
            topUI:SetVisible(true)
            topUI.isOnTop = true
            ViewBase.topGui = topUI
        else
            ViewBase.topGui = nil
        end
    end
    self.displaying = false
    if self.closeHuds then
        for _, ui in ipairs(hiddenHuds) do
            if ui and ui.displaying then
                ui:SetVisible(true)
            end
        end
        hiddenHuds = {}
    end
    if self.closeCb then
        self.closeCb()
    end
end

function ViewBase:Open()
    if self.displaying then
        return
    end
    self.displaying = true
    self:SetVisible(true)
    if self.bgmMusic ~= "" then
        ClientEventManager.Publish("PlaySound", {
            soundAssetId = self.bgmMusic,
            key = "bgm",
            layer = self.layer + 5,
            volume = 0.2
        })
    end
    ClientEventManager.Publish("PlaySound", {
        soundAssetId = self.openSound
    })
    if self.mouseVisible then
        ViewBase.LockMouseVisible(true)
    end
    if self.layer > 0 then
        if displayingUI[self.layer] then
            local oldUI = displayingUI[self.layer]
            if oldUI ~= self then
                oldUI.isOnTop = false
                oldUI:Close()
            end
        end
        self.isOnTop = true
        for i = 1, self.layer do
            if displayingUI[i] then
                displayingUI[i].isOnTop = false
                displayingUI[i].node.Enabled = false
            end
        end
        displayingUI[self.layer] = self
        self.isOnTop = true
        -- 更新 topGui
        if not ViewBase.topGui or self.layer > ViewBase.topGui.layer then
            ViewBase.topGui = self
        end
    end
    if self.closeHuds then
        -- 隐藏所有正在显示的layer=0界面
        for _, ui in pairs(ViewBase.allUI) do
            if ui.layer == 0 and ui.displaying and ui ~= self then
                ui:SetVisible(false)
                table.insert(hiddenHuds, ui)
            end
        end
    end
    if self.openCb then
        self.openCb()
    end
end

function ViewBase:OnHide()

end

---@param component ViewComponent
function ViewBase:DestroyComponent(component)
    -- Find and remove the component from the cache
    for path, cachedComponent in pairs(self.componentCache) do
        if cachedComponent == component then
            self.componentCache[path] = nil
            break
        end
    end
    
    -- Destroy the component's node
    if component.node then
        component.node:Destroy()
    end
end

return ViewBase
