-- local MainStorage = game:GetService("MainStorage")
-- local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
-- local gg = require(MainStorage.code.common.MGlobal)   ---@type gg

-- ---@class ShakeBeh
-- local ShakeBeh = {}

-- -- 震动数据
-- local _shakeData = {
--     stop = true,
--     loop = false,
--     elapsedtime = 0.0,
--     duration = 0.5,
--     frequency = 0.05,
--     strength = 1.0,
--     rotX = 20,
--     rotY = 20,
--     rotZ = 0,
--     posX = 0,
--     posY = 0,
--     posZ = 0,
--     posDelta = Vector3.New(0, 0, 0),
--     rotDelta = Vector3.New(0, 0, 0),
--     randSeed = 0
-- }

-- -- 更新循环连接
-- local _updateConnection = nil

-- -- 私有方法
-- local function Noise2D(x, y)
--     return gg.noise:StaticNoise2D(x, y)
-- end

-- local function HasActiveTasks()
--     return not _shakeData.stop
-- end

-- local function StopUpdateLoop()
--     if _updateConnection then
--         _updateConnection:Disconnect()
--         _updateConnection = nil
--     end
-- end

-- local function UpdateShake(dt)
--     gg.log("UpdateShake", _shakeData, _shakeData.elapsedtime < _shakeData.duration)
--     if _shakeData.stop then return end
    
--     if _shakeData.elapsedtime < _shakeData.duration then
--         _shakeData.elapsedtime = _shakeData.elapsedtime + dt
--         local progress = _shakeData.elapsedtime / _shakeData.duration
--         local easingValue = 1 - progress -- 简单的线性衰减

--         -- 计算旋转震动
--         local rx = Noise2D(_shakeData.elapsedtime * _shakeData.frequency, _shakeData.randSeed + 0.0) - 0.5
--         local ry = Noise2D(_shakeData.elapsedtime * _shakeData.frequency, _shakeData.randSeed + 1.0) - 0.5
--         local rz = Noise2D(_shakeData.elapsedtime * _shakeData.frequency, _shakeData.randSeed + 2.0) - 0.5
--         _shakeData.rotDelta = gg.vec.Multiply3(Vector3.New(rx * _shakeData.rotX, ry * _shakeData.rotX, rz * _shakeData.rotX), _shakeData.strength * easingValue)

--         -- 计算位移震动
--         local px = Noise2D(_shakeData.elapsedtime * _shakeData.frequency, _shakeData.randSeed + 3.0) - 0.5
--         local py = Noise2D(_shakeData.elapsedtime * _shakeData.frequency, _shakeData.randSeed + 4.0) - 0.5
--         local pz = Noise2D(_shakeData.elapsedtime * _shakeData.frequency, _shakeData.randSeed + 5.0) - 0.5
--         print("Shake", py, ry)
--         _shakeData.posDelta = gg.vec.Multiply3(Vector3.New(px * _shakeData.posX, py * _shakeData.posY, pz * _shakeData.posZ), _shakeData.strength * easingValue)
--     else
--         if _shakeData.loop then
--             _shakeData.elapsedtime = 0.0
--         else
--             ShakeBeh.StopShake()
--         end
--     end
-- end

-- local function Update(dt)
--     UpdateShake(dt)
--     -- 如果没有活动任务，停止更新循环
--     if not HasActiveTasks() then
--         StopUpdateLoop()
--     end
-- end

-- local function StartUpdateLoop()
--     if not _updateConnection then
--         _updateConnection = game.RunService.RenderStepped:Connect(Update)
--     end
-- end

-- -- 公共方法
-- function ShakeBeh.StopShake()
--     _shakeData.stop = true
--     _shakeData.loop = false
    
--     -- 如果没有活动任务，停止更新循环
--     if not HasActiveTasks() then
--         StopUpdateLoop()
--     end
-- end

-- function ShakeBeh.StartShake(loop)
--     _shakeData.stop = false
--     _shakeData.loop = loop
--     _shakeData.elapsedtime = 0.0
--     _shakeData.posDelta = Vector3.New(0, 0, 0)
--     _shakeData.rotDelta = Vector3.New(0, 0, 0)
--     _shakeData.randSeed = math.random(0, 36)
--     StartUpdateLoop()
-- end

-- function ShakeBeh.GetPosDelta()
--     gg.log("ShakeBeh.GetPosDelta", _shakeData.posDelta)
--     return _shakeData.posDelta
-- end

-- function ShakeBeh.GetRotDelta()
--     gg.log("ShakeBeh.GetRotDelta", _shakeData.rotDelta)
--     return _shakeData.rotDelta
-- end

-- function ShakeBeh.IsShaking()
--     return not _shakeData.stop
-- end

-- ClientEventManager.Subscribe("ShakeCamera", function(evt)
--     gg.log("ShakeBeh received ShakeCamera event:", evt)
--     _shakeData = evt
--     ShakeBeh.StartShake(evt.loop)
-- end)

-- -- 导出单例
-- return ShakeBeh