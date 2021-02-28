--[[
    Sync lists in lua

    This is wow specific and so uses LibStub
]]--

local MAJOR,MINOR = "ListSync-1.0", 1
print("Loading list sync")
local ListSync, _ = LibStub:NewLibrary(MAJOR, MINOR)
_G.ListSync = NewLibrary
if not ListSync then
    print("ListSync already loaded")

return end

local aceComm =  LibStub("AceComm-3.0")
local aceSerializer =  LibStub("AceSerializer-3.0")

function ListSync:new(prefix, sortedList)
    if (prefix == nil or type(prefix) ~= 'string' or string.len(prefix) > 7 or string.len(prefix) < 1) then
        print(prefix)
        error("Prefix must be a non empty string of length <=7")
    end

    if type(sortedList.uniqueInsert) ~= "function" then
        error("Not a valid sorted list")
    end



    o = {}
    setmetatable(o, self)
    self.__index = self

    self._list = sortedList

    self._prefix = "ListSync" .. prefix
    print("Registering listener for list sync, prefix ", self._prefix, self._prefix .. 'B')

    aceComm:RegisterComm(self._prefix, function(_, message, distribution, sender)
        -- single updates
        local result, message = aceSerializer:Deserialize(message)
        if (not result) then
            error("failed to deserialize message")
        end
        if (sortedList:uniqueInsert(message)) then
            print(string.format("Inserting unique event from sender [%s] via [%s] into list", sender, distribution))
        else
            print(string.format("Skipped inserting non-unique event from sender [%s] via [%s] into list", sender, distribution))
        end
    end)
    aceComm:RegisterComm(self._prefix .. 'B', function(_, message, distribution, sender)
        -- batch update
        local result, messages = aceSerializer:Deserialize(message)
        if (not result) then
            error("failed to deserialize message")
        end
        print(string.format("Received %d entries from sender [%s] via [%s]", #messages, sender, distribution))
        for _, v in ipairs(messages) do
            if (sortedList:uniqueInsert(v)) then
                print(string.format("Inserting unique event from sender [%s] via [%s] into list", sender, distribution))
            else
                print(string.format("Skipped inserting non-unique event from sender [%s] via [%s] into list", sender, distribution))
            end
        end

    end)
    return o
end

function ListSync:transmitViaGuild(entry)
    aceComm:SendCommMessage(self._prefix, aceSerializer:Serialize(entry), "GUILD", nil, "BULK")
end

function ListSync:fullSyncViaWhisper(target)
    local data = aceSerializer:Serialize(self._list:entries())
    aceComm:SendCommMessage(self._prefix .. 'B', data, "WHISPER", target, "BULK")
end
