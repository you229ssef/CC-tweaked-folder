local detector = peripheral.wrap("top")
if not detector then error("No Environment Detector on top!") end

local wasNight = false
local wasStormy = false

local function pulse(side, reason)
    print(string.format("[%s] Pulsing %s", reason, side))
    redstone.setOutput(side, true)
    sleep(1)
    redstone.setOutput(side, false)
end

-- Startup test
print("Testing redstone...")
redstone.setOutput("left", true)
sleep(0.3)
redstone.setOutput("left", false)
sleep(0.3)
redstone.setOutput("right", true)
sleep(0.3)
redstone.setOutput("right", false)
print("Running...")

while true do
    local time = detector.getTime()      -- total world ticks (huge number)
    local daytime = time % 24000         -- convert to 0-24000 cycle
    local raining = detector.isRaining()
    local thunder = detector.isThunder()

    local night = (daytime >= 12000 or daytime < 1000)
    local stormy = raining or thunder

    -- Only log when state changes to avoid spam
    if night ~= wasNight or stormy ~= wasStormy then
        print(string.format("Daytime:%d Night:%s Rain:%s Thunder:%s", daytime, tostring(night), tostring(raining), tostring(thunder)))
    end

    if night and not wasNight then
        pulse("left", "Night started")
    end

    if stormy and not wasStormy then
        pulse("right", "Rain/Storm started")
    end

    wasNight = night
    wasStormy = stormy

    sleep(5)
end
