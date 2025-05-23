local MainStorage = game:GetService("MainStorage")
local Vec3 = require(MainStorage.code.common.math.Vec3)
local Vec4 = require(MainStorage.code.common.math.Vec4)
local Mat4 = {}

--实例化
function Mat4.new()
    local obj = {}
    Mat4.__index = Mat4
    setmetatable(obj, Mat4)
    obj:SetIdentity()
    return obj
end

--设置单位矩阵
function Mat4:SetIdentity()
    self:SetData(
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    )
end

--设置
function Mat4:SetData(m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33)
    self.m00 = m00
    self.m01 = m01
    self.m02 = m02
    self.m03 = m03
    self.m10 = m10
    self.m11 = m11
    self.m12 = m12
    self.m13 = m13
    self.m20 = m20
    self.m21 = m21
    self.m22 = m22
    self.m23 = m23
    self.m30 = m30
    self.m31 = m31
    self.m32 = m32
    self.m33 = m33
end

--矩阵乘法
function Mat4:Mul(mat)
    local res = Mat4.new()
    res.m00 = self.m00 * mat.m00 + self.m01 * mat.m10 + self.m02 * mat.m20 + self.m03 * mat.m30
    res.m01 = self.m00 * mat.m01 + self.m01 * mat.m11 + self.m02 * mat.m21 + self.m03 * mat.m31
    res.m02 = self.m00 * mat.m02 + self.m01 * mat.m12 + self.m02 * mat.m22 + self.m03 * mat.m32
    res.m03 = self.m00 * mat.m03 + self.m01 * mat.m13 + self.m02 * mat.m23 + self.m03 * mat.m33
    res.m10 = self.m10 * mat.m00 + self.m11 * mat.m10 + self.m12 * mat.m20 + self.m13 * mat.m30
    res.m11 = self.m10 * mat.m01 + self.m11 * mat.m11 + self.m12 * mat.m21 + self.m13 * mat.m31
    res.m12 = self.m10 * mat.m02 + self.m11 * mat.m12 + self.m12 * mat.m22 + self.m13 * mat.m32
    res.m13 = self.m10 * mat.m03 + self.m11 * mat.m13 + self.m12 * mat.m23 + self.m13 * mat.m33
    res.m20 = self.m20 * mat.m00 + self.m21 * mat.m10 + self.m22 * mat.m20 + self.m23 * mat.m30
    res.m21 = self.m20 * mat.m01 + self.m21 * mat.m11 + self.m22 * mat.m21 + self.m23 * mat.m31
    res.m22 = self.m20 * mat.m02 + self.m21 * mat.m12 + self.m22 * mat.m22 + self.m23 * mat.m32
    res.m23 = self.m20 * mat.m03 + self.m21 * mat.m13 + self.m22 * mat.m23 + self.m23 * mat.m33
    res.m30 = self.m30 * mat.m00 + self.m31 * mat.m10 + self.m32 * mat.m20 + self.m33 * mat.m30
    res.m31 = self.m30 * mat.m01 + self.m31 * mat.m11 + self.m32 * mat.m21 + self.m33 * mat.m31
    res.m32 = self.m30 * mat.m02 + self.m31 * mat.m12 + self.m32 * mat.m22 + self.m33 * mat.m32
    res.m33 = self.m30 * mat.m03 + self.m31 * mat.m13 + self.m32 * mat.m23 + self.m33 * mat.m33
    return res
end
--矩阵乘向量
function Mat4:MulVec3(rhs)
    local res = Vec3.new()
    local invW = 1.0 / (self.m30 * rhs.x + self.m31 * rhs.y + self.m32 * rhs.z + self.m33)

    res.x = (self.m00 * rhs.x + self.m01 * rhs.y + self.m02 * rhs.z + self.m03) * invW
    res.y = (self.m10 * rhs.x + self.m11 * rhs.y + self.m12 * rhs.z + self.m13) * invW
    res.z = (self.m20 * rhs.x + self.m21 * rhs.y + self.m22 * rhs.z + self.m23) * invW

    return res
end

function Mat4:MulVec4(rhs)
    local res = Vec4.new()
    res.x = self.m00 * rhs.x + self.m01 * rhs.y + self.m02 * rhs.z + self.m03 * rhs.w
    res.y = self.m10 * rhs.x + self.m11 * rhs.y + self.m12 * rhs.z + self.m13 * rhs.w
    res.z = self.m20 * rhs.x + self.m21 * rhs.y + self.m22 * rhs.z + self.m23 * rhs.w
    res.w = self.m30 * rhs.x + self.m31 * rhs.y + self.m32 * rhs.z + self.m33 * rhs.w
    return res
end


function Mat4:MulMat3x4(rhs)
    local res = Mat4.new()
    res.m00 = self.m00 * rhs.m00 + self.m01 * rhs.m10 + self.m02 * rhs.m20
    res.m01 = self.m00 * rhs.m01 + self.m01 * rhs.m11 + self.m02 * rhs.m21
    res.m02 = self.m00 * rhs.m02 + self.m01 * rhs.m12 + self.m02 * rhs.m22
    res.m03 = self.m00 * rhs.m03 + self.m01 * rhs.m13 + self.m02 * rhs.m23 + self.m03
    res.m10 = self.m10 * rhs.m00 + self.m11 * rhs.m10 + self.m12 * rhs.m20
    res.m11 = self.m10 * rhs.m01 + self.m11 * rhs.m11 + self.m12 * rhs.m21
    res.m12 = self.m10 * rhs.m02 + self.m11 * rhs.m12 + self.m12 * rhs.m22
    res.m13 = self.m10 * rhs.m03 + self.m11 * rhs.m13 + self.m12 * rhs.m23 + self.m13
    res.m20 = self.m20 * rhs.m00 + self.m21 * rhs.m10 + self.m22 * rhs.m20
    res.m21 = self.m20 * rhs.m01 + self.m21 * rhs.m11 + self.m22 * rhs.m21
    res.m22 = self.m20 * rhs.m02 + self.m21 * rhs.m12 + self.m22 * rhs.m22
    res.m23 = self.m20 * rhs.m03 + self.m21 * rhs.m13 + self.m22 * rhs.m23 + self.m23
    res.m30 = self.m30 * rhs.m00 + self.m31 * rhs.m10 + self.m32 * rhs.m20
    res.m31 = self.m30 * rhs.m01 + self.m31 * rhs.m11 + self.m32 * rhs.m21
    res.m32 = self.m30 * rhs.m02 + self.m31 * rhs.m12 + self.m32 * rhs.m22
    res.m33 = self.m30 * rhs.m03 + self.m31 * rhs.m13 + self.m32 * rhs.m23 + self.m33
    return res
end


---------------------------------运算符重载-------------------------------
function Mat4.__add(lhs, rhs)
    local res = Mat4.new()
    res.m00 = lhs.m00 + rhs.m00
    res.m01 = lhs.m01 + rhs.m01
    res.m02 = lhs.m02 + rhs.m02
    res.m03 = lhs.m03 + rhs.m03
    res.m10 = lhs.m10 + rhs.m10
    res.m11 = lhs.m11 + rhs.m11
    res.m12 = lhs.m12 + rhs.m12
    res.m13 = lhs.m13 + rhs.m13
    res.m20 = lhs.m20 + rhs.m20
    res.m21 = lhs.m21 + rhs.m21
    res.m22 = lhs.m22 + rhs.m22
    res.m23 = lhs.m23 + rhs.m23
    res.m30 = lhs.m30 + rhs.m30
    res.m31 = lhs.m31 + rhs.m31
    res.m32 = lhs.m32 + rhs.m32
    res.m33 = lhs.m33 + rhs.m33
    return res
end

function Mat4.__sub(lhs, rhs)
    local res = Mat4.new()
    res.m00 = lhs.m00 - rhs.m00
    res.m01 = lhs.m01 - rhs.m01
    res.m02 = lhs.m02 - rhs.m02
    res.m03 = lhs.m03 - rhs.m03
    res.m10 = lhs.m10 - rhs.m10
    res.m11 = lhs.m11 - rhs.m11
    res.m12 = lhs.m12 - rhs.m12
    res.m13 = lhs.m13 - rhs.m13
    res.m20 = lhs.m20 - rhs.m20
    res.m21 = lhs.m21 - rhs.m21
    res.m22 = lhs.m22 - rhs.m22
    res.m23 = lhs.m23 - rhs.m23
    res.m30 = lhs.m30 - rhs.m30
    res.m31 = lhs.m31 - rhs.m31
    res.m32 = lhs.m32 - rhs.m32
    res.m33 = lhs.m33 - rhs.m33
    return res
end
--乘
function Mat4.__mul(lhs, rhs)
    if rhs.x and rhs.y and rhs.z and rhs.w then
        return lhs:MulVec4(rhs)
    elseif rhs.x and rhs.y and rhs.z then
        return lhs:MulVec3(rhs)
    elseif rhs.m33 then
        return lhs:Mul(rhs)
    elseif rhs.m23 then
        return lhs:MulMat3x4(rhs)
    end
end

function Mat4:__tostring()
    return string.format(
        "[[%f, %f, %f, %f], [%f, %f, %f, %f], [%f, %f, %f, %f], [%f, %f, %f, %f]]",
        self.m00, self.m01, self.m02, self.m03,
        self.m10, self.m11, self.m12, self.m13,
        self.m20, self.m21, self.m22, self.m23,
        self.m30, self.m31, self.m32, self.m33
    )
end
--设置平移
function Mat4:SetTranslation(x, y, z)
    if type(x) == "table" then
        x, y, z = x.x, x.y, x.z
    end
    self.m03 = x
    self.m13 = y
    self.m23 = z
end

function Mat4:GetTranslation()
    return Vec3.new(self.m03, self.m13, self.m23)
end

--设置旋转
function Mat4:SetRotation(rotation)
    if rotation.x and rotation.y and rotation.z and rotation.w then
        rotation = rotation:ToMat3()
    end
    self.m00 = rotation.m00
    self.m01 = rotation.m01
    self.m02 = rotation.m02
    self.m10 = rotation.m10
    self.m11 = rotation.m11
    self.m12 = rotation.m12
    self.m20 = rotation.m20
    self.m21 = rotation.m21
    self.m22 = rotation.m22
end
--获取旋转，返回四元数
function Mat4:GetRotation()
    local mat3 = Mat3.new(self.m00, self.m01, self.m02,
                    self.m10, self.m11, self.m12,
                    self.m20, self.m21, self.m22)
    local quat = Quat.new()
    quat:FromMat3(mat3)
    return quat
end
--设置缩放
function Mat4:SetScale(x, y, z)
    if type(x) == "table" then
        x, y, z = x.x, x.y, x.z
    end
    self.m00 = x
    self.m11 = y
    self.m22 = z
end

function Mat4:GetScale()
    return Vec3.new(self.m00, self.m11, self.m22)
end

--逆矩阵
function Mat4:Inverse()
    local v0 = self.m20 * self.m31 - self.m21 * self.m30
    local v1 = self.m20 * self.m32 - self.m22 * self.m30
    local v2 = self.m20 * self.m33 - self.m23 * self.m30
    local v3 = self.m21 * self.m32 - self.m22 * self.m31
    local v4 = self.m21 * self.m33 - self.m23 * self.m31
    local v5 = self.m22 * self.m33 - self.m23 * self.m32

    local i00 = (v5 * self.m11 - v4 * self.m12 + v3 * self.m13)
    local i10 = -(v5 * self.m10 - v2 * self.m12 + v1 * self.m13)
    local i20 = (v4 * self.m10 - v2 * self.m11 + v0 * self.m13)
    local i30 = -(v3 * self.m10 - v1 * self.m11 + v0 * self.m12)

    local invDet = 1.0 / (i00 * self.m00 + i10 * self.m01 + i20 * self.m02 + i30 * self.m03)

    i00 = i00 * invDet
    i10 = i10 * invDet
    i20 = i20 * invDet
    i30 = i30 * invDet

    local i01 = -(v5 * self.m01 - v4 * self.m02 + v3 * self.m03) * invDet
    local i11 = (v5 * self.m00 - v2 * self.m02 + v1 * self.m03) * invDet
    local i21 = -(v4 * self.m00 - v2 * self.m01 + v0 * self.m03) * invDet
    local i31 = (v3 * self.m00 - v1 * self.m01 + v0 * self.m02) * invDet

    v0 = self.m10 * self.m31 - self.m11 * self.m30
    v1 = self.m10 * self.m32 - self.m12 * self.m30
    v2 = self.m10 * self.m33 - self.m13 * self.m30
    v3 = self.m11 * self.m32 - self.m12 * self.m31
    v4 = self.m11 * self.m33 - self.m13 * self.m31
    v5 = self.m12 * self.m33 - self.m13 * self.m32

    local i02 = (v5 * self.m01 - v4 * self.m02 + v3 * self.m03) * invDet
    local i12 = -(v5 * self.m00 - v2 * self.m02 + v1 * self.m03) * invDet
    local i22 = (v4 * self.m00 - v2 * self.m01 + v0 * self.m03) * invDet
    local i32 = -(v3 * self.m00 - v1 * self.m01 + v0 * self.m02) * invDet

    v0 = self.m21 * self.m10 - self.m20 * self.m11
    v1 = self.m22 * self.m10 - self.m20 * self.m12
    v2 = self.m23 * self.m10 - self.m20 * self.m13
    v3 = self.m22 * self.m11 - self.m21 * self.m12
    v4 = self.m23 * self.m11 - self.m21 * self.m13
    v5 = self.m23 * self.m12 - self.m22 * self.m13

    local i03 = -(v5 * self.m01 - v4 * self.m02 + v3 * self.m03) * invDet
    local i13 = (v5 * self.m00 - v2 * self.m02 + v1 * self.m03) * invDet
    local i23 = -(v4 * self.m00 - v2 * self.m01 + v0 * self.m03) * invDet
    local i33 = (v3 * self.m00 - v1 * self.m01 + v0 * self.m02) * invDet

    local res = Mat4.new()
    res:SetData(
        i00, i01, i02, i03,
        i10, i11, i12, i13,
        i20, i21, i22, i23,
        i30, i31, i32, i33)
    return res
end

function Mat4:ToMat3()
    local res = Mat3.new()
    res:SetData(
        self.m00,
        self.m01,
        self.m02,
        self.m10,
        self.m11,
        self.m12,
        self.m20,
        self.m21,
        self.m22
    )
    return res
end
--分解
function Mat4:Decompose()
    local translation = Vec3.new()
    local rotation = Quat.new()
    local scale = Vec3.new()

    translation.x = self.m03
    translation.y = self.m13
    translation.z = self.m23

    scale.x = math.sqrt(self.m00 * self.m00 + self.m10 * self.m10 + self.m20 * self.m20)
    scale.y = math.sqrt(self.m01 * self.m01 + self.m11 * self.m11 + self.m21 * self.m21)
    scale.z = math.sqrt(self.m02 * self.m02 + self.m12 * self.m12 + self.m22 * self.m22)

    local invScale = Vec3.new(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
    rotation = self:ToMat3():Scaled(invScale)
    
    return translation, rotation, scale
end

--拷贝
function Mat4:Clone()
    local res = Mat4.new()
    res:SetData(
        self.m00, self.m01, self.m02, self.m03,
        self.m10, self.m11, self.m12, self.m13,
        self.m20, self.m21, self.m22, self.m23,
        self.m30, self.m31, self.m32, self.m33
    )
    return res
end

return Mat4