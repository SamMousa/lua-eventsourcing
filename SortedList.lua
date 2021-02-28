--[[
    Sorted lists with an insert API
]]--

if Util == nil then
    require "Util"
end

if SortedList == nil then
    SortedList = {}
end

--[[
 Create a new sorted list
 @param data the initial data, this must be already sorted or things will break
 @param compare the comparison function to use. This function should return -1 if a < b, 0 if a == b and 1 if a > b.
]]--
function SortedList:new(data, compare)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o._entries  = data or {}
    if type(o._entries) ~= 'table' then
        error('Entries not initialized to a table')
    end
    o._compare = compare
    return o
end

function SortedList:entries()
    return self._entries
end

function SortedList:insert(element)
    -- since we expect elements to be mostly appended, we do a shortcut check.
    if (#self._entries == 0 or self._compare(self._entries[#self._entries], element)) then
        table.insert(self._entries, element)
        return
    end

    local position = Util.BinarySearch(self._entries, element, self._compare)
    if position == nil then
        table.insert(self._entries, element)
    else
        table.insert(self._entries, position, element)
    end
end

--[[
  Insert an element into the list, if it doesn't exist already. Uniqueness is determined via the
  compare function only
]]--
function SortedList:uniqeInsert(element)
    if (#self._entries == 0 or self._compare(self._entries[#self._entries], element)) then
        table.insert(self._entries, element)
        return
    end

    local position = Util.BinarySearch(self._entries, element, self._compare)
    if position == nil then
        table.insert(self._entries, element)
    else
        table.insert(self._entries, position, element)
    end
end

-- We don't return a value since we are change the table, this makes it clear for consuming code
function SortedList:cast(table, compare)
    if (table._entries == nil) then
        error("This is not a sorted list table")
    end
    setmetatable(table, SortedList)
    table._compare = compare
end






function SortedList.TestInsert()
    local cases = {
        { list = { 2, 1}, insert = 4, sorter = Util.InvertSorter(function(a, b) return a < b  end) },
        { list = { }, insert = 4},
        { list = { 1, 5}, insert = 4},
        { list = { { x = 4 }, { x = 6 }}, insert = { x = 2 }, sorter = Util.CreateFieldSorter('x') },
        { list = { { x = 4 }, { x = 6 }}, insert = { x = 5}, sorter = Util.CreateFieldSorter('x') }
    }

    for _, v in ipairs(cases) do
        local sortedList = SortedList:new(v.list, v.sorter)
        sortedList:insert(v.insert)

        if not Util.IsSorted(sortedList:entries(), v.sorter) then

            io.write("Test FAIL =>")
            Util.DumpTable({
                insert = v.insert,
                list = v.list
            })
        else
            print("Test PASS")
        end

    end


end


--SortedList.TestInsert()
