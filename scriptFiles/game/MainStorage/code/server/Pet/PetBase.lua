local game = game
local Vector3 = Vector3
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local ClientScheduler = require(MainStorage.code.client.ClientScheduler) ---@type ClientScheduler
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local Entity = require(MainStorage.code.server.entity_types.Entity) ---@type Entity

---@class PetBase :Class 宠物基类，定义宠物的通用属性和方法
---@field name  string 宠物名称
---@field id    string 宠物ID
---@field pos   table 宠物位置
---@field Quality   number 宠物品质
---@field Size   number 宠物大小
---@field totalPetNum   number 宠物总数
---@field PetRanking   number 宠物排名
---@field New fun(PetData:table):PetBase
local PetBase = ClassMgr.Class("PetBase",Entity)

--- 初始化宠物对象
---@param PetData table 宠物数据
function PetBase:OnInit(PetData)
    -- 宠物名称
    self.name = PetData.name or ''
    -- 宠物id
    self.id = PetData.id
    -- 宠物品质
    self.Quality = PetData.Quality
    -- 宠物大小
    self.Size = PetData.Size or 1
    -- 宠物总数
    self.totalPetNum = PetData.totalPetNum
    -- 宠物排名
    self.PetRanking = PetData.PetRanking
    -- 移动速度
    self.MoveSpeed = PetData.MoveSpeed
    self.PlayerPath = PetData.PlayerPath
    -- 初始宠物位置
    self:GetPetPos()

    self.StopTime = 0
    self.StopLongTime = 0
    self.RandomMove = false
    self.LagNum = 0
    self.LastPos = Vector3.New( 0,0,0 )
end

--- 获取宠物位置
---@param
---@return
function PetBase:GetPetPos()
    local Position = self.PlayerPath.Position
    if self.totalPetNum == 1 then
        self.pos = Vector3.New( Position.x,Position.y,Position.z + 100 )
    elseif self.totalPetNum == 2 then
        if self.PetRanking == 1 then
            self.pos = Vector3.New( Position.x+ 50,  Position.y,Position.z + 100 )
        elseif self.PetRanking == 2 then
            self.pos = Vector3.New( Position.x - 50, Position.y,Position.z + 100 )
        end
    elseif self.totalPetNum == 3 then
        if self.PetRanking == 1 then
            self.pos = Vector3.New( Position.x, Position.y,Position.z + 100 )
        elseif self.PetRanking == 2 then
            self.pos = Vector3.New( Position.x + 100, Position.y,Position.z + 100 )
        elseif self.PetRanking == 3 then
            self.pos = Vector3.New( Position.x - 100, Position.y,Position.z + 100 )
        end
    end
end

--- 创建宠物模型
---@param
---@return
function PetBase:CreatePetModel(Player)
    local name = self.name
    -- 创建宠物 --game:GetService("Players").LocalPlayer.Character.Name
    local container = game.WorkSpace[Player]
    if not container then
        gg.log("找不到绑定节点:", container)
        return
    end
    container = game.WorkSpace[Player]['Pet']
    if not container then
        gg.log("找不到绑定节点:", container)
        return
    end
    local PetPath = container['Pet' .. tostring(self.PetRanking)]
    if PetPath then
        -- 克隆路径
        local actor_pet = gg.GetChild(MainStorage["怪物模型"]['宠物'], name) ---@type Actor
        -- 克隆一个
        actor_pet = actor_pet:Clone()
        -- 显示
        PetPath.Enabled = true
        PetPath.Visible = true
        -- 宠物大小
        local size = 0.25 * self.Size
        if name == '魅惑菇' then
            size = 0.1 * self.Size
        end
        PetPath.LocalScale = Vector3.New(size,size,size)

        -- 模型 和 动画
        PetPath.ModelId = actor_pet.ModelId
        if PetPath.Animator then
            if actor_pet.Animator then
                PetPath.Animator.ControllerAsset = actor_pet.Animator.ControllerAsset
            else
                PetPath.Animator.ControllerAsset = ''
            end
        end

        --移动速度
        PetPath.Movespeed = self.MoveSpeed or 400
        -- 碰撞组 同组不会产生碰撞
        PetPath.CollideGroupID = 4
        -- 更新名字
        self:CreatePetTitle(PetPath,name,container,true)
        -- 关联到对象
        self:setGameActor(PetPath)
    else
        -- 克隆路径
        local actor_pet = gg.GetChild(MainStorage["怪物模型"]['宠物'], name) ---@type Actor
        -- 克隆一个
        actor_pet = actor_pet:Clone()
        -- 设置路径
        actor_pet:SetParent(container)
        -- 显示
        actor_pet.Enabled = true
        actor_pet.Visible = true
        -- 名称
        actor_pet.Name = 'Pet' .. tostring(self.PetRanking)
        -- 宠物大小
        local size = 0.25 * self.Size
        if name == '魅惑菇' then
            size = 0.1 * self.Size
        end
        actor_pet.LocalScale = Vector3.New(size,size,size)
        --移动速度
        actor_pet.Movespeed = self.MoveSpeed or 400
        -- 设置初始位置
        actor_pet.Position = self.pos
        -- 碰撞组 同组不会产生碰撞
        actor_pet.CollideGroupID = 4
        -- 创建名字
        self:CreatePetTitle(actor_pet,name,container)
        -- 关联到对象
        self:setGameActor(actor_pet)
        -- 跟随系统
        ClientScheduler.add(function()
            self:SetPetState()
        end, 0, 0.1)
    end
end

-- 创建名字
function PetBase:CreatePetTitle(actor_pet,name,container,UpData)
    if UpData then
        -- 设置名字颜色
        container['Pet' .. tostring(self.PetRanking)]['默认']['名字'].TitleColor = ColorQuad.New(255,255,255,255)
        -- 设置名字
        container['Pet' .. tostring(self.PetRanking)]['默认']['名字'].Title = name
    else
        local petTitle = gg.GetChild(MainStorage["特效"]['名字'], '默认') ---@type Actor
        -- 克隆一个
        petTitle = petTitle:Clone()
        -- 设置路径
        petTitle:SetParent(container['Pet' .. tostring(self.PetRanking)])
        -- 设置名字颜色
        petTitle['名字'].TitleColor = ColorQuad.New(255,255,255,255)
        -- 设置名字
        petTitle['名字'].Title = name
        -- 设置相对位置
        container['Pet' .. tostring(self.PetRanking)]['默认'].LocalPosition = Vector3.New(0,actor_pet.Size.y,0)
    end
end

--- 设置宠物每秒状态
function PetBase:SetPetState()
    -- 获取宠物目标点的位置
    self:GetPetPos()
    -- 获取宠物的状态
    local PetState = self.actor:GetCurMoveState()
    -- 最远距离
    local MaxDist = 1000 * 1000
    -- 移动距离
    local MoveDist = 200 * 200
    -- 宠物与目标点距离
    local distanceSq = gg.vec.DistanceSq3(self.pos, self.actor.Position)
    if distanceSq >= MaxDist then
        -- 瞬移到指定位置
        self.actor.Position = self.pos
        -- 清空卡位时间
        self.LagNum = 0
    elseif distanceSq >= MoveDist then
        local logDist = gg.vec.DistanceSq3(self.LastPos, self.actor.Position) ^ 2
        if logDist >= 10 then
            self.LagNum = 0
            self.LastPos = self.actor.Position
        else
            self.LagNum = self.LagNum + 1
        end
        if self.LagNum >= 15 then
            -- 瞬移到指定位置
            self.actor.Position = self.pos
        else
            -- 移动到指定位置
            self.actor:NavigateTo(self.pos)
        end
        -- 标记随机移动为false
        self.RandomMove = false
        -- 清空待机时间
        self.StopTime = 0
        -- 清空跳跃间隔时间
        self.StopLongTime = 0
    else
        -- 清空卡位时间
        self.LagNum = 0
        if self.StopTime >= 15 then
            -- 判断待机是否跳跃
            local jump = false
            -- 待机超过3秒
            if self.StopLongTime >= 30 then
                local is_jump = math.random(1,2)
                if is_jump == 1 then
                    self.actor:Jump(true)
                    jump = true
                end
                -- 清空跳跃间隔时间
                self.StopLongTime = 0
            end
            if not jump then
                local Position = self.PlayerPath.Position --game.WorkSpace['player1'].Position
                local pos_x = math.random(Position.x-100,Position.x+100)
                local pos_z = math.random(Position.z-100,Position.z+100)
                self.actor:NavigateTo(Vector3.New(pos_x,self.pos.y,pos_z))
            end
            -- 标记随机移动为true
            self.RandomMove = true
            -- 清空待机时间
            self.StopTime = 0
        else
            if PetState == Enum.BehaviorState.Jump then -- 3 跳跃
                self.actor:Jump(false)
            elseif PetState == Enum.BehaviorState.Stand then -- 4 站立
                -- 计时待机
                self.StopTime = self.StopTime + 1
                self.StopLongTime = self.StopLongTime + 1
            elseif PetState == Enum.BehaviorState.Walk then -- 5 行走
                -- 如果是移动到目标点 立即停止移动
                if not self.RandomMove then
                    self.actor:StopNavigate()
                else
                    -- 计时待机
                    self.StopTime = self.StopTime + 1
                    self.StopLongTime = self.StopLongTime + 1
                end
            end
        end
    end
end

return PetBase