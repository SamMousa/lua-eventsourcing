if (GetTime == nil) then
    require "./Database"
    require "./wow"
    require "./string"
end
--error('disabled')
if (math.randomseed ~= nil) then

    math.randomseed(GetTime())
end

if (os == nil) then
    os = {
        clock =  GetTimePreciseSec
    }
end

Profile = {}
function Profile:start(name)
    Profile[name] = os.clock()
end

function Profile:stop(name)
    local elapsed = os.clock() - Profile[name]
    print(string.format(name .. ": elapsed time: %.2f\n", elapsed))
end




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

guids = {}
-- Create 1000 guids (think 1 database containing 1000 players)
for i = 1, 1000 do
    local server = math.random(5)
    local player = math.random(2 ^ 31 - 1)
    table.insert(guids, string.format('%08x%08x', server, player))
end


Profile:start('Creating data')
for i = 1, 1000 * 1000 do
    local uuid = Database.UUID()
--    data[uuid] = {
--        player = string.guid(),
--        a = 15,
--        i = i,
--        ts = Database.time()
--    }
    local player = math.random(1000)
    data[uuid] = {
        player = guids[player],
        ts = Database.time()
    }
end

Profile:stop('Creating data')
Profile:start('Creating table')
local table = Database.Table:new(data);
globalTable = table
Profile:start('Creating indices')
--table:AddIndex("a")
--table:AddIndex("i")
--table:AddHashIndex("player");
Profile:stop('Creating indices')
Profile:stop('Creating table')

Profile:start('Search 1')
local guid = guids[math.random(1000)]
--printtable(table:SearchAllByValue(guid, "player"))
Profile:stop('Search 1')

table:InsertRecordWithKey('test', {b = 15, ts = 13, dkpmutation = -5, note="test123"});
table:UpsertRecordWithKey('test', {b = 15, a =6,  ts = 13, note="cool stuff"});
--local searchResult = table:SearchRange(10, 15, "b");

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
print(Database.UUID())


--local records = Database.RetrieveByKeys(data, searchResult)
--
--printtable(records);
