# Table library

The table library allows you to manage a collection of rows (represented as tables).
The table supports multiple indices as well as change events for specific parts of an index.

When inserting rows into the table you should make sure that the rows are not edited externally.

## Index
An index is defined by a comparison function, the comparison can be single or multiple columns.
See `Util.CreateMultiFieldSorter` and `Util.CreateFieldSorter`.

```lua
local table = Table.new({
    primary = Util.createFieldSorter('a')
})


table.addRow({a = 5})
table.addRow({a = 3})

for i, v in ipairs(table.iterateByIndex('primary') do
  print(i, v.a)
done
```
Will output
```
1    3
2    5
```

Note the use of `iterateByIndex` this creates an iterator allowing you to go over the elements in any order as long as there is an index for it. The iteration itself is really cheap since the index is already in memory.


## Updating rows
To update a row you should wrap the code in a closure and pass it to the table:
```lua
local table = Table.new({
    primary = Util.createFieldSorter('a')
})

local row = {a = 5, t = 'row1'}
table.addRow(row)
table.addRow({a = 3, t = 'row2'})

for i, v in ipairs(table.iterateByIndex('primary') do
  print(i, v.a, v.t)
done

table.updateRow(row, function()
    row.a = 1
))

for i, v in ipairs(table.iterateByIndex('primary') do
  print(i, v.a, v.t)
done

```
Will output
```
1    3    row2
2    5    row1
1    1    row1
2    3    row2
```

Internally the library will do some bookkeeping to make sure indices remain sorted.

## Watching index ranges
Imagine you have a very large table, 10.000 records for example.
When displaying this table in a UI, most records won't be visible. Suppose there are 50 visible lines, each line showing data from 1 row.

Now if any of the rows change, normally what you do is redraw the whole table, regardless if the change is relevant.

To aid with the library supports watching indexes for changes. The reasoning is that you will watch the index that has the same sort order used in your UI.

```lua
local table = Table.new({
    name = Util.createFieldSorter('name'),
    age = Util.createFieldSorter('age')
})

-- build the initial table.
table.addRow({name = "Bob1", age = 20})
table.addRow({name = "Bob2", age = 30})
table.addRow({name = "Bob3", age = 40})
table.addRow({name = "Bob4", age = 25})
table.addRow({name = "Bob5", age = 35})
table.addRow({name = "Bob6", age = 45})
local UI = ImaginaryScrollTable()
-- Let's assume our UI is very small, so it can only show 2 rows.
-- We pass an offset, 1 (our UI scrollbar is at the top) and a length.
local watch = table.watchIndexRange('age', function(iterator, reason) 
    -- This function is called every time something in our visible area has changed.
    -- Reason contains the cause (addRow, updateRow, trigger, updateWatch, updateOffset)

end, 1, 2)

-- The watch object allows us to cancel our subscription as well as update our offset & length.

UI.onScroll = function(offset) {
    -- Updating the offset or length will always trigger the watch.
    watch.updateOffset(offset)
}

-- Initial setup of UI is done, load data.
watch.trigger()

-- When the UI closes you can cancel the watch.
watch.cancel()
```

