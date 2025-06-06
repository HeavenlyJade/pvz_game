local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg

local commandInput = script.Parent ---@type UITextInput

local commandHistory = {}
local commandHistoryIndex = 1

local UserInputService = game:GetService("UserInputService")

local function inputBegan( inputObj, bGameProcessd )
	if inputObj.UserInputType == Enum.UserInputType.Keyboard.Value then
        if inputObj.KeyCode == Enum.KeyCode.Return.Value then
            gg.network_channel:FireServer({ 
                cmd = "ClientExecuteCommand", command = commandInput.Title 
            })
            table.insert(commandHistory, commandInput.Title)
            commandInput.Title = ""
            
        elseif inputObj.KeyCode == Enum.KeyCode.PageDown.Value then
            if commandHistoryIndex < #commandHistory then
                commandHistoryIndex = commandHistoryIndex + 1
            end
            commandInput.Title = commandHistory[commandHistoryIndex]
        elseif inputObj.KeyCode == Enum.KeyCode.PageUp.Value then    
            if commandHistoryIndex > 1 then
                commandHistoryIndex = commandHistoryIndex - 1
            end
            commandInput.Title = commandHistory[commandHistoryIndex]
        elseif inputObj.KeyCode == Enum.KeyCode.F12.Value then
            if #commandHistory > 0 then
                local lastCommand = commandHistory[#commandHistory]
                gg.network_channel:FireServer({ 
                    cmd = "ClientExecuteCommand", command = lastCommand 
                })
                commandInput.Title = lastCommand
            end
        end
    end
end

UserInputService.InputBegan:Connect(inputBegan)