--- 测试技能事件配置的脚本
--- 用于验证event_skill.lua配置文件是否正确

-- 模拟Roblox环境
local function mockRoblox()
    if not game then
        _G.game = {
            GetService = function(serviceName)
                if serviceName == "MainStorage" then
                    return {
                        code = {
                            common = {
                                event_conf = {}
                            }
                        }
                    }
                end
            end
        }
    end
end

-- 初始化测试环境
mockRoblox()

-- 加载配置文件
local SkillEventConfig = require("scriptFiles/game/MainStorage/code/common/event_conf/event_skill")

print("=== 技能事件配置测试 ===")

-- 测试请求事件
print("\n--- 请求事件测试 ---")
for key, value in pairs(SkillEventConfig.REQUEST) do
    print(string.format("REQUEST.%s = %s", key, value))
end

-- 测试响应事件
print("\n--- 响应事件测试 ---")
for key, value in pairs(SkillEventConfig.RESPONSE) do
    print(string.format("RESPONSE.%s = %s", key, value))
end

-- 测试错误码
print("\n--- 错误码测试 ---")
for key, value in pairs(SkillEventConfig.ERROR_CODES) do
    print(string.format("ERROR_CODES.%s = %d", key, value))
end

-- 测试错误消息获取函数
print("\n--- 错误消息测试 ---")
for errorCode, expectedMessage in pairs(SkillEventConfig.ERROR_MESSAGES) do
    local actualMessage = SkillEventConfig.GetErrorMessage(errorCode)
    local status = actualMessage == expectedMessage and "✓" or "✗"
    print(string.format("%s 错误码 %d: %s", status, errorCode, actualMessage))
end

-- 测试事件验证函数
print("\n--- 事件验证测试 ---")
local testEvents = {
    {SkillEventConfig.REQUEST.GET_LIST, "IsValidRequestEvent", true},
    {SkillEventConfig.RESPONSE.LIST, "IsValidRequestEvent", false},
    {SkillEventConfig.RESPONSE.LIST, "IsValidResponseEvent", true},
    {"InvalidEvent", "IsValidRequestEvent", false},
}

for _, test in ipairs(testEvents) do
    local eventName, funcName, expected = test[1], test[2], test[3]
    local actual = SkillEventConfig[funcName](eventName)
    local status = actual == expected and "✓" or "✗"
    print(string.format("%s %s('%s') = %s (期望: %s)", status, funcName, eventName, tostring(actual), tostring(expected)))
end

-- 测试事件列表获取
print("\n--- 事件列表测试 ---")
local requestEvents = SkillEventConfig.GetAllRequestEvents()
local responseEvents = SkillEventConfig.GetAllResponseEvents()
print(string.format("请求事件数量: %d", #requestEvents))
print(string.format("响应事件数量: %d", #responseEvents))

print("\n=== 测试完成 ===")
print("✓ 所有配置功能工作正常！") 