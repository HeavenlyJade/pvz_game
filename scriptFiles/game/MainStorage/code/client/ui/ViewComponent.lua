local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.code.common.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.code.common.MGlobal) ---@type gg

---@class ViewComponent:Class
---@field node UIComponent
---@field New fun(node: SandboxNode, ui: ViewBase, path?:string,  ...): ViewComponent
---@field path string 组件的绝对路径
local ViewComponent = ClassMgr.Class("ViewComponent")

function ViewComponent:OnInit(node, ui, path)
    if node.className then
        self.node = node.node
    else
        self.node = node
    end
    self.defaultPos = self.node.Position
    self.defaultSize = self.node.Size
    self.defaultRotation = self.node.Rotation
    self.ui = ui ---@type ViewBase
    self.index = 0
    self.path = path or ""
    self.extraParams = {} -- 可在此存储任意与该按钮相关的数据
end

---@return Vector2
function ViewComponent:GetGlobalPos()
    return self.node:GetGlobalPos()
end

function ViewComponent:SetGray(isGray)
    self.node.Grayed = isGray
end

---@override
function ViewComponent:GetToStringParams()
    return {
        node = self.path
    }
end

---@return ViewComponent
function ViewComponent:GetComponent(path)
    return self:Get(path)
end

---@return ViewItem
function ViewComponent:GetItem(path)
    local ViewItem = require(MainStorage.code.client.ui.ViewItem) ---@type ViewItem
    return self:Get(path, ViewItem)
end

---@return ViewToggle
function ViewComponent:GetToggle(path)
    local ViewToggle = require(MainStorage.code.client.ui.ViewToggle) ---@type ViewToggle
    return self:Get(path, ViewToggle)
end

---@return ViewList
function ViewComponent:GetList(path, onAddElementCb)
    local ViewList = require(MainStorage.code.client.ui.ViewList) ---@type ViewList
    return self:Get(path, ViewList, onAddElementCb)
end

---@return ViewButton
function ViewComponent:GetButton(path)
    local ViewButton = require(MainStorage.code.client.ui.ViewButton) ---@type ViewButton
    return self:Get(path, ViewButton)
end

---@generic T : ViewComponent
---@param path string 相对路径
---@param type? T 组件类型
---@param ... any 额外参数
---@return T
function ViewComponent:Get(path, type, ...)
    return self.ui:Get(self.path .. "/" .. path, type, ...)
end

---@param color Vector4
function ViewComponent:SetColor(color)
    local c
    if color.x <= 1 and color.y <= 1 and color.z <= 1 and color.w <= 1 then
        c = ColorQuad.New(color.x * 255, color.y * 255, color.z * 255, color.w * 255)
    else
        c = ColorQuad.New(color.x, color.y, color.z, color.w)
    end
    if self.node:IsA("UIImage") then
        self.node.FillColor = c
    elseif self.node:IsA("UITextLabel") then
        local node = self.node ---@cast node UITextLabel
        node.TitleColor = c
    end
end

---@param visible boolean
function ViewComponent:SetVisible(visible)
    if type(visible) ~= "boolean" then
        if type(visible) == "nil" then
            visible = false
        else
            visible = true
        end
    end
    self.node.Visible = visible
    self.node.Enabled = visible
end

---@param ui_view ViewComponent 榜单UI视图
---@param old_ranking_list table 旧榜单数据，包含 {name, uin, val} 字段
---@param new_ranking_list table 新榜单数据，包含 {name, uin, val} 字段
---@param duration number 动画持续时间（秒），默认1.0
function ViewComponent:UpdateRankingAnimation(ui_view, old_ranking_list, new_ranking_list, my_uin, duration)
    gg.log('-----', old_ranking_list, new_ranking_list, my_uin)

    duration = duration or 1.0
    local update_interval = 0.016 -- 约60fps

    -- 终止之前的动画
    if self._ranking_animation_flag then
        self._ranking_animation_flag.stop = true
    end

    local flag = { stop = false }
    self._ranking_animation_flag = flag
    -- 获取榜单列表映射
    local rang_list = {
        ui_view:Get("排行榜单背景/排名榜/排名_1"),
        ui_view:Get("排行榜单背景/排名榜/排名_2"),
        ui_view:Get("排行榜单背景/排名榜/排名_3"),
        ui_view:Get("排行榜单背景/排名榜/排名_4"),
        ui_view:Get("排行榜单背景/排名榜/排名_5"),
    }


    -- 创建旧榜单映射
    local old_ranking_map = {}
    for i, item in ipairs(old_ranking_list) do
        if i > 5 then
            break
        end
        old_ranking_map[item.uin] = {
            rank = i,
            val = item.val,
            name = item.name
        }
    end

    -- 创建新榜单映射
    local new_ranking_map = {}
    for i, item in ipairs(new_ranking_list) do
        if i > 5 then
            break
        end
        new_ranking_map[item.uin] = {
            rank = i,
            val = item.val,
            name = item.name
        }
    end

    -- 计算变化
    local changes = {}
    for uin, new_data in pairs(new_ranking_map) do
        local old_data = old_ranking_map[uin]
        if old_data then
            -- 榜单变化
            local rank_diff = old_data.rank - new_data.rank

            -- 值变化
            local val_diff = new_data.val - old_data.val

            if rank_diff ~= 0 or val_diff ~= 0 then
                local child = rang_list[old_data.rank]

                if child then
                    local start_pos_y = (old_data.rank-1) * 50 -- current_pos.y
                    local is_up = rank_diff > 0 and -1 or 1
                    local end_pos_y = start_pos_y + (is_up * 50 * math.abs(rank_diff))
                    table.insert(changes, {
                        -- 开始的pos_y
                        start_pos_y = start_pos_y,
                        -- 结束的pox_y
                        end_pos_y = end_pos_y,
                        uin = uin,
                        old_rank = old_data.rank,
                        new_rank = new_data.rank,
                        rank_diff = rank_diff,
                        old_val = old_data.val,
                        new_val = new_data.val,
                        name = new_data.name
                    })
                end
            end
        else
            table.insert(changes, {
                ---- 开始的pos_y
                --start_pos_y = start_pos_y,
                ---- 结束的pox_y
                --end_pos_y = end_pos_y,
                --rank_diff = rank_diff,
                --old_rank = old_data.rank,
                --old_val = old_data.val,
                uin = uin,
                new_rank = new_data.rank,
                new_val = new_data.val,
                name = new_data.name
            })
        end
    end




    -- 如果没有变化，直接返回
    if #changes == 0 then
        return
    end
    local function ParseChineseNumber(str)
        if type(str) ~= "string" then
            return tonumber(str) or 0
        end
        local num = string.match(str, "([%d%.?]+)")
        num = tonumber(num)
        if not num then return 0 end
        if string.find(str,'万') then
            return num * 1e4
        elseif string.find(str,'亿') then
            return num * 1e8

        elseif string.find(str,'兆') then
            return num * 1e12
        elseif string.find(str,'京') then
            return num * 1e16
        end
        return num
    end
    -- 动画主循环
    local function run_animation()
        local elapsed = 0

        -- 第一阶段：数值滚动动画 (60%时间)
        local val_duration = duration * 0.6
        while elapsed < val_duration do
            if self._ranking_animation_flag and self._ranking_animation_flag.stop then
                break
            end
            elapsed = elapsed + update_interval
            local t = math.min(elapsed / val_duration, 1)

            -- 使用缓动函数
            local ease_t = t * t * (3 - 2 * t) -- smoothstep

            -- 更新所有项目的数值显示
            for i, item in ipairs(new_ranking_list) do
                -- 更新UI显示
                local old_data = old_ranking_map[item.uin]
                if old_data then
                    local child = rang_list[old_data.rank]
                    -- 更新老表的 伤害 值
                    if child then
                        local text_node = child:Get("伤害").node
                        if text_node then
                            local start_val = ParseChineseNumber(text_node.Title)
                            local end_val = item.val
                            local current_val = math.floor(start_val + (end_val - start_val) * ease_t)
                            local display_text = gg.FormatLargeNumber(current_val)
                            text_node.Title = display_text
                        end
                    end
                end
                if item.uin == my_uin then
                    local end_val = item.val
                    local text_node = ui_view:Get("排行榜单背景/我的伤害/伤害").node
                    local start_val = ParseChineseNumber(text_node.Title)
                    local current_val = math.floor(start_val + (end_val - start_val) * ease_t)
                    local display_text = gg.FormatLargeNumber(current_val)
                    text_node.Title = display_text
                end
            end
            ease_t = 1 - (1 - t) * (1 - t) -- easeOutQuad
            for _, change in ipairs(changes) do
                if not change.start_pos_y then
                    -- 直接变更
                    local rank = change.new_rank
                    local val = change.new_val
                    local name = change.name
                    local child = rang_list[rank]
                    -- 更新老表的 伤害 值
                    if child then
                        child:Get("名字").node.Title = name
                        child:Get("伤害").node.Title = gg.FormatLargeNumber(val)
                    end
                else
                    if change.rank_diff ~= 0 then
                        -- 根据排名变化方向设置动画
                        local start_pos_y = change.start_pos_y
                        local end_pos_y = change.end_pos_y
                        local old_child = rang_list[change.old_rank]
                        local new_child = rang_list[change.new_rank]
                        if old_child and new_child then
                            local current_pos = old_child.node.Position
                            local y = (start_pos_y + (end_pos_y - start_pos_y) * ease_t)
                            gg.log('角色名:',change.name,'  [开始位置-结束位置][',start_pos_y,'-',end_pos_y,']当前位置:', y,' 当前时间:',ease_t)
                            old_child.node.Position = Vector2.New(current_pos.x,y)
                        end
                    end
                end
            end
            wait(update_interval)
        end
        -- 最终状态更新
        self:UpData(ui_view,new_ranking_list,rang_list,my_uin)
    end

    -- 启动动画
    if coroutine and coroutine.create then
        gg.log('携程开始')
        local co = coroutine.create(run_animation)
        coroutine.resume(co)
        gg.log('携程结束')
    else
        -- 没有协程支持时直接显示最终状态
        self:UpData(new_ranking_list,rang_list,my_uin)
    end
end

function ViewComponent:UpData(ui_view,new_ranking_list,rang_list,my_uin)

    for i = 1, 5 do
        local data = new_ranking_list[i]
        if data then
            rang_list[i]:Get("名次").node.Title = i .. '.'
            rang_list[i]:Get("名字").node.Title = data.name
            rang_list[i]:Get("伤害").node.Title = tostring(math.floor(data.val))
            rang_list[i].node.Position = Vector2.New(0,(i-1) * 50)
        else
            rang_list[i]:Get("名次").node.Title = ''
            rang_list[i]:Get("名字").node.Title = ''
            rang_list[i]:Get("伤害").node.Title = ''
            rang_list[i].node.Position = Vector2.New(0,(i-1) * 50)
        end
    end
    for i, v in ipairs(new_ranking_list) do
        if v.uin == my_uin then
            ui_view:Get("排行榜单背景/我的伤害/伤害").node.Title = gg.FormatLargeNumber(v.val)
            break
        end
    end
    self._ranking_animation_flag = nil
end

---@param ranking_list_container UIComponent 榜单列表容器
---@param rank number 排名
---@param name string 玩家名称
---@param val number 数值
---@param uin number 玩家ID
function ViewComponent:UpdateRankingItem(ranking_list_container, rank, name, val, uin)
    -- 获取指定排名的UI组件
    local child = ranking_list_container:GetChild(rank)
    if child then
        local text_node = child:Get("名次").node
        if text_node then
            local gg = require(MainStorage.code.common.MGlobal) ---@type gg
            local display_text = string.format("%d. %s: %s", rank, name, gg.FormatLargeNumber(val))
            text_node.Title = display_text
        end
    end
end

---@param ranking_list_container UIComponent 榜单列表容器
---@param uin number 玩家ID
---@param distance number 移动距离
---@param is_up boolean 是否向上移动
function ViewComponent:AnimateRankingItem(ranking_list_container, start_pos_y, end_pos_y, ease_t, change)


    gg.log('change - ', change)
    -- 查找对应的UI组件
    local child = ranking_list_container:GetChild(change.old_rank)
    if child then
        local current_pos = child.node.Position
        child.node.Position = Vector2.New(
                current_pos.x,
                (start_pos_y + (end_pos_y - start_pos_y) * ease_t)
        )
    end
end

return ViewComponent
