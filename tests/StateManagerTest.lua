beginTests()

local Logger = LibStub("LibLogger")
local StateManager = LibStub("EventSourcing/StateManager")
local LogEntry = LibStub("EventSourcing/LogEntry")
local Util = LibStub("EventSourcing/Util")
local testData = {}
local sortedList = LogEntry.sortedList(testData)
local stateManager = StateManager:new(sortedList, Logger:New())




local TestEntry = LogEntry:extend('TE')

function TestEntry:new(message)
    local o = LogEntry.new(self)
    o.m = message
    return o
end

local messages = {}
stateManager:registerHandler(TestEntry, function(entry)
    table.insert(messages, entry.m)
end)

stateManager:addStateRestartListener(function()
    messages = {}
end)

stateManager:lag();

assertTrue(type(StateManager) == 'table')
-- Hash starts at 0
assertSame(0, stateManager:stateHash())
assertEmpty(messages)

sortedList:uniqueInsert(TestEntry:new('test'))
stateManager:catchup()
assertCount(1, messages)
for i = 1, 100 do
    sortedList:uniqueInsert(TestEntry:new('test' .. i))
end
stateManager:catchup()
assertCount(101, messages)
assertNotSame(0, stateManager:stateHash())

-- test that state hash is the same if we restart.
local expectedHash = stateManager:stateHash()
stateManager:restart()
assertSame(0, stateManager:stateHash())
stateManager:catchup()
assertSame(expectedHash, stateManager:stateHash())



-- Test that setting an interval registers a timer
stateManager:restart()
stateManager:setUpdateInterval(1000)
assertCount(1, C_Timer.tickers)

assertSame(101, stateManager:lag())
C_Timer.Tick()
assertSame(101 - stateManager:getBatchSize(), stateManager:lag())

sortedList._entries = {}
-- test ignoring entries
local entryToIgnore = TestEntry:new('ignore this one')
assertError(function()
    stateManager:createIgnoreEntry(entryToIgnore, "bob")
end)

stateManager:catchup()
assertEmpty(messages)
sortedList:uniqueInsert(entryToIgnore)
stateManager:catchup()
assertSame(0, stateManager:lag())
assertSame('ignore this one', messages[#messages])
local ignoreEntry = stateManager:createIgnoreEntry(entryToIgnore, "Bob")
sortedList:uniqueInsert(ignoreEntry)
assertCount(2, sortedList:entries())
assertSame(2, stateManager:lag())
stateManager:catchup()
assertSame(0, stateManager:lag())
assertEmpty(messages)
assertNotSame('ignore this one', messages[#messages])
printResultsAndExit()
