-- ============================================
-- X2 AUTOPILOT v4.1 — Drag Assist Edition
-- Main Computer (next to typewriter)
-- Controls: Left/Right redstone + rednet (engine, altitude, 2x drag)
-- ============================================

-- ============ CONFIG ============
local WAYPOINT_FILE = "x2_waypoints.txt"
local TICK_RATE = 0.05
local MAX_SPEED = 500
local LOOKAHEAD_SECONDS = 2.5
local YAW_KP = 2.5
local SPEED_KP = 0.08
local ARRIVE_DIST = 20

-- Sides
local LEFT_SIDE = "left"
local RIGHT_SIDE = "right"
local MODEM_SIDE = "top"

-- Drag stabilizer config
local DRAG_ENABLED = true       -- Set false to disable
local DRAG_BASE = 4             -- Weak-mid signal (0-15)
local DRAG_MAX = 7              -- Max drag during hard turns
local DRAG_KP = 0.8             -- How much drag scales with turn rate

-- Altitude (reversed on slave: 0=max, 15=off. 6 = moderate hover)
local ALT_BASE = 6
local ALT_MIN = 4
local ALT_MAX = 8
-- =================================

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
local targetSpeed = 0

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
    if d > 2000 then return 500
    elseif d > 1000 then return 400
    elseif d > 500 then return 300
    elseif d > 250 then return 200
    elseif d > 100 then return 100
    elseif d > 50 then return 50
    elseif d > 20 then return 25
    else return 10 end
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

-- ========= REDSTONE / REDNET ==

function setTurn(diff)
    local base = 8
    local L = clamp(base - diff, 0, 15)
    local R = clamp(base + diff, 0, 15)
    rs.setOutput(LEFT_SIDE, math.floor(L))
    rs.setOutput(RIGHT_SIDE, math.floor(R))
end

function setEngine(eng)
    rednet.broadcast({engine=clamp(math.floor(eng), 0, 15)})
end

function setAltitude(alt)
    local out = clamp(math.floor(alt), ALT_MIN, ALT_MAX)
    rednet.broadcast({altitude=out})
end

-- Drag stabilizers: weak-mid signals to reduce drift during turns
-- diff > 0 = turning right, so we send drag to left side (or vice versa)
-- FLIP THE SIGNS if your build works opposite
function setDrag(diff)
    if not DRAG_ENABLED then
        rednet.broadcast({dragL=0, dragR=0})
        return
    end
    local dragVal = clamp(math.abs(diff) * DRAG_KP, 0, DRAG_MAX - DRAG_BASE) + DRAG_BASE
    dragVal = math.floor(dragVal)
    
    if diff > 0.5 then
        -- Turning right: drag on left to pivot
        rednet.broadcast({dragL=dragVal, dragR=0})
    elseif diff < -0.5 then
        -- Turning left: drag on right to pivot
        rednet.broadcast({dragL=0, dragR=dragVal})
    else
        -- Straight: no drag
        rednet.broadcast({dragL=0, dragR=0})
    end
end

function allStop()
    rs.setOutput(LEFT_SIDE, 0)
    rs.setOutput(RIGHT_SIDE, 0)
    rednet.broadcast({engine=0, altitude=15, dragL=0, dragR=0})
end

-- ========= AUTOPILOT ===========

function autopilotTick()
    if not navActive or not targetWP then return end
    
    local dx = targetWP.x - pos.x
    local dz = targetWP.z - pos.z
    local dist = math.sqrt(dx*dx + dz*dz)
    
    if dist < ARRIVE_DIST then
        navActive = false
        targetWP = nil
        allStop()
        statusText = "ARRIVED"
        return
    end
    
    targetSpeed = getSpeedForDist(dist)
    
    local lookahead = targetSpeed * LOOKAHEAD_SECONDS
    local aimX, aimZ
    if dist < lookahead then
        aimX, aimZ = targetWP.x, targetWP.z
        statusText = "FINAL APPROACH"
    else
        local r = lookahead / dist
        aimX = pos.x + dx * r
        aimZ = pos.z + dz * r
        if dist > 1000 then statusText = "CRUISE"
        else statusText = "APPROACH" end
    end
    
    local tBearing = math.atan2(aimX - pos.x, -(aimZ - pos.z))
    local err = normAngle(tBearing - heading)
    
    local diff = clamp(err * YAW_KP, -6, 6)
    setTurn(diff)
    setDrag(diff)  -- <-- NEW: sends weak-mid drag signals
    
    local sErr = targetSpeed - speed
    local eng = clamp(7 + sErr * SPEED_KP, 0, 15)
    setEngine(eng)
    
    local aErr = targetWP.y - pos.y
    local alt = clamp(ALT_BASE + aErr * 0.3, ALT_MIN, ALT_MAX)
    setAltitude(alt)
end

-- ============ UI ===============

function drawMenu()
    term.clear(); term.setCursorPos(1,1)
    print("=== X2 AUTOPILOT v4.1 ===")
    print("SPD: " .. math.floor(speed) .. "  HDG: " .. string.format("%.1f", math.deg(heading)))
    print(string.format("POS: %d %d %d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)))
    print(string.rep("-", 34))
    
    for i = 1, math.min(6, #waypoints) do
        local wp = waypoints[i]
        local d = math.floor(dist2D(pos.x, pos.z, wp.x, wp.z))
        local line = (i==selected and "> " or "  ") .. i .. "." .. wp.name
        line = line .. string.rep(" ", 22 - #line) .. d .. "m"
        print(line)
    end
    
    print(string.rep("-", 34))
    print("[UP/DOWN] Select  [ENTER] Fly")
    print("[A] Add Here  [N] Add Named")
    print("[D] Delete  [Q] Quit")
end

function drawNav()
    term.clear(); term.setCursorPos(1,1)
    print("=== NAVIGATING ===")
    if targetWP then
        print("TO: " .. targetWP.name)
        print(string.format("DEST: %d %d %d", targetWP.x, targetWP.y, targetWP.z))
    end
    print(string.format("AT:   %d %d %d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)))
    local d = targetWP and math.floor(dist2D(pos.x, pos.z, targetWP.x, targetWP.z)) or 0
    print("DIST: " .. d .. "m  SPD: " .. math.floor(speed) .. "/" .. targetSpeed)
    print("STAT: " .. statusText)
    print(string.rep("-", 34))
    print("[Q] Abort  [H] Hover Here")
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
            term.clear(); term.setCursorPos(1,1)
            print("=== ADD WAYPOINT ===")
            write("Name: "); local name = read()
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
term.clear(); term.setCursorPos(1,1)
print("X2 AUTOPILOT v4.1")
print("Drag assist: ON")
print("Opening rednet on " .. MODEM_SIDE .. "...")
print("Press any key to start...")
os.pullEvent("key")

loadWP()
parallel.waitForAll(mainLoop, gpsThread)

term.clear()
print("Autopilot shutdown.")
allStop()
