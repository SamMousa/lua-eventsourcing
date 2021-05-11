

local LedgerFactory, _ = LibStub:NewLibrary("EventSourcing/LedgerFactory", 1)
if not LedgerFactory then
    return
end

local Util = LibStub("EventSourcing/Util")
local ListSync = LibStub("EventSourcing/ListSync")
local LogEntry = LibStub("EventSourcing/LogEntry")
local StateManager = LibStub("EventSourcing/StateManager")
local Logger = LibStub("LibLogger")

--[[
Params
  table: table -- Reference to the data, should be a saved variable
  send: function(tableData, distribution, target, progressCallback): void -- function the sync will use to send outgoing data
  sendLargeMessage: function(tableData, distribution, target, progressCallback): void -- function the sync will use to send large messages
  authorizationHandler: function(entry, sender): bool -- Authorization handler, called before sending outgoing entries and before
  committing incoming entries

  registerReceiveHandler: function(receiveCallback: function(message, distribution, sender)): void


Notes
  - Calling library must supply communication that takes care of serializing table typed data for sending across the network
  -




]]--


LedgerFactory.createLedger = function(table, send, registerReceiveHandler, authorizationHandler, sendLargeMessage,
    updateInterval, batchSize, logger)
    Util.assertTable(table, 'table')
    Util.assertFunction(send, 'send')
    Util.assertFunction(registerReceiveHandler, 'registerReceiveHandler')
    Util.assertFunction(sendLargeMessage, 'sendLargeMessage', true)
    Util.assertLogger(logger, 'logger', true)

    if not logger then
        --[[
            If calling code doesn't care about logs neither do we; so we set severity to the highest possible level.
          ]]--
        logger = Logger:New({})
        logger:SetSeverity(Logger.SEVERITY.FATAL)
    end

    local sortedList = LogEntry.sortedList(table)
    local stateManager = StateManager:new(sortedList, logger)
    local listSync = ListSync:new(stateManager, send, registerReceiveHandler, authorizationHandler, sendLargeMessage, logger)

    stateManager:setUpdateInterval(updateInterval or 500)
    stateManager:setBatchSize(batchSize or 50)

    return {
        getSortedList = function()
            return sortedList
        end,
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
            if listSync:transmitViaGuild(entry) then
                -- only commit locally if we are authorized to send
                sortedList:uniqueInsert(entry)
            else
                error("Attempted to submit entries for which you are not authorized")
            end
        end,
        ignoreEntry = function(entry)
            local ignoreEntry = stateManager:createIgnoreEntry(entry)
            if listSync:transmitViaGuild(ignoreEntry, entry) then
                -- only commit locally if we are authorized to send
                sortedList:uniqueInsert(ignoreEntry)
            else
                error("Attempted to submit entries for which you are not authorized")
            end
        end,
        catchup = function(limit)
            stateManager:catchup(limit)
        end,
        reset = function()
            stateManager:reset()
        end,
        addStateRestartListener = function(callback)
            Util.assertFunction(callback, 'callback')
            stateManager:addStateRestartListener(callback)
        end,
        addMutatorFailedListener = function(callback)
            Util.assertFunction(callback, 'callback')
            stateManager:addMutatorFailedListener(callback)
        end,
        addSyncStateChangedListener = function(callback)
            Util.assertFunction(callback, 'callback')
            listSync:addSyncStateChangedListener(callback)
        end,
        addStateChangedListener = function(callback)
            Util.assertFunction(callback, 'callback')
            -- We hide the state manager from this callback
            --
            stateManager:addStateChangedListener(function(_)
                local lag, uncommitted = stateManager:lag()
                return callback(lag, uncommitted, stateManager:stateHash())
            end)
        end,
        enableSending = function ()
            listSync:enableSending()
        end,
        disableSending = function()
            listSync:disableSending()
        end,
        getPeerStatus = function()
            return listSync:getPeerStatus()
        end,
        requestPeerStatusFromRaid = function()
            listSync:requestPeerStatusFromRaid()
        end,
        requestPeerStatusFromGuild = function()
            listSync:requestPeerStatusFromGuild()
        end



    }
end
