
require "./Database"
function printtable(table, indent)

    indent = indent or 0;

    local keys = {};

    for k in pairs(table) do
        keys[#keys+1] = k;
    end

    print(string.rep('  ', indent)..'{');
    indent = indent + 1;
    for k, v in pairs(table) do

        local key = k;
        if (type(key) == 'string') then
            if not (string.match(key, '^[A-Za-z_][0-9A-Za-z_]*$')) then
                key = "['"..key.."']";
            end
        elseif (type(key) == 'number') then
            key = "["..key.."]";
        end

        if (type(v) == 'table') then
            if (next(v)) then
                print(string.rep('  ', indent), tostring(key), "=");
                printtable(v, indent);
            else
                print(string.rep('  ', indent), tostring(key), "= {},");
            end
        elseif (type(v) == 'string') then
            print(string.rep('  ', indent), tostring(key), " = ", "'"..v.."'");
        else
            print(string.rep('  ', indent), tostring(key), " = ", tostring(v));
        end
    end
    indent = indent - 1;
    print(string.rep('  ', indent)..'}');
end


data = {}

data.test1 =  {a = 16, ts = 11213, player = "a9847aa3-ca65-4246-8614-2cd0436f0ed9"};
data.test2 =  {a = 14, ts = 12313, player = "a9847aa3-ca65-4246-8614-2cd0436f0ed9"};
data.test3 =  {b = 12, ts = 12113};
data.test4 =  {a = 11, ts = 12313};
data.test5 =  {a = 12, ts = 12113};
data.test6 =  {a = 11, ts = 12313};


local table = Database.Table:new(data);
table:AddIndex("a")
table:AddIndex("b")

local uuid = table:InsertRecordWithUUID({b = 15, ts = 13});
table:AddIndex("a")
table:AddIndex("b")
table:AddIndex("player");

printtable(table:SearchValue("a9847aa3-ca65-4246-8614-2cd0436f0ed9", "player"))

table:InsertRecordWithKey('test', {b = 15, ts = 13, dkpmutation = -5, note="test123"});
table:UpsertRecordWithKey('test', {b = 15, a =6,  ts = 13, note="cool stuff"});
local searchResult = table:SearchRange(10, 15, "b");

--print(table:Serialize())
--printtable(searchResult, 0)
--
--print(Database.UUID())
--print(Database.UUID())
--print(Database.UUID())
--print(Database.UUID())
--print(Database.UUID())
--os.execute("sleep 3")
--print(Database.UUID())
--print(Database.UUID())
--print(Database.UUID())
--print(Database.UUID())
--print(Database.UUID())


--local records = Database.RetrieveByKeys(data, searchResult)
--
--printtable(records);
