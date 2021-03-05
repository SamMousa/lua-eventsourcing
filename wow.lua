-- Placeholders for WoW functions

function GetTime()
    return math.floor(os.clock() * 1000000)
end

local start

function GetTimePreciseSec()
    local currentTime = math.floor(os.clock() * 1000000)
    if (start == nil) then
        start = currentTime
    end
    return currentTime - start
end

strmatch = string.match


C_Timer = {
}

local tickers = {}

function C_Timer.NewTicker(interval, callback)
    interval = math.max(1, math.floor(interval))
    if tickers[interval] == nil then
        tickers[interval] = {}
    end
    table.insert(tickers[interval], callback)
end

function C_Timer.startEventLoop()
    if os.execute ~= nil then
        print("Starting custom event loop to mimic WOW C_Timer tickers")
        i = 0
        while os.execute("sleep 1") == 0 do
            io.write('.')
            io.flush()
            for interval, callbacks in pairs(tickers) do
                if (i % interval == 0) then
                    for _, callback in ipairs(tickers[interval]) do
                        callback()
                    end
                end

            end
            i = i + 1
        end
        print("\nEvent loop stopped")
    end
end
