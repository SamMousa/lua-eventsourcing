

local LedgerFactory, _ = LibStub:NewLibrary("EventSourcing/LedgerFactory", 1)
if not LedgerFactory then
    return
end

local ListSync = LibStub("EventSourcing/ListSync")
local LogEntry = LibStub("EventSourcing/LogEntry")
local StateManager = LibStub("EventSourcing/StateManager")



LedgerFactory.createLedger = function(table, send, registerReceiveHandler, authorizationHandler)
    -- Support calls via : and .
    if (self ~= nil) then
        table = self
    end
    if type(table) ~= "table" then
        error("Must pass a table to LedgerFactory")
    end

    local sortedList = LogEntry.sortedList(table)
    local stateManager = StateManager:new(sortedList)
    local listSync = ListSync:new(stateManager, send, registerReceiveHandler, authorizationHandler)

    stateManager:setUpdateInterval(500)
    stateManager:setBatchSize(5)

    return {
        getListSync = function()
            return listSync
        end,
        getStateManager = function()
            return stateManager
        end,
        registerMutator = function(metatable, mutatorFunc)
            stateManager:registerHandler(metatable, mutatorFunc)
        end,
        submitEntry = function(entry)
            return sortedList:uniqueInsert(entry)
        end,
        reset = function()
            stateManager:reset()
        end,
        addStateChangedListener = function(callback)
            -- We hide the state manager from this callback
            --
            stateManager:addStateChangedListener(function(stateManager)
                local lag, uncommitted = stateManager:lag()
                return callback(lag, uncommitted)
            end)
        end,
        enableSending = function ()
            listSync:enableSending()
        end,
        disableSending = function()
            listSync:disableSending()
        end



    }
end
