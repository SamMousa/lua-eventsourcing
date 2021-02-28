if LogEntry == nil then
    LogEntry = {
    }
end

--[[
    LogEntry models an entry in the event log
    We use short field names because the field names are serialized to disk.
    The assumption is that all field names are private to this file and other files will use functions to get what they need.
    Since functions are not serialized we do use descriptive names for the functions
]]--
LogEntry.__index = LogEntry
LogEntry._cls = 'LE'

function LogEntry:extend(identifier, snapshot)
    local o = self:new()
    o.__index = o
    o._cls = identifier
    o._snapshot = snapshot or false
    return o
end

function LogEntry:new()
    local o = {}
    setmetatable(o, self)
    o.cls = self._cls
    o.t = Util.time()
    o.r = math.random(2 ^ 31- 1)
    return o
end

function LogEntry:class()
    return self.cls
end

-- return bool whether this is a snapshot entry
function LogEntry:snapshot()
    -- this is a property of the class, not of the instance
    -- this therefore is not serialized to saved variables
    return self._snapshot
end

function LogEntry:time()
    return self.t
end

function LogEntry:random()
    return self.r
end


-- return int the weeknumber of this entry
function LogEntry:weekNumber()
    return Util.WeekNumber(self.t)
end

-- Return a sorted list set up for log entries
function LogEntry.sortedList(data)
    return SortedList:new(data or {}, Util.CreateMultiFieldSorter('t', 'r'), true)
end
