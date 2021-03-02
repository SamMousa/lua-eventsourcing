--[[
    Sync lists in lua
]]--

local ListSync, _ = LibStub:NewLibrary("EventSourcing/ListSync", 1)
if not ListSync then
return end

StateManager = LibStub("EventSourcing/StateManager")
function ListSync:new(stateManager, sendAddonMessage, registerReceiveHandler)
    if getmetatable(stateManager) ~= StateManager then
        error("stateManager must be an instance of StateManager")
    end



    o = {}
    setmetatable(o, self)
    self.__index = self
    self.sendAddonMessage = sendAddonMessage

    self._stateManager = stateManager

    registerReceiveHandler(function(_, message, distribution, sender)
        -- our messages have a type, this way we can use 1 prefix for all communication
        if message.type == "fullSync" then
            -- handle full sync

            for i, v in ipairs(message.data) do
                self._stateManager:queueRemoteEvent(v)
            end
            print("Enqueued %d events from remote received from %s via %s", #message.data, sender, distribution)
        elseif message.type == "singleEntry" then
            self._stateManager:queueRemoteEvent(message.data)
        end

    end)

    return o
end

function ListSync:transmitViaGuild(entry)
    self.sendAddonMessage({
        type = "singleEntry",
        data = entry:toList()
    }, "GUILD", nil, "BULK")
end

function ListSync:fullSyncViaWhisper(target)
    local data = {}
    for _, v in ipairs(self._stateManager:getAllEntries()) do
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
