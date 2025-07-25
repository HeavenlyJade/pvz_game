local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg                = require(MainStorage.code.common.MGlobal)    ---@type gg
local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local ItemTypeConfig = require(MainStorage.config.ItemTypeConfig) ---@type ItemTypeConfig
local CameraController = require(MainStorage.code.client.camera.CameraController) ---@type CameraController
local TweenService = game:GetService('TweenService') ---@type TweenService

---@class DrawCard:ViewBase
local DrawCard = ClassMgr.Class("DrawCard", ViewBase)
local rarityRanks = {
    mythic = {
        priority = 5,
        anim = "chu_2",
        card_back = "AssetId://401980482528337921",
        card_front = "sandboxId://textures/ui/主界面UI/抽卡/UR卡.png",
        delay = 1.63,
        model = "怪物模型/抽卡/Model",
        sound = "sandboxId://soundeffect/carddraw/card_ur.ogg"
    },
    legendary = {
        priority = 4,
        anim = "chu_2",
        card_back = "AssetId://401980450785845257",
        card_front = "sandboxId://textures/ui/主界面UI/抽卡/SSR卡.png",
        delay = 1.63,
        model = "怪物模型/抽卡/Model",
        sound = "sandboxId://soundeffect/carddraw/card_ur.ogg"
    },
    epic = {
        priority = 3,
        anim = "chu_1",
        card_back = "AssetId://401980420670742535",
        card_front = "sandboxId://textures/ui/主界面UI/抽卡/SR卡.png",
        delay = 0.93,
        model = "怪物模型/抽卡/Model",
        sound = "sandboxId://soundeffect/carddraw/card_sr.ogg"
    },
    rare = {
        priority = 2,
        anim = "chu_1",
        card_back = "AssetId://401980391310614528",
        card_front = "sandboxId://textures/ui/主界面UI/抽卡/R卡.png",
        delay = 0.93,
        model = "怪物模型/抽卡/Model",
        sound = "sandboxId://soundeffect/carddraw/card_r.ogg"
    },
    default = {
        priority = 1,
        anim = "chu_0",
        card_back = "AssetId://401980362743209984",
        card_front = "sandboxId://textures/ui/主界面UI/抽卡/N卡.png",
        delay = 0.23,
        model = "怪物模型/抽卡/Model",
    }
}

local tweenInfo = TweenInfo.New(0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local maskInfo = TweenInfo.New(0.21, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local uiConfig = {
    uiName = "DrawCard",
    layer = 1,
    hideOnInit = true,
    closeHuds = true
}

function DrawCard:OnInit(node, config)
    local modelView = self:Get("UIImage").node
    self.flyingCardList = self:Get("FlyingCard", ViewList) ---@type ViewList
    self.initialFlyingCardPos = self.flyingCardList:GetChild(1).node.Position
    self.cardSize = self.flyingCardList:GetChild(1).node.Size
    self.swipeHint = self:Get("SwipeHint")
    self.swipeHint.node.Visible = false
    self._dragStartPos = nil
    self._dragCompleted = false
    self.closeButton = self:Get("关闭", ViewButton)
    self.closeButton.clickCb = function (ui, button)
        self:Close()
    end
    modelView.TouchBegin:Connect(
        function(node, isTouchMove, vector2, int)
            if self.state == 1 then
                self._dragStartPos = vector2
                self._dragCompleted = false
                self.animator:Play("kai_0", 0, 0)
                self.animator:Play("kai_1", 1, 0)
            end
        end
    )
    modelView.TouchMove:Connect(
        function(node, isTouchMove, vector2, int)
            if self.state == 1 and self._dragStartPos and not self._dragCompleted then
                local deltaX = math.clamp(vector2.x - self._dragStartPos.x, 0, 300)
                local percent = deltaX / 300
                
                -- 检查拖动距离是否达到500以上，自动触发完成
                local totalDistance = math.abs(vector2.x - self._dragStartPos.x) + math.abs(vector2.y - self._dragStartPos.y)
                if totalDistance >= 500 and not self._dragCompleted then
                    self.state = 2
                    self._dragCompleted = true
                    self:onDragComplete()
                    return
                end
                
                if percent > self.maxPercent then
                    if game.RunService:IsMobile() then
                        game:GetService("UtilService"):GameVibrateWithTimeAmplitude(0.1, 0.1)
                    end
                    local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
                    ClientEventManager.Publish("ShakeCamera", {
                        dura = 0.2,
                        rotShake = {0,0,0},
                        posShake = {0,10,0},
                        mode = "随机",
                        drop = "二次方",
                        frequency = 0.05
                    })
                    if percent - self.lastSoundPercent > 0.1 then
                        ClientEventManager.Publish("PlaySound", {
                            soundAssetId = "sandboxId://soundeffect/carddraw/pack_open[1~2].ogg",
                            pitch = 0.8 + percent * 1.5
                        })
                        self.lastSoundPercent = percent
                    end
                end
                self.maxPercent = math.max(self.maxPercent, percent)
                self.animator:SetLayerWeight(0, 1-percent)
                self.animator:SetLayerWeight(1, percent)
                game.WorkSpace.CurrentCamera.FieldOfView = 75 - percent * 15
            end
        end
    )

    modelView.TouchEnd:Connect(
        function(node, isTouchMove, vector2, int)
            if self.state == 1 and self._dragStartPos then
                local deltaX = math.clamp(vector2.x - self._dragStartPos.x, 0, 200)
                if deltaX >= 200 then
                    self.state = 2
                    self._dragCompleted = true
                    self:onDragComplete()
                end
                self._dragStartPos = nil
                self._dragCompleted = false
            end
        end
    )

    ClientEventManager.Subscribe("LotteryRewards", function (evt)
        self.swipeHint.node.Visible = true
        ClientEventManager.Publish("PlaySound", {
            soundAssetId = "sandboxId://soundeffect/carddraw/cardpack_appear.ogg"
        })
        self.lastSoundPercent = 0
        self.maxPercent = 0
        self.flyingCardList:SetElementSize(0)
        self.rewards = evt.rewards
        self.chosenAnim = nil
        for i, reward in ipairs(self.rewards) do
            local chosenAnim = rarityRanks[reward.rarity] or rarityRanks.default
            if not self.chosenAnim or self.chosenAnim.priority < chosenAnim.priority then
                self.chosenAnim = chosenAnim
            end
        end
        self.model = gg.GetChild(MainStorage, self.chosenAnim.model):Clone() ---@type Model
        self.model.Parent = game.WorkSpace
        local localPos = game.Players.LocalPlayer.Character.Position
        self.model.Position = Vector3.New(localPos.x, localPos.y + 5000, localPos.z)
        CameraController.SetCameraAt(self.model.Position + Vector3.New(0, 150, -200), Vector3.New(0,0,0))
        local stateId = self.model:GetAttribute("状态机")
        if stateId and stateId ~= "" then
            local AnimationConfig = require(MainStorage.config.AnimationConfig) ---@type AnimationConfig
            local ModelPlayer = require(MainStorage.code.server.graphic.ModelPlayer) ---@type ModelPlayer
            self.animator = self.model.Animator
            local animator = self.animator
            local animationConfig = AnimationConfig.Get(stateId)
            if animator and animationConfig then
                self.modelPlayer = ModelPlayer.New(stateId, animator, animationConfig)
                self.modelPlayer.onAnimFinishedCb = function (stateConfig, newStateConfig)
                    if stateConfig.id == "born" then
                        self.state = 1
                    end
                end
            end
        end
        self.closeButton.node.Alpha = 0
        self.closeButton:SetVisible(false)
        self:Open()
    end)
end

function DrawCard:Close()
    ViewBase.Close(self)
    if self.model then
        self.model:Destroy()
    end
    ViewBase.LockMouseVisible(false)
    CameraController.UnlockCamera()
    if ViewBase.GetUI("HudMoney") then
        ViewBase.GetUI("HudMoney"):SetVisible(true) 
    end
    ClientEventManager.SendToServer("CloseDrawGui", {})
end

function DrawCard:Open()
    ViewBase.Open(self)
    ViewBase.GetUI("HudMoney"):SetVisible(false)
    self.state = 0
    self.modelPlayer:SwitchState("born")
end

function DrawCard:onDragComplete()
    self.state = 2
    self.swipeHint.node.Visible = false
    self.modelPlayer:SwitchState(self.chosenAnim.anim)
    self.flyingCardList:SetElementSize(#self.rewards)
    TweenService:Create(game.WorkSpace.CurrentCamera, tweenInfo, {FieldOfView = 80}):Play()
    
    -- 计算卡片居中排列的位置
    local cardSpacing = 20 -- 卡片之间的间距
    local cardsPerRow = 5 -- 每行最多5张卡片
    local rowSpacing = 20 -- 行间距
    local centerX = self.initialFlyingCardPos.x -- 使用已有的屏幕中心X坐标
    local centerY = self.initialFlyingCardPos.y -- 保持原有的Y坐标
    
    for i, reward in ipairs(self.rewards) do
        local card = self.flyingCardList:GetChild(i)
        card:SetVisible(false)
        card:Get("ItemIcon"):SetVisible(false)
        card:Get("Amount"):SetVisible(false)
        card:Get("ItemName"):SetVisible(false)
        local mask = card.node["MaskUIImage"]
        mask.Scale = Vector2.New(1, 0)
        ClientScheduler.add(function ()
            ClientEventManager.Publish("PlaySound", {
                soundAssetId = "sandboxId://soundeffect/carddraw/card_flip.ogg"
            })
            card:SetVisible(true)
            card.node.Position = self.initialFlyingCardPos
            card.node.Icon = (rarityRanks[reward.rarity] or rarityRanks.default).card_back
            TweenService:Create(card.node, tweenInfo, {
                Position = Vector2.New(self.initialFlyingCardPos.x, -500),
            }):Play()
            TweenService:Create(mask, maskInfo, {
                Scale = Vector2.New(1, 1)
            }):Play()
        end, self.chosenAnim.delay + 0.3 * i)
    end
    
    for i, reward in ipairs(self.rewards) do
        local card = self.flyingCardList:GetChild(i)
        ClientScheduler.add(function ()
            card:Get("ItemIcon"):SetVisible(true)
            local itemType = ItemTypeConfig.Get(reward.itemType)
            if itemType.icon then
                card:Get("ItemIcon").node.Icon = itemType.icon
            end
            card:Get("Amount"):SetVisible(true)
            card:Get("Amount").node.Title = gg.FormatLargeNumber(reward.amount)
            card:Get("ItemName"):SetVisible(true)
            card:Get("ItemName").node.Title = reward.itemType
            -- 计算卡片位置
            local row = math.ceil(i / cardsPerRow) -- 当前行
            local col = ((i - 1) % cardsPerRow) + 1 -- 当前列
            
            -- 计算当前行的卡片数量
            local cardsInRow = math.min(cardsPerRow, #self.rewards - (row - 1) * cardsPerRow)
            local rowWidth = (cardsInRow - 1) * cardSpacing + cardsInRow * self.cardSize.x
            
            -- 计算当前行的起始X位置（居中）
            local rowStartX
            if cardsInRow % 2 == 0 then
                -- 偶数：往左排列
                rowStartX = centerX - rowWidth / 2 + self.cardSize.x / 2
            else
                -- 奇数：居中排列
                rowStartX = centerX - (rowWidth - self.cardSize.x) / 2
            end
            
            -- 计算当前卡片的X和Y位置
            local cardX = rowStartX + (col - 1) * (self.cardSize.x + cardSpacing)
            local cardY = centerY - (row - 1) * (self.cardSize.y + rowSpacing) - 20
            
            card.node.Position = Vector2.New(cardX, -500)
            card.node.Icon = (rarityRanks[reward.rarity] or rarityRanks.default).card_front
            -- 计算每个卡片的最终位置
            local finalPosition = Vector2.New(cardX, cardY)
            local resetTween = TweenService:Create(card.node, tweenInfo, {Position = finalPosition})
            resetTween:Play()
            resetTween.Completed:Connect(function ()
                local sound = (rarityRanks[reward.rarity] or rarityRanks.default).sound
                if sound then
                    ClientEventManager.Publish("PlaySound", {
                        soundAssetId = sound,
                        pitch = 0.8 + 0.1 * i
                    })
                end
            end)
            if i == #self.rewards then
                self.state = 3
                self.closeButton.node.Visible = true
                TweenService:Create(self.closeButton.node, tweenInfo, {Alpha = 1}):Play()
            end
        end, self.chosenAnim.delay * 2 + 0.5 + 0.3 * i)
        end
end

return DrawCard.New(script.Parent, uiConfig)
