local MainStorage  = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local ItemRankConfig = require(MainStorage.config.ItemRankConfig) ---@type ItemRankConfig
local gg              = require(MainStorage.code.common.MGlobal) ---@type gg

-- ItemType class
---@class CustomUI:Class
---@field New fun( data:table ):CustomUI
local CustomUI = ClassMgr.Class("CustomUI")

--[[
使用方法：
1. 在UI下新建一个LocalScript，名字随意，将下列代码粘贴进去：
local MainStorage  = game:GetService('MainStorage')
local ClientCustomUI      = require(MainStorage.code.common.config_type.custom_ui.ClientCustomUI)    ---@type ClientCustomUI
return ClientCustomUI.Load(script.Parent)
2. 在Unity下新建一个自定义UI，其中的"UI名"填UI控件的名字
3. 在本目录下新建一个ModuleScript，名字为UI控件的名字。继承CustomUI
    然后在其中实现 
        S_BuildPacket（服务端构建给客户端的包体 ）
        C_BuildUI（客户端收到包体，刷新UI控件）
    客户端 > 服务端的通信可使用 ：
        function OnlineRewardsUI:OnClickReward(player, packet)
            //服务端处理事件的回调
        end
        self:C_SendEvent("OnClickReward", {
            index = button.index
        })
]]
function CustomUI.Load(data)
    local uiClass = require(MainStorage.code.common.config_type.custom_ui[data["UI名"]])
    return uiClass.New(data)
end

function CustomUI:OnInit(data)
    self.id = data["ID"]
    self.uiName = data["UI名"]
    self.usingVars = data["使用变量"]
    self.miscData = data
    self._serverInited = false
    self.view = nil ---@type ViewBase
    self.paths = {}
end

--服务端构建要发给客户端的包体，一般是加入界面需要的信息
function CustomUI:S_BuildPacket(player, packet)
    
end

---@param text string 提示文本
---@param player? Player 仅服务端调用时：发送给的玩家
function CustomUI:SendHoverText(text, playerIfServer)
    if gg.isServer then
        if not playerIfServer then
            return
        end
        playerIfServer:SendHoverText(text)
    else
        local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
        ViewBase.GetUI("HoverTextHud"):ShowText(text)
    end
end

---@param player Player
function CustomUI:S_Open(player,item_name)
    if not self._serverInited then
        self._serverInited = true
        local ServerEventManager = require(MainStorage.code.server.event.ServerEventManager) ---@type ServerEventManager
        ServerEventManager.Subscribe("CustomUIEvent_".. self.id, function (evt)
            if evt.__func then
                self[evt.__func](self, evt.player, evt)
            end
        end)
    end
    local packet = {
        id = self.id,
        uiName = self.uiName,
        item_name = item_name
    }
    self:S_BuildPacket(player, packet)
    player:SendEvent("ViewCustomUI"..self.uiName, packet)
end

--初始化UI控件
function CustomUI:C_InitUI()
    
end

--客户端收到包体，初始化界面。注意，界面元素的初始化也在这里面
--获取元素请使用 self.view:Get！ 它有缓存，对多次调用有优化。绝不可直接 ViewList.New()!
function CustomUI:C_BuildUI(packet)
    
end

function CustomUI:C_SendEvent(func, packet)
    local ClientEventManager = require(MainStorage.code.client.event.ClientEventManager) ---@type ClientEventManager
    packet.__func = func
    print("call", self.className, "CustomUIEvent_".. self.id)
    ClientEventManager.SendToServer("CustomUIEvent_".. self.id, packet)
end

return CustomUI