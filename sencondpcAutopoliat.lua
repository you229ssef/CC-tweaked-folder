-- ============================================
-- X2 SLAVE v5.0 — 4-Channel Controller
-- Receives rednet, drives redstone
-- ============================================

-- Configure sides to match your build
local MODEM_SIDE = "top"      -- Wireless modem
local LEFT_SIDE = "front"     -- Left thruster
local RIGHT_SIDE = "right"    -- Right thruster
local ALT_SIDE = "left"       -- Altitude (REVERSED)
local ENGINE_SIDE = "back"    -- Central engine (optional)

-- Colors
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
print("  X2 SLAVE v5.0  ")
term.setTextColor(C_DIM)
print(string.rep("\140", 20))
term.setTextColor(C_TEXT)
print("Listening...")

while true do
    local id, msg = rednet.receive()
    if type(msg) == "table" then
        
        -- LEFT / RIGHT thrusters (direct)
        if msg.left ~= nil then
            rs.setOutput(LEFT_SIDE, msg.left)
        end
        if msg.right ~= nil then
            rs.setOutput(RIGHT_SIDE, msg.right)
        end
        
        -- ALTITUDE (inverted: 0 logical = max thrust, 15 = off)
        -- We receive logical value (6=hover) and invert for hardware
        if msg.altitude ~= nil then
            local out = 15 - msg.altitude
            rs.setOutput(ALT_SIDE, out)
        end
        
        -- ENGINE (central thruster, direct)
        if msg.engine ~= nil then
            rs.setOutput(ENGINE_SIDE, msg.engine)
        end
        
        -- Display
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
