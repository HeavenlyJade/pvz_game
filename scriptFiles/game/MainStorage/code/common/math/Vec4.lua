local MainStorage = game:GetService("MainStorage")
local MathDefines = require(MainStorage.code.common.math.MathDefines)
local Vec4 = {}

--实例化
function Vec4.new(x, y, z, w)
    local obj = {}
    obj.x = x or 0
    obj.y = y or 0
    obj.z = z or 0
    obj.w = w or 0
    Vec4.__index = Vec4
    setmetatable(obj, Vec4)
    return obj
end

function Vec4.zero()
    return Vec4.new(0, 0, 0, 0)
end

function Vec4.one()
    return Vec4.new(1, 1, 1, 1)
end

---------------------------------运算符重载-------------------------------
--加
function Vec4.__add(lhs, rhs)
    return Vec4.new(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z, lhs.w + rhs.w)
end

--减
function Vec4.__sub(lhs, rhs)
    return Vec4.new(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z, lhs.w - rhs.w)
end

--乘
function Vec4.__mul(lhs, rhs)
    if rhs == nil then
        return Vec4.new(lhs.x, lhs.y, lhs.z, lhs.w)
    end
    if type(lhs) == "number" then
        return Vec4.new(lhs * rhs.x, lhs * rhs.y, lhs * rhs.z, lhs * rhs.w)
    elseif type(rhs) == "number" then
        return Vec4.new(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs, lhs.w * rhs)
    else
        return Vec4.new(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z, lhs.w * rhs.w)
    end
end

--除
function Vec4.__div(lhs, rhs)
    if type(rhs) == "number" then
        return Vec4.new(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs, lhs.w / rhs)
    else
        return Vec4.new(lhs.x / rhs.x, lhs.y / rhs.y, lhs.z / rhs.z, lhs.w / rhs.w)
    end
end

--字符串
function Vec4.__tostring(v)
    return string.format("(%f, %f, %f, %f)", v.x, v.y, v.z, v.w)
end

--取元素
function Vec4.__index(t, k)
    if k == 1 then
        return t.x
    elseif k == 2 then
        return t.y
    elseif k == 3 then
        return t.z
    elseif k == 4 then
        return t.w
    end
end

--设置元素
function Vec4.__newindex(t, k, v)
    if k == 1 then
        t.x = v
    elseif k == 2 then
        t.y = v
    elseif k == 3 then
        t.z = v
    elseif k == 4 then
        t.w = v
    end
end

---------------------------------数学运算-------------------------------

--点乘
function Vec4:Dot(rhs)
    return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z + self.w * rhs.w
end

--获取插值向量
function Vec4:Lerp(to, t)
    return self + (to - self) * t
end

--取反
function Vec4:Negate()
    return Vec4.new(-self.x, -self.y, -self.z, -self.w)
end

--长度是否为0
function Vec4:IsZero()
    --接近0即可
    local r = 0.01
    return math.abs(self.x) < r and math.abs(self.y) < r and math.abs(self.z) < r and math.abs(self.w) < r
end

--是否有无效值
function Vec4:IsNaN()
    return self.x ~= self.x or self.y ~= self.y or self.z ~= self.z or self.w ~= self.w
end

--判断是否相等,接近0即可
function Vec4:Equals(other)
    local r = 0.01
    return math.abs(self.x - other.x) < r and math.abs(self.y - other.y) < r and math.abs(self.z - other.z) < r and
        math.abs(self.w - other.w) < r
end

--转换成表
function Vec4:ToTable()
    return {self.x, self.y, self.z, self.w}
end

--从表创建
function Vec4:FromTable(t)
    self.x = t[1]
    self.y = t[2]
    self.z = t[3]
    self.w = t[4]
end

--拷贝
function Vec4:Clone()
    return Vec4.new(self.x, self.y, self.z, self.w)
end

return Vec4
