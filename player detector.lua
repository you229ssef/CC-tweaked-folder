-- coords.lua
local pd = peripheral.wrap("back")

if not pd then
    print("ERROR: Nothing behind the computer!")
    return
end

while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Player Coordinates ===")

    local ok, players = pcall(pd.getPlayers)

    if not ok then
        print("That block isn't a Player Detector!")
        print("Peripheral type: " .. peripheral.getType("back"))
        break
    elseif #players == 0 then
        print("No players in range")
    else
        for _, name in ipairs(players) do
            local ok2, pos = pcall(pd.getPlayerPos, name)
            if ok2 and pos then
                print(("%s: X=%d Y=%d Z=%d [%s]")
                    :format(name, pos.x, pos.y, pos.z, pos.dimension))
            end
        end
    end

    print("==========================")
    sleep(5)
end
