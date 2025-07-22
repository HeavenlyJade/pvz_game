local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr

---@class Dict<K, V>:Class
local Dict = ClassMgr.Class("Dict")

function Dict:OnInit(init)
    self._data = init or {}
    self.size = 0
    for _ in pairs(self._data) do self.size = self.size + 1 end
end

function Dict:Add(key, value)
    if self._data[key] == nil then self.size = self.size + 1 end
    self._data[key] = value
end

function Dict:Remove(key)
    if self._data[key] ~= nil then self.size = self.size - 1 end
    self._data[key] = nil
end

function Dict:ContainsKey(key)
    return self._data[key] ~= nil
end

function Dict:ContainsValue(val)
    for _, v in pairs(self._data) do
        if v == val then return true end
    end
    return false
end

function Dict:Keys()
    local t = {}
    for k in pairs(self._data) do table.insert(t, k) end
    return t
end

function Dict:Values()
    local t = {}
    for _, v in pairs(self._data) do table.insert(t, v) end
    return t
end

function Dict:ForEach(fn)
    for k, v in pairs(self._data) do fn(k, v) end
end

function Dict:Where(fn)
    local t = Dict.New()
    for k, v in pairs(self._data) do if fn(k, v) then t:Add(k, v) end end
    return t
end

function Dict:Select(fn)
    local t = {}
    for k, v in pairs(self._data) do table.insert(t, fn(k, v)) end
    return t
end

function Dict:Any(fn)
    for k, v in pairs(self._data) do if fn(k, v) then return true end end
    return false
end

function Dict:All(fn)
    for k, v in pairs(self._data) do if not fn(k, v) then return false end end
    return true
end

function Dict:ToTable()
    local t = {}
    for k, v in pairs(self._data) do t[k] = v end
    return t
end

function Dict:Clear()
    self._data = {}
    self.size = 0
end

function Dict:Count()
    return self.size
end

function Dict:First()
    for _, v in pairs(self._data) do return v end
    return nil
end

function Dict:Last()
    local last = nil
    for _, v in pairs(self._data) do last = v end
    return last
end

return Dict 