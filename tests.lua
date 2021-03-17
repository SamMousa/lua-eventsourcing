if (GetTime == nil) then
    require "./wow"
    require "Util"
    require "./modules/LibStub"
    require "./LogEntry"
    require "./source/StartEntry"
    require "./source/PlayerAmountEntry"
    require "./source/PercentageDecayEntry"
    require "./StateManager"
    require "./ListSync"
    require "./LedgerFactory"
    require "./string"
    require "./SortedList"
    math.randomseed(os.time())
end



local PlayerAmountEntry = LibStub("EventSourcing/PlayerAmountEntry")
local StartEntry = LibStub("EventSourcing/StartEntry")



local subject
subject = PlayerAmountEntry.create({}, 10, 1234)
assertSame(subject:creator(), 1234)
assertSame(subject:amount(), 10)
assertSame(subject:class(), 'PAE')

assertError(function()
    PlayerAmountEntry.create({}, 15, 'bob')
end)


--[[ BEGIN TESTS ]]--

subject = StartEntry.create(1234)
assertSame(subject:creator(), 1234)


local sortedList = LogEntry.sortedList
assertTrue(true)
