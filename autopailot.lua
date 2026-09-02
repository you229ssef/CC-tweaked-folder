-- ============================================
-- X2 AUTOPILOT v5.0 — Tight Space Edition
-- Main computer: ONLY Ender Modem on back
-- No redstone. All control via rednet.
-- ============================================

-- ============ CONFIG ============
local MODEM_SIDE = "back"
local WAYPOINT_FILE = "x2_waypoints.txt"
local TICK_RATE = 0.05

-- Speeds (DELIBERATELY LOW for momentum control)
local CRUISE_SPEED = 80
local APPROACH_SPEED = 40
local FINAL_SPEED = 15
local ARRIVE_DIST = 60
local BRAKE_DIST = 300

-- Steering
local LOOKAHEAD = 3.0
local YAW_KP = 2.0

-- Altitude logic (6 = moderate hover)
local ALT_HOVER = 6
local ALT_MIN = 3
local ALT_MAX = 9
-- =================================

-- Colors
local C_HEAD = colors.cyan
local C_OK = colors.lime
local C_WARN = colors.yellow
local C_ERR = colors.red
local C_SEL = colors.pink
local C_TEXT = colors.white
local C_DIM = colors.lightGray
local C_DIST = colors.lightBlue

-- State
local waypoints = {}
local selected = 1
local navActive = false
local targetWP = nil
local mode = "MENU"
local running = true
local statusText = "IDLE"

local pos = {x=0, y=120, z=0}
local heading = 0
local speed = 0

-- ========= UTILITIES ===========

function loadWP()
    if fs.exists(WAYPOINT_FILE) then
        local f = fs.open(WAYPOINT_FILE, "r")
        waypoints = textutils.unserialize(f.readAll()) or {}
        f.close()
    else
        waypoints = {{name="Home", x=0, y=120, z=0}}
        saveWP()
    end
end

function saveWP()
    local f = fs.open(WAYPOINT_FILE, "w")
    f.write(textutils.serialize(waypoints))
    f.close()
end

function normAngle(a)
    return (a + math.pi) % (2 * math.pi) - math.pi
end

function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function dist2D(x1,z1,x2,z2)
    return math.sqrt((x2-x1)^2 + (z2-z1)^2)
end

function getSpeedForDist(d)
    if d > BRAKE_DIST then return CRUISE_SPEED
    elseif d > 150 then return APPROACH_SPEED
    elseif d > ARRIVE_DIST then return FINAL_SPEED
    else return 5 end
end

-- ========= GPS THREAD ==========

local lastX, lastZ = 0, 0
local lastTime = os.clock()

function gpsThread()
    while running do
        local x, y, z = gps.locate(2)
        if x then
            local now = os.clock()
            local dt = now - lastTime
            if dt > 0 and (x ~= lastX or z ~= lastZ) then
                heading = math.atan2(x - lastX, -(z - lastZ))
                speed = dist2D(lastX, lastZ, x, z) / dt
                lastX, lastZ = x, z
                lastTime = now
            end
            pos.x, pos.y, pos.z = x, y, z
        end
        sleep(0.1)
    end
end

-- ========= REDNET CONTROL ======

function sendControls(left, right, altitude, engine)
    rednet.broadcast({
        left = clamp(math.floor(left), 0, 15),
        right = clamp(math.floor(right), 0, 15),
        altitude = clamp(math.floor(altitude), ALT_MIN, ALT_MAX),
        engine = clamp(math.floor(engine), 0, 15)
    })
end

function allStop()
    rednet.broadcast({left=0, right=0, altitude=15, engine=0})
    -- altitude=15 logical = OFF (slave inverts to 0 output)
end

-- ========= AUTOPILOT ===========

function autopilotTick()
    if not navActive or not targetWP then return end
    
    local dx = targetWP.x - pos.x
    local dz = targetWP.z - pos.z
    local dist = math.sqrt(dx*dx + dz*dz)
    
    -- Overshoot detection: if we're moving away from target, turn around
    local tBearing = math.atan2(dx, -dz)
    local faceErr = math.abs(normAngle(tBearing - heading))
    if dist < ARRIVE_DIST and faceErr > math.pi * 0.7 then
        -- We're past it and facing away. Just stop and let it coast/drift.
        sendControls(0, 0, ALT_HOVER, 0)
        statusText = "OVERSHOOT — COASTING"
        if dist > ARRIVE_DIST * 3 then
            -- Way overshot. Turn around and come back slowly.
            targetWP = {name=targetWP.name, x=targetWP.x, y=targetWP.y, z=targetWP.z}
            statusText = "TURNING AROUND"
        end
        return
    end
    
    -- Arrival
    if dist < ARRIVE_DIST and speed < 20 then
        navActive = false
        targetWP = nil
        allStop()
        statusText = "ARRIVED"
        return
    end
    
    -- Speed profile (momentum-aware)
    local targetSpeed = getSpeedForDist(dist)
    
    -- Lookahead steering
    local lookahead = targetSpeed * LOOKAHEAD
    local aimX, aimZ
    if dist < lookahead then
        aimX, aimZ = targetWP.x, targetWP.z
        statusText = "FINAL"
    else
        local r = lookahead / dist
        aimX = pos.x + dx * r
        aimZ = pos.z + dz * r
        if dist > BRAKE_DIST then statusText = "CRUISE"
        elseif dist > 150 then statusText = "BRAKING"
        else statusText = "APPROACH" end
    end
    
    -- Target bearing vs current heading
    local aimBearing = math.atan2(aimX - pos.x, -(aimZ - pos.z))
    local err = normAngle(aimBearing - heading)
    
    -- Differential thrust
    local diff = clamp(err * YAW_KP, -6, 6)
    local base = targetSpeed / 500 * 15  -- scale to 0-15
    base = clamp(base, 2, 12)
    
    local left = base + diff
    local right = base - diff
    
    -- Altitude hold
    local altErr = targetWP.y - pos.y
    local altitude = clamp(ALT_HOVER + altErr * 0.25, ALT_MIN, ALT_MAX)
    
    -- Engine (average for a central thruster if you have one)
    local engine = (left + right) / 2
    
    sendControls(left, right, altitude, engine)
end

-- ============ COLOR UI =========

function drawMenu()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Header
    term.setCursorPos(1,1)
    term.setTextColor(C_HEAD)
    print("  \187  X2 AUTOPILOT v5.0  \171  ")
    term.setTextColor(C_DIM)
    print(string.rep("\140", 26))
    
    -- Status line
    term.setCursorPos(1,3)
    term.setTextColor(C_TEXT)
    write("SPD: ")
    term.setTextColor(C_OK)
    write(string.format("%3d", math.floor(speed)))
    term.setTextColor(C_TEXT)
    write("  HDG: ")
    term.setTextColor(C_DIST)
    print(string.format("%3.0f\186", math.deg(heading)))
    
    term.setTextColor(C_DIM)
    write("POS ")
    term.setTextColor(C_TEXT)
    print(string.format("%d %d %d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)))
    
    term.setTextColor(colors.gray)
    print(string.rep("\143", 26))
    
    -- Waypoints
    for i = 1, math.min(5, #waypoints) do
        local wp = waypoints[i]
        local d = math.floor(dist2D(pos.x, pos.z, wp.x, wp.z))
        term.setCursorPos(1, 6 + i)
        if i == selected then
            term.setTextColor(C_SEL)
            write(" > ")
        else
            term.setTextColor(C_DIM)
            write("   ")
        end
        term.setTextColor(C_TEXT)
        write(string.sub(wp.name, 1, 14))
        term.setCursorPos(18, 6 + i)
        term.setTextColor(C_DIST)
        print(string.format("%5dm", d))
    end
    
    -- Footer
    term.setCursorPos(1, 12)
    term.setTextColor(colors.gray)
    print(string.rep("\143", 26))
    term.setTextColor(C_DIM)
    print("[\181/\184]Sel [\170]Fly [A]Here")
    print("[N]Add [D]Del [Q]Quit")
end

function drawNav()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setCursorPos(1,1)
    term.setTextColor(C_HEAD)
    print("  \187  NAVIGATING  \171  ")
    term.setTextColor(colors.gray)
    print(string.rep("\140", 26))
    
    if targetWP then
        term.setTextColor(C_WARN)
        term.setCursorPos(1,3)
        print("TO: " .. string.sub(targetWP.name, 1, 18))
        term.setTextColor(C_DIM)
        print(string.format("DEST: %d %d %d", targetWP.x, targetWP.y, targetWP.z))
    end
    
    term.setTextColor(C_TEXT)
    print(string.format("AT:   %d %d %d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)))
    
    local d = targetWP and math.floor(dist2D(pos.x, pos.z, targetWP.x, targetWP.z)) or 0
    term.setTextColor(C_DIST)
    write("DIST: " .. string.format("%4d", d) .. "m  ")
    term.setTextColor(C_OK)
    print("SPD: " .. math.floor(speed))
    
    term.setTextColor(C_WARN)
    print("STAT: " .. statusText)
    
    term.setCursorPos(1, 10)
    term.setTextColor(colors.gray)
    print(string.rep("\143", 26))
    term.setTextColor(C_DIM)
    print("[Q]Abort  [H]Hover")
end

-- ========= INPUT ===============

function menuInput()
    while mode == "MENU" and running do
        local e, key = os.pullEvent("key")
        if key == keys.up then
            selected = math.max(1, selected - 1)
        elseif key == keys.down then
            selected = math.min(#waypoints, selected + 1)
        elseif key == keys.enter then
            if waypoints[selected] then
                targetWP = waypoints[selected]
                navActive = true
                mode = "NAV"
            end
        elseif key == keys.a then
            local x,y,z = gps.locate(2)
            if x then
                table.insert(waypoints, {name="WP"..#waypoints+1, x=x, y=y, z=z})
                saveWP()
            end
        elseif key == keys.n then
            term.setBackgroundColor(colors.black)
            term.clear()
            term.setTextColor(C_HEAD)
            print("=== ADD WAYPOINT ===")
            term.setTextColor(C_TEXT)
            write("Name: ")
            term.setTextColor(C_OK)
            local name = read()
            term.setTextColor(C_TEXT)
            write("X: "); local nx = tonumber(read())
            write("Y: "); local ny = tonumber(read())
            write("Z: "); local nz = tonumber(read())
            if nx and ny and nz then
                table.insert(waypoints, {name=name, x=nx, y=ny, z=nz})
                saveWP()
            end
        elseif key == keys.d then
            if #waypoints > 1 then
                table.remove(waypoints, selected)
                selected = math.min(selected, #waypoints)
                saveWP()
            end
        elseif key == keys.q then
            running = false
        end
        drawMenu()
    end
end

function navInput()
    while mode == "NAV" and running do
        local e, key = os.pullEvent("key")
        if key == keys.q then
            navActive = false; targetWP = nil; allStop()
            mode = "MENU"; statusText = "ABORTED"
        elseif key == keys.h then
            targetWP = {name="HOLD", x=pos.x, y=pos.y, z=pos.z}
            statusText = "HOVER"
        end
    end
end

-- ========= MAIN ================

function mainLoop()
    while running do
        if mode == "MENU" then
            drawMenu(); menuInput()
        elseif mode == "NAV" then
            drawNav()
            parallel.waitForAny(
                function()
                    while navActive do
                        autopilotTick(); drawNav(); sleep(TICK_RATE)
                    end
                end,
                navInput
            )
            mode = "MENU"
        end
        sleep(0.1)
    end
end

-- ========= BOOT ================

rednet.open(MODEM_SIDE)
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1,1)
term.setTextColor(C_HEAD)
print("X2 AUTOPILOT v5.0")
term.setTextColor(C_TEXT)
print("Modem: " .. MODEM_SIDE)
print("Cruise: " .. CRUISE_SPEED .. " (capped)")
print("")
term.setTextColor(C_DIM)
print("Press any key...")
os.pullEvent("key")

loadWP()
parallel.waitForAll(mainLoop, gpsThread)

term.setBackgroundColor(colors.black)
term.clear()
term.setTextColor(C_OK)
print("Shutdown.")
allStop()
