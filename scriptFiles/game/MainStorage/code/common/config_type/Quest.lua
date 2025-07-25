local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg            = require(MainStorage.code.common.MGlobal) ---@type gg
local Modifiers = require(MainStorage.code.common.config_type.modifier.Modifiers) ---@type Modifiers
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity

---@enum QuestRefreshType
local QuestRefreshType = {
    NONE = "不刷新",
    DAILY = "每日",
    WEEKLY = "每周",
    MONTHLY = "每月"
}

---@enum QuestType
local QuestType = {
    NONE = "无类型",
    VARIABLE = "变量",
    ITEM = "物品",
    EVENT = "事件"
}

---@class Quest:Class
local Quest = ClassMgr.Class("Quest")

---@param data table
function Quest:OnInit(data)
    self.name = data["名字"]
    self.category = data["分类"] or "主线"
    self.shortDesc = data["简短描述"]
    self.fullDesc = data["完整描述"]
    
    self.completionCount = data["完成数量"] or 1
    self.acceptConditions = Modifiers.New(data["领取条件"]) ---@type Modifiers
    self.questType = data["任务类型"] or QuestType.NONE
    
    self.questVariable = data["任务变量"]
    self.requiredItem = ItemTypeConfig.Get(data["需求物品"])
    self.eventName = data["事件名"]
    self.completionRewards = data["提交奖励"] ---@type table<string, number>
    self.mailRewards = data["提交奖励_邮件"] ---@type table<string, number>
    self.completionCommands = data["提交指令"] ---@type string[]
    self.finishCommands = data["完成指令"] ---@type string[]
    self.gotoSceneNode = data["前往场景节点"] ---@type string
    self.focusOnUI = data["聚焦场景UI"]
    if self.focusOnUI and not self.focusOnUI["聚焦UI"] then
        self.focusOnUI = nil
    end
    self.nextQuest = data["自动领取下一任务"]
    self.refreshType = data["刷新类型"] or QuestRefreshType.NONE
    self.autoTurnIn = data["自动提交兑奖"] or false
    
    self.autoAcceptOnRefresh = data["刷新时自动领取"] or false
    self.showProgress = data["显示完成进度"]
    
    self.questList = data["任务列表"]
    self.rewards = data["奖励"]
end

---@param player Player
function Quest:OnClick(player)
    if self.gotoSceneNode then
        local node = gg.GetSceneNode(self.gotoSceneNode)
        if not node then
            gg.log("任务%s有不存在的节点%s", self.name, self.gotoSceneNode)
            return
        end
        local cb = nil
        local e = Entity.node2Entity[node] ---@cast e Npc
        if ClassMgr.Is(e, "Npc") then
            cb = function ()
                e:HandleInteraction(player)
            end
        end
        local range = 300
        if node:IsA("Actor") then
            range = range + math.max(node.Size.x, node.Size.z)
        end
        player:NavigateTo(node.Position, range, cb)
    end
    if self.focusOnUI then
        player.focusOnCommandsCb = self.focusOnUI["完成时执行指令"]
        player:SendEvent("FocusOnUI", self.focusOnUI)
    end
end

--玩家当前是否有此任务
function Quest:Has(player)
    -- 检查是否已接受
    if player.quests[self.name] then
        return true
    end
    
    -- 检查是否已完成
    if player.acceptedQuestIds[self.name] == 1 then
        return true
    end
    
    return false
end

function Quest:GetToStringParams()
    return {
        name = self.name
    }
end

function Quest:Accept(player)
    -- 检查是否已有此任务
    if self:Has(player) then
        return false
    end
    if self.acceptConditions then
        -- 使用Modifiers的Check方法检查所有条件
        local param = self.acceptConditions:Check(player, player)
        if param.cancelled then
            return false
        end
    end
    local AcceptedQuest = require(MainStorage.code.server.entity_types.player_data.AcceptedQuest)
    local questInstance = AcceptedQuest.New(self, player)
    
    -- 添加到玩家任务列表
    player.quests[self.name] = questInstance
    player.acceptedQuestIds[self.name] = 0 -- 标记为已接受未完成
    
    -- 同步到客户端
    player:UpdateQuestsData()
    
    -- 任务被接受时，AcceptedQuest会自动将进度关键字注册到player.questKey，完成时自动移除。
    
    return true
end


return Quest