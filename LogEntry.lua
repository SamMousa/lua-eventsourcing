if LogEntry == nil then
    LogEntry = {

    }
end

--[[
    LogEntry models an entry in the event log
    We use short field names because the field names are serialized to disk.
    The assumption is that all field names are private to this files and other files will use functions to get what they need.
    Since functions are not serialized we do use descriptive names for the functions
]]--

function LogEntry:__new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.cls = 'LE'
    o.t = Util.time()
    o.r = math.random(2 ^ 31 - 1)
    return o
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
-- This is not really needed, one could also inspect the cls member
function LogEntry:className()
    local meta = getmetatable(self)
    if (meta == LogEntry) then
        return 'LogEntry'
    elseif (meta == PlayerLogEntry) then
        return 'PlayerLogEntry'
    elseif (meta == SimpleDkpAwardEntry) then
        return 'SimpleDkpAwardEntry'
    end
end

function LogEntry:time()
    return self.t
end

function LogEntry:weekNumber()
    return Util.WeekNumber(self.t)
end

-- Return a sorted list set up for log entries
function LogEntry.sortedList()
    return  SortedList:new({}, Util.CreateMultiFieldSorter('t', 'r'))
end

function LogEntry:value()
    return self._value
end

PlayerLogEntry = LogEntry:__new()

function PlayerLogEntry:new(player)
    local o = LogEntry.__new(self);
    o.cls = 'PLE'
    o.p = player

    return o
end

function PlayerLogEntry:player()
    return self.p
end

PlayerAmountEntry = PlayerLogEntry:__new()

function PlayerAmountEntry:new(player, amount, creator)
    local o = PlayerLogEntry.new(self, player);
    o.cls = 'PAE'
    o.a = amount
    o.cr = creator
    return o
end

function PlayerAmountEntry:creator()
    return self.cr
end

function PlayerAmountEntry:amount()
    return self.a
end

LogEntry.TYPES = {
    PAE = PlayerAmountEntry,
    LE = LogEntry,
    PLE = PlayerLogEntry,
}
