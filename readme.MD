# LUA Database

This is / will be a library that creates a table store in LUA with support for custom indices.

The API, for now looks roughly like this:

```lua
data = {}

data.test1 =  {a = 16, ts = 11213};
data.test2 =  {a = 14, ts = 12313};
data.test3 =  {b = 12, ts = 12113};
data.test4 =  {a = 11, ts = 12313};
data.test5 =  {a = 12, ts = 12113};
data.test6 =  {a = 11, ts = 12313};


local table = Database.Table:new(data);
table:AddIndex("a")
table:AddIndex("b")

-- This will take all records with values 10 .. 15 in field b
local searchResult = table:SearchRange(10, 15, "b");

```

Future ideas:
- Add optional auto updating of indices (this can be more efficient than rebuilding them)
- 
