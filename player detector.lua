-- startup
local pd = peripheral.wrap("bottom")
local monitor = peripheral.wrap("right")

if not pd then
    print("ERROR: Nothing under the computer!")
    return
end

if not monitor then
    print("Warning: no monitor on the right, terminal only")
end

local FILENAME = "last_locations.txt"
local lastKnown = {}

-- Load saved locations
if fs.exists(FILENAME) then
    local f = fs.open(FILENAME, "r")
    lastKnown = textutils.unserialize(f.readAll()) or {}
    f.close()
end

local function save()
    local f = fs.open(FILENAME, "w")
    f.write(textutils.serialize(lastKnown))
    f.close()
end

local function draw(target)
    target.clear()
    target.setCursorPos(1, 1)
    target.write("=== Player Coordinates ===\n")

    local names = {}
    for name in pairs(lastKnown) do
        table.insert(names, name)
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local d = lastKnown[name]
        local status = d.online and "ONLINE " or "offline"
        target.write(("%s [%s]: X=%d Y=%d Z=%d (%s)\n")
            :format(name, status, d.x, d.y, d.z, d.dimension))
    end
end

while true do
    local ok, players = pcall(pd.getOnlinePlayers)

    if ok then
        for name in pairs(lastKnown) do
            lastKnown[name].online = false
        end

        for _, name in ipairs(players) do
            local ok2, pos = pcall(pd.getPlayerPos, name)
            if ok2 and pos then
                lastKnown[name] = {
                    x = pos.x, y = pos.y, z = pos.z,
                    dimension = pos.dimension,
                    online = true
                }
            end
        end

        save()
    end

    draw(term)
    if monitor then
        draw(monitor)
    end

    sleep(5)
end
