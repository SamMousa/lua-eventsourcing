
if Database == nil then
    Database = {
        Table = {},
        Index = {}
    }

end

function Database.time()
    if (os ~= nill and os.time ~= nil) then
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

function Database.Index:new(key, data)
    o = {}
    setmetatable(o, self)
    self.__index = self

    o._entries = {}
    o._key = key

    for _, tableRow in pairs(data) do
        if tableRow[key] ~= nil then
            table.insert(o._entries, tableRow)
        end
    end
    table.sort(o._entries, function(a, b)
        return a[key] < b[key];
    end)
    return o
end

-- Searches for the first index that has value >= to the given value
function Database.Index:BinarySearch(value)
    local min = 1
    local max = #self._entries

    local key = self._key
    if (max == 0) then
        return nil
    end

    local iterations = 0

    while (min < max) do
        test = math.floor((max + min) / 2)
        if self._entries[test][key] >= value then
            max = test
        else
            min = test + 1
        end
        iterations = iterations + 1

    end

    return max
end


function Database.Index:SearchValue(value)
    local index = self:BinarySearch(value)
    local entry = self._entries[index]
    if (entry[self._key] == value) then
        return entry
    end

    return nil
end

function Database.Index:SearchAllByValue(value)
    local index = self:BinarySearch(value)
    local result = {}
    while self._entries[index][self._key] == value do
        table.insert(result, self._entries[index])
        index = index + 1
    end
    return result
end

function Database.Index:SearchRange(min, max)

    local result = {}
    local key = self:BinarySearch(min)
    if (key == nil) then
        return result
    end
    while(key <= #self._entries and self._entries[key][self._key] <= max) do
        table.insert(result, self._entries[key])
        key = key + 1
    end


    return result
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
    return table.concat(lines, "\n")

end

function Database.Table:AddIndex(key)
    local data = self._data
    self._indexes[key] = Database.Index:new(key, data)
end

function Database.Table:SearchRange(min, max, key)
    if (self._indexes[key] == nil) then
        error("Index not defined: " .. key, 2);
        return
    end
    return self._indexes[key]:SearchRange(min, max)
end

function Database.Table:SearchValue(value, key)
    if (self._indexes[key] == nil) then
        error("Index not defined: " .. key, 2);
        return
    end
    return self._indexes[key]:SearchValue(value)
end

function Database.Table:SearchAllByValue(value, key)
    if (self._indexes[key] == nil) then
        error("Index not defined: " .. key, 2);
        return
    end
    return self._indexes[key]:SearchAllByValue(value)
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

function Database.CreateTable(data)
    return Database.Table:new(data)
end

function Database.CreateIndex(data, key)
    local index = {
        field = key,
        entries = {}
    }
    for tableRow in pairs(data) do
        if tableRow[key] ~= nil then
            table.insert(index.entries, tableRow)
        end
    end
    table.sort(index.entries, function(a, b)
        return a[key] < b[key];
    end)
    return index
end

--[[
  Search an index, return all records within the range (inclusive)
  The index is assumed to be ordered, so we will stop searching as soon as we pass max.
--]]
function Database.SearchRange(min, max, index)
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
function Database.BinarySearch(value, index)
    local min = 1
    local max = #index

    if (max == 0) then
        return nil
    end

    -- Floor division
    local test = math.floor((max + min) / 2)

    while (max > min) do
        print(min, max, test, index[test][0], value)
        if index[test][0] >= value then
            max = test
            test = math.floor((max + min) / 2)
        else
            min = test
            test = math.ceil((max + min) / 2)
        end
    end

    print("Min", min, "Max", max)
    return max
end

function Database.RetrieveByKeys(data, keys)
    local result = {}
    for _, k in ipairs(keys) do
        result[k] = data[k]
    end
    return result
end

function Database.UUID()
    local random = math.random(1, 2^31 - 1)
    local ts = Database.time() - 1577836861

    return string.format('%08x%08x', ts, random)
end
