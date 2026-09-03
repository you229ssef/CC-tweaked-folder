--[[
  Environment Detector Redstone Controller
  Detector on TOP of the computer.
  
  Left  -> 1s pulse when night starts
  Right -> 1s pulse when rain or thunder starts
]]

local CHECK_INTERVAL = 5
local PULSE_DURATION = 1

local detector = peripheral.wrap("top")
if not detector then
    error("No Environment Detector found on top!")
end

local wasNight = false
local wasStormy = false

local function pulse(side, reason)
    print(string.format("[%s] Pulsing %s for %ds", reason, side, PULSE_DURATION))
    redstone.setOutput(side, true)
    sleep(PULSE_DURATION)
    redstone.setOutput(side, false)
end

-- Minecraft time: 0=sunrise, ~6000=noon, ~12000=sunset, ~18000=midnight
local function isNightTime(time)
    return time >= 12000 or time < 1000
end

print("Environment Detector Controller running...")
print("Left = Night | Right = Rain/Storm")

while true do
    local time = detector.getTime()      -- NUMBER (0-24000)
    local raining = detector.isRaining() -- boolean
    local thunder = detector.isThunder() -- boolean

    local night = isNightTime(time)
    local stormy = raining or thunder

    -- Pulse LEFT when night begins
    if night and not wasNight then
        pulse("left", "Night started")
    end

    -- Pulse RIGHT when rain/thunder begins
    if stormy and not wasStormy then
        pulse("right", "Rain/Storm started")
    end

    wasNight = night
    wasStormy = stormy

    sleep(CHECK_INTERVAL)
end
