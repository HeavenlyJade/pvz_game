local MainStorage = game:GetService("MainStorage")
local Vec3 = require(MainStorage.code.common.math.Vec3)
local Mat3 = require(MainStorage.code.common.math.Matrix3x3)
local MathDefines = require(MainStorage.code.common.math.MathDefines)
local FaceCameraMode = MathDefines.FaceCameraMode
local Quat = {}

--实例化
function Quat.new(w, x, y, z)
    local obj = {}
    obj.w = w or 1
    obj.x = x or 0
    obj.y = y or 0
    obj.z = z or 0
    Quat.__index = Quat
    setmetatable(obj, Quat)
    return obj
end

function Quat.identity()
    return Quat.new(1, 0, 0, 0)
end

function Quat.euler(x, y, z)
    if type(x) == "table" then
        y = x.y
        z = x.z
        x = x.x
    end
    local q = Quat.new()
    q:FromEuler(Vec3.new(x, y, z))
    return q
end

function Quat.lookAt(dir)
    local q = Quat.new()
    q:FromLookRotation(dir)
    return q
end

---------------------------------运算符重载-------------------------------
--加
function Quat.__add(lhs, rhs)
    return Quat.new(lhs.w + rhs.w, lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
end

--减
function Quat.__sub(lhs, rhs)
    return Quat.new(lhs.w - rhs.w, lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
end

--乘
function Quat.__mul(lhs, rhs)
    if type(lhs) == "number" then
        return Quat.new(lhs * rhs.w, lhs * rhs.x, lhs * rhs.y, lhs * rhs.z)
    elseif type(rhs) == "number" then
        return Quat.new(lhs.w * rhs, lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    elseif getmetatable(lhs) == Quat and getmetatable(rhs) == Vec3 then
        return lhs:MulVec3(rhs)
    else
        if rhs.x and rhs.y and rhs.z then
            if rhs.w then
                local w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
                local x = lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y
                local y = lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x
                local z = lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w
                return Quat.new(w, x, y, z)
            else
                return lhs:MulVec3(Vec3.new(rhs.x, rhs.y, rhs.z))
            end
        end
    end
end

--除
function Quat.__div(lhs, rhs)
    return Quat.new(lhs.w / rhs, lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
end

--负
function Quat.__unm(q)
    return Quat.new(-q.w, -q.x, -q.y, -q.z)
end

--相等
function Quat.__eq(lhs, rhs)
    return lhs.w == rhs.w and lhs.x == rhs.x and lhs.y == rhs.y and lhs.z == rhs.z
end

--字符串
function Quat.__tostring(q)
    return string.format("Quat(%f, %f, %f, %f)", q.w, q.x, q.y, q.z)
end

---------------------------------运算符重载-------------------------------

--是否有无效值
function Quat:IsNaN()
    return self.w ~= self.w or self.x ~= self.x or self.y ~= self.y or self.z ~= self.z
end
--长度
function Quat:Length()
    return math.sqrt(self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z)
end

--从角度和轴创建
function Quat:FromAngleAxis(angle, axis)
    local normAxis = axis:Normalized()
    angle = angle * MathDefines.M_DEGTORAD_2
    local sinAngle = math.sin(angle)
    local cosAngle = math.cos(angle)

    self.w = cosAngle
    self.x = normAxis.x * sinAngle
    self.y = normAxis.y * sinAngle
    self.z = normAxis.z * sinAngle
end

--转换成角度和轴
function Quat:ToAngleAxis()
    local halfAngle = math.acos(self.w)
    local sinHalfAngle = math.sin(halfAngle)
    if sinHalfAngle < 0.0001 then
        return 0, Vec3.new(1, 0, 0)
    end
    local angle = halfAngle * 2
    local axis = Vec3.new(self.x, self.y, self.z) / sinHalfAngle
    return angle, axis
end
--从欧拉角创建
function Quat:FromEuler(euler)
    local halfX = euler.x * 0.5 * MathDefines.M_DEGTORAD
    local halfY = euler.y * 0.5 * MathDefines.M_DEGTORAD
    local halfZ = euler.z * 0.5 * MathDefines.M_DEGTORAD
    local cosX = math.cos(halfX)
    local sinX = math.sin(halfX)
    local cosY = math.cos(halfY)
    local sinY = math.sin(halfY)
    local cosZ = math.cos(halfZ)
    local sinZ = math.sin(halfZ)
    self.x = sinX * cosY * cosZ + cosX * sinY * sinZ
    self.y = cosX * sinY * cosZ - sinX * cosY * sinZ
    self.z = cosX * cosY * sinZ - sinX * sinY * cosZ
    self.w = cosX * cosY * cosZ + sinX * sinY * sinZ
end
--转换成欧拉角
function Quat:ToEuler()
    local check = 2 * (-self.y * self.z + self.w * self.x)
    if check < -0.995 then
        return Vec3.new(
            -90,
            0,
            -math.atan2(2 * (self.x * self.z - self.w * self.y), 1 - 2 * (self.y * self.y + self.z * self.z)) *
                MathDefines.M_RADTODEG
        )
    elseif check > 0.995 then
        return Vec3.new(
            90,
            0,
            math.atan2(2 * (self.x * self.z - self.w * self.y), 1 - 2 * (self.y * self.y + self.z * self.z)) *
                MathDefines.M_RADTODEG
        )
    else
        return Vec3.new(
            math.asin(check) * MathDefines.M_RADTODEG,
            math.atan2(2 * (self.x * self.z + self.w * self.y), 1 - 2 * (self.x * self.x + self.y * self.y)) *
                MathDefines.M_RADTODEG,
            math.atan2(2 * (self.x * self.y + self.w * self.z), 1 - 2 * (self.x * self.x + self.z * self.z)) *
                MathDefines.M_RADTODEG
        )
    end
end
--从两个向量创建
function Quat:FromRotationTo(from, to)
    local normStart = from:Normalized()
    local normEnd = to:Normalized()
    local d = normStart:Dot(normEnd)
    if d > (-1 + MathDefines.M_EPSILON) then
        local c = normStart:Cross(normEnd)
        local s = math.sqrt((1 + d) * 2)
        local invS = 1 / s
        self.x = c.x * invS
        self.y = c.y * invS
        self.z = c.z * invS
        self.w = 0.5 * s
    else
        local axis = Vec3.new(1, 0, 0):Cross(normStart)
        if axis:Magnitude() < MathDefines.M_EPSILON then
            axis = Vec3.new(0, 1, 0):Cross(normStart)
        end
        self:FromAngleAxis(180, axis)
    end
end

function Quat:FromLookRotation(direction, upDirection)
    upDirection = upDirection or Vec3.new(0, 1, 0)
    local ret = Quat.new()
    local forward = direction:Normalized()

    local v = forward:Cross(upDirection)
    if v:SqrMagnitude() >= MathDefines.M_EPSILON then
        v:Normalize()
        local up = v:Cross(forward)
        local right = up:Cross(forward)
        ret:FromAxes(right, up, forward)
    else
        ret:FromRotationTo(Vec3.new(0, 0, 1), forward)
    end
    if not self:IsNaN() then
        self.w = ret.w
        self.x = ret.x
        self.y = ret.y
        self.z = ret.z
        return true
    else
        return false
    end
end
--从方向创建
function Quat:FromDirection(direction)
    self:FromRotationTo(Vec3.new(0, 0, 1), direction)
end

--获取左向量
function Quat:GetLeft()
    local left = Vec3.new(-1, 0, 0)
    return self:MulVec3(left)
end

--获取上向量
function Quat:GetUp()
    local up = Vec3.new(0, 1, 0)
    return self:MulVec3(up)
end

--获取前向量
function Quat:GetForward()
    local forward = Vec3.new(0, 0, 1)
    return self:MulVec3(forward)
end

--获取后向量
function Quat:GetBackward()
    local back = Vec3.new(0, 0, -1)
    return self:MulVec3(back)
end

--获取右向量
function Quat:GetRight()
    local right = Vec3.new(1, 0, 0)
    return self:MulVec3(right)
end

--获取下向量
function Quat:GetDown()
    local down = Vec3.new(0, -1, 0)
    return self:MulVec3(down)
end

--归一化
function Quat:Normalize()
    local length = self:Length()
    if length > 0 then
        return Quat.new(self.w / length, self.x / length, self.y / length, self.z / length)
    else
        return Quat.new(1, 0, 0, 0)
    end
end

--逆四元数
function Quat:Inversed()
    local factor = 1 / (self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z)
    return Quat.new(self.w * factor, -self.x * factor, -self.y * factor, -self.z * factor)
end
function Quat:Inverse()
    local factor = 1 / (self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z)
    self.w = self.w * factor
    self.x = -self.x * factor
    self.y = -self.y * factor
    self.z = -self.z * factor
end

--四元数乘以向量
function Quat:MulVec3(v)
    local qvec = Vec3.new(self.x, self.y, self.z)
    local uv = qvec:Cross(v)
    local uuv = qvec:Cross(uv)
    uv = uv * (2 * self.w)
    uuv = uuv * 2
    return v + uv + uuv
end

--四元数乘以四元数
function Quat:MulQuat(q)
    local w = self.w * q.w - self.x * q.x - self.y * q.y - self.z * q.z
    local x = self.w * q.x + self.x * q.w + self.y * q.z - self.z * q.y
    local y = self.w * q.y - self.x * q.z + self.y * q.w + self.z * q.x
    local z = self.w * q.z + self.x * q.y - self.y * q.x + self.z * q.w
    return Quat.new(w, x, y, z)
end

--四元数点乘
function Quat:Dot(q)
    return self.w * q.w + self.x * q.x + self.y * q.y + self.z * q.z
end

--四元数叉乘
function Quat:Cross(q)
    local w = self.w * q.w - self.x * q.x - self.y * q.y - self.z * q.z
    local x = self.w * q.x + self.x * q.w + self.y * q.z - self.z * q.y
    local y = self.w * q.y - self.x * q.z + self.y * q.w + self.z * q.x
    local z = self.w * q.z + self.x * q.y - self.y * q.x + self.z * q.w
    return Quat.new(w, x, y, z)
end

--获取球面插值四元数
function Quat:Slerp(to, t)
    local cosAngle = self:Dot(to)
    local sign = 1.0
    if cosAngle < 0.0 then
        cosAngle = -cosAngle
        sign = -1.0
    end
    local angle = math.acos(cosAngle)
    local sinAngle = math.sin(angle)
    local t1, t2
    if sinAngle > 0.001 then
        local invSinAngle = 1.0 / sinAngle
        t1 = math.sin((1.0 - t) * angle) * invSinAngle
        t2 = math.sin(t * angle) * invSinAngle
    else
        t1 = 1.0 - t
        t2 = t
    end
    return self * t1 + to * sign * t2
end

--获取插值四元数
function Quat:Lerp(to, t)
    return self * (1 - t) + to * t
end

--获取反射四元数
function Quat:Reflect(normal)
    return self - 2 * self:Dot(normal) * normal
end

--获取反向四元数
function Quat:Inversed()
    return -self
end

--获取垂直四元数
function Quat:Perpendicular()
    local x = self.x
    local y = self.y
    local z = self.z
    if math.abs(x) <= math.abs(y) and math.abs(x) <= math.abs(z) then
        return Quat.new(0, -z, y, -x)
    elseif math.abs(y) <= math.abs(x) and math.abs(y) <= math.abs(z) then
        return Quat.new(-z, 0, x, -y)
    else
        return Quat.new(-y, x, -z, 0)
    end
end

--获取共轭四元数
function Quat:Conjugate()
    return Quat.new(self.w, -self.x, -self.y, -self.z)
end

--设置Yaw
function Quat:SetYaw(yaw)
    local halfYaw = yaw * 0.5
    local cosHalfYaw = math.cos(halfYaw)
    local sinHalfYaw = math.sin(halfYaw)
    self.w = cosHalfYaw
    self.x = 0
    self.y = sinHalfYaw
    self.z = 0
end

--设置Pitch
function Quat:SetPitch(pitch)
    local halfPitch = pitch * 0.5
    local cosHalfPitch = math.cos(halfPitch)
    local sinHalfPitch = math.sin(halfPitch)
    self.w = cosHalfPitch
    self.x = sinHalfPitch
    self.y = 0
    self.z = 0
end
--设置Roll
function Quat:SetRoll(roll)
    local halfRoll = roll * 0.5
    local cosHalfRoll = math.cos(halfRoll)
    local sinHalfRoll = math.sin(halfRoll)
    self.w = cosHalfRoll
    self.x = 0
    self.y = 0
    self.z = sinHalfRoll
end

--获取Yaw
function Quat:GetYaw()
    return math.atan2(2 * (self.w * self.y + self.z * self.x), 1 - 2 * (self.x * self.x + self.y * self.y))
end

--获取Pitch
function Quat:GetPitch()
    return math.asin(2 * (self.w * self.x - self.y * self.z))
end

--获取Roll
function Quat:GetRoll()
    return math.atan2(2 * (self.w * self.z + self.x * self.y), 1 - 2 * (self.y * self.y + self.z * self.z))
end

--拷贝
function Quat:Clone()
    return Quat.new(self.w, self.x, self.y, self.z)
end
--从3轴创建
function Quat:FromAxes(xAxis, yAxis, zAxis)
    local matrix = Mat3.new()
    matrix:SetData(xAxis.x, yAxis.x, zAxis.x, xAxis.y, yAxis.y, zAxis.y, xAxis.z, yAxis.z, zAxis.z)

    self:FromMat3(matrix)
end
--转换成3轴
function Quat:ToAxes()
    local kRot = self:ToMat3()
    local xaxis = Vec3.new()
    local yaxis = Vec3.new()
    local zaxis = Vec3.new()

    xaxis.x = kRot:Get(0, 0)
    xaxis.y = kRot:Get(1, 0)
    xaxis.z = kRot:Get(2, 0)

    yaxis.x = kRot:Get(0, 1)
    yaxis.y = kRot:Get(1, 1)
    yaxis.z = kRot:Get(2, 1)

    zaxis.x = kRot:Get(0, 2)
    zaxis.y = kRot:Get(1, 2)
    zaxis.z = kRot:Get(2, 2)
    return xaxis, yaxis, zaxis
end
--从3x3矩阵创建
function Quat:FromMat3(matrix)
    local t = matrix:Get(0, 0) + matrix:Get(1, 1) + matrix:Get(2, 2)

    if t > 0 then
        local invS = 0.5 / math.sqrt(1 + t)
        self.x = (matrix:Get(2, 1) - matrix:Get(1, 2)) * invS
        self.y = (matrix:Get(0, 2) - matrix:Get(2, 0)) * invS
        self.z = (matrix:Get(1, 0) - matrix:Get(0, 1)) * invS
        self.w = 0.25 / invS
    else
        if matrix:Get(0, 0) > matrix:Get(1, 1) and matrix:Get(0, 0) > matrix:Get(2, 2) then
            local invS = 0.5 / math.sqrt(1 + matrix:Get(0, 0) - matrix:Get(1, 1) - matrix:Get(2, 2))
            self.x = 0.25 / invS
            self.y = (matrix:Get(0, 1) + matrix:Get(1, 0)) * invS
            self.z = (matrix:Get(2, 0) + matrix:Get(0, 2)) * invS
            self.w = (matrix:Get(2, 1) - matrix:Get(1, 2)) * invS
        elseif matrix:Get(1, 1) > matrix:Get(2, 2) then
            local invS = 0.5 / math.sqrt(1 + matrix:Get(1, 1) - matrix:Get(0, 0) - matrix:Get(2, 2))

            self.x = (matrix:Get(0, 1) + matrix:Get(1, 0)) * invS
            self.y = 0.25 / invS
            self.z = (matrix:Get(1, 2) + matrix:Get(2, 1)) * invS
            self.w = (matrix:Get(0, 2) - matrix:Get(2, 0)) * invS
        else
            local invS = 0.5 / math.sqrt(1 + matrix:Get(2, 2) - matrix:Get(0, 0) - matrix:Get(1, 1))
            self.x = (matrix:Get(0, 2) + matrix:Get(2, 0)) * invS
            self.y = (matrix:Get(1, 2) + matrix:Get(2, 1)) * invS
            self.z = 0.25 / invS
            self.w = (matrix:Get(1, 0) - matrix:Get(0, 1)) * invS
        end
    end
end
--转换成3x3矩阵
function Quat:ToMat3()
    local fTx = self.x + self.x
    local fTy = self.y + self.y
    local fTz = self.z + self.z
    local fTwx = fTx * self.w
    local fTwy = fTy * self.w
    local fTwz = fTz * self.w
    local fTxx = fTx * self.x
    local fTxy = fTy * self.x
    local fTxz = fTz * self.x
    local fTyy = fTy * self.y
    local fTyz = fTz * self.y
    local fTzz = fTz * self.z

    local kRot = Mat3.new()
    kRot:Set(0, 0, 1.0 - (fTyy + fTzz))
    kRot:Set(0, 1, fTxy - fTwz)
    kRot:Set(0, 2, fTxz + fTwy)
    kRot:Set(1, 0, fTxy + fTwz)
    kRot:Set(1, 1, 1.0 - (fTxx + fTzz))
    kRot:Set(1, 2, fTyz - fTwx)
    kRot:Set(2, 0, fTxz - fTwy)
    kRot:Set(2, 1, fTyz + fTwx)
    kRot:Set(2, 2, 1.0 - (fTxx + fTyy))
    return kRot
end
--获取朝向四元数
function Quat:GetFaceCameraRotation(cameraPos, cameraRotation, pos, rotation, faceMode, minAngle)
    if faceMode == FaceCameraMode.FC_ROTATE_XYZ then
        return cameraRotation
    elseif faceMode == FaceCameraMode.FC_ROTATE_Y then
        local euler = rotation:ToEuler()
        euler.y = cameraRotation:ToEuler().y
        local ret = Quat.new()
        ret.FromEuler(euler)
        return ret
    elseif faceMode == FaceCameraMode.FC_LOOKAT_XYZ then
        local ret = Quat.new()
        ret:FromLookRotation(cameraPos - pos)
        return ret
    elseif faceMode == FaceCameraMode.FC_LOOKAT_Y or faceMode == FaceCameraMode.FC_LOOKAT_MIXED then
        local lookAtVec = pos - cameraPos
        local lookAtVecXZ = Vec3.new(lookAtVec.x, 0, lookAtVec.z)
        local lookAt = Quat.new()
        lookAt:FromLookRotation(lookAtVecXZ)
        local euler = rotation:ToEuler()
        if faceMode == FaceCameraMode.FC_LOOKAT_MIXED then
            local angle = lookAtVec:AngleBetween(rotation * Vec3.new(0, 1, 0))
            if angle > 180 - minAngle then
                euler.x = euler.x + minAngle - (180 - angle)
            elseif angle < minAngle then
                euler.x = euler.x - minAngle + angle
            end
        end
        euler.y = lookAt:ToEuler().y
        local ret = Quat.new()
        ret.FromEuler(euler)
        return ret
    end
    return rotation
end

--求角度
function Quat:Angle(quat)
    local dot = self:Dot(quat)
    local angle = math.acos(math.min(math.max(dot, -1), 1)) * 180 / MathDefines.M_PI
    return angle
end

return Quat
