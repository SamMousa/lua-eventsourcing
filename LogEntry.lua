if LogEntry == nil then
    LogEntry = {
        TYPES = {}

    }
end

--[[
    LogEntry models an entry in the event log
    We use short field names because the field names are serialized to disk.
    The assumption is that all field names are private to this files and other files will use functions to get what they need.
    Since functions are not serialized we do use descriptive names for the functions
]]--
LogEntry.__index = LogEntry
LogEntry._cls = 'LE'
LogEntry.TYPES[LogEntry._cls] = LogEntry



function LogEntry:__new()
    local o = {}
    setmetatable(o, self)
    o.cls = self._cls
    o.t = Util.time()
    o.r = math.random(2 ^ 31- 1)
    return o
end

-- Register a subclass
function LogEntry:register(cls, mutator)
    local o = self:__new()
    o.__index = o
    o._cls = cls
    o.super = LogEntry.new
    o._mutator = mutator
    LogEntry.TYPES[cls] = o
    return o
end

function LogEntry:new(team, creator)
    local o = LogEntry.__new(self)
    o.t = team
    o.cr = creator
    return o
end

function LogEntry:creator()
    return self.cr
end


function LogEntry:cast(table)
    -- Find which meta table we should use
    if LogEntry.TYPES[table.cls] == nil then
        error("Unknown class: " .. table.cls)
    end
    setmetatable(table, LogEntry.TYPES[table.cls])
end

function LogEntry:class()
    return self.cls
end

function LogEntry:time()
    return self.t
end

function LogEntry:weekNumber()
    return Util.WeekNumber(self.t)
end

-- Return a sorted list set up for log entries
function LogEntry.sortedList(data)
    return  SortedList:new(data or {}, Util.CreateMultiFieldSorter('t', 'r'))
end

function LogEntry:applyToState(state)
    if self._mutator == nil then
        Util.DumpTable(self)
        error("No mutator found")
    end
    self._mutator(state, self)
end
