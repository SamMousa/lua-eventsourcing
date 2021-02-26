--[[
    This event models an amount of points given to a set of players on a specific ledger
]]--

PercentageDecayEntry = LogEntry:extend('PDE')

--        function(state, entry)
--    local creator = entry:creator()
--    for player, balance in pairs(state.balances) do
--        if (balance > 0) then
--            state.balances[player] = entry:applyDecay(balance)
--            state.totalDecay = (state.totalDecay or 0) + (balance - state.balances[player])
--        end
--    end
--
--end)

function PercentageDecayEntry:new(percentage, creator, team)
    local o = LogEntry.new(self);
    o.cr = creator
    o.team = team
    o.a = percentage
    return o
end

function PercentageDecayEntry:creator()
    return self.cr
end
function PercentageDecayEntry:applyDecay(balance)
    -- We multiply by 100 and divide by 100 outside the floor to implement rounding
    return math.floor(balance * 100 * 100 / (100 + self.a)) / 100
end

function PercentageDecayEntry:amount()
    return self.a
end
