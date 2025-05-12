
--------------------------------------------------

--- Description：服务器代码入口
--- 服务器启动的时候，会自动加载此代码并执行，再加载其他代码模块 (v109)
--------------------------------------------------

print("Server Side enter begin")

local MainStorage = game:GetService("MainStorage")
local code = MainStorage:WaitForChild('code')
local common = code:WaitForChild('common')
common:WaitForChild('ClassMgr' )
common:WaitForChild('MCEntitySpawn'):WaitForChild( 'MConfigScene' )

local server = code:WaitForChild('server')
-- local skill  = server:WaitForChild('skill')

-- local SkillFactory = skill:WaitForChild('SkillFactory')

-- skill:WaitForChild('CSkillBase')
-- SkillFactory:WaitForChild('CSkill_2006')
-- local equipment = server:WaitForChild('equipment')
local CommandSystem = server:WaitForChild('CommandSystem')
local CommandManager = CommandSystem:WaitForChild('MCommandManager')
-- local TaskSystem = require(server.TaskSystem.MTaskSystem) ---@type TaskSystem
-- print("111TaskSystem对象",TaskSystem)
local TaskSystem = server:WaitForChild('TaskSystem')
local TaskManager = TaskSystem:WaitForChild('MTaskSystem')
local MainServer = require(server.MServerMain) ---@type MainServer
MainServer.start_server()
print("服务器加载完成")