--[[
    Sorted lists with an insert API
]]--

if Util == nil then
    require "Util"
end

if SortedList == nil then
    SortedList = {}
end

function SortedList:new(data, sorter)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o._entries  = data or {}
    if type(o._entries) ~= 'table' then
        error('Entries not initialized to a table')
    end
    o._sorter = sorter
    return o
end

function SortedList:entries()
    return self._entries
end

function SortedList:insert(element)
    -- since we expect elements to be mostly appended, we do a shortcut check.
    if (#self._entries == 0 or self._sorter(self._entries[#self._entries], element)) then
        table.insert(self._entries, element)
        return
    end



    local position = Util.BinarySearch(self._entries, element, self._sorter)
    if position == nil then
        table.insert(self._entries, element)
    else
        table.insert(self._entries, position, element)
    end

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
