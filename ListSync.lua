--[[
    Sync lists in lua
]]--

local ListSync, _ = LibStub:NewLibrary("EventSourcing/ListSync", 1)
if not ListSync then
return end

local StateManager = LibStub("EventSourcing/StateManager")
local LogEntry = LibStub("EventSourcing/LogEntry")
local Util = LibStub("EventSourcing/Util")

function ListSync:new(stateManager, sendAddonMessage, registerReceiveHandler, authorizationHandler)
    if getmetatable(stateManager) ~= StateManager then
        error("stateManager must be an instance of StateManager")
    end



    o = {}
    setmetatable(o, self)
    self.__index = self

    self.advertiseTicker = nil
    self.sendAddonMessage = sendAddonMessage
    self.authorizationHandler = authorizationHandler

    self._stateManager = stateManager

    registerReceiveHandler(function(_, message, distribution, sender)
        -- our messages have a type, this way we can use 1 prefix for all communication
        if message.type == "fullSync" then
            -- handle full sync
            local count = 0
            for i, v in ipairs(message.data) do
                local entry = self._stateManager:createLogEntryFromList(v)
                -- Check authorize each events
                if authorizationHandler(entry, sender) then
                    self._stateManager:queueRemoteEvent(entry)
                    count = count + 1
                else
                    print(string.format("Dropping event from sender %s", sender))
                end
            end
            print("Enqueued %d events from remote received from %s via %s", count, sender, distribution)
        elseif message.type == "singleEntry" then
            local entry = self._stateManager:createLogEntryFromList(message.data)
            if authorizationHandler(entry, sender) then
                self._stateManager:queueRemoteEvent(entry)
                count = count + 1
            else
                print(string.format("Dropping event from sender %s", sender))
            end

        end

    end)

    return o
end

--[[
    Sends an entry out over the guild channel, if allowed
]]--
function ListSync:transmitViaGuild(entry)
    if self.authorizationHandler(entry, UnitName("player")) then
        self.sendAddonMessage({
            type = "singleEntry",
            data = entry:toList()
        }, "GUILD", nil, "BULK")
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
        local hashes = {}
        for i = 0, 3 do
            hashes[currentWeek - i] = self:weekHash(currentWeek - i)
        end

        Util.DumpTable(hashes)
    end)
end

function ListSync:disableSending()
    if self.advertiseTicker ~= nill then
        self.advertiseTicker:cancel()
        self.advertiseTicker = nil
    end
end

function ListSync:weekHash(week)
    local sortedList = self._stateManager:getSortedList()

    local position = sortedList:searchGreaterThanOrEqual({t = Util.WeekStart(week) })
    if (position == nil) then
        return 0
    end

    local adler32 = Util.IntegerChecksumCoroutine()
    local stateManager = self._stateManager
    local entries = sortedList:entries()
    local result, hash
    while position <= #entries do
        local entry = entries[position]
        if entry == nil then
            print("Entry is nil", position, #entries)
            error("exit listsync:139")
        end
        stateManager:castLogEntry(entry)
        if entry:weekNumber() == week then
            result, hash = coroutine.resume(adler32, LogEntry.time(entry))
            if not result then
                error(hash)
            end
        else
            break
        end
        position = position + 1
    end
    return hash or 0
end
