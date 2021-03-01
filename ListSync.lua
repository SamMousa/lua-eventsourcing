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
local libDeflate = LibStub("LibDeflate")
local libSerialize =  LibStub("LibSerialize")

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
    local data = {}
    for _, v in ipairs(self._list:entries()) do
        table.insert(data, v:toList())
    end
    local smartSerialized = libSerialize:Serialize(data)
    local dumbSerialized = libSerialize:Serialize(self._list:entries())
    local smartCompressed = libDeflate:CompressDeflate(smartSerialized)
    local dumbCompressed = libDeflate:CompressDeflate(dumbSerialized)
    print(string.format("Size for smart serialize: %d, compressed: %d", string.len(smartSerialized), string.len(smartCompressed)))
    print(string.format("Size for dumb serialize: %d, compressed: %d", string.len(dumbSerialized), string.len(dumbCompressed)))

    aceComm:SendCommMessage(self._prefix .. 'B', data, "WHISPER", target, "BULK", function(_, sent, total)
        print(string.format("Sent %d of %d", sent, total))
    end)
end
