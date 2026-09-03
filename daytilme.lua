--[[
  Environment Detector Redstone Controller
  Detector must be placed ON TOP of the computer.
  
  Left  -> 1s pulse when night starts
  Right -> 1s pulse when rain or thunder starts
]]

local CHECK_INTERVAL = 5
local PULSE_DURATION = 1

-- Explicitly wrap the detector on top
local detector = peripheral.wrap("top")
if not detector then
    error("No Environment Detector found on top! Place it on top of the computer.")
end

local wasNight = false
local wasRaining = false

local function pulse(side, reason)
    print(string.format("[%s] Pulsing %s for %ds", reason, side, PULSE_DURATION))
    redstone.setOutput(side, true)
    sleep(PULSE_DURATION)
    redstone.setOutput(side, false)
end

print("Environment Detector on top detected.")
print("Left = Night | Right = Rain/Storm")
print("Running...")

while true do
    local time = detector.getTime()
    local raining = detector.isRaining()
    local thunder = detector.isThunder()

    local isNight = (time == "night")
    local isStormy = raining or thunder

    if isNight and not wasNight then
        pulse("left", "Night started")
    end

    if isStormy and not wasRaining then
        pulse("right", "Rain/Storm started")
    end

    wasNight = isNight
    wasRaining = isStormy

    sleep(CHECK_INTERVAL)
end
