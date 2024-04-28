beginTests()


local Util = LibStub("EventSourcing/Util")


local int, realm = Util.getIntegerGuid("player")
local guid = Util.getGuidFromInteger(int, realm)

assertSame(guid, UnitGUID("player"))

local function TestBinarySearch()
    local comparator = function(a, b)
        if a < b then
            return -1
        elseif a > b then
            return 1
        else
            return 0
        end
    end
    local cases = {
        { list = { 1, 2}, search = 2, expected = 2 },
        { list = { 1, 2, 3}, search = 2, expected = 2 },
        { list = { 1, 2, 3, 4, 5, 6}, search = 14, expected = nil },
        { list = { 1, 2, 3, 4, 5, 6}, search = 2, expected = 2 },
        { list = { 10, 20, 30, 40, 50, 60}, search = 20, expected = 2 },
        { list = { 1, 2, 4, 5, 6}, search = 4, expected = 3 },
        { list = { 1, 2, 3, 5, 6}, search = 4, expected = 4 }

    }

    for _, v in ipairs(cases) do
        local result = Util.BinarySearch(v.list, v.search, comparator)
        assertSame(v.expected, result)
    end

end

local function TestBinarySearchDuplicates()
    local comparator = function(a, b)
        if a.val < b.val then
            return -1
        elseif a.val > b.val then
            return 1
        else
            return 0
        end
    end
    local search = { val = 2 }
    local cases = {
        { list = {{ val = 1 }, { val = 2 }, search, { val = 2 }}, search = search, expected =  3 },
        { list = {{ val = 1 }, { val = 1 }, { val = 1 }, { val = 2, a = 4 }, { val = 2, b = 6 }, search}, search = search, expected =  6 },
        { list = {{ val = 1 }, search, { val = 2 }, { val = 2 }}, search = search, expected =  2 },
        { list = {{ val = 1 }, search, { val = 2 }, { val = 2 }, { val = 2 }, { val = 2 }, { val = 2 }, { val = 2 }}, search = search, expected =  2 },
        { list = {{ val = 1 }, { val = 2 }, { val = 2 }, { val = 2 }, { val = 2 }, { val = 2 }, { val = 2 }, search}, search = search, expected =  8 }
    }

    for _, v in ipairs(cases) do
        local result = Util.BinarySearch(v.list, v.search, comparator)
        assertSame(v.expected, result)
    end

end

TestBinarySearch()
TestBinarySearchDuplicates()
printResultsAndExit()
