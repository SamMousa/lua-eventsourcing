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


function updateTestFrameStatus(s1, s2, s3, s4, s5)
    display:SetText(string.format(template, s1, s2, s3, s4, s5))
end
