-- coords.lua
local pd = peripheral.find("player_detector")

while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Player Coordinates ===")

    local players = pd.getPlayers()

    if #players == 0 then
        print("No players in range")
    else
        for _, name in ipairs(players) do
            local ok, pos = pcall(pd.getPlayerPos, name)
            if ok and pos then
                print(("%s: X=%d Y=%d Z=%d [%s]")
                    :format(name, pos.x, pos.y, pos.z, pos.dimension))
            end
        end
    end

    print("==========================")
    sleep(5) -- refresh every 5 seconds
end
