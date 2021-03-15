if (GetTime == nil) then
    require "./wow"
    require "./Libs/LibStub"
    require "Util"
    require "./SortedList"
    require "./LogEntry"
    require "./source/StartEntry"
    require "./source/PlayerAmountEntry"
    require "./source/PercentageDecayEntry"
    require "./StateManager"
    require "./source/Message"
    require "./source/Message/AdvertiseHash"
    require "./source/Message/WeekData"
    require "./ListSync"
    require "./LedgerFactory"
    math.randomseed(os.time())
end

local EventSourcing, _ = LibStub:NewLibrary("EventSourcing", 1)
if not EventSourcing then
    return end

local state = {
    balances = {},
    weeks = {},
    messages = {}
}

local Profile = {}
function Profile:start(name)
    Profile[name] =  GetTime()
end

function Profile:stop(name)
    local elapsed =  GetTime() - Profile[name]
    print(string.format(name .. ": elapsed time: %.2f\n", elapsed))
end

local PlayerAmountEntry = LibStub("EventSourcing/PlayerAmountEntry")
local StartEntry = LibStub("EventSourcing/StartEntry")
local TextMessageEntry = LibStub("EventSourcing/TextMessageEntry")
local Util = LibStub("EventSourcing/Util")

local ScrollingTable = LibStub("ScrollingTable");
local PercentageDecayEntry = LibStub("EventSourcing/PercentageDecayEntry")

-- Allows defining fallbacks so we can test outside WoW
local function LibStubWithStub(library, fallback)
    local result, lib = pcall(LibStub, library)
    if result then
        return lib
    elseif type(fallback) == 'function' then
        return fallback()
    else
        return fallback
    end
end

function EventSourcing.createTestData()
    local ledger = EventSourcing.ledger
    local guids = {}
    -- Create 500 guids (think 1 database containing 500 players)
    for _ = 1, 500 do
        local player = math.random(2 ^ 31 - 1)
        table.insert(guids, string.format('%08x', player))
    end

    state = {
        balances = {},
        weeks = {},
        total_dkp = 0
    }
    ledger.reset()
    Profile:start('Creating data')

    local start = StartEntry.create(guids[1])
    start.t = Util.time() - 604800 * 4
    ledger.submitEntry(start)
    for i = 1, 1 * 400 do
        -- First 50 players are managers
        local creator = guids[math.random(1, 10)]

        local players = {}
        for j = 1, math.random(10) do
            players[j] = guids[math.random(#guids)]
        end

        local entry = PlayerAmountEntry.create(players, math.random(10), creator)
        -- today minus 4 weeks
        entry.t = Util.time() - math.random(604800 * 4)
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

function EventSourcing.launchTest()
    local AceComm = LibStubWithStub("AceComm-3.0", {
        RegisterComm = function()  end
    })
    local LibSerialize = LibStubWithStub("LibSerialize", {})
    local LibDeflate = LibStubWithStub("LibDeflate", {})



    if BigDataSet == nil then
        BigDataSet = {}
    end
    print('reconstructing list from saved variables', #BigDataSet)

    --local records = Database.RetrieveByKeys(data, searchResult)
    --
    --printtable(records);

    local function registerReceiveHandler(callback)
        print("Registering handler")
        AceComm:RegisterComm('ledgertest', function(prefix, text, distribution, sender)
            local result, data = LibSerialize:Deserialize(
                LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(text)))
            if result then
                if distribution == "WHISPER" then
                    distribution = "GUILD"
                end
                callback(data, distribution, sender)
            else
                print("Failed to deserialize data", data)
            end
        end)
    end

    local function send(data, distribution, target, prio, callbackFn, callbackArg)
        if distribution == "GUILD" then
            distribution = "WHISPER"
            if UnitName("player") == "Awesam" then
                target = "Samdev"
            else
                target = "Awesam"
            end
        end
        local serialized = LibSerialize:Serialize(data)
--        print("Sending")
--        Util.DumpTable(data)
        local compressed = LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(serialized))

        AceComm:SendCommMessage('ledgertest', compressed, distribution, target, prio, callbackFn, callbackArg)
    end

    EventSourcing.ledger = LibStub("EventSourcing/LedgerFactory").createLedger(BigDataSet, send, registerReceiveHandler, function() return true end)
    local ledger = EventSourcing.ledger
    if (#BigDataSet == 0) then
--        createTestData(ledger)
    end

    ledger.registerMutator(TextMessageEntry.class(), function(entry)
        local _, _, _, _, _, name, _ = GetPlayerInfoByGUID(Util.getGuidFromInteger(entry:creator()))
        table.insert(state.messages, {
            date("%m/%d/%y %H:%M:%S", entry:time()),
            name,
            entry:message(),
        })
    end)
    ledger.registerMutator(StartEntry.class(), function(entry)
        Util.wipe(state.messages)
        Util.wipe(state.balances)
        Util.wipe(state.weeks)
        print("Start entry handled")
    end)

    ledger.addStateRestartListener(function()
        Util.wipe(state.messages)
        Util.wipe(state.balances)
        Util.wipe(state.weeks)
        print("State restarted")
    end)
    ledger.registerMutator(PlayerAmountEntry.class(), function(entry)

        local creator = entry:creator()
        local amount = entry:amount()
        state.weeks[Util.WeekNumber(entry:time())] = true


        state.dkp_per_creator = state.dkp_per_creator or {}
        state.balances = state.balances or {}

        for _, player in ipairs(entry:players()) do
            state.balances[player] = (state.balances[player] or 0) + amount
            state.total_dkp = (state.total_dkp or 0)+ amount
            state.dkp_per_creator[creator] = (state.dkp_per_creator[creator] or 0) + amount
        end

    end)

    ledger.registerMutator(PercentageDecayEntry.class(), function(entry)
        for player, balance in pairs(state.balances) do
            if (balance > 0) then
                state.balances[player] = entry:applyDecay(balance)
                state.totalDecay = state.totalDecay + (balance - state.balances[player])
            end
        end
    end)



    Util.DumpTable(state)

    local previousLag = 0
    local updateCounter = 0


    local scrollingTable = ScrollingTable:CreateST({
        {
            name="Timestamp",
            width=150
        },
        {
            name="Sender",
            width=100
        },
        {
            name="Message",
            width=300
        }
    })
    local display = scrollingTable.frame
    display:SetPoint("CENTER", UIParent)
    display:SetHeight(200)
    display:Show()
    display:RegisterForDrag("Leftbutton")
    display:EnableMouse(true)
    display:SetMovable(true)
    display:SetScript("OnDragStart", function(self) self:StartMoving() end)
    display:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    scrollingTable:SetData(state.messages, true)
    SLASH_LEDGERCHAT1 = "/ledgerchat"
    SlashCmdList["LEDGERCHAT"] = ledger.sendMessage
    ledger.addStateChangedListener(function(lag, uncommitted)
        updateCounter = updateCounter + 1

        local stateManager = ledger.getStateManager()
        scrollingTable:SortData()
        if (EventSourcing.updateTestFrameStatus ~= nil) then
            local mydkp = state.balances[UnitGUID("player")] or 0;
            EventSourcing.updateTestFrameStatus(
                string.format("Lag: %d", lag),
                string.format("Uncommitted: %d", uncommitted),
                string.format("Dkp: %d",  mydkp),
                string.format("Total dkp: %d",  state.total_dkp),
                string.format("Batchsize: %d", stateManager:getBatchSize()),
                string.format("Interval (measured): %d", stateManager:getUpdateInterval()),
                string.format("Log length: %d", stateManager:logSize()),
                string.format("Update counter: %d", updateCounter),
                -- hash > 32bit signed int allows
                string.format("Hash: %s", stateManager:stateHash())
            )
        else
            print(string.format("State changed, lag is now %d, there are %d entries not committed to the log", lag, uncommitted))
            if previousLag > 0 and lag == 0 then
                Util.DumpTable(state.dkp_per_creator)
                for k, _ in pairs(state.weeks) do
                    print(string.format("Week %d hash: %d", k, ledger.getListSync():weekHash(k)))
                end
            end
            previousLag = lag
        end
    end)

    if UnitName("player") == "Awesam" then
        print("Player is Sam, enabling sending")
        ledger.enableSending()
    else
        print("Player is not Sam, not enabling sending")
    end





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
    EventSourcing.launchTest()

else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(data, event, addon)
        if addon == 'LuaDatabase'then
            BigDataSet = BigDataSet or {}
            EventSourcing.launchTest()
        end
    end)
end





-- event loop for C_Timer outside wow
if C_Timer.startEventLoop ~= nil then
C_Timer.startEventLoop()
end
