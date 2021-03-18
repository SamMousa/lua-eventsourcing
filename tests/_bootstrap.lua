print("Starting bootstrap")

require "tests/_wowstubs"
require "libs/LibStub/LibStub"
require "source/Util"
require "source/SortedList"
require "source/LogEntry"
require "source/Message"
require "source/AdvertiseHashMessage"
require "source/RequestWeekMessage"
require "source/BulkDataMessage"
require "source/WeekDataMessage"
require "source/StateManager"
require "source/ListSync"
require "source/LedgerFactory"
math.randomseed(os.time())

local assertionStatistics = {
    total = 0,
    passed = 0,
    failed = 0
}
function assertTrue(param, message)
    assertionStatistics["total"] = assertionStatistics["total"] + 1
    assert(param == true, "Assertion failed: " .. message)
    assertionStatistics["passed"] = assertionStatistics["passed"] + 1
end

function assertFalse(param, message)
    assertionStatistics["total"] = assertionStatistics["total"] + 1
    assert(param == false, message or "failed asserting that param is false")
    assertionStatistics["passed"] = assertionStatistics["passed"] + 1
end

function assertSame(expected, value)
    assertionStatistics["total"] = assertionStatistics["total"] + 1
    assert(expected == value, "failed assert that expected " .. expected .. " matches " .. value)
    assertionStatistics["passed"] = assertionStatistics["passed"] + 1
end

function assertError(cb)
    assertionStatistics["total"] = assertionStatistics["total"] + 1
    assert(pcall(cb), "Assert failed: Expected error")
    assertionStatistics["passed"] = assertionStatistics["passed"] + 1
end

local Util = LibStub("EventSourcing/Util")
-- freeze time
local ts = Util.time()
Util.time = function() return ts  end

function printResultsAndExit()
    Util.DumpTable(assertionStatistics)
    if (assertionStatistics['failed'] > 0) then
        os.exit(1)
    else
        os.exit(0)
    end
end

function beginTests()
    print(string.format("Starting tests in file %s", arg[0]))
end

print("Finished bootstrap")
