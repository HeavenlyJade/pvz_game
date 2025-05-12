--- V109 miniw-haima
--- 对class父子继承类的封装

if  _G.CommonModule then
	--print( 'use cache CommonModule' )
	return _G.CommonModule
end

---@class CommonModule        对class父子继承类的封装
local CommonModule = {}
_G.CommonModule = CommonModule

function CommonModule.Clone(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local newObject = {}
		lookup_table[object] = newObject
		for key, value in pairs(object) do
			newObject[_copy(key)] = _copy(value)
		end
		return setmetatable(newObject, getmetatable(object))
	end
	return _copy(object)
end

local s_register_class = {}
function CommonModule.GetRegisterClass( classname )
	return s_register_class[classname]
end

function CommonModule.RegisterClass( classname, cls)
	assert(s_register_class[classname] == nil, string.format("classname[%s]is exist", classname))
	s_register_class[classname] = cls
end

---@class Class
---@field className string 类名
---@field New fun(...: any): any 返回本类的实例
local Class = {}

---@generic T : Class
---@param name string 类名
---@param ... Class 父类
---@return T 返回类定义
function CommonModule.Class( name, ...)
	local cls = nil
	local super = ...

	if super then
		cls = CommonModule.Clone(super)
		cls.super = super
	else
		cls = { OnInit = function() end, Destroy = function() end}
	end

	cls.__index = cls
	cls.className = name

	local create = nil
	create = function(instance, c, ...)
		if c.super then
            create(instance, c.super, ...)
        end
		c.className = name
        if c.OnInit then
            c.OnInit(instance, ...)
        end
	end

	function cls.New(...)
        local instance = setmetatable({}, cls)
        create(instance, cls, ...)
        return instance
    end

    CommonModule.RegisterClass(name, cls)

    return cls
end

function math.clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end

	return value
end

return CommonModule