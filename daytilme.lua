--[[
  Environment Detector Redstone Controller
  Requires: Advanced Peripherals (Environment Detector)
  
  Left  -> 1s pulse when night starts
  Right -> 1s pulse when rain or thunder starts
]]

local CHECK_INTERVAL = 5  -- seconds between checks
local PULSE_DURATION = 1  -- seconds the signal stays high

-- Find the Environment Detector
local detector = peripheral.find("environmentDetector")
if not detector then
    error("No Environment Detector found! Attach one to the computer.")
end

local wasNight = false
local wasRaining = false

local function pulse(side, reason)
    print(string.format("[%s] Pulsing %s for %ds", reason, side, PULSE_DURATION))
    redstone.setOutput(side, true)
    sleep(PULSE_DURATION)
    redstone.setOutput(side, false)
end

print("Environment Detector Redstone Controller")
print("Left = Night | Right = Rain/Storm")
print("Running...")

while true do
    local time = detector.getTime()      -- "day", "night", etc.
    local raining = detector.isRaining() -- boolean
    local thunder = detector.isThunder() -- boolean

    local isNight = (time == "night")
    local isStormy = raining or thunder

    -- Pulse LEFT when night begins
    if isNight and not wasNight then
        pulse("left", "Night started")
    end

    -- Pulse RIGHT when rain/thunder begins
    if isStormy and not wasRaining then
        pulse("right", "Rain/Storm started")
    end

    wasNight = isNight
    wasRaining = isStormy

    sleep(CHECK_INTERVAL)
end
