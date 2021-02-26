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
    o.metatables = {}

    o.lastAppliedEntry = nil
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
 Recalculate the state from the list
 @return the new state
]]--
function StateManager:recalculateState()
    for i, entry in ipairs(self.list:entries()) do
        self:castLogEntry(entry)
        self.handlers[entry:class()](entry)
        self.lastAppliedEntry = entry
        self.lastAppliedIndex = i
        self.errorCount = 0
    end
end

--[[
  Higher means less noticeable lag
  @param float the interval in milliseconds to use for updating state
]]--
function StateManager:setUpdateInterval(interval)
    if self.ticker then
        self.ticker:cancel()
    end
    if (interval == 0) then
        -- work in synchronous mode
        o.async = false
        self:catchUp()
    end
    self.ticker = C_Timer.NewTicker(interval / 1000, function()
        -- Use a closure here because we don't know what NewTicker does ie if it'll pass a different self
        success, message = pcall(self:updateState())
        if (not success) then
            self.errorCount = self.errorCount + 1
        else
            self.errorCount = 0
        end

        if self.errorCount >= 10 then
            -- not strictly needed since the error() call below will also cancel the ticker
            self.ticker:cancel()
            self.errorCount = 0
            error("State manager auto update stopped, got 10 consecutive errors")
        end
    end)
end

--[[
  This function plays new entries, it is called repeatedly on a timer.
  The goal of each call is to remain under the frame render time
  Current solution: apply just 1 entry
]]--
function StateManager:updateState()
    local entries = self.list:entries()
    if self.lastAppliedIndex < #entries then
        local entry = entries[self.lastAppliedIndex + 1]
        self:castLogEntry(entry)
        -- This will throw an error if update fails, this is good since we don't want to update our tracking in that case.
        self.handlers[entry:class()](event)
        self.lastAppliedEntry = entry
        self.lastAppliedIndex = self.lastAppliedIndex + 1
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
