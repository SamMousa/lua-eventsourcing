if (GetTime == nil) then
    require "./Database"
    require "./wow"
    require "./string"
    require "./SortedList"
    require "./LogEntry"
    require "bit"

end
--error('disabled')
if (math.randomseed ~= nil) then
    math.randomseed(GetTime())
end

if (os == nil) then
    os = {
        clock =  GetTimePreciseSec
    }
end

Profile = {}
function Profile:start(name)
    Profile[name] = os.clock()
end

function Profile:stop(name)
    local elapsed = os.clock() - Profile[name]
    print(string.format(name .. ": elapsed time: %.2f\n", elapsed))
end

guids = {}
-- Create 500 guids (think 1 database containing 500 players)
for i = 1, 500 do
    local server = math.random(5) * 1000 + 312
    local player = math.random(2 ^ 31 - 1)
    table.insert(guids, string.format('%04d%08x', server, player))
end

if BigDataSet == nil then
    Profile:start('Creating data')
    local sortedList = LogEntry:sortedList()
    for i = 1, 1000 * 1000 do
        -- First 50 players are managers
        local creator = guids[math.random(1, 50)]
        if i % 2 == 0 then
            creator = 'bob'
        else
            creator = 'anna'
        end
        local entry = PlayerAmountEntry:new(guids[math.random(#guids)], math.random(10), creator)
        local copy = {}
        for k, v in pairs(entry) do
            copy[k] = v
        end
        sortedList:insert(copy)
        if i % 1000 == 0 then
            io.write('.')
            io.flush()
        end
    end
    print('done')

    Profile:stop('Creating data')

    BigDataSet = sortedList
else
    sortedList = BigDataSet
end


--local records = Database.RetrieveByKeys(data, searchResult)
--
--printtable(records);

--local log = LogEntry:new()



--print(string.format("%08x", 51))
--local adler32 = Util.IntegerChecksumCoroutine()
--local week = sortedList:entries()[1]:weekNumber()
--local hashes = {}
--print('Start week', week)
--print('End week', math.floor(sortedList:entries()[#sortedList:entries()]:time() / 604800))
--Profile:start('Hashing')
--for k, v in ipairs(sortedList:entries()) do
--    if (v:weekNumber() > week)  then
--        week = v:weekNumber()
--        adler32 = Util.IntegerChecksumCoroutine()
--    end
--    coroutine.resume(adler32, v.time)
--    _, hashes[week] = coroutine.resume(adler32, v.rand)
--    if (k % 1000 == 0) then
--        io.write('x')
--        io.flush()
--    end
--end
--Profile:stop('Hashing')

local state = {
    playerLogCount = 0,
    balances = {

    },
    dkp_per_creator = {

    }
}

local mutator = function(logEntry, state)
    LogEntry:cast(logEntry)
    if (logEntry.class == nil) then
        Util.DumpTable(logEntry)
        error("No class member on logEntry")
    end
    if (type(logEntry.className) ~= 'function') then
        error("missing function")
    end
    local class = logEntry:class()
    if  class == 'PLE' then
        state.playerLogCount = state.playerLogCount + 1
        return true
    elseif class == 'PAE' then
        local player = logEntry:player()
        local creator = logEntry:creator()
        state.balances[player] = (state.balances[player] or 0) + logEntry:amount()
        state.dkp_per_creator[creator] = (state.dkp_per_creator[creator] or 0) + logEntry:amount()
        return true
    end

    return false
end

Profile:start('playing event log')
for i, v in ipairs(sortedList:entries()) do
    if mutator(v, state) then
        --Util.DumpTable(state)
    end
end
Profile:stop('playing event log')
--Util.DumpTable(state)

-- Verify state
totalbalance = 0
for k, v in pairs(state.balances) do
    totalbalance = totalbalance + v
end

totalcreated = 0
for k, v in pairs(state.dkp_per_creator) do
    totalcreated = totalcreated + v
end
print(totalbalance, totalcreated)
