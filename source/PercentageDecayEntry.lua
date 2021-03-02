--[[
    This event models an amount of points given to a set of players on a specific ledger
]]--

local Factory, _ = LibStub:NewLibrary("EventSourcing/PercentageDecayEntry", 1)
if not Factory then
    return
end

local LogEntry = LibStub("EventSourcing/LogEntry")
local PercentageDecayEntry = LogEntry:extend('PDE')

function PercentageDecayEntry:new(percentage, creator, team)
    local o = LogEntry.new(self);
    o.cr = creator
    o.team = team
    o.a = percentage
    return o
end

function PercentageDecayEntry:creator()
    return self.cr
end
function PercentageDecayEntry:applyDecay(balance)
    -- We multiply by 100 and divide by 100 outside the floor to implement rounding
    return math.floor(balance * 100 * 100 / (100 + self.a)) / 100
end

function PercentageDecayEntry:amount()
    return self.a
end

function Factory.create(percentage, creator, team)
    return PercentageDecayEntry:new(percentage, creator, team)
end

function Factory.class()
    return PercentageDecayEntry
end
