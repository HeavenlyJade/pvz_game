local MainStorage  = game:GetService('MainStorage')
local ClientCustomUI      = require(MainStorage.code.common.config_type.custom_ui.ClientCustomUI)    ---@type ClientCustomUI
return ClientCustomUI.Load(script.Parent)