
local MainStorage = game:GetService("MainStorage")
local Vec3 = require(MainStorage.code.common.math.Vec3)
local Quat = require(MainStorage.code.common.math.Quat)
local Mat3 = require(MainStorage.code.common.math.Matrix3x3)

local Mat3x4 = {}

--实例化
function Mat3x4.new()
    local obj = {}
    Mat3x4.__index = Mat3x4
    setmetatable(obj, Mat3x4)
    obj:SetIdentity()
    return obj
end

function Mat3x4:FromTransforms(translation, rotation, scale)
    self:SetRotation(rotation:ToMat3() * scale)
    self:SetTranslation(translation)
end

--设置单位矩阵
function Mat3x4:SetIdentity()
    self:SetData(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0)
end

--设置
function Mat3x4:SetData(m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23)
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
end

--矩阵乘法
function Mat3x4:Mul(mat)
    local res = Mat3x4.new()
    res.m00 = self.m00 * mat.m00 + self.m01 * mat.m10 + self.m02 * mat.m20
    res.m01 = self.m00 * mat.m01 + self.m01 * mat.m11 + self.m02 * mat.m21
    res.m02 = self.m00 * mat.m02 + self.m01 * mat.m12 + self.m02 * mat.m22
    res.m03 = self.m00 * mat.m03 + self.m01 * mat.m13 + self.m02 * mat.m23 + self.m03
    res.m10 = self.m10 * mat.m00 + self.m11 * mat.m10 + self.m12 * mat.m20
    res.m11 = self.m10 * mat.m01 + self.m11 * mat.m11 + self.m12 * mat.m21
    res.m12 = self.m10 * mat.m02 + self.m11 * mat.m12 + self.m12 * mat.m22
    res.m13 = self.m10 * mat.m03 + self.m11 * mat.m13 + self.m12 * mat.m23 + self.m13
    res.m20 = self.m20 * mat.m00 + self.m21 * mat.m10 + self.m22 * mat.m20
    res.m21 = self.m20 * mat.m01 + self.m21 * mat.m11 + self.m22 * mat.m21
    res.m22 = self.m20 * mat.m02 + self.m21 * mat.m12 + self.m22 * mat.m22
    res.m23 = self.m20 * mat.m03 + self.m21 * mat.m13 + self.m22 * mat.m23 + self.m23
    return res
end
--矩阵乘向量
function Mat3x4:MulVec3(vec3)
    local res = Vec3.new()
    res.x = self.m00 * vec3.x + self.m01 * vec3.y + self.m02 * vec3.z + self.m03
    res.y = self.m10 * vec3.x + self.m11 * vec3.y + self.m12 * vec3.z + self.m13
    res.z = self.m20 * vec3.x + self.m21 * vec3.y + self.m22 * vec3.z + self.m23
    return res
end

function Mat3x4:MulVec4(vec4)
    local res = Vec3.new()
    res.x = self.m00 * vec4.x + self.m01 * vec4.y + self.m02 * vec4.z + self.m03
    res.y = self.m10 * vec4.x + self.m11 * vec4.y + self.m12 * vec4.z + self.m13
    res.z = self.m20 * vec4.x + self.m21 * vec4.y + self.m22 * vec4.z + self.m23
    return res
end

---------------------------------运算符重载-------------------------------
function Mat3x4.__add(lhs, rhs)
    local res = Mat3x4.new()
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
    return res
end

function Mat3x4.__sub(lhs, rhs)
    local res = Mat3x4.new()
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
    return res
end
--乘
function Mat3x4.__mul(lhs, rhs)
    if rhs.x and rhs.y and rhs.z and rhs.w then
        return lhs:MulVec4(rhs)
    elseif rhs.x and rhs.y and rhs.z then
        return lhs:MulVec3(rhs)
    else
        return lhs:Mul(rhs)
    end
end

function Mat3x4:__tostring()
    return string.format(
        "[[%f, %f, %f, %f], [%f, %f, %f, %f], [%f, %f, %f, %f]]",
        self.m00,
        self.m01,
        self.m02,
        self.m03,
        self.m10,
        self.m11,
        self.m12,
        self.m13,
        self.m20,
        self.m21,
        self.m22,
        self.m23
    )
end
--设置平移
function Mat3x4:SetTranslation(x, y, z)
    if type(x) == "table" then
        x, y, z = x.x, x.y, x.z
    end
    self.m03 = x
    self.m13 = y
    self.m23 = z
end

function Mat3x4:GetTranslation()
    return Vec3.new(self.m03, self.m13, self.m23)
end

--设置旋转
function Mat3x4:SetRotation(rotation)
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
function Mat3x4:GetRotation()
    local mat3 = Mat3.new(self.m00, self.m01, self.m02, self.m10, self.m11, self.m12, self.m20, self.m21, self.m22)
    local quat = Quat.new()
    quat:FromMat3(mat3)
    return quat
end
--设置缩放
function Mat3x4:SetScale(x, y, z)
    if type(x) == "table" then
        x, y, z = x.x, x.y, x.z
    end
    self.m00 = x
    self.m11 = y
    self.m22 = z
end

function Mat3x4:GetScale()
    return Vec3.new(self.m00, self.m11, self.m22)
end

--逆矩阵
function Mat3x4:Inverse()
    local det =
        self.m00 * (self.m11 * self.m22 - self.m12 * self.m21) - self.m01 * (self.m10 * self.m22 - self.m12 * self.m20) +
        self.m02 * (self.m10 * self.m21 - self.m11 * self.m20)
    if det == 0 then
        return nil
    end
    local invDet = 1 / det
    local res = Mat3x4.new()
    res.m00 = invDet * (self.m11 * self.m22 - self.m12 * self.m21)
    res.m01 = invDet * (self.m02 * self.m21 - self.m01 * self.m22)
    res.m02 = invDet * (self.m01 * self.m12 - self.m02 * self.m11)
    res.m03 = -(self.m03 * res.m00 + self.m13 * res.m01 + self.m23 * res.m02)

    res.m10 = invDet * (self.m12 * self.m20 - self.m10 * self.m22)
    res.m11 = invDet * (self.m00 * self.m22 - self.m02 * self.m20)
    res.m12 = invDet * (self.m02 * self.m10 - self.m00 * self.m12)
    res.m13 = -(self.m03 * res.m10 + self.m13 * res.m11 + self.m23 * res.m12)

    res.m20 = invDet * (self.m10 * self.m21 - self.m11 * self.m20)
    res.m21 = invDet * (self.m01 * self.m20 - self.m00 * self.m21)
    res.m22 = invDet * (self.m00 * self.m11 - self.m01 * self.m10)
    res.m23 = -(self.m03 * res.m20 + self.m13 * res.m21 + self.m23 * res.m22)
    return res
end

function Mat3x4:ToMat3()
    local res = Mat3.new()
    res:SetData(self.m00, self.m01, self.m02, self.m10, self.m11, self.m12, self.m20, self.m21, self.m22)
    return res
end
--分解
function Mat3x4:Decompose()
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
function Mat3x4:Clone()
    local res = Mat3x4.new()
    res:SetData(
        self.m00,
        self.m01,
        self.m02,
        self.m10,
        self.m11,
        self.m12,
        self.m20,
        self.m21,
        self.m22,
        self.m30,
        self.m31,
        self.m32
    )
    return res
end

return Mat3x4
