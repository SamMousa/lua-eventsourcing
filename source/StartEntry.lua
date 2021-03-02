--[[
    Example start entry
]]--

local Factory, _ = LibStub:NewLibrary("EventSourcing/StartEntry", 1)
if not Factory then
    return
end

local LogEntry = LibStub("EventSourcing/LogEntry")

local StartEntry = LogEntry:extend("START", true)


function StartEntry:new()
    local o = LogEntry.new(self)
    o.t = 1
    return o
end

function Factory.create()
    return StartEntry:new()
end

function Factory.class()
    return StartEntry
end
