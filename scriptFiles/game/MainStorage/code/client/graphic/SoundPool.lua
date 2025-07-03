local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg = require(MainStorage.code.common.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager

local  soundNodePoolReady = {}
-- 记录每个声音的最后播放时间，防止0.1秒内重复播放
local lastPlayTimes = {}

local keyedSounds = {} ---@type table<number, table<number, Sound>>

local function PlaySound(data)
    local sound = data.soundAssetId
    local key = data.key
    local layer = data.layer or 1
    gg.log("PlaySound", data)
    if data.close and key then
        -- 检查是否在0.1秒内刚刚播放过同一个layer的同一个音乐，如果是则不处理关闭事件
        local soundKey = tostring(key) .. "_" .. tostring(layer)
        local currentTime = gg.GetTimeStamp()
        local lastPlayTime = lastPlayTimes[soundKey]
        gg.log("lastPlayTime", soundKey, lastPlayTimes)
        if lastPlayTime then
            gg.log("lastPlayTime", soundKey, currentTime - lastPlayTime)
        end
        if lastPlayTime and (currentTime - lastPlayTime) < 0.1 then
            return
        end
        -- 停止该key+layer音效
        if keyedSounds[key] and keyedSounds[key][layer] then
            local node = keyedSounds[key][layer]
            node:StopSound()
            node.SoundPath = ""
        else
            return
        end
        -- 恢复上一个被暂停的同key音效（SoundPath不为""）
        if keyedSounds[key] then
            local maxLayer, resumeNode = nil, nil
            for l, node in pairs(keyedSounds[key]) do
                if l < layer and node and node.SoundPath and node.SoundPath ~= "" then
                    if not maxLayer or l > maxLayer then
                        maxLayer = l
                        resumeNode = node
                    end
                end
            end
            if resumeNode then
                print("ResumeSound", resumeNode.Name)
                resumeNode:ResumeSound()
            end
        end
        return
    end
    if not sound or sound == "" then
        return
    end
    if type(sound) == "string" then
        sound = sound:gsub("%[(%d+)~(%d+)%]", function(a, b)
            local n, m = tonumber(a), tonumber(b)
            if n and m and n <= m then
                return tostring(math.random(n, m))
            end
            return a .. "~" .. b
        end)
    end


    local soundNode
    if key then
        keyedSounds[key] = keyedSounds[key] or {}
        -- 停止所有更低layer的同key音效
        for l, node in pairs(keyedSounds[key]) do
            if l < layer and node then
                node:PauseSound()
            end
        end
        if keyedSounds[key][layer] then
            soundNode = keyedSounds[key][layer]
            -- 如果素材一样且正在播放，则无事发生
            if soundNode.SoundPath == sound then
                local soundKey = tostring(key) .. "_" .. tostring(layer)
                local currentTime = gg.GetTimeStamp()
                local lastPlayTime = lastPlayTimes[soundKey]
                if lastPlayTime and (currentTime - lastPlayTime) < 0.1 then
                    return
                end
                lastPlayTimes[soundKey] = currentTime
                return
            end
            soundNode:StopSound()
            soundNode.SoundPath = ""
        else
            -- 创建新的Sound节点
            soundNode = SandboxNode.new("Sound", game.Players.LocalPlayer.Character) ---@type Sound
            soundNode.Name = "KeyedSound_" .. tostring(key) .. "_" .. tostring(layer)
            soundNode.IsLoop = true
            keyedSounds[key][layer] = soundNode
        end
    else
        soundNode = soundNodePoolReady[1]
        if soundNode == nil then
            print("No available sound nodes")
            return
        end
    end

    -- 设置音效参数
    soundNode.SoundPath = sound
    soundNode.Volume = data.volume or 1
    soundNode.Pitch = data.pitch or 1
    soundNode.RollOffMaxDistance = data.range or 6000

    if not key then
        if data.boundTo then
            local targetNode = gg.GetChild(WorkSpace, data.boundTo)
            if targetNode then ---@cast targetNode Transform
                soundNode.FixPos = targetNode.Position
            end
        elseif data.position then
            soundNode.FixPos = Vector3.New(data.position[1], data.position[2], data.position[3])
        else
            soundNode.FixPos = game.Players.LocalPlayer.Character.Position
        end
    end

    -- 播放音效
    soundNode:PlaySound()

    if not key then
        table.remove(soundNodePoolReady, 1)
        table.insert(soundNodePoolReady, soundNode)
    end
end

local function ActivateSoundNode(soundAssetID, parent, localPosition)
    PlaySound({
        soundAssetId = soundAssetID,
        boundTo = parent,
        volume = 1.0,
        pitch = 1.0,
        range = 6000,
        position = localPosition
    })
end

local SoundPool = SandboxNode.new("Transform", WorkSpace)
SoundPool.Name = "SoundPool"
for i = 1, 50 do
    local soundNode = SandboxNode.new("Sound", SoundPool)
    soundNode.Name = "SoundNode" .. i
    table.insert(soundNodePoolReady, soundNode)
end
ClientEventManager.Subscribe("PlaySound", function(data)
    PlaySound(data)
end)
