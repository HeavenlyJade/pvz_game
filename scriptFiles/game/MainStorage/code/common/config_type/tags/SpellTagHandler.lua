-- local MainStorage = game:GetService('MainStorage')
-- local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
-- local TagHandler = require(MainStorage.code.battle.TagHandler) ---@type TagHandler

-- ---@class SpellTag : TagHandler
-- local SpellTag = ClassMgr.Class("SpellTag", TagHandler)

-- function SpellTag:OnInit(data)
--     -- 初始化父类
--     TagHandler.OnInit(self, data)
    
--     -- 初始化SpellTag特有属性
--     self.affectSpellName = data["影响魔法"] or {} ---@type string[]
--     self.affectSpellKeyword = data["影响魔法关键字"] or "" ---@type string
--     self.powerIncrease = data["威力增加"] or 0 ---@type number
--     self.powerExpression = data["威力增加表达式"] or "" ---@type string
--     self.cancel = data["取消"] or false ---@type boolean
--     self.modifyValues = data["修改数值"] or {} ---@type OverrideValue[]
--     self.overrideParams = data["复写参数"] or {} ---@type OverrideParam[]
--     self.subSpell = data["释放魔法"] or {} ---@type SubSpell[]
--     self.subSpellInheritPower = data["释放魔法继承威力"] or false ---@type boolean
-- end

-- function SpellTag:CanTriggerReal(caster, target, castParam, param, log)
--     local spell = param[1] ---@type Spell
--     local spellParam = param[2] ---@type CastParam
    
--     -- 检查魔法关键字
--     if self.affectSpellKeyword ~= "" then
--         if not string.find(spell.魔法名, self.affectSpellKeyword) then
--             if self.printMessage then
--                 table.insert(log, string.format("%s.%s触发失败：魔法名%s不包含关键字%s", self.m_tagType.id, self.m_tagIndex, spell.魔法名, self.affectSpellKeyword))
--             end
--             return false
--         end
--     end
    
--     -- 检查影响魔法列表
--     if #self.affectSpellName > 0 then
--         local matchFound = false
--         for _, spellName in ipairs(self.affectSpellName) do
--             if spellName == spell.魔法名 then
--                 matchFound = true
--                 break
--             end
--         end
        
--         if not matchFound then
--             if self.printMessage then
--                 table.insert(log, string.format("%s.%s触发失败：魔法%s不在影响魔法列表中", self.m_tagType.id, self.m_tagIndex, spell.魔法名))
--             end
--             return false
--         end
--     end
    
--     return true
-- end

-- function SpellTag:TriggerReal(caster, target, castParam, param, log)
--     local spell = param[1] ---@type Spell
--     local spellParam = param[2] ---@type CastParam
    
--     -- 处理被释放魔法时的情况，交换施法者和目标
--     if self.m_trigger == "被释放魔法时" then
--         if not target.isEntity then return false end
--         local temp = caster
--         caster = target:GetCreature()
--         target = temp
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：交换攻受位置", self.m_tagType.id, self.m_tagIndex))
--         end
--     end
    
--     -- 处理取消魔法
--     if self.cancel then
--         spellParam.cancelled = true
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：取消魔法释放", self.m_tagType.id, self.m_tagIndex))
--         end
--     end
    
--     -- 应用威力加成
--     spellParam.power = spellParam.power * castParam.power
    
--     -- 处理威力增加
--     if self.powerIncrease ~= 0 then
--         local addPower = self.powerIncrease * (1 + castParam.power) / 100.0
--         spellParam.power = spellParam.power + addPower
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：增加%.2f%%威力", self.m_tagType.id, self.m_tagIndex, addPower * 100))
--         end
--     elseif self.powerExpression ~= "" then
--         local addPower = caster:CalculateValue(self.powerExpression, target:GetCreature(), self.printMessage) * (1 + castParam.power) / 100.0
--         spellParam.power = spellParam.power + addPower
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：增加%.2f%%威力", self.m_tagType.id, self.m_tagIndex, addPower * 100))
--         end
--     end
    
--     -- 合并额外修改数值
--     for key, modifier in pairs(castParam.extraModifiers) do
--         if not spellParam.extraModifiers[key] then
--             spellParam.extraModifiers[key] = ClassMgr.New("Battle", {caster, caster, key})
--         end
--         spellParam.extraModifiers[key]:AddDamageModifier(self.m_tagType.id, "增加", modifier:GetFinalDamage())
        
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：合并修改数值 %s", self.m_tagType.id, self.m_tagIndex, key))
--         end
--     end
    
--     -- 合并额外参数
--     for key, value in pairs(castParam.extraParams) do
--         spellParam.extraParams[key] = value
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：合并复写参数 %s = %s", self.m_tagType.id, self.m_tagIndex, key, tostring(value)))
--         end
--     end
    
--     -- 处理修改数值
--     for _, modifier in ipairs(self.modifyValues) do
--         if not modifier.paramName then goto continue end
        
--         local name
--         if not modifier.objectName or modifier.isAlways then
--             name = modifier.paramName
--         else
--             name = string.format("%s.%s", modifier.objectName, modifier.paramName)
--         end
        
--         if not spellParam.extraModifiers[name] then
--             spellParam.extraModifiers[name] = ClassMgr.New("Battle", {caster, caster, name})
--         end
        
--         spellParam.extraModifiers[name]:AddDamageModifier(
--             self.m_tagType.id, 
--             modifier.paramValue.增加类型, 
--             modifier.paramValue.倍率
--         )
        
--         if self.printMessage then
--             table.insert(log, string.format("%s.%s：修改%s的%s为%.2f", 
--                 self.m_tagType.id, self.m_tagIndex, 
--                 name, modifier.paramValue.增加类型, modifier.paramValue.倍率))
--         end
        
--         ::continue::
--     end
    
--     -- 处理复写参数
--     for _, modifier in ipairs(self.overrideParams) do
--         if not modifier.paramName then goto continue end
        
--         local name
--         if not modifier.objectName then
--             name = modifier.paramName
--         else
--             name = string.format("%s.%s", modifier.objectName, modifier.paramName)
--         end
        
--         local value = nil
--         if modifier.paramValue.intValue ~= 0 then
--             value = modifier.paramValue.intValue
--         elseif modifier.paramValue.floatValue ~= 0 then
--             value = modifier.paramValue.floatValue
--         elseif modifier.paramValue.stringValue ~= "" then
--             value = modifier.paramValue.stringValue
--         elseif modifier.paramValue.boolValue then
--             value = modifier.paramValue.boolValue
--         elseif modifier.paramValue.gameObjectValue then
--             value = modifier.paramValue.gameObjectValue
--         end
        
--         if value ~= nil then
--             spellParam.extraParams[name] = value
--             if self.printMessage then
--                 table.insert(log, string.format("%s.%s：复写%s为%s", 
--                     self.m_tagType.id, self.m_tagIndex, name, tostring(value)))
--             end
--         end
        
--         ::continue::
--     end
    
--     -- 处理额外释放魔法
--     if #self.subSpell > 0 then
--         local subParam = gg.clone(spellParam)
--         for _, tag in ipairs(castParam.skipTags) do
--             table.insert(subParam.skipTags, tag)
--         end
        
--         if not self.subSpellInheritPower then
--             subParam.power = 1.0
--         end
        
--         for _, subSpell in ipairs(self.subSpell) do
--             subSpell:Cast(caster, target, subParam)
--             if self.printMessage then
--                 table.insert(log, string.format("%s.%s：%s=>%s释放子魔法%s", 
--                     self.m_tagType.id, self.m_tagIndex, 
--                     tostring(caster), tostring(target), subSpell.魔法.魔法名))
--             end
--         end
--     end
    
--     return true
-- end

-- return SpellTag