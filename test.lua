if (GetTime == nil) then
    require "./Database"
    require "./wow"
end
error('disabled')
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


local defaultCharset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
function string.random(length, alternativeCharset)
    local charset = alternativeCharset or defaultCharset
    local charsetLength = string.len(charset)
    local result = ""
    while string.len(result) < length do
        local i = math.random(1, charsetLength)
        result = result .. charset.sub(charset, i, i)
    end
    return result
end

function string.guid()
    local hex = '0123456789abcdef'
    return table.concat({
        string.random(8, hex),
        string.random(4, hex),
        string.random(4, hex),
        string.random(4, hex),
        string.random(12, hex),
    }, '-')
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
Profile:start('Creating data')
for i = 1, 1000 * 1000 do
    local uuid = Database.UUID()
--    data[uuid] = {
--        player = string.guid(),
--        a = 15,
--        i = i,
--        ts = Database.time()
--    }
    data[uuid] = {
        server = math.random(9999),
        player = math.random(2147483647),
        ts = Database.time()
    }
end

Profile:stop('Creating data')
Profile:start('Creating table')
local table = Database.Table:new(data);
globalTable = table
local guid = math.random(1, 2^31 - 1)
table:InsertRecordWithUUID({b = 15, ts = 13, player = guid});
local uuid = table:InsertRecordWithUUID({b = 15, ts = 13, player = guid});
Profile:start('Creating indices')
table:AddIndex("a")
table:AddIndex("i")
table:AddIndex("player");
Profile:stop('Creating indices')
Profile:stop('Creating table')

Profile:start('Search 1')
printtable(table:SearchAllByValue(guid, "player"))
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
