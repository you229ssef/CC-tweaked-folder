local detector = peripheral.wrap("top")
if not detector then error("No Environment Detector on top!") end

local logFile = "env_log.txt"
local function log(msg)
    local f = fs.open(logFile, "a")
    f.writeLine(msg)
    f.close()
    print(msg)
end

-- Clear old log
if fs.exists(logFile) then fs.delete(logFile) end

log("=== STARTED ===")

-- Startup test: pulse both sides so you know redstone works
log("Testing redstone...")
redstone.setOutput("left", true)
sleep(0.5)
redstone.setOutput("left", false)
sleep(0.5)
redstone.setOutput("right", true)
sleep(0.5)
redstone.setOutput("right", false)
log("Redstone test done. Left then Right should have blinked.")

local wasNight = false
local wasStormy = false

while true do
    local ok1, time = pcall(detector.getTime)
    local ok2, raining = pcall(detector.isRaining)
    local ok3, thunder = pcall(detector.isThunder)

    if not ok1 then log("getTime ERROR: " .. tostring(time)) end
    if not ok2 then log("isRaining ERROR: " .. tostring(raining)) end
    if not ok3 then log("isThunder ERROR: " .. tostring(thunder)) end

    if ok1 and ok2 and ok3 then
        local night = (time >= 12000 or time < 1000)
        local stormy = raining or thunder

        log(string.format("Time:%s Night:%s Rain:%s Thunder:%s", tostring(time), tostring(night), tostring(raining), tostring(thunder)))

        if night and not wasNight then
            log(">>> NIGHT DETECTED - Pulsing LEFT")
            redstone.setOutput("left", true)
            sleep(1)
            redstone.setOutput("left", false)
        end

        if stormy and not wasStormy then
            log(">>> STORM DETECTED - Pulsing RIGHT")
            redstone.setOutput("right", true)
            sleep(1)
            redstone.setOutput("right", false)
        end

        wasNight = night
        wasStormy = stormy
    end

    sleep(5)
end
