--[[
    Sync lists in lua
]]--

local ListSync, _ = LibStub:NewLibrary("EventSourcing/ListSync", 1)
if not ListSync then
return end

local MESSAGE = {
    WEEKHASH = 'weekhash',
    REQUESTWEEK = "requestweek"
}
local StateManager = LibStub("EventSourcing/StateManager")
local LogEntry = LibStub("EventSourcing/LogEntry")
local Util = LibStub("EventSourcing/Util")
local AdvertiseHashMessage = LibStub("EventSourcing/Message/AdvertiseHash")
local WeekDataMessage = LibStub("EventSourcing/Message/WeekData")
local Message = LibStub("EventSourcing/Message")


local function handleAdvertiseMessage(message)
    for _, weekHashCount in message.hashes do

        local hash, count = self:weekHash(value[1])
        if  hash == weekHashCount[2] and count == weekHashCount[3] then
            print(string.format("Received week hash from %s, we are in sync", sender))
        else
            print(string.format("Received week hash from %s, we are NOT in sync", sender))
            -- TODO: requestweek

        end
    end
end

local function handleWeekDataMessage(message, sender, distribution, stateManager, listSync)
    local count = 0
    for _, v in ipairs(message.entries) do
        local entry = stateManager:createLogEntryFromList(v)
        -- Authorize each event
        if listSync.authorizationHandler(entry, sender) then
            stateManager:queueRemoteEvent(entry)
            count = count + 1
        else
            print(string.format("Dropping event from sender %s", sender))
        end
    end
    print(string.format("Enqueued %d events from remote received from %s via %s", count, sender, distribution))
end

local function handleRequestWeekMessage(message, sender, distribution, stateManager, listSync)
-- todo
--
--    elseif self:isSendingEnabled() and message.type == MESSAGE.REQUESTWEEK then
--    -- If we don't have the same week hash we ignore the request
--    local hash, count = self:weekHash(message.week)
--    if  hash ~= message.hash or count ~= message.count then
--    print(string.format("Ignoring week request for week %d with hash %d from %s, we are not in sync",
--    message.week, message.hash))
--    return
--    end
--
--    if distribution == "WHISPER" then
--    self:weekSyncViaWhisper(sender, message.week)
--    elseif distribution == "GUILD" then
--    -- We need to prevent hammering the guild comms with updates.
--    -- Every agent has an upper limit on sending a week twice (ie send at most once every minute)
--    --
--    -- temp fix: always respond via whisper.
--    self:weekSyncViaWhisper(sender, message.week)
--    end
end

local function handleSingleEntryMessage(message, sender, distribution, stateManager, listSync)
    -- todo
--   elseif message.type == "singleEntry" then
    --        local entry = self._stateManager:createLogEntryFromList(message.data)
    --        if self.authorizationHandler(entry, sender) then
    --            self._stateManager:queueRemoteEvent(entry)
    --        else
    --            print(string.format("Dropping event from sender %s", sender))
    --        end
end


function ListSync:new(stateManager, sendAddonMessage, registerReceiveHandler, authorizationHandler)
    if getmetatable(stateManager) ~= StateManager then
        error("stateManager must be an instance of StateManager")
    end



    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.advertiseTicker = nil
    o.sendAddonMessage = sendAddonMessage
    o.authorizationHandler = authorizationHandler

    o._stateManager = stateManager
    o._weekHashCache = {
        -- numeric counter for checking if the list has changed
        state = stateManager:getSortedList():state(),
        entries = {}
    }
    o.playerName = UnitName("player")
    registerReceiveHandler(function(message, distribution, sender)
        o:handleMessage(message, distribution, sender)
    end)

    o.messageHandlers = {}
    o.messageHandlers[AdvertiseHashMessage.type()] = { handleAdvertiseMessage }
    o.messageHandlers[WeekDataMessage.type()] = { handleWeekDataMessage }

    return o
end


function ListSync:handleMessage(message, distribution, sender)
    if not Message.cast(message) then
        print(string.format("Ignoring invalid message from %s", sender))
        return
    end

    if sender == self.playerName then
        print("Ignoring message from self")
        return
    end

    -- We use pairs() because we don't care about order.
    -- This allows us to insert handlers with a key (and to easily remove them later)
    for _, handler in pairs(self.messageHandlers[message.type] or {}) do
        handler(message, sender, distribution, self._stateManager, self)
    end
end
--[[
    Sends an entry out over the guild channel, if allowed
]]--
function ListSync:transmitViaGuild(entry)
    if self.authorizationHandler(entry, UnitName("player")) then
        self:send({
            type = "singleEntry",
            data = entry:toList()
        }, "GUILD")
    end
end


--[[
    Full sync via whisper, we don't use the authorizationCallback here.
    In case it is initiated by the sender the receiver will discard messages.
    In case it is initiated by the receiver they might temporarily trust the sender and we should just send all data.
    This could also be used for deep data validation in the future.
]]--
function ListSync:fullSyncViaWhisper(target)
    local data = {}
    for _, v in ipairs(self._stateManager:getSortedList():entries()) do
        self._stateManager:castLogEntry(v)
        local list = v:toList()
        table.insert(list, v:class())
        table.insert(data, list)
    end
    local message = {
        type = "fullSync",
        data = data
    }
    self:send(message, "WHISPER", target)

end


function ListSync:send(message, distribution, target)
    self.sendAddonMessage(message, distribution, target, "BULK", function(_, sent, total)
        print(string.format("Sent %d of %d", sent, total))
    end)
end

function ListSync:weekSyncViaWhisper(target, week)
    local data = {}
    local message = WeekDataMessage.create(week, self:weekHash(week))
    for entry in self:weekEntryIterator(week) do
        message:addEntry(self._stateManager:createListFromEntry(entry))
    end
    self:send(message, "WHISPER", target)
end

function ListSync:fullSyncViaWhisper(target)
    local data = {}
    for _, v in ipairs(self._stateManager:getSortedList():entries()) do
        table.insert(data, self._stateManager:createListFromEntry(v))
    end
    local message = {
        type = "bulkSync",
        data = data
    }
    self.sendAddonMessage(message, "WHISPER", target, "BULK", function(_, sent, total)
        print(string.format("Sent %d of %d", sent, total))
    end)
end

function ListSync:isSendingEnabled()
    return self.advertiseTicker ~= nil
end

function ListSync:enableSending()
    -- Start advertisements of our latest hashes.
    self.advertiseTicker = C_Timer.NewTicker(10, function()
        -- Get week hash for the last 4 weeks.
        local currentWeek = Util.WeekNumber(Util.time())
        print("Announcing hashes of last 4 weeks")
        local message = AdvertiseHashMessage.create()
        for i = 0, 3 do
            local hash, count = self:weekHash(currentWeek - i)
            message:addHash(currentWeek - 1, hash, count)
            self:send(message, "GUILD")
        end
    end)
end

function ListSync:disableSending()
    if self.advertiseTicker ~= nil then
        self.advertiseTicker:Cancel()
        self.advertiseTicker = nil
    end
end

function ListSync:weekEntryIterator(week)
    local sortedList = self._stateManager:getSortedList()

    local position = sortedList:searchGreaterThanOrEqual({t = Util.WeekStart(week) })
    local stateManager = self._stateManager
    local entries = sortedList:entries()

    return function()
        -- luacheck: push ignore
        while position ~= nil and position <= #entries do
            -- luacheck: pop ignore
            local entry = entries[position]
            stateManager:castLogEntry(entry)
            position = position + 1
            if entry:weekNumber() == week then
                return entry
            else
                return nil
            end
        end
    end
end

--[[
  Get the hash and number of events in a week.
  Result is cached using the sortedList state.
]]--
function ListSync:weekHash(week)
    local adler32 = Util.IntegerChecksumCoroutine()

    local result, hash
    local count = 0

    local state = self._stateManager:getSortedList():state()
    if (self._weekHashCache.state ~= state) then
        self._weekHashCache = {
            state = state,
            entries = {}
        }
    end
    if self._weekHashCache.entries[week] == nil then
        for entry in self:weekEntryIterator(week) do
            result, hash = coroutine.resume(adler32, LogEntry.time(entry))
            count = count + 1
            if not result then
                error(hash)
            end
        end
        self._weekHashCache.entries[week] = {hash or 0, count }
    end
    return self._weekHashCache.entries[week][1], self._weekHashCache.entries[week][2]
end
