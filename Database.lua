
if Database == nil then
    Database = {
        Table = {}
    }

end

Database.time = function()
    if (os.time ~= nil) then
        return os.time()
    elseif time ~= nil then
        return time()
    end
    error("No time function found", 2)
end

function Database.Table:new(data)
    o = {}
    setmetatable(o, self)
    self.__index = self

    o._indexes = {}
    o._data = data
    return o
end

function Database.Table:Serialize()
    local lines = {}
    local columns = {}
    for _, v in pairs(self._data) do
        for k, _ in pairs(v) do
            columns[k] = 1
        end
    end

    local sortedColumns = {}
    for k, _ in pairs(columns) do
        table.insert(sortedColumns, k)
    end
    table.sort(sortedColumns)

    table.insert(lines, table.concat(sortedColumns, '~'))

    for k, v in pairs(self._data) do
        local row = {}
        table.insert(row, k)
        for _, col in ipairs(sortedColumns) do
            table.insert(row, v[col] or "")
        end
        table.insert(lines, table.concat(row, "~"))
    end
    printtable(lines)

    return table.concat(lines, "\n")

end

function Database.Table:AddIndex(key)
    self._indexes[key] = Database.CreateIndex(self._data, key)
end

function Database.Table:SearchRange(min, max, key)
    if (self._indexes[key] == nil) then
        error("Index not defined: " .. key, 2);
        return
    end
    return Database.RetrieveByKeys(self._data, Database.SearchRange(min, max, self._indexes[key]))
end

function Database.Table:KeyExists(key)
    return self._data[key] ~= nil
end

function Database.Table:InsertRecordWithKey(key, value)
    if self:KeyExists(key) then
        error("Duplicate primary key: " .. key)
    end
    self._data[key] = value
    return key
end

function Database.Table:UpsertRecordWithKey(key, value)
    self._data[key] = value
    return key
end


function Database.Table:InsertRecordWithUUID(value)
    local key = Database.UUID();
    return self:InsertRecordWithKey(key, value)
end

Database.CreateTable = function(data)
    return Database.Table:new(data)
end

Database.CreateIndex = function(data, key)
    local index = {}
    for uniqueId, tableRow in pairs(data) do
        if tableRow[key] ~= nil then
            local indexEntry = {}
            indexEntry[0] = tableRow[key]
            indexEntry[1] = uniqueId

            table.insert(index, indexEntry)
        end
    end
    table.sort(index, function(a, b)
        return a[0] < b[0];
    end)
    return index
end

--[[
  Search an index, return all records within the range (inclusive)
  The index is assumed to be ordered, so we will stop searching as soon as we pass max.
--]]
Database.SearchRange = function(min, max, index)
    local result = {}
    local key = Database.BinarySearch(min, index)
    if (key == nil) then
        return result
    end
    while(key <= #index and index[key][0] <= max) do
        table.insert(result, index[key][1])
        key = key + 1
    end


    return result


end

--[[
  Binary search an index, this value will return the first index that is >= the search value
--]]
Database.BinarySearch = function(value, index)
    local min = 1
    local max = #index

    if (max == 0) then
        return nil
    end

    -- Floor division
    local test = (max + min) // 2

    while (max > min) do
        print(min, max, test, index[test][0], value)
        if index[test][0] >= value then
            max = test
            test = (max + min) // 2
        else
            min = test
            test = (max + min) // 2 + 1
        end
    end

    print("Min", min, "Max", max)
    return max
end

Database.RetrieveByKeys = function(data, keys)
    local result = {}
    for _, k in ipairs(keys) do
        result[k] = data[k]
    end
    return result
end

Database.UUID = function()
    local random = math.random(0, 1000000)
    local ts = Database.time()
    return string.format('{%s-%s}', ts, random)
end
