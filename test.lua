if (GetTime == nil) then
    require "./wow"
    require "Util"
    require "./modules/LibStub"
    require "./LogEntry"
    require "./source/StartEntry"
    require "./source/PlayerAmountEntry"
    require "./source/PercentageDecayEntry"
    require "./ListSync"
    require "./StateManager"
    require "./LedgerFactory"
    require "./string"
    require "./SortedList"
    math.randomseed(os.time())
end
--error('disabled')


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

local PlayerAmountEntry = LibStub("EventSourcing/PlayerAmountEntry")
local StartEntry = LibStub("EventSourcing/StartEntry")
local PercentageDecayEntry = LibStub("EventSourcing/PercentageDecayEntry")
function createTestData(ledger)
    guids = {}
    -- Create 500 guids (think 1 database containing 500 players)
    for i = 1, 500 do
        local player = math.random(2 ^ 31 - 1)
        table.insert(guids, string.format('%08x', player))
    end


    Profile:start('Creating data')

    local start = StartEntry.create()
    ledger.submitEntry(start)
    for i = 1, 1 * 400 do
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

        local entry = PlayerAmountEntry.create(players, math.random(10), creator)
        local copy = {}
        for k, v in pairs(entry) do
            copy[k] = v
        end
        ledger.submitEntry(copy)
        if i % 1000 == 0 then
            print('.')
        end
    end
    print('done')

    Profile:stop('Creating data')
end

function launchTest()
    if BigDataSet == nil then
        BigDataSet = {}
    end
    print('reconstructing list from saved variables', #BigDataSet)

    --local records = Database.RetrieveByKeys(data, searchResult)
    --
    --printtable(records);

    --local log = LogEntry:new()
    local function registerReceiveHandler()

    end

    local function send()

    end

    local ledger = LibStub("EventSourcing/LedgerFactory").createLedger(BigDataSet, send, registerReceiveHandler)

    if (#BigDataSet == 0) then
        createTestData(ledger)
    end




    local state = {
        balances = {}
    }

    ledger.registerMutator(StartEntry.class(), function(entry)
        state = {
            balances = {}
        }
    end)

    ledger.registerMutator(PlayerAmountEntry.class(), function(entry)
        local creator = entry:creator()
        state.dkp_per_creator = state.dkp_per_creator or {}
        state.balances = state.balances or {}

        for _, player in ipairs(entry:players()) do
            state.balances[player] = (state.balances[player] or 0) + entry:amount()
            state.dkp_per_creator[creator] = (state.dkp_per_creator[creator] or 0) + entry:amount()
        end
    end)

    ledger.registerMutator(PercentageDecayEntry.class(), function(entry)
        local creator = entry:creator()
        for player, balance in pairs(state.balances) do
            if (balance > 0) then
                state.balances[player] = entry:applyDecay(balance)
                state.totalDecay = (state.totalDecay or 0) + (balance - state.balances[player])
            end
        end
    end)



    Util.DumpTable(state)

    previousLag = 0
    ledger.addStateChangedListener(function(lag, uncommitted)

    local stateManager = ledger.getStateManager()

        if (updateTestFrameStatus ~= nil) then
            local mydkp = state.balances[UnitGUID("player")] or 0;
            updateTestFrameStatus(
                string.format("Lag: %d", lag),
                string.format("Not committed to log: %d", uncommitted),
                string.format("Dkp: %d",  mydkp),
                string.format("Batchsize: %d", stateManager:getBatchSize()),
                string.format("Interval (measured): %d", stateManager:getUpdateInterval()),
                string.format("Log length: %d", #stateManager:getAllEntries())
            )
        else
            print(string.format("State changes, lag is now %d, there are %d entries not committed to the log", lag, uncommitted))
            if previousLag > 0 and lag == 0 then
                Util.DumpTable(state.dkp_per_creator)
            end
            previousLag = lag
        end
    end)





    --print(string.format("%08x", 51))
    --if (sortedList:length() > 0) then
    --    local adler32 = Util.IntegerChecksumCoroutine()
    --    stateManager:castLogEntry(sortedList:entries()[1])
    --    local week = sortedList:entries()[1]:weekNumber()
    --    local hashes = {}
    --    print('Start week', week)
    --    Profile:start('Hashing')
    --    for k, v in ipairs(sortedList:entries()) do
    --        stateManager:castLogEntry(v)
    --        if (v:weekNumber() > week)  then
    --            week = v:weekNumber()
    --            adler32 = Util.IntegerChecksumCoroutine()
    --        end
    --        local res, err = coroutine.resume(adler32, LogEntry.time(v))
    --        if not res then
    --            error(err)
    --        end
    --        _, hashes[week] = coroutine.resume(adler32, LogEntry.random(v))
    --        if (k % 1000 == 0) then
    --            print('x')
    --        end
    --    end
    --    Profile:stop('Hashing')
    --    Util.DumpTable(hashes)
    --end
end

if (GetServerTime == nil) then
    launchTest()

else
--    local ticker
--    -- register for event.
--     ticker = C_Timer.NewTicker(1, function()
--        print("Waiting for data load")
--        if (BigDataSet ~= nil) then
--            ticker:Cancel()
--            launchTest()
--            stateManager:setBatchSize(10)
--            stateManager:setUpdateInterval(1000)
--            ListSync = LibStub("ListSync-1.0")
--            listSync = ListSync:new('test', sortedList)
--            exampleEntry = PlayerAmountEntry:new({UnitGUID("player")}, math.random(100), "sam")
--            print("Data load")
--        end
--    end)

end



-- event loop for C_Timer outside wow
if C_Timer.startEventLoop ~= nil then
C_Timer.startEventLoop()
end
