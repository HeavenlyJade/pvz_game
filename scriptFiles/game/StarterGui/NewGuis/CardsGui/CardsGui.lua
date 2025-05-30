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
    qualityList = {"UR", "SSR", "SR", "R", "N"},
    qualityListMap = {["品质_5"]="N", ["品质_4"]="R", ["品质_3"]="SR", ["品质_2"]="SSR", ["品质_1"]="UR"},
    mianCard ="主卡",
    Subcard = "副卡"
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
            self:SwitchToCardType("主卡")
        end
    else
    end
    -- 副卡按钮点击事件
    if self.subCardButton then
        self.subCardButton:SetTouchEnable(true)
        self.subCardButton.clickCb = function(ui, button)
            self:SwitchToCardType("副卡")
        end
    else
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
    self.skillButtons = {} ---@type table<string, ViewButton> -- 主卡按钮框
    self.skillLists = {} ---@type table<string, ViewList>     -- 主卡技能树列表
    self.subQualityLists ={} ---@type table<string, ViewList> -- 副卡品级列表
    self.qualityListMap = {} ---@type table<string, string> -- 构建反射的品质按钮名->品质名字典
    self.qualityLists = {} ---@type table<string, ViewList> -- 品质列表
    -- 初始化技能数据
    self.skills = {} ---@type table<string, Skill>
    self.equippedSkills = {} ---@type table<number, string>

    -- 当前显示的卡片类型 ("主卡" 或 "副卡")
    self.currentCardType = "主卡"
    -- 注册按钮事件
    self:RegisterMenuButton(self.closeButton)
    self:RegisterCardButtons()
    -- 设置默认显示主卡
    self:SwitchToCardType(self.currentCardType)
    -- 读取主卡数据并克隆节点
    self:LoadMainCardsAndClone()
    self:LoadSubCardsAndClone()
    self:BindQualityButtonEvents()
    ClientEventManager.Subscribe("SyncPlayerSkills", function(data)
        self:HandleSkillSync(data)
    end)

end

-- 处理技能同步数据
function CardsGui:HandleSkillSync(data)
    -- gg.log("CardsGui:HandleSkillSync", data)
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
    self.currentCardType = cardType
    self:UpdateCardDisplay(cardType)
end

-- 更新指定卡片类型的显示
function CardsGui:UpdateCardDisplay(cardType)
    -- gg.log("更新卡片显示:", cardType)

    -- 显示/隐藏对应的卡片组件
    if self.mainCardComponent then
        local showMain = (cardType == "主卡")
        self.mainCardComponent:SetVisible(showMain)
        -- gg.log("主卡组件显示状态:", showMain)
    end

    if self.subCardComponent then
        local showSub = (cardType == "副卡")
        self.subCardComponent:SetVisible(showSub)
        -- gg.log("副卡组件显示状态:", showSub)
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
    local datat =SkillTypeConfig.BuildSkillForest(0)
    gg.log("datat", datat)


    -- 使用美化的打印函数显示技能树结构
    SkillTypeConfig.PrintSkillForest(datat)

    -- 克隆纵列表
    self:CloneVerticalListsForSkillTrees(skillMainTrees)

    -- 克隆主卡选择按钮
    self:CloneMainCardButtons(skillMainTrees)

end

-- 克隆主卡选择按钮
function CardsGui:CloneMainCardButtons(skillMainTrees)
    local qualityList = uiConfig.qualityList or {"UR", "SSR", "SR", "R", "N"}
    local qualityListMap = uiConfig.qualityListMap or {}


    local ListTemplate = self:Get('框体/主卡/选择列表/列表', ViewList) ---@type ViewList
    -- 克隆品质列表
    for _, quality in ipairs(qualityList) do
        local listClone = ListTemplate.node:Clone()
        local qualityName = "列表_" .. quality
        listClone.Name = qualityName
        listClone.Parent = ListTemplate.node.Parent
        listClone.Visible = false         -- 默认不可见
        local viewListObj = ViewList.New(listClone, self, "框体/主卡/选择列表/" .. qualityName)
        self.qualityLists[quality] = viewListObj

        listClone['主卡_1']:Destroy()
    end


    local templateNodeRef = self:Get('框体/主卡/选择列表/列表/主卡_1', ViewButton)

        -- 遍历主卡，按品质分组
    for mainSkillName, skillTree in pairs(skillMainTrees) do
        local skillType = skillTree.mainSkill
        local quality = skillType.quality or "N"
        local listNode = self.qualityLists[quality]
        if listNode and templateNodeRef then
            local clonedNode = templateNodeRef.node:Clone()
            local skillName = "技能" .. skillType.name
            clonedNode.Name = skillName
            clonedNode.Parent = listNode.node
            clonedNode.Visible = true      -- 技能节点默认可见

            -- 设置图标
            if skillType.icon and skillType.icon ~= "" then
                local iconNode = clonedNode['图标']
                if iconNode then
                    iconNode.Icon = skillType.icon
                end
            end
            -- 包装成ViewButton
            local clonedButton = ViewButton.New(clonedNode, self, "框体/主卡/选择列表/列表/" .. skillName)
            self.skillButtons[skillName] = clonedButton
            clonedButton.clickCb = function(ui, button)
                local rawName = button.node.Name
                local mainSkillName = rawName:gsub("^技能", "")
                local verticalKey = "纵" .. mainSkillName
                local currentList = self.skillLists[verticalKey]
                if currentList then
                    local isVisible = currentList.node.Visible
                    if isVisible then
                        currentList:SetVisible(false)
                    else
                        for name, vlist in pairs(self.skillLists) do
                            vlist:SetVisible(name == verticalKey)
                        end
                    end
                end
            end
        end
    end

    -- 销毁列表模板
    ListTemplate.node:Destroy()
end


-- 为技能树克隆纵列表
function CardsGui:CloneVerticalListsForSkillTrees(skillMainTrees)
    -- gg.log("开始为技能树克隆纵列表...")

    -- 获取纵列表模板节点
    local verticalListTemplate = self:Get("框体/主卡/加点框/纵列表", ViewList) ---@type ViewList
    if not verticalListTemplate or not verticalListTemplate.node then
        -- gg.log("错误：找不到纵列表模板节点")
        return
    end

    -- 为每个主卡技能克隆纵列表
    for mainSkillName, skillTree in pairs(skillMainTrees) do
        -- gg.log("为主卡克隆纵列表:", mainSkillName)

        -- 克隆纵列表节点
        local clonedVerticalList = verticalListTemplate.node:Clone()
        if clonedVerticalList then
            -- 设置克隆节点的名称：纵+主卡技能名字
            local newListName = "纵" .. mainSkillName
            clonedVerticalList.Name = newListName

            -- 设置克隆节点的父容器（与原纵列表同级）
            clonedVerticalList.Parent = verticalListTemplate.node.Parent

            -- 初始隐藏克隆的纵列表
            clonedVerticalList.Visible = false

            -- 1. 修改主卡框的图片资源为主卡的资源
            local mainCardFrame = clonedVerticalList:FindFirstChild("主卡框")
            if mainCardFrame and skillTree.mainSkill.icon and skillTree.mainSkill.icon ~= "" then
                -- 查找主卡框下的图标节点
                local iconNode = mainCardFrame:FindFirstChild("图标")
                if iconNode then
                    iconNode.Icon = skillTree.mainSkill.icon
                    -- gg.log("设置主卡框图标:", skillTree.mainSkill.icon)
                else
                    -- gg.log("警告：找不到主卡框的图标节点")
                end
            end

            -- 2. 根据二级分支数量克隆对应的列表_1,2,3
            local branchSkills = skillTree.branches
            -- gg.log("分支技能数量:", #branchSkills)

            -- 获取原始的列表模板（列表_1, 列表_2, 列表_3）
            local originalLists = {}
            for i = 1, 3 do
                local listName = "列表_" .. i
                local originalList = clonedVerticalList:FindFirstChild(listName)
                if originalList then
                    originalLists[i] = originalList
                    -- gg.log("找到原始列表:", listName)
                end
            end

            -- 为每个分支技能克隆对应的列表
            for i, branchSkill in ipairs(branchSkills) do
                if i <= 3 and originalLists[i] then -- 最多支持3个分支
                    local clonedList = originalLists[i]:Clone()
                    if clonedList then
                        -- 设置列表名字为分支名字
                        clonedList.Name = branchSkill.name
                        clonedList.Parent = clonedVerticalList

                        -- gg.log("克隆分支列表:", branchSkill.name, "从模板:", "列表_" .. i)

                        -- 克隆分支技能的卡框
                        self:CloneBranchSkillCards(clonedList, branchSkill)

                    else
                        -- gg.log("克隆分支列表失败:", branchSkill.name)
                    end
                end
            end

            -- 销毁原来的列表模板
            for i = 1, 3 do
                if originalLists[i] then
                    originalLists[i]:Destroy()
                    -- gg.log("销毁原始列表模板:", "列表_" .. i)
                end
            end

            -- 等待一帧确保节点完全初始化
            wait(0.01)

            -- 将克隆节点包装成ViewComponent对象

            -- 将克隆的各个组件进行类的实例化
            local clonedComponents = {}

            -- 实例化主卡框
            local mainCardFramePath = "框体/主卡/加点框/" .. newListName .. "/主卡框"
            clonedComponents.mainCardFrame = ViewButton.New(clonedVerticalList:FindFirstChild("主卡框"), self, mainCardFramePath)
            -- gg.log("实例化主卡框:", mainCardFramePath)

            -- 实例化分支列表组件
            clonedComponents.branchLists = {}
            for i, branchSkill in ipairs(branchSkills) do
                if i <= 3 then
                    local branchListNode = clonedVerticalList:FindFirstChild(branchSkill.name)
                    if branchListNode then
                        local branchListPath = "框体/主卡/加点框/" .. newListName .. "/" .. branchSkill.name
                        clonedComponents.branchLists[branchSkill.name] = ViewList.New(branchListNode, self, branchListPath)
                        -- gg.log("实例化分支列表:", branchListPath)
                    end
                end
            end

            -- gg.log("成功克隆纵列表:", newListName, "用于主卡:", mainSkillName)
            -- gg.log("  - 分支技能数量:", #skillTree.branches)

            -- 为这个纵列表设置分支技能
            self:SetupBranchSkillsForVerticalList(clonedVerticalList, skillTree.branches, mainSkillName)
            local verticalListTemplate = self:Get("框体/主卡/加点框/"..newListName, ViewList) ---@type ViewList
            self.skillLists[newListName] = verticalListTemplate

        else
            -- gg.log("克隆纵列表失败:", mainSkillName)
        end
    end

    -- 延迟销毁模板节点，确保所有ViewComponent初始化完成
    gg.thread_call(function()
        wait(0.1) -- 等待一帧确保所有ViewComponent都初始化完成
        if verticalListTemplate and verticalListTemplate.node then
            verticalListTemplate.node:Destroy()
            -- gg.log("纵列表模板节点已销毁")
        end
    end)

    -- gg.log("纵列表克隆完成")
end

-- 为纵列表设置分支技能
function CardsGui:SetupBranchSkillsForVerticalList(verticalListNode, branchSkills, mainSkillName)
    -- gg.log("为纵列表设置分支技能:", mainSkillName, "分支数量:", #branchSkills)

    -- 在这里可以设置每个分支技能对应的UI元素
    -- 比如克隆卡框、设置技能图标和信息等

    for i, branchSkill in ipairs(branchSkills) do
        -- gg.log("  - 设置分支技能", i, ":", branchSkill.name)

        -- 这里可以根据需要克隆和设置分支技能的UI
        -- 例如：
        -- 1. 克隆卡框
        -- 2. 设置技能图标
        -- 3. 设置技能描述
        -- 4. 绑定点击事件
    end
end

-- 克隆分支技能的卡框
function CardsGui:CloneBranchSkillCards(branchListNode, branchSkill)
    -- gg.log("开始克隆分支技能卡框:", branchSkill.name)

    -- 获取卡框模板（假设第一个卡框作为模板）
    local cardTemplate = nil
    for _, child in ipairs(branchListNode.Children) do
        if child.Name:find("卡框") then
            cardTemplate = child
            break
        end
    end

    if not cardTemplate then
        -- gg.log("警告：找不到卡框模板在分支列表:", branchSkill.name)
        return
    end

    -- 1. 首先为二级节点本身克隆卡框（如射速1_豌豆、攻击1_豌豆、生命1_豌豆）
    local branchCard = cardTemplate:Clone()
    if branchCard then
        branchCard.Name = branchSkill.name
        branchCard.Parent = branchListNode

        -- 设置二级节点的卡框资源
        if branchSkill.icon and branchSkill.icon ~= "" then
            local iconNode = branchCard:FindFirstChild("图标")
            if iconNode then
                iconNode.Icon = branchSkill.icon
                -- gg.log("设置二级节点卡框图标:", branchSkill.name, "图标:", branchSkill.icon)
            end
        end

        -- 判断是否为最后节点（没有下一级技能）
        local isLastNode = not branchSkill.nextSkills or #branchSkill.nextSkills == 0
        if isLastNode then
            local arrowNode = branchCard:FindFirstChild("箭头右")
            if arrowNode then
                arrowNode.Visible = false
                -- gg.log("隐藏箭头右，分支节点为最后节点:", branchSkill.name)
            end
        end

        -- gg.log("成功克隆二级节点卡框:", branchSkill.name)
    else
        -- gg.log("克隆二级节点卡框失败:", branchSkill.name)
    end

    -- 2. 然后为三级节点（下一级技能）克隆卡框
    local nextSkills = branchSkill.nextSkills or {}
    -- gg.log("分支技能", branchSkill.name, "的下级技能数量:", #nextSkills)

    -- 为每个下级技能克隆卡框
    for i, nextSkill in ipairs(nextSkills) do
        local clonedCard = cardTemplate:Clone()
        if clonedCard then
            -- 设置名字为三级节点的名字
            clonedCard.Name = nextSkill.name
            clonedCard.Parent = branchListNode

            -- 设置对应三级节点的卡框资源
            if nextSkill.icon and nextSkill.icon ~= "" then
                -- 查找卡框下的图标节点
                local iconNode = clonedCard:FindFirstChild("图标")
                if iconNode then
                    iconNode.Icon = nextSkill.icon
                    -- gg.log("设置三级节点卡框图标:", nextSkill.name, "图标:", nextSkill.icon)
                else
                    -- gg.log("警告：找不到三级节点卡框的图标节点:", nextSkill.name)
                end
            end

            -- gg.log("成功克隆三级节点卡框:", nextSkill.name)
        else
            -- gg.log("克隆三级节点卡框失败:", nextSkill.name)
        end
    end

    -- 销毁初始卡框模板
    if cardTemplate then
        cardTemplate:Destroy()
        -- gg.log("销毁分支技能卡框模板:", branchSkill.name)
    end
end

-- 动态生成副卡列表
function CardsGui:LoadSubCardsAndClone()
    local qualityList = uiConfig.qualityList or {"UR", "SSR", "SR", "R", "N"}
    local subListTemplate = self:Get('框体/副卡/副卡列/副卡列表', ViewList) ---@type ViewList

    local allSkills = SkillTypeConfig.GetAll()
    local subSkillsByQuality = {}
    for _, quality in ipairs(qualityList) do
        subSkillsByQuality[quality] = {}
    end

    -- 分类统计
    for name, skill in pairs(allSkills) do
        if skill.skillType == 1 and skill.isEntrySkill then
            local quality = skill.quality or "N"
            if subSkillsByQuality[quality] then
                table.insert(subSkillsByQuality[quality], skill)
            end
        end
    end

    -- 克隆副卡品级列表
    for _, quality in ipairs(qualityList) do
        local listClone = subListTemplate.node:Clone()
        local qualityName = "副卡列表_" .. quality
        listClone.Name = qualityName
        listClone.Parent = subListTemplate.node.Parent
        listClone.Visible = false

        -- 设置LineCount为该品质副卡数量
        local count = #subSkillsByQuality[quality]
        listClone.LineCount = count > 0 and count or 1

        self.subQualityLists[quality] = ViewList.New(listClone, self, "框体/副卡/副卡列/" .. qualityName)
        -- 清空模板下的副卡槽
        for _, child in ipairs(listClone.Children) do
            if string.find(child.Name, "副卡槽") then
                child:Destroy()
            end
        end
    end

    local subCardTemplate = self:Get('框体/副卡/副卡列/副卡列表/副卡槽_1', ViewButton) ---@type ViewButton
    if not subCardTemplate or not subCardTemplate.node then return end
    -- 遍历副卡数据，按品级分组
    local allSkills = SkillTypeConfig.GetAll()
    for name, skill in pairs(allSkills) do
        if skill.skillType == 1 and skill.isEntrySkill then
            local quality = skill.quality
            local listNode = self.subQualityLists[quality]
            if listNode then

                local clonedNode = subCardTemplate.node:Clone()
                clonedNode.Name = skill.name
                clonedNode.Parent = listNode.node
                clonedNode.Visible = true
                -- 设置副卡名字和图标
                local nameNode = clonedNode["副卡名字"]
                if nameNode then nameNode.Title = skill.name end
                local iconNode = clonedNode["图标"]
                if iconNode and skill.icon and skill.icon ~= "" then
                    iconNode.Icon = skill.icon
                end
            end
        end
    end


    subListTemplate.node:Destroy()
    print("副卡全部生成完毕，模板已销毁")
end

function CardsGui:BindQualityButtonEvents()
    local qualityListMap = uiConfig.qualityListMap or {}
    for btnName, quality in pairs(qualityListMap) do
        local qualityBtn = self:Get("品质列表/"  .. btnName, ViewButton)
        if qualityBtn then
            qualityBtn.clickCb = function()
                if self.currentCardType == "主卡" or self.currentCardType == "main" then
                    -- 主卡品级列表显示
                    for q, listNode in pairs(self.qualityLists) do
                        listNode:SetVisible(q == quality)
                    end
                    -- 隐藏所有加点框下的纵列表
                    for _, vlist in pairs(self.skillLists) do
                        vlist:SetVisible(false)
                    end
                elseif self.currentCardType == "副卡" or self.currentCardType == "sub" then
                    -- 副卡品级列表显示
                    if self.subQualityLists then
                        for q, listNode in pairs(self.subQualityLists) do
                            listNode:SetVisible(q == quality)
                        end
                    end
                end
            end
        end
    end
end

return CardsGui.New(script.Parent, uiConfig)

