local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg
local CustomUI      = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local SkillTypeConfig = require(MainStorage.config.SkillTypeConfig) ---@type SkillTypeConfig

---@class PetsGui:CustomUI
local PetsGui = ClassMgr.Class("PetsGui", CustomUI)

---@param data table
function PetsGui:OnInit(data)
    self.petsGoods = {} ---@type table<string, SkillType>
    if data and data["技能"] then  -- 修正：配置中使用的是"技能"字段
        for _, skillType in ipairs(data["技能"]) do
            self.petsGoods[skillType] = SkillTypeConfig.Get(skillType)
        end
    end
    gg.log("PetsGui初始化技能数据:", data and data["技能"] or "无技能配置")
    gg.log("petsGoods数量:", gg.TableLength(self.petsGoods))
end

---@param player Player
function PetsGui:S_BuildPacket(player, packet)
    packet.petsGoods = {}
    for skillName, skillType in pairs(self.petsGoods) do
        -- 获取玩家的技能信息
        local playerSkill = player:GetSkill(skillName)
        local isLearned = playerSkill and playerSkill:IsLearned() or false
        local isEquipped = playerSkill and playerSkill:IsEquipped() or false
        local currentLevel = playerSkill and playerSkill.level or 0
        local maxLevel = skillType.maxLevel or 1
        
        -- 计算升级消耗
        local upgradeCost = skillType:GetCostAtLevel(currentLevel + 1)
        local canAfford = true
        local priceHas = 0
        local priceAmount = 0
        
        -- 检查是否能负担得起升级费用
        if upgradeCost and next(upgradeCost) then
            -- 假设主要货币是阳光，获取第一个资源作为价格显示
            local firstResource, firstCost = next(upgradeCost)
            priceAmount = firstCost or 0
            priceHas = player:GetResourceAmount(firstResource) or 0
            canAfford = priceHas >= priceAmount
        end
        
        packet.petsGoods[skillName] = {
            affordable = canAfford and currentLevel < maxLevel,
            bought = isLearned,
            equipped = isEquipped,
            currentLevel = currentLevel,
            maxLevel = maxLevel,
            price = priceAmount,
            priceHas = priceHas,
            canLevelUp = currentLevel > 0 and currentLevel < maxLevel
        }
    end
end
function PetsGui:onViewCategory(player,evt)
    local CustomUIConfig = require(MainStorage.config.CustomUIConfig) ---@type CustomUIConfig
    local customUI = CustomUIConfig.Get(evt.shop)
    customUI:S_Open(player)
end

function PetsGui:onPurchase(player, evt)
    local skillType = self.petsGoods[evt.shopGood]
    if not skillType then
        gg.log("错误: 找不到技能类型", evt.shopGood)
        return
    end
    
    -- 获取玩家的技能信息
    local playerSkill = player:GetSkill(evt.shopGood)
    local currentLevel = playerSkill and playerSkill.level or 0
    
    -- 如果还没学会技能，先学习技能
    if currentLevel == 0 then
        -- 学习技能逻辑 - 这里需要根据实际的学习技能方法来调用
        if player:LearnSkill(evt.shopGood) then
            self:S_Open(player)
        end
    else
        -- 升级技能逻辑
        if player:UpgradeSkill(evt.shopGood) then
        self:S_Open(player)
        end
    end
end

-- 技能装备
function PetsGui:onEquipSkill(player, evt)
    gg.log("PetsGui 装备技能请求", evt)
    local skillName = evt.skillName
    if not skillName or not self.petsGoods[skillName] then
        gg.log("错误: 技能名称无效", skillName)
        return
    end
    
    -- 使用 SkillEventManager 的装备事件
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager)
    SkillEventManager.HandleEquipSkill({
        player = player,
        skillName = skillName
    })
    
    -- 重新打开界面刷新显示
    self:S_Open(player)
end

-- 技能卸下
function PetsGui:onUnequipSkill(player, evt)
    gg.log("PetsGui 卸下技能请求", evt)
    local skillName = evt.skillName
    if not skillName or not self.petsGoods[skillName] then
        gg.log("错误: 技能名称无效", skillName)
        return
    end
    
    -- 使用 SkillEventManager 的卸下事件
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager)
    SkillEventManager.HandleUnequipSkill({
        player = player,
        skillName = skillName
    })
    
    -- 重新打开界面刷新显示
    self:S_Open(player)
end

-- 技能升级
function PetsGui:onUpgradeSkill(player, evt)
    gg.log("PetsGui 升级技能请求", evt)
    local skillName = evt.skillName
    if not skillName or not self.petsGoods[skillName] then
        gg.log("错误: 技能名称无效", skillName)
        return
    end
    
    -- 使用 SkillEventManager 的升级事件
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager)
    SkillEventManager.HandleUpgradeSkill({
        player = player,
        skillName = skillName
    })
    
    -- 重新打开界面刷新显示
    self:S_Open(player)
end

-- 技能升星
function PetsGui:onUpgradeStarSkill(player, evt)
    gg.log("PetsGui 升星技能请求", evt)
    local skillName = evt.skillName
    if not skillName or not self.petsGoods[skillName] then
        gg.log("错误: 技能名称无效", skillName)
        return
    end
    
    -- 使用 SkillEventManager 的升星事件
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager)
    SkillEventManager.HandleUpgradeStarSkill({
        player = player,
        skillName = skillName
    })
    
    -- 重新打开界面刷新显示
    self:S_Open(player)
end

-- 技能升阶
function PetsGui:onUpgradeRankSkill(player, evt)
    gg.log("PetsGui 升阶技能请求", evt)
    local skillName = evt.skillName
    if not skillName or not self.petsGoods[skillName] then
        gg.log("错误: 技能名称无效", skillName)
        return
    end
    
    -- 使用 SkillEventManager 的升阶事件
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager)
    SkillEventManager.HandleUpgradeRankSkill({
        player = player,
        skillName = skillName
    })
    
    -- 重新打开界面刷新显示
    self:S_Open(player)
end

-- 一键强化技能
function PetsGui:onUpgradeAllSkill(player, evt)
    gg.log("PetsGui 一键强化技能请求", evt)
    local skillName = evt.skillName
    local targetLevel = evt.targetLevel
    if not skillName or not self.petsGoods[skillName] then
        gg.log("错误: 技能名称无效", skillName)
        return
    end
    
    -- 使用 SkillEventManager 的一键强化事件
    local SkillEventManager = require(MainStorage.code.server.spells.SkillEventManager)
    SkillEventManager.HandleUpgradeAllSkill({
        player = player,
        skillName = skillName,
        targetLevel = targetLevel
    })
    
    -- 重新打开界面刷新显示
    self:S_Open(player)
end


-----------------------客户端---------------------------
---@param node ViewButton
---@param skillType SkillType
---@param status table
function PetsGui:_UpdateCard(node, skillType, status)
    -- 使用正确的UI路径结构：主卡框_1/卡框背景/图标
    node:SetChildIcon("卡框背景/图标", skillType.icon)
    -- 显示技能等级 - 使用"等级"节点
    local levelNode = node:Get("等级")
    if levelNode then
        levelNode.node.Title = string.format("Lv.%d", status.currentLevel or 0)
    end
    -- 显示技能名
    local nameNode = node:Get("技能名")
    if nameNode then
        nameNode.node.Title = skillType.name or ""
    end
    -- 根据技能品级或状态显示标签 - 检查是否有对应节点
    local hotNode = node:Get("卡框背景/角标")
    if hotNode then
        hotNode.node.Visible = skillType.quality == "UR" or skillType.quality == "SSR"
    end
    node.clickCb = function (ui, button)
        self:_ShowGood(skillType)
        self.selectedSkillName = skillType.name -- 更新选中的技能
    end
end

---@param skillType SkillType
function PetsGui:_ShowGood(skillType)
    -- 更新选中的技能名称，供按钮回调使用
    self.selectedSkillName = skillType.name
    
    -- 可以在这里添加显示技能详细信息的逻辑
    -- 比如更新技能描述、图标、属性等UI显示
    gg.log("选中技能:", skillType.name)
end

--1. 在C_BuildUI初始化所有要用到的UI控件，并且标注其类型（可让AI做）

function PetsGui:C_BuildUI(packet)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    local ui = self.view
    
    -- 初始化所有UI组件
    self.qualityList = ui:GetList("品质列表",function (child,childPath)
        local c = ViewButton.New(child,ui,childPath)
        return c
    end) ---@type ViewList
    
    self.background = ui:GetComponent("框体") ---@type ViewComponent
    self.closeButton = ui:GetButton("框体/关闭") ---@type ViewButton
    self.attributeButton = ui:GetComponent("框体/宠物属性") ---@type ViewComponent
    self.petsComponent = ui:GetComponent("框体/宠物类目") ---@type ViewComponent
    self.UpgradeButton = ui:GetButton("框体/宠物属性/宠物升级") ---@type ViewButton
    self.EquipmentButton = ui:GetButton("框体/宠物属性/宠物装备") ---@type ViewButton
    self.UnEquipButton = ui:GetButton("框体/宠物属性/宠物卸下") ---@type ViewButton
    self.UpgradeRankButton = ui:GetButton("框体/宠物属性/宠物升星") ---@type ViewButton
    self.AllUpgradeButton = ui:GetButton("框体/宠物属性/宠物一键升级") ---@type ViewButton
    
    -- 设置按钮点击回调
    if self.closeButton then
        self.closeButton.clickCb = function(ui, button)
            self.view:Close()
        end
    end
    
    self.UpgradeButton.clickCb = function(ui, button)
        if not self.selectedSkillName then
            gg.log("错误: 未选择技能")
            return
        end
        self:C_SendEvent("onUpgradeSkill", {
            skillName = self.selectedSkillName
        })
    end
    
    self.EquipmentButton.clickCb = function(ui, button)
        if not self.selectedSkillName then
            gg.log("错误: 未选择技能")
            return
        end
        self:C_SendEvent("onEquipSkill", {
            skillName = self.selectedSkillName
        })
    end
    
    self.UnEquipButton.clickCb = function(ui, button)
        if not self.selectedSkillName then
            gg.log("错误: 未选择技能")
            return
        end
        self:C_SendEvent("onUnequipSkill", {
            skillName = self.selectedSkillName
        })
    end
    
    self.UpgradeRankButton.clickCb = function(ui, button)
        if not self.selectedSkillName then
            gg.log("错误: 未选择技能")
            return
        end
        self:C_SendEvent("onUpgradeRankSkill", {
            skillName = self.selectedSkillName
        })
    end
    
    self.AllUpgradeButton.clickCb = function(ui, button)
        if not self.selectedSkillName then
            gg.log("错误: 未选择技能")
            return
        end
        local skillStatus = self.packet.petsGoods[self.selectedSkillName]
        if skillStatus then
            local targetLevel = skillStatus.currentLevel + 1
            self:C_SendEvent("onUpgradeAllSkill", {
                skillName = self.selectedSkillName,
                targetLevel = targetLevel
            })
        end
    end
    
    self.functionList = ui:GetList("框体/宠物类目/功能框/列表",function (child,childPath)
        local c = ViewButton.New(child,ui,childPath)
        return c
    end) ---@type ViewList
    self.PetsList = ui:GetList("框体/宠物类目/宠物展示框/纵列表",function (child,childPath)
        local c = ViewButton.New(child,ui,childPath)
        return c  
    end) ---@type ViewList
    
    
    -- 初始化技能列表数据
    if packet.petsGoods and next(packet.petsGoods) then
        local skillList = {}
        for skillName, skillType in pairs(self.petsGoods) do
            table.insert(skillList, skillType)
        end
        
        -- 检查列表是否有模板元素
        if #skillList > 0 and self.PetsList.childrens and #self.PetsList.childrens > 0 then
        -- 更新宠物展示框列表
        self.PetsList:SetElementSize(#skillList)
        for i, skillType in ipairs(skillList) do
            local node = self.PetsList:GetChild(i)
                if node then
            local status = packet.petsGoods[skillType.name] or {}
            self:_UpdateCard(node, skillType, status)
        end
    end
        else
            gg.log("调试信息 - skillList数量:", #skillList)
            if self.PetsList.childrens then
                gg.log("调试信息 - PetsList.childrens数量:", #self.PetsList.childrens)
            else
                gg.log("调试信息 - PetsList.childrens为nil")
            end
            if self.functionList.childrens then
                gg.log("调试信息 - functionList.childrens数量:", #self.functionList.childrens)
            else
                gg.log("调试信息 - functionList.childrens为nil")
            end
            gg.log("PetsList没有模板子元素或技能数据为空")
        end
    end
    
    -- 确保主要组件可见
    self.background.node.Visible = true
    self.background.node.Active = true
    self.attributeButton.node.Visible = true
    self.attributeButton.node.Active = true
    self.petsComponent.node.Visible = true
    self.petsComponent.node.Active = true
    -- 最后设置packet
    self.packet = packet
    
    self.view:Open()
end


return PetsGui