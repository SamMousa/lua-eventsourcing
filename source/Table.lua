local Table, _ = LibStub:NewLibrary("EventSourcing/Table", 1)
if not Table then
    return
end

local Util = LibStub("EventSourcing/Util")
local SortedList = LibStub("EventSourcing/SortedList")


local function curryOne(func, param)
    return function(...)
        return func(param, ...)
    end
end


local function addRow(table, row)
    -- Add the row to each index
    local triggers = {}
    table.rowCount = table.rowCount + 1
    for indexName, index in pairs(table.indices) do
        local position = index:insert(row)
        -- Check watches
        for _, watch in ipairs(table.watches[indexName]) do
            local callback, offset, length = unpack(watch)
            if position >= offset and position <= offset + length then
                triggers[#triggers + 1] = callback
            end
        end
    end

    -- Execute triggers
    for _, callback in ipairs(triggers) do
        pcall(callback, 'addRow')
    end
end

local function updateRow(table, row, mutator)
    -- Get the current location in each index
    local oldPositions = {}
    for indexName, index in pairs(table.indices) do        
        oldPositions[indexName] = index:remove(row)
    end
    mutator()

    -- After mutating we insert the row into all indices again
    local triggers = {}
    for indexName, index in pairs(table.indices) do
        local newPosition = index:insert(row)
        -- Check watches
        for _, watch in ipairs(table.watches[indexName]) do
            local callback, offset, length = unpack(watch)
            -- trigger for same spot
            if (true or oldPositions[indexName] ~= newPosition) and (
                (oldPositions[indexName] >= offset and oldPositions[indexName] <= offset + length)
                or  (newPosition >= offset and newPosition <= offset + length)
            ) then
                triggers[#triggers + 1] = callback
            end
        end
    end

    -- Execute triggers
    for _, callback in ipairs(triggers) do
        pcall(callback, 'updateRow')
    end
end

local function iterateByIndex(table, name, start, length)
    local i = (start or 1) - 1
    local data = table.indices[name]:entries()
    local n = math.min(#data, i + (length or 0))
    return function()
        i = i + 1
        if i <=n then return i, data[i] end
    end
end

--[[
    Register a callback to be called when a specific part of the index changes
    Returns a function that can be used to remove the watch and a function to update the offset / length.
]]
local function watchIndexRange(table, indexName, callback, offset, length)
    local watches = table.watches[indexName]
    local watch = {0, offset, length}
    local paused = false
    -- We want to pass an iterator to the callback, so we curry it.
    watch[1] = function(reason)
        return paused or callback(iterateByIndex(table, indexName, watch[2], watch[3]), reason, table.rowCount)
    end
    watches[#watches+1] = watch

    local updateOffset = function(newOffset)
        watch[2] = newOffset
        watch[1]('updateOffset')
    end

    local update = function(newOffset, newLength)
        watch[2] = newOffset
        watch[3] = newLength
        watch[1]('updateWatch')
    end

    local cancel = function()
        for i, v in ipairs(watches) do
            if v == watch then
                watches[i] = nil
                break;
            end
        end
    end

    return {
        update = update,
        updateOffset = updateOffset,
        cancel = cancel,
        pause = function() paused = true end,
        resume = function()
             paused = false
             watch[1]('resume')

        end,
        trigger = function() watch[1]('trigger') end
    }
end


Table.new = function(indices)
    local private = {
        -- A list of index data tables
        indices = {},
        watches = {},
        rowCount = 0
    }

    for name, compare in pairs(indices) do
        Util.assertFunction(compare)
        private.indices[name] = SortedList:new({}, compare, false)
        private.watches[name] = {}
    end
    local public = {
        addRow = curryOne(addRow, private),
        updateRow = curryOne(updateRow, private),
        iterateByIndex = curryOne(iterateByIndex, private),
        watchIndexRange = curryOne(watchIndexRange, private)
    }

    return public
end



