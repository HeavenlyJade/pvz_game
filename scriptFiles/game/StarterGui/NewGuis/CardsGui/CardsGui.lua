local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.code.client.ui.ViewComponent) ---@type ViewComponent

local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.code.common.MGlobal)   ---@type gg

local uiConfig = {
    uiName = "CardsGui",
    layer = 3,
    hideOnInit = true,
}

---@class CardsGui:ViewBase
local CardsGui = ClassMgr.Class("CardsGui", ViewBase)

---@override
function CardsGui:OnInit(node, config)
    ViewBase.OnInit(self, node, config)
    gg.log("初始化CardsGui")
    self.qualityList = self:Get("品质列表", ViewList) ---@type ViewList
    self.mainCardButton = self:Get("框体/标题/卡片/主卡", ViewButton) ---@type ViewButton
    self.subCardButton = self:Get("框体/标题/卡片/副卡", ViewButton) ---@type ViewButton
    self.closeButton = self:Get("框体/关闭", ViewButton) ---@type ViewButton
    self.attributeButton = self:Get("框体/属性", ViewButton) ---@type ViewButton
    self.mainCardComponent = self:Get("框体/主卡", ViewComponent) ---@type ViewComponent
    self.subCardComponent = self:Get("框体/副卡", ViewComponent) ---@type ViewComponent

    self.confirmPointsButton = self:Get("框体/主卡/确定加点", ViewButton) ---@type ViewButton
    self.selectionList = self:Get("框体/主卡/选择列表", ViewList) ---@type ViewList
    self.mainCardFrame = self:Get("框体/主卡/加点框/纵列表/主卡框", ViewButton) ---@type ViewButton
    self.skillButtons = {}
    for i = 1, 3 do
        self.skillButtons[i] = self:Get("框体/主卡/加点框/纵列表/列表_" .. i, ViewButton) ---@type ViewButton
    end
    self.RegisterMenuButton(self.closeButton)

    -- 初始化技能数据
    self.skills = {} ---@type table<string, Skill>
    self.equippedSkills = {} ---@type table<number, string>

    ClientEventManager.Subscribe("SyncPlayerSkills", function(data)
        self:HandleSkillSync(data)
    end)
end


---@param viewButton ViewButton
function CardsGui.RegisterMenuButton(viewButton)
    if not viewButton then return end
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        local buttonName = button.node.Name
        local get_player_gui = gg.get_player_gui()
        if buttonName == "关闭" then
            local CardsGui = get_player_gui.NewGuis.CardsGui
            CardsGui.Visible= false
        end
    end
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
        local Skill = require(MainStorage.code.client.skills.Skill) ---@type Skill
        local skill = Skill.New(skillData)
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

return CardsGui.New(script.Parent, uiConfig)
