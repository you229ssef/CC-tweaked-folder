-- Run this on the computer that outputs redstone upward
rednet.open("back")  -- side your wireless/ender modem is on

local PULSE_TIME = 1  -- vanilla button = 1 second
local active = false

print("Listening for button presses...")

while true do
    local id, msg = rednet.receive("redstone_btn")

    if msg == "press" then
        if active then
            -- vanilla buttons ignore presses while already pushed
            print("Button is already pressed, ignoring.")
        else
            active = true
            redstone.setOutput("top", true)
            print("Button pressed! Redstone ON")

            -- sleep in small chunks so we can still listen isn't needed here;
            -- rednet.receive queues messages, so a press during the pulse
            -- will be handled right after
            sleep(PULSE_TIME)

            redstone.setOutput("top", false)
            active = false
            print("Button popped out. Redstone OFF")
        end
    end
end
