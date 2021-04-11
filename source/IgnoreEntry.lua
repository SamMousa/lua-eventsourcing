
local Factory, _ = LibStub:NewLibrary("EventSourcing/IgnoreEntry", 1)
if not Factory then
    return
end


local LogEntry = LibStub("EventSourcing/LogEntry")
local IgnoreEntry = LogEntry:extend('IGN')

function IgnoreEntry:new(entry, timestamp, counter, creator)
    local o = LogEntry.new(self, creator)
    o.ref = entry:numbersForHash()
    o.t = timestamp
    o.co = counter
    return o
end

function IgnoreEntry:fields()
    local result = LogEntry:fields()
    table.insert(result, 'ref')
    return result
end
