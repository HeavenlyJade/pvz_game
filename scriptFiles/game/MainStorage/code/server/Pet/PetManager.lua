local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local PetBase = require(MainStorage.code.server.Pet.PetBase) ---@type PetBase
local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class PetManager :Class 宠物基类，定义宠物的通用属性和方法
---@field New fun(data:PetManager):PetManager
local PetManager = ClassMgr.Class("PetManager")

--- 初始化宠物管理器
function PetManager:Init()
    gg.log('初始化 PetManager')
    -- 注册网络消息处理函数
    self:RegisterNetworkHandlers()
    gg.log('初始化 PetManager 完成')
    return self
end

--- 服务端接受消息发给客户端
function PetManager:RegisterNetworkHandlers()
    -- 服务端接受消息发给客户端
    ServerEventManager.Subscribe('ClickTestBtn', function(event)
        if not event or not event.player then
            return
        end
        -- 通知全部玩家
        for _, p in pairs(gg.server_players_list) do
            if p and p.uin then
                gg.network_channel:fireClient(p.uin, {
                    cmd = 'CreatePet',
                    PlayerName = event.PlayerName,
                    PetList = event.PetList,
                })
            end
        end
    end)
end



---@param PetList table 宠物信息
---@return PetBase
function PetManager:ShowPet(Player, PetList)
    gg.log('客户端发信息给服务端')
    local container = game.WorkSpace[Player]
    if not container then
        return
    end
    for i = (#PetList + 1), 3 do
        local PetPath = container['Pet']
        if PetPath then
            PetPath = container['Pet']['Pet' .. i]
            if PetPath then
                PetPath:Destroy()
            end
        end
    end
    for i, PetData in ipairs(PetList) do
        self:Spawn(Player, PetData)
    end
end

---@param PetData table 宠物信息
---@return PetBase
function PetManager:Spawn(Player, PetData)
    PetData.PlayerPath = game.WorkSpace[Player]
    local Pet = PetBase.New(PetData)
    -- 创建宠物
    Pet:CreatePetModel(Player)
    return Pet
end

--- 发送宠物列表到客户端
---@param PlayerName string 玩家节点
---@param uin number 玩家ID
function PetManager:SendMailListToClient(PlayerName, uin)
    -- 服务端发送到客户端
    gg.network_channel:fireClient(uin, {
        cmd = 'SubscribePet',
        PlayerName = PlayerName,
    })
end



return PetManager