-- ============================================
-- X2 SLAVE v5.3 — Fixed Analog Output
-- Ender Modem on TOP
-- ============================================

local MODEM_SIDE = "top"
local LEFT_SIDE = "front"
local RIGHT_SIDE = "right"
local ALT_SIDE = "left"
local ENGINE_SIDE = "back"

local C_HEAD = colors.cyan
local C_OK = colors.lime
local C_WARN = colors.yellow
local C_TEXT = colors.white
local C_DIM = colors.lightGray

rednet.open(MODEM_SIDE)

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1,1)
term.setTextColor(C_HEAD)
print("  X2 SLAVE v5.3  ")
term.setTextColor(C_DIM)
print(string.rep("\140", 20))
term.setTextColor(C_TEXT)
print("Listening...")

while true do
    local id, msg = rednet.receive()
    if type(msg) == "table" then
        if msg.left ~= nil then
            rs.setAnalogOutput(LEFT_SIDE, msg.left)
        end
        if msg.right ~= nil then
            rs.setAnalogOutput(RIGHT_SIDE, msg.right)
        end
        if msg.altitude ~= nil then
            local out = 15 - msg.altitude
            rs.setAnalogOutput(ALT_SIDE, out)
        end
        if msg.engine ~= nil then
            rs.setAnalogOutput(ENGINE_SIDE, msg.engine)
        end
        
        term.setCursorPos(1, 5)
        term.setTextColor(C_OK)
        write("L:")
        term.setTextColor(C_TEXT)
        write(string.format("%2d", msg.left or 0))
        term.setTextColor(C_OK)
        write(" R:")
        term.setTextColor(C_TEXT)
        write(string.format("%2d", msg.right or 0))
        
        term.setCursorPos(1, 6)
        term.setTextColor(C_WARN)
        write("ALT:")
        term.setTextColor(C_TEXT)
        write(string.format("%2d", msg.altitude or 0))
        term.setTextColor(C_DIM)
        write(" (out:")
        write(string.format("%2d", 15 - (msg.altitude or 0)))
        write(")")
        
        term.setCursorPos(1, 7)
        term.setTextColor(C_DIM)
        write("ENG:")
        term.setTextColor(C_TEXT)
        print(string.format("%2d", msg.engine or 0))
    end
end
