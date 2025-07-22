local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr

---@class Dict<K, V>:Class
local Dict = ClassMgr.Class("Dict")

---@generic K, V
---@param init table<K, V>?
function Dict:OnInit(init)
    self._data = init or {}
    self.size = 0
    for _ in pairs(self._data) do self.size = self.size + 1 end
end

---@generic K, V
---@param key K
---@param value V
function Dict:Add(key, value)
    if self._data[key] == nil then self.size = self.size + 1 end
    self._data[key] = value
end

---@generic K, V
---@param key K
function Dict:Remove(key)
    if self._data[key] ~= nil then self.size = self.size - 1 end
    self._data[key] = nil
end

---@generic K, V
---@param key K
---@return boolean
function Dict:ContainsKey(key)
    return self._data[key] ~= nil
end

---@generic K, V
---@param val V
---@return boolean
function Dict:ContainsValue(val)
    for _, v in pairs(self._data) do
        if v == val then return true end
    end
    return false
end

---@generic K, V
---@return K[]
function Dict:Keys()
    local t = {}
    for k in pairs(self._data) do table.insert(t, k) end
    return t
end

---@generic K, V
---@return V[]
function Dict:Values()
    local t = {}
    for _, v in pairs(self._data) do table.insert(t, v) end
    return t
end

---@generic K, V
---@param fn fun(key:K, value:V)
function Dict:ForEach(fn)
    for k, v in pairs(self._data) do fn(k, v) end
end

---@generic K, V
---@param fn fun(key:K, value:V):boolean
---@return Dict<K, V>
function Dict:Where(fn)
    local t = Dict.New()
    for k, v in pairs(self._data) do if fn(k, v) then t:Add(k, v) end end
    return t
end

---@generic K, V
---@param fn fun(key:K, value:V):any
---@return any[]
function Dict:Select(fn)
    local t = {}
    for k, v in pairs(self._data) do table.insert(t, fn(k, v)) end
    return t
end

---@generic K, V
---@param fn fun(key:K, value:V):boolean
---@return boolean
function Dict:Any(fn)
    for k, v in pairs(self._data) do if fn(k, v) then return true end end
    return false
end

---@generic K, V
---@param fn fun(key:K, value:V):boolean
---@return boolean
function Dict:All(fn)
    for k, v in pairs(self._data) do if not fn(k, v) then return false end end
    return true
end

---@generic K, V
---@return table<K, V>
function Dict:ToTable()
    local t = {}
    for k, v in pairs(self._data) do t[k] = v end
    return t
end

function Dict:Clear()
    self._data = {}
    self.size = 0
end

---@return integer
function Dict:Count()
    return self.size
end

---@generic K, V
---@return V|nil
function Dict:First()
    for _, v in pairs(self._data) do return v end
    return nil
end

---@generic K, V
---@return V|nil
function Dict:Last()
    local last = nil
    for _, v in pairs(self._data) do last = v end
    return last
end

return Dict 