if (GetTime == nil) then
    require "./Database"
    require "./wow"
    require "./string"
    require "./SortedList"
    require "./LogEntry"
    require "./source/PlayerAmountEntry"
    require "./source/PercentageDecayEntry"
    require "./StateManager"
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

function launchTest()
guids = {}
-- Create 500 guids (think 1 database containing 500 players)
for i = 1, 500 do
    local server = math.random(5) * 1000 + 312
    local player = math.random(2 ^ 31 - 1)
    table.insert(guids, string.format('%04d%08x', server, player))
end

if BigDataSet == nil then
    Profile:start('Creating data')
    sortedList = LogEntry:sortedList()
    for i = 1, 10 * 1000 do
        -- First 50 players are managers
        local creator = guids[math.random(1, 50)]
        if i % 2 == 0 then
            creator = 'bob'
        else
            creator = 'anna'
        end
        local players = {}
        for i = 1, math.random(10) do
            players[#players + 1] = guids[math.random(#guids)]
        end

        local entry = PlayerAmountEntry:new(players, math.random(10), creator)
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

    local stateManager = StateManager:new(sortedList)
    local state = {}
    stateManager:registerHandler(PlayerAmountEntry, function(entry)
        local creator = entry:creator()
        state.dkp_per_creator = state.dkp_per_creator or {}
        state.balances = state.balances or {}

        for _, player in ipairs(entry:players()) do
            state.balances[player] = (state.balances[player] or 0) + entry:amount()
            state.dkp_per_creator[creator] = (state.dkp_per_creator[creator] or 0) + entry:amount()
        end
    end)
    stateManager:recalculateState()


Util.DumpTable(state)

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

    --Util.DumpTable(state)

    local decay = PercentageDecayEntry:new(5, 'sam')
    sortedList:insert(decay)

    print(stateManager:lag())
    --state = recalculateState(sortedList)
    print(state.totalDecay)
end

if (GetServerTime == nil) then
    launchTest()
end
