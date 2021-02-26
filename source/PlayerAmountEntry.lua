--[[
    This event models an amount of points given to a set of players on a specific ledger
]]--

PlayerAmountEntry = LogEntry:extend('PAE')

function PlayerAmountEntry:new(players, amount, creator, ledger)
    local o = LogEntry.new(self)
    o.cr = creator
    o.p = players
    o.a = amount
    return o
end

function PlayerAmountEntry:creator()
    return self.cr
end

function PlayerAmountEntry:players()
    return self.p
end

function PlayerAmountEntry:amount()
    return self.a
end
