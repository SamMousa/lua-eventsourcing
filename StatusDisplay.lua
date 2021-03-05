local frame, events = CreateFrame("Frame"), {}

local display = CreateFrame("SimpleHTML", nil, UIParent)
local template = [[
    <html>
    <body>
    <h1>Ledger status</h1><br/>
    %s
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


function updateTestFrameStatus(...)
    local status = ""
    for i, v in ipairs({...}) do
        status = status .. string.format('<p>%s</p><br/>', v)
    end
    display:SetText(string.format(template, status))
end
