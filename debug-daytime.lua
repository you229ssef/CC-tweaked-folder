--[[ DEBUG SCRIPT - Run this and tell me the output ]]

print("=== PERIPHERAL SCAN ===")
local names = peripheral.getNames()
for _, name in ipairs(names) do
    local p = peripheral.wrap(name)
    local pType = peripheral.getType(name)
    print(string.format("Side: %s | Type: %s", name, tostring(pType)))
    
    -- Try to list methods if available
    if p and p.getDocs then
        local methods = p.getDocs()
        print("  Methods: " .. textutils.serialize(methods))
    end
end

print("\n=== TRYING TOP ===")
local det = peripheral.wrap("top")
if det then
    print("Wrapped successfully!")
    
    -- Try each method with error catching
    local function try(name, ...)
        local ok, result = pcall(det[name], ...)
        if ok then
            print(string.format("  %s() = %s", name, textutils.serialize(result)))
        else
            print(string.format("  %s() FAILED: %s", name, tostring(result)))
        end
    end
    
    try("getTime")
    try("getDimension")
    try("getDimensionProvider")
    try("isRaining")
    try("isThunder")
    try("isSunny")
    try("getBiome")
    try("getMoonId")
    
    -- Try some alternate method names just in case
    try("getWeather")
    try("isStorming")
    try("getDimensionName")
else
    print("peripheral.wrap('top') returned nil!")
end

print("\n=== REDSTONE TEST ===")
print("Turning LEFT on for 2 seconds...")
redstone.setOutput("left", true)
sleep(2)
redstone.setOutput("left", false)
print("Done. Did you see anything?")

print("\n=== WAITING 10s, printing time every second ===")
for i = 1, 10 do
    if det then
        local ok, t = pcall(det.getTime)
        if ok then
            print(string.format("  Time: %s", tostring(t)))
        else
            print("  getTime error: " .. tostring(t))
        end
    end
    sleep(1)
end
print("=== END DEBUG ===")
