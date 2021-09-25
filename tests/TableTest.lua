beginTests()

local Util = LibStub("EventSourcing/Util")
local Table = LibStub("EventSourcing/Table")


local table = Table.new({
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


printResultsAndExit()
