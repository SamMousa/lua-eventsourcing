--[[

State manager manages (re)playing the event log to calculate state

To work it requires a reference to a SortedList

]]--

if StateManager == nil then
    StateManager = {}
end

function StateManager:new(list)
    o = {}
    setmetatable(o, self)
    self.__index = self

    o.list  = list
    o.handlers = {}
    o.async = true
    o.batchSize = 1
    o.metatables = {}
    o.errorCount = 0
    o.listeners = {}
    o.lastTick = 0
    o.measuredInterval = 0

    o.lastAppliedIndex = 0
    return o
end

function StateManager:castLogEntry(table)
    -- Find which meta table we should use
    if self.metatables[table.cls] == nil then
        error("Unknown class: " .. table.cls)
    end
    setmetatable(table, self.metatables[table.cls])
end


function StateManager:registerHandler(event, handler)
    if event._cls == nil then
        error("Event does not seem to have been created using LogEntry:extend()")
    end
    o.handlers[event._cls] = handler
    o.metatables[event._cls] = event
end

--[[
 Recalculate the state from the list, will start from the latest snapshot
 Initial implementation does a linear search in reverse order to find a snapshot
 @return the new state
]]--
function StateManager:recalculateState()
    local start
    -- find last log entry
    for i = #self.list:entries(), 1, -1 do
        local entry = self.list:entries()[i]
        self:castLogEntry(entry)
        if entry:snapshot() then
            start = i
            break
        end
    end

    for i = start or 1, #self.list:entries() do
        local entry = self.list:entries()[i]
        self.handlers[entry:class()](entry)
        self.lastAppliedIndex = i
        self.errorCount = 0
    end
end

function StateManager:setBatchSize(size)
    if type(size) ~= 'number' then
        error("Batch size must be a number")
    end
    self.batchSize = math.floor(size)
end

function StateManager:getBatchSize()
    return self.batchSize
end

--[[
  Higher means less noticeable lag
  @param float the interval in milliseconds to use for updating state
]]--
function StateManager:setUpdateInterval(interval)
    if self.ticker then
        self.ticker:Cancel()
    end
    if (interval == 0) then
        -- work in synchronous mode
        self.async = false
        self:catchUp()
    end
    self.ticker = C_Timer.NewTicker(interval / 1000, function()
        local t = GetTimePreciseSec()
        self.measuredInterval = t - self.lastTick
        self.lastTick = t

        -- Use a closure here because we don't know what NewTicker does ie if it'll pass a different self
        success, message = pcall(self.updateState, self)
        if (not success) then
            print(message)
            self.errorCount = self.errorCount + 1
        else
            self.errorCount = 0
        end

        if self.errorCount >= 10 then
            -- not strictly needed since the error() call below will also cancel the ticker
            self.ticker:Cancel()
            error("State manager auto update stopped, got 10 consecutive errors")
        end
    end)
end

function StateManager:getUpdateInterval()
    return math.floor(self.measuredInterval * 1000)
end

--[[
  This function plays new entries, it is called repeatedly on a timer.
  The goal of each call is to remain under the frame render time
  Current solution: apply just 1 entry
]]--
function StateManager:updateState()
    local entries = self.list:entries()
    local applied = 0
    while applied < self.batchSize and self.lastAppliedIndex < #entries do
        local entry = entries[self.lastAppliedIndex + 1]
        self:castLogEntry(entry)
        -- This will throw an error if update fails, this is good since we don't want to update our tracking in that case.
        self.handlers[entry:class()](entry)
        self.lastAppliedIndex = self.lastAppliedIndex + 1
        applied = applied + 1
    end
    if applied > 0 then
        self:trigger('STATE')
    end
end

function StateManager:catchUp()

end
--[[
  @return int the number of entries the state is lagging behind the log
]]--
function StateManager:lag()
    return #self.list:entries() - self.lastAppliedIndex
end

function StateManager:trigger(event)
    for _, callback in ipairs(self.listeners[event] or {}) do
        -- trigger callback, pass statemanager
        callback(self)
    end
end

function StateManager:addStateChangedListener(callback)
    if self.listeners['STATE'] == nil then
        self.listeners['STATE'] = {}
    end
    table.insert(self.listeners['STATE'], callback)
end
