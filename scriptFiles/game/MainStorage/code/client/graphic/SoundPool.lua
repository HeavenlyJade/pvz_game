
local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

local SoundNodePool = {
    soundNodePoolReady = {}
}

function SoundNodePool:Init()
    local SoundPool = SandboxNode.new("Transform", WorkSpace)
    SoundPool.Name = "SoundPool"
    for i = 1, 50 do
        local soundNode = SandboxNode.new("Sound", SoundPool)
        soundNode.Name = "SoundNode" .. i
        table.insert(self.soundNodePoolReady, soundNode)
    end

    -- 监听PlaySound事件
    ClientEventManager.Subscribe("PlaySound", function(data)
        self:PlaySound(data)
    end)
end

function SoundNodePool:PlaySound(data)
    local soundNode = self.soundNodePoolReady[1]
    if soundNode == nil then
        print("No available sound nodes")
        return
    end

    -- 设置音效参数
    soundNode.SoundPath = data.soundAssetId
    soundNode.Volume = data.volume * 100 -- 转换为0-100范围
    soundNode.Pitch = data.pitch
    soundNode.Range = data.range

    -- 设置音效位置
    if data.boundTo then
        -- 如果绑定到节点
        local targetNode = gg.GetChild(WorkSpace, data.boundTo)
        if targetNode then
            soundNode.Parent = targetNode
            soundNode.FixPos = {0, 0, 0}
        end
    elseif data.position then
        -- 如果指定位置
        soundNode.Parent = WorkSpace
        soundNode.FixPos = data.position
    end

    -- 播放音效
    soundNode:PlaySound()

    table.remove(self.soundNodePoolReady, 1)
    table.insert(self.soundNodePoolReady, soundNode)
end

function SoundNodePool:ActivateSoundNode(soundAssetID, parent, localPosition)
    self:PlaySound({
        soundAssetId = soundAssetID,
        boundTo = parent,
        volume = 1.0,
        pitch = 1.0,
        range = 6000,
        position = localPosition
    })
end

return SoundNodePool