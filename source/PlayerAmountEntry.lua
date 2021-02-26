--[[
    This event models an amount of points given to a set of players on a specific ledger
]]--

PlayerAmountEntry = LogEntry:register('PAE', function(state, entry)
    local creator = entry:creator()
    state.dkp_per_creator = state.dkp_per_creator or {}
    state.balances = state.balances or {}

    for _, player in ipairs(entry:players()) do
        state.balances[player] = (state.balances[player] or 0) + entry:amount()
        state.dkp_per_creator[creator] = (state.dkp_per_creator[creator] or 0) + entry:amount()
    end
end)

function PlayerAmountEntry:new(players, amount, creator, ledger)
    local o = self.super(self, ledger or 'def', creator);
    o.p = players
    o.a = amount
    return o
end


function PlayerAmountEntry:players()
    return self.p
end

function PlayerAmountEntry:amount()
    return self.a
end
