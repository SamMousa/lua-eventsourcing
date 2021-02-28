--
-- Created by IntelliJ IDEA.
-- User: Sam
-- Date: 22-2-2021
-- Time: 22:42
-- To change this template use File | Settings | File Templates.
--

local frame, events = CreateFrame("Frame"), {}

local display = CreateFrame("SimpleHTML", nil, UIParent)
local template = [[
    <html>
    <body>
    <h1>Database status</h1><br/>
    <p>%s</p><br/>
    <p>%s</p><br/>
    <p>%s</p><br/>
    <p>%s</p><br/>
    <p>%s</p><br/>
    </body></html>
]]

display:SetFont('Fonts\\FRIZQT__.TTF', 20)
display:SetPoint("CENTER", UIParent)
display:SetWidth(200)
display:SetHeight(200)
display:Show()
display:RegisterForDrag("Leftbutton")
display:EnableMouse(true)
display:SetMovable(true)
display:SetScript("OnDragStart", function(self) self:StartMoving() end)
display:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
aceComm = LibStub("AceComm-3.0")
aceSerializer = LibStub("AceSerializer-3.0")
samtest = display

function updateTestFrameStatus(s1, s2, s3, s4, s5)
    display:SetText(string.format(template, s1, s2, s3, s4, s5))
end


frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        events.pureComm( ...)
    end
end);



function events.aceComm(prefix, message, type, sender)
    print("Received ace addon message with prefix " .. prefix .. " of length " .. string.len(message) .. " from "  .. (sender or "unkown"))
--    print(message)

end

function events.pureComm(prefix, message, type, sender)
    print("Received pure addon message with prefix " .. prefix .. " of length " .. string.len(message) .. " from "  .. (sender or "unkown"))
--    print(message)

end

frame:RegisterEvent('CHAT_MSG_ADDON')

aceComm:RegisterComm("samtest", function(prefix, message, type, sender)
    if (prefix == "db_log_entry") then
        lastMessage = aceSerializer:DeSerialize(message)
    end
end)
