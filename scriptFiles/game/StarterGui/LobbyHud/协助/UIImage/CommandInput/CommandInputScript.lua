local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.code.common.MGlobal)            ---@type gg

local commandInput = script.Parent ---@type UITextInput
local uiImage = commandInput.Parent ---@type UIImage
local localPlayer = game.Players.LocalPlayer

if not gg.opUin[localPlayer.UserId] then
    commandInput.Visible = false
    uiImage.Visible = false
else
    commandInput.Visible = true
    uiImage.Visible = true
end

local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
local UserInputService = game:GetService("UserInputService") ---@type UserInputService

local commandHistory = {}
local commandHistoryIndex = 1

local function inputBegan( inputObj, bGameProcessd )
	if inputObj.UserInputType == Enum.UserInputType.Keyboard.Value then
        ClientEventManager.Publish("PressKey", {
            key = inputObj.KeyCode,
            isDown = true
        })
    elseif inputObj.UserInputType == Enum.UserInputType.MouseButton2.Value then
            ClientEventManager.Publish("MouseButton", {
                right = true,
                isDown = true
            })
    elseif inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
            ClientEventManager.Publish("MouseButton", {
                right = false,
                isDown = true
            })
    end
end
local function inputEnded( inputObj, bGameProcessd )
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
        else
            ClientEventManager.Publish("PressKey", {
                key = inputObj.KeyCode,
                isDown = false
            })
        end
    elseif inputObj.UserInputType == Enum.UserInputType.MouseButton2.Value then
            ClientEventManager.Publish("MouseButton", {
                right = true,
                isDown = false
            })
    elseif inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
            ClientEventManager.Publish("MouseButton", {
                right = false,
                isDown = false
            })
    end
end
local function inputChanged( inputObj, bGameProcessd )
    if inputObj.UserInputType == Enum.UserInputType.MouseWheel.Value then
        ClientEventManager.Publish("MouseScroll", {
            isDown = inputObj.Position.z == 1
        })
    elseif inputObj.UserInputType == Enum.UserInputType.MouseMovement.Value then
        ClientEventManager.Publish("MouseMove", {
            x = inputObj.Position.X,
            y = inputObj.Position.Y
        })
    end
end

UserInputService.InputBegan:Connect(inputBegan)
UserInputService.InputEnded:Connect(inputEnded)
UserInputService.InputChanged:Connect(inputChanged)