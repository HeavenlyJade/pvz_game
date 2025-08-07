local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local Spell = require(MainStorage.code.server.spells.Spell) ---@type Spell
local CastParam = require(MainStorage.code.server.spells.CastParam) ---@type CastParam

---@class CommandSpell:Spell
---@field commands string[] 指令列表
local CommandSpell = ClassMgr.Class("CommandSpell", Spell)

function CommandSpell:OnInit(data)
    self.commands = data["指令"] ---@type string[]
    if self.printInfo then
        print(string.format("CommandSpell[%s] 初始化，指令数量: %d", self.spellName, self.commands and #self.commands or 0))
    end
end

--- 实际执行魔法
---@param caster Entity 施法者
---@param target Entity 目标
---@param param CastParam 参数
---@return boolean 是否成功释放
function CommandSpell:CastReal(caster, target, param)
    if not self.commands or #self.commands == 0 then
        if param.printInfo then
            caster:SendLog(string.format("CommandSpell[%s] 没有可执行的指令", self.spellName))
        end
        return false
    end

    if param.printInfo then
        caster:SendLog(string.format("CommandSpell[%s] 开始执行指令，施法者: %s, 目标: %s", 
            self.spellName, 
            caster.name or "未知", 
            target and target.name or "无目标"))
    end

    local anySucceed = false ---@type boolean|nil
    for i, command in ipairs(self.commands) do
        -- 执行指令
        local success = caster:ExecuteCommand(command, target, param)
        if param.printInfo then
            caster:SendLog(string.format("CommandSpell[%s] 执行第 %d 个指令: %s, 结果: %s", 
                self.spellName, 
                i, 
                command, 
                success and "成功" or "失败"))
        end
        anySucceed = anySucceed or success
    end

    if param.printInfo then
        caster:SendLog(string.format("CommandSpell[%s] 指令执行完成，总体结果: %s", 
            self.spellName, 
            anySucceed and "成功" or "失败"))
    end

    return anySucceed
end

return CommandSpell