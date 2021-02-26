--[[
    This event models an event as used by ClassicLootManager Interconnect
    CLM manages state outside this loop, so we just pass on the entry
]]--


ClassicLootManagerEntry = LogEntry:register('CLM', function(state, entry)
    if type(CLM.Interconnect.Ledger.onUpdate) == nill then
        error("Couldn't call interconnect, CLM not loaded?")
    end
    -- Call CLM interconnect.
    CLM.Interconnect.Ledger.onUpdate(entry)

end)

function ClassicLootManagerEntry:new(team, data, timestamp)
    local o = self.super(self, team or 'def');
    o.d = data
    if timestamp ~= nil then
        o.t = timestamp
    end

    return o
end
