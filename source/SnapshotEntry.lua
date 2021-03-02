--[[
    This event models an amount of points given to a set of players on a specific ledger
]]--
local SnapshotEntryLib, _ = LibStub:NewLibrary("EventSourcing/Entries", 1)
if not SnapshotEntryLib then
    return
end

local LogEntry = LibStub("EventSourcing/LogEntry")

local SnapshotEntry = LogEntry:extend('START', true):extend('SNAP', function(state, entry)
    if table.wipe ~= nil then
        -- wow specific table wipe
        table.wipe(state)
    else
        -- dumb table wipe
        for k in pairs(state) do
            table.remove(k)
        end
    end

    for k, v in pairs(entry.savedstate) do
        state[k] = v
    end
end)

function SnapshotEntry:new(state)
    local o = self.super(self);
    o.savedstate = state
    return o
end

function SnapshotEntry:extend(identifier)
    return LogEntry:extend('START', true):extend(identifier, true)
end

function SnapshotEntryLib.createEntry(state)
    return SnapshotEntryLib:new(state)
end
