local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local CustomUI = require(MainStorage.code.common.config_type.custom_ui.CustomUI)    ---@type CustomUI
local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
local gg = require(MainStorage.code.common.MGlobal)    ---@type gg

---@class PetGui:CustomUI
local PetGui = ClassMgr.Class("PetGui", CustomUI)

---@param data table
function PetGui:OnInit(data)

end

-- 服务端进入
function PetGui:S_BuildPacket(player, packet)

end

-----------------客户端
-- 客户端进入
function PetGui:C_BuildUI(packet)
    local PetUi = self.view
    local paths = self.paths
    gg.log(paths)
    PetUi:Get(paths.CloseButton, ViewButton).clickCb = function (ui, button)
        self.view:Close()
    end
end

return PetGui