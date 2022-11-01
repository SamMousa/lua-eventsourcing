beginTests()

local Util = LibStub("EventSourcing/Util")
local Table = LibStub("EventSourcing/Table")


local table = Table.new({


}, {
    a = Util.CreateFieldSorter('a'),
    inverse_a = Util.InvertSorter(Util.CreateFieldSorter('a'))

})

table.addRow({
    a =  5
})

table.addRow({
    a =  10
})

table.addRow({
    a =  11
})

table.addRow({
    a =  8
})
table.addRow({
    a =  8
})
table.addRow({
    a =  8
})
table.addRow({
    a =  8
})

local someRow = {
    a =  8
}

table.addRow(someRow)

local updateCounter = 0
local watch = table.watchIndexRange('a', function(iterator, reason)
    updateCounter = updateCounter + 1
end, 1, 5)

assertSame(0, updateCounter)
table.addRow({
    a =  1
})

assertSame(1, updateCounter)
watch.update(1, 50)
assertSame(2, updateCounter)

table.updateRow(someRow, function()
    someRow.a = 400
end)
assertSame(3, updateCounter)
table.updateRow(someRow, function()
    someRow.a = 400
end)
assertSame(4, updateCounter)

watch.pause()
for i = 0, 10000 do
    table.addRow({a = math.random(10000)})
end
assertSame(4, updateCounter)
watch.resume()
assertSame(5, updateCounter)


-- test nonexistent index
assertError(function()
table.watchIndexRange('test', function() end)
end)




-- unique indexes are faster but dont support index range watches
-- test this with a model type table that CLM uses:

local Raid = {} -- Raid information
function Raid:New(uid, name, roster, config, creator, entry)
    local o = {}

    setmetatable(o, self)
    self.__index = self

    o.entry = entry

    -- Raid Management
    o.uid  = uid
    o.roster = roster

    o.config = config
    o.name = name
    o.status = "CREATED"
    -- o.owner = creator

    o.startTime = 0
    o.endTime = 0

    -- GUID dict
    -- Dynamic status of tje raid
    o.players = { [creator] = true } -- for raid mangement we check sometimes if creator is part of raid
    o.standby = { }

    -- Historical storage of the raid
    o.participated = {
        inRaid = {},
        standby = {}
    }

    return o
end

function Raid:UID()
    return self.uid
end

function Raid:Name()
    return self.name
end

local raids = Table.new({
    name = function(raid) return raid:Name() end,
    uid = test
})

local A = {}
A.__index = A
function A:new()
    local o = {}
    setmetatable(o, self)

    return o
end

function A:test()

print("test")
end

local a = A:new()
print(a:test())

printResultsAndExit()