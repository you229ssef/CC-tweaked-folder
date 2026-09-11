-- Run this on your pocket computer
local MAIN_ID = 0  -- <-- replace with your main computer's ID

print("Press [SPACE] = push the button!")

while true do
    local event, key = os.pullEvent("key")

    if key == keys.space then
        rednet.send(MAIN_ID, "press", "redstone_btn")
        print("Click!")
    end
end
