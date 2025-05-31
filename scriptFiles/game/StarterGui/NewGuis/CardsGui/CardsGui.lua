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
    self.attributeButton = self:Get("框体/属性", ViewComponent) ---@type ViewComponent
    self.mainCardComponent = self:Get("框体/主卡", ViewComponent) ---@type ViewComponent
    self.subCardComponent = self:Get("框体/副卡", ViewComponent) ---@type ViewComponent

    self.confirmPointsButton = self:Get("框体/属性/主卡_研究", ViewButton) ---@type ViewButton
    self.selectionList = self:Get("框体/主卡/选择列表", ViewList) ---@type ViewList
    self.mainCardFrame = self:Get("框体/主卡/加点框/纵列表/主卡框", ViewButton) ---@type ViewButton
    self.skillButtons = {} ---@type table<string, ViewButton> -- 主卡按钮框
    self.skillLists = {} ---@type table<string, ViewList>     -- 主卡技能树列表
    self.subQualityLists ={} ---@type table<string, ViewList> -- 副卡品级列表
    self.qualityListMap = {} ---@type table<string, string> -- 构建反射的品质按钮名->品质名字典
    -- 初始化技能数据
    self.skills = {} ---@type table<string, Skill>
    self.equippedSkills = {} ---@type table<number, string>

    -- 当前显示的卡片类型 ("主卡" 或 "副卡")
    self.currentCardType = "主卡"
    self.closeButton.clickCb = function ()
        self:Close()
    end
    self:RegisterCardButtons()
    -- 设置默认显示主卡
    self:SwitchToCardType(self.currentCardType)
    self:LoadMainCardsAndClone()
    -- self:LoadSubCardsAndClone()
    -- self:BindQualityButtonEvents()
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
    
    -- 根据卡片类型显示/隐藏品质列表
    if self.qualityList then
        self.qualityList:SetVisible(cardType == "副卡")
    end
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
    local skillMainTrees = SkillTypeConfig.GetSkillTrees(0)
    -- 使用美化的打印函数显示技能树结构
    SkillTypeConfig.PrintSkillTrees(skillMainTrees)
    -- 克隆纵列表
    self:CloneVerticalListsForSkillTrees(skillMainTrees)
    -- 克隆主卡选择按钮
    self:CloneMainCardButtons(skillMainTrees)
end

function CardsGui:CloneMainCardButtons(skillMainTrees)
    local ListTemplate = self:Get('框体/主卡/选择列表/列表', ViewList, function(child)
        --由于不希望"发光"相应点击,真正的按钮是 按钮/卡框背景
        local clonedButton = ViewButton.New(child, self, nil, "卡框背景")
        self.skillButtons[child.Name] = clonedButton
        clonedButton.clickCb = function(ui, button)
            local mainSkillName = button.extraParams["skillId"]
            local currentList = self.skillLists[mainSkillName]
            if currentList then
                for name, vlist in pairs(self.skillLists) do
                    vlist:SetVisible(name == mainSkillName)
                end
            end
        end
        return clonedButton
    end) ---@type ViewList
    -- 遍历主卡，设置图标和名称
    local index = 1
    for mainSkillName, skillTree in pairs(skillMainTrees) do
        local skillType = skillTree.mainSkill
        local child = ListTemplate:GetChild(index)
        child.extraParams["skillId"] = skillType.name
        
        if skillType.icon and skillType.icon ~= "" then
            local iconNode = child.node['图标']
            if iconNode then
                iconNode.Icon = skillType.icon
            end
        end
        index = index + 1
    end
    ListTemplate:HideChildrenFrom(index)
end

-- 注册技能卡片的ViewButton
function CardsGui:RegisterSkillCardButton(cardFrame, skill, lane, position)
    local viewButton = ViewButton.New(cardFrame, self, nil, "卡框背景")
    viewButton.extraParams = {
        skillId = skill.name,
        lane = lane,
        position = position
    }
    viewButton.clickCb = function(ui, button)
        local skillId = button.extraParams.skillId
        local skill = SkillTypeConfig.Get(skillId)
        local skillInst = self.skills[skillId]
        local skillLevel = 0
        if skillInst then
            skillLevel = skillInst.level
        end
        local nameNode = self.attributeButton.node["卡片名字"]
        if nameNode then
            nameNode.Title = skill.displayName
        end
        -- 更新技能描述
        local descNode = self.attributeButton.node["卡片介绍"]
        if descNode then
            descNode.Title = skill.description
        end
        local descPreTitleNode = self.attributeButton.node["列表_强化前"]["强化标题"]
        local descPostTitleNode = self.attributeButton.node["列表_强化后"]["强化标题"]
        local descPreNode = self.attributeButton.node["列表_强化前"]["属性_1"]
        local descPostNode = self.attributeButton.node["列表_强化后"]["属性_1"]
        descPreTitleNode.Title = string.format("等级 %d/%d", skillLevel, skill.maxLevel)
        local descPre = {}
        for _, tag in pairs(skill.passiveTags) do
            table.insert(descPre, tag:GetDescription(skillLevel))
        end
        descPreNode.Title = table.concat(descPre, "\n")
        if skillLevel < skill.maxLevel then
            descPostTitleNode.Title = string.format("等级 %d/%d", skillLevel+1, skill.maxLevel)
            local descPost = {}
            for _, tag in pairs(skill.passiveTags) do
                table.insert(descPost, tag:GetDescription(skillLevel+1))
            end
            descPostNode.Title = table.concat(descPost, "\n")
        end
    end

    -- 设置图标
    if skill.icon and skill.icon ~= "" then
        local iconNode = cardFrame["卡框背景"]["图标"]
        if iconNode then
            iconNode.Icon = skill.icon
        end
    end

    -- 设置技能名称
    local nameNode = cardFrame["技能名"]
    if nameNode then
        nameNode.Title = skill.displayName
    end

    -- 设置技能等级
    local skillInst = self.skills[skill.name]
    local skillLevel = 0
    if skillInst then
        skillLevel = skillInst.level
    end
    local descNode = cardFrame["等级"]
    if descNode then
        local maxLevel = skill.maxLevel or 1
        descNode.Title = string.format("%d/%d", skillLevel, maxLevel)
    end

    return viewButton
end

-- 为技能树克隆纵列表
function CardsGui:CloneVerticalListsForSkillTrees(skillMainTrees)
    local verticalListTemplate = self:Get("框体/主卡/加点框/纵列表", ViewList) ---@type ViewList
    if not verticalListTemplate or not verticalListTemplate.node then
        return
    end

    -- 为每个主卡技能克隆纵列表
    for mainSkillName, skillTree in pairs(skillMainTrees) do
        -- 克隆纵列表节点
        local clonedVerticalList = verticalListTemplate.node:Clone()
        if clonedVerticalList then
            -- 设置克隆节点的名称：主卡技能名字
            clonedVerticalList.Name = mainSkillName
            clonedVerticalList.Parent = verticalListTemplate.node.Parent
            clonedVerticalList.Visible = false

            -- 注册主卡（第一层）的ViewButton
            local mainCardFrame = clonedVerticalList["主卡框"]
            if mainCardFrame then
                self:RegisterSkillCardButton(mainCardFrame, skillTree.mainSkill, 0, 2)
            end

            -- 获取列表_1作为模板
            local listTemplate = clonedVerticalList["列表_1"]
            if not listTemplate then return end

            -- 获取最大层级数
            local maxLane = 0
            for lane, _ in pairs(skillTree.skills) do
                maxLane = math.max(maxLane, lane)
            end

            -- 从第二层开始创建列表（第一层是入口技能）
            for lane = 1, maxLane do
                local laneSkills = skillTree:GetLane(lane)
                if #laneSkills > 0 then
                    -- 克隆列表模板
                    local clonedList = listTemplate:Clone()
                    clonedList.Name = "列表_" .. lane
                    clonedList.Parent = clonedVerticalList

                    -- 为这一层的每个技能设置卡框
                    local skillCount = #laneSkills
                    local positions = {}
                    
                    -- 根据技能数量决定位置
                    if skillCount == 1 then
                        positions = {2} -- 只有一个技能时放在2号位
                    elseif skillCount == 2 then
                        positions = {1, 3} -- 有两个技能时放在1号和3号位
                    else
                        -- 超过两个技能时按顺序排列
                        for i = 1, skillCount do
                            positions[i] = i
                        end
                    end

                    -- 隐藏所有卡框
                    for i = 1, 3 do
                        local cardFrame = clonedList["卡框_" .. i]
                        if cardFrame then
                            cardFrame.Visible = false
                        end
                    end

                    -- 设置每个技能的卡框
                    for i, skill in ipairs(laneSkills) do
                        if skill then
                            local position = positions[i]
                            if position and position <= 3 then
                                local cardFrame = clonedList["卡框_" .. position]
                                if cardFrame then
                                    cardFrame.Visible = true
                                    cardFrame.Name = skill.name

                                    -- 注册为ViewButton
                                    self:RegisterSkillCardButton(cardFrame, skill, lane, position)

                                    -- 处理箭头显示
                                    local nextSkills = skill.nextSkills or {}
                                    local nextPositions = {}
                                    
                                    -- 在下一层找到这个技能的位置
                                    local nextLaneSkills = skillTree:GetLane(lane + 1)
                                    local nextLaneCount = #nextLaneSkills
                                    local nextLanePositions = {}
                                    
                                    -- 根据下一层的技能数量决定位置
                                    if nextLaneCount == 1 then
                                        nextLanePositions = {2} -- 只有一个技能时放在2号位
                                    elseif nextLaneCount == 2 then
                                        nextLanePositions = {1, 3} -- 有两个技能时放在1号和3号位
                                    else
                                        -- 超过两个技能时按顺序排列
                                        for i = 1, nextLaneCount do
                                            nextLanePositions[i] = i
                                        end
                                    end

                                    -- 找到每个下一技能的实际位置
                                    for _, nextSkill in ipairs(nextSkills) do
                                        for nextPos, nextLaneSkill in ipairs(nextLaneSkills) do
                                            if nextLaneSkill.name == nextSkill.name then
                                                table.insert(nextPositions, nextLanePositions[nextPos])
                                                break
                                            end
                                        end
                                    end

                                    -- 根据下一技能的位置显示/隐藏箭头
                                    local upRightArrow = cardFrame["上右"]
                                    local downRightArrow = cardFrame["下右"]
                                    local rightArrow = cardFrame["箭头右"]

                                    if upRightArrow then
                                        upRightArrow.Visible = false
                                    end
                                    if downRightArrow then
                                        downRightArrow.Visible = false
                                    end
                                    if rightArrow then
                                        rightArrow.Visible = false
                                    end

                                    -- 根据当前技能位置和下一技能位置决定显示哪个箭头
                                    for k, nextPos in pairs(nextPositions) do
                                        if position == 1 then -- 当前技能在左边
                                            if nextPos == 1 then
                                                if rightArrow then rightArrow.Visible = true end
                                            elseif nextPos == 2 then
                                                if downRightArrow then downRightArrow.Visible = true end
                                            elseif nextPos == 3 then
                                                if downRightArrow then downRightArrow.Visible = true end
                                            end
                                        elseif position == 2 then -- 当前技能在中间
                                            if nextPos == 1 then
                                                if upRightArrow then upRightArrow.Visible = true end
                                            elseif nextPos == 2 then
                                                if rightArrow then rightArrow.Visible = true end
                                            elseif nextPos == 3 then
                                                if downRightArrow then downRightArrow.Visible = true end
                                            end
                                        elseif position == 3 then -- 当前技能在右边
                                            if nextPos == 1 then
                                                if upRightArrow then upRightArrow.Visible = true end
                                            elseif nextPos == 2 then
                                                if upRightArrow then upRightArrow.Visible = true end
                                            elseif nextPos == 3 then
                                                if rightArrow then rightArrow.Visible = true end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- 销毁列表模板
            listTemplate:Destroy()

            -- 将克隆节点包装成ViewList对象
            local verticalList = ViewList.New(clonedVerticalList, self, "框体/主卡/加点框/" .. mainSkillName)
            self.skillLists[mainSkillName] = verticalList
        end
    end

    -- 销毁模板节点
    if verticalListTemplate and verticalListTemplate.node then
        verticalListTemplate.node:Destroy()
    end
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
                if self.currentCardType == "副卡" or self.currentCardType == "sub" then
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

