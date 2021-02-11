-- This is a POC impelemtation of OOP Classes in Lua language

-- Member Resolution Order for classes
-- Allows virtual class members and super class member access
-- See: https://www.python.org/download/releases/2.3/mro/
-- MRO[className] => mro for the class
local MRO = {}

local function ComputeMRO(cls, bases)

    -- Naive implementation of the C3 algorithm.

    local result = {cls}
    local lists = {}

    for _, base in ipairs(bases) do
        local list = MRO[base]
        assert(list ~= nil, "Base class '" .. tostring(base) .. "' not found!")
        lists[#lists + 1] = {table.unpack(list)}
    end

    while #lists > 0 do

        local head = nil
        local i = 0

        while head == nil and i < #lists do
            i = i + 1

            head = lists[i][1]
            local j = 0

            while head ~= nil and j < #lists do
                j = j + 1

                if i ~= j then
                    local tail = lists[j]
                    local k = 1
                    while head ~= nil and k < #tail do
                        k = k + 1
                        if head == tail[k] then
                            head = nil
                        end
                    end
                end
            end
        end

        if head == nil then
            error("Cannot compute MRO for class '" .. tostring(cls) .. "' !")
        end

        result[#result + 1] = head

        i = 1
        while i <= #lists do
            local list = lists[i]
            if list[1] == head then
                table.remove(list, 1)
            end
            if #list > 0 then
                i = i + 1
            else
                table.remove(lists, i)
            end
        end
    end

    return result
end

-- MEMBERS[className] => non-inherited class members
local MEMBERS = {}

local function DefineClass(name, bases, members)

    assert((type(name) == "string") and (#name > 0), "Invalid class name '" .. tostring(className) .. "'.")
    assert(MRO[name] == nil, "Redefining class '" .. tostring(name) .. "'.")

    MRO[name] = ComputeMRO(name, bases)
    MEMBERS[name] = members or {}
end

local CreateMethod

local function WrapMember(className, idx, member)
    if type(member) == "function" then
        return CreateMethod(className, idx, member)
    end
    return member
end

local function GetClassMemberHelper(className, mroIdx, key)

    local mro = MRO[className]
    assert(mro ~= nil, "Invalid class name '" .. tostring(className) .. "'.")

    local member = nil
    local idx = mroIdx - 1

    while (member == nil) and (idx < #mro) do
        idx = idx + 1
        member = MEMBERS[mro[idx]][key]
    end

    assert(member ~= nil, "Class member not found: '" .. tostring(className) .. "(" .. tostring(mroIdx) .. ")." .. tostring(key) .. "'. MRO: '" .. table.concat(mro, ", ") .. "'.")

    return WrapMember(className, idx, member)
end

local function GetStaticClassMember(ctx, key)
    
    local mro = MRO[ctx.__className]
    assert(mro ~= nil, "Invalid class name '" .. tostring(className) .. "'.")
    
    local member = MEMBERS[mro[ctx.__mroIdx]][key]
    assert(member ~= nil, "Static class member not found: '" .. tostring(className) .. "." .. tostring(key) .. "'.")
    
    return WrapMember(ctx.__className, ctx.__mroIdx, member)
end

local CreateSuperInstance
local CreateStaticInstance

local function GetClassMember(ctx, key)

    if key == "super" then
        return CreateSuperInstance(ctx)
    end

    if key == "static" then
        return CreateStaticInstance(ctx)
    end

    return GetClassMemberHelper(ctx.__className, 1, key)
end

local function GetSuperClassMember(ctx, key)
    return GetClassMemberHelper(ctx.__className, ctx.__mroIdx + 1, key)
end

local function CallMethod(ctx, ...)
    local fn, ctx = ctx.__function, {__className = ctx.__className, __mroIdx = ctx.__mroIdx}
    setmetatable(ctx, {__index = GetClassMember})
    return fn(ctx, ...)
end

local function CreateInstance(name)
    local ctx = {__className = name, __mroIdx = 1}
    setmetatable(ctx, {__index = GetClassMember})
    return ctx
end

CreateSuperInstance = function(ctx)
    local ctx = {__className = ctx.__className, __mroIdx = ctx.__mroIdx}
    setmetatable(ctx, {__index = GetSuperClassMember})
    return ctx
end

CreateStaticInstance = function(ctx)
    local ctx = {__className = ctx.__className, __mroIdx = ctx.__mroIdx}
    setmetatable(ctx, {__index = GetStaticClassMember})
    return ctx
end

CreateMethod = function(className, mroIdx, callable)
    local ctx = {__className = className, __mroIdx = mroIdx, __function = callable}
    setmetatable(ctx, {__call = CallMethod})
    return ctx
end

-------------------------------------
-- TEST
-------------------------------------

DefineClass("Animal", {}, {
    GetSound = function(self) error("Not implemented!") end,
    GetUnison = function(self) return "" end
})

DefineClass("Dog", {"Animal"}, {
    Bark = function(self) return "Bark" end,
    GetSound = function(self) return self.Bark() end,
    GetUnison = function(self) return (self.super.GetUnison() .. ", " .. self.static.GetSound()) end
})

DefineClass("Cat", {"Animal"}, {
    Meow = function(self) return "Meow" end,
    GetSound = function(self) return self.Meow() end,
    GetUnison = function(self) return (self.super.GetUnison() .. ", " .. self.static.GetSound()) end
})

DefineClass("Duck", {"Animal"}, {
    Quack = function(self) return "Quack" end,
    GetSound = function(self) return self.Quack() end,
    GetUnison = function(self) return (self.super.GetUnison() .. ", " .. self.static.GetSound()) end
})

DefineClass("Mutant", {"Duck", "Cat", "Dog"}, {
    GetUnison = function(self) return self.super.GetUnison() end
})

local soundTest = {
    Dog = "Bark",
    Cat = "Meow",
    Duck = "Quack",
}

for cls, sound in pairs(soundTest) do
    assert(CreateInstance(cls).GetSound() == sound)
end

local mutant = CreateInstance("Mutant")
assert(mutant.GetUnison() == ", Bark, Meow, Quack")

for _, sound in pairs(soundTest) do
    assert(mutant[sound]() == sound)
end