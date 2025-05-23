local Mat3 = {}

--实例化
function Mat3.new(m00, m01, m02, m10, m11, m12, m20, m21, m22)
    local obj = {}
    Mat3.__index = Mat3
    setmetatable(obj, Mat3)
    obj:SetData(m00, m01, m02, m10, m11, m12, m20, m21, m22)
    return obj
end

--设置单位矩阵
function Mat3:SetIdentity()
    self.m00 = 1
    self.m01 = 0
    self.m02 = 0
    self.m10 = 0
    self.m11 = 1
    self.m12 = 0
    self.m20 = 0
    self.m21 = 0
    self.m22 = 1
end

--设置零矩阵
function Mat3:SetZero()
    self.m00 = 0
    self.m01 = 0
    self.m02 = 0
    self.m10 = 0
    self.m11 = 0
    self.m12 = 0
    self.m20 = 0
    self.m21 = 0
    self.m22 = 0
end

--设置
function Mat3:SetData(m00, m01, m02, m10, m11, m12, m20, m21, m22)
    self.m00 = m00 or 1
    self.m01 = m01 or 0
    self.m02 = m02 or 0
    self.m10 = m10 or 0
    self.m11 = m11 or 1
    self.m12 = m12 or 0
    self.m20 = m20 or 0
    self.m21 = m21 or 0
    self.m22 = m22 or 1
end

---------------------------------运算符重载-------------------------------

--加
function Mat3.__add(lhs, rhs)
    return Mat3.new(
        lhs.m00 + rhs.m00, lhs.m01 + rhs.m01, lhs.m02 + rhs.m02,
        lhs.m10 + rhs.m10, lhs.m11 + rhs.m11, lhs.m12 + rhs.m12,
        lhs.m20 + rhs.m20, lhs.m21 + rhs.m21, lhs.m22 + rhs.m22
    )
end

--减
function Mat3.__sub(lhs, rhs)
    return Mat3.new(
        lhs.m00 - rhs.m00, lhs.m01 - rhs.m01, lhs.m02 - rhs.m02,
        lhs.m10 - rhs.m10, lhs.m11 - rhs.m11, lhs.m12 - rhs.m12,
        lhs.m20 - rhs.m20, lhs.m21 - rhs.m21, lhs.m22 - rhs.m22
    )
end

--乘
function Mat3.__mul(lhs, rhs)
    if type(lhs) == "number" then
        return Mat3.new(
            lhs * rhs.m00, lhs * rhs.m01, lhs * rhs.m02,
            lhs * rhs.m10, lhs * rhs.m11, lhs * rhs.m12,
            lhs * rhs.m20, lhs * rhs.m21, lhs * rhs.m22
        )
    elseif type(rhs) == "number" then
        return Mat3.new(
            lhs.m00 * rhs, lhs.m01 * rhs, lhs.m02 * rhs,
            lhs.m10 * rhs, lhs.m11 * rhs, lhs.m12 * rhs,
            lhs.m20 * rhs, lhs.m21 * rhs, lhs.m22 * rhs
        )
    else
        return Mat3.new(
            lhs.m00 * rhs.m00 + lhs.m01 * rhs.m10 + lhs.m02 * rhs.m20,
            lhs.m00 * rhs.m01 + lhs.m01 * rhs.m11 + lhs.m02 * rhs.m21,
            lhs.m00 * rhs.m02 + lhs.m01 * rhs.m12 + lhs.m02 * rhs.m22,
            lhs.m10 * rhs.m00 + lhs.m11 * rhs.m10 + lhs.m12 * rhs.m20,
            lhs.m10 * rhs.m01 + lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21,
            lhs.m10 * rhs.m02 + lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22,
            lhs.m20 * rhs.m00 + lhs.m21 * rhs.m10 + lhs.m22 * rhs.m20,
            lhs.m20 * rhs.m01 + lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21,
            lhs.m20 * rhs.m02 + lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22
        )
    end
end

--除
function Mat3.__div(lhs, rhs)
    if type(rhs) == "number" then
        return Mat3.new(
            lhs.m00 / rhs, lhs.m01 / rhs, lhs.m02 / rhs,
            lhs.m10 / rhs, lhs.m11 / rhs, lhs.m12 / rhs,
            lhs.m20 / rhs, lhs.m21 / rhs, lhs.m22 / rhs
        )
    else
        return Mat3.new(
            lhs.m00 / rhs.m00, lhs.m01 / rhs.m01, lhs.m02 / rhs.m02,
            lhs.m10 / rhs.m10, lhs.m11 / rhs.m11, lhs.m12 / rhs.m12,
            lhs.m20 / rhs.m20, lhs.m21 / rhs.m21, lhs.m22 / rhs.m22
        )
    end
end

--负
function Mat3.__unm(v)
    return Mat3.new(
        -v.m00, -v.m01, -v.m02,
        -v.m10, -v.m11, -v.m12,
        -v.m20, -v.m21, -v.m22
    )
end

--等于
function Mat3.__eq(lhs, rhs)
    return lhs.m00 == rhs.m00 and lhs.m01 == rhs.m01 and lhs.m02 == rhs.m02 and
           lhs.m10 == rhs.m10 and lhs.m11 == rhs.m11 and lhs.m12 == rhs.m12 and
           lhs.m20 == rhs.m20 and lhs.m21 == rhs.m21 and lhs.m22 == rhs.m22
end

--转字符串
function Mat3:__tostring()
    return string.format(
        "[[%f, %f, %f], [%f, %f, %f], [%f, %f, %f]]",
        self.m00, self.m01, self.m02,
        self.m10, self.m11, self.m12,
        self.m20, self.m21, self.m22
    )
end


--取元素
function Mat3:Get(row, col)
    return self["m"..row..col]
end

--设置元素
function Mat3:Set(row, col, value)
    self["m"..row..col] = value
end

--转置
function Mat3:Transpose()
    self.m01, self.m10 = self.m10, self.m01
    self.m02, self.m20 = self.m20, self.m02
    self.m12, self.m21 = self.m21, self.m12
end

--求逆
function Mat3:Inverse()
    local det = self.m00 * (self.m11 * self.m22 - self.m12 * self.m21) -
                self.m01 * (self.m10 * self.m22 - self.m12 * self.m20) +
                self.m02 * (self.m10 * self.m21 - self.m11 * self.m20)
    if det == 0 then
        return false
    end
    local invDet = 1 / det
    local m00 = (self.m11 * self.m22 - self.m12 * self.m21) * invDet
    local m01 = (self.m02 * self.m21 - self.m01 * self.m22) * invDet
    local m02 = (self.m01 * self.m12 - self.m02 * self.m11) * invDet
    local m10 = (self.m12 * self.m20 - self.m10 * self.m22) * invDet
    local m11 = (self.m00 * self.m22 - self.m02 * self.m20) * invDet
    local m12 = (self.m02 * self.m10 - self.m00 * self.m12) * invDet
    local m20 = (self.m10 * self.m21 - self.m11 * self.m20) * invDet
    local m21 = (self.m01 * self.m20 - self.m00 * self.m21) * invDet
    local m22 = (self.m00 * self.m11 - self.m01 * self.m10) * invDet
    self:SetData(m00, m01, m02, m10, m11, m12, m20, m21, m22)
    return true
end
--设置平移
function Mat3:SetTranslate(tx, ty)
    self.m02 = tx
    self.m12 = ty
end
--设置缩放
function Mat3:SetScale(sx, sy)
    self.m00 = sx
    self.m11 = sy
end
--设置旋转
function Mat3:SetRotate(angle)
    local radian = math.rad(angle)
    local c = math.cos(radian)
    local s = math.sin(radian)
    self.m00 = c
    self.m01 = -s
    self.m10 = s
    self.m11 = c
end

--获取平移
function Mat3:GetTranslate()
    return self.m02, self.m12
end

--获取缩放
function Mat3:GetScale()
    return self.m00, self.m11
end

--获取旋转
function Mat3:GetRotate()
    return math.deg(math.atan2(self.m10, self.m00))
end

--矩阵乘向量
function Mat3:MulVec2(v)
    return Vec2.new(
        self.m00 * v.x + self.m01 * v.y + self.m02,
        self.m10 * v.x + self.m11 * v.y + self.m12
    )
end

--矩阵乘矩阵
function Mat3:MulMat3(m)
    return Mat3.new(
        self.m00 * m.m00 + self.m01 * m.m10 + self.m02 * m.m20,
        self.m00 * m.m01 + self.m01 * m.m11 + self.m02 * m.m21,
        self.m00 * m.m02 + self.m01 * m.m12 + self.m02 * m.m22,
        self.m10 * m.m00 + self.m11 * m.m10 + self.m12 * m.m20,
        self.m10 * m.m01 + self.m11 * m.m11 + self.m12 * m.m21,
        self.m10 * m.m02 + self.m11 * m.m12 + self.m12 * m.m22,
        self.m20 * m.m00 + self.m21 * m.m10 + self.m22 * m.m20,
        self.m20 * m.m01 + self.m21 * m.m11 + self.m22 * m.m21,
        self.m20 * m.m02 + self.m21 * m.m12 + self.m22 * m.m22
    )
end

function Mat3:Scaled(scale)
    local res = Mat3.new()
    res:SetData(
        self.m00 * scale.x,
        self.m01 * scale.y,
        self.m02 * scale.z,
        self.m10 * scale.x,
        self.m11 * scale.y,
        self.m12 * scale.z,
        self.m20 * scale.x,
        self.m21 * scale.y,
        self.m22 * scale.z
    )
    return res
end
    

--拷贝
function Mat3:Clone()
    return Mat3.new(
        self.m00, self.m01, self.m02,
        self.m10, self.m11, self.m12,
        self.m20, self.m21, self.m22
    )
end


return Mat3