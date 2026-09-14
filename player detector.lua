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

    local ok, players = pcall(pd.getOnlinePlayers)

    if not ok then
        print("getOnlinePlayers() failed: " .. tostring(players))
        break
    elseif #players == 0 then
        print("No players online")
    else
        for _, name in ipairs(players) do
            local ok2, pos = pcall(pd.getPlayerPos, name)
            if ok2 and pos then
                print(("%s: X=%d Y=%d Z=%d [%s]")
                    :format(name, pos.x, pos.y, pos.z, pos.dimension))
            else
                print(name .. ": (no data)")
            end
        end
    end

    print("==========================")
    sleep(5)
end
