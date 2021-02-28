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

    StartEntry = LogEntry:extend('START', true)
    function StartEntry:new()
        local o = LogEntry.new(self)
        o.t = 1
        return o
    end

    if BigDataSet == nil then
        Profile:start('Creating data')
        sortedList = LogEntry.sortedList()
        local start = StartEntry:new()
        sortedList:insert(start)
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
                print('.')
            end
        end
        print('done')

        Profile:stop('Creating data')

        BigDataSet = sortedList
    else
        print('reconstructing list from saved variables', #BigDataSet._entries)
        sortedList = LogEntry.sortedList(BigDataSet._entries)
    end


    --local records = Database.RetrieveByKeys(data, searchResult)
    --
    --printtable(records);

    --local log = LogEntry:new()

    stateManager = StateManager:new(sortedList)
    local state = {
        balances = {}
    }
    stateManager:addStateChangedListener(function(stateManager)
        local mydkp = state.balances[UnitGUID("player")] or 0;
        updateTestFrameStatus(
            string.format("Lag: %d", stateManager:lag()),
            string.format("Dkp: %d",  mydkp),
            string.format("Batchsize: %d", stateManager:getBatchSize()),
            string.format("Interval (measured): %d", stateManager:getUpdateInterval()),
            ""
        )
    end)
    stateManager:registerHandler(StartEntry, function(entry)
        state = {
            balances = {}
        }
    end)
    stateManager:registerHandler(PlayerAmountEntry, function(entry)
        local creator = entry:creator()
        state.dkp_per_creator = state.dkp_per_creator or {}
        state.balances = state.balances or {}

        for _, player in ipairs(entry:players()) do
            state.balances[player] = (state.balances[player] or 0) + entry:amount()
            state.dkp_per_creator[creator] = (state.dkp_per_creator[creator] or 0) + entry:amount()
        end
    end)

    stateManager:registerHandler(PercentageDecayEntry, function(entry)
        local creator = entry:creator()
        for player, balance in pairs(state.balances) do
            if (balance > 0) then
                state.balances[player] = entry:applyDecay(balance)
                state.totalDecay = (state.totalDecay or 0) + (balance - state.balances[player])
            end
        end
    end)


    --print(string.format("%08x", 51))
    local adler32 = Util.IntegerChecksumCoroutine()
    stateManager:castLogEntry(sortedList:entries()[1])
    local week = sortedList:entries()[1]:weekNumber()
    local hashes = {}
    print('Start week', week)
    Profile:start('Hashing')
    for k, v in ipairs(sortedList:entries()) do
        stateManager:castLogEntry(v)
        if (v:weekNumber() > week)  then
            week = v:weekNumber()
            adler32 = Util.IntegerChecksumCoroutine()
        end
        local res, err = coroutine.resume(adler32, LogEntry.time(v))
        if not res then
            error(err)
        end
        _, hashes[week] = coroutine.resume(adler32, LogEntry.random(v))
        if (k % 1000 == 0) then
            print('x')
        end
    end
    Profile:stop('Hashing')
    Util.DumpTable(hashes)
end

if (GetServerTime == nil) then
    launchTest()

else
    local ticker
    -- register for event.
     ticker = C_Timer.NewTicker(1, function()
        print("Waiting for data load")
        if (BigDataSet ~= nil) then
            ticker:Cancel()
            launchTest()
            stateManager:setBatchSize(100)
            stateManager:setUpdateInterval(100)
            ListSync = LibStub("ListSync-1.0")
            listSync = ListSync:new('test', sortedList)
            exampleEntry = PlayerAmountEntry:new({UnitGUID("player")}, math.random(100), "sam")
            print("Data load")
        end
    end)

end
