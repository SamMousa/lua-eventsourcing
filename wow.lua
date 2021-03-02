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
    table.insert(tickers, callback)
end

function C_Timer.startEventLoop()
    if os.execute ~= nil then
        print("Starting custom event loop to mimic WOW C_Timer tickers")
        while os.execute("sleep 1") == 0 do
            io.write('.')
            io.flush()
            for _, callback in ipairs(tickers) do
                callback()
            end

        end
        print("\nEvent loop stopped")
    end
end
