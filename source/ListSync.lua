--[[
    Sync lists in lua
]]--

local ListSync, _ = LibStub:NewLibrary("EventSourcing/ListSync", 1)
if not ListSync then
return end

local StateManager = LibStub("EventSourcing/StateManager")
local LogEntry = LibStub("EventSourcing/LogEntry")
local Util = LibStub("EventSourcing/Util")
local AdvertiseHashMessage = LibStub("EventSourcing/Message/AdvertiseHash")
local WeekDataMessage = LibStub("EventSourcing/Message/WeekData")
local RequestWeekMessage = LibStub("EventSourcing/Message/RequestWeek")
local BulkDataMessage = LibStub("EventSourcing/Message/BulkData")
local Message = LibStub("EventSourcing/Message")


local ADVERTISEMENT_TIMEOUT = 30



--[[
  Internally we use the secure channel for large messages to prevent DoS,
  unsecure channel will only send small messages.
]]--
local function send(listSync, message, distribution, target)
    listSync.send(message, distribution, target)
end


local function weekEntryIterator(listSync, week)
    local sortedList = listSync._stateManager:getSortedList()

    local search = LogEntry:new()
    search:setTime(Util.WeekStart(week))
    search:setCounter(-1 * math.huge)

    local position = sortedList:searchGreaterThanOrEqual(search)
    local stateManager = listSync._stateManager
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
local function weekHash(listSync, week)
    local adler32 = Util.IntegerChecksumCoroutine()

    local result, hash
    local count = 0

    local state = listSync._stateManager:getSortedList():state()
    if (listSync._weekHashCache.state ~= state) then
        listSync._weekHashCache = {
            state = state,
            entries = {}
        }
    end
    if listSync._weekHashCache.entries[week] == nil then
        for entry in weekEntryIterator(listSync, week) do
            for _, v in ipairs(LogEntry.numbersForHash(entry)) do
                result, hash = coroutine.resume(adler32, v)
                if not result then
                    error(hash)
                end
            end
            count = count + 1

        end
        listSync._weekHashCache.entries[week] = {hash or 0, count }
    end
    return listSync._weekHashCache.entries[week][1], listSync._weekHashCache.entries[week][2]
end

local function advertiseWeekHashInhibitorSet(listSync, week)
    local messageType = AdvertiseHashMessage.type()
    local now = Util.time()
    listSync.inhibitors[messageType][week] = now + listSync.inhibitorTimes[messageType]
end

local function requestWeekInhibitorSet(listSync, week)
    local messageType = RequestWeekMessage.type()
    local now = Util.time()
    listSync.inhibitors[messageType][week] = now + listSync.inhibitorTimes[messageType]
end

local function requestWeekInhibitorCheck(listSync, week)
    local messageType = RequestWeekMessage.type()
    return listSync.inhibitors[messageType][week] == nil
            or listSync.inhibitors[messageType][week] < Util.time()
end

local function handleAdvertiseMessage(message, sender, distribution, stateManager, listSync)
    -- This is the number of entries we expect to have after all data from advertisements in this message have been synced
    local projectedEntries = stateManager:getSortedList():length()
    -- First we check every week's hash
    for _, whc in ipairs(message.hashes) do
        local week, hash, count = unpack(whc)
        Util.assertNumber(week, 'week')
        Util.assertNumber(hash, 'hash')
        Util.assertNumber(count, 'count')

        -- If sender has priority over us we remove our advertisement, this will prevent us from sending data.
        if sender < listSync.playerName then
            listSync.logger:Info("Removing advertisement for week %d because %s has prio", week, sender)
            listSync.advertisedWeeks[week] = nil
        end

        local localHash, localCount = weekHash(listSync, week)
        advertiseWeekHashInhibitorSet(listSync, week)
        if  localHash == hash and localCount == count then
            listSync.logger:Info("Received week %s hash from %s, we are in sync", week, sender)
        else
            projectedEntries = projectedEntries + count
            if requestWeekInhibitorCheck(listSync, week) then
                listSync.logger:Info("Requesting data for week %s", week)
                requestWeekInhibitorSet(listSync, week)
                send(listSync, RequestWeekMessage.create(week), "GUILD")
            end
        end
    end
    -- Then we check data set properties to decide if we might be far behind.
    if projectedEntries < message.totalEntryCount then
        -- We have fewer entries than the sender
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
            listSync.logger:Warning("Dropping event from unauthorized sender %s", sender)
        end
    end
    listSync.logger:Info("Enqueued %d events for week %s from remote received from %s via %s", count, message.week, sender, distribution)
end

local function handleBulkDataMessage(message, sender, distribution, stateManager, listSync)
    local count = 0
    for _, v in ipairs(message.entries) do
        local entry = stateManager:createLogEntryFromList(v)
        -- Authorize each event
        if listSync.authorizationHandler(entry, sender) then
            stateManager:queueRemoteEvent(entry)
            count = count + 1
        else
            listSync.logger:Warning("Dropping event from unauthorized sender %s", sender)
        end
    end
    listSync.logger:Info("Enqueued %d events from remote received from %s via %s", count, sender, distribution)
end

local function handleRequestWeekMessage(message, sender, distribution, stateManager, listSync)
    if distribution == "GUILD" and not listSync:isSendingEnabled() then
        -- We are not sending, but we do need to make sure to not request the same week
        requestWeekInhibitorSet(listSync, message.week)
    elseif distribution == "GUILD" and listSync:isSendingEnabled() then
        listSync.logger:Info("Received request for week %d from %s, will attempt send in 5s", message.week, sender)
        C_Timer.After(5, function()
            -- check advertisements after delay, someone might have advertised after us and still gained priority
            if listSync.advertisedWeeks[message.week] ~= nil and listSync.advertisedWeeks[message.week] > Util.time() then
                listSync:weekSyncViaGuild(message.week)
            end
        end)

    elseif distribution == "WHISPER" then
        listSync:weekSyncViaWhisper(sender, message.week)
    end

end


local function handleMessage(listSync, message, distribution, sender)
    if sender == listSync.playerName then
        return
    end

    if not Message.cast(message) then
        listSync.logger:Warning("Ignoring invalid message from %s", sender)
        return
    end

    -- We use pairs() because we don't care about order.
    -- This allows us to insert handlers with a key (and to easily remove them later)
    for _, handler in pairs(listSync.messageHandlers[message.type] or {}) do
        handler(message, sender, distribution, listSync._stateManager, listSync)
    end
end

-- Checks if this week hash advertisement is inhibited, if not adds an inhibition.
-- returns true if we are allowed to advertise
local function advertiseWeekHashInhibitorCheckOrSet(listSync, week)
    local messageType = AdvertiseHashMessage.type()
    local now = Util.time()
    if listSync.inhibitors[messageType][week] == nil
        or listSync.inhibitors[messageType][week] < now then
        advertiseWeekHashInhibitorSet(listSync, week)
        return true
    end
    return false
end

function ListSync:new(stateManager, sendMessage, registerReceiveHandler, authorizationHandler, sendLargeMessage, logger)
    Util.assertInstanceOf(stateManager, StateManager)
    Util.assertFunction(sendMessage, "send")
    Util.assertFunction(registerReceiveHandler, "registerReceiveHandler")
    Util.assertFunction(authorizationHandler, "authorizationHandler")
    Util.assertFunction(sendLargeMessage, "sendLargeMessage", true)
    Util.assertLogger(logger)



    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.advertiseTicker = nil
    o.advertiseCount = 4
    o.advertiseRollingOffset = 0
    o.send = sendMessage
    o.sendLargeMessage = sendLargeMessage or sendMessage
    o.authorizationHandler = authorizationHandler
    o.logger = logger

    o._stateManager = stateManager
    o._weekHashCache = {
        -- numeric counter for checking if the list has changed
        state = stateManager:getSortedList():state(),
        entries = {}
    }
    o.playerName = UnitName("player")
    registerReceiveHandler(function(message, distribution, sender)
        handleMessage(o, message, distribution, sender)
    end)

    o.messageHandlers = {}
    o.messageHandlers[AdvertiseHashMessage.type()] = { handleAdvertiseMessage }
    o.messageHandlers[WeekDataMessage.type()] = { handleWeekDataMessage }
    o.messageHandlers[BulkDataMessage.type()] = { handleBulkDataMessage }
    o.messageHandlers[RequestWeekMessage.type()] = { handleRequestWeekMessage }
    o.inhibitors = {}
    -- Inhibitor for sending hash advertisements, format is week => timestamp inhibition ends
    o.inhibitors[AdvertiseHashMessage.type()] = {}
    -- Inhibitor for sending week requests, format is week => timestamp inhibition ends
    o.inhibitors[RequestWeekMessage.type()] = {}

    -- Inhibitor for sending week data, format is week .. hash => timestamp inhibition ends
    o.inhibitors[WeekDataMessage.type()] = {}

    o.inhibitorTimes = {}
    -- Send a week hash at most once every 30 seconds
    o.inhibitorTimes[AdvertiseHashMessage.type()] = 30
    -- Request week data at most once every 30 seconds
    o.inhibitorTimes[RequestWeekMessage.type()] = 30
    -- Send week data at most once every 30 seconds
    o.inhibitorTimes[WeekDataMessage.type()] = 30

    -- Format week => timestamp, advertisements are valid for a limited time only
    o.advertisedWeeks = {}
    return o
end

--[[
    Sends an entry out over the guild channel, if allowed
    @param LogEntry authEntry, the entry to use for auth checking, defaults to the entry that is to be transmitted
    @return bool whether we were authorized to send the message

]]--
function ListSync:transmitViaGuild(entry, authEntry)
    if self.authorizationHandler(authEntry or entry, UnitName("player")) then
        local message = BulkDataMessage.create()
        message:addEntry(self._stateManager:createListFromEntry(entry))
        send(self, message, "GUILD")
        return true
    end
    return false
end




function ListSync:weekSyncViaWhisper(target, week)
    local message = WeekDataMessage.create(week, weekHash(self, week))
    for entry in weekEntryIterator(self, week) do
        message:addEntry(self._stateManager:createListFromEntry(entry))
    end
    send(self, message, "WHISPER", target)
end

function ListSync:weekSyncViaGuild(week)
    local message = WeekDataMessage.create(week, weekHash(self, week))
    for entry in weekEntryIterator(self, week) do
        message:addEntry(self._stateManager:createListFromEntry(entry))
    end
    self.sendLargeMessage(message, "GUILD")
end

function ListSync:fullSyncViaWhisper(target)
    local message = BulkDataMessage.create()
    for _, v in ipairs(self._stateManager:getSortedList():entries()) do
        message:addEntry(self._stateManager:createListFromEntry(v))
    end

    send(self, message, "WHISPER", target);
end

function ListSync:isSendingEnabled()
    return self.advertiseTicker ~= nil
end

function ListSync:enableSending()
    -- Start advertisements of our latest hashes.
    if self.advertiseTicker ~= nil then
        return
    end
    self.advertiseTicker = C_Timer.NewTicker(10, function()

        -- Get week hash for the last  weeks.
        local list = self._stateManager:getSortedList()
        if list:length() == 0 then
            return
        end
        local now = Util.time()
        local firstWeek = LogEntry.weekNumber(list:head())
        local currentWeek = Util.WeekNumber(now)
        self.logger:Info("Announcing hashes of last %d weeks + %d rolling weeks starting at %d", self.advertiseCount, self.advertiseCount, self.advertiseRollingOffset)
        local message = AdvertiseHashMessage.create(
            firstWeek,
            self._stateManager:getSortedList():length(),
            self._stateManager:stateHash(),
            self._stateManager:lag()
        )
        -- recent weeks
        for i = 0, self.advertiseCount - 1 do
            if (advertiseWeekHashInhibitorCheckOrSet(self, currentWeek - i)) then
                local hash, count = weekHash(self, currentWeek - i)
                message:addHash(currentWeek - i, hash, count)
                self.advertisedWeeks[currentWeek - i] = now + ADVERTISEMENT_TIMEOUT
            end
        end

        -- historical rolling weeks
        self.advertiseRollingOffset = self.advertiseRollingOffset + self.advertiseCount
        if self.advertiseRollingOffset > currentWeek then
            self.advertiseRollingOffset = 0
        end

        for i = 0, self.advertiseCount - 1 do
            local checkWeek = currentWeek - self.advertiseRollingOffset - i
            if (advertiseWeekHashInhibitorCheckOrSet(self,  checkWeek)) then
                local hash, count = weekHash(self, checkWeek)
                message:addHash(checkWeek, hash, count)
                self.advertisedWeeks[checkWeek] = now + ADVERTISEMENT_TIMEOUT
            end
        end

        if (message:hashCount() > 0) then
            self.logger:Trace("Sending hashes for %d weeks", message:hashCount())
            send(self, message, "GUILD")
        else
            self.logger:Info("Skipping send since all weeks are inhibited")
        end
    end)
end

function ListSync:disableSending()
    if self.advertiseTicker ~= nil then
        self.advertiseTicker:Cancel()
        self.advertiseTicker = nil
    end
end
