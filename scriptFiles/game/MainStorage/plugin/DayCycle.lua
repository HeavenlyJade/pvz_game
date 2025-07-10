
local MainStorage     = game:GetService("MainStorage")
local ClassMgr    = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ServerScheduler = require(MainStorage.code.server.ServerScheduler) ---@type ServerScheduler
local Environment = game:GetService("WorkSpace")["Environment"] ---@type Environment

---@class DayCycle
local DayCycle = ClassMgr.Class("DayCycle")

local worldTime = 12

function DayCycle:StartServer()
    ServerScheduler.add(function ()
        worldTime = worldTime + 0.01
        if worldTime > 24 then
            worldTime = 0
        end
        Environment.TimeHour = worldTime
    end, 0, 1)
end

return DayCycle