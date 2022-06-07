--[[
    Sync lists in lua
]] --

local ListSync, _ = LibStub:NewLibrary("EventSourcing/ListSync", 2)
if not ListSync then
    return
end

local StateManager = LibStub("EventSourcing/StateManager")
local LogEntry = LibStub("EventSourcing/LogEntry")
local Util = LibStub("EventSourcing/Util")
local AdvertiseHashMessage = LibStub("EventSourcing/Message/AdvertiseHash")
local WeekDataMessage = LibStub("EventSourcing/Message/WeekData")
local RequestWeekMessage = LibStub("EventSourcing/Message/RequestWeek")
local RequestStateMessage = LibStub("EventSourcing/Message/RequestState")
local StateMessage = LibStub("EventSourcing/Message/State")
local BulkDataMessage = LibStub("EventSourcing/Message/BulkData")
local SubscribeMessage = LibStub("EventSourcing/Message/Subscribe")
local Message = LibStub("EventSourcing/Message")


local ADVERTISEMENT_TIMEOUT = 30

local STATUS_SYNCED = "synced"
local STATUS_OUT_OF_SYNC = "out_of_sync"
local STATUS_UNKNOWN = "unknown"

local EVENT = {
    SYNC_STATE_CHANGED = 'sync_state_changed',
}

local function send(listSync, message, target)
    listSync.send(message, target)
end

local function trigger(listSync, event, ...)
    for _, callback in ipairs(listSync.listeners[event] or {}) do
        callback(listSync, ...)
    end
end

local function addEventListener(listSync, event, callback)
    if listSync.listeners[event] == nil then
        listSync.listeners[event] = {}
    end
    table.insert(listSync.listeners[event], callback)
end

local function setSyncState(listSync, status)
    if listSync.syncStatus ~= status then
        listSync.syncStatusTime = Util.time()
        listSync.syncStatus = status
        listSync.logger:Info("Sync status changed to: %s", status)
        trigger(listSync, EVENT.SYNC_STATE_CHANGED, status)
    end
end

local function updatePeerStatus(listSync, stateManager, peer, stateHash, lag, count)
    listSync.peerStatus[peer] = {
        stateHash = stateHash,
        lag = lag,
        count = count,
        timestamp = Util.time()
    }
end

local function weekEntryIterator(listSync, week)
    local sortedList = listSync._stateManager:getSortedList()

    local search = LogEntry:new()
    search:setTime(Util.WeekStart(week))
    search:setCounter(-1 * math.huge)

    local position = sortedList:searchGreaterThanOrEqual(search)
    local entries = sortedList:entries()

    return function()
        if position ~= nil and position <= #entries then
            local entry = entries[position]
            position = position + 1
            if LogEntry.weekNumber(entry) == week then
                return entry
            end
        end
    end
end

--[[
  Get the hash and number of events in a week.
  Result is cached using the sortedList state.
]] --
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
        listSync._weekHashCache.entries[week] = { hash or 0, count }
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

local function handleSubscribeMessage(message, sender, stateManager, listSync)
    -- This message should only be received on a whisper channel.
    listSync.subscribers[#listSync.subscribers + 1] = sender
end

local function handleAdvertiseMessage(message, sender, _, stateManager, listSync)
    -- This is the number of entries we expect to have after all data from advertisements in this message have been synced
    local projectedEntries = stateManager:getSortedList():length()
    local now = Util.time()
    local currentWeek = Util.WeekNumber(now)
    -- First we check every week's hash
    for _, whc in ipairs(message.hashes) do
        local week, hash, count = unpack(whc)

        -- If sender has priority over us we remove our advertisement, this will prevent us from sending data.
        if sender < listSync.playerName and listSync.advertisedWeeks[week] ~= nil then
            listSync.logger:Debug("Removing advertisement for week %d because %s has prio", week, sender)
            listSync.advertisedWeeks[week] = nil
        end

        local localHash, localCount = weekHash(listSync, week)
        if localHash == hash and localCount == count then
            advertiseWeekHashInhibitorSet(listSync, week)
            listSync.logger:Debug("Received week %s hash from %s, we are in sync", week, sender)
        else
            -- local hash is out of sync
            -- mark us as out of sync only if we have fewer entries or if this is not the current week
            if week ~= currentWeek or count > localCount then
                setSyncState(listSync, STATUS_OUT_OF_SYNC)
            end
            projectedEntries = projectedEntries + math.max(0, localCount - count)
            if requestWeekInhibitorCheck(listSync, week) then
                listSync.logger:Info("Requesting data for week %s", week)
                requestWeekInhibitorSet(listSync, week)
                send(listSync, RequestWeekMessage.create(week))
            end
        end
    end

    updatePeerStatus(listSync, stateManager, sender, message.stateHash, message.lag, message.totalEntryCount)
    if (message.stateHash == stateManager:stateHash()) then
        setSyncState(listSync, STATUS_SYNCED)
    end
    -- Then we check data set properties to decide if we might be far behind.
    if projectedEntries < message.totalEntryCount then
        -- We have fewer entries than the sender
    end


end

local function handleWeekDataMessage(message, sender, stateManager, listSync, trusted)
    if not trusted then
        listSync.logger:Warning("Dropping week data message from untrusted sender %s", sender)
        return
    end

    if (message.hash == weekHash(listSync, message.week)) then
        listSync.logger:Warning("Dropping week data message from sender %s, we have the same hash", sender)
        return
    end

    local count = 0
    for _, v in ipairs(message.entries) do
        local entry = stateManager:createLogEntryFromList(v)
        stateManager:queueRemoteEvent(entry)
        count = count + 1
    end
    listSync.logger:Info("Enqueued %d events for week %s from remote received from %s via %s", count, message.week, sender)

end

local function handleBulkDataMessage(message, sender, stateManager, listSync, trusted)
    if not trusted then
        listSync.logger:Warning("Dropping bulk data message from untrusted sender %s", sender)
    else
        local count = 0
        for _, v in ipairs(message.entries) do
            local entry = stateManager:createLogEntryFromList(v)
            stateManager:queueRemoteEvent(entry)
            count = count + 1
        end
        listSync.logger:Info("Enqueued %d events from remote received from %s via %s", count, sender)
    end
end

local function handleRequestWeekMessage(message, sender, stateManager, listSync, trusted)
    if not listSync:isSendingEnabled() then
        -- We are not sending, but we do need to make sure to not request the same week
        requestWeekInhibitorSet(listSync, message.week)
    else
        if (listSync.advertisedWeeks[message.week] ~= nil) then
            local delay = 3 + 5 * math.random();
            listSync.logger:Info("Received request for week %d from %s, will attempt send in %.2fs", message.week, sender, delay)
            C_Timer.After(delay, function()
                -- check advertisements after delay, someone might have advertised after us and still gained priority
                if listSync.advertisedWeeks[message.week] ~= nil and listSync.advertisedWeeks[message.week] > Util.time() then
                    -- Remove our advertisement for this week, this prevents multiple requests leading to multiple sends
                    listSync.advertisedWeeks[message.week] = nil
                    listSync:syncWeek(message.week)
                end
            end)
        else
            listSync.logger:Info("Ignoring request for week %d from %s, we did not advertise or lost prio on", message.week, sender)
        end
    end
end

local function handleRequestStateMessage(message, sender, stateManager, listSync, trusted)
    send(listSync, StateMessage.create(stateManager:stateHash(), stateManager:getSortedList():length(), stateManager:lag()))
end

local function handleStateMessage(message, sender, stateManager, listSync, trusted)
    updatePeerStatus(listSync, stateManager, sender, message.stateHash, message.lag, message.totalEntryCount)
end

local function handleMessage(listSync, message, sender, trusted)
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
        handler(message, sender, listSync._stateManager, listSync, trusted)
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

local function transmitEntry(listSync, entry, channel)
    local message = BulkDataMessage.create()
    message:addEntry(listSync._stateManager:createListFromEntry(entry))
    send(listSync, message, channel)
end

function ListSync:new(stateManager, sendMessage, logger)
    Util.assertInstanceOf(stateManager, StateManager)
    Util.assertFunction(sendMessage, "send")
    Util.assertLogger(logger)

    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.listeners = {}
    o.advertiseTicker = nil
    o.advertiseCount = 8
    o.advertiseRollingOffset = 0
    o.send = sendMessage
    o.logger = logger

    o._stateManager = stateManager
    o._weekHashCache = {
        -- numeric counter for checking if the list has changed
        state = stateManager:getSortedList():state(),
        entries = {}
    }
    o.playerName = UnitName("player")
    -- A list of players that want our advertisements
    o.subscribers = {}

    o.messageHandlers = {}
    o.messageHandlers[AdvertiseHashMessage.type()] = { handleAdvertiseMessage }
    o.messageHandlers[WeekDataMessage.type()] = { handleWeekDataMessage }
    o.messageHandlers[BulkDataMessage.type()] = { handleBulkDataMessage }
    o.messageHandlers[RequestWeekMessage.type()] = { handleRequestWeekMessage }
    o.messageHandlers[RequestStateMessage.type()] = { handleRequestStateMessage }
    o.messageHandlers[StateMessage.type()] = { handleStateMessage }
    o.messageHandlers[SubscribeMessage.type()] = { handleSubscribeMessage }
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

    o.peerStatus = {}

    o.syncStatusTime = 0
    C_Timer.NewTicker(10, function()
        if o.syncStatusTime + 90 < Util.time() then
            setSyncState(o, STATUS_UNKNOWN)
        end


    end)
    return o
end

function ListSync:handleMessage(message, sender, trusted)
    handleMessage(self, message, sender, trusted)
end

function ListSync:transmit(entry)
    return transmitEntry(self, entry)
end

function ListSync:getPeerStatus()
    return self.peerStatus
end

function ListSync:addSyncStateChangedListener(callback)
    Util.assertFunction(callback, 'callback')
    addEventListener(self, EVENT.SYNC_STATE_CHANGED, callback);
end

function ListSync:syncWeek(week)
    local message = WeekDataMessage.create(week, weekHash(self, week))
    for entry in weekEntryIterator(self, week) do
        message:addEntry(self._stateManager:createListFromEntry(entry))
    end
    self.send(message)
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
        local weeksWithData = currentWeek - firstWeek + 1
        self.logger:Debug("Announcing hashes of last %d weeks + %d rolling weeks starting at %d, first week with data is: %d", self.advertiseCount, self.advertiseCount, currentWeek - self.advertiseRollingOffset, firstWeek)
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
        local rollingWeekOffsetLimit = weeksWithData - self.advertiseCount - 1
        self.logger:Debug("Weeks with data: %d, rollingWeekOffsetLimit: %d", weeksWithData, rollingWeekOffsetLimit)
        if weeksWithData > self.advertiseCount then
            -- most recent
            local firstHistoricalWeek = currentWeek - self.advertiseCount - self.advertiseRollingOffset
            -- least recent
            local lastHistoricalWeek = firstHistoricalWeek - self.advertiseCount + 1
            for checkWeek = firstHistoricalWeek, lastHistoricalWeek, -1 do
                self.logger:Debug("Checking historical week %d", checkWeek)
                if (checkWeek >= firstWeek and advertiseWeekHashInhibitorCheckOrSet(self, checkWeek)) then
                    local hash, count = weekHash(self, checkWeek)
                    message:addHash(checkWeek, hash, count)
                    self.advertisedWeeks[checkWeek] = now + ADVERTISEMENT_TIMEOUT
                end
                self.advertiseRollingOffset = self.advertiseRollingOffset + 1
            end

            -- Reset the rolling weeks, we've reached the start of our data
            if self.advertiseRollingOffset > rollingWeekOffsetLimit then
                self.advertiseRollingOffset = 0
            end
        end

        if (message:hashCount() > 0) then
            self.logger:Debug("Sending hashes for %d weeks", message:hashCount())
            send(self, message)
        else
            self.logger:Debug("Skipping send since all weeks are inhibited")
        end
    end)
end

function ListSync:requestPeerStatus()
    send(self, RequestStateMessage.create())
end

function ListSync:disableSending()
    if self.advertiseTicker ~= nil then
        self.advertiseTicker:Cancel()
        self.advertiseTicker = nil
    end
end
