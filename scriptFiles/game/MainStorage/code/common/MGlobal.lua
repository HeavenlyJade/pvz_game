local MainStorage = game:GetService("MainStorage")
local Vec2 = require(MainStorage.code.common.math.Vec2)
local Vec3 = require(MainStorage.code.common.math.Vec3)
local Vec4 = require(MainStorage.code.common.math.Vec4)
local Quat = require(MainStorage.code.common.math.Quat)
-- 延迟加载Dict，避免循环依赖
-- local Dict = require(MainStorage.code.common.func_utils.Dict)

local inputservice = game:GetService("UserInputService")
local Players = game:GetService('Players')

---@class NetworkChannel
---@field OnClientNotify Event<fun(self, event: string, data: table)>
---@field FireServer fun(self, data: table)
---@field fireClient fun(self, uin: number, data: table)


local Math = {}
--求半径内的随机点
function Math.RandomPointInRadius(center, radius)
    local angle = math.random(0, 360)
    local x = center.x + radius * math.cos(angle)
    local z = center.z + radius * math.sin(angle)
    return Vector3.New(x, center.y, z)
end
--平滑阻尼插值
function Math.SmoothDamp(current, target, velocity, smoothTime, maxSpeed, deltaTime)
    -- 防止除以零
    if smoothTime == 0 then
        return target
    end

    -- 计算减速度常数
    local timeConstant = math.sqrt(2.0 / smoothTime)

    -- 计算最大速度
    local maxVelocity = maxSpeed * timeConstant

    -- 限制速度
    velocity = math.min(velocity, maxVelocity)
    velocity = math.max(velocity, -maxVelocity)

    -- 计算新的位置
    local remainingTime = smoothTime - deltaTime
    local t = 1 - math.exp(-timeConstant * deltaTime)

    -- 使用线性插值（lerp）来平滑移动
    local smoothedValue = current + (target - current) * t

    -- 更新速度
    velocity = velocity - (target - smoothedValue) / remainingTime

    return smoothedValue, velocity
end

--范围随机数
function Math.Random(min, max)
    return min + math.random() * (max - min)
end
--随机数加偏移
function Math.RandomDeviation(value, dev)
    return value + self:Random(-dev, dev)
end
--在一个圈内随机
function Math.RandomInsideUnitCircle()
    local x = math.random() * 2 - 1
    local y = math.random() * 2 - 1
    local ret = Vector2.New(x, y)
    return ret:Normalize()
end

--判断一个数字是否在某个范围内
function Math.IsInRange(value, min, max)
    return value >= min and value <= max
end

--几乎等于
function Math.IsAlmostEqual(a, b, epsilon)
    return math.abs(a - b) < epsilon
end

--补间
function Math.Lerp(a, b, t)
    return a + (b - a) * t
end
--判断是否为NaN
function Math.IsNaN(x)
    return x ~= x
end
--判断数字是否无穷大
function Math.IsInfinity(x)
    return x == math.huge or x == -math.huge
end
--判断浮点是否等于0，接近即可
function Math.IsZero(x)
    local r = 0.001
    return math.abs(x) <= r
end
--角度差
function Math.DeltaAngle(a, b)
    local delta = (b - a) % 360
    if delta < -180 then
        delta = delta + 360
    elseif delta > 180 then
        delta = delta - 360
    end
    return delta
end

--根据一个向量方向，返回的左边方向
function Math.GetLeftDirection(direction)
    return Math.GetRightDirection(direction):Negate()
end
--根据一个向量方向，返回的右边方向
function Math.GetRightDirection(direction)
    if direction.x == 0 and direction.z == 0 then
        return Vector3.New(0, 0, 1)
    end
    local orient = Quaternion.lookAt(direction)
    return orient * Vector3.New(1, 0, 0)
end



local vec = {}

vec.M_EPSILON = 0.000001
vec.M_PI = 3.14159265358979323846
vec.M_DEGTORAD = vec.M_PI / 180.0
vec.M_DEGTORAD_2 = vec.M_PI / 360.0
vec.M_RADTODEG = 1.0 / vec.M_DEGTORAD
vec.Rad2Deg = 180.0 / vec.M_PI
vec.Deg2Rad = vec.M_PI / 180.0

-- Vector2 specific functions
---@param v Vector2 要标准化的向量
---@return Vector2 标准化后的向量
function vec.Normalize2(v)
        return Vector2.Normalize(v)
end

---@param v1 Vector2 第一个向量
---@param v2 Vector2 第二个向量
---@return number 两个向量之间的距离
function vec.Distance2(v1, v2)
    return math.sqrt(vec.DistanceSq2(v1, v2))
end

---@param v1 Vector2 第一个向量
---@param v2 Vector2 第二个向量
---@return number 两个向量之间距离的平方
function vec.DistanceSq2(v1, v2)
        local dx = v1.x - v2.x
        local dy = v1.y - v2.y
    return dx * dx + dy * dy
end

---@param v1 Vector2 第一个向量
---@param v2 Vector2 第二个向量
---@return number 两个向量的点积
function vec.Dot2(v1, v2)
    return Vector2.Dot(v1, v2)
end


---@param target Vector3|Entity|Vec3
---@return Vector3
function vec.ToVector3(target)
    if type(target) == "userdata" then
        return target
    else
        if type(target) == "table" and target.Is and target:Is("Entity") then
            return target:GetPosition():ToVector3()
        else
            return target:ToVector3()
        end
    end
end

---@param v1 Vector2 起始向量
---@param v2 Vector2 目标向量
---@param percent number 插值比例(0-1)
---@return Vector2 插值后的向量
function vec.Lerp2(v1, v2, percent)
    return Vector2.Lerp(v1, v2, percent)
end

---@param v1 Vector2 向量
---@param x number x坐标
---@param y number y坐标
---@return Vector2 相加后的向量
function vec.Add2(v1, x, y)
    return Vector2.New(v1.x + x, v1.y + y)
end

function vec.ToDirection(v1)
    -- Convert angles to radians
    local pitch = v1.x * vec.M_DEGTORAD
    local yaw = v1.y * vec.M_DEGTORAD

    -- Calculate direction vector components
    local x = math.sin(yaw) * math.cos(pitch)
    local y = -math.sin(pitch)
    local z = math.cos(yaw) * math.cos(pitch)

    -- Return normalized direction vector
    return Vector3.New(x, y, z)
end

---@param v Vector2 向量
---@param scalar_or_vec number|Vector2 标量值或向量
---@return Vector2 相乘后的向量
function vec.Multiply2(v, scalar_or_vec)
    if type(scalar_or_vec) == "number" then
        return Vector2.New(v.x * scalar_or_vec, v.y * scalar_or_vec)
    else
        return Vector2.New(v.x * scalar_or_vec.x, v.y * scalar_or_vec.y)
    end
end

-- Vector3 specific functions
---@param v Vector3 要标准化的向量
---@return Vector3 标准化后的向量
function vec.Normalize3(v)
    return Vector3.Normalize(v)
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return number 两个向量之间的距离
function vec.Distance3(v1, v2)
    return math.sqrt(vec.DistanceSq3(v1, v2))
end

---@param v1 Vector3 第一个向量
---@return number 向量长度
function vec.Length3(v1)
    return math.sqrt(v1.x * v1.x + v1.y * v1.y + v1.z * v1.z)
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return number 两个向量之间距离的平方
function vec.DistanceSq3(v1, v2)
        local dx = v1.x - v2.x
        local dy = v1.y - v2.y
        local dz = v1.z - v2.z
        return dx * dx + dy * dy + dz * dz
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return number 两个向量的点积
function vec.Dot3(v1, v2)
        return Vector3.Dot(v1, v2)
end

---@param v1 Vector3 起始向量
---@param v2 Vector3 目标向量
---@param percent number 插值比例(0-1)
---@return Vector3 插值后的向量
function vec.Lerp3(v1, v2, percent)
        return Vector3.Lerp(v1, v2, percent)
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return Vector3 两个向量的叉积
function vec.Cross3(v1, v2)
        return Vector3.Cross(v1, v2)
    end

---@param v1 Vector3 向量
---@param x number x坐标
---@param y number y坐标
---@param z number z坐标
---@return Vector3 相加后的向量
function vec.Add3(v1, x, y, z)
    return Vector3.New(v1.x + x, v1.y + y, v1.z + z)
end

---@param v Vector3 向量
---@param scalar_or_vec number|Vector3 标量值或向量
---@return Vector3 相乘后的向量
function vec.Multiply3(v, scalar_or_vec)
    if type(scalar_or_vec) == "number" then
        return Vector3.New(v.x * scalar_or_vec, v.y * scalar_or_vec, v.z * scalar_or_vec)
    else
        return Vector3.New(v.x * scalar_or_vec.x, v.y * scalar_or_vec.y, v.z * scalar_or_vec.z)
    end
end

-- Vector4 specific functions
---@param v Vector4 要标准化的向量
---@return Vector4 标准化后的向量
function vec.Normalize4(v)
    return Vector4.Normalize(v)
end

---@param v1 Vector4 第一个向量
---@param v2 Vector4 第二个向量
---@return number 两个向量之间的距离
function vec.Distance4(v1, v2)
    return math.sqrt(vec.DistanceSq4(v1, v2))
end

---@param v1 Vector4 第一个向量
---@param v2 Vector4 第二个向量
---@return number 两个向量之间距离的平方
function vec.DistanceSq4(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    local dz = v1.z - v2.z
    local dw = v1.w - v2.w
    return dx * dx + dy * dy + dz * dz + dw * dw
end

---@param v1 Vector4 第一个向量
---@param v2 Vector4 第二个向量
---@return number 两个向量的点积
function vec.Dot4(v1, v2)
    return Vector4.Dot(v1, v2)
end

---@param v1 Vector4 起始向量
---@param v2 Vector4 目标向量
---@param percent number 插值比例(0-1)
---@return Vector4 插值后的向量
function vec.Lerp4(v1, v2, percent)
    return Vector4.Lerp(v1, v2, percent)
end

---@param v1 Vector4 向量
---@param x number x坐标
---@param y number y坐标
---@param z number z坐标
---@param w number w坐标
---@return Vector4 相加后的向量
function vec.Add4(v1, x, y, z, w)
        return Vector4.New(v1.x + x, v1.y + y, v1.z + z, v1.w + w)
end

---@param v Vector4 向量
---@param scalar_or_vec number|Vector4 标量值或向量
---@return Vector4 相乘后的向量
function vec.Multiply4(v, scalar_or_vec)
    if type(scalar_or_vec) == "number" then
        return Vector4.New(v.x * scalar_or_vec, v.y * scalar_or_vec, v.z * scalar_or_vec, v.w * scalar_or_vec)
    else
        return Vector4.New(v.x * scalar_or_vec.x, v.y * scalar_or_vec.y, v.z * scalar_or_vec.z, v.w * scalar_or_vec.w)
    end
end

---@class gg      --存放自定义的global全局变量和函数
---@field tick number 当前tick
---@field game_stat number 游戏状态
---@field uuid_start number 当前uuid起始值
---@field server_players_list table<number, Player> 服务器玩家列表
---@field server_players_name_list table<string, Player> 服务器玩家名称列表
---@field equipSlot table<number, table<number, boolean>> 各个装备槽位对应的装备类型
local gg = {
    isServer = nil,
    opUin = {[1995296726]= true, [1999522565]= true, [1997748985] = true, [1831921352] = true, [1995494850] = true, [1997807412] = true, [1972857840] = true},
    math = Math,
    vec = vec,
    Vec2 = Vec2, ---@type Vec2
    Vec3 = Vec3, ---@type Vec3
    Vec4 = Vec4, ---@type Vec4
    -- Dict 延迟加载，避免循环依赖
    Quat = Quat, ---@type Quat
    noise = require(script.Parent.math.PerlinNoise),
    VECUP = Vector3.New(0, 1, 0), -- 向上方向 y+
    VECDOWN = Vector3.New(0, -1, 0), -- 向下方向 y-

    CommandManager = nil, ---@type CommandManager
    network_channel = nil, ---@type NetworkChannel
    cloudMailData = nil, ---@type CloudMailDataAccessor
    tick = 0, -- server_main的tick
    game_stat = 0, -- 0=正常 1=完结

    uuid_start = math.random(100000, 999999),

    server_players_list = {}, ---@type table<number, Player>
    server_players_name_list = {}, ---@type table<string, Player>

    equipSlot = { -- 各个装备槽位对应的装备类型
        [2] = {
            [1] = {[1] = true},
            [2] = {[2] = true},
            [3] = {[3] = true},
            [4] = {[4] = true},
            [5] = {[5] = true},
            [6] = {[6] = true},
            [7] = {[7] = true},
            [8] = {[8] = true},
            [9] = {[9] = true},
            [10] = {[10] = true},
            [11] = {[11] = true},
            [12] = {[12] = true}
        }
    },

    server_scene_list = {}, ---@type table<string, Scene>
    -- 客户端使用(p1)
    client_scene_name = 'g0', -- 当前客户端的场景
    client_target_node = nil, -- 当前目标
    client_selected = nil, -- 选中控件
    client_aoe_cylinder = nil, -- aoe技能碰撞控件

    lockClientCharactor = false, -- 是否锁定玩家

    client_bag_ver = 0, -- 背包的时间戳版本号

    client_bag_size = 36, -- 背包大小
    ---@type table<number, table>
    client_bag_index = {}, -- 服务器同步给玩家的背包放置数据
    ---@type table<string, table>
    client_bag_items = {}, -- 服务器同步给玩家的背包物品详情
    ---@type table
    client_player_data = { -- 玩家数据 (需要从服务器同步)
        battle_data = nil, -- 战斗数据
        exp = 0,
        level = 0,
        user_name = nil,
        user_id = nil
    }

}

---@param node SandboxNode
function gg.GetFullPath(node)
    local path = node.Name
    local parent = node.Parent

    if parent.Name ~= "WorkSpace" then
        while parent do
            path = parent.Name .. "/" .. path
            parent = parent.Parent
            if not parent or parent.Name == "WorkSpace" then
                break
            end
        end
    end

    return path
end

function gg.ProcessVariables(formula, caster, target)
    if not formula then
        return nil
    end
    target = target or caster
    local processedFormula = formula:gsub("%<(.-)%>", function(varName)
        if not target then
            gg.log("解析公式%s时出错：target不存在！")
            print(debug.traceback())
            return varName
        end
        local useCaster = target ---@type Entity
        local realVarName = varName
        if varName:sub(1,2) == "c:" then
            useCaster = caster
            realVarName = varName:sub(3)
        end
        if realVarName == "UIN" then
            return useCaster.uin
        end
        if realVarName == "NAME" then
            return useCaster.name
        end
        if realVarName == "OWNER" then
            if useCaster.owner then
                return useCaster.owner.name
            else
                return ""
            end
        end
        local value
        value = useCaster and useCaster:GetVariable(realVarName) or nil
        return tostring(value)
    end)
    return processedFormula
end
function gg.ProcessFormula(formula, caster, target)
    if not formula then
        return nil
    end
    -- 自动修正常见中文符号为英文
    formula = formula
        :gsub("，", ",")
        :gsub("（", "(")
        :gsub("）", ")")
        :gsub("－", "-")
        :gsub("−", "-")
        :gsub("—", "-")
        :gsub("＋", "+")
        :gsub("×", "*")
        :gsub("＊", "*")
        :gsub("÷", "/")
        :gsub("／", "/")
        :gsub("．", ".")
    formula = gg.ProcessVariables(formula, caster, target)
    if not formula then
        return 0
    end
    return gg.eval(formula)
end

-- 将table以json格式打印
---@param t table 要打印的表
---@param indent string? 缩进字符串(可选)
---@return string 格式化后的字符串
function gg.printTable(t, indent)
    indent = indent or ""

    if type(t) ~= "table" then
        return tostring(t)
    end

    local function escapeStr(str)
        str = string.gsub(str, '"', '\\"')
        str = string.gsub(str, '\n', '\\n')
        return str
    end

    local result = indent .. "{\n"
    for k, v in pairs(t) do
        local key = type(k) == "string" and '"' .. escapeStr(k) .. '"' or k
        if type(v) == "table" then
            result = result .. indent .. "  " .. key .. ": \n"
            result = result .. gg.printTable(v, indent .. "  ")
        else
            local val = type(v) == "string" and '"' .. escapeStr(v) .. '"' or tostring(v)
            result = result .. indent .. "  " .. key .. ": " .. val .. ",\n"
        end
    end
    result = result .. indent .. "}\n"
    return result
end

-----------------------------------------------
-- 从 Service - Players找到一个玩家
---@param uin_ number 玩家ID
---@return Player|nil 找到的玩家对象
function gg.getPlayerInfoByUin(uin_)
    local allPlayers = Players:GetPlayers()
    for _, player in ipairs(allPlayers) do
        if player.UserId == uin_ then
            return player
        end
    end
end

---@param name_ string
function gg.getLivingByName(name_)
    if string.sub(name_, 1, 2) == 'u_' then
        for scene_name, scene in pairs(gg.server_scene_list) do
            if scene.uuid2Entity[name_] then
                return scene.uuid2Entity[name_]
            end
        end
    end
    gg.log("gg.server_players_name_list",gg.server_players_name_list)
    return gg.server_players_name_list[name_]
end

-- 获得player实例
---@param uin_ number 玩家ID
---@return Player|nil 玩家实例
function gg.getPlayerByUin(uin_)
    if gg.server_players_list[uin_] then
        return gg.server_players_list[uin_];
    end
    return nil
end

-- 使用uuid查找一个怪物 m10002 m20003
---@param uuid_ string 怪物UUID
---@return Monster|nil 找到的怪物实例
function gg.findMonsterByUuid(uuid_)
    for scene_name, scene in pairs(gg.server_scene_list) do
        if next(scene.players) then
            -- 场景内有玩家
            if scene.monsters[uuid_] then
                return scene.monsters[uuid_]
            end
        end
    end
    return nil -- 查找失败
end

-- 使用uuid查找一个怪物 m10002 m20003，client端
---@param scene_name_ string 场景名称
---@param uuid_ string 怪物UUID
---@return Monster|nil 找到的怪物实例
function gg.findMonsterClientContainer(scene_name_, uuid_)
    local contain_ = game.WorkSpace["Ground"][scene_name_].container_monster
    if contain_ then
        return contain_[uuid_]
    end
    return nil -- 查找失败
end

-- 获得当前场景（客户端侧）
---@return Workspace 当前工作空间
function gg.getClientWorkSpace()
    return game.WorkSpace
    -- return game:GetService("workspace")
end

-- -- 是否锁定视角，不允许转动
-- ---@param flag_ boolean 是否锁定
-- function gg.lockCamera(flag_)

--     if flag_ then
--         gg.getClientWorkSpace().Camera.CameraType = Enum.CameraType.Fixed
--         gg.lockClientCharactor = true
--     else
--         gg.getClientWorkSpace().Camera.CameraType = Enum.CameraType.Custom
--         gg.lockClientCharactor = false
--     end

-- end

-- 客户端获得怪物容器
---@return SandboxNode 怪物容器
function gg.clentGetContainerMonster()
    return game.WorkSpace["Ground"][gg.client_scene_name].container_monster
end

-- 获得武器法术效果容器
---@param scene_name_ string 场景名称
---@return SandboxNode 武器容器
function gg.serverGetContainerWeapon(scene_name_)
    return game.WorkSpace["Ground"][scene_name_].container_weapon
end

-- 获得当前玩家（客户端侧）
---@return Character 当前玩家角色
function gg.getClientLocalPlayer()
    return Players.LocalPlayer.Character
end

-- 建立一个uuid
---@param pre_ string 前缀
---@return string 生成的UUID
function gg.create_uuid(pre_)
    gg.uuid_start = gg.uuid_start + 1
    return pre_ .. gg.uuid_start .. '_' .. (gg.GetTimeStamp() * 1000 + math.random(1, 1000)) % 1000 .. '_' ..
               math.random(10000, 99999)
end

-- 获取屏幕大小
---@return number, number 屏幕宽度和高度
function gg.get_ui_wwhh()
    local ui_size = gg.get_ui_size()
    return ui_size.x, ui_size.y
end

-- 获取屏幕大小
---@return Vector2 屏幕尺寸
function gg.get_ui_size()
    if not gg.ui_size then
        wait(1)
        gg.ui_size = game:GetService('WorldService'):GetUISize()
        gg.log('获取屏幕大小====', gg.ui_size)
    end
    return gg.ui_size
end

function gg.FormatTime(time, isShort)
    if isShort == nil then
        isShort = true
    end
    local s = ""
    local c = 0

    -- Handle days
    if time > 86400 then
        local days = math.floor(time / 86400)
        s = s .. days .. "天"
        time = time - days * 86400
        c = c + 1
        if c > 0 and isShort then
            return s
        end
    end

    -- Handle hours
    if time > 3600 then
        local hours = math.floor(time / 3600)
        s = s .. hours .. "小时"
        time = time - hours * 3600
        c = c + 1
        if c > 0 and isShort then
            return s
        end
    end

    -- Handle minutes
    if time > 60 then
        local minutes = math.floor(time / 60)
        s = s .. minutes .. "分"
        time = time - minutes * 60
        c = c + 1
        if c > 0 and isShort then
            return s
        end
    end

    -- Add seconds
    s = s .. math.floor(time) .. "秒"
    return s
end

-- 数字格式化函数
function gg.FormatLargeNumber(num)
    if num < 10000 then
        return tostring(num)
    end

    local units = {"", "万", "亿", "兆", "京"}
    local unitIndex = 1
    local result = num

    while result >= 10000 and unitIndex < #units do
        result = result / 10000
        unitIndex = unitIndex + 1
    end

    -- 保留一位小数
    result = math.floor(result * 10) / 10

    -- 如果是整数，去掉小数点
    if result == math.floor(result) then
        return tostring(math.floor(result)) .. units[unitIndex]
    else
        -- 检查小数点前的数字位数
        local wholePart = math.floor(result)
        if wholePart >= 1000 and wholePart < 10000 then
            -- 如果是4位数，去掉小数部分
            return tostring(wholePart) .. units[unitIndex]
        else
            return tostring(result) .. units[unitIndex]
        end
    end
end

-- 屏幕视角大小
---@return number, number 视角宽度和高度
function gg.get_camera_window_size()
    if not gg.camera_win_size then
        wait(1)
        gg.camera_win_size = game.WorkSpace.CurrentCamera.WindowSize
        gg.log('camera_win_size====', gg.camera_win_size)
    end
    return gg.camera_win_size.x, gg.camera_win_size.y
end

-- 获得当前玩家 (只有client会使用)
---@return number 玩家ID
function gg.get_client_uin()
    return game.Players.LocalPlayer.UserId;
end

local const_diff_str = {"普通", "冒险", "挑战", "精英"}
-- 获得难度描述
---@param i number 难度等级
---@return string 难度描述
function gg.getDiffString(i)
    return const_diff_str[i];
end

-- 获取当前玩家使用的2d控件使用的ui_root，不存在则建立  (只有client会使用)
---@return SandboxNode UI根节点
function gg.create_ui_root()

    -- local player_ = gg.getPlayerInfoByUin( gg.get_client_uin() )
    local player_ = game.Players.LocalPlayer

    if player_ and player_.PlayerGui then
        if player_.PlayerGui.ui_root then
            return player_.PlayerGui.ui_root
        else
            local ui_root = SandboxNode.New('UIRoot')
            ui_root.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
            ui_root.Name = 'ui_root'
            ui_root.Parent = player_.PlayerGui
            return ui_root;
        end
    end
end

-- 获得root_spell界面的ui_root
---@return SandboxNode 法术UI根节点
function gg.get_ui_root_spell()
    return Players.LocalPlayer.PlayerGui.ui_root_spell
end

-- 获取ui_root
---@return SandboxNode UI根节点
function gg.get_ui_root()
    return Players.LocalPlayer.PlayerGui.ui_root
end

-- 标准按钮样式格式化函数
---@param button_ UIButton 要格式化的按钮
function gg.formatButton(button_)
    -- 设置按钮填充颜色为完全透明（R:0 G:0 B:0 A:0 透明黑）
    button_.FillColor = ColorQuad.New(0, 0, 0, 0)

    -- 设定按钮按下时颜色改变效果（区别于缩放效果）        -¬-
    button_.DownEffect = Enum.DownEffect.ColorEffect

    -- 水平右对齐：以父容器右边缘为定位基准               -¬- [^6][^2]
    button_.LayoutHRelation = Enum.LayoutHRelation.Right

    -- 垂直底对齐：以父容器底部为定位基准                -¬- [^2]
    button_.LayoutVRelation = Enum.LayoutVRelation.Bottom
end

-- input 100 return  0 to 100
---@param int32 number 上限值
---@return number 随机数
function gg.rand_int(int32)
    -- return math.floor( math.random() * int32 + 0.5 )
    return math.random(int32 + 1) - 1
end

-- input 100 return  -100 to 100 (可以为负数)
---@param int32 number 范围值
---@return number 随机数
function gg.rand_int_both(int32)
    -- local ret_ = math.floor( math.random() * int32 + 0.5 )
    -- if  math.random() < 0.5 then
    -- ret_ = 0 - ret_
    -- end
    -- return  ret_
    return math.random(0 - int32, int32)
end

-- 获得两个整数之间的一个随机值
---@param int1_ number 第一个整数
---@param int2_ number 第二个整数
---@return number 随机数
function gg.rand_int_between(int1_, int2_)
    if int1_ > int2_ then
        return math.random(int2_, int1_)
    else
        return math.random(int1_, int2_)
    end
end

-- 从一个list中获得一个随机值
---@param list_ table 列表
---@return any 随机值
function gg.getRandFromList(list_)
    return list_[math.random(1, 65535) % #list_ + 1]
end

function gg.contains(list, target)
    for _, value in ipairs(list) do
        if value == target then
            return true
        end
    end
    return false
end

-- 获得随机质量
---@return number 质量等级(1-5)
function gg.rand_qulity()
    local int_ = gg.rand_int_between(1, 100)
    if int_ <= 5 then
        return 5 -- 5%
    elseif int_ <= 15 then
        return 4 -- 10%
    elseif int_ <= 45 then
        return 3 -- 30%
    elseif int_ <= 85 then
        return 2 -- 30%
    else
        return 1 -- 25%
    end
end

function gg.removeElement(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
        end
    end
end

-- 字符串分割函数，返回一个table   t_ = uu.split( "abc_cdf_dfd", "_" )
---@param s string 要分割的字符串
---@param delim string 分隔符
---@return table|nil 分割后的字符串数组
function gg.split(s, delim)
    if type(delim) ~= "string" or string_len(delim) <= 0 then
        return
    end
    local start = 1
    local t = {}
    while true do
        local pos = string_find(s, delim, start, true) -- plain find
        if not pos then
            break
        end

        table_insert(t, string_sub(s, start, pos - 1))
        start = pos + string_len(delim)
    end
    table_insert(t, string_sub(s, start))
    return t
end

-- lua-table 转字符串（打印日志使用）
---@param tbl table 要转换的表
---@param level_? number 递归层级
---@param visited? table 已访问的表
---@return string 转换后的字符串
function gg.table2str(tbl, level_, visited)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    level_ = level_ or 0
    if level_ >= 20 then
        gg.log('ERROR table2str level>=10')
        return '' -- 层数保护
    end

    visited = visited or {} -- 防止两个table互相引用，互相循环

    local tab = {'{'}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            if visited[v] then
                if v.uuid then
                    tab[#tab + 1] = 'VISITED uuid=' .. v.uuid
                else
                    tab[#tab + 1] = 'VISITED ' .. tostring(v)
                end
            else
                visited[v] = true -- table作为key等同于tostring(v)
                if v.ToString then
                    tab[#tab + 1] = tostring(k) .. '=' .. v:ToString()
                else
                    tab[#tab + 1] = tostring(k) .. gg.table2str(v, level_ + 1, visited)
                end
            end
        elseif type(v) == 'function' or type(v) == 'userdata' or type(v) == 'thread' then
            -- 忽略不打印
        else
            tab[#tab + 1] = tostring(k) .. '=' .. tostring(v)
        end
    end

    tab[#tab + 1] = '}'
    return table.concat(tab, ' ')
end

-- 打印一个lua-table
---@param t table 要打印的表
---@param info_ string 打印信息
function gg.print_table(t, info_)
    if type(t) == 'table' then
        print(info_, ' ' .. gg.table2str(t))
    else
        print(info_, ' not table= ', t)
    end
end

-- 浅拷贝 不拷贝meta
---@param ori_tab table 原始表
---@param visited table|nil 访问过的表，防止循环引用
---@return table 拷贝后的表
function gg.clone(ori_tab, visited)
    if type(ori_tab) ~= "table" then
        return nil
    end

    -- 初始化或使用传入的visited表来跟踪已访问的表
    visited = visited or {}

    -- 如果这个表已经被访问过，直接返回nil避免循环引用
    if visited[ori_tab] then
        return nil
    end

    -- 标记这个表为已访问
    visited[ori_tab] = true

    local new_tab = {}
    for i, v in pairs(ori_tab) do
        if type(v) == "table" then
            new_tab[i] = gg.clone(v, visited)
        else
            new_tab[i] = v
        end
    end

    -- 清除访问标记
    visited[ori_tab] = nil

    return new_tab
end

function gg:ShallowCopy(orig, customCopy)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = Utils:ShallowCopy(orig_value, customCopy)
        end
    else -- number, string, boolean, etc
        if customCopy then
            copy = customCopy(orig)
        else
            copy = orig
        end
    end
    return copy
end

function gg.DeepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function gg.GetTimeStamp()
    return game.RunService:CurrentSteadyTimeStampMS() / 1000
end

local function RecursivlyGet(source, paths, i, parent)
    if not source then
        return nil, i, parent
    end
    if i > #paths then
        return source, i, parent
    else
        local nextNode = source[paths[i]]
        if not nextNode then
            local numKey = tonumber(paths[i])
            if numKey and source[numKey] then
                nextNode = source[numKey]
            end
        end
        if not nextNode then
            return nil, i, source
        end
        return RecursivlyGet(nextNode, paths, i + 1, source)
    end
end

function gg.Debug(params, player)
    local vars = {}
    for _, value in ipairs(params["操作"]) do
        if value["操作"] == "变量" then
            local varDict = value["变量"]
            local source = player ---@type any
            if varDict["源"] and varDict["源"] ~= "" then
                local paths = {}
                for part in string.gmatch(varDict["源"], "[^%.]+") do
                    table.insert(paths, part)
                end
                local starter = 1
                source = game
                if paths[1] == "game" then
                    starter = 2
                elseif paths[1] == "MainStorage" then
                    source = MainStorage
                    starter = 2
                elseif paths[1] == "WorkSpace" then
                    source = game.WorkSpace
                    starter = 2
                elseif paths[1] == "UI" then
                    local ViewBase = require(MainStorage.code.client.ui.ViewBase) ---@type ViewBase
                    source = ViewBase.GetUI(paths[2])
                    starter = 3
                elseif string.sub(paths[1], -6) == "Config" then
                    source = require(MainStorage.config [paths[1]]).config
                    starter = 2
                end
                local returned, i, parent = RecursivlyGet(source, paths, starter)
                if not returned then
                    local log = gg.log("在从%s获取%s时，进行到%d(%s)时出错", source, paths, i, tostring(parent))
                    if player then
                        player:SendLog(log)
                    end
                    return
                end
                source = returned
                if type(source) == "userdata" and source.IsA and source:IsA("ModuleScript") then
                    source = require(source)
                end
            elseif varDict["快捷源"] then
                if varDict["快捷源"] == "player" then
                    source = player
                elseif varDict["快捷源"] == "gg" then
                    source = gg
                elseif varDict["快捷源"] == "Scene" then
                    source = require(MainStorage.code.server.Scene)         ---@type Scene
                end
            end
            local obj, i, parent
            if varDict["路径"] and varDict["路径"] ~= "" then
                local paths = {}
                for part in string.gmatch(varDict["路径"], "[^%.]+") do
                    table.insert(paths, part)
                end
                obj, i, parent = RecursivlyGet(source, paths, 1)
                if not obj then
                    local log = gg.log("在从%s获取%s时，进行到%d(%s)时出错", source, paths, i, tostring(parent))
                    if player then
                        player:SendLog(log)
                    end
                    return
                end
            else
                obj = source
            end
            if obj then
                vars[varDict["变量名"]] = {
                    type = type(obj),
                    obj = obj,
                    parent = parent,
                    path = varDict["路径"]
                }
            end
        elseif value["操作"] == "调用" then
            local operation = value["调用"]
            local op = {}
            for index, value in ipairs(operation["参数"]) do
                if not vars[value] then
                    -- 检查是否为字符串字面量（被双引号包围）
                    if type(value) == "string" and string.sub(value, 1, 1) == '"' and string.sub(value, -1) == '"' then
                        op[index] = string.sub(value, 2, -2)  -- 去掉首尾的双引号
                    else
                        -- 尝试转换为数字
                        local numValue = tonumber(value)
                        if numValue then
                            op[index] = numValue
                        else
                            local log = gg.log("不存在的变量", value)
                            if player then
                                player:SendLog(log)
                            end
                        end
                    end
                else
                    op[index] = vars[value].obj
                end
            end
            if operation["操作"] == "print" then
                local log = gg.log(op)
                if player then
                    player:SendLog(log)
                end
            elseif operation["操作"] == "set" or operation["操作"] == "call" then
                local funcStruct = vars[operation["调用"]]
                if not funcStruct then
                    gg.log("不存在的函数变量", operation["调用"])
                    return
                end
                local returned
                if not vars["静态函数"] then
                    returned = funcStruct.obj(funcStruct.parent, unpack(op))
                else
                    returned = funcStruct.obj(unpack(op))
                end
                if operation["操作"] == "set" then
                    vars[operation["变量名"]] = {
                        type = type(returned),
                        obj = returned,
                        parent = "CALLED",
                        path = "CALLED"
                    }
                end
                local log = gg.log(funcStruct.path, returned)
                if player then
                    player:SendLog(log)
                end
            end
        end
    end
end

function gg.GetSceneNode(path)
    if not path then return nil end

    -- Split the path by first '/'
    local sceneName, remainingPath = string.match(path, "([^/]+)/(.+)")
    if not sceneName then return nil end

    -- Get the scene using the first part
    local scene = gg.server_scene_list[sceneName]
    if not scene then return nil end

    -- Pass the remaining path to scene:Get()
    return scene:Get(remainingPath)
end

-- 打印日志使用
---@param ... any 要打印的内容
function gg.log(...)
    local tab = {}
    local n = select('#', ...)
    for i = 1, n do
        local v = select(i, ...)
        if v == nil then
            tab[i] = "nil"
        elseif type(v) == 'table' then
            if v.ToString then
                tab[i] = v:ToString()
            else
                tab[i] = gg.table2str(v)
            end
        else
            tab[i] = tostring(v)
        end
    end
    if type(tab[1]) == "string" and string.find(tab[1], "%%s") then
        local fmt_args = {}
        for i = 2, n do
            fmt_args[#fmt_args + 1] = tab[i]
        end
        tab[1] = string.format(tab[1], unpack(fmt_args))
        for i = 2, #tab do
            tab[i] = nil
        end
    end
    local s = table.concat(tab, ' ')
    print(s)
    return s
end


-- 快速判断一个xyz的每个轴距都在len的范围内
---@param dir_ Vector3 方向向量
---@param len number 长度
---@return boolean 是否在范围内
function gg.fast_in_distance(dir_, len)
    if dir_.x > 0 - len and dir_.x < len and dir_.y > 0 - len and dir_.y < len and dir_.z > 0 - len and dir_.z < len then
        return true
    else
        return false
    end
end

-- 快速判断两个点是否超距离
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@param len number 距离
---@return boolean 是否超出距离
function gg.fast_out_distance(pos1, pos2, len)
    local xx_ = math.abs(pos1.x - pos2.x)
    local yy_ = math.abs(pos1.y - pos2.y)
    local zz_ = math.abs(pos1.z - pos2.z)
    if zz_ > len or xx_ > len or yy_ > len then
        return true
    else
        return false
    end
end

-- 快速判断两个点是否超距离(length)
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@param len number 距离
---@return boolean 是否超出距离
function gg.out_distance(pos1, pos2, len)
    local dis_ = (pos1 - pos2).length
    return dis_ > len
end

-- Vector2.Normalize
---@param x number X坐标
---@param y number Y坐标
---@return number, number 标准化后的X,Y坐标
function gg.Normalize2(x, y)
    local len = math.sqrt(x * x + y * y)
    if len > 0 then
        return x / len, y / len
    else
        return 0, 0
    end
end

-- 克隆一个物体 template下对模型
---@param name_ string 模型名称
---@return Instance 克隆的模型
function gg.cloneFromTemplate(name_)
    if MainStorage.template[name_] then
        return MainStorage.template[name_]:Clone()
    elseif game.WorkSpace.template[name_] then
        return game.WorkSpace.template[name_]:Clone()
    else
        -- error
    end
end


---@param node SandboxNode
---@param path string
---@return SandboxNode|nil
function gg.GetChild(node, path)
    local root = node
    local cacheKey = path
    local fullPath = ""
    local lastPart = ""
    for part in path:gmatch("[^/]+") do -- 用/分割字符串
        if part ~= "" then
            lastPart = part
            if not node then
                gg.log(string.format("[%s]获取路径[%s]失败: 在[%s]处节点不存在。%s", root.Name, path,
                    fullPath, debug.traceback()))
                return nil
            end
            node = node[part]
            if fullPath == "" then
                fullPath = part
            else
                fullPath = fullPath .. "/" .. part
            end
        end
    end

    if not node then
        gg.log(string.format("[%s]获取路径[%s]失败: 最终节点[%s]不存在。%s", root.Name, path, lastPart, debug.traceback()))
        return nil
    end
    return node
end

-- 选择一个目标（客户端侧）(debug使用)
---@return SandboxNode|nil 选中的目标
function gg.clientPickObjectMiddle()
    local obj_list = {} -- 表示只在哪些obj里面查找
    if not gg.camera_mid_x then
        local win_size = game.WorkSpace.CurrentCamera.WindowSize
        gg.camera_mid_x = win_size.x * 0.5
        gg.camera_mid_y = win_size.y * 0.5
    end

    local ret_node_
    -- 从中间扩散选择，增大范围
    for xx = 0, 5 do
        ret_node_ = inputservice:PickObjects(gg.camera_mid_x + xx * 10, gg.camera_mid_y, obj_list)
        -- gg.log( 'clientPickObjectMiddle===:[', ret_node_, ']' )
        if ret_node_ then
            return ret_node_
        end

        ret_node_ = inputservice:PickObjects(gg.camera_mid_x - xx * 10, gg.camera_mid_y, obj_list)
        if ret_node_ then
            return ret_node_
        end
    end

    return ret_node_
end

-- 使用鼠标和触屏点击选择目标（客户端侧）（debug）
function gg.clientPickPress()
    -- 按下
    local function inputBegan(inputObj, bGameProcessd)
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
            local obj_list = {} -- 表示只在哪些obj里面查找
            for k, v in pairs(gg.clentGetContainerMonster().Children) do
                obj_list[#obj_list + 1] = v -- 只找怪物
            end

            -- 屏幕中心点位置
            local win_size = game.WorkSpace.CurrentCamera.WindowSize
            local xx = math.floor(win_size.x * 0.5)
            local yy = math.floor(win_size.y * 0.5)

            local rets
            -- 从中间扩散选择，增大范围
            for x = 0, 5 do
                rets = inputservice:PickObjects(xx + x * 10, yy, obj_list)
                -- gg.log( 'GetCursorPick[', #obj_list, '] [', rets, ']' )
                if rets then
                    break
                end

                rets = inputservice:PickObjects(xx - x * 10, yy, obj_list)
                -- gg.log( 'GetCursorPick[', #obj_list, '] [', rets, ']' )
                if rets then
                    break
                end
            end

            if rets then
                -- 改动框的显示，明确是否被选中
                rets.CubeBorderEnable = not rets.CubeBorderEnable
            end

        end
    end
    inputservice.InputBegan:Connect(inputBegan)
end

-- alias
gg.thread_call = coroutine.work

-- 等同于下面定义
-- function gg.thread_call( func_ )
-- coroutine.work( func_ )
-- end

-- 文字框
---@param root_ SandboxNode 父节点
---@param title_ string 标题文本
---@return UITextLabel 创建的文本标签
function gg.createTextLabel(root_, title_)
    local textLabel_ = SandboxNode.new('UITextLabel', root_)
    textLabel_.Size = Vector2.New(3000, 800)
    textLabel_.Pivot = Vector2.New(0.5, 0.5)

    textLabel_.FontSize = 30
    textLabel_.Scale = Vector2.New(5,5)

    textLabel_.TitleColor = ColorQuad.New(255, 255, 255, 255)
    textLabel_.FillColor = ColorQuad.New(0, 0, 0, 0)

    textLabel_.TextVAlignment = Enum.TextVAlignment.Center -- Top  Bottom
    textLabel_.TextHAlignment = Enum.TextHAlignment.Center -- Left Right

    -- textLabel_.Position   = Vector2.New( 0,  0 )
    textLabel_.Title = title_

    return textLabel_
end

function gg.createNpcImage(root_, args)
    local image_ = SandboxNode.new("UIImage")
    local icon_ = args.icon
    local size_ = args.size
    local name_ = args.name
    local active_ = args.active
    local click_pass_ = args.click_pass
    local pivot_ = args.pivot
    local position_ = args.position
    local rotation_ = args.rotation
    local scale_ = args.scale

    image_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    image_.Parent = root_

    if icon_ then
        image_.Icon = icon_
    end
    if size_ then
        image_.Size = Vector2.New(size_[1], size_[2])
    end
    if name_ then
        image_.Name = name_
    end
    if active_ then
        image_.Active = active_
    end
    if click_pass_ then
        image_.ClickPass = click_pass_
    end
    if pivot_ then
        image_.Pivot = Vector2.New(pivot_[1], pivot_[2])
    end
    if position_ then
        image_.Position = Vector3.New(position_[1], position_[2], position_[3])
    end
    if rotation_ then
        image_.Rotation = Quaternion.FromEuler(rotation_[1], rotation_[2], rotation_[3])
    end
    if scale_ then
        image_.Scale = Vector3.New(scale_[1], scale_[2], scale_[3])
    end
    return image_
end

-- 图片
function gg.createImage(root_, icon_)
    local image_ = SandboxNode.new("UIImage")
    image_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    image_.Parent = root_

    if icon_ then
        image_.Icon = icon_
    end

    -- image_.Name      = "xxx"
    -- image_.Active    = true
    -- image_.ClickPass = true

    -- image_.Size  = Vector2.New(100, 100)
    -- image_.Pivot = Vector2.New(0.5, 0.5)  --默认

    -- imgTouchBg.LayoutHRelation = Enum.LayoutHRelation.Left
    -- imgTouchBg.LayoutVRelation = Enum.LayoutVRelation.Top

    -- bar_.FillMethod = Enum.FillMethod.Horizontal
    -- bar_.FillAmount = 1

    -- bar_.FillColor = ColorQuad.New( 255,0,0,255 )

    return image_
end

function gg.createImageNode(root_, args)
    local image_ = SandboxNode.new("UIImage", root_)
    image_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    -- image_.Parent    = root_
    image_.Name = args.name
    image_.Active = true
    image_.ClickPass = true
    image_.Visible = false
    if args.icon then
        image_.Icon = args.icon
    end
    if args.size then
        image_.Size = Vector2.New(args.size[1], args.size[2])
    end
    return image_
end
-- 按钮
function gg.createButton(root_, args)
    local button_ = SandboxNode.new("UIButton", root_)
    -- button_.Parent    = root_
    button_.Title = args.title
    if args.title_Size then
        button_.TitleSize = button_.title_Size
    end
    gg.formatButton(button_)
    return button_
end

-- 按客户端背包id，获得物品详情
---@param bag_id_ number 背包ID
---@return table|nil 物品详情
function gg.getClientBagItemByBagId(bag_id_)
    local uuid_
    if gg.client_bag_index[bag_id_] then
        uuid_ = gg.client_bag_index[bag_id_].uuid
    end
    if uuid_ and gg.client_bag_items[uuid_] then
        return gg.client_bag_items[uuid_]
    end
    return nil
end

-- 获得客户端背包中，某一个可堆叠物品的数量，魔力碎片1 神力碎片2
---@param mat_id_ number 材料ID
---@param quality_ number 品质
---@return number 数量
function gg.getClientBagMatNum(mat_id_, quality_)
    for k, v in pairs(gg.client_bag_items) do
        if v.mat_id == mat_id_ and v.quality == quality_ then
            return v.num or 0
        end
    end
    return 0
end

-- 客户端的背包是否全满
function gg.ifClientBagFull()
    for bag_id_ = 10000, 10035 do
        if gg.client_bag_index[bag_id_] then
            -- 有物品了
        else
            return false -- 没有物品
        end
    end
    return true
end

-- 获得质量字符串
local const_quality_name = {
    [1] = '普通',
    [2] = '精良',
    [3] = '神器',
    [4] = '史诗',
    [5] = '传说',
    [6] = '神話'
}

function gg.getQualityStr(quality_)
    return const_quality_name[quality_] or '未知'
end

-- 获得质量颜色
local const_quality_color = {
    [1] = ColorQuad.New(255, 255, 255, 255), -- 白色
    [2] = ColorQuad.New(0, 0, 255, 255), -- 蓝色
    [3] = ColorQuad.New(255, 255, 0, 255), -- 黄金
    [4] = ColorQuad.New(255, 0, 255, 255), -- 粉色
    [5] = ColorQuad.New(255, 0, 0, 255) -- 红色
}
function gg.getQualityColor(quality_)
    return const_quality_color[quality_] or ColorQuad.New(0, 0, 0, 255)
end

function gg.eval(expr)
    -- 自动修正常见中文符号为英文
    expr = expr
        :gsub("，", ",")
        :gsub("（", "(")
        :gsub("）", ")")
        :gsub("－", "-")
        :gsub("−", "-")
        :gsub("—", "-")
        :gsub("＋", "+")
        :gsub("×", "*")
        :gsub("＊", "*")
        :gsub("÷", "/")
        :gsub("／", "/")
        :gsub("．", ".")
    local ok, result = pcall(function()
        expr = expr:gsub("%s+", "")  -- 移除空格
        local pos = 1

        -- 先声明所有函数（避免未定义错误）
        local parseExpr, parseMulDiv, parsePower, parseAtom, parseNumber

        parseNumber = function()
            local start = pos
            if expr:sub(pos, pos) == "-" then pos = pos + 1 end
            while pos <= #expr and (expr:sub(pos, pos):match("%d") or expr:sub(pos, pos) == ".") do
                pos = pos + 1
            end
            return tonumber(expr:sub(start, pos - 1))
        end

        parseAtom = function()
            -- 支持 max/min/clamp 函数
            local func3 = expr:sub(pos, pos+2)
            local func5 = expr:sub(pos, pos+4)

            if func3 == "max" or func3 == "min" then
                pos = pos + 3
                -- 跳过函数名后的空白字符
                while pos <= #expr and expr:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end

                if pos > #expr or expr:sub(pos, pos) ~= "(" then
                    error("Missing '(' after function name")
                end
                pos = pos + 1

                local args = {}
                -- 解析第一个参数
                if pos <= #expr and expr:sub(pos, pos) ~= ")" then
                    args[1] = parseExpr()

                    -- 解析后续参数
                    while pos <= #expr and expr:sub(pos, pos) == "," do
                        pos = pos + 1
                        if pos <= #expr then
                            args[#args+1] = parseExpr()
                        end
                    end
                end

                if pos > #expr or expr:sub(pos, pos) ~= ")" then
                    error("Missing ')' after function arguments")
                end
                pos = pos + 1

                if func3 == "max" then
                    return math.max(unpack(args))
                else
                    return math.min(unpack(args))
                end
            elseif func5 == "clamp" then
                pos = pos + 5
                -- 跳过函数名后的空白字符
                while pos <= #expr and expr:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end

                if pos > #expr or expr:sub(pos, pos) ~= "(" then
                    error("Missing '(' after clamp function name")
                end
                pos = pos + 1

                local args = {}
                -- 解析第一个参数
                if pos <= #expr and expr:sub(pos, pos) ~= ")" then
                    args[1] = parseExpr()

                    -- 解析后续参数
                    while pos <= #expr and expr:sub(pos, pos) == "," do
                        pos = pos + 1
                        if pos <= #expr then
                            args[#args+1] = parseExpr()
                        end
                    end
                end

                if pos > #expr or expr:sub(pos, pos) ~= ")" then
                    error("Missing ')' after clamp function arguments")
                end
                pos = pos + 1

                -- clamp(value, min, max) 函数实现
                if #args >= 3 then
                    local value, minVal, maxVal = args[1], args[2], args[3]
                    -- 使用与 math.clamp 相同的逻辑
                    if value < minVal then return minVal end
                    if value > maxVal then return maxVal end
                    return value
                else
                    error("clamp function requires 3 arguments: clamp(value, min, max)")
                end
            elseif expr:sub(pos, pos) == "(" then
                pos = pos + 1
                local val = parseExpr()
                if pos > #expr or expr:sub(pos, pos) ~= ")" then
                    error("Missing closing parenthesis")
                end
                pos = pos + 1
                return val
            else
                return parseNumber()
            end
        end

        parsePower = function()
            local left = parseAtom()
            while pos <= #expr and expr:sub(pos, pos) == "^" do
                pos = pos + 1
                left = left ^ parseAtom()  -- 右结合（如 2^3^2 = 2^(3^2)）
            end
            return left
        end

        parseMulDiv = function()
            local left = parsePower()
            while pos <= #expr do
                local op = expr:sub(pos, pos)
                if op == "*" or op == "/" then
                    pos = pos + 1
                    local right = parsePower()
                    if op == "*" then
                        left = left * right
                    else
                        left = left / right
                    end
                else
                    break
                end
            end
            return left
        end

        parseExpr = function()
            local left = parseMulDiv()
            while pos <= #expr do
                local op = expr:sub(pos, pos)
                if op == "+" or op == "-" then
                    pos = pos + 1
                    local right = parseMulDiv()
                    if op == "+" then
                        left = left + right
                    else
                        left = left - right
                    end
                else
                    break
                end
            end
            return left
        end

        return parseExpr()
    end)
    if ok then
        return result
    else
        gg.log("[gg.eval] 公式计算失败: " .. tostring(result) .. "，表达式: " .. tostring(expr))
        return 0
    end
end

-- 添加table.contains函数
table.contains = function(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 延迟加载Dict，避免循环依赖
local _Dict = nil
local dictMetatable = {
    __index = function(t, k)
        if k == "Dict" then
            if not _Dict then
                _Dict = require(MainStorage.code.common.func_utils.Dict)
            end
            return _Dict
        end
        return rawget(t, k)
    end
}
setmetatable(gg, dictMetatable)

return gg;
