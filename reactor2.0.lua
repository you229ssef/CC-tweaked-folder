-- reactor_safety.lua
-- Monitors coolant, waste, and damage
-- Sends Discord alerts + redstone shutdown on danger
-- Place computer next to Fission Reactor LOGIC ADAPTER

-- ==================== CONFIG ====================
local DISCORD_TOKEN      = "MTU0MjE3NjQ1MTcyMDM4ODcwOA.GHldip.87uEC3cb8P-3ilVM8fkPAWcG0qXI3N02pIsmak"      -- Discord bot token
local DISCORD_CHANNEL_ID = "1513023005943664732"     -- Discord channel ID (numbers only)
local MENTION_EVERYONE   = false                       -- Ping @everyone on alerts?

local COOLANT_THRESHOLD = 0.25  -- 25%
local WASTE_THRESHOLD   = 0.60  -- 60%
local DAMAGE_THRESHOLD  = 0.50  -- 50%
local REDSTONE_SIDE     = "back"
local POLL_INTERVAL     = 2
-- ===============================================

-- State tracking (prevents Discord spam)
local lastAlert = nil
local startupMsgSent = false

-- ==================== DISCORD ====================
local function sendDiscord(msg)
    if DISCORD_TOKEN == "YOUR_BOT_TOKEN_HERE" then
        print("[Discord] Not configured")
        return
    end

    local prefix = ""
    if MENTION_EVERYONE and (string.find(msg, "SHUTDOWN") or string.find(msg, "DESTROYED") or string.find(msg, "CRITICAL")) then
        prefix = "@everyone "
    end

    local url = "https://discord.com/api/v10/channels/" .. DISCORD_CHANNEL_ID .. "/messages"
    local body = textutils.serializeJSON({content = prefix .. msg})
    local headers = {
        Authorization = "Bot " .. DISCORD_TOKEN,
        ["Content-Type"] = "application/json"
    }

    local ok, response = pcall(http.post, url, body, headers)
    if not ok then
        print("[Discord] Failed: " .. tostring(response))
    elseif response then
        response.close()
    end
end
-- =================================================

-- Find the Logic Adapter
local reactorSide = nil

for _, side in ipairs({"top","bottom","left","right","front","back"}) do
    if peripheral.getType(side) == "fissionReactorLogicAdapter" then
        reactorSide = side
        break
    end
end

if not reactorSide then
    print("ERROR: Fission Reactor Logic Adapter not found!")
    sendDiscord("REACTOR MONITOR STARTUP FAILED: Logic adapter not found. Reactor may already be destroyed.")
    return
end

print("=== Reactor Safety Monitor ===")
print("Found on: " .. reactorSide)
print("Coolant threshold: " .. (COOLANT_THRESHOLD * 100) .. "%")
print("Waste threshold:   " .. (WASTE_THRESHOLD * 100) .. "%")
print("Damage threshold:  " .. (DAMAGE_THRESHOLD * 100) .. "%")
print("Running...")

if not startupMsgSent then
    sendDiscord("Reactor safety monitor **started**. Monitoring reactor on `" .. reactorSide .. "` side.")
    startupMsgSent = true
end

-- ==================== MAIN LOOP ====================
while true do
    -- CHECK 1: Did the reactor blow up? (block is gone)
    local currentType = peripheral.getType(reactorSide)
    if currentType ~= "fissionReactorLogicAdapter" then
        if lastAlert ~= "blew_up" then
            sendDiscord("REACTOR DESTROYED: The fission reactor logic adapter is no longer detected. The reactor has likely **exploded**.")
            lastAlert = "blew_up"
        end
        redstone.setOutput(REDSTONE_SIDE, true)
        sleep(POLL_INTERVAL)
        -- Keep looping — if the block reappears (rebuilt), we resume monitoring
    else
        -- Read all reactor values
        local ok1, coolant = pcall(peripheral.call, reactorSide, "getCoolantFilledPercentage")
        local ok2, temp    = pcall(peripheral.call, reactorSide, "getTemperature")
        local ok3, active  = pcall(peripheral.call, reactorSide, "getStatus")
        local ok4, waste   = pcall(peripheral.call, reactorSide, "getWasteFilledPercentage")
        local ok5, damage  = pcall(peripheral.call, reactorSide, "getDamagePercent")

        -- Display
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Reactor Safety Monitor ===")
        print("Side: " .. reactorSide)

        if ok1 then print(string.format("Coolant: %.1f%%", coolant * 100)) else print("Coolant: ERROR") end
        if ok4 then print(string.format("Waste:   %.1f%%", waste * 100))     else print("Waste:   ERROR") end
        if ok5 then print(string.format("Damage:  %.1f%%", damage * 100))   else print("Damage:  ERROR") end
        if ok2 then print(string.format("Temp:    %.1f K", temp))           else print("Temp:    ERROR") end
        if ok3 then print(string.format("Status:  %s", active and "ACTIVE" or "INACTIVE")) else print("Status:  ERROR") end
        print("")

        -- Evaluate conditions
        local lowCoolant = ok1 and coolant <= COOLANT_THRESHOLD
        local highWaste  = ok4 and waste >= WASTE_THRESHOLD
        local highDamage = ok5 and damage >= DAMAGE_THRESHOLD
        local readError  = not ok1 or not ok2 or not ok3 or not ok4 or not ok5

        if readError then
            -- Can't read data = reactor may be critically damaged/destroyed
            if lastAlert ~= "read_error" then
                sendDiscord("REACTOR CRITICAL: Cannot read reactor data. The reactor may be destroyed or critically damaged.")
                lastAlert = "read_error"
            end
            print("*** CANNOT READ REACTOR DATA ***")
            redstone.setOutput(REDSTONE_SIDE, true)

        elseif lowCoolant or highWaste or highDamage then
            -- Safety shutdown triggered
            local alerts = {}
            if lowCoolant then table.insert(alerts, "LOW COOLANT " .. string.format("%.1f%%", coolant*100)) end
            if highWaste  then table.insert(alerts, "HIGH WASTE " .. string.format("%.1f%%", waste*100)) end
            if highDamage then table.insert(alerts, "HIGH DAMAGE " .. string.format("%.1f%%", damage*100)) end

            local alertText = table.concat(alerts, " | ")
            print("*** " .. alertText .. " ***")
            print("Triggering shutdown...")

            if lastAlert ~= "safety_shutdown" then
                sendDiscord("REACTOR SAFETY SHUTDOWN: " .. alertText .. ". Emergency stop triggered.")
                lastAlert = "safety_shutdown"
            end

            redstone.setOutput(REDSTONE_SIDE, true)

            if ok3 and active then
                pcall(peripheral.call, reactorSide, "scram")
                print("Reactor SCRAMMED.")
            end

        else
            -- All normal
            if lastAlert ~= nil and lastAlert ~= "normal" then
                sendDiscord("Reactor monitor: All conditions **normal**. Reactor operating safely.")
                lastAlert = "normal"
            end
            print("Status: NORMAL")
            redstone.setOutput(REDSTONE_SIDE, false)
        end
    end

    sleep(POLL_INTERVAL)
end
