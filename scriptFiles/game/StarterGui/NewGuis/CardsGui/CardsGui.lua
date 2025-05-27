local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent
local SkillTypeConfig = require(MainStorage.code.common.config.SkillTypeConfig) ---@type SkillTypeConfig
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg

local uiConfig = {
    uiName = "CardsGui",
    layer = 3,
    hideOnInit = true,
}

---@class CardsGui:ViewBase
local CardsGui = ClassMgr.Class("CardsGui", ViewBase)

---@param viewButton ViewButton
function CardsGui:RegisterMenuButton(viewButton)
    if not viewButton then return end
    viewButton:SetTouchEnable(true)
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        if button.node.Name == "关闭" then
            self:Close()
        end
        -- 发送菜单点击事件到服务器
        -- gg.network_channel:FireServer({
        --     cmd = "MenuClicked",
        --     buttonName = button.node.Name
        -- })
          end
end

-- 注册主卡/副卡按钮事件
function CardsGui:RegisterCardButtons()
    -- 主卡按钮点击事件
    if self.mainCardButton then
        self.mainCardButton:SetTouchEnable(true)
        self.mainCardButton.clickCb = function(ui, button)
            self:SwitchToCardType("main")
        end
        gg.log("主卡按钮事件已注册")
    else
        gg.log("警告：找不到主卡按钮")
    end
    
    -- 副卡按钮点击事件
    if self.subCardButton then
        self.subCardButton:SetTouchEnable(true)
        self.subCardButton.clickCb = function(ui, button)
            self:SwitchToCardType("sub")
        end
        gg.log("副卡按钮事件已注册")
    else
        gg.log("警告：找不到副卡按钮")
    end
end

---@override
function CardsGui:OnInit(node, config)
    ViewBase.OnInit(self, node, config)
    self.qualityList = self:Get("品质列表", ViewList) ---@type ViewList
    self.mainCardButton = self:Get("框体/标题/卡片/主卡", ViewButton) ---@type ViewButton
    self.subCardButton = self:Get("框体/标题/卡片/副卡", ViewButton) ---@type ViewButton
    self.closeButton = self:Get("框体/关闭", ViewButton) ---@type ViewButton
    self.attributeButton = self:Get("框体/属性", ViewButton) ---@type ViewButton
    self.mainCardComponent = self:Get("框体/主卡", ViewComponent) ---@type ViewComponent
    self.subCardComponent = self:Get("框体/副卡", ViewComponent) ---@type ViewComponent
    
    self.confirmPointsButton = self:Get("框体/属性/主卡_研究", ViewButton) ---@type ViewButton
    self.selectionList = self:Get("框体/主卡/选择列表", ViewList) ---@type ViewList
    self.mainCardFrame = self:Get("框体/主卡/加点框/纵列表/主卡框", ViewButton) ---@type ViewButton
    self.skillButtons = {} ---@type table<number, ViewList>
    for i = 1, 3 do
        self.skillButtons[i] = self:Get("框体/主卡/加点框/纵列表/列表_" .. i, ViewList) ---@type ViewList
    end

    -- 初始化技能数据
    self.skills = {} ---@type table<string, Skill>
    self.equippedSkills = {} ---@type table<number, string>
    
    -- 当前显示的卡片类型 ("main" 或 "sub")
    self.currentCardType = "主卡"
    
    -- 注册按钮事件
    self:RegisterMenuButton(self.closeButton)
    self:RegisterCardButtons()
    -- 设置默认显示主卡
    self:SwitchToCardType(self.currentCardType)    -- 读取主卡数据并克隆节点
    self:LoadMainCardsAndClone()

    ClientEventManager.Subscribe("SyncPlayerSkills", function(data)
        self:HandleSkillSync(data)
    end)
end

-- 处理技能同步数据
function CardsGui:HandleSkillSync(data)
    gg.log("CardsGui:HandleSkillSync", data)
    if not data or not data.skillData then return end
    
    -- 清空现有技能数据
    self.skills = {}
    self.equippedSkills = {}
    
    -- 反序列化技能数据
    for skillId, skillData in pairs(data.skillData.skills) do
        -- 创建技能对象
        local Skill = require(MainStorage.code.server.spells.Skill) ---@type Skill
        local skill = Skill.New(nil, skillData)
        self.skills[skillId] = skill
        
        -- 记录已装备的技能
        if skill.equipSlot > 0 then
            self.equippedSkills[skill.equipSlot] = skillId
        end
    end
    
    -- 更新UI显示
    self:UpdateSkillDisplay()
end

-- 更新技能显示
function CardsGui:UpdateSkillDisplay()
    -- 更新技能按钮显示
    for slot, skillId in pairs(self.equippedSkills) do
        local skill = self.skills[skillId]
        if skill and self.skillButtons[slot] then
            -- 更新技能按钮显示
            self.skillButtons[slot].Title = skill.skillType.name
            -- 可以添加更多UI更新逻辑
        end
    end
end

function CardsGui:Display(title, content, confirmCallback, cancelCallback)
    self.qualityList.Title = title
    self.mainCardButton.Title = content
    self.confirmCallback = confirmCallback
    self.cancelCallback = cancelCallback
end

-- ========== 卡片切换功能 ==========

-- 切换到指定的卡片类型
function CardsGui:SwitchToCardType(cardType)
    if self.currentCardType == cardType then
        gg.log("已经在", cardType, "页面，无需切换")
        return
    end
    
    local oldCardType = self.currentCardType
    self.currentCardType = cardType
    gg.log("切换卡片类型:", oldCardType, "->", cardType)
    
    -- 更新显示
    self:UpdateCardDisplay(cardType)
    
    -- 更新按钮状态
    self:UpdateCardButtonStates()
end

-- 更新指定卡片类型的显示
function CardsGui:UpdateCardDisplay(cardType)
    gg.log("更新卡片显示:", cardType)
    
    -- 显示/隐藏对应的卡片组件
    if self.mainCardComponent then
        local showMain = (cardType == "main")
        self.mainCardComponent:SetVisible(showMain)
        gg.log("主卡组件显示状态:", showMain)
    end
    
    if self.subCardComponent then
        local showSub = (cardType == "sub")
        self.subCardComponent:SetVisible(showSub)
        gg.log("副卡组件显示状态:", showSub)
    end
end

-- 更新卡片按钮状态（选中/未选中）
function CardsGui:UpdateCardButtonStates()
    -- 更新主卡按钮状态
    if self.mainCardButton then
        local isSelected = self.currentCardType == "main"
        -- 这里可以设置按钮的选中状态样式
        -- 例如改变颜色、边框等
        gg.log("主卡按钮状态:", isSelected and "选中" or "未选中")
    end
    -- 更新副卡按钮状态
    if self.subCardButton then
        local isSelected = self.currentCardType == "sub"
        gg.log("副卡按钮状态:", isSelected and "选中" or "未选中")
        

    end
end

-- 获取当前卡片类型
function CardsGui:GetCurrentCardType()
    return self.currentCardType
end

-- 读取主卡数据并克隆节点
function CardsGui:LoadMainCardsAndClone()
    gg.log("开始读取主卡数据并克隆节点...")
    local skillMainTrees = SkillTypeConfig.GetSkillTrees(0)
    gg.log("skillMainTrees", skillMainTrees)
    -- 获取所有技能配置
    local allSkills = SkillTypeConfig.GetAll()
    local mainCards = {} ---@type SkillType[]
    -- 筛选：技能分类为0且是入口技能为true的主卡
    for skillName, skillType in pairs(allSkills) do
        -- 使用skillType对象的属性来检查
        if skillType.skillType == 0 and skillType.isEntrySkill == true then
            table.insert(mainCards, skillType)
            gg.log("找到主卡:", skillType.name, "描述:", skillType.description)
            gg.log("  - 最大等级:", skillType.maxLevel)
            gg.log("  - 是入口技能:", skillType.isEntrySkill)
            gg.log("  - 目标模式:", skillType.targetMode)
            if skillType.activeSpell then
                gg.log("  - 主动技能:", skillType.activeSpell.name)
                gg.log("  - 冷却时间:", skillType.cooldown)
            end
        end
    end
    
    gg.log("共找到", #mainCards, "个主卡")

    local templateNode  = self:Get('框体/主卡/选择列表/列表/主卡_1', ViewButton) ---@type ViewButton
    if not templateNode or not templateNode.node then
        gg.log("错误：找不到主卡_1模板节点")
        return
    end
    
    -- 存储克隆的ViewButton对象
    self.clonedMainCardButtons = {}
    -- 克隆每个主卡
    for i, skillType in ipairs(mainCards) do
        local clonedNode = templateNode.node:Clone()
        if clonedNode then
            -- 更新克隆节点的名称，使用skillType的name属性
            clonedNode.Name = skillType.name
            
            -- 确保克隆节点具有基本的图标属性和必要的Attribute            
            -- 安全设置图标
            if skillType.icon and skillType.icon ~= "" then
                gg.log("skillType.icon:资源加载的日志", skillType.icon)
                local iconNode = clonedNode['图标']
                if iconNode then
                    iconNode.Icon = skillType.icon
                else
                    gg.log("警告：找不到图标子节点")
                end
            end
            
            -- 设置克隆节点的父容器
            clonedNode.Parent = templateNode.node.Parent
            
            -- 等待一帧确保节点完全初始化
            wait(0.01)
            
            -- 将克隆节点包装成ViewButton对象，使用简化的路径
            local clonedButton = ViewButton.New(clonedNode, self, "框体/主卡/选择列表/列表/" .. skillType.name)
            -- 设置按钮点击事件
            clonedButton:SetTouchEnable(true)
            clonedButton:SetVisible(true)
            clonedButton.clickCb = function(ui, button)
                self:OnMainCardClicked(skillType, button)
            end
            
            -- 存储克隆的按钮对象和对应的技能数据
            self.clonedMainCardButtons[skillType.name] = {
                button = clonedButton,
                skillType = skillType,
                node = clonedNode
            }
            
            gg.log("成功克隆主卡ViewButton:", skillType.name, "节点名:", clonedNode.Name)
        else
            gg.log("克隆失败:", skillType.name)
        end
    end
    
    -- 延迟销毁模板节点，确保所有ViewButton初始化完成
    gg.thread_call(function()
        wait(0.1) -- 等待一帧确保所有ViewButton都初始化完成
        if templateNode and templateNode.node then
            templateNode.node:Destroy()
            gg.log("模板节点已销毁")
        end
    end)
    
    gg.log("主卡克隆完成")
end

-- 处理主卡点击事件
function CardsGui:OnMainCardClicked(skillType, button)
    gg.log("主卡被点击:", skillType.name)
    gg.log("  - 技能描述:", skillType.description)
    gg.log("  - 最大等级:", skillType.maxLevel)
    gg.log("  - 目标模式:", skillType.targetMode)
    
    -- 这里可以添加点击后的逻辑
    -- 比如显示技能详情、装备技能等
    
    -- 示例：更新某个UI显示选中的技能信息

    -- 可以发送网络事件到服务器
    -- gg.network_channel:FireServer({
    --     cmd = "SelectMainCard",
    --     skillName = skillType.name
    -- })
end

-- 获取所有克隆的主卡按钮
function CardsGui:GetClonedMainCardButtons()
    return self.clonedMainCardButtons or {}
end

-- 根据技能名获取克隆的主卡按钮
function CardsGui:GetClonedMainCardButton(skillName)
    if self.clonedMainCardButtons and self.clonedMainCardButtons[skillName] then
        return self.clonedMainCardButtons[skillName]
    end
    return nil
end

return CardsGui.New(script.Parent, uiConfig)